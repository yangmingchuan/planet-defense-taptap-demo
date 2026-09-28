const {execFileSync} = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const baseline = execFileSync('git', ['show', '55e8b8a:scripts/main.lua'], {cwd: root, encoding: 'utf8'});
const setup = `package.path="scripts/?.lua;"..package.path
package.preload["LuaScripts/Utilities/Sample"]=function() return {} end
package.preload["urhox-libs/UI"]=function() return {} end
function nvgCreateImage(_,path) print(path); return path end
function nvgImageSize() return 1,1 end
`;
async function measure(source) {
  const code = setup + '\n' + source + '\nLoadImages()\n';
  const output = execFileSync('npx', ['--yes', '--package', 'fengari-node-cli', 'fengari', '-e', code], {
    cwd: root, encoding: 'utf8', maxBuffer: 1024 * 1024,
  }).trim();
  const files = output.split('\n');
  let bytes = 0;
  for (const file of files) {
    if (!file.startsWith('assets/image/')) throw new Error(output);
    const {width, height} = await sharp(path.join(root, file)).metadata();
    bytes += width * height * 4;
  }
  return {imageLoads: files.length, rgbaMiBEstimate: Number((bytes / 1048576).toFixed(2))};
}
(async () => {
  const before = await measure(baseline);
  const after = await measure(fs.readFileSync(path.join(root, 'scripts/main.lua'), 'utf8'));
  if (after.imageLoads >= before.imageLoads / 2) throw new Error('Startup texture budget regressed');
  console.log(JSON.stringify({baseline: '55e8b8a', before, after,
    note: 'RGBA estimate only; excludes engine/browser overhead and audio. Not measured process memory.'}, null, 2));
})().catch(error => {console.error(error); process.exitCode = 1;});
