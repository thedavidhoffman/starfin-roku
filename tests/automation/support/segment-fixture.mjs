import assert from 'node:assert/strict';
import { value, press, focusItem, page, openLibrary, waitForVideo } from './remote-keys.mjs';
import { categories, openSettings, selectRadioOption, closeAndSaveSettings } from './settings.mjs';
import { waitFor } from './lifecycle.mjs';
import { returnToHome, stopPlaybackForCleanup, selectConfiguredEpisode } from './tv-series.mjs';

const fixtureTitle = 'Aaahh!!! Real Monsters';

export async function loadSegmentFixture(environment) {
  const [server, token, userId] = await Promise.all(['server', 'token', 'userId'].map(
    field => value(environment, `#authController.authenticatedSession.${field}`)));
  const base = (server.includes('://') ? server : `http://${server}`).replace(/\/$/, '');
  async function api(path, query = {}, body, method) {
    const url = new URL(base + path);
    url.search = new URLSearchParams({ userId, ...query }).toString();
    const response = await fetch(url, {
      method: method ?? (body === undefined ? 'GET' : 'POST'),
      headers: { 'X-Emby-Token': token, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(30000)
    });
    assert.ok(response.ok, `Fixture API ${path}: HTTP ${response.status}`);
    return response.json();
  }
  const matches = (await api('/Items', { Recursive: true, IncludeItemTypes: 'Series', SearchTerm: fixtureTitle })).Items
    .filter(item => item.Name === fixtureTitle);
  assert.equal(matches.length, 1, 'Exactly one Aaahh!!! Real Monsters series is required.');
  const series = matches[0];
  const episodeResponse = await api(`/Shows/${series.Id}/Episodes`);
  const episodes = episodeResponse.Items;
  assert.equal(episodes.length, episodeResponse.TotalRecordCount, 'Snapshot must include every episode.');
  const episode = episodes.find(item => item.ParentIndexNumber === 1 && item.IndexNumber === 1);
  assert.ok(episode, 'S1E1 must exist.');
  const segments = (await api(`/MediaSegments/${episode.Id}`)).Items;
  const ranges = {};
  for (const type of ['Intro', 'Outro']) {
    const segment = segments.find(item => item.Type === type);
    assert.ok(segment, `S1E1 requires a ${type} marker.`);
    ranges[type] = { start: segment.StartTicks / 1e7, end: segment.EndTicks / 1e7 };
    assert.ok(ranges[type].end - ranges[type].start > 15, `${type} needs a measurable test window.`);
  }
  const duration = episode.RunTimeTicks / 1e7;
  assert.ok(ranges.Outro.end >= duration - 2, 'This fixture tests credits ending at the media endpoint.');
  const next = episodes.find(item => item.ParentIndexNumber === 1 && item.IndexNumber === 2);
  assert.ok(next, 'S1E2 is required for queue continuation.');
  const seasons = (await api(`/Shows/${series.Id}/Seasons`)).Items;
  // Restore leaves before aggregates; never overwrite the original mixed history with a series toggle.
  const snapshot = [...episodes, ...seasons, series].map(item => {
    assert.ok(item.UserData, `User data required for ${item.Id}`);
    return { id: item.Id, data: structuredClone(item.UserData) };
  });
  return { api, series, episode, next, episodes, seasons, ranges, duration, snapshot, session: { server, token, userId } };
}

export async function restoreFixture(environment, fixture) {
  await stopPlaybackForCleanup(environment);
  await returnToHome();
  // The old channel has exited, so it cannot publish late playback progress after restoration.
  const failures = [];
  for (const entry of fixture.snapshot) {
    try {
      await fixture.api(`/UserItems/${entry.id}/UserData`, {}, entry.data);
    } catch (error) { failures.push(error); }
  }
  if (failures.length) throw new AggregateError(failures, 'Failed to restore fixture user data.');
  const restoredEpisodes = (await fixture.api(`/Shows/${fixture.series.Id}/Episodes`)).Items;
  const restoredById = new Map(restoredEpisodes.map(item => [item.Id, item.UserData]));
  for (const episode of fixture.episodes) {
    const restored = restoredById.get(episode.Id);
    assert.ok(restored, `Restored episode ${episode.Id} must still exist.`);
    for (const key of ['Played', 'PlaybackPositionTicks', 'PlayCount']) {
      assert.equal(restored[key], episode.UserData[key], `Restored ${episode.Id} ${key}`);
    }
  }
}

export async function openFixtureSeries(environment, fixture) {
  await openLibrary(environment, environment.tvLibrary, 'tvshows');
  await focusItem(environment, '#itemsGrid', fixture.series.Id);
  await press(environment, 'Ok');
  const path = await page(environment, 'TVShow');
  await waitFor(async () => await value(environment, `${path}.#videoToolbar.supportsWatchedActions`) === true,
    'series details and watched toolbar', 120000);
  return path;
}

export async function playFixture(environment, fixture) {
  await openFixtureSeries(environment, fixture);
  await focusItem(environment, '#seasonsGrid', fixture.episode.SeasonId);
  await press(environment, 'Ok');
  const seasonPath = await page(environment, 'TVSeason');
  // Visibility precedes the asynchronous episode response and rendered content.
  await waitFor(async () => {
    if (await value(environment, `${seasonPath}.ready`) !== true) return false;
    for (const contentPath of ['#episodesList.content.0', '#episodesGrid.content']) {
      const count = await value(environment, `${seasonPath}.${contentPath}.getChildCount()`) ?? 0;
      for (let index = 0; index < count; index++) {
        if (await value(environment, `${seasonPath}.${contentPath}.${index}.itemId`) === fixture.episode.Id) return true;
      }
    }
    return false;
  }, 'Aaahh!!! Real Monsters Season 1 to finish loading and render S1E1', 120000);
  const scoped = { ...environment, tvSeriesSmokeTest: { testEpisode: { season: 1, episode: 1 } } };
  const episode = await selectConfiguredEpisode(scoped);
  // Restart is the production zero-position action; Play can resume saved progress.
  await environment.odc.setValue({ base: 'scene', keyPath: '#mediaToolbar.restartSelected', value: true });
  await waitForVideo(environment, episode.Id);
  await waitFor(async () => await value(environment, '#mediaSegmentsTask.response.ok') === true,
    'official media segments', 30000);
}

export async function seekFixture(environment, seconds) {
  await environment.odc.setValue({ base: 'scene', keyPath: '#videoPlayer.seek', value: seconds });
}

export async function samplePlayback(environment, seconds, check) {
  const deadline = Date.now() + seconds * 1000;
  do {
    await check();
    await new Promise(resolve => setTimeout(resolve, 200));
  } while (Date.now() < deadline);
}

export async function playbackPreferences(indices) {
  const { environment } = await openSettings(categories.playback);
  const original = {};
  for (const [id, index] of Object.entries(indices)) {
    original[id] = await value(environment, `#${id}.checkedItem`);
    await selectRadioOption(environment, id, index);
  }
  await closeAndSaveSettings(environment);
  return original;
}
