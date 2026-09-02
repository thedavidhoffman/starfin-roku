import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import sharp from 'sharp';
import {
  assertNoSensitiveText,
  buildSensitiveValues,
  createReleaseAutomationReport,
  redactLoginScreenshot,
  scaleLoginServerField,
  shouldRedactLoginScreenshot,
  validateAutomationReport
} from '../../../scripts/automation-report.mjs';

function passingReport(overrides = {}) {
  return {
    stats: {
      tests: 2,
      passes: 2,
      failures: 0,
      pending: 0,
      skipped: 0,
      other: 0,
      end: '2026-09-02T18:00:00.000Z',
      ...overrides
    }
  };
}

test('accepts a complete passing automation report', () => {
  assert.deepEqual(validateAutomationReport(passingReport()), {
    tests: 2,
    passes: 2,
    completedAt: '2026-09-02T18:00:00.000Z'
  });
});

for (const [name, stats] of [
  ['empty', { tests: 0, passes: 0 }],
  ['failed', { failures: 1, passes: 1 }],
  ['pending', { pending: 1, passes: 1 }],
  ['skipped', { skipped: 1, passes: 1 }],
  ['unexpected', { other: 1, passes: 1 }],
  ['mismatched', { passes: 1 }]
]) {
  test(`rejects a ${name} automation report`, () => {
    assert.throws(() => validateAutomationReport(passingReport(stats)));
  });
}

test('selects normal and failure Login screenshots for redaction', () => {
  assert.equal(shouldRedactLoginScreenshot('login-screen-populated.png'), true);
  assert.equal(
    shouldRedactLoginScreenshot('starfin-authenticated-smoke-test-login-flow-failure.png'),
    true
  );
  assert.equal(shouldRedactLoginScreenshot('home-page.png'), false);
});

test('scales the Login server field for HD screenshots', () => {
  assert.deepEqual(scaleLoginServerField(1280, 720), {
    left: 663,
    top: 259,
    width: 467,
    height: 70
  });
});

test('redacts the server rectangle without changing the private source', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'starfin-redaction-'));
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }));
  const sourcePath = path.join(tempDir, 'private.png');
  const publicPath = path.join(tempDir, 'public.png');
  const sourceSvg = Buffer.from(`
    <svg width="1920" height="1080" xmlns="http://www.w3.org/2000/svg">
      <rect width="100%" height="100%" fill="#ff0000" />
      <circle cx="300" cy="300" r="100" fill="#00ff00" />
    </svg>
  `);
  await sharp(sourceSvg).png().toFile(sourcePath);
  const privateBefore = await fs.readFile(sourcePath);

  const rectangle = await redactLoginScreenshot(sourcePath, publicPath);
  const privateAfter = await fs.readFile(sourcePath);
  const pixel = await sharp(publicPath)
    .extract({ left: rectangle.left + 1, top: rectangle.top + 1, width: 1, height: 1 })
    .raw()
    .toBuffer();
  const preservedPixel = await sharp(publicPath)
    .extract({ left: 300, top: 300, width: 1, height: 1 })
    .removeAlpha()
    .raw()
    .toBuffer();

  assert.deepEqual(privateAfter, privateBefore);
  assert.deepEqual([...pixel.subarray(0, 3)], [17, 24, 39]);
  assert.deepEqual([...preservedPixel.subarray(0, 3)], [0, 255, 0]);
});

test('detects configured hosts and passwords but permits fixed loopback data', () => {
  const sensitive = buildSensitiveValues({
    rokuHost: '10.0.0.8',
    rokuPassword: 'roku-secret',
    server: 'http://10.0.0.9:8096',
    jellyfinPassword: 'jellyfin-secret'
  });
  assert.doesNotThrow(() => assertNoSensitiveText('Failed to connect to 127.0.0.1:1', sensitive));
  for (const value of ['10.0.0.8', 'roku-secret', 'http://10.0.0.9:8096', '10.0.0.9', 'jellyfin-secret']) {
    assert.throws(() => assertNoSensitiveText(`prefix ${value} suffix`, sensitive));
  }
});

test('does not treat a password embedded in an unrelated word as a credential leak', () => {
  const sensitive = buildSensitiveValues({ rokuPassword: 'pass' });

  assert.doesNotThrow(() => assertNoSensitiveText(
    '{"pass":true} &quot;pass&quot;:true \\&quot;pass\\&quot;:false 38 passes and password masking passed',
    sensitive
  ));
  assert.throws(() => assertNoSensitiveText('credential="pass"', sensitive));
});

test('creates a sanitized archive without logs and preserves private evidence', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'starfin-report-'));
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }));
  const screenshotsDir = path.join(tempDir, 'screenshots');
  await fs.mkdir(path.join(tempDir, 'logs'), { recursive: true });
  await fs.mkdir(screenshotsDir, { recursive: true });
  await fs.writeFile(path.join(tempDir, 'report.html'), '<html><body>passing</body></html>');
  await fs.writeFile(path.join(tempDir, 'report.json'), JSON.stringify(passingReport()));
  await fs.writeFile(path.join(tempDir, 'logs', 'automation.log'), 'private log');
  const screenshotPath = path.join(screenshotsDir, 'login-screen-populated.png');
  await sharp({
    create: { width: 1920, height: 1080, channels: 3, background: '#ff0000' }
  }).png().toFile(screenshotPath);
  const privateBefore = await fs.readFile(screenshotPath);

  const result = await createReleaseAutomationReport({
    resultsDir: tempDir,
    runId: 'test-run',
    version: '1.2.3',
    sensitiveValues: buildSensitiveValues({
      rokuHost: '10.0.0.8',
      rokuPassword: 'roku-secret',
      server: 'http://10.0.0.9:8096',
      jellyfinPassword: 'jellyfin-secret'
    })
  });
  const archive = await fs.readFile(result.archivePath);

  assert.deepEqual(await fs.readFile(screenshotPath), privateBefore);
  assert.ok(archive.length > 0);
  assert.equal(await fs.readFile(path.join(result.publicDir, 'verification.json'), 'utf8').then(JSON.parse).then(value => value.tests), 2);
  await assert.rejects(fs.access(path.join(result.publicDir, 'logs')));
});
