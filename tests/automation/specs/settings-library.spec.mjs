import assert from 'node:assert/strict';
import { captureEvidence } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import {
  categories,
  closeAndSaveSettings,
  openSettings,
  readSetting
} from '../support/settings.mjs';

const libraryKeys = [
  'tv-library-layout',
  'movie-library-layout',
  'collection-cards-layout',
  'collection-items-layout',
  'playlist-cards-layout',
  'playlist-items-layout',
  'music-videos-layout',
  'home-videos-layout'
];

const layouts = [
  { presentation: 'poster', columns: 3, presentationNode: 'posterOptions', columnIndex: 0 },
  { presentation: 'poster', columns: 4, presentationNode: 'posterOptions', columnIndex: 1 },
  { presentation: 'poster', columns: 5, presentationNode: 'posterOptions', columnIndex: 2 },
  { presentation: 'poster', columns: 6, presentationNode: 'posterOptions', columnIndex: 3 },
  { presentation: 'thumbnail', columns: 2, presentationNode: 'thumbnailOptions', columnIndex: 0 },
  { presentation: 'thumbnail', columns: 3, presentationNode: 'thumbnailOptions', columnIndex: 1 },
  { presentation: 'thumbnail', columns: 4, presentationNode: 'thumbnailOptions', columnIndex: 2 },
  { presentation: 'detailed', columns: 2, presentationNode: 'detailedOptions', columnIndex: 0 }
];

async function selectLayoutForEveryLibrary(environment, layout) {
  const expectedValue = `${layout.presentation};${layout.columns}`;

  for (let rowIndex = 0; rowIndex < libraryKeys.length; rowIndex += 1) {
    await environment.odc.setValue({
      base: 'scene',
      keyPath: `#${layout.presentationNode}.itemSelected`,
      value: rowIndex
    });
    await environment.odc.setValue({
      base: 'scene',
      keyPath: `#columnsGroups.${rowIndex}.${layout.columnIndex}.buttonSelected`,
      value: true
    });
  }

  await waitFor(async () => {
    const response = await environment.odc.getValue({
      base: 'scene',
      keyPath: '#librarySettingsGrid.selections'
    });
    if (!response.found || !response.value) return false;
    return libraryKeys.every(key => response.value[key] === expectedValue);
  }, `all library controls to select ${expectedValue}`);
}

async function assertPersistedLayout(environment, accountKey, expectedValue) {
  await waitFor(async () => {
    const values = await Promise.all(
      libraryKeys.map(key => readSetting(environment, accountKey, 'account', key))
    );
    return values.every(value => value === expectedValue);
  }, `all library registry values to persist ${expectedValue}`);

  for (const key of libraryKeys) {
    const value = await readSetting(environment, accountKey, 'account', key);
    assert.equal(value, expectedValue, `${key} should persist ${expectedValue}.`);
  }
}

describe('Starfin library settings persistence', function () {
  for (const layout of layouts) {
    const expectedValue = `${layout.presentation};${layout.columns}`;

    it(`persists ${expectedValue} for every library`, async function () {
      const { environment, accountKey } = await openSettings(categories.libraries);

      await selectLayoutForEveryLibrary(environment, layout);
      await captureEvidence(this, `settings-library-${layout.presentation}-${layout.columns}`);
      await closeAndSaveSettings(environment);
      await assertPersistedLayout(environment, accountKey, expectedValue);
    });
  }
});
