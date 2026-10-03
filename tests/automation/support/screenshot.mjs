import sharp from 'sharp';

export async function captureScreenshotPng(environment) {
  try {
    const screenshot = await environment.screenshotClient.takeScreenshot();
    return await sharp(screenshot).png().toBuffer();
  } catch (error) {
    const fallback = await environment.device.getScreenshot();
    if (!fallback.buffer?.length) throw error;
    return sharp(fallback.buffer).png().toBuffer();
  }
}
