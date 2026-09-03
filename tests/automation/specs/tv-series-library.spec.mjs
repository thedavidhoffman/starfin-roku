import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { getAutomationEnvironment } from '../support/environment.mjs';
import { waitFor } from '../support/lifecycle.mjs';

async function findConfiguredTVLibrary(environment) {
  return waitFor(async () => {
    const shelfCountResponse = await environment.odc.getValue({
      base: 'scene',
      keyPath: '#shelvesGroup.getChildCount()'
    });
    const shelfCount = shelfCountResponse.found ? shelfCountResponse.value : 0;

    for (let shelfIndex = 0; shelfIndex < shelfCount; shelfIndex += 1) {
      const shelf = await environment.odc.getValues({
        requests: {
          title: { base: 'scene', keyPath: `#shelvesGroup.${shelfIndex}.rowContent.title` },
          itemCount: { base: 'scene', keyPath: `#shelvesGroup.${shelfIndex}.rowContent.getChildCount()` }
        }
      });
      if (shelf.results.title?.value !== 'My Media') continue;

      const itemCount = shelf.results.itemCount?.value ?? 0;
      for (let itemIndex = 0; itemIndex < itemCount; itemIndex += 1) {
        const itemResponse = await environment.odc.getValue({
          base: 'scene',
          keyPath: `#shelvesGroup.${shelfIndex}.rowContent.${itemIndex}.raw`
        });
        const item = itemResponse.value;
        if (
          item?.Name === environment.tvSeriesLibrary
          && String(item.CollectionType ?? '').toLowerCase() === 'tvshows'
        ) {
          return { item, shelfIndex };
        }
      }
    }

    return false;
  }, `the ${environment.tvSeriesLibrary} TV library in My Media`, 45000);
}

async function openConfiguredTVLibrary(environment) {
  const { item, shelfIndex } = await findConfiguredTVLibrary(environment);

  await environment.odc.setValue({
    base: 'scene',
    keyPath: `#shelvesGroup.${shelfIndex}.selectedItem`,
    value: { item, rowKey: 'libraries' }
  });

  await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        pageType: { base: 'scene', keyPath: '#dynamicPageHost.0.subtype()' },
        pageVisible: { base: 'scene', keyPath: '#dynamicPageHost.0.visible' },
        collectionType: { base: 'scene', keyPath: '#videoLibraryTask.request.collectionType' },
        responseOk: { base: 'scene', keyPath: '#videoLibraryTask.response.ok' },
        taskState: { base: 'scene', keyPath: '#videoLibraryTask.state' }
      }
    });
    return values.results.pageType?.value === 'VideoLibrary'
      && values.results.pageVisible?.value === true
      && String(values.results.collectionType?.value ?? '').toLowerCase() === 'tvshows'
      && values.results.responseOk?.value === true
      && ['done', 'stop'].includes(String(values.results.taskState?.value ?? '').toLowerCase());
  }, `the ${environment.tvSeriesLibrary} TV library to load`, 120000);
}

async function findSeries(environment) {
  const expectedPrefix = environment.tvSeriesSmokeTest.seriesName.toLocaleLowerCase('en-US');

  return waitFor(async () => {
    const state = await environment.odc.getValues({
      requests: {
        gridCount: { base: 'scene', keyPath: '#itemsGrid.content.getChildCount()' },
        responseOk: { base: 'scene', keyPath: '#videoLibraryTask.response.ok' },
        taskState: { base: 'scene', keyPath: '#videoLibraryTask.state' },
        totalCount: { base: 'scene', keyPath: '#videoLibraryTask.response.totalRecordCount' }
      }
    });
    const taskState = String(state.results.taskState?.value ?? '').toLowerCase();
    if (state.results.responseOk?.value !== true || !['done', 'stop'].includes(taskState)) return false;

    const gridCount = state.results.gridCount?.value ?? 0;
    if (gridCount === 0) return false;
    const requests = {};
    for (let itemIndex = 0; itemIndex < gridCount; itemIndex += 1) {
      requests[itemIndex] = { base: 'scene', keyPath: `#itemsGrid.content.${itemIndex}.raw` };
    }
    const itemsResponse = await environment.odc.getValues({ requests });
    for (let itemIndex = 0; itemIndex < gridCount; itemIndex += 1) {
      const item = itemsResponse.results[itemIndex]?.value;
      if (
        String(item?.Type ?? '').toLowerCase() === 'series'
        && String(item?.Name ?? '').toLocaleLowerCase('en-US').startsWith(expectedPrefix)
      ) {
        return { item, itemIndex };
      }
    }

    const totalCount = state.results.totalCount?.value ?? -1;
    if (gridCount > 0 && gridCount < totalCount) {
      await environment.odc.setValue({
        base: 'scene',
        keyPath: '#itemsGrid.itemFocused',
        value: gridCount - 1
      });
    }
    return false;
  }, `a series starting with ${environment.tvSeriesSmokeTest.seriesName}`, 120000);
}

async function openSeries(environment, itemIndex, item) {
  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#itemsGrid.itemSelected',
    value: itemIndex
  });

  await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        childCount: { base: 'scene', keyPath: '#dynamicPageHost.getChildCount()' },
        pageType: { base: 'scene', keyPath: '#dynamicPageHost.1.subtype()' },
        pageVisible: { base: 'scene', keyPath: '#dynamicPageHost.1.visible' },
        itemId: { base: 'scene', keyPath: '#tvShowTask.request.itemId' },
        responseOk: { base: 'scene', keyPath: '#tvShowTask.response.ok' },
        taskState: { base: 'scene', keyPath: '#tvShowTask.state' }
      }
    });
    return values.results.childCount?.value === 2
      && values.results.pageType?.value === 'TVShow'
      && values.results.pageVisible?.value === true
      && values.results.itemId?.value === item.Id
      && values.results.responseOk?.value === true
      && ['done', 'stop'].includes(String(values.results.taskState?.value ?? '').toLowerCase());
  }, `${item.Name} series page to load`, 120000);
}

async function readSeasonCards(environment) {
  const countResponse = await environment.odc.getValue({
    base: 'scene',
    keyPath: '#seasonsGrid.content.getChildCount()'
  });
  const seasonCount = countResponse.value ?? 0;
  const fields = ['title', 'seasonYear', 'episodeCount', 'raw'];
  const requests = {};
  for (let seasonIndex = 0; seasonIndex < seasonCount; seasonIndex += 1) {
    for (const field of fields) {
      requests[`${seasonIndex}-${field}`] = {
        base: 'scene',
        keyPath: `#seasonsGrid.content.${seasonIndex}.${field}`
      };
    }
  }

  const response = await environment.odc.getValues({ requests });
  return Array.from({ length: seasonCount }, (_, seasonIndex) => Object.fromEntries(
    fields.map(field => [field, response.results[`${seasonIndex}-${field}`]?.value])
  ));
}

function assertExpectedSeasons(cards, expectedSeasons) {
  for (const expected of expectedSeasons) {
    const card = cards.find(candidate => Number(candidate.raw?.IndexNumber) === expected.season);
    assert.ok(card, `Season ${expected.season} should have a season card.`);
    assert.equal(card.title, `Season ${expected.season}`);
    assert.equal(Number(card.seasonYear), expected.year, `Season ${expected.season} should show ${expected.year}.`);
    assert.equal(
      Number(card.episodeCount),
      expected.episodeCount,
      `Season ${expected.season} should show ${expected.episodeCount} episodes.`
    );
  }
}

async function openSeasonOne(environment, seasonCards) {
  const seasonIndex = seasonCards.findIndex(card => Number(card.raw?.IndexNumber) === 1);
  assert.notEqual(seasonIndex, -1, 'Season 1 should be selectable.');

  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#seasonsGrid.itemSelected',
    value: seasonIndex
  });

  await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        childCount: { base: 'scene', keyPath: '#dynamicPageHost.getChildCount()' },
        pageType: { base: 'scene', keyPath: '#dynamicPageHost.2.subtype()' },
        pageVisible: { base: 'scene', keyPath: '#dynamicPageHost.2.visible' },
        seasonLabel: { base: 'scene', keyPath: '#seasonLabel.text' },
        horizontalCount: { base: 'scene', keyPath: '#episodesList.content.0.getChildCount()' },
        verticalCount: { base: 'scene', keyPath: '#episodesGrid.content.getChildCount()' }
      }
    });
    const episodeNodeCount = Math.max(
      values.results.horizontalCount?.value ?? 0,
      values.results.verticalCount?.value ?? 0
    );
    return values.results.childCount?.value === 3
      && values.results.pageType?.value === 'TVSeason'
      && values.results.pageVisible?.value === true
      && values.results.seasonLabel?.value === 'Season 1'
      && episodeNodeCount > environment.tvSeriesSmokeTest.season1.length;
  }, 'the Season 1 episode list to load', 120000);
}

async function readEpisodeCards(environment) {
  const counts = await environment.odc.getValues({
    requests: {
      horizontal: { base: 'scene', keyPath: '#episodesList.content.0.getChildCount()' },
      vertical: { base: 'scene', keyPath: '#episodesGrid.content.getChildCount()' }
    }
  });
  const horizontalCount = counts.results.horizontal?.value ?? 0;
  const verticalCount = counts.results.vertical?.value ?? 0;
  const isHorizontal = horizontalCount > 0;
  const itemCount = isHorizontal ? horizontalCount : verticalCount;
  const contentPath = isHorizontal ? '#episodesList.content.0' : '#episodesGrid.content';
  const fields = ['title', 'itemType', 'episodeIndexNumber', 'premiereDate', 'airDate', 'dateCreated'];
  const requests = {};

  for (let itemIndex = 0; itemIndex < itemCount; itemIndex += 1) {
    for (const field of fields) {
      requests[`${itemIndex}-${field}`] = {
        base: 'scene',
        keyPath: `${contentPath}.${itemIndex}.${field}`
      };
    }
  }

  const response = await environment.odc.getValues({ requests });
  return Array.from({ length: itemCount }, (_, itemIndex) => Object.fromEntries(
    fields.map(field => [field, response.results[`${itemIndex}-${field}`]?.value])
  )).filter(item => String(item.itemType).toLowerCase() === 'episode');
}

function assertExpectedEpisodes(cards, expectedEpisodes) {
  for (const expected of expectedEpisodes) {
    const card = cards.find(candidate => Number(candidate.episodeIndexNumber) === expected.number);
    assert.ok(card, `Episode ${expected.number} should be listed.`);
    assert.equal(card.title, expected.title, `Episode ${expected.number} should have the expected title.`);

    const airedDate = card.premiereDate || card.airDate || card.dateCreated || '';
    assert.equal(
      String(airedDate).slice(0, 10),
      expected.date,
      `Episode ${expected.number} should have the expected air date.`
    );
  }
}

async function returnToHome() {
  const environment = await getAutomationEnvironment();

  for (let attempt = 0; attempt < 3; attempt += 1) {
    const state = await environment.odc.getValues({
      requests: {
        childCount: { base: 'scene', keyPath: '#dynamicPageHost.getChildCount()' },
        homeVisible: { base: 'scene', keyPath: '#homePage.visible' }
      }
    });
    if (state.results.childCount?.value === 0 && state.results.homeVisible?.value === true) return;

    await environment.ecp.sendKeypress(environment.ecp.Key.Back);
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  await waitFor(async () => {
    const state = await environment.odc.getValues({
      requests: {
        childCount: { base: 'scene', keyPath: '#dynamicPageHost.getChildCount()' },
        homeVisible: { base: 'scene', keyPath: '#homePage.visible' }
      }
    });
    return state.results.childCount?.value === 0 && state.results.homeVisible?.value === true;
  }, 'the TV series pages to return to Home');
}

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
