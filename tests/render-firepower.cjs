const {execFileSync}=require('node:child_process');
const fs=require('node:fs');
const path=require('node:path');
const sharp=require('sharp');
const root=path.resolve(__dirname,'..');
async function main(){
  const out=process.argv[2]||'/tmp/planet-firepower-proof';fs.mkdirSync(out,{recursive:true});
  for(const [w,h] of [[390,844],[450,800]]) for(const frame of [20,25,30]){
    let svg=execFileSync('npx',['--yes','--package','fengari-node-cli','fengari','tests/render-home.lua','battle',String(w),String(h),String(frame)],{cwd:root,encoding:'utf8'});
    if(!svg.startsWith('<svg')) throw Error(svg.slice(0,500));
    svg=svg.replace(/href="(assets\/[^\"]+)"/g,(_,file)=>`href="data:image/png;base64,${fs.readFileSync(path.join(root,file)).toString('base64')}"`);
    await sharp(Buffer.from(svg)).png().toFile(path.join(out,`battle-${w}x${h}-${frame}.png`));
  }
  console.log(`PASS battle layout proofs: ${out}; synthetic late-game fixture, not engine screenshots`);
}
main().catch(e=>{console.error(e);process.exitCode=1;});
