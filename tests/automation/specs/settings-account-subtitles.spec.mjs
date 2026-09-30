import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { categories, openSettingsFromSystemMenu } from '../support/settings.mjs';

const settingsContent = '#overlayHost.0.#content.0';

describe('Starfin Jellyfin account subtitle settings', function () {
  let environment;
  let server;
  let token;
  let original;

  async function value(keyPath) {
    return (await environment.odc.getValue({ base: 'scene', keyPath })).value;
  }

  async function set(keyPath, nextValue) {
    await environment.odc.setValue({ base: 'scene', keyPath, value: nextValue });
  }

  async function api(route, body) {
    const response = await fetch(server + route, {
      method: body ? 'POST' : 'GET',
      headers: { 'X-Emby-Token': token, 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(15000)
    });
    assert.ok(response.ok, 'Jellyfin ' + route + ' returned ' + response.status);
    return response.status === 204 ? undefined : response.json();
  }

  async function waitForIdle() {
    await waitFor(async () => await value('#loadingSpinner.blockInteraction') === false && await value(`${settingsContent}.#accountSubtitleSpinner.control`) === 'stop', 'account request finished', 35000);
  }

  async function openAccountPage() {
    await openSettingsFromSystemMenu(environment, categories.accountSubtitles);
    await waitFor(async () => await value(`${settingsContent}.#subtitleAccountPage.visible`) === true, 'Jellyfin preferences page');
    await waitFor(async () => await value(`${settingsContent}.#accountSubtitleFields.visible`) === true, 'account subtitle fields loaded', 35000);
    await waitForIdle();
  }

  async function close() {
    await waitForIdle();
    await environment.ecp.sendKeypress(environment.ecp.Key.Back);
    await waitFor(async () => await value('#overlayHost.getChildCount()') === 0, 'Settings closed without confirmation', 35000);
  }

  function otherSettings(configuration) {
    return Object.fromEntries(Object.entries(configuration).filter(([key]) => !['SubtitleMode', 'SubtitleLanguagePreference'].includes(key)));
  }

  before(async function () {
    environment = await ensureAuthenticated();
    await openAccountPage();
    server = (await value('#overlayHost.0.server')).replace(/\/$/, '');
    token = await value('#overlayHost.0.token');
    original = (await api('/Users/Me')).Configuration;
  });

  after(async function () {
    if (!environment) return;
    try {
      try {
        // Allow any in-flight closing save to finish before restoring the account.
        if (await value('#overlayHost.getChildCount()') > 0) await waitForIdle();
      } finally {
        if (original) {
          const current = (await api('/Users/Me')).Configuration;
          current.SubtitleMode = original.SubtitleMode;
          current.SubtitleLanguagePreference = original.SubtitleLanguagePreference;
          await api('/Users/Configuration', current);
          const restored = (await api('/Users/Me')).Configuration;
          assert.equal(restored.SubtitleMode, original.SubtitleMode);
          assert.equal(restored.SubtitleLanguagePreference, original.SubtitleLanguagePreference);
        }
      }
    } finally {
      await environment.odc.callFunc({ base: 'scene', funcName: 'dismissMessage' });
      await environment.odc.callFunc({ base: 'scene', keyPath: '#overlayHost', funcName: 'closeOverlay' });
    }
  });

  it('saves a pending mode only when Back closes Settings', async function () {
    const before = (await api('/Users/Me')).Configuration;
    const targetMode = before.SubtitleMode === 'Always' ? 'Smart' : 'Always';
    const targetIndex = targetMode === 'Always' ? 3 : 1;
    await set(`${settingsContent}.#accountSubtitleModes.itemSelected`, targetIndex);
    await waitFor(async () => await value(`${settingsContent}.#accountSubtitleModes.checkedItem`) === targetIndex, 'pending subtitle mode selection');
    assert.deepEqual((await api('/Users/Me')).Configuration, before);
    await close();
    const saved = (await api('/Users/Me')).Configuration;
    assert.equal(saved.SubtitleMode, targetMode);
    assert.equal(saved.SubtitleLanguagePreference, before.SubtitleLanguagePreference);
    assert.deepEqual(otherSettings(saved), otherSettings(before));
    await openAccountPage();
    await captureEvidence(this, 'settings-account-subtitle-mode-saved');
    assert.equal(await value(`${settingsContent}.#accountSubtitleModes.checkedItem`), targetIndex);
  });

  it('saves a pending language on close without changing other settings', async function () {
    const before = (await api('/Users/Me')).Configuration;
    await set(`${settingsContent}.#accountSubtitleLanguage.buttonSelected`, true);
    await waitFor(async () => await value(`${settingsContent}.#accountSubtitlePicker.visible`) === true, 'language picker');
    await captureEvidence(this, 'settings-account-subtitle-languages');
    // Exercise empty-string preference when possible; otherwise choose a concrete language.
    const languageIndex = before.SubtitleLanguagePreference ? 0 : 1;
    await set(`${settingsContent}.#accountSubtitleLanguages.itemSelected`, languageIndex);
    await waitFor(async () => await value(`${settingsContent}.#accountSubtitlePicker.visible`) === false, 'language selected');
    const pendingLanguageLabel = await value(`${settingsContent}.#accountSubtitleCurrentLanguage.text`);
    assert.deepEqual((await api('/Users/Me')).Configuration, before);
    await close();
    const saved = (await api('/Users/Me')).Configuration;
    assert.notEqual(saved.SubtitleLanguagePreference, before.SubtitleLanguagePreference);
    if (languageIndex === 0) assert.equal(saved.SubtitleLanguagePreference, '');
    assert.equal(saved.SubtitleMode, before.SubtitleMode);
    assert.deepEqual(otherSettings(saved), otherSettings(before));
    await openAccountPage();
    assert.equal(await value(`${settingsContent}.#accountSubtitleCurrentLanguage.text`), pendingLanguageLabel);
  });

  it('cancels the language picker with Back without changing the account', async function () {
    const before = (await api('/Users/Me')).Configuration;
    const previous = await value(`${settingsContent}.#accountSubtitleCurrentLanguage.text`);
    await set(`${settingsContent}.#accountSubtitleLanguage.buttonSelected`, true);
    await waitFor(async () => await value(`${settingsContent}.#accountSubtitlePicker.visible`) === true, 'language picker');
    await environment.ecp.sendKeypress(environment.ecp.Key.Down);
    await environment.ecp.sendKeypress(environment.ecp.Key.Back);
    await waitFor(async () => await value(`${settingsContent}.#accountSubtitlePicker.visible`) === false, 'language picker dismissed');
    assert.equal(await value(`${settingsContent}.#accountSubtitleCurrentLanguage.text`), previous);
    assert.equal(await value(`${settingsContent}.#subtitleAccountPage.visible`), true);
    assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: `${settingsContent}.#accountSubtitleLanguage` }), true);
    assert.deepEqual((await api('/Users/Me')).Configuration, before);
  });
});
