import assert from 'node:assert/strict';
import { ensureAuthenticated, relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { value, set, press, page, getItem, homeShelfItem, focusHomeItem } from '../support/remote-keys.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { startHomeRefreshFixture } from '../support/home-refresh-fixture.mjs';

// Writes are confined to the test account and restored even after assertion failures.
describe('Home lifecycle reconciliation', function () {
  this.timeout(240000);
  let environment, api, snapshots;

  beforeEach(async function () {
    environment = await ensureAuthenticated();
    snapshots = new Map();
    const [server, token, userId] = await Promise.all(['server', 'token', 'userId'].map(
      field => value(environment, `#authController.authenticatedSession.${field}`)));
    const base = (server.includes('://') ? server : `http://${server}`).replace(/\/$/, '');
    api = async (path, query = {}, body) => {
      const url = new URL(base + path);
      url.search = new URLSearchParams({ userId, ...query });
      const response = await fetch(url, {
        method: body === undefined ? 'GET' : 'POST',
        headers: { 'X-Emby-Token': token, 'Content-Type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(30000)
      });
      assert.ok(response.ok, `${path}: HTTP ${response.status}`);
      const text = await response.text();
      return text ? JSON.parse(text) : undefined;
    };
  });

  afterEach(async function () {
    try {
      // Stop audio while its durable reporter is still attached and let writes settle.
      const count = await value(environment, '#dynamicPageHost.getChildCount()');
      for (let i = 0; i < count; i++) {
        const path = `#dynamicPageHost.${i}`;
        if (await value(environment, `${path}.subtype()`) === 'AudioPlayer') {
          await environment.odc.callFunc({ base: 'scene', keyPath: path, funcName: 'deactivate' });
        }
      }
      const finalReportId = await value(environment, '#audioPlaybackReporter.mediaChange.reportId');
      await waitFor(async () => {
        if (!finalReportId) return true;
        const reportId = await value(environment, '#audioPlaybackReporter.mediaChange.reportId');
        const state = await value(environment, '#audioPlaybackReporter.mediaChange.reportState');
        return reportId === finalReportId && ['saved', 'failed'].includes(state);
      }, 'audio terminal reporting before fixture restoration', 45000);
    } finally {
      // Exiting prevents any further playback writes from racing restoration.
      await press(environment, 'Home');
      const failures = [];
      for (const [id, data] of snapshots) {
        try { await api(`/UserItems/${id}/UserData`, {}, data); }
        catch (error) { failures.push(error); }
      }
      await relaunchAuthenticatedStarfin();
      if (failures.length) throw new AggregateError(failures, 'Home fixture cleanup failed');
    }
  });

  async function snapshot(item) {
    assert.ok(item.UserData, 'The fixture requires account-specific user data');
    snapshots.set(item.Id, structuredClone(item.UserData));
  }

  async function findHomeItem(id, rowKey) {
    const count = await value(environment, '#shelvesGroup.getChildCount()');
    for (let row = 0; row < count; row++) {
      const shelf = `#shelvesGroup.${row}`;
      if (rowKey && await value(environment, `${shelf}.rowContent.rowKey`) !== rowKey) continue;
      const size = await value(environment, `${shelf}.rowContent.getChildCount()`);
      for (let index = 0; index < size; index++) {
        const raw = `${shelf}.rowContent.${index}.raw`;
        if (await value(environment, `${raw}.Id`) === id) {
          // SceneGraph assocarrays are case-insensitive; serialized JS objects are not.
          return { Id: id, UserData: {
            Played: await value(environment, `${raw}.UserData.Played`),
            PlaybackPositionTicks: await value(environment, `${raw}.UserData.PlaybackPositionTicks`)
          } };
        }
      }
    }
    return undefined;
  }

  it('reconciles a detail watched change with Jellyfin Recently Added results', async function () {
    const selected = await homeShelfItem(environment, 'latest', 'Movie');
    const original = await getItem(environment, selected.id, 'Movie');
    await snapshot(original);
    await press(environment, 'Ok');
    const details = await page(environment, 'Movie');
    const watched = !original.UserData.Played;
    await waitFor(async () => await value(environment, `${details}.#mediaToolbar.isWatched`) === original.UserData.Played,
      'movie details loaded');
    await set(environment, `${details}.#mediaToolbar.${watched ? 'markAsWatchedSelected' : 'markAsUnwatchedSelected'}`, true);
    await waitFor(async () => (await getItem(environment, selected.id, 'Movie')).UserData.Played === watched,
      'independent server watched commit');
    await waitFor(async () => {
      const itemId = await value(environment, `${details}.watchedStateChanged.itemId`);
      const isWatched = await value(environment, `${details}.watchedStateChanged.isWatched`);
      return itemId === selected.id && isWatched === watched;
    }, 'movie details accepted watched response');
    await waitFor(async () => (await findHomeItem(selected.id, selected.rowKey))?.UserData.Played === watched,
      'local watched change on the retained Home card');
    const latest = await api('/Items/Latest', { parentId: selected.rowKey.slice(7), limit: 25, fields: 'Genres' });
    const expected = latest.find(item => item.Id === selected.id);
    await press(environment, 'Back');
    await waitFor(async () => {
      if (await value(environment, '#homePage.visible') !== true) return false;
      const card = await findHomeItem(selected.id, selected.rowKey);
      // Jellyfin may exclude played items from Latest according to account preferences.
      return expected ? card?.UserData.Played === expected.UserData.Played : card === undefined;
    }, 'Recently Added membership and watched state matching Jellyfin after return');
  });

  it('restores a usable Home shelf after acknowledgment', async function () {
    const selected = await homeShelfItem(environment, 'latest', 'Movie');
    await environment.odc.callFunc({ base: 'scene', keyPath: '', funcName: 'showMessage', funcParams: ['Home acknowledgment regression'] });
    await waitFor(async () => await value(environment, '#messageOverlayHost.getChildCount()') > 0, 'acknowledgment');
    await press(environment, 'Ok');
    await waitFor(async () => await value(environment, '#messageOverlayHost.getChildCount()') === 0, 'acknowledgment dismissal');
    await press(environment, 'Ok');
    const details = await page(environment, 'Movie');
    assert.equal(await value(environment, `${details}.loadRequest.itemId`), selected.id);
  });

  it('restores the retained shelf after a blocking refresh HTTP failure is acknowledged', async function () {
    const selected = await homeShelfItem(environment, 'latest', 'Movie');
    const movie = await getItem(environment, selected.id, 'Movie');
    const originalRequest = await value(environment, '#homePage.loadRequest');
    const fixture = await startHomeRefreshFixture(environment.selectedDevice.host, movie);
    const homeCall = (funcName, ...funcParams) => environment.odc.callFunc({
      base: 'scene', keyPath: '#homePage', funcName, funcParams
    });
    try {
      // Populate real Home tasks and shelves, then control only their HTTP boundary.
      await set(environment, '#homePage.loadRequest', {
        ...originalRequest, server: fixture.url, token: 'home-fixture-token',
        permissions: { canAccessLiveTv: false }, homePreferences: { latestItemsExcludes: [] }
      });
      await homeCall('activate', true);
      await waitFor(async () => await value(environment, '#homePage.ready') === true, 'fixture Home loaded');
      const retained = await homeShelfItem(environment, 'latest', 'Movie');
      fixture.holdRefresh();
      await homeCall('deactivate');
      await homeCall('recordMediaChange', {
        itemId: 'fixture-unlisted-movie', itemType: 'Movie', action: 'progress', positionTicks: 100000000
      });
      await homeCall('activate');
      await waitFor(() => fixture.hasPending('continueWatching') && fixture.hasPending('nextUp'),
        'both blocking Home HTTP requests');
      assert.equal(await value(environment, '#homePage.visible'), false);
      assert.equal(await value(environment, '#loadingSpinner.control'), 'start');

      fixture.release('continueWatching', 503);
      await waitFor(async () => await value(environment, '#continueWatchingTask.response.status') === 503,
        'real task HTTP failure');
      assert.equal(await value(environment, '#homePage.visible'), false, 'Home stays hidden until the final core response');
      assert.equal(await value(environment, '#loadingSpinner.control'), 'start');
      assert.equal(await value(environment, '#messageOverlayHost.getChildCount()'), 0);

      fixture.release('nextUp', 200);
      await waitFor(async () => (await value(environment, '#messageOverlayHost.0.message'))?.includes('Continue Watching'),
        'refresh error acknowledgment');
      assert.equal(await value(environment, '#homePage.visible'), true);
      assert.equal(await value(environment, '#loadingSpinner.control'), 'stop');
      await press(environment, 'Ok');
      await waitFor(async () => await value(environment, '#messageOverlayHost.getChildCount()') === 0,
        'refresh acknowledgment dismissed');
      assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: `${retained.shelf}.#items` }), true);
      await press(environment, 'Ok');
      const details = await page(environment, 'Movie');
      assert.equal(await value(environment, `${details}.loadRequest.itemId`), movie.Id,
        'the retained item remains usable after acknowledgment');
    } finally {
      try {
        await homeCall('deactivate');
        await set(environment, '#homePage.loadRequest', originalRequest);
      } finally {
        await fixture.close();
      }
    }
  });

  it('reloads an empty Recently Added shelf after an absent item becomes unwatched', async function () {
    const selected = await homeShelfItem(environment, 'latest', 'Movie');
    const movie = await getItem(environment, selected.id, 'Movie');
    const originalRequest = await value(environment, '#homePage.loadRequest');
    const fixture = await startHomeRefreshFixture(environment.selectedDevice.host, movie, []);
    const homeCall = (funcName, ...funcParams) => environment.odc.callFunc({
      base: 'scene', keyPath: '#homePage', funcName, funcParams
    });
    try {
      await set(environment, '#homePage.loadRequest', {
        ...originalRequest, server: fixture.url, token: 'home-fixture-token',
        permissions: { canAccessLiveTv: false }, homePreferences: { latestItemsExcludes: [] }
      });
      await homeCall('activate', true);
      await waitFor(async () => {
        if (fixture.latestRequestCount === 0 || await value(environment, '#homePage.ready') !== true) return false;
        const count = await value(environment, '#homePage.getChildCount()');
        for (let i = 0; i < count; i++) {
          if (await value(environment, `#homePage.${i}.subtype()`) === 'LatestMediaTask') return false;
        }
        return true;
      }, 'initial empty Recently Added snapshot');
      assert.equal(await findHomeItem(movie.Id, 'latest:fixture-movies'), undefined);
      await homeCall('deactivate');
      // Model the accepted server mutation; this fixture never changes real account data.
      fixture.setLatestItems([{ ...movie, UserData: { ...movie.UserData, Played: false } }]);
      await homeCall('recordMediaChange', {
        itemId: movie.Id, itemType: 'Movie', action: 'watched', value: false
      });
      await homeCall('activate');
      await waitFor(async () => (await findHomeItem(movie.Id, 'latest:fixture-movies'))?.UserData.Played === false,
        'newly unwatched movie restored through a Recently Added HTTP reload');
      assert.ok(fixture.latestRequestCount >= 2, 'The return must request a new Latest snapshot');
      await focusHomeItem(environment, 'latest:fixture-movies', movie.Id);
    } finally {
      try {
        await homeCall('deactivate');
        await set(environment, '#homePage.loadRequest', originalRequest);
      } finally {
        await fixture.close();
      }
    }
  });

  async function audioFixture() {
    const configured = process.env.STARFIN_AUTOMATION_AUDIO_ITEM_ID;
    let item;
    if (configured) item = await getItem(environment, configured, 'AudioBook');
    else {
      const response = await api('/Items', { Recursive: true, IncludeItemTypes: 'AudioBook', Limit: 1000 });
      item = response.Items.find(candidate => candidate.RunTimeTicks >= 1800 * 1e7);
    }
    assert.ok(item, 'Provide STARFIN_AUTOMATION_AUDIO_ITEM_ID for a seekable AudioBook item at least thirty minutes long');
    assert.ok(item.RunTimeTicks >= 1800 * 1e7, 'Audiobook resume fixture must be at least thirty minutes long');
    await snapshot(item);
    const ticks = Math.floor(item.RunTimeTicks / 1e7 / 2) * 1e7;
    await api(`/UserItems/${item.Id}/UserData`, {}, { ...item.UserData, Played: false, PlaybackPositionTicks: ticks });
    const seeded = await getItem(environment, item.Id, 'AudioBook');
    assert.equal(seeded.UserData.PlaybackPositionTicks, ticks, 'Jellyfin must retain the fixture bookmark within its configured audiobook resume thresholds');
    return { item: seeded, ticks };
  }

  async function openAudio(item) {
    await environment.odc.callFunc({ base: 'scene', keyPath: '#homePage', funcName: 'activate', funcParams: [true] });
    await waitFor(async () => await value(environment, '#homePage.ready') === true, 'Home audiobook refresh');
    await focusHomeItem(environment, 'continueListening', item.Id);
    await press(environment, 'Ok');
    const path = await page(environment, 'AudioPlayer');
    await waitFor(async () => await value(environment, `${path}.#player.state`) === 'playing', 'audio playback', 45000);
    return path;
  }

  // Re-enable when the automation account has a seekable AudioBook fixture.
  it.skip('saves an interrupted audio position and resumes it when reopened', async function () {
    const { item, ticks } = await audioFixture();
    const player = await openAudio(item);
    const target = ticks / 1e7 + 20;
    await set(environment, `${player}.#player.seek`, target);
    await waitFor(async () => await value(environment, `${player}.#player.position`) >= target, 'audio seek');
    await press(environment, 'Back');
    let saved;
    try {
      saved = await waitFor(async () => {
        const latest = await getItem(environment, item.Id, 'AudioBook');
        return latest.UserData.PlaybackPositionTicks >= target * 1e7 ? latest : false;
      }, 'independent persisted audio bookmark', 45000);
    } catch (error) {
      const latest = await getItem(environment, item.Id, 'AudioBook');
      error.message += ` expectedTicks=${target * 1e7}, actualTicks=${latest.UserData.PlaybackPositionTicks}, reportState=${await value(environment, '#audioPlaybackReporter.mediaChange.reportState')}, reportedTicks=${await value(environment, '#audioPlaybackReporter.mediaChange.positionTicks')}, finished=${await value(environment, '#audioPlaybackReporter.mediaChange.isFinished')}.`;
      throw error;
    }
    await waitFor(async () => (await findHomeItem(item.Id, 'continueListening'))?.UserData.PlaybackPositionTicks >= target * 1e7,
      'Continue Listening after terminal save');
    const reopened = await openAudio(saved);
    await waitFor(async () => await value(environment, `${reopened}.#player.position`) >= target - 1, 'saved audio resume');
  });

  // Re-enable when the automation account has a seekable AudioBook fixture.
  it.skip('reports audio completion and removes the item from Continue Listening', async function () {
    const { item } = await audioFixture();
    const player = await openAudio(item);
    await set(environment, `${player}.#player.seek`, item.RunTimeTicks / 1e7 - 3);
    await waitFor(async () => await value(environment, `${player}.#player.state`) === 'finished', 'audio completion', 45000);
    await waitFor(async () => await value(environment, '#audioPlaybackReporter.mediaChange.reportState') === 'saved', 'terminal save', 45000);
    await press(environment, 'Back');
    await waitFor(async () => await value(environment, '#homePage.visible') === true && await value(environment, '#homePage.ready') === true,
      'Home after completed audio');
    const serverItems = (await api('/UserItems/Resume', { MediaTypes: 'Audio' })).Items;
    assert.equal(serverItems.some(entry => entry.Id === item.Id), false, 'Jellyfin no longer considers the item resumable');
    assert.equal(await findHomeItem(item.Id, 'continueListening'), undefined);
  });
});
