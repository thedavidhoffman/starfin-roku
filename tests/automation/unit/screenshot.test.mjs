import assert from 'node:assert/strict';
import test from 'node:test';
import sharp from 'sharp';
import { captureScreenshotPng } from '../support/screenshot.mjs';

async function jpegScreenshot() {
  return sharp({
    create: { width: 2, height: 2, channels: 3, background: '#336699' }
  }).jpeg().toBuffer();
}

test('converts an ECP screenshot to PNG without using the fallback', async () => {
  const screenshot = await jpegScreenshot();
  let fallbackCalled = false;
  const environment = {
    screenshotClient: { takeScreenshot: async () => screenshot },
    device: { getScreenshot: async () => { fallbackCalled = true; } }
  };

  const buffer = await captureScreenshotPng(environment);

  assert.equal((await sharp(buffer).metadata()).format, 'png');
  assert.equal(fallbackCalled, false);
});

test('converts a device screenshot to PNG when ECP capture fails', async () => {
  const screenshot = await jpegScreenshot();
  const environment = {
    screenshotClient: { takeScreenshot: async () => { throw new Error('ECP unavailable'); } },
    device: { getScreenshot: async () => ({ buffer: screenshot }) }
  };

  const buffer = await captureScreenshotPng(environment);

  assert.equal((await sharp(buffer).metadata()).format, 'png');
});

test('uses the device screenshot when ECP image conversion fails', async () => {
  const screenshot = await jpegScreenshot();
  const environment = {
    screenshotClient: { takeScreenshot: async () => Buffer.from('invalid image') },
    device: { getScreenshot: async () => ({ buffer: screenshot }) }
  };

  const buffer = await captureScreenshotPng(environment);

  assert.equal((await sharp(buffer).metadata()).format, 'png');
});

test('retains the ECP error when the fallback screenshot is empty', async () => {
  const captureError = new Error('ECP unavailable');
  const environment = {
    screenshotClient: { takeScreenshot: async () => { throw captureError; } },
    device: { getScreenshot: async () => ({ buffer: Buffer.alloc(0) }) }
  };

  await assert.rejects(captureScreenshotPng(environment), error => error === captureError);
});
