import { getAutomationEnvironment } from './environment.mjs';
import { relaunchStarfin, waitFor } from './lifecycle.mjs';

async function getAuthenticationSurface(environment) {
  return environment.odc.getValues({
    requests: {
      home: { base: 'scene', keyPath: '#homePage.visible' },
      login: { base: 'scene', keyPath: '#login.visible' }
    }
  });
}

export async function ensureAuthenticated() {
  const environment = await getAutomationEnvironment();
  const surface = await getAuthenticationSurface(environment);
  if (surface.results.home?.value === true) return environment;

  if (surface.results.login?.value === true) {
    await environment.odc.setValue({
      base: 'scene',
      keyPath: '#login.serverValue',
      value: environment.testAccount.server
    });
    await environment.odc.setValue({
      base: 'scene',
      keyPath: '#login.usernameValue',
      value: environment.testAccount.username
    });
    await environment.odc.setValue({
      base: 'scene',
      keyPath: '#login.passwordValue',
      value: environment.testAccount.password
    });
    await environment.odc.callFunc({
      base: 'scene',
      keyPath: '#login',
      funcName: 'focusLoginButton'
    });
    await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
  }

  await waitFor(async () => {
    const values = await getAuthenticationSurface(environment);
    return values.results.home?.value === true && values.results.login?.value === false;
  }, 'an authenticated Home surface', 45000);

  return environment;
}

export async function relaunchAuthenticatedStarfin() {
  const environment = await getAutomationEnvironment();

  await relaunchStarfin(environment);
  return ensureAuthenticated();
}
