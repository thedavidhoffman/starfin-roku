import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { categories, openSettings, closeAndSaveSettings, selectRadioOption } from '../support/settings.mjs';
import { loadSegmentFixture, restoreFixture, openFixtureSeries } from '../support/segment-fixture.mjs';
import { value, press } from '../support/remote-keys.mjs';
import { returnToHome } from '../support/tv-series.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { captureEvidence, addEvidenceMetadata } from '../support/evidence.mjs';

describe('Starfin whole-series watched toolbar', function () {
  this.timeout(300000);
  let environment, fixture, originalBadge;

  async function waitForWatchedSnapshot(path, watched, previousRequestId = -1) {
    const episodes = await waitFor(async () => {
      const items = (await fixture.api(`/Shows/${fixture.series.Id}/Episodes`)).Items;
      assert.deepEqual(items.map(item => item.Id).sort(), fixture.episodes.map(item => item.Id).sort());
      assert.ok(items.every(item => item.UserData.Played === watched), 'all episode watched states must settle');
      return items;
    }, 'server episode watched state', 30000);
    return waitFor(async () => {
      const refresh = `${path}.#episodeCountRefresh.response`;
      assert.equal(await value(environment, `${refresh}.ok`), true);
      const requestId = await value(environment, `${refresh}.requestId`);
      assert.ok(requestId > previousRequestId, 'a new aggregate response must finish');
      const grid = `${path}.#seasonsGrid`;
      assert.equal(await value(environment, `${grid}.content.getChildCount()`), fixture.seasons.length);
      const seasons = [];
      for (let index = 0; index < fixture.seasons.length; index++) {
        const card = `${grid}.content.${index}`;
        const id = await value(environment, `${card}.itemId`);
        assert.ok(fixture.seasons.some(season => season.Id === id), `unexpected season ${id}`);
        const expectedCount = episodes.filter(item => item.SeasonId === id && !item.UserData.Played).length;
        const count = await value(environment, `${card}.raw.UserData.UnplayedItemCount`);
        assert.equal(count, expectedCount, `season ${id} unplayed count`);
        // Season badges use the aggregate count; retain Played only as diagnostic evidence.
        seasons.push({ id, unplayedCount: count, played: await value(environment, `${card}.raw.UserData.Played`) });
      }
      assert.equal(new Set(seasons.map(season => season.id)).size, fixture.seasons.length);
      assert.equal(await value(environment, `${path}.#videoToolbar.isWatched`), watched);
      return { requestId, watched, seasons };
    }, 'completed aggregate refresh and season card counts', 30000);
  }
  beforeEach(async function () {
    environment = await ensureAuthenticated();
    fixture = undefined;
    originalBadge = undefined;
    fixture = await loadSegmentFixture(environment);
    await openSettings(categories.theme);
    originalBadge = await value(environment, '#showUnwatchedEpisodeCountOptions.checkedItem');
    await closeAndSaveSettings(environment);
  });
  afterEach(async function () {
    try {
      if (fixture) await restoreFixture(environment, fixture);
    } finally {
      if (originalBadge !== undefined) {
        await openSettings(categories.theme);
        await selectRadioOption(environment, 'showUnwatchedEpisodeCountOptions', originalBadge);
        await closeAndSaveSettings(environment);
      }
      await returnToHome();
    }
  });

  for (const badges of [0, 1]) {
    for (const watched of [true, false]) {
      it(`marks the series ${watched ? 'watched' : 'unwatched'} with badges ${badges ? 'enabled' : 'disabled'} and preserves focus`, async function () {
        // Each case begins at the opposite state; the operation under test always changes it.
        await fixture.api(`/UserPlayedItems/${fixture.series.Id}`, {}, undefined, watched ? 'DELETE' : 'POST');
        await openSettings(categories.theme);
        await selectRadioOption(environment, 'showUnwatchedEpisodeCountOptions', badges);
        await closeAndSaveSettings(environment);
        const path = await openFixtureSeries(environment, fixture);
        const toolbar = `${path}.#videoToolbar`;
        const initial = await waitForWatchedSnapshot(path, !watched);
        const seasonsBefore = await value(environment, '#seasonsGrid.content.getChildCount()');
        const focusedSeason = await value(environment, '#seasonsGrid.itemFocused');
        await environment.odc.callFunc({ base: 'scene', keyPath: toolbar, funcName: 'resetFocus' });
        await press(environment, 'Right');
        const beforeButton = watched ? 'markWatchedButton' : 'markUnwatchedButton';
        await waitFor(() => environment.odc.hasFocus({ base: 'scene', keyPath: `${toolbar}.#${beforeButton}` }), 'watched action focus');
        await press(environment, 'Ok');
        const afterButton = watched ? 'markUnwatchedButton' : 'markWatchedButton';
        await waitFor(async () => await value(environment, `${toolbar}.isWatched`) === watched
          && await environment.odc.hasFocus({ base: 'scene', keyPath: `${toolbar}.#${afterButton}` }), 'watched commit and replacement focus');
        const committed = await waitForWatchedSnapshot(path, watched, initial.requestId);
        addEvidenceMetadata(this, { initial, committed });
        assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: `${toolbar}.#${afterButton}` }), true);
        assert.equal(await value(environment, '#seasonsGrid.content.getChildCount()'), seasonsBefore);
        assert.equal(await value(environment, '#seasonsGrid.itemFocused'), focusedSeason);
        await captureEvidence(this, `series-${watched ? 'watched' : 'unwatched'}-badges-${badges}`);
        await returnToHome();
        const reopened = await openFixtureSeries(environment, fixture);
        addEvidenceMetadata(this, { reopened: await waitForWatchedSnapshot(reopened, watched) });
      });
    }
  }
  for (const focusedAction of ['watched', 'random']) {
    it(`preserves ${focusedAction} focus during background watched reconciliation`, async function () {
      await fixture.api(`/UserPlayedItems/${fixture.series.Id}`, {}, undefined, 'DELETE');
      const path = await openFixtureSeries(environment, fixture);
      const toolbar = `${path}.#videoToolbar`;
      const initial = await waitForWatchedSnapshot(path, false);
      await environment.odc.callFunc({ base: 'scene', keyPath: toolbar, funcName: 'resetFocus' });
      await press(environment, 'Right');
      await waitFor(() => environment.odc.hasFocus({ base: 'scene', keyPath: `${toolbar}.#markWatchedButton` }), 'watched action focus');
      if (focusedAction === 'random') await press(environment, 'Right');
      const before = focusedAction === 'random' ? 'randomPlayButton' : 'markWatchedButton';
      await waitFor(() => environment.odc.hasFocus({ base: 'scene', keyPath: `${toolbar}.#${before}` }), 'background reconciliation initial focus');
      await fixture.api(`/UserPlayedItems/${fixture.series.Id}`, {}, undefined, 'POST');
      // Supply the existing refresher request boundary; the real task fetches and publishes its response.
      await environment.odc.setValue({
        base: 'scene', keyPath: `${path}.#episodeCountRefresh.request`,
        value: { ...fixture.session, items: [fixture.series, ...fixture.seasons], refreshWhenCountHidden: true }
      });
      const after = focusedAction === 'random' ? 'randomPlayButton' : 'markUnwatchedButton';
      addEvidenceMetadata(this, { initial, committed: await waitForWatchedSnapshot(path, true, initial.requestId) });
      assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: `${toolbar}.#${after}` }), true);
      await captureEvidence(this, `series-background-focus-${focusedAction}`);
    });
  }

});
