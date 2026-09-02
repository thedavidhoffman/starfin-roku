import fs from 'node:fs/promises';
import { createWriteStream } from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';
import yazl from 'yazl';

const loginServerField = {
  left: 995,
  top: 389,
  width: 700,
  height: 105
};
const referenceResolution = { width: 1920, height: 1080 };

export function validateAutomationReport(report) {
  const stats = report?.stats;
  if (!stats || !Number.isInteger(stats.tests) || stats.tests < 1) {
    throw new Error('Automation report must contain at least one executed test.');
  }
  if (stats.failures !== 0) throw new Error('Automation report contains failed tests.');
  if (stats.pending !== 0) throw new Error('Automation report contains pending tests.');
  if ((stats.skipped ?? 0) !== 0) throw new Error('Automation report contains skipped tests.');
  if ((stats.other ?? 0) !== 0) throw new Error('Automation report contains tests with an unexpected result.');
  if (stats.passes !== stats.tests) throw new Error('Automation report pass count does not match its test count.');

  return {
    tests: stats.tests,
    passes: stats.passes,
    completedAt: stats.end
  };
}

export function shouldRedactLoginScreenshot(filename) {
  const normalized = filename.toLowerCase();
  return normalized.endsWith('.png')
    && (normalized.startsWith('login-') || normalized.includes('authenticated-smoke-test'));
}

export function scaleLoginServerField(width, height) {
  const scaleX = width / referenceResolution.width;
  const scaleY = height / referenceResolution.height;
  return {
    left: Math.round(loginServerField.left * scaleX),
    top: Math.round(loginServerField.top * scaleY),
    width: Math.round(loginServerField.width * scaleX),
    height: Math.round(loginServerField.height * scaleY)
  };
}

export async function redactLoginScreenshot(inputPath, outputPath = inputPath) {
  const metadata = await sharp(inputPath).metadata();
  if (!metadata.width || !metadata.height) throw new Error('Unable to determine screenshot dimensions for redaction.');

  const rectangle = scaleLoginServerField(metadata.width, metadata.height);
  const fontSize = Math.max(12, Math.round(28 * metadata.width / referenceResolution.width));
  const overlay = Buffer.from(`
    <svg width="${rectangle.width}" height="${rectangle.height}" xmlns="http://www.w3.org/2000/svg">
      <rect width="100%" height="100%" fill="#111827" />
      <text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle"
        fill="#ffffff" font-family="sans-serif" font-size="${fontSize}" font-weight="bold">REDACTED</text>
    </svg>
  `);
  const redacted = await sharp(inputPath)
    .composite([{ input: overlay, left: rectangle.left, top: rectangle.top }])
    .removeAlpha()
    .png()
    .toBuffer();
  await fs.writeFile(outputPath, redacted);

  return rectangle;
}

function serverAddresses(server) {
  const values = new Set();
  if (!server) return values;

  values.add(server);
  try {
    const parsed = new URL(server.includes('://') ? server : `http://${server}`);
    if (parsed.host) values.add(parsed.host);
    if (parsed.hostname) values.add(parsed.hostname);
  } catch {
    // The complete configured value is still scanned when it is not URL-shaped.
  }
  return values;
}

export function buildSensitiveValues({ rokuHost, rokuPassword, server, jellyfinPassword }) {
  const values = [];
  for (const value of serverAddresses(server)) values.push({ label: 'configured Jellyfin server', value });
  values.push(
    { label: 'configured Roku host', value: rokuHost },
    { label: 'Roku developer password', value: rokuPassword, wholeToken: true },
    { label: 'Jellyfin password', value: jellyfinPassword, wholeToken: true }
  );

  const unique = new Map();
  for (const item of values) {
    if (typeof item.value !== 'string' || item.value.length === 0) continue;
    if (!unique.has(item.value)) unique.set(item.value, item);
  }
  return [...unique.values()];
}

export function assertNoSensitiveText(text, sensitiveValues, sourceName = 'public report') {
  for (const sensitive of sensitiveValues) {
    if (containsSensitiveValue(text, sensitive)) {
      throw new Error(`${sourceName} contains the ${sensitive.label}.`);
    }
  }
}

function containsSensitiveValue(text, sensitive) {
  if (sensitive.wholeToken !== true) return text.includes(sensitive.value);

  const propertyForms = [
    `"${sensitive.value}":`,
    `&quot;${sensitive.value}&quot;:`,
    `\\&quot;${sensitive.value}\\&quot;:`
  ];
  let searchableText = text;
  for (const propertyForm of propertyForms) searchableText = searchableText.replaceAll(propertyForm, '');

  let index = searchableText.indexOf(sensitive.value);
  while (index >= 0) {
    const before = index > 0 ? searchableText[index - 1] : '';
    const afterIndex = index + sensitive.value.length;
    const after = afterIndex < searchableText.length ? searchableText[afterIndex] : '';
    const startsWithWord = /[a-z0-9]/i.test(sensitive.value[0]);
    const endsWithWord = /[a-z0-9]/i.test(sensitive.value.at(-1));
    const hasLeftBoundary = !startsWithWord || !/[a-z0-9]/i.test(before);
    const hasRightBoundary = !endsWithWord || !/[a-z0-9]/i.test(after);
    if (hasLeftBoundary && hasRightBoundary) return true;
    index = searchableText.indexOf(sensitive.value, index + 1);
  }
  return false;
}

async function listFiles(root, current = root) {
  const entries = await fs.readdir(current, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const absolutePath = path.join(current, entry.name);
    if (entry.isDirectory()) {
      files.push(...await listFiles(root, absolutePath));
    } else if (entry.isFile()) {
      files.push({
        absolutePath,
        relativePath: path.relative(root, absolutePath).split(path.sep).join('/')
      });
    }
  }
  return files;
}

async function scanPublicText(publicDir, sensitiveValues) {
  const files = await listFiles(publicDir);
  for (const file of files) {
    if (!['.html', '.json'].includes(path.extname(file.relativePath).toLowerCase())) continue;
    const text = await fs.readFile(file.absolutePath, 'utf8');
    assertNoSensitiveText(text, sensitiveValues, file.relativePath);
  }
}

async function createZip(sourceDir, outputPath) {
  const zip = new yazl.ZipFile();
  const files = await listFiles(sourceDir);
  for (const file of files) zip.addFile(file.absolutePath, file.relativePath);

  await new Promise((resolve, reject) => {
    const output = createWriteStream(outputPath);
    zip.outputStream.once('error', reject);
    output.once('error', reject);
    output.once('close', resolve);
    zip.outputStream.pipe(output);
    zip.end();
  });
  return files.map(file => file.relativePath);
}

export async function createReleaseAutomationReport({
  resultsDir,
  runId,
  version,
  sensitiveValues
}) {
  const reportJsonPath = path.join(resultsDir, 'report.json');
  const report = JSON.parse(await fs.readFile(reportJsonPath, 'utf8'));
  const summary = validateAutomationReport(report);
  const publicDir = path.join(resultsDir, 'public-report');
  const archiveName = `starfin-automation-report-v${version}-${runId}.zip`;
  const archivePath = path.join(resultsDir, archiveName);

  await fs.rm(publicDir, { recursive: true, force: true });
  await fs.rm(archivePath, { force: true });
  await fs.mkdir(path.join(publicDir, 'screenshots'), { recursive: true });
  await Promise.all([
    fs.copyFile(path.join(resultsDir, 'report.html'), path.join(publicDir, 'report.html')),
    fs.copyFile(reportJsonPath, path.join(publicDir, 'report.json')),
    fs.cp(path.join(resultsDir, 'screenshots'), path.join(publicDir, 'screenshots'), { recursive: true })
  ]);

  const screenshots = await fs.readdir(path.join(publicDir, 'screenshots'));
  const redactedScreenshots = screenshots.filter(shouldRedactLoginScreenshot);
  for (const screenshot of redactedScreenshots) {
    await redactLoginScreenshot(path.join(publicDir, 'screenshots', screenshot));
  }
  if (redactedScreenshots.length === 0) {
    throw new Error('Release report did not contain a Login screenshot to redact.');
  }

  const verification = {
    starfinVersion: version,
    tests: summary.tests,
    passes: summary.passes,
    completedAt: summary.completedAt
  };
  await fs.writeFile(
    path.join(publicDir, 'verification.json'),
    `${JSON.stringify(verification, null, 2)}\n`
  );
  await scanPublicText(publicDir, sensitiveValues);

  const archiveEntries = await createZip(publicDir, archivePath);
  const requiredEntries = ['report.html', 'report.json', 'verification.json'];
  for (const required of requiredEntries) {
    if (!archiveEntries.includes(required)) throw new Error(`Release archive is missing ${required}.`);
  }
  if (archiveEntries.some(entry => entry.startsWith('logs/'))) {
    throw new Error('Release archive unexpectedly contains automation logs.');
  }

  return { archivePath, publicDir, verification, redactedScreenshots };
}
