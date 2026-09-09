import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { assertEverySortNameStartsWith, loadEveryFilteredItem, selectBrowseMode, selectLetterFromGrid } from '../support/letter-grid.mjs';
import { openConfiguredLibrary } from '../support/library-navigation.mjs';
import { returnToHome } from '../support/tv-series.mjs';

describe('Starfin TV library letter grid', function () {
  afterEach(async function () { await returnToHome(); });

  const cases = JSON.parse(process.env.STARFIN_AUTOMATION_LETTERGRID_TV_CASES ?? '[]');
  for (const testCase of cases) {
    it(`shows every series whose sort name starts with ${testCase.letter} in ${testCase.browseMode}`, async function () {
      const environment = await ensureAuthenticated();
      await openConfiguredLibrary(environment, { collectionType: 'tvshows', libraryName: environment.tvLibrary, pageType: 'VideoLibrary', taskId: 'videoLibraryTask' });
      await selectBrowseMode(environment, testCase.browseMode);
      await selectLetterFromGrid(this, environment, 'tv-library', testCase.letter);
      const { gridCount, totalCount } = await loadEveryFilteredItem(environment, { gridId: 'itemsGrid', itemLabel: 'series', letter: testCase.letter, taskId: 'videoLibraryTask' });

      assert.equal(gridCount, totalCount, `The grid should render all ${totalCount} matching series.`);
      await assertEverySortNameStartsWith(environment, { gridId: 'itemsGrid', itemCount: gridCount, letter: testCase.letter });
      await captureEvidence(this, `tv-library-letter-grid-${testCase.letter.toLowerCase()}`);
    });
  }
});
