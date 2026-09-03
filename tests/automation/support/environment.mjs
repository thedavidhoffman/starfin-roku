import fs from 'node:fs/promises';
import path from 'node:path';
import rta from 'roku-test-automation';
import { EcpClient } from '@danecodes/roku-ecp';

const { device, ecp, odc, utils } = rta;

let environment;

export async function getAutomationEnvironment() {
  if (environment) return environment;

  const configText = process.env.STARFIN_AUTOMATION_CONFIG;
  const resultsDir = process.env.STARFIN_AUTOMATION_RESULTS;
  if (!configText || !resultsDir) {
    throw new Error('Run automation through npm run automation:test so configuration and result paths are initialized.');
  }

  const config = JSON.parse(configText);
  const testAccount = JSON.parse(process.env.STARFIN_AUTOMATION_ACCOUNT ?? '{}');
  const searchCases = JSON.parse(process.env.STARFIN_AUTOMATION_SEARCH_CASES ?? '[]');
  const letterGridCases = JSON.parse(process.env.STARFIN_AUTOMATION_LETTERGRID_CASES ?? '[]');
  const letterGridSearchLibrary = process.env.STARFIN_AUTOMATION_LETTERGRID_SEARCH_LIBRARY ?? '';
  const tvSeriesLibrary = process.env.STARFIN_AUTOMATION_TVSERIES_LIBRARY ?? '';
  const tvSeriesSmokeTest = JSON.parse(process.env.STARFIN_AUTOMATION_TVSERIES_SMOKE_TEST ?? '{}');
  if (!testAccount.server || !testAccount.username || !testAccount.password) {
    throw new Error('Automation login credentials were not provided by the runner.');
  }
  utils.setupEnvironmentFromConfig(config);
  const selectedDevice = device.getCurrentDeviceConfig();
  const screenshotClient = new EcpClient(selectedDevice.host, {
    devPassword: selectedDevice.password,
    timeout: selectedDevice.defaultTimeout ?? 15000
  });
  const manifest = await fs.readFile(path.resolve('manifest'), 'utf8');
  const version = ['major_version', 'minor_version', 'build_version']
    .map(key => manifest.match(new RegExp(`^${key}=(\\d+)$`, 'm'))?.[1] ?? 'unknown')
    .join('.');

  environment = {
    config,
    device,
    ecp,
    letterGridCases,
    letterGridSearchLibrary,
    odc,
    resultsDir,
    screenshotClient,
    searchCases,
    selectedDevice,
    testAccount,
    tvSeriesLibrary,
    tvSeriesSmokeTest,
    version
  };
  return environment;
}

export async function closeAutomationEnvironment() {
  if (!environment) return;
  await environment.odc.shutdown();
  environment = undefined;
}
