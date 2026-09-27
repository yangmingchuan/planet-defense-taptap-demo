// Development-only: rasterize pinned Lucide assets for NanoVG's image loader.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');
const dir = path.resolve(__dirname, '../assets/image/home/icons');
const names = process.argv.includes('--audio-only') ? ['volume-2','volume-x'] : ['castle', 'shield', 'bot', 'orbit', 'swords', 'snowflake', 'heart', 'lock-keyhole', 'volume-2', 'volume-x'];
async function main() {
  await fs.mkdir(dir, { recursive: true });
  for (const name of names) {
    const response = await fetch(`https://unpkg.com/lucide-static@0.468.0/icons/${name}.svg`);
    if (!response.ok) throw new Error(`${name}: ${response.status}`);
    const svg = await response.text();
    for (const [tone, color] of [['light', '#f5f8f6'], ['dark', '#254c4d'], ['gold', '#ffd37a']]) {
      await sharp(Buffer.from(svg.replace(/currentColor/g, color)), { density: 384 })
        .resize(96, 96).png().toFile(path.join(dir, `${name}-${tone}.png`));
    }
  }
  const license = await fetch('https://unpkg.com/lucide-static@0.468.0/LICENSE');
  if (!license.ok) throw new Error('Lucide license download failed');
  await fs.writeFile(path.join(dir, 'LICENSE'), await license.text());
}
main().catch(error => { console.error(error); process.exitCode = 1; });
