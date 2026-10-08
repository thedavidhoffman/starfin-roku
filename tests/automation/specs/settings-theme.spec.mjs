import assert from 'node:assert/strict';
import { captureEvidence } from '../support/evidence.mjs';
import { openConfiguredLibrary } from '../support/library-navigation.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { categories, exerciseRadioSetting, openSettings, openSettingsFromSystemMenu, selectRadioOption, closeAndSaveSettings, readSetting } from '../support/settings.mjs';

const cases = [
  { label: 'blue theme', nodeId: 'themeOptions', index: 0, key: 'theme', value: 'blue' },
  { label: 'black theme', nodeId: 'themeOptions', index: 1, key: 'theme', value: 'black' },
  { label: 'grey theme', nodeId: 'themeOptions', index: 2, key: 'theme', value: 'grey' },
  { label: 'pure black theme', nodeId: 'themeOptions', index: 3, key: 'theme', value: 'pure-black' },
  { label: 'high contrast watched indicator', nodeId: 'watchedIndicatorOptions', index: 1, key: 'watched-indicator-style', value: 'high-contrast' },
  { label: 'subtle watched indicator', nodeId: 'watchedIndicatorOptions', index: 0, key: 'watched-indicator-style', value: 'subtle' },
  { label: 'subtle unwatched episode counts', nodeId: 'showUnwatchedEpisodeCountOptions', index: 1, key: 'show-unwatched-episode-count', value: 'subtle' },
  { label: 'high contrast unwatched episode counts', nodeId: 'showUnwatchedEpisodeCountOptions', index: 2, key: 'show-unwatched-episode-count', value: 'high-contrast' },
  { label: 'disabled unwatched episode counts', nodeId: 'showUnwatchedEpisodeCountOptions', index: 0, key: 'show-unwatched-episode-count', value: 'off' }
];

describe('Starfin Theme settings persistence', function () {
  for (const testCase of cases) {
    it(`persists ${testCase.label}`, async function () {
      await exerciseRadioSetting(this, {
        ...testCase,
        category: categories.theme,
        scope: 'account',
        checkpoint: `settings-theme-${testCase.value}`
      });
    });
  }
});

const watchedStyleKey = 'watched-indicator-style';
const watchedUris = {
  subtle: 'pkg:/images/icons/watched-check.png',
  'high-contrast': 'pkg:/images/icons/watched-check-high-contrast.png'
};

async function cancelSettings(environment) {
  await environment.odc.callFunc({ base: 'scene', keyPath: '#overlayHost', funcName: 'closeOverlay' });
  await waitFor(async () => {
    const response = await environment.odc.getValue({ base: 'scene', keyPath: '#overlayHost.getChildCount()' });
    return response.value === 0;
  }, 'Settings cancellation');
}

async function exerciseWatchedPreview(context, from, to, verifyCancellation = false) {
  const nodeRefKey = 'watched-indicator-preview';
  let environment;
  let badgePath;
  let originalVisibility;
  let originalCheckVisibility;
  let referencesStored = false;
  try {
    const initial = await openSettings(categories.theme);
    environment = initial.environment;
    const accountKey = initial.accountKey;
    // Commit the opposite style first so the initial style is persisted even in isolation.
    await selectRadioOption(environment, 'watchedIndicatorOptions', from === 'subtle' ? 1 : 0);
    await closeAndSaveSettings(environment);
    await openSettings(categories.theme);
    await selectRadioOption(environment, 'watchedIndicatorOptions', from === 'subtle' ? 0 : 1);
    await closeAndSaveSettings(environment);
    assert.equal(await readSetting(environment, accountKey, 'account', watchedStyleKey), from);

    await openSettings(categories.libraries);
    await environment.odc.setValue({ base: 'scene', keyPath: '#posterOptions.itemSelected', value: 1 });
    await environment.odc.setValue({ base: 'scene', keyPath: '#columnsGroups.1.3.buttonSelected', value: true });
    await closeAndSaveSettings(environment);
    await openConfiguredLibrary(environment, {
      collectionType: 'movies', libraryName: environment.movieLibrary,
      pageType: 'VideoLibrary', taskId: 'videoLibraryTask'
    });
    const firstItem = await environment.odc.getValue({ base: 'scene', keyPath: '#itemsGrid.content.0.raw.Id' });
    assert.ok(firstItem.value, 'The configured movie library must contain a poster card.');
    await waitFor(async () => {
      await environment.odc.storeNodeReferences({ nodeRefKey, includeArrayGridChildren: true });
      referencesStored = true;
      const { nodeRefs } = await environment.odc.getNodesWithProperties({ nodeRefKey, properties: [
        { field: 'id', value: 'presentation' },
        { keyPath: 'itemContent.raw.Id', value: firstItem.value },
        { keyPath: 'itemContent.cardLayout.numColumns', value: 6 }
      ] });
      if (!nodeRefs.length) return false;
      badgePath = nodeRefs[0] + '.#watchedIndicator';
      return true;
    }, 'an existing movie poster badge');
    const badgeValue = field => environment.odc.getValue({ base: 'nodeRef', nodeRefKey, keyPath: badgePath + (field === 'visible' ? '.' : '.#watchedCheck.') + field });
    originalVisibility = (await badgeValue('visible')).value;
    originalCheckVisibility = (await environment.odc.getValue({ base: 'nodeRef', nodeRefKey, keyPath: badgePath + '.#watchedCheck.visible' })).value;
    assert.equal(typeof originalVisibility, 'boolean');
    // Only the local visual is changed; never mark the server item watched.
    await environment.odc.setValue({ base: 'nodeRef', nodeRefKey, keyPath: badgePath + '.visible', value: true });
    await environment.odc.setValue({ base: 'nodeRef', nodeRefKey, keyPath: badgePath + '.#watchedCheck.visible', value: true });
    await waitFor(async () => (await badgeValue('uri')).value === watchedUris[from] && (await badgeValue('loadStatus')).value === 'ready', 'the saved badge style');
    await captureEvidence(context, 'watched-preview-' + from + '-before-' + (verifyCancellation ? 'cancel' : 'switch'));

    await openSettingsFromSystemMenu(environment, categories.theme);
    await selectRadioOption(environment, 'watchedIndicatorOptions', to === 'subtle' ? 0 : 1);
    await waitFor(async () => (await badgeValue('uri')).value === watchedUris[to] && (await badgeValue('loadStatus')).value === 'ready', 'the same badge to preview ' + to);
    assert.equal((await badgeValue('visible')).value, true);
    const dialog = await environment.odc.getValue({ base: 'scene', keyPath: '#overlayHost.0.#dialog.visible' });
    assert.equal(dialog.value, true, 'The badge must update before Settings closes.');
    assert.equal(await readSetting(environment, accountKey, 'account', watchedStyleKey), from, 'Preview must not persist the selection.');
    await captureEvidence(context, 'watched-preview-' + from + '-to-' + to + (verifyCancellation ? '-cancel-pending' : ''));

    if (verifyCancellation) {
      await cancelSettings(environment);
      await waitFor(async () => (await badgeValue('uri')).value === watchedUris[from] && (await badgeValue('loadStatus')).value === 'ready', 'the same badge to restore its saved style');
      assert.equal(await readSetting(environment, accountKey, 'account', watchedStyleKey), from);
      await captureEvidence(context, 'watched-preview-cancel-restored');
    }
  } finally {
    if (environment) {
      try {
        await cancelSettings(environment);
      } finally {
        try {
          if (badgePath && typeof originalVisibility === 'boolean') {
            await environment.odc.setValue({ base: 'nodeRef', nodeRefKey, keyPath: badgePath + '.visible', value: originalVisibility });
          }
          if (badgePath && typeof originalCheckVisibility === 'boolean') {
            await environment.odc.setValue({ base: 'nodeRef', nodeRefKey, keyPath: badgePath + '.#watchedCheck.visible', value: originalCheckVisibility });
          }
        } finally {
          try {
            if (referencesStored) await environment.odc.deleteNodeReferences({ nodeRefKey });
          } finally {
            await environment.odc.focusNode({ base: 'scene', keyPath: '#homeButton' });
            await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
            await waitFor(async () => {
              const state = await environment.odc.getValues({ requests: {
                home: { base: 'scene', keyPath: '#homePage.visible' },
                pages: { base: 'scene', keyPath: '#dynamicPageHost.getChildCount()' }
              } });
              return state.results.home?.value === true && state.results.pages?.value === 0;
            }, 'Home after watched-preview cleanup');
          }
        }
      }
    }
  }
}

describe('Starfin watched indicator live preview', function () {
  it('updates the existing badge from subtle to high contrast before closing Settings', async function () {
    await exerciseWatchedPreview(this, 'subtle', 'high-contrast');
  });

  it('updates the existing badge from high contrast to subtle before closing Settings', async function () {
    await exerciseWatchedPreview(this, 'high-contrast', 'subtle');
  });

  it('restores the same badge and leaves persistence unchanged on cancellation', async function () {
    await exerciseWatchedPreview(this, 'subtle', 'high-contrast', true);
  });
});
