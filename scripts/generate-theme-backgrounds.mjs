import sharp from 'sharp';

const width = 1920;
const height = 1080;
const themes = {
  black: { top: 10, bottom: 34, lift: 7 },
  grey: { top: 44, bottom: 67, lift: 16 }
};

// Repeating sub-level dither softens 8-bit banding without random pixel noise.
const bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
for (const [theme, { top, bottom, lift }] of Object.entries(themes)) {
  const pixels = Buffer.alloc(width * height * 3);
  for (let y = 0; y < height; y++) {
    const vertical = y / (height - 1);
    const blend = vertical * vertical * (3 - 2 * vertical);
    for (let x = 0; x < width; x++) {
      const center = Math.sin(Math.PI * x / (width - 1));
      const shade = top + (bottom - top) * blend + lift * center * vertical ** 1.5;
      const dither = (bayer[(y % 4) * 4 + x % 4] + 0.5) / 16 - 0.5;
      const value = Math.round(shade + dither);
      const offset = (y * width + x) * 3;
      pixels.fill(value, offset, offset + 3);
    }
  }
  await sharp(pixels, { raw: { width, height, channels: 3 } })
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toFile(`images/themes/${theme}/background.png`);
}
