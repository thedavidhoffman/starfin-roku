import assert from 'node:assert/strict';
import { waitFor } from '../support/lifecycle.mjs';
import { categories, openSettings, selectRadioOption, closeAndSaveSettings } from '../support/settings.mjs';
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

  it('refreshes series playback targets without moving season focus', async function () {
    const { environment } = await openSettings(categories.tv);
    await closeAndSaveSettings(environment);
    await openConfiguredTVLibrary(environment);
    const { item, itemIndex } = await findSeries(environment);
    await openSeries(environment, itemIndex, item);
    const cards = await readSeasonCards(environment);
    await environment.ecp.sendKeypress(environment.ecp.Key.Down);
    await waitFor(async () => await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#seasonsGrid' }), 'season grid focus');
    const focusedIndex = (await environment.odc.getValue({ base: 'scene', keyPath: '#seasonsGrid.itemFocused' })).value;
    const season = cards[focusedIndex].raw;

    // Replay the current count as a controlled success notification; no server write.
    await environment.odc.setValue({ base: 'scene', keyPath: '#dynamicPageHost.1.seasonWatchedStateChange', value: {
      seasonId: season.Id, unplayedItemCount: season.UserData.UnplayedItemCount
    }});
    const response = await waitFor(async () => {
      const state = await environment.odc.getValues({ requests: {
        playbackOnly: { base: 'scene', keyPath: '#tvShowTaskAlternate.request.playbackOnly' },
        requestId: { base: 'scene', keyPath: '#tvShowTaskAlternate.request.requestId' },
        responseId: { base: 'scene', keyPath: '#tvShowTaskAlternate.response.requestId' },
        ok: { base: 'scene', keyPath: '#tvShowTaskAlternate.response.ok' },
        itemId: { base: 'scene', keyPath: '#tvShowTaskAlternate.response.itemId' },
        expectedPlay: { base: 'scene', keyPath: '#tvShowTaskAlternate.response.payload.upNextItem.Id' },
        expectedResume: { base: 'scene', keyPath: '#tvShowTaskAlternate.response.payload.resumeItem.Id' },
        play: { base: 'scene', keyPath: '#videoToolbar.playItem.Id' },
        resume: { base: 'scene', keyPath: '#videoToolbar.resumeItem.Id' }
      }});
      const values = Object.fromEntries(Object.entries(state.results).map(([key, result]) => [key, result.value]));
      if (values.ok === false) throw new Error('Playback refresh failed on the device.');
      return values.playbackOnly === true && values.ok === true
        && values.requestId === values.responseId
        && (values.play ?? '') === (values.expectedPlay ?? '')
        && (values.resume ?? '') === (values.expectedResume ?? '')
        ? values : false;
    }, 'fresh series playback targets', 60000);
    assert.equal(response.itemId, item.Id);
    assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#seasonsGrid' }), true);
    assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: '#seasonsGrid.itemFocused' })).value, focusedIndex);
    assert.deepEqual((await readSeasonCards(environment)).map(card => card.raw.Id), cards.map(card => card.raw.Id));
    await captureEvidence(this, 'tv-season-playback-refresh');
  });

  for (const [index, layout] of ['horizontal', 'vertical'].entries()) {
    it(`toggles the season summary display on and off in the ${layout} layout`, async function () {
      const { environment } = await openSettings(categories.tv);
      await selectRadioOption(environment, 'tvEpisodeListDisplayOptions', index);
      await selectRadioOption(environment, 'showSeasonSummaryCardOptions', 0);
      await closeAndSaveSettings(environment);
      let expectedSeasonId;
      let expectedEpisodeIds;

      for (const enabled of [true, false]) {
        await openSettings(categories.tv);
        const before = await environment.odc.getValue({ base: 'scene', keyPath: '#showSeasonSummaryCardOptions.checkedItem' });
        assert.equal(before.value, enabled ? 0 : 1, 'Reopening Settings should restore the previous selection.');
        await selectRadioOption(environment, 'showSeasonSummaryCardOptions', enabled ? 1 : 0);
        await closeAndSaveSettings(environment);

        await openConfiguredTVLibrary(environment);
        const { item, itemIndex } = await findSeries(environment);
        await openSeries(environment, itemIndex, item);
        const seasons = await readSeasonCards(environment);
        const season = seasons.find(card => Number(card.raw?.IndexNumber) === 1);
        assert.ok(season, 'Season 1 should be available.');
        expectedSeasonId ??= season.raw.Id;
        assert.equal(season.raw.Id, expectedSeasonId, 'Both checks must open the same season.');
        await openSeasonOne(environment, seasons);

        const visible = await environment.odc.getValue({ base: 'scene', keyPath: index === 0 ? '#episodesList.visible' : '#episodesGrid.visible' });
        assert.equal(visible.value, true, 'The requested episode layout should be visible.');
        const cards = await readEpisodeCards(environment);
        assert.equal(cards.length, environment.tvSeriesSmokeTest.season1.length + (enabled ? 1 : 0));
        assert.equal(cards.filter(card => card.itemType === 'Season').length, enabled ? 1 : 0);
        assert.equal(cards[0].itemType, enabled ? 'Season' : 'Episode');
        if (enabled) assert.equal(cards[0].itemId, expectedSeasonId);
        assertExpectedEpisodes(cards, environment.tvSeriesSmokeTest.season1);
        const episodeIds = cards.filter(card => card.itemType === 'Episode').map(card => card.itemId);
        assert.ok(episodeIds.every(Boolean), 'Every episode should retain its item ID.');
        expectedEpisodeIds ??= episodeIds;
        assert.deepEqual(episodeIds, expectedEpisodeIds, 'Toggling the summary must preserve episode identity and order.');
        await captureEvidence(this, `tv-season-summary-${layout}-${enabled ? 'on' : 'off'}`);
        await returnToHome();
      }
    });

    it(`shows episodes without a season summary in the ${layout} layout and opens season actions`, async function () {
      const { environment } = await openSettings(categories.tv);
      await selectRadioOption(environment, 'tvEpisodeListDisplayOptions', index);
      await selectRadioOption(environment, 'showSeasonSummaryCardOptions', 0);
      await closeAndSaveSettings(environment);

      await openConfiguredTVLibrary(environment);
      const { item, itemIndex } = await findSeries(environment);
      await openSeries(environment, itemIndex, item);
      const seasonCards = await readSeasonCards(environment);
      assertExpectedSeasons(seasonCards, environment.tvSeriesSmokeTest.seasons);
      const seasonIndex = seasonCards.findIndex(card => Number(card.raw?.IndexNumber) === 1);
      assert.notEqual(seasonIndex, -1);
      await environment.odc.setValue({ base: 'scene', keyPath: '#seasonsGrid.jumpToItem', value: seasonIndex });
      await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      await waitFor(async () => await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#seasonsGrid' }), 'season grid focus');
      await environment.ecp.sendKeypress(environment.ecp.Key.Option);
      await waitFor(async () => (await environment.odc.getValue({ base: 'scene', keyPath: '#overlayHost.0.subtype()' })).value === 'MediaActionsDialog', 'season actions to open');
      const dialog = await environment.odc.getValues({ requests: {
        item: { base: 'scene', keyPath: '#overlayHost.0.item' },
        options: { base: 'scene', keyPath: '#overlayHost.0.options' }
      }});
      assert.equal(dialog.results.item.value.Id, seasonCards[seasonIndex].raw.Id);
      assert.equal(dialog.results.options.value.length, 1);
      assert.equal(dialog.results.options.value[0].key, seasonCards[seasonIndex].raw.UserData?.UnplayedItemCount === 0 ? 'MarkAsUnwatched' : 'MarkAsWatched');
      await captureEvidence(this, `tv-season-actions-${layout}`);
      // Inspect and dismiss without changing the real season's watched state.
      await environment.ecp.sendKeypress(environment.ecp.Key.Back);
      await waitFor(async () => (await environment.odc.getValue({ base: 'scene', keyPath: '#overlayHost.getChildCount()' })).value === 0, 'season actions to close');
      const focus = await environment.odc.getValues({ requests: {
        index: { base: 'scene', keyPath: '#seasonsGrid.itemFocused' }
      }});
      assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#seasonsGrid' }), true);
      assert.equal(focus.results.index.value, seasonIndex);

      await openSeasonOne(environment, seasonCards);
      const episodeCards = await readEpisodeCards(environment);
      assert.ok(episodeCards.every(card => card.itemType === 'Episode'));
      assertExpectedEpisodes(episodeCards, environment.tvSeriesSmokeTest.season1);
      await captureEvidence(this, `tv-season-episodes-${layout}`);
    });
  }
});
