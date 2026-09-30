import sharp from 'sharp';
import { mkdir } from 'node:fs/promises';

// Header-nav glass colors, with the smaller radius used by the TV settings cards.
for (const [profile, scale] of [['fhd', 1], ['hd', 2 / 3]]) {
  const size = Math.round(60 * scale);
  const radius = 12 * scale;
  const stroke = scale;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">
    <rect x="${stroke / 2}" y="${stroke / 2}" width="${size - stroke}" height="${size - stroke}" rx="${radius}" fill="#e1e8f7" fill-opacity="0.133333" stroke="white" stroke-opacity="0.15" stroke-width="${stroke}"/>
    <rect x="${2 * scale}" y="${2 * scale}" width="${size - 4 * scale}" height="${size - 4 * scale}" rx="${radius - 2 * scale}" fill="none" stroke="#edf3f9" stroke-opacity="0.06" stroke-width="${stroke}"/>
  </svg>`;
  const inner = await sharp(Buffer.from(svg)).ensureAlpha().raw().toBuffer();
  const edge = size + 2;
  const pixels = Buffer.alloc(edge * edge * 4);
  for (let y = 0; y < size; y++) inner.copy(pixels, ((y + 1) * edge + 1) * 4, y * size * 4, (y + 1) * size * 4);
  const center = 1 + Math.floor(size / 2);
  for (const [x, y] of [[center, 0], [center, edge - 1], [0, center], [edge - 1, center]]) pixels[(y * edge + x) * 4 + 3] = 255;
  await mkdir(`images/settings/${profile}`, { recursive: true });
  await sharp(pixels, { raw: { width: edge, height: edge, channels: 4 } }).png().toFile(`images/settings/${profile}/settings-card-glass.9.png`);
}
