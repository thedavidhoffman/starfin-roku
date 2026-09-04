import { getAutomationEnvironment } from './environment.mjs';

export async function waitFor(check, description, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  let lastError;

  while (Date.now() < deadline) {
    try {
      const result = await check();
      if (result) return result;
    } catch (error) {
      lastError = error;
    }
    await new Promise(resolve => setTimeout(resolve, 250));
  }

  const detail = lastError ? ` Last error: ${lastError.message}` : '';
  throw new Error(`Timed out waiting for ${description}.${detail}`);
}

export async function launchStarfin(environment) {
  await environment.ecp.sendLaunchChannel({
    channelId: 'dev',
    verifyLaunch: true,
    verifyLaunchTimeOut: 15000
  });

  return waitFor(async () => {
    const response = await environment.ecp.getActiveApp();
    return response.app?.id === 'dev' ? response.app : undefined;
  }, 'the sideloaded Starfin channel to become active');
}

export async function waitForMainScene(environment) {
  return waitFor(async () => {
    const response = await environment.odc.getValue(
      { base: 'scene', keyPath: 'subtype()' },
      { timeout: 3000 }
    );
    return response.found && response.value === 'MainScene' ? response.value : undefined;
  }, 'the Starfin MainScene to become available');
}

export async function relaunchStarfin(environment) {
  await environment.ecp.sendKeypress(environment.ecp.Key.Home);
  await waitFor(async () => {
    const response = await environment.ecp.getActiveApp();
    return response.app?.id !== 'dev';
  }, 'Starfin to exit before relaunch');

  await launchStarfin(environment);
  await waitForMainScene(environment);
}

export async function resetRegistryAndRelaunch() {
  const environment = await getAutomationEnvironment();

  await launchStarfin(environment);
  await waitForMainScene(environment);

  console.log('Resetting Starfin dev-channel registry for deterministic automation.');
  await environment.odc.deleteEntireRegistry();
  const registry = await environment.odc.readRegistry();
  const remainingSections = Object.keys(registry.values ?? {})
    .filter(section => section !== 'rokuTestAutomation');
  if (remainingSections.length !== 0) {
    throw new Error(`Starfin registry sections remained after the automation reset: ${remainingSections.join(', ')}.`);
  }

  await environment.ecp.sendKeypress(environment.ecp.Key.Home);
  await waitFor(async () => {
    const response = await environment.ecp.getActiveApp();
    return response.app?.id !== 'dev';
  }, 'Starfin to exit after the registry reset');

  await launchStarfin(environment);
  await waitForMainScene(environment);
  await waitFor(async () => {
    const response = await environment.odc.getValue({ base: 'scene', keyPath: '#login.visible' });
    return response.found && response.value === true;
  }, 'the clean Starfin login screen');
}
