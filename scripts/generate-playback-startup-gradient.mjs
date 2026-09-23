import sharp from 'sharp';
import { writeFile } from 'node:fs/promises';

// A compact alpha texture stretches to fullscreen without adding image detail.
const size = 256;
const pixels = Buffer.alloc(size * size * 4);
const smoothstep = value => {
  const t = Math.max(0, Math.min(1, value));
  return t * t * (3 - 2 * t);
};
for (let y = 0; y < size; y++) {
  for (let x = 0; x < size; x++) {
    const horizontal = 1 - smoothstep((x / (size - 1) - 0.1) / 0.55);
    const vertical = 1 - smoothstep((y / (size - 1) - 0.08) / 0.6);
    pixels[(y * size + x) * 4 + 3] = Math.round(255 * 0.6 * horizontal * vertical);
  }
}
const png = await sharp(pixels, { raw: { width: size, height: size, channels: 4 } })
  .png()
  .toBuffer();
await writeFile('images/overlays/playback-startup-gradient.png', png);
