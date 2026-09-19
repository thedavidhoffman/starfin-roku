import assert from 'node:assert/strict';
import { captureEvidence, addEvidenceMetadata } from '../support/evidence.mjs';
import { getAutomationEnvironment } from '../support/environment.mjs';
import { waitFor } from '../support/lifecycle.mjs';

const contentPath = '#overlayHost.0.#content.0';

async function value(environment, keyPath) {
  return (await environment.odc.getValue({ base: 'scene', keyPath })).value;
}

async function openPicker(environment) {
  await environment.odc.callFunc({ base: 'scene', keyPath: '#login', funcName: 'activate' });
  assert.equal(await value(environment, '#serverInput.hasFocusVisual'), true);
  await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
  await waitFor(() => value(environment, `${contentPath}.viewState.searching`), 'discovery to start');
  assert.equal(await value(environment, `${contentPath}.#servers.visible`), false);
  assert.equal(await value(environment, `${contentPath}.#cancel.hasFocusVisual`), true);
}

async function openManualEntry(environment) {
  await openPicker(environment);
  await waitFor(async () => (await value(environment, `${contentPath}.viewState.searching`)) === false, 'scan completion before manual entry', 12000);
  const state = await value(environment, `${contentPath}.viewState`);
  assert.equal(await value(environment, `${contentPath}.#servers.itemFocused`), 0);
  for (let index = 0; index < state.servers.length; index++) {
    await environment.ecp.sendKeypress(environment.ecp.Key.Down);
  }
  await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
}

describe('Starfin server discovery', function () {
  it('cancels a running scan and preserves the login form', async function () {
    const environment = await getAutomationEnvironment();
    await openPicker(environment);
    await captureEvidence(this, 'discovery-searching');
    await environment.ecp.sendKeypress(environment.ecp.Key.Back);
    assert.equal(await value(environment, '#overlayHost.getChildCount()'), 0);
    assert.equal(await value(environment, '#serverInput.hasFocusVisual'), true);
    assert.equal(await value(environment, '#login.serverValue'), '');
  });

  it('discovers local servers and applies an explicit selection', async function () {
    const environment = await getAutomationEnvironment();
    await captureEvidence(this, 'discovery-login');
    await openPicker(environment);
    const state = await waitFor(async () => {
      const current = await value(environment, `${contentPath}.viewState`);
      return current?.searching === false && current;
    }, 'discovery results', 12000);
    assert.ok(state.servers.length > 0, state.message);
    if (process.env.STARFIN_DISCOVERY_EXPECTED_NAME) {
      assert.ok(state.servers.some(server => server.name === process.env.STARFIN_DISCOVERY_EXPECTED_NAME));
    }
    addEvidenceMetadata(this, { servers: state.servers });
    await captureEvidence(this, 'discovery-results');
    assert.equal(await value(environment, '#login.serverValue'), '');
    assert.equal(await value(environment, `${contentPath}.#servers.itemFocused`), 0);
    assert.equal(await value(environment, `${contentPath}.#servers.content.0.listFocused`), true);
    assert.equal(state.message, 'Select a server...');
    await captureEvidence(this, 'discovery-server-focused');
    await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
    assert.equal(await value(environment, '#login.serverValue'), state.servers[0].address);
    assert.equal(await value(environment, '#usernameInput.hasFocusVisual'), true);
    assert.ok(!await value(environment, '#login.loginRequested'));
    await captureEvidence(this, 'discovery-selected');
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.serverValue', value: '' });
  });

  it('allows remote navigation to Search Again and completes another scan', async function () {
    const environment = await getAutomationEnvironment();
    await openPicker(environment);
    const state = await waitFor(async () => {
      const current = await value(environment, `${contentPath}.viewState`);
      return current?.searching === false && current;
    }, 'initial results', 12000);
    for (let index = 0; index < state.servers.length; index++) {
      await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      await waitFor(async () => (await value(environment, `${contentPath}.#servers.itemFocused`)) === index + 1, 'next row focus');
    }
    await environment.ecp.sendKeypress(environment.ecp.Key.Down);
    await waitFor(() => value(environment, `${contentPath}.#search.hasFocusVisual`), 'Search Again focus');
    assert.equal(await value(environment, `${contentPath}.#search.hasFocusVisual`), true);
    assert.equal(await value(environment, `${contentPath}.#servers.content.0.listFocused`), false);
    await captureEvidence(this, 'discovery-footer-focused');
    await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
    assert.equal(await value(environment, `${contentPath}.viewState.searching`), true);
    assert.equal(await value(environment, `${contentPath}.#servers.visible`), false);
    assert.equal(await value(environment, `${contentPath}.#cancel.hasFocusVisual`), true);
    await waitFor(async () => (await value(environment, `${contentPath}.viewState.searching`)) === false, 'retry results', 12000);
    await environment.ecp.sendKeypress(environment.ecp.Key.Back);
    assert.equal(await value(environment, '#serverInput.hasFocusVisual'), true);
  });
  it('returns keyboard cancellation to manual entry after discovery', async function () {
    const environment = await getAutomationEnvironment();
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.serverValue', value: 'http://nas:8097/base' });
    await openManualEntry(environment);
    assert.equal(await value(environment, 'dialog.text'), 'http://nas:8097/base');
    assert.equal(await value(environment, `${contentPath}.keyboardActive`), true);
    assert.equal(await value(environment, 'dialog.text'), 'http://nas:8097/base');
    await captureEvidence(this, 'discovery-manual-keyboard');
    await environment.ecp.sendKeypress(environment.ecp.Key.Back);
    assert.equal(await value(environment, `${contentPath}.keyboardActive`), false);
    const state = await value(environment, `${contentPath}.viewState`);
    assert.equal(await value(environment, `${contentPath}.#servers.itemFocused`), state.servers.length);
    await environment.ecp.sendKeypress(environment.ecp.Key.Back);
    assert.equal(await value(environment, '#login.serverValue'), 'http://nas:8097/base');
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.serverValue', value: '' });
  });

  it('validates and commits manual entry through the shared selection path', async function () {
    const environment = await getAutomationEnvironment();
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.usernameValue', value: 'existing-user' });
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.passwordValue', value: 'existing-password' });
    await openManualEntry(environment);
    await environment.odc.setValue({ base: 'scene', keyPath: 'dialog.text', value: '   ' });
    await environment.odc.setValue({ base: 'scene', keyPath: 'dialog.buttonSelected', value: 0 });
    assert.deepEqual(await value(environment, 'dialog.message'), ['Server address is required']);
    await environment.odc.setValue({ base: 'scene', keyPath: 'dialog.text', value: ' nas:8097/jellyfin/ ' });
    await environment.odc.setValue({ base: 'scene', keyPath: 'dialog.buttonSelected', value: 0 });
    assert.equal(await value(environment, '#overlayHost.getChildCount()'), 0);
    assert.equal(await value(environment, '#login.serverValue'), 'http://nas:8097/jellyfin');
    assert.equal(await value(environment, '#login.usernameValue'), '');
    assert.equal(await value(environment, '#login.passwordValue'), '');
    assert.equal(await value(environment, '#usernameInput.hasFocusVisual'), true);
    await captureEvidence(this, 'discovery-manual-selected');
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.serverValue', value: '' });
  });

  it('preserves credentials when manual entry keeps the same normalized address', async function () {
    const environment = await getAutomationEnvironment();
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.serverValue', value: 'http://nas:8097/base' });
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.usernameValue', value: 'existing-user' });
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.passwordValue', value: 'existing-password' });
    await openManualEntry(environment);
    await environment.odc.setValue({ base: 'scene', keyPath: 'dialog.text', value: ' nas:8097/base/ ' });
    await environment.odc.setValue({ base: 'scene', keyPath: 'dialog.buttonSelected', value: 0 });
    assert.equal(await value(environment, '#login.usernameValue'), 'existing-user');
    assert.equal(await value(environment, '#login.passwordValue'), 'existing-password');
    assert.equal(await value(environment, '#usernameInput.hasFocusVisual'), true);
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.serverValue', value: '' });
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.usernameValue', value: '' });
    await environment.odc.setValue({ base: 'scene', keyPath: '#login.passwordValue', value: '' });
  });

});
