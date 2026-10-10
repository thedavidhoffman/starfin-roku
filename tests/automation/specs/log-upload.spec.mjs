import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { waitFor } from '../support/lifecycle.mjs';

const content = '#overlayHost.0.#content.0';
const confirmation = '#confirmationOverlayHost.0.#content.0';

describe('Starfin log upload confirmation', function () {
  let environment;
  const value = async keyPath => (await environment.odc.getValue({ base: 'scene', keyPath })).value;
  const call = (keyPath, funcName, ...funcParams) => environment.odc.callFunc({ base: 'scene', keyPath, funcName, funcParams });

  before(async function () {
    environment = await ensureAuthenticated();
  });

  beforeEach(async function () {
    // Initial Home loading restores shelf focus before publishing ready.
    if (await value('#homePage.visible') === true) {
      await waitFor(async () => await value('#homePage.ready') === true, 'Home loading to finish before opening Logs', 45000);
    }
    // Open without credentials so the capability task does not contact a server.
    await call('#overlayHost', 'openOverlay', {
      id: 'logs', componentName: 'LogDialog', openFunction: 'openLogs',
      closeField: 'closeRequested', eventFields: ['confirmationRequested']
    });
    // Unknown capability permits confirmation. These values cannot authenticate
    // to the user's Jellyfin server, and these tests only choose Cancel or Back.
    for (const [field, nextValue] of Object.entries({ server: 'http://127.0.0.1:1', token: 'synthetic-test-token', userId: 'synthetic-user' })) {
      await environment.odc.setValue({ base: 'scene', keyPath: `#overlayHost.0.${field}`, value: nextValue });
    }
    await call(content, 'focusLog');
  });

  afterEach(async function () {
    await call('#overlayHost', 'closeOverlay');
  });

  async function openConfirmation() {
    await environment.ecp.sendKeypress(environment.ecp.Key.Right);
    await waitFor(() => environment.odc.hasFocus({ base: 'scene', keyPath: `${content}.#sendLog` }), 'Send Log focused');
    await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
    await waitFor(async () => await value('#confirmationOverlayHost.getChildCount()') === 1, 'log confirmation opened');
    assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: `${confirmation}.#cancel` }), true);
    assert.equal(await value('#overlayHost.0.title'), 'Application Log');
  }

  it('Cancel restores Send focus without replacing or scrolling the log', async function () {
    const offset = await value(`${content}.#scrollThumb.translation`);
    await openConfirmation();
    await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
    await waitFor(async () => await value('#confirmationOverlayHost.getChildCount()') === 0, 'confirmation cancelled');
    assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: `${content}.#sendLog` }), true);
    assert.deepEqual(await value(`${content}.#scrollThumb.translation`), offset);
    assert.equal(await value('#loadingSpinner.blockInteraction'), false);
    assert.equal(await value('#overlayHost.0.#uploadTask.subtype()'), 'ClientLogUploadTask');
    const uploadRequest = await environment.odc.getValue({ base: 'scene', keyPath: '#overlayHost.0.#uploadTask.request' });
    // RTA reports an invalid Roku field as not found and omits its value.
    assert.equal(uploadRequest.found, false);
  });

  it('Back cancels confirmation and keeps the log open', async function () {
    await openConfirmation();
    await environment.ecp.sendKeypress(environment.ecp.Key.Back);
    await waitFor(async () => await value('#confirmationOverlayHost.getChildCount()') === 0, 'confirmation dismissed');
    assert.equal(await value('#overlayHost.getChildCount()'), 1);
    assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: `${content}.#sendLog` }), true);
  });
});
