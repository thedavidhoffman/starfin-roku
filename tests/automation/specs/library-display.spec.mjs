import assert from 'node:assert/strict';
import { captureEvidence } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { openConfiguredLibrary } from '../support/library-navigation.mjs';
import { categories, closeAndSaveSettings, openSettings } from '../support/settings.mjs';
import { returnToHome } from '../support/tv-series.mjs';

const layouts = [
  { presentation: 'poster', columns: 3, presentationNode: 'posterOptions', columnIndex: 0, translation: [96, 207], itemSize: [582, 893], itemSpacing: [-12, 27], numRows: 2 },
  { presentation: 'poster', columns: 4, presentationNode: 'posterOptions', columnIndex: 1, translation: [96, 207], itemSize: [438, 677], itemSpacing: [-10, 27], numRows: 2 },
  { presentation: 'poster', columns: 5, presentationNode: 'posterOptions', columnIndex: 2, translation: [96, 207], itemSize: [354, 551], itemSpacing: [-12, 27], numRows: 2 },
  { presentation: 'poster', columns: 6, presentationNode: 'posterOptions', columnIndex: 3, translation: [96, 207], itemSize: [297, 465], itemSpacing: [-12, 27], numRows: 2 },
  { presentation: 'thumbnail', columns: 2, presentationNode: 'thumbnailOptions', columnIndex: 0, translation: [24, 207], itemSize: [930, 609], itemSpacing: [0, 12], numRows: 3 },
  { presentation: 'thumbnail', columns: 3, presentationNode: 'thumbnailOptions', columnIndex: 1, translation: [24, 207], itemSize: [620, 434], itemSpacing: [0, 12], numRows: 3 },
  { presentation: 'thumbnail', columns: 4, presentationNode: 'thumbnailOptions', columnIndex: 2, translation: [24, 207], itemSize: [465, 348], itemSpacing: [0, 12], numRows: 3 },
  { presentation: 'detailed', columns: 2, presentationNode: 'detailedOptions', columnIndex: 0, translation: [24, 207], itemSize: [936, 591], itemSpacing: [0, -39], numRows: 2 }
];

const surfaces = [
  { label: 'movie', collectionType: 'movies', environmentKey: 'movieLibrary', settingKey: 'movie-library-layout', rowIndex: 1 },
  { label: 'TV', collectionType: 'tvshows', environmentKey: 'tvLibrary', settingKey: 'tv-library-layout', rowIndex: 0 }
];

async function selectLibraryLayout(environment, surface, layout) {
  await environment.odc.setValue({
    base: 'scene',
    keyPath: `#${layout.presentationNode}.itemSelected`,
    value: surface.rowIndex
  });
  await environment.odc.setValue({
    base: 'scene',
    keyPath: `#columnsGroups.${surface.rowIndex}.${layout.columnIndex}.buttonSelected`,
    value: true
  });

  const expected = `${layout.presentation};${layout.columns}`;
  await waitFor(async () => {
    const response = await environment.odc.getValue({
      base: 'scene',
      keyPath: '#librarySettingsGrid.selections'
    });
    return response.value?.[surface.settingKey] === expected;
  }, `${surface.label} library controls to select ${expected}`);
}

async function assertLibraryLayout(environment, layout) {
  let observedState;
  let state;
  try {
    state = await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        gridCount: { base: 'scene', keyPath: '#itemsGrid.content.getChildCount()' },
        numColumns: { base: 'scene', keyPath: '#itemsGrid.numColumns' },
        numRows: { base: 'scene', keyPath: '#itemsGrid.numRows' },
        itemSize: { base: 'scene', keyPath: '#itemsGrid.itemSize' },
        itemSpacing: { base: 'scene', keyPath: '#itemsGrid.itemSpacing' },
        translation: { base: 'scene', keyPath: '#itemsGrid.translation' },
        cardAspect: { base: 'scene', keyPath: '#itemsGrid.content.0.imageAspect' },
        cardColumns: { base: 'scene', keyPath: '#itemsGrid.content.0.cardLayout.numColumns' },
        taskState: { base: 'scene', keyPath: '#videoLibraryTask.state' }
      }
    });
    const result = Object.fromEntries(
      Object.entries(values.results).map(([key, response]) => [key, response?.value])
    );
    observedState = result;
    return result.gridCount > 0
      && result.numColumns === layout.columns
      && result.cardAspect === layout.presentation
      && result.cardColumns === layout.columns
      && ['done', 'stop'].includes(String(result.taskState ?? '').toLowerCase())
      ? result
      : false;
    }, `${layout.presentation};${layout.columns} to render`, 30000);
  } catch (error) {
    throw new Error(`${error.message} Last observed state: ${JSON.stringify(observedState)}`);
  }

  assert.equal(state.numRows, layout.numRows);
  assert.deepEqual(state.itemSize, layout.itemSize);
  assert.deepEqual(state.itemSpacing, layout.itemSpacing);
  assert.deepEqual(state.translation, layout.translation);
}

async function restoreDefaultLibraryLayouts() {
  const { environment } = await openSettings(categories.libraries);
  const defaultLayout = layouts.find(layout => layout.presentation === 'poster' && layout.columns === 6);
  for (const surface of surfaces) await selectLibraryLayout(environment, surface, defaultLayout);
  await closeAndSaveSettings(environment);
}

describe('Starfin movie and TV library display', function () {
  this.timeout(180000);

  afterEach(async function () {
    await returnToHome();
  });

  after(async function () {
    await restoreDefaultLibraryLayouts();
  });

  for (const surface of surfaces) {
    for (const layout of layouts) {
      it(`renders the ${surface.label} library as ${layout.presentation};${layout.columns}`, async function () {
        const { environment } = await openSettings(categories.libraries);
        await selectLibraryLayout(environment, surface, layout);
        await captureEvidence(this, `${surface.label.toLowerCase()}-library-setting-${layout.presentation}-${layout.columns}`);
        await closeAndSaveSettings(environment);

        await openConfiguredLibrary(environment, {
          collectionType: surface.collectionType,
          libraryName: environment[surface.environmentKey],
          pageType: 'VideoLibrary',
          taskId: 'videoLibraryTask'
        });
        await assertLibraryLayout(environment, layout);
        await captureEvidence(this, `${surface.label.toLowerCase()}-library-display-${layout.presentation}-${layout.columns}`);
      });
    }
  }
});
