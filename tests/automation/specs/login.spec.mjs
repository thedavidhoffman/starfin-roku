import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { addEvidenceMetadata, captureEvidence } from '../support/evidence.mjs';
import { getAutomationEnvironment } from '../support/environment.mjs';
import { waitFor } from '../support/lifecycle.mjs';

const coreHomeTaskIds = [
  'librariesTask',
  'continueWatchingTask',
  'continueListeningTask',
  'nextUpTask',
  'liveTvOnNowTask'
];

const requiredCredentialsMessage = 'Server address, username, and password are all required.';
const unreachableServer = '127.0.0.1:1';
const unreachableServerMessage = /^Login failed: Failed to connect to 127\.0\.0\.1 port 1 after \d+ ms: Could not connect to server$/;
const invalidCredentialsMessage = 'Login failed: Not authorized';

function isTaskComplete(state) {
  return ['done', 'stop'].includes(String(state ?? '').toLowerCase());
}

async function setLoginCredentials(environment, { server, username, password }) {
  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#login.serverValue',
    value: server
  });
  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#login.usernameValue',
    value: username
  });
  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#login.passwordValue',
    value: password
  });
}

async function submitLogin(environment) {
  await environment.odc.callFunc({
    base: 'scene',
    keyPath: '#login',
    funcName: 'focusLoginButton'
  });
  await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
}

async function getLoginState(environment) {
  return environment.odc.getValues({
    requests: {
      status: { base: 'scene', keyPath: '#loginStatus.text' },
      loginVisible: { base: 'scene', keyPath: '#login.visible' },
      homeVisible: { base: 'scene', keyPath: '#homePage.visible' }
    }
  });
}

async function assertFailedLoginState(environment, expectedStatus) {
  const values = await getLoginState(environment);
  const status = values.results.status?.value;

  if (expectedStatus instanceof RegExp) {
    assert.match(status ?? '', expectedStatus);
  } else {
    assert.equal(status, expectedStatus);
  }
  assert.equal(values.results.loginVisible?.value, true, 'Login should remain visible after a failed attempt.');
  assert.equal(values.results.homeVisible?.value, false, 'Home should remain hidden after a failed attempt.');
}

async function waitForHomeReady(environment) {
  let stableFingerprint;
  let stableSince = 0;

  return waitFor(async () => {
    const requests = {
      home: { base: 'scene', keyPath: '#homePage.visible' },
      login: { base: 'scene', keyPath: '#login.visible' },
      shelves: { base: 'scene', keyPath: '#shelvesGroup.getChildCount()' },
      spinner: { base: 'scene', keyPath: '#loadingSpinner.visible' },
      statusVisible: { base: 'scene', keyPath: '#statusLabel.visible' },
      statusText: { base: 'scene', keyPath: '#statusLabel.text' }
    };
    for (const taskId of coreHomeTaskIds) {
      requests[taskId] = { base: 'scene', keyPath: `#${taskId}.state` };
    }
    const values = await environment.odc.getValues({ requests });
    if (values.results.home?.value !== true || values.results.login?.value !== false) return false;

    if (coreHomeTaskIds.some(taskId => !isTaskComplete(values.results[taskId]?.value))) return false;

    if (values.results.statusVisible?.value === true) {
      throw new Error(`Home reported an initial-load error: ${values.results.statusText?.value ?? 'Unknown error'}`);
    }
    const shelfCount = values.results.shelves?.value ?? 0;
    if (values.results.spinner?.value !== false || shelfCount < 1) return false;

    const shelfRequests = {};
    for (let index = 0; index < shelfCount; index += 1) {
      shelfRequests[index] = {
        base: 'scene',
        keyPath: `#shelvesGroup.${index}.rowContent.getChildCount()`
      };
    }
    const shelfValues = await environment.odc.getValues({ requests: shelfRequests });
    const fingerprint = Array.from(
      { length: shelfCount },
      (_, index) => shelfValues.results[index]?.value ?? 0
    ).join(',');
    if (fingerprint !== stableFingerprint) {
      stableFingerprint = fingerprint;
      stableSince = Date.now();
      return false;
    }

    return Date.now() - stableSince >= 2000;
  }, 'Home initial API requests and rendered shelves', 45000);
}

describe('Starfin authenticated smoke test', function () {
  it('validates login attempts, then signs in and reaches Home', async function () {
    const environment = await getAutomationEnvironment();
    const activeApp = await environment.ecp.getActiveApp();
    const deviceInfo = await environment.screenshotClient.queryDeviceInfo();
    const emptyLoginScreenshot = await captureEvidence(this, 'login-screen-empty');

    await submitLogin(environment);
    await assertFailedLoginState(environment, requiredCredentialsMessage);
    const emptyValidationScreenshot = await captureEvidence(this, 'login-validation-empty');

    await setLoginCredentials(environment, {
      server: unreachableServer,
      username: 'automation-user',
      password: 'automation-password'
    });
    await submitLogin(environment);
    await waitFor(async () => {
      const values = await getLoginState(environment);
      const status = values.results.status?.value ?? '';
      return unreachableServerMessage.test(status) ? status : false;
    }, 'the unreachable-server login failure', 20000);
    await assertFailedLoginState(environment, unreachableServerMessage);
    const unreachableServerScreenshot = await captureEvidence(this, 'login-validation-unreachable-server');

    await setLoginCredentials(environment, {
      server: environment.testAccount.server,
      username: '',
      password: ''
    });
    await submitLogin(environment);
    await assertFailedLoginState(environment, requiredCredentialsMessage);
    const missingUsernameScreenshot = await captureEvidence(this, 'login-validation-missing-username');

    await setLoginCredentials(environment, {
      server: environment.testAccount.server,
      username: environment.testAccount.username,
      password: ''
    });
    await submitLogin(environment);
    await assertFailedLoginState(environment, requiredCredentialsMessage);
    const missingPasswordScreenshot = await captureEvidence(this, 'login-validation-missing-password');

    await setLoginCredentials(environment, {
      server: environment.testAccount.server,
      username: environment.testAccount.username,
      password: 'starfin-automation-invalid-password'
    });
    await submitLogin(environment);
    await waitFor(async () => {
      const values = await getLoginState(environment);
      return values.results.status?.value === invalidCredentialsMessage;
    }, 'the invalid-credentials login failure', 20000);
    await assertFailedLoginState(environment, invalidCredentialsMessage);
    const invalidCredentialsScreenshot = await captureEvidence(this, 'login-validation-invalid-credentials');

    await setLoginCredentials(environment, environment.testAccount);

    const populatedValues = await environment.odc.getValues({
      requests: {
        server: { base: 'scene', keyPath: '#login.serverValue' },
        username: { base: 'scene', keyPath: '#login.usernameValue' },
        passwordDisplay: { base: 'scene', keyPath: '#passwordInput.text' }
      }
    });
    assert.equal(populatedValues.results.server?.value, environment.testAccount.server);
    assert.equal(populatedValues.results.username?.value, environment.testAccount.username);
    assert.equal(
      populatedValues.results.passwordDisplay?.value,
      '*'.repeat(environment.testAccount.password.length),
      'The populated password must be masked on screen.'
    );
    const populatedLoginScreenshot = await captureEvidence(this, 'login-screen-populated');

    await submitLogin(environment);

    await waitForHomeReady(environment);
    await new Promise(resolve => setTimeout(resolve, 400));

    const homeScreenshot = await captureEvidence(this, 'home-page');

    addEvidenceMetadata(this, {
      activeChannelId: activeApp.app?.id,
      checkpoints: [
        'login-screen-empty',
        'login-validation-empty',
        'login-validation-unreachable-server',
        'login-validation-missing-username',
        'login-validation-missing-password',
        'login-validation-invalid-credentials',
        'login-screen-populated',
        'home-page'
      ],
      capturedAt: new Date().toISOString(),
      registryReset: true,
      homeReadiness: 'initial API tasks complete with rendered shelves',
      rokuModel: deviceInfo.modelName,
      rokuModelNumber: deviceInfo.modelNumber,
      rokuOsVersion: deviceInfo.softwareVersion,
      scene: 'MainScene',
      starfinVersion: environment.version,
      startupSurface: 'Login',
      test: this.test.fullTitle()
    });

    assert.equal(activeApp.app?.id, 'dev');
    const screenshots = [
      emptyLoginScreenshot,
      emptyValidationScreenshot,
      unreachableServerScreenshot,
      missingUsernameScreenshot,
      missingPasswordScreenshot,
      invalidCredentialsScreenshot,
      populatedLoginScreenshot,
      homeScreenshot
    ];
    for (const screenshot of screenshots) {
      const stats = await fs.stat(screenshot.outputPath);
      assert.ok(screenshot.buffer.length > 0, 'Screenshot buffer should not be empty.');
      assert.ok(stats.isFile(), 'Screenshot evidence should be written to disk.');
      assert.ok(stats.size > 0, 'Screenshot evidence file should not be empty.');
    }
  });
});
