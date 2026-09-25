import test from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import { stat } from 'node:fs/promises';

const themes = ['blue', 'black', 'grey'];
const detailedColors = { blue: [16, 28, 42, 255], black: [38, 38, 38, 255], grey: [74, 74, 74, 255] };
for (const [theme, color] of Object.entries(detailedColors)) {
  test(`${theme} detailed panel has the intended dimensions and opaque fill`, async () => {
    const { data, info } = await sharp(`images/themes/${theme}/detailed-card-panel.png`).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    assert.equal(info.width, 882);
    assert.equal(info.height, 496);
    for (let index = 0; index < data.length; index += 4) {
      assert.deepEqual([...data.subarray(index, index + 4)], color);
    }
  });
}
const profiles = ['', 'fhd/', 'hd/'];
const panelFiles = ['header-menu-fill.9.png', 'header-menu-glass.9.png', 'dialog-panel.9.png'];

for (const theme of themes) {
  test(`${theme} background fills a 1080p canvas`, async () => {
    const metadata = await sharp(`images/themes/${theme}/background.png`).metadata();
    assert.equal(metadata.width, 1920);
    assert.equal(metadata.height, 1080);
    assert.equal(metadata.format, 'png');
  });
}

for (const theme of ['black', 'grey']) {
  test(`${theme} background stays within its 100 KB package budget`, async () => {
    const file = await stat(`images/themes/${theme}/background.png`);
    assert.ok(file.size <= 100_000, `${file.size} bytes exceeds the background budget`);
  });

  for (const profile of profiles) {
    for (const file of panelFiles) {
      test(`${theme}/${profile}${file} preserves alpha and nine-patch markers`, async () => {
        const original = await sharp(`images/themes/blue/${profile}${file}`).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
        const variant = await sharp(`images/themes/${theme}/${profile}${file}`).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
        assert.equal(variant.info.width, original.info.width);
        assert.equal(variant.info.height, original.info.height);
        const { width, height } = original.info;
        for (let y = 0; y < height; y++) {
          for (let x = 0; x < width; x++) {
            const index = (y * width + x) * 4;
            assert.equal(variant.data[index + 3], original.data[index + 3], `alpha at ${x},${y}`);
            if (x === 0 || y === 0 || x === width - 1 || y === height - 1) {
              assert.deepEqual(variant.data.subarray(index, index + 4), original.data.subarray(index, index + 4), `marker at ${x},${y}`);
            }
          }
        }
      });
    }
  }
}

for (const theme of ['black', 'grey']) {
  for (const profile of profiles) {
    test(`${theme}/${profile}dialog preserves the white border and uses a neutral interior`, async () => {
      const original = await sharp(`images/themes/blue/${profile}dialog-panel.9.png`).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
      const variant = await sharp(`images/themes/${theme}/${profile}dialog-panel.9.png`).ensureAlpha().raw().toBuffer();
      for (let i = 0; i < original.data.length; i += 4) {
        if (original.data[i] === 255 && original.data[i + 1] === 255 && original.data[i + 2] === 255) {
          assert.deepEqual(variant.subarray(i, i + 4), original.data.subarray(i, i + 4));
        }
      }
      const center = (Math.floor(original.info.height / 2) * original.info.width + Math.floor(original.info.width / 2)) * 4;
      const expected = theme === 'black' ? 25 : 61;
      assert.deepEqual([...variant.subarray(center, center + 4)], [expected, expected, expected, 255]);
    });
  }
}

for (const [theme, fill] of [['black', 38], ['grey', 74]]) {
  test(`${theme} square button preserves the original mask and uses a neutral fill`, async () => {
    const original = await sharp('images/themes/blue/square-button-background.png').ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const variant = await sharp(`images/themes/${theme}/square-button-background.png`).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    assert.equal(variant.info.width, original.info.width);
    assert.equal(variant.info.height, original.info.height);
    for (let i = 0; i < original.data.length; i += 4) {
      assert.equal(variant.data[i + 3], original.data[i + 3]);
      if (variant.data[i + 3]) assert.deepEqual([...variant.data.subarray(i, i + 3)], [fill, fill, fill]);
    }
  });
}
