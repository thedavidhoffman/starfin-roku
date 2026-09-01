import fs from 'node:fs/promises';
import path from 'node:path';
import addContext from 'mochawesome/addContext.js';
import { capture, processImage } from '@danecodes/roku-screenshot';
import { getAutomationEnvironment } from './environment.mjs';

function sanitizeName(value) {
  return value
    .toLowerCase()
    .replaceAll(/[^a-z0-9]+/g, '-')
    .replaceAll(/^-+|-+$/g, '')
    .slice(0, 100) || 'evidence';
}

export async function captureEvidence(context, checkpoint, options = {}) {
  const environment = await getAutomationEnvironment();
  const screenshotsDir = path.join(environment.resultsDir, 'screenshots');
  const filename = `${sanitizeName(checkpoint)}${options.failure ? '-failure' : ''}.png`;
  const outputPath = path.join(screenshotsDir, filename);

  await fs.mkdir(screenshotsDir, { recursive: true });
  let buffer;
  try {
    buffer = await capture(environment.screenshotClient, { format: 'png' });
  } catch (error) {
    const fallback = await environment.device.getScreenshot();
    if (!fallback.buffer?.length) throw error;
    buffer = await processImage(fallback.buffer, { format: 'png' });
  }
  if (buffer.length === 0) throw new Error(`Screenshot capture returned an empty buffer for ${checkpoint}.`);
  await fs.writeFile(outputPath, buffer);

  const relativePath = path.posix.join('screenshots', filename);
  addContext(context, {
    title: options.failure ? `Failure screenshot: ${checkpoint}` : `Screenshot: ${checkpoint}`,
    value: relativePath
  });

  return { buffer, outputPath, relativePath };
}

export function addEvidenceMetadata(context, metadata) {
  addContext(context, {
    title: 'Automation evidence metadata',
    value: JSON.stringify(metadata, null, 2)
  });
}
