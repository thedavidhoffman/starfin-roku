import assert from 'node:assert/strict';
import { getAutomationEnvironment } from '../support/environment.mjs';
import { waitFor } from '../support/lifecycle.mjs';

async function value(environment, keyPath) {
  return (await environment.odc.getValue({ base: 'scene', keyPath })).value;
}

describe('Starfin credential keyboards', function () {
  afterEach(async function () {
    const environment = await getAutomationEnvironment();
    if (await value(environment, 'dialog')) await environment.ecp.sendKeypress(environment.ecp.Key.Back);
    for (const field of ['usernameValue', 'passwordValue']) {
      await environment.odc.setValue({ base: 'scene', keyPath: `#login.${field}`, value: '' });
    }
  });

  for (const [target, downCount] of [['username', 1], ['password', 2]]) {
    for (const action of ['Save', 'Cancel', 'Back']) {
      it(`${action} uses the native ${target} keyboard and restores field focus`, async function () {
        const environment = await getAutomationEnvironment();
        const initial = action === 'Save' ? '' : 'original';
        await environment.odc.setValue({ base: 'scene', keyPath: `#login.${target}Value`, value: initial });
        await environment.odc.callFunc({ base: 'scene', keyPath: '#login', funcName: 'activate' });
        await environment.ecp.sendKeypress(environment.ecp.Key.Down, { count: downCount, wait: 250 });
        await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
        await waitFor(async () => (await value(environment, 'dialog.title')) === `Enter ${target === 'username' ? 'Username' : 'Password'}`, 'credential keyboard');
        assert.equal(await value(environment, 'dialog.text'), initial);
        await environment.ecp.sendText('typed-value');
        await waitFor(async () => (await value(environment, 'dialog.text')) === `${initial}typed-value`, 'remote keyboard input');
        if (action === 'Back') {
          await environment.ecp.sendKeypress(environment.ecp.Key.Back);
        } else {
          // Native keyboard has four key rows above its Save and Cancel buttons.
          await environment.ecp.sendKeypress(environment.ecp.Key.Down, { count: action === 'Save' ? 4 : 5, wait: 250 });
          await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
        }
        await waitFor(async () => !await value(environment, 'dialog'), 'keyboard closure');
        assert.equal(await value(environment, `#login.${target}Value`), action === 'Save' ? 'typed-value' : initial);
        assert.equal(await value(environment, `#${target}Input.hasFocusVisual`), true);
      });
    }
  }
});
