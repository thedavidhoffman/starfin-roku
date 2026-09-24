import sharp from "sharp";
import { mkdir, writeFile } from "node:fs/promises";

// Only the central row/column stretch; circular end caps retain their radius.
for (const [profile, size] of [["fhd", 75], ["hd", 50]]) {
  await mkdir(`images/buttons/${profile}`, { recursive: true });
  for (const focused of [false, true]) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}"><rect width="${size}" height="${size}" rx="${size/2}" fill="${focused ? "white" : "black"}"/></svg>`;
    const inner = await sharp(Buffer.from(svg)).ensureAlpha().raw().toBuffer();
    const edge = size + 2;
    const pixels = Buffer.alloc(edge * edge * 4);
    for (let y = 0; y < size; y++) inner.copy(pixels, ((y+1)*edge+1)*4, y*size*4, (y+1)*size*4);
    const center = 1 + Math.floor(size/2);
    for (const [x,y] of [[center,0],[center,edge-1],[0,center],[edge-1,center]]) pixels[(y*edge+x)*4+3] = 255;
    const png = await sharp(pixels, { raw: { width: edge, height: edge, channels: 4 } }).png().toBuffer();
    await writeFile(`images/buttons/${profile}/playback-summary-${focused ? "focused" : "unfocused"}.9.png`, png);
  }
}
