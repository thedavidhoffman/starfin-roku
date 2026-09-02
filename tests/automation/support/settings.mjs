import assert from 'node:assert/strict';
import { captureEvidence } from './evidence.mjs';
import { ensureAuthenticated } from './authentication.mjs';
import { waitFor } from './lifecycle.mjs';

export const accountDefaults = {
  'tv-library-layout': 'poster;6',
  'movie-library-layout': 'poster;6',
  'collection-cards-layout': 'poster;6',
  'collection-items-layout': 'poster;6',
  'playlist-cards-layout': 'poster;6',
  'playlist-items-layout': 'poster;6',
  'music-videos-layout': 'poster;6',
  'home-videos-layout': 'poster;6',
  'tv-ep-list-scroll': 'vertical',
  'media-shell-background': 'full-screen',
  'theme-music': 'off',
  'next-item-playback': 'show-up-next',
  'screensaver-type': 'none',
  'screensaver-delay': '1'
};

export const globalDefaults = {
  'display-account-badge': 'off',
  'video-streaming-mode': 'automatic',
  'subtitle-burn-in-mode': 'during-transcoding',
  'tmdb-api-key': ''
};

export const categories = {
  libraries: { listNode: 'userCategoryList', index: 0, panelNode: 'libraryPanel' },
  mediaShell: { listNode: 'userCategoryList', index: 1, panelNode: 'mediaShellPanel' },
  playback: { listNode: 'userCategoryList', index: 2, panelNode: 'playbackPanel' },
  tv: { listNode: 'userCategoryList', index: 3, panelNode: 'tvPanel' },
  screensaver: { listNode: 'userCategoryList', index: 4, panelNode: 'screensaverPanel' },
  general: { listNode: 'deviceCategoryList', index: 0, panelNode: 'systemPanel' },
  video: { listNode: 'deviceCategoryList', index: 1, panelNode: 'videoPanel' },
  subtitles: { listNode: 'deviceCategoryList', index: 2, panelNode: 'subtitlesPanel' },
  advanced: { listNode: 'deviceCategoryList', index: 3, panelNode: 'advancedPanel' }
};

let settingsTestsRan = false;
let activeAccountKey;

export async function getAccountKey(environment) {
  const response = await environment.odc.getValue({
    base: 'scene',
    keyPath: '#authController.authenticatedSession.accountKey'
  });
  assert.equal(response.found, true, 'The authenticated account key should be available.');
  assert.ok(response.value, 'The authenticated account key should not be empty.');
  return response.value;
}

export async function openSettings(category) {
  const environment = await ensureAuthenticated();
  const accountKey = await getAccountKey(environment);
  settingsTestsRan = true;
  activeAccountKey = accountKey;

  await environment.odc.callFunc({
    base: 'scene',
    keyPath: '#overlayHost',
    funcName: 'openOverlay',
    funcParams: [{
      id: 'settings',
      componentName: 'SettingsDialog',
      closeField: 'closeRequested',
      openFunction: 'openSettings',
      accountKey
    }]
  });
  await environment.odc.setValue({
    base: 'scene',
    keyPath: `#${category.listNode}.itemSelected`,
    value: category.index
  });

  await waitFor(async () => {
    const response = await environment.odc.getValue({
      base: 'scene',
      keyPath: `#${category.panelNode}.visible`
    });
    return response.found && response.value === true;
  }, 'the requested Settings category');

  return { environment, accountKey };
}

export async function selectRadioOption(environment, nodeId, index) {
  await environment.odc.setValue({
    base: 'scene',
    keyPath: `#${nodeId}.itemSelected`,
    value: index
  });

  await waitFor(async () => {
    const response = await environment.odc.getValue({
      base: 'scene',
      keyPath: `#${nodeId}.checkedItem`
    });
    return response.found && response.value === index;
  }, `${nodeId} to select option ${index}`);
}

export async function closeAndSaveSettings(environment) {
  await environment.odc.callFunc({
    base: 'scene',
    keyPath: '#overlayHost.0',
    funcName: 'closeDialog'
  });

  await waitFor(async () => {
    const response = await environment.odc.getValue({
      base: 'scene',
      keyPath: '#overlayHost.getChildCount()'
    });
    return response.found && response.value === 0;
  }, 'the Settings dialog to close');
}

function getRegistrySection(scope, accountKey) {
  if (scope === 'global') return 'STARFIN_ROKU';
  return `STARFIN_ACCOUNT_${accountKey}`;
}

export async function readSetting(environment, accountKey, scope, key) {
  const sectionName = getRegistrySection(scope, accountKey);
  const registry = await environment.odc.readRegistry({
    values: { [sectionName]: [key] }
  });
  return registry.values?.[sectionName]?.[key];
}

export async function assertSettingPersisted(environment, accountKey, scope, key, expectedValue) {
  await waitFor(async () => {
    const value = await readSetting(environment, accountKey, scope, key);
    return value === expectedValue;
  }, `${key} to persist ${expectedValue || 'its empty default'}`);

  const value = await readSetting(environment, accountKey, scope, key);
  assert.equal(value, expectedValue, `${key} should persist the selected value.`);
}

export async function exerciseRadioSetting(context, options) {
  const { environment, accountKey } = await openSettings(options.category);
  await selectRadioOption(environment, options.nodeId, options.index);
  await captureEvidence(context, options.checkpoint);
  await closeAndSaveSettings(environment);
  await assertSettingPersisted(environment, accountKey, options.scope, options.key, options.value);
}

export async function resetSettingsDefaults() {
  if (!settingsTestsRan || !activeAccountKey) return;

  const environment = await ensureAuthenticated();
  const accountSection = `STARFIN_ACCOUNT_${activeAccountKey}`;
  await environment.odc.writeRegistry({
    values: {
      [accountSection]: accountDefaults,
      STARFIN_ROKU: globalDefaults
    }
  });

  const registry = await environment.odc.readRegistry({
    values: {
      [accountSection]: Object.keys(accountDefaults),
      STARFIN_ROKU: Object.keys(globalDefaults)
    }
  });
  const accountValues = registry.values?.[accountSection] ?? {};
  const globalValues = registry.values?.STARFIN_ROKU ?? {};

  for (const [key, expectedValue] of Object.entries(accountDefaults)) {
    assert.equal(accountValues[key], expectedValue, `${key} should be restored to its default.`);
  }
  for (const [key, expectedValue] of Object.entries(globalDefaults)) {
    assert.equal(globalValues[key], expectedValue, `${key} should be restored to its default.`);
  }
}
