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
  redactScreenshot,
  redactReportAddresses,
  screenshotRedactionRegions,
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
  assert.deepEqual(screenshotRedactionRegions('login-screen-populated.png', 1280, 720), [{
    left: 663,
    top: 259,
    width: 467,
    height: 71
  }]);
});

test('redacts the server rectangle without changing the private source', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'starfin-redaction-'));
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }));
  const sourcePath = path.join(tempDir, 'login-screen-populated.png');
  const publicPath = path.join(tempDir, 'public.png');
  const sourceSvg = Buffer.from(`
    <svg width="1920" height="1080" xmlns="http://www.w3.org/2000/svg">
      <rect width="100%" height="100%" fill="#ff0000" />
      <circle cx="300" cy="300" r="100" fill="#00ff00" />
    </svg>
  `);
  await sharp(sourceSvg).png().toFile(sourcePath);
  const privateBefore = await fs.readFile(sourcePath);

  const [rectangle] = await redactScreenshot(sourcePath, publicPath);
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

// Marker locations are independent of the redaction policy: Login's right edge,
// the moving result rows, and the native keyboard's address field.
const discoveryCases = [
  ['discovery-login.png', [[1040, 440], [1660, 480]]],
  ['discovery-results.png', [[490, 540], [1420, 540], [1660, 440]]],
  ['discovery-server-focused.png', [[490, 480], [490, 584], [490, 688], [1660, 440]]],
  ['discovery-footer-focused.png', [[490, 480], [1420, 770], [1660, 440]]],
  ['discovery-selected.png', [[1040, 440], [1660, 480]]],
  ['discovery-manual-selected.png', [[1040, 440], [1660, 480]]],
  ['discovery-manual-keyboard.png', [[310, 300], [1600, 300]]]
];

for (const [width, height] of [[1920, 1080], [1280, 720]]) {
  for (const [filename, markers] of discoveryCases) {
    test(`redacts all address locations in ${filename} at ${height}p`, async t => {
      const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'starfin-discovery-redaction-'));
      t.after(() => fs.rm(tempDir, { recursive: true, force: true }));
      const input = path.join(tempDir, filename);
      const output = path.join(tempDir, 'public.png');
      const svg = `<svg width="1920" height="1080" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#00ff00" />
        ${markers.map(([x, y]) => `<rect x="${x}" y="${y}" width="20" height="10" fill="#ff0000" />`).join('')}
      </svg>`;
      await sharp(Buffer.from(svg)).resize(width, height).png().toFile(input);
      const original = await fs.readFile(input);

      await redactScreenshot(input, output);
      const pixels = await sharp(output).removeAlpha().raw().toBuffer();

      assert.deepEqual(await fs.readFile(input), original, 'private screenshot must remain unchanged');
      assert.deepEqual([...pixels.subarray(0, 3)], [0, 255, 0], 'unrelated image area must remain visible');
      for (let i = 0; i < pixels.length; i += 3) {
        assert.ok(!(pixels[i] > 200 && pixels[i + 1] < 50 && pixels[i + 2] < 50),
          'no address marker may survive in the public image');
      }
    });
  }
}

test('matches discovery screenshot names without regard to case', () => {
  assert.equal(screenshotRedactionRegions('DISCOVERY-RESULTS.PNG', 1920, 1080).length, 2);
});

for (const [width, height] of [[1920, 1080], [1280, 720]]) {
  test(`preserves the empty discovery-searching checkpoint at ${height}p`, async t => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'starfin-searching-'));
    t.after(() => fs.rm(tempDir, { recursive: true, force: true }));
    const input = path.join(tempDir, 'discovery-searching.png');
    await sharp({ create: { width, height, channels: 3, background: '#abcdef' } }).png().toFile(input);
    const original = await fs.readFile(input);

    assert.deepEqual(await redactScreenshot(input), []);
    assert.deepEqual(await fs.readFile(input), original);
  });
}

test('requires a redaction policy for new discovery checkpoints', () => {
  assert.throws(() => screenshotRedactionRegions('discovery-new-layout.png', 1920, 1080),
    /No redaction layout/);
});

test('rejects an unclassified discovery failure screenshot', () => {
  assert.throws(() => screenshotRedactionRegions('starfin-server-discovery-cancel-failure.png', 1280, 720),
    /No redaction layout/);
});

test('does not modify unrelated screenshots', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'starfin-unredacted-'));
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }));
  const input = path.join(tempDir, 'home-page.png');
  await sharp({ create: { width: 1920, height: 1080, channels: 3, background: '#abcdef' } }).png().toFile(input);
  const original = await fs.readFile(input);

  assert.deepEqual(await redactScreenshot(input), []);
  assert.deepEqual(await fs.readFile(input), original);
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

for (const [name, input, expected] of [
  ['unconfigured discovered server', 'http://10.23.45.67:8096/base', 'http://[ip_redacted]:8096/base'],
  ['encoded HTML metadata', '&quot;address&quot;:&quot;http://192.168.1.8:8096&quot;', '&quot;address&quot;:&quot;http://[ip_redacted]:8096&quot;'],
  ['protocol-adjacent socket address', 'IPv410.23.45.67:1234', 'IPv4[ip_redacted]:1234'],
  ['exact loopback exception', 'http://127.0.0.1:1', 'http://127.0.0.1:1'],
  ['other loopback address', '127.0.0.2', '[ip_redacted]'],
  ['invalid address-like version', '999.1.2.3', '999.1.2.3']
]) {
  test(`sanitizes report text: ${name}`, () => {
    assert.equal(redactReportAddresses(input), expected);
  });
}

test('rejects discovered addresses even when no sensitive values are configured', () => {
  assert.throws(() => assertNoSensitiveText('http://10.23.45.67:8096', []), /non-exempt IPv4/);
});

test('redacts nested JSON metadata without breaking its encoding', () => {
  const input = JSON.stringify({ context: JSON.stringify({ servers: [{ address: 'http://10.23.45.67:8096' }] }) });
  const output = JSON.parse(redactReportAddresses(input));
  assert.equal(JSON.parse(output.context).servers[0].address, 'http://[ip_redacted]:8096');
});

test('creates a sanitized archive without logs and preserves private evidence', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'starfin-report-'));
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }));
  const screenshotsDir = path.join(tempDir, 'screenshots');
  await fs.mkdir(path.join(tempDir, 'logs'), { recursive: true });
  await fs.mkdir(path.join(tempDir, 'assets'), { recursive: true });
  await fs.mkdir(screenshotsDir, { recursive: true });
  const privateHtml = '<html><body>http://10.23.45.67:8096</body></html>';
  const privateJson = JSON.stringify({ ...passingReport(), context: JSON.stringify({ servers: [{ address: 'http://10.23.45.67:8096' }] }) });
  await fs.writeFile(path.join(tempDir, 'report.html'), privateHtml);
  await fs.writeFile(path.join(tempDir, 'report.json'), privateJson);
  await fs.writeFile(path.join(tempDir, 'logs', 'automation.log'), 'private log');
  const screenshotPath = path.join(screenshotsDir, 'login-screen-populated.png');
  await sharp({
    create: { width: 1920, height: 1080, channels: 3, background: '#ff0000' }
  }).png().toFile(screenshotPath);
  const privateBefore = await fs.readFile(screenshotPath);
  const discoveryPath = path.join(screenshotsDir, 'discovery-results.png');
  await fs.copyFile(screenshotPath, discoveryPath);

  const result = await createReleaseAutomationReport({
    resultsDir: tempDir,
    runId: 'test-run',
    version: '1.2.3',
    resolution: '1080p',
    deviceInfo: { modelNumber: '4630X', softwareVersion: '15.3.4' },
    sensitiveValues: buildSensitiveValues({
      rokuHost: '10.0.0.8',
      rokuPassword: 'roku-secret',
      server: 'http://10.0.0.9:8096',
      jellyfinPassword: 'jellyfin-secret'
    })
  });
  const archive = await fs.readFile(result.archivePath);

  assert.deepEqual(await fs.readFile(screenshotPath), privateBefore);
  assert.deepEqual(await fs.readFile(discoveryPath), privateBefore);
  assert.ok(result.redactedScreenshots.includes('discovery-results.png'));
  const discoveryPixel = await sharp(path.join(result.publicDir, 'screenshots', 'discovery-results.png'))
    .extract({ left: 500, top: 540, width: 1, height: 1 }).raw().toBuffer();
  assert.deepEqual([...discoveryPixel.subarray(0, 3)], [17, 24, 39]);
  assert.ok(archive.includes(Buffer.from('screenshots/discovery-results.png')));
  assert.ok(archive.length > 0);
  assert.equal(await fs.readFile(path.join(tempDir, 'report.html'), 'utf8'), privateHtml);
  assert.equal(await fs.readFile(path.join(tempDir, 'report.json'), 'utf8'), privateJson);
  assert.equal(await fs.readFile(path.join(result.publicDir, 'report.html'), 'utf8'),
    '<html><body>http://[ip_redacted]:8096</body></html>');
  const publicJson = JSON.parse(await fs.readFile(path.join(result.publicDir, 'report.json'), 'utf8'));
  assert.equal(JSON.parse(publicJson.context).servers[0].address, 'http://[ip_redacted]:8096');
  const verification = await fs.readFile(path.join(result.publicDir, 'verification.json'), 'utf8').then(JSON.parse);
  assert.equal(verification.tests, 2);
  assert.equal(verification.displayResolution, '1080p');
  assert.equal(verification.screenshotWidth, 1920);
  assert.equal(verification.screenshotHeight, 1080);
  assert.equal(verification.rokuModel, '4630X');
  assert.equal(verification.rokuOsVersion, '15.3.4');
  assert.match(path.basename(result.archivePath), /-1080p-test-run[.]zip$/);
  await assert.rejects(fs.access(path.join(result.publicDir, 'logs')));
});

test('packages report scripts, styles, and nested font assets in the ZIP', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'starfin-report-assets-'));
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }));
  await fs.mkdir(path.join(tempDir, 'screenshots'), { recursive: true });
  await fs.mkdir(path.join(tempDir, 'assets', 'fonts'), { recursive: true });
  const assets = {
    'assets/app.js': 'document.body.dataset.rendered = "true";',
    'assets/app.css': '@font-face { font-family: report; src: url("fonts/report.woff2"); }',
    'assets/fonts/report.woff2': 'font fixture'
  };
  for (const [name, contents] of Object.entries(assets)) {
    await fs.writeFile(path.join(tempDir, name), contents);
  }
  await fs.writeFile(path.join(tempDir, 'report.html'),
    '<html><head><link rel="stylesheet" href="assets/app.css"></head><body><script src="assets/app.js"></script></body></html>');
  await fs.writeFile(path.join(tempDir, 'report.json'), JSON.stringify(passingReport()));
  await sharp({ create: { width: 1280, height: 720, channels: 3, background: '#ffffff' } })
    .png().toFile(path.join(tempDir, 'screenshots', 'login-screen-empty.png'));

  const result = await createReleaseAutomationReport({
    resultsDir: tempDir, runId: 'assets', version: '1.2.3', resolution: '720p', sensitiveValues: []
  });
  const archive = await fs.readFile(result.archivePath);

  for (const [name, contents] of Object.entries(assets)) {
    assert.equal(await fs.readFile(path.join(result.publicDir, name), 'utf8'), contents);
    assert.equal(await fs.readFile(path.join(tempDir, name), 'utf8'), contents);
    assert.ok(archive.includes(Buffer.from(name)), `ZIP must include ${name}`);
  }
});

test('rejects an incomplete report whose assets directory is missing', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'starfin-report-missing-assets-'));
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }));
  await fs.mkdir(path.join(tempDir, 'screenshots'));
  await fs.writeFile(path.join(tempDir, 'report.html'), '<script src="assets/app.js"></script>');
  await fs.writeFile(path.join(tempDir, 'report.json'), JSON.stringify(passingReport()));

  await assert.rejects(createReleaseAutomationReport({
    resultsDir: tempDir, runId: 'missing-assets', version: '1.2.3', sensitiveValues: []
  }), { code: 'ENOENT' });
  await assert.rejects(fs.access(path.join(tempDir, 'starfin-automation-report-v1.2.3-missing-assets.zip')));
});

test('does not produce an archive containing an unknown discovery layout', async t => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'starfin-report-unknown-discovery-'));
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }));
  await fs.mkdir(path.join(tempDir, 'screenshots'));
  await fs.mkdir(path.join(tempDir, 'assets'));
  await fs.writeFile(path.join(tempDir, 'report.html'), '<html>passing</html>');
  await fs.writeFile(path.join(tempDir, 'report.json'), JSON.stringify(passingReport()));
  const image = await sharp({ create: { width: 1280, height: 720, channels: 3, background: '#ffffff' } }).png().toBuffer();
  await fs.writeFile(path.join(tempDir, 'screenshots', 'login-screen-empty.png'), image);
  await fs.writeFile(path.join(tempDir, 'screenshots', 'discovery-new-layout.png'), image);

  await assert.rejects(createReleaseAutomationReport({
    resultsDir: tempDir, runId: 'unknown', version: '1.2.3', sensitiveValues: []
  }), /No redaction layout/);
  await assert.rejects(fs.access(path.join(tempDir, 'starfin-automation-report-v1.2.3-unknown.zip')));
});
