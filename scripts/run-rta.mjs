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
const grepArgumentIndex = process.argv.indexOf('--grep');
const automationTestGrep = grepArgumentIndex >= 0 ? process.argv[grepArgumentIndex + 1]?.trim() : '';
if (grepArgumentIndex >= 0 && !automationTestGrep) throw new Error('--grep requires a test-title pattern.');
if (releaseReportEnabled && automationTestGrep) throw new Error('Release reports must run the complete automation suite.');

function readConfig() {
  const result = dotenv.config({ path: environmentPath, quiet: true });
  if (result.error) {
    throw new Error('Missing tests/automation/.env.automation. Copy .env.automation.example and add the local test environment values.');
  }

  const host = process.env.ROKU_HOST?.trim();
  const password = process.env.ROKU_DEV_PASSWORD;
  const server = process.env.JELLYFIN_SERVER_URL?.trim();
  const username = process.env.JELLYFIN_USERNAME?.trim();
  const jellyfinPassword = process.env.JELLYFIN_PASSWORD;
  const searchCasesText = process.env.SEARCH_CASES?.trim();
  const letterGridSearchLibrary = process.env.LETTERGRID_SEARCH_LIBRARY?.trim();
  const letterGridCasesText = process.env.LETTERGRID_CASES?.trim();
  const tvSeriesLibrary = process.env.TVSERIES_LIBRARY?.trim();
  const tvSeriesSmokeTestText = process.env.TVSERIES_SMOKE_TEST?.trim();
  if (!host || !password) {
    throw new Error('tests/automation/.env.automation must define ROKU_HOST and ROKU_DEV_PASSWORD.');
  }
  if (!server || !username || !jellyfinPassword) {
    throw new Error('tests/automation/.env.automation must define JELLYFIN_SERVER_URL, JELLYFIN_USERNAME, and JELLYFIN_PASSWORD.');
  }
  if (!letterGridSearchLibrary) {
    throw new Error('tests/automation/.env.automation must define LETTERGRID_SEARCH_LIBRARY.');
  }
  if (!tvSeriesLibrary) {
    throw new Error('tests/automation/.env.automation must define TVSERIES_LIBRARY.');
  }

  let letterGridCases;
  try {
    letterGridCases = JSON.parse(letterGridCasesText ?? '');
  } catch {
    throw new Error('LETTERGRID_CASES must be a valid JSON array.');
  }
  if (
    !Array.isArray(letterGridCases)
    || letterGridCases.length === 0
    || letterGridCases.some(letter => typeof letter !== 'string' || !/^[A-Z]$/i.test(letter.trim()))
  ) {
    throw new Error('LETTERGRID_CASES must contain at least one single letter.');
  }
  letterGridCases = letterGridCases.map(letter => letter.trim().toUpperCase());

  let tvSeriesSmokeTest;
  try {
    tvSeriesSmokeTest = JSON.parse(tvSeriesSmokeTestText ?? '');
  } catch {
    throw new Error('TVSERIES_SMOKE_TEST must be valid JSON.');
  }
  if (!tvSeriesSmokeTest || typeof tvSeriesSmokeTest !== 'object' || Array.isArray(tvSeriesSmokeTest)) {
    throw new Error('TVSERIES_SMOKE_TEST must be a JSON object.');
  }
  const seriesName = typeof tvSeriesSmokeTest.seriesName === 'string'
    ? tvSeriesSmokeTest.seriesName.trim()
    : '';
  const seasons = tvSeriesSmokeTest.seasons;
  if (!seriesName) {
    throw new Error('TVSERIES_SMOKE_TEST seriesName must be a non-empty string.');
  }
  if (
    !Array.isArray(seasons)
    || seasons.length === 0
    || seasons.some(season => !season
      || typeof season !== 'object'
      || Array.isArray(season)
      || !Number.isInteger(season.season)
      || season.season < 0
      || !Number.isInteger(season.year)
      || season.year < 1
      || !Number.isInteger(season.episodeCount)
      || season.episodeCount < 0)
  ) {
    throw new Error('TVSERIES_SMOKE_TEST seasons must contain season, year, and episodeCount integers.');
  }
  const season1 = tvSeriesSmokeTest.season1;
  if (
    !Array.isArray(season1)
    || season1.length === 0
    || season1.some(episode => !episode
      || typeof episode !== 'object'
      || Array.isArray(episode)
      || !Number.isInteger(episode.number)
      || episode.number < 1
      || typeof episode.title !== 'string'
      || episode.title.trim() === ''
      || typeof episode.date !== 'string'
      || !/^\d{4}-\d{2}-\d{2}$/.test(episode.date))
  ) {
    throw new Error('TVSERIES_SMOKE_TEST season1 must contain number, title, and YYYY-MM-DD date values.');
  }
  const testEpisode = tvSeriesSmokeTest.testEpisode;
  if (
    !testEpisode
    || typeof testEpisode !== 'object'
    || Array.isArray(testEpisode)
    || !Number.isInteger(testEpisode.season)
    || testEpisode.season < 0
    || !Number.isInteger(testEpisode.episode)
    || testEpisode.episode < 1
  ) {
    throw new Error('TVSERIES_SMOKE_TEST testEpisode must contain valid season and episode integers.');
  }
  tvSeriesSmokeTest = {
    seriesName,
    seasons,
    season1: season1.map(episode => ({ ...episode, title: episode.title.trim() })),
    testEpisode
  };

  let searchCases;
  try {
    searchCases = JSON.parse(searchCasesText ?? '');
  } catch {
    throw new Error('SEARCH_CASES must be a valid JSON array.');
  }
  if (!Array.isArray(searchCases) || searchCases.length === 0) {
    throw new Error('SEARCH_CASES must contain at least one search case.');
  }

  const sectionNames = ['moviesAndSeries', 'episodes', 'people'];
  searchCases = searchCases.map((searchCase, caseIndex) => {
    if (!searchCase || typeof searchCase !== 'object' || Array.isArray(searchCase)) {
      throw new Error(`SEARCH_CASES case ${caseIndex + 1} must be an object.`);
    }

    const query = typeof searchCase.query === 'string' ? searchCase.query.trim() : '';
    if (query.length < 3) {
      throw new Error(`SEARCH_CASES case ${caseIndex + 1} must have a query of at least three characters.`);
    }

    const normalizedCase = { query };
    let expectedCount = 0;
    for (const sectionName of sectionNames) {
      const values = searchCase[sectionName] ?? [];
      if (!Array.isArray(values) || values.some(value => typeof value !== 'string' || value.trim() === '')) {
        throw new Error(`SEARCH_CASES case ${caseIndex + 1} ${sectionName} must be an array of non-empty strings.`);
      }
      normalizedCase[sectionName] = values.map(value => value.trim());
      expectedCount += values.length;
    }
    if (expectedCount === 0) {
      throw new Error(`SEARCH_CASES case ${caseIndex + 1} must include at least one expected result.`);
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
    letterGridCases,
    letterGridSearchLibrary,
    searchCases,
    selectedDevice,
    testAccount: { server, username, password: jellyfinPassword },
    tvSeriesLibrary,
    tvSeriesSmokeTest
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
  const {
    config,
    letterGridCases,
    letterGridSearchLibrary,
    searchCases,
    selectedDevice,
    testAccount,
    tvSeriesLibrary,
    tvSeriesSmokeTest
  } = readConfig();
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
    const mochaArguments = [
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
    ];
    if (automationTestGrep) mochaArguments.push('--grep', automationTestGrep);

    await run(process.execPath, mochaArguments, {
      env: {
        ...process.env,
        STARFIN_AUTOMATION_CONFIG: JSON.stringify(config),
        STARFIN_AUTOMATION_ACCOUNT: JSON.stringify(testAccount),
        STARFIN_AUTOMATION_LETTERGRID_CASES: JSON.stringify(letterGridCases),
        STARFIN_AUTOMATION_LETTERGRID_SEARCH_LIBRARY: letterGridSearchLibrary,
        STARFIN_AUTOMATION_SEARCH_CASES: JSON.stringify(searchCases),
        STARFIN_AUTOMATION_TVSERIES_LIBRARY: tvSeriesLibrary,
        STARFIN_AUTOMATION_TVSERIES_SMOKE_TEST: JSON.stringify(tvSeriesSmokeTest),
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
