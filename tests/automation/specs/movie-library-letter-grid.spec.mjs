import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { assertEverySortNameStartsWith, loadEveryFilteredItem, selectBrowseMode, selectLetterFromGrid } from '../support/letter-grid.mjs';
import { openConfiguredLibrary } from '../support/library-navigation.mjs';
import { returnToHome } from '../support/tv-series.mjs';

describe('Starfin movie library letter grid', function () {
  afterEach(async function () { await returnToHome(); });

  const cases = JSON.parse(process.env.STARFIN_AUTOMATION_LETTERGRID_MOVIE_CASES ?? '[]');
  for (const testCase of cases) {
    it(`shows every movie whose sort name starts with ${testCase.letter} in ${testCase.browseMode}`, async function () {
      const environment = await ensureAuthenticated();
      await openConfiguredLibrary(environment, { collectionType: 'movies', libraryName: environment.movieLibrary, pageType: 'VideoLibrary', taskId: 'videoLibraryTask' });
      await selectBrowseMode(environment, testCase.browseMode);
      await selectLetterFromGrid(this, environment, 'movie-library', testCase.letter);
      const { gridCount, totalCount } = await loadEveryFilteredItem(environment, { gridId: 'itemsGrid', itemLabel: 'movies', letter: testCase.letter, taskId: 'videoLibraryTask' });

      assert.equal(gridCount, totalCount, `The grid should render all ${totalCount} matching movies.`);
      await assertEverySortNameStartsWith(environment, { gridId: 'itemsGrid', itemCount: gridCount, letter: testCase.letter });
      await captureEvidence(this, `movie-library-letter-grid-${testCase.letter.toLowerCase()}`);
    });
  }
});
