// User-approved standing-pose extraction; source sheets remain unchanged.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const regions = {
  bombardier: [0, 210, 480, 560],
  stormcaller: [0, 180, 465, 600],
  rail_sniper: [0, 170, 455, 600],
  blade_dancer: [0, 165, 430, 615],
  alchemist: [0, 190, 485, 600],
  gravity_engineer: [0, 190, 435, 650],
};
async function main() {
  for (const [id, [left, top, width, height]] of Object.entries(regions)) {
    const source = `assets/design/defenders/${id}/poses-v1.png`;
    const {data, info} = await sharp(path.join(root, source)).extract({left,top,width,height}).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    let x0=width,y0=height,x1=0,y1=0;
    for(let y=0;y<height;y++) for(let x=0;x<width;x++) {
      if(data[(y*width+x)*4+3]>32) {x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);}
    }
    if(x1<=x0 || y1<=y0) throw Error(`Empty sprite: ${id}`);
    const scale=Math.min(224/(x1-x0+1),218/(y1-y0+1));
    const w=Math.round((x1-x0+1)*scale),h=Math.round((y1-y0+1)*scale);
    const sprite=await sharp(data,{raw:info}).extract({left:x0,top:y0,width:x1-x0+1,height:y1-y0+1}).resize(w,h).png().toBuffer();
    const folder=path.join(root,'assets/image/defenders',id);
    fs.mkdirSync(folder,{recursive:true});
    await sharp({create:{width:256,height:256,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite([{input:sprite,left:Math.round((256-w)/2),top:234-h}]).png().toFile(path.join(folder,'standing-v1.png'));
    fs.writeFileSync(path.join(folder,'manifest-v1.json'),JSON.stringify({version:1,source,canvas:[256,256],footAnchor:[128,234],standing:'standing-v1.png',status:'prototype-static-pose',animationFrames:false,sourceRect:[left+x0,top+y0,x1-x0+1,y1-y0+1]},null,2)+'\n');
    console.log(`${id}: 256x256, anchor 128,234`);
  }
}
main().catch(error=>{console.error(error);process.exitCode=1;});
