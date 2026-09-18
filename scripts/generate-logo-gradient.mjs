import sharp from 'sharp';

// A compact alpha texture stretches with the card; both fades end transparently.
const size = 256;
const pixels = Buffer.alloc(size * size * 4);
const smoothstep = value => {
  const t = Math.max(0, Math.min(1, value));
  return t * t * (3 - 2 * t);
};

for (let y = 0; y < size; y++) {
  for (let x = 0; x < size; x++) {
    const horizontal = 1 - smoothstep((x / (size - 1) - 0.35) / 0.45);
    const vertical = smoothstep((y / (size - 1) - 0.25) / 0.55);
    pixels[(y * size + x) * 4 + 3] = Math.round(255 * 0.68 * horizontal * vertical);
  }
}

await sharp(pixels, { raw: { width: size, height: size, channels: 4 } })
  .png()
  .toFile('images/overlays/episode-logo-gradient.png');
