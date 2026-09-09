import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { assertEverySortNameStartsWith, loadEveryFilteredItem, selectBrowseMode, selectLetterFromGrid } from '../support/letter-grid.mjs';
import { openConfiguredLibrary } from '../support/library-navigation.mjs';
import { returnToHome } from '../support/tv-series.mjs';

describe('Starfin music library letter grid', function () {
  afterEach(async function () { await returnToHome(); });

  const cases = JSON.parse(process.env.STARFIN_AUTOMATION_LETTERGRID_MUSIC_CASES ?? '[]');
  for (const testCase of cases) {
    it(`shows every ${testCase.browseMode.toLowerCase()} whose sort name starts with ${testCase.letter}`, async function () {
      const environment = await ensureAuthenticated();
      await openConfiguredLibrary(environment, { collectionType: 'music', libraryName: environment.musicLibrary, pageType: 'MusicLibrary', taskId: 'musicLibraryTask' });
      await selectBrowseMode(environment, testCase.browseMode);
      await selectLetterFromGrid(this, environment, 'music-library', testCase.letter);
      const taskId = testCase.browseMode === 'Artist' ? 'musicArtistsTask' : 'musicLibraryTask';
      const { gridCount, totalCount } = await loadEveryFilteredItem(environment, { gridId: 'musicGrid', itemLabel: `${testCase.browseMode.toLowerCase()}s`, letter: testCase.letter, taskId });

      assert.equal(gridCount, totalCount, `The grid should render all ${totalCount} matching items.`);
      await assertEverySortNameStartsWith(environment, { gridId: 'musicGrid', itemCount: gridCount, letter: testCase.letter });
      await captureEvidence(this, `music-library-letter-grid-${testCase.browseMode.toLowerCase()}-${testCase.letter.toLowerCase()}`);
    });
  }
});
