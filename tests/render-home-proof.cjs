// Requires Fengari CLI and sharp; export Lua draw calls, not engine screenshots.
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
async function main() {
  const out = process.argv[2] || '/tmp/planet-defense-home-proof';
  fs.mkdirSync(out, { recursive: true });
  for (const [w, h] of [[390, 844], [450, 800], [1280, 800]]) {
    for (const page of ['home', 'guards', 'mecha', 'map']) {
      let svg = execFileSync('npx', ['--yes', '--package', 'fengari-node-cli', 'fengari', 'tests/render-home.lua', page, `${w}`, `${h}`], {cwd: root, encoding: 'utf8'});
      svg = svg.replace(/href="(assets\/[^\"]+)"/g, (_, file) => `href="data:image/png;base64,${fs.readFileSync(path.join(root, file)).toString('base64')}"`);
      await sharp(Buffer.from(svg)).png().toFile(path.join(out, `${page}-${w}x${h}.png`));
    }
  }
  console.log(`Layout proofs: ${out} (not engine screenshots)`);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
