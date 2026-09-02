import fs from 'node:fs/promises';
import { createWriteStream } from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import dotenv from 'dotenv';
import rokuDeploy from 'roku-deploy';
import {
  buildSensitiveValues,
  createReleaseAutomationReport
} from './automation-report.mjs';

const rootDir = process.cwd();
const environmentPath = path.join(rootDir, 'tests', 'automation', '.env.automation');
const packagePath = path.join(rootDir, 'out', 'starfin-roku-automation.zip');
const runId = new Date().toISOString().replaceAll(':', '-').replaceAll('.', '-');
const resultsDir = path.join(rootDir, 'out', 'automation-results', runId);
const releaseReportEnabled = process.argv.includes('--release-report');

function readConfig() {
  const result = dotenv.config({ path: environmentPath, quiet: true });
  if (result.error) {
    throw new Error('Missing tests/automation/.env.automation. Copy .env.example and add the local test environment values.');
  }

  const host = process.env.ROKU_HOST?.trim();
  const password = process.env.ROKU_DEV_PASSWORD;
  const server = process.env.JELLYFIN_SERVER_URL?.trim();
  const username = process.env.JELLYFIN_USERNAME?.trim();
  const jellyfinPassword = process.env.JELLYFIN_PASSWORD;
  const searchCasesText = process.env.JELLYFIN_SEARCH_CASES?.trim();
  if (!host || !password) {
    throw new Error('tests/automation/.env.automation must define ROKU_HOST and ROKU_DEV_PASSWORD.');
  }
  if (!server || !username || !jellyfinPassword) {
    throw new Error('tests/automation/.env.automation must define JELLYFIN_SERVER_URL, JELLYFIN_USERNAME, and JELLYFIN_PASSWORD.');
  }

  let searchCases;
  try {
    searchCases = JSON.parse(searchCasesText ?? '');
  } catch {
    throw new Error('JELLYFIN_SEARCH_CASES must be a valid JSON array.');
  }
  if (!Array.isArray(searchCases) || searchCases.length === 0) {
    throw new Error('JELLYFIN_SEARCH_CASES must contain at least one search case.');
  }

  const sectionNames = ['moviesAndSeries', 'episodes', 'people'];
  searchCases = searchCases.map((searchCase, caseIndex) => {
    if (!searchCase || typeof searchCase !== 'object' || Array.isArray(searchCase)) {
      throw new Error(`JELLYFIN_SEARCH_CASES case ${caseIndex + 1} must be an object.`);
    }

    const query = typeof searchCase.query === 'string' ? searchCase.query.trim() : '';
    if (query.length < 3) {
      throw new Error(`JELLYFIN_SEARCH_CASES case ${caseIndex + 1} must have a query of at least three characters.`);
    }

    const normalizedCase = { query };
    let expectedCount = 0;
    for (const sectionName of sectionNames) {
      const values = searchCase[sectionName] ?? [];
      if (!Array.isArray(values) || values.some(value => typeof value !== 'string' || value.trim() === '')) {
        throw new Error(`JELLYFIN_SEARCH_CASES case ${caseIndex + 1} ${sectionName} must be an array of non-empty strings.`);
      }
      normalizedCase[sectionName] = values.map(value => value.trim());
      expectedCount += values.length;
    }
    if (expectedCount === 0) {
      throw new Error(`JELLYFIN_SEARCH_CASES case ${caseIndex + 1} must include at least one expected result.`);
    }

    return normalizedCase;
  });

  const selectedDevice = {
    host,
    password,
    defaultTimeout: 15000,
    screenshotFormat: 'jpg'
  };
  const config = {
    RokuDevice: { devices: [selectedDevice] },
    ECP: { default: { launchChannelId: 'dev' } },
    OnDeviceComponent: {
      logLevel: 'info',
      defaultBase: 'scene',
      restoreRegistry: false,
      disableTelnet: true,
      uiResolution: 'fhd'
    }
  };
  return {
    config,
    searchCases,
    selectedDevice,
    testAccount: { server, username, password: jellyfinPassword }
  };
}

function run(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const { logPath, ...spawnOptions } = options;
    const log = logPath ? createWriteStream(logPath, { flags: 'a' }) : undefined;
    const child = spawn(command, args, {
      cwd: rootDir,
      stdio: log ? ['inherit', 'pipe', 'pipe'] : 'inherit',
      shell: false,
      ...spawnOptions
    });

    if (log) {
      child.stdout.on('data', chunk => {
        process.stdout.write(chunk);
        log.write(chunk);
      });
      child.stderr.on('data', chunk => {
        process.stderr.write(chunk);
        log.write(chunk);
      });
    }

    child.once('error', error => {
      log?.end();
      reject(error);
    });
    child.once('exit', code => {
      log?.end();
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`${command} exited with code ${code ?? 'unknown'}.`));
      }
    });
  });
}

async function addScreenshotLinksToReport(reportPath) {
  const script = `<script>
window.addEventListener('load', () => setTimeout(() => {
  const pattern = /^screenshots\/[a-z0-9-]+\.png$/;
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  const matches = [];
  while (walker.nextNode()) {
    if (pattern.test(walker.currentNode.textContent.trim())) matches.push(walker.currentNode);
  }
  for (const textNode of matches) {
    const href = textNode.textContent.trim();
    const link = document.createElement('a');
    link.href = href;
    link.target = '_blank';
    link.rel = 'noopener';
    link.textContent = href;
    textNode.replaceWith(link);
  }
}, 0));
</script>`;
  const html = await fs.readFile(reportPath, 'utf8');
  await fs.writeFile(reportPath, html.replace('</body>', `${script}</body>`));
}

try {
  const { config, searchCases, selectedDevice, testAccount } = readConfig();
  await fs.mkdir(resultsDir, { recursive: true });

  console.log('Building the automation-only Starfin package...');
  await run(process.execPath, [
    path.join(rootDir, 'node_modules', 'brighterscript', 'dist', 'cli.js'),
    '--project',
    'bsconfig-automation.json'
  ]);

  console.log(`Deploying the automation package to ${selectedDevice.host}...`);
  await rokuDeploy.publish({
    host: selectedDevice.host,
    password: selectedDevice.password,
    outDir: path.dirname(packagePath),
    outFile: path.basename(packagePath)
  });

  console.log(`Running RTA smoke tests. Results: ${path.relative(rootDir, resultsDir)}`);
  const logsDir = path.join(resultsDir, 'logs');
  await fs.mkdir(logsDir, { recursive: true });
  let testError;
  try {
    await run(process.execPath, [
      path.join(rootDir, 'node_modules', 'mocha', 'bin', 'mocha.js'),
      'tests/automation/specs/**/*.spec.mjs',
      '--require',
      './tests/automation/support/hooks.mjs',
      '--timeout',
      '90000',
      '--sort',
      '--reporter',
      'mochawesome',
      '--reporter-options',
      `reportDir=${resultsDir},reportFilename=report,saveHtml=true,saveJson=true,overwrite=false,quiet=true`
    ], {
      env: {
        ...process.env,
        STARFIN_AUTOMATION_CONFIG: JSON.stringify(config),
        STARFIN_AUTOMATION_ACCOUNT: JSON.stringify(testAccount),
        STARFIN_AUTOMATION_SEARCH_CASES: JSON.stringify(searchCases),
        STARFIN_AUTOMATION_RESULTS: resultsDir
      },
      logPath: path.join(logsDir, 'automation.log')
    });
  } catch (error) {
    testError = error;
  }

  const reportPath = path.join(resultsDir, 'report.html');
  await addScreenshotLinksToReport(reportPath);
  if (testError) throw testError;

  console.log(`Automation report: ${reportPath}`);
  if (releaseReportEnabled) {
    const releaseReport = await createReleaseAutomationReport({
      resultsDir,
      runId,
      version: (await fs.readFile(path.join(rootDir, 'manifest'), 'utf8'))
        .match(/^major_version=(\d+)$[\s\S]*^minor_version=(\d+)$[\s\S]*^build_version=(\d+)$/m)
        ?.slice(1)
        .join('.') ?? 'unknown',
      sensitiveValues: buildSensitiveValues({
        rokuHost: selectedDevice.host,
        rokuPassword: selectedDevice.password,
        server: testAccount.server,
        jellyfinPassword: testAccount.password
      })
    });
    console.log(`Credential-safe release report: ${releaseReport.archivePath}`);
  }
} catch (error) {
  console.error(`Automation run failed: ${error.message}`);
  process.exitCode = 1;
}
