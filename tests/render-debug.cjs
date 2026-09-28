const {execFileSync}=require('node:child_process');
const fs=require('node:fs');
const path=require('node:path');
const sharp=require('sharp');
const root=path.resolve(__dirname,'..');
(async()=>{
  const out='/tmp/planet-debug-proof'; fs.mkdirSync(out,{recursive:true});
  for(const [w,h] of [[320,568],[390,844],[450,800],[1280,800]]){
    let svg=execFileSync('npx',['--yes','--package','fengari-node-cli','fengari','tests/render-home.lua','battle',String(w),String(h),'25','debug'],{cwd:root,encoding:'utf8'});
    if(!svg.startsWith('<svg')) throw Error(svg.slice(0,500));
    svg=svg.replace(/href="(assets\/[^\"]+)"/g,(_,file)=>`href="data:image/png;base64,${fs.readFileSync(path.join(root,file)).toString('base64')}"`);
    await sharp(Buffer.from(svg)).png().toFile(path.join(out,`debug-${w}x${h}.png`));
  }
  console.log(`PASS debug layout proofs: ${out}; displayed values are layout fixtures, not live measurements`);
})().catch(e=>{console.error(e);process.exitCode=1;});
