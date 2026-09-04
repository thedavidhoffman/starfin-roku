import assert from 'node:assert/strict';
import { captureEvidence } from './evidence.mjs';
import { getAutomationEnvironment } from './environment.mjs';
import { waitFor } from './lifecycle.mjs';

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

async function selectConfiguredEpisode(context, environment) {
  const expected = environment.tvSeriesSmokeTest.testEpisode;
  assert.equal(expected.season, 1, 'The current TV-series fixture provides episode data for Season 1.');

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
  const requests = {};
  for (let itemIndex = 0; itemIndex < itemCount; itemIndex += 1) {
    requests[itemIndex] = {
      base: 'scene',
      keyPath: `${contentPath}.${itemIndex}.episodeIndexNumber`
    };
  }
  const response = await environment.odc.getValues({ requests });
  const itemIndex = Array.from(
    { length: itemCount },
    (_, index) => Number(response.results[index]?.value) === expected.episode ? index : -1
  ).find(index => index >= 0);
  assert.notEqual(itemIndex, undefined, `Season 1 Episode ${expected.episode} should be selectable.`);

  if (isHorizontal) {
    await environment.odc.setValue({
      base: 'scene',
      keyPath: '#episodesList.rowItemFocused',
      value: [0, itemIndex]
    });
  } else {
    await environment.odc.setValue({
      base: 'scene',
      keyPath: '#episodesGrid.itemFocused',
      value: itemIndex
    });
  }
  await captureEvidence(context, 'tv-series-library-test-episode-focused');

  await environment.odc.setValue({
    base: 'scene',
    keyPath: isHorizontal ? '#episodesList.rowItemSelected' : '#episodesGrid.itemSelected',
    value: isHorizontal ? [0, itemIndex] : itemIndex
  });

  return waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        childCount: { base: 'scene', keyPath: '#dynamicPageHost.getChildCount()' },
        pageType: { base: 'scene', keyPath: '#dynamicPageHost.3.subtype()' },
        pageVisible: { base: 'scene', keyPath: '#dynamicPageHost.3.visible' },
        playItem: { base: 'scene', keyPath: '#mediaToolbar.playItem' }
      }
    });
    const playItem = values.results.playItem?.value;
    return values.results.childCount?.value === 4
      && values.results.pageType?.value === 'TVEpisode'
      && values.results.pageVisible?.value === true
      && Number(playItem?.ParentIndexNumber) === expected.season
      && Number(playItem?.IndexNumber) === expected.episode
      ? playItem
      : false;
  }, `the Season ${expected.season} Episode ${expected.episode} detail page to load`, 120000);
}

async function startEpisodePlayback(environment, episode) {
  const expected = environment.tvSeriesSmokeTest.testEpisode;

  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#mediaToolbar.playSelected',
    value: true
  });

  return waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        playerCount: { base: 'scene', keyPath: '#playbackController.getChildCount()' },
        itemId: { base: 'scene', keyPath: '#playbackController.playRequest.itemId' },
        requestSeason: { base: 'scene', keyPath: '#playbackController.playRequest.item.ParentIndexNumber' },
        requestEpisode: { base: 'scene', keyPath: '#playbackController.playRequest.item.IndexNumber' },
        playerState: { base: 'scene', keyPath: '#videoPlayer.state' },
        position: { base: 'scene', keyPath: '#videoPlayer.position' },
        duration: { base: 'scene', keyPath: '#videoPlayer.duration' }
      }
    });
    const snapshot = {
      state: String(values.results.playerState?.value ?? '').toLowerCase(),
      position: Number(values.results.position?.value),
      duration: Number(values.results.duration?.value)
    };
    return values.results.playerCount?.value === 1
      && values.results.itemId?.value === episode.Id
      && Number(values.results.requestSeason?.value) === expected.season
      && Number(values.results.requestEpisode?.value) === expected.episode
      && snapshot.state === 'playing'
      && Number.isFinite(snapshot.position)
      && snapshot.position >= 0
      && Number.isFinite(snapshot.duration)
      && snapshot.duration > 0
      ? snapshot
      : false;
  }, 'the configured episode to start playing', 120000);
}

async function verifyPlaybackCheckpoints(environment, initialSnapshot) {
  const playbackStartedAt = Date.now();
  const checkpoints = [];
  let previousPosition = initialSnapshot.position;

  for (const seconds of [5, 10, 15, 20]) {
    const checkpointAt = playbackStartedAt + (seconds * 1000);
    let snapshot;
    while (Date.now() < checkpointAt) {
      snapshot = await readPlaybackSnapshot(environment, seconds);
      assert.equal(snapshot.playerCount, 1, `The player detached before ${seconds} seconds; ${playbackDiagnostic(snapshot)}.`);
      assert.ok(
        !['error', 'finished', 'stopped'].includes(snapshot.state),
        `Playback entered a terminal state before ${seconds} seconds; ${playbackDiagnostic(snapshot)}.`
      );

      const remaining = checkpointAt - Date.now();
      if (remaining > 0) await new Promise(resolve => setTimeout(resolve, Math.min(500, remaining)));
    }
    snapshot = await readPlaybackSnapshot(environment, seconds);
    const diagnostic = `state=${snapshot.state}, position=${snapshot.position}, duration=${snapshot.duration}`;

    assert.equal(snapshot.playerCount, 1, `The player should remain attached at ${seconds} seconds; ${diagnostic}.`);
    assert.equal(snapshot.state, 'playing', `Playback should remain active at ${seconds} seconds; ${diagnostic}.`);
    assert.ok(Number.isFinite(snapshot.duration) && snapshot.duration > 0, `Duration should be positive at ${seconds} seconds; ${diagnostic}.`);
    assert.ok(Number.isFinite(snapshot.position), `Position should be numeric at ${seconds} seconds; ${diagnostic}.`);
    assert.ok(snapshot.position > previousPosition, `Position should advance at ${seconds} seconds; previous=${previousPosition}, ${diagnostic}.`);
    assert.ok(snapshot.position < snapshot.duration, `Position should remain before duration at ${seconds} seconds; ${diagnostic}.`);

    checkpoints.push(snapshot);
    previousPosition = snapshot.position;
  }

  return checkpoints;
}

async function readPlaybackSnapshot(environment, checkpointSeconds) {
  const values = await environment.odc.getValues({
    requests: {
      playerCount: { base: 'scene', keyPath: '#playbackController.getChildCount()' },
      state: { base: 'scene', keyPath: '#videoPlayer.state' },
      position: { base: 'scene', keyPath: '#videoPlayer.position' },
      duration: { base: 'scene', keyPath: '#videoPlayer.duration' }
    }
  });
  return {
    checkpointSeconds,
    playerCount: values.results.playerCount?.value,
    state: String(values.results.state?.value ?? '').toLowerCase(),
    position: Number(values.results.position?.value),
    duration: Number(values.results.duration?.value)
  };
}

function playbackDiagnostic(snapshot) {
  return `state=${snapshot.state}, position=${snapshot.position}, duration=${snapshot.duration}`;
}

async function isPlayerAttached(environment) {
  const response = await environment.odc.getValue({
    base: 'scene',
    keyPath: '#playbackController.getChildCount()'
  });
  return response.found && response.value > 0;
}

async function stopPlayback(context, environment, episode, options = {}) {
  await requestPlayerClose(environment);
  const restoredState = await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        playerCount: { base: 'scene', keyPath: '#playbackController.getChildCount()' },
        episodeVisible: { base: 'scene', keyPath: '#dynamicPageHost.3.visible' },
        restoredItemId: { base: 'scene', keyPath: '#dynamicPageHost.3.loadRequest.itemId' },
        progressItemId: { base: 'scene', keyPath: '#dynamicPageHost.3.playbackProgressChanged.itemId' },
        progressTicks: { base: 'scene', keyPath: '#dynamicPageHost.3.playbackProgressChanged.positionTicks' },
        statusVisible: { base: 'scene', keyPath: '#statusLabel.visible' },
        statusText: { base: 'scene', keyPath: '#statusLabel.text' }
      }
    });
    const result = {
      playerCount: values.results.playerCount?.value,
      episodeVisible: values.results.episodeVisible?.value,
      restoredItemId: values.results.restoredItemId?.value,
      progressItemId: values.results.progressItemId?.value,
      progressTicks: Number(values.results.progressTicks?.value),
      statusVisible: values.results.statusVisible?.value,
      statusText: values.results.statusText?.value ?? ''
    };
    return result.playerCount === 0
      && result.episodeVisible === true
      && result.restoredItemId === episode.Id
      ? result
      : false;
  }, 'playback to stop and return to the episode page', 30000);

  if (options.verifyProgress !== false) {
    assert.equal(restoredState.progressItemId, episode.Id, 'Playback progress should return to the configured episode page.');
    assert.ok(
      Number.isFinite(restoredState.progressTicks) && restoredState.progressTicks > 0,
      `Restored playback progress should be nonzero; received ${restoredState.progressTicks}.`
    );
  }
  assert.equal(restoredState.statusVisible, false, `No application error should be visible after playback: ${restoredState.statusText}`);
  assert.equal(restoredState.statusText, '', 'No application error text should remain after playback.');
  await captureEvidence(context, 'tv-series-library-episode-playback-stopped');
}

async function stopPlaybackForCleanup(environment) {
  if (!await isPlayerAttached(environment)) return;

  await requestPlayerClose(environment);
  await waitFor(
    async () => !await isPlayerAttached(environment),
    'failed playback assertion cleanup to remove the player',
    30000
  );
}

async function requestPlayerClose(environment) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    if (!await isPlayerAttached(environment)) return;

    await environment.ecp.sendKeypress(environment.ecp.Key.Back);
    await new Promise(resolve => setTimeout(resolve, 500));
  }
}

async function returnToHome() {
  const environment = await getAutomationEnvironment();

  for (let attempt = 0; attempt < 5; attempt += 1) {
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

export {
  assertExpectedEpisodes,
  assertExpectedSeasons,
  findSeries,
  isPlayerAttached,
  openConfiguredTVLibrary,
  openSeasonOne,
  openSeries,
  readEpisodeCards,
  readPlaybackSnapshot,
  readSeasonCards,
  returnToHome,
  selectConfiguredEpisode,
  startEpisodePlayback,
  stopPlayback,
  stopPlaybackForCleanup,
  verifyPlaybackCheckpoints
};
