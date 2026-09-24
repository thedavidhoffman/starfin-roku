import sharp from "sharp";
import { writeFile } from "node:fs/promises";

// Match DynamicButton's 58-pixel height; only the center stretches horizontally.
const size = 58;
const edge = size + 2;
for (const focused of [false, true]) {
  const fill = focused ? "#ffffff" : "#182130";
  const opacity = focused ? 1 : 210 / 255;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}"><rect width="${size}" height="${size}" rx="${size / 2}" fill="${fill}"/></svg>`;
  const inner = await sharp(Buffer.from(svg)).ensureAlpha().raw().toBuffer();
  // Apply alpha after rasterization to preserve the exact unpremultiplied fill RGB.
  for (let i = 3; i < inner.length; i += 4) inner[i] = Math.round(inner[i] * opacity);
  const pixels = Buffer.alloc(edge * edge * 4);
  for (let y = 0; y < size; y++) {
    inner.copy(pixels, ((y + 1) * edge + 1) * 4, y * size * 4, (y + 1) * size * 4);
  }
  const center = 1 + Math.floor(size / 2);
  for (const [x, y] of [[center, 0], [center, edge - 1], [0, center], [edge - 1, center]]) {
    pixels[(y * edge + x) * 4 + 3] = 255;
  }
  const png = await sharp(pixels, { raw: { width: edge, height: edge, channels: 4 } }).png().toBuffer();
  await writeFile(`images/buttons/media-toolbar-button-${focused ? "focused" : "unfocused"}.9.png`, png);
}
