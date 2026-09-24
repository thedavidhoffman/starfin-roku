import test from "node:test";
import assert from "node:assert/strict";
import sharp from "sharp";

for (const state of ["focused", "unfocused"]) {
  test(`DynamicButton ${state} retains its fill and rounded nine-patch geometry`, async () => {
    const { data, info } = await sharp(`images/buttons/media-toolbar-button-${state}.9.png`).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    assert.equal(info.width, 60);
    assert.equal(info.height, 60);
    const pixel = (x, y) => Array.from(data.subarray((y * info.width + x) * 4, (y * info.width + x) * 4 + 4));
    assert.deepEqual(pixel(30, 30), state === "focused" ? [255, 255, 255, 255] : [24, 33, 48, 210]);
    for (const [x, y] of [[1, 1], [58, 1], [1, 58], [58, 58], [8, 8]]) assert.equal(pixel(x, y)[3], 0);
    for (let i = 0; i < 60; i++) {
      const expected = i === 30 ? [0, 0, 0, 255] : [0, 0, 0, 0];
      for (const [x, y] of [[i, 0], [i, 59], [0, i], [59, i]]) assert.deepEqual(pixel(x, y), expected);
    }
  });
}
