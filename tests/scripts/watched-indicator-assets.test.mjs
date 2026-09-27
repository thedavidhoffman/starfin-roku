import test from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';

const read = name => sharp('images/icons/' + name).ensureAlpha().raw().toBuffer({ resolveWithObject: true });

for (const [name, background, check] of [
  ['watched-check.png', [0, 0, 0], [255, 255, 255]],
  ['watched-check-high-contrast.png', [226, 164, 76], [0, 0, 0]]
]) {
  test(name + ' has opaque background and check with transparent outer corners', async () => {
    const { data, info } = await read(name);
    assert.equal(info.width, 58);
    assert.equal(info.height, 58);
    let backgroundCount = 0;
    let checkCount = 0;
    for (let y = 8; y < 50; y++) {
      for (let x = 8; x < 50; x++) {
        const offset = (y * 58 + x) * 4;
        assert.equal(data[offset + 3], 255);
        const rgb = Array.from(data.subarray(offset, offset + 3));
        if (rgb.join() === background.join()) backgroundCount++;
        if (rgb.join() === check.join()) checkCount++;
      }
    }
    assert.ok(backgroundCount > 1000);
    assert.ok(checkCount > 100);
    assert.equal(data[3], 0);
  });
}

test('both styles share the same alpha geometry', async () => {
  const subtle = await read('watched-check.png');
  const contrast = await read('watched-check-high-contrast.png');
  for (let i = 3; i < subtle.data.length; i += 4) assert.equal(subtle.data[i], contrast.data[i]);
});
