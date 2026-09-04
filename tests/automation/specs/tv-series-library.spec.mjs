import { ensureAuthenticated } from '../support/authentication.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import {
  assertExpectedEpisodes,
  assertExpectedSeasons,
  findSeries,
  openConfiguredTVLibrary,
  openSeasonOne,
  openSeries,
  readEpisodeCards,
  readSeasonCards,
  returnToHome
} from '../support/tv-series.mjs';

describe('Starfin TV series library', function () {
  afterEach(async function () {
    await returnToHome();
  });

  it('shows every configured season and Season 1 episode for the configured series', async function () {
    const environment = await ensureAuthenticated();

    await openConfiguredTVLibrary(environment);
    const { item, itemIndex } = await findSeries(environment);
    await openSeries(environment, itemIndex, item);
    const seasonCards = await readSeasonCards(environment);

    assertExpectedSeasons(seasonCards, environment.tvSeriesSmokeTest.seasons);
    await captureEvidence(this, 'tv-series-library-season-cards');

    await openSeasonOne(environment, seasonCards);
    const episodeCards = await readEpisodeCards(environment);

    assertExpectedEpisodes(episodeCards, environment.tvSeriesSmokeTest.season1);
    await captureEvidence(this, 'tv-series-library-season-1-episodes');
  });
});
