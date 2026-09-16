const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '../assets/image/monsters');
const monsters = [
  { id: 'basic', name: '小怪兽', fps: 8, attack: [120, 140, 70, 80, 130, 160] },
  { id: 'tank', name: '肉怪兽', fps: 6, attack: [160, 240, 220, 100, 160, 220] },
  { id: 'armored', name: '甲壳怪兽', fps: 4, attack: [200, 250, 150, 150, 200, 250] },
  { id: 'agile', name: '敏捷怪兽', fps: 12, attack: [70, 90, 50, 60, 90, 120] },
];

function neighbors(p, w, h) {
  const x = p % w;
  const y = Math.floor(p / w);
  return [x ? p - 1 : -1, x + 1 < w ? p + 1 : -1,
    y ? p - w : -1, y + 1 < h ? p + w : -1];
}

function removeExteriorChecker(data, w, h, clearInterior = false) {
  const seen = new Uint8Array(w * h);
  const queue = [];
  const background = (p) => {
    const rgb = [data[p * 4], data[p * 4 + 1], data[p * 4 + 2]];
    return Math.min(...rgb) >= 170 && Math.max(...rgb) - Math.min(...rgb) <= 8;
  };
  const enqueue = (p) => {
    if (p >= 0 && !seen[p] && background(p)) {
      seen[p] = 1;
      queue.push(p);
    }
  };
  for (let x = 0; x < w; x++) { enqueue(x); enqueue((h - 1) * w + x); }
  for (let y = 0; y < h; y++) { enqueue(y * w); enqueue(y * w + w - 1); }
  // Only remove bright neutral regions connected to the exterior, protecting armor highlights.
  for (let i = 0; i < queue.length; i++) {
    for (const p of neighbors(queue[i], w, h)) enqueue(p);
  }
  for (let p = 0; p < w * h; p++) if (seen[p]) data[p * 4 + 3] = 0;
  if (clearInterior) {
    for (let p = 0; p < w * h; p++) {
      if (seen[p] || !background(p)) continue;
      const region = [p]; seen[p] = 1;
      let low = 255, high = 0;
      for (let i = 0; i < region.length; i++) {
        const q = region[i]; low = Math.min(low, data[q * 4]); high = Math.max(high, data[q * 4]);
        for (const n of neighbors(q, w, h)) if (n >= 0 && !seen[n] && background(n)) {
          seen[n] = 1; region.push(n);
        }
      }
      if (region.length > 20 && low < 225 && high > 240) {
        for (const q of region) data[q * 4 + 3] = 0;
      }
    }
  }
  return queue.length;
}

function bounds(data, w, h) {
  let left = w, top = h, right = -1, bottom = -1;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (data[(y * w + x) * 4 + 3] < 16) continue;
    left = Math.min(left, x); right = Math.max(right, x);
    top = Math.min(top, y); bottom = Math.max(bottom, y);
  }
  if (right < 0) throw new Error('Empty frame');
  return { left, top, width: right - left + 1, height: bottom - top + 1 };
}

function connectedSprites(data, w, h) {
  const seen = new Uint8Array(w * h), groups = [];
  for (let p = 0; p < w * h; p++) {
    if (seen[p] || data[p * 4 + 3] < 16) continue;
    const pixels = [p]; seen[p] = 1;
    let left = w, right = 0, top = h, bottom = 0;
    for (let i = 0; i < pixels.length; i++) {
      const q = pixels[i], x = q % w, y = Math.floor(q / w);
      left = Math.min(left, x); right = Math.max(right, x);
      top = Math.min(top, y); bottom = Math.max(bottom, y);
      for (const n of neighbors(q, w, h)) {
        if (n >= 0 && !seen[n] && data[n * 4 + 3] >= 16) { seen[n] = 1; pixels.push(n); }
      }
    }
    groups.push({ pixels, left, right, top, bottom });
  }
  groups.sort((a, b) => b.pixels.length - a.pixels.length);
  const main = groups.slice(0, 12);
  if (main.length !== 12 || main.some(g => g.pixels.length < 5000)) throw new Error('Could not isolate twelve sprites');
  main.sort((a, b) => (a.top + a.bottom) - (b.top + b.bottom));
  const ordered = [];
  for (let row = 0; row < 4; row++) ordered.push(...main.slice(row * 3, row * 3 + 3).sort((a, b) => a.left - b.left));
  // Attach detached artwork, such as a slash arc, to the nearest character instead of clipping it at grid lines.
  for (const extra of groups.slice(12)) {
    if (extra.pixels.length < 12) continue;
    const distance = g => Math.hypot(Math.max(g.left - extra.right, extra.left - g.right, 0),
      Math.max(g.top - extra.bottom, extra.top - g.bottom, 0));
    const nearest = [...ordered].sort((a, b) => distance(a) - distance(b))[0];
    if (distance(nearest) > 36) continue;
    nearest.pixels.push(...extra.pixels);
    nearest.left = Math.min(nearest.left, extra.left); nearest.right = Math.max(nearest.right, extra.right);
    nearest.top = Math.min(nearest.top, extra.top); nearest.bottom = Math.max(nearest.bottom, extra.bottom);
  }
  return ordered.map(g => {
    const width = g.right - g.left + 1, height = g.bottom - g.top + 1;
    const output = Buffer.alloc(width * height * 4);
    for (const p of g.pixels) {
      const q = ((Math.floor(p / w) - g.top) * width + p % w - g.left) * 4;
      data.copy(output, q, p * 4, p * 4 + 4);
    }
    return { data: output, width, height, box: { left: 0, top: 0, width, height }, removed: 0,
      sourceRect: { left: g.left, top: g.top, width, height } };
  });
}

async function main() {
  const removeBackground = process.argv.includes('--remove-checker');
  const report = [];
  for (const monster of monsters) {
    const dir = path.join(root, monster.id);
    const source = path.join(dir, 'animation-source-v1.png');
    const meta = await sharp(source).metadata();
    let frames = [];
    let removedPixels = 0;
    if (removeBackground) {
      const { data } = await sharp(source).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
      removedPixels = removeExteriorChecker(data, meta.width, meta.height, ['basic', 'agile'].includes(monster.id));
      frames = connectedSprites(data, meta.width, meta.height);
    }
    for (let i = 0; !removeBackground && i < 12; i++) {
      const col = i % 3, row = Math.floor(i / 3);
      const left = Math.round(col * meta.width / 3);
      const top = Math.round(row * meta.height / 4);
      const width = Math.round((col + 1) * meta.width / 3) - left;
      const height = Math.round((row + 1) * meta.height / 4) - top;
      const { data } = await sharp(source).extract({ left, top, width, height })
        .ensureAlpha().raw().toBuffer({ resolveWithObject: true });
      const removed = removeBackground ? removeExteriorChecker(data, width, height) : 0;
      const box = bounds(data, width, height);
      frames.push({ data, width, height, box, removed, sourceRect: { left, top, width, height } });
    }
    const scale = Math.min(224 / Math.max(...frames.map(f => f.box.width)),
      216 / Math.max(...frames.map(f => f.box.height)));
    const clips = {};
    for (const [action, offset] of [['walk', 0], ['attack', 6]]) {
      await fs.mkdir(path.join(dir, action), { recursive: true });
      const composite = [];
      const entries = [];
      for (let i = 0; i < 6; i++) {
        const frame = frames[offset + i];
        const width = Math.max(1, Math.round(frame.box.width * scale));
        const height = Math.max(1, Math.round(frame.box.height * scale));
        const sprite = await sharp(frame.data, { raw: { width: frame.width, height: frame.height, channels: 4 } })
          .extract(frame.box).resize(width, height).png().toBuffer();
        const left = Math.round((256 - width) / 2), top = 232 - height;
        const png = await sharp({ create: { width: 256, height: 256, channels: 4, background: '#00000000' } })
          .composite([{ input: sprite, left, top }]).png().toBuffer();
        const file = `${action}/${String(i + 1).padStart(2, '0')}.png`;
        await fs.writeFile(path.join(dir, file), png);
        composite.push({ input: png, left: i * 256, top: 0 });
        entries.push({ file, durationMs: action === 'walk' ? 1000 / monster.fps : monster.attack[i],
          sourceRect: frame.sourceRect, sourceContentBounds: frame.box,
          destinationRect: { left, top, width, height }, atlasRect: { x: i * 256, y: 0, width: 256, height: 256 } });
      }
      const sheet = `${action}-sheet-v1.png`;
      await sharp({ create: { width: 1536, height: 256, channels: 4, background: '#00000000' } })
        .composite(composite).png().toFile(path.join(dir, sheet));
      clips[action] = { sheet, loop: action === 'walk', frames: entries };
      if (action === 'attack') clips[action].events = [{ name: 'hit', frameIndex: 3,
        atMs: monster.attack.slice(0, 3).reduce((a, b) => a + b, 0), oncePerAttack: true }];
    }
    const manifest = { version: 1, id: monster.id, name: monster.name,
      status: 'AI动画初稿，待游戏内复查步态和细节连续性', frameIndexBase: 0,
      frameSize: { width: 256, height: 256 }, pivotPixels: { x: 128, y: 232 },
      source: 'animation-source-v1.png', sourceGrid: { columns: 3, rows: 4 },
      processing: { removeExteriorChecker: removeBackground, uniformScale: scale,
        note: '统一缩放及脚底对齐，水平按轮廓居中；封闭缝隙和白边需人工复查。' }, clips };
    await fs.writeFile(path.join(dir, 'animations-v1.json'), JSON.stringify(manifest, null, 2) + '\n');
    report.push({ id: monster.id, frameCount: 12, sourceSize: [meta.width, meta.height],
      backgroundRemovedPixels: removedPixels, uniformScale: scale });
  }
  await fs.writeFile(path.join(root, 'export-report-v1.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
}

main().catch(error => { console.error(error); process.exitCode = 1; });
