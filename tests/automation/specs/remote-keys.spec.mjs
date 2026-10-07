import assert from 'node:assert/strict';
import { ensureAuthenticated, relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { addEvidenceMetadata, captureEvidence } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { findSeries, openConfiguredTVLibrary, openSeries, openSeasonOne, readSeasonCards, selectConfiguredEpisode } from '../support/tv-series.mjs';
import { value, set, press, page, getItem, openLibrary, focusItem, shelfItem, homeShelfItem, waitForVideo, readPlaybackQueue, assertNoPlayback, assertFocus, closeVideo, openMovie } from '../support/remote-keys.mjs';

async function seasonEpisode(environment) {
  await openConfiguredTVLibrary(environment);
  const series = await findSeries(environment);
  await openSeries(environment, series.itemIndex, series.item);
  await openSeasonOne(environment, await readSeasonCards(environment));
  const episode = await selectConfiguredEpisode(environment);
  await press(environment, 'Back');
  const destination = await page(environment, 'TVSeason');
  const horizontal = (await value(environment, `${destination}.#episodesList.content.0.getChildCount()`)) > 0;
  const focus = await focusItem(environment, `${destination}.#${horizontal ? 'episodesList' : 'episodesGrid'}`, episode.Id, horizontal);
  return { episode, destination, focus };
}

describe('Starfin remote OK and PLAY workflows', function () {
  this.timeout(240000);

  afterEach(async function () {
    try {
      if (this.currentTest?.state === 'failed') {
        await captureEvidence(this, `before cleanup ${this.currentTest.fullTitle()}`, { failure: true });
      }
    } catch (error) {
      console.warn(`Unable to capture failure evidence before cleanup: ${error.message}`);
    } finally {
      // Relaunch cleans players, overlays, and navigation between cases.
      await relaunchAuthenticatedStarfin();
    }
  });

  for (const key of ['Ok', 'Play']) {
    it(`${key} on a library movie ${key === 'Ok' ? 'opens details' : 'plays directly and restores item focus'}`, async function () {
      const environment = await ensureAuthenticated();
      const destination = await openLibrary(environment, environment.movieLibrary, 'movies');
      const id = environment.deepLinkCases.movieId;
      const focus = await focusItem(environment, `${destination}.#itemsGrid`, id);
      await press(environment, key);
      if (key === 'Ok') {
        const details = await page(environment, 'Movie');
        await waitFor(async () => await value(environment, `${details}.loadRequest.itemId`) === id, 'selected movie details');
        await assertNoPlayback(environment);
      } else {
        await waitForVideo(environment, id);
        assert.equal(await value(environment, '#dynamicPageHost.getChildCount()'), 1, 'PLAY must not create movie details.');
        await closeVideo(environment, destination, focus);
      }
    });

    for (const row of [
      { kind: 'latest', label: 'Recently Added', types: ['Movie', 'Episode'] },
      { kind: 'continueWatching', label: 'Continue Watching', types: ['Movie', 'Episode'] },
      { kind: 'nextUp', label: 'Next Up', types: ['Episode'] }
    ]) {
      for (const type of row.types) {
        it(`${key} on a ${row.label} ${type} ${key === 'Ok' ? 'opens details' : 'plays and restores the shelf item'}`, async function () {
          const environment = await ensureAuthenticated();
          const selected = await homeShelfItem(environment, row.kind, type);
          addEvidenceMetadata(this, {
            homeRowKey: selected.rowKey, itemId: selected.id, itemType: type,
            savedPositionTicks: selected.savedPositionTicks
          });
          await press(environment, key);
          if (key === 'Ok') {
            const details = await page(environment, type === 'Movie' ? 'Movie' : 'TVEpisode');
            assert.equal(await value(environment, `${details}.loadRequest.itemId`), selected.id);
            await assertNoPlayback(environment);
          } else {
            await waitForVideo(environment, selected.id);
            assert.equal(await value(environment, '#dynamicPageHost.getChildCount()'), 0, 'Home PLAY must not create details.');
            if (row.kind === 'continueWatching') {
              assert.equal(await value(environment, '#playbackController.0.#playbackInfoTask.response.startPositionTicks'), selected.savedPositionTicks,
                'Continue Watching must resume from the selected item saved position.');
            }
            await closeVideo(environment, '#homePage', selected.focus);
          }
        });
      }
    }

    it(`${key} on a Search movie ${key === 'Ok' ? 'opens details' : 'plays and restores the result'}`, async function () {
      const environment = await ensureAuthenticated();
      const movie = await getItem(environment, environment.deepLinkCases.movieId, 'Movie');
      await set(environment, '#header.searchSelected', true);
      const destination = await page(environment, 'Search');
      await set(environment, `${destination}.#keyboard.text`, movie.Name);
      await set(environment, `${destination}.#searchButton.buttonSelected`, true);
      await waitFor(async () => await value(environment, `${destination}.#searchTask.response.query`) === movie.Name
        && await value(environment, `${destination}.#searchTask.response.ok`) === true
        && await value(environment, '#loadingSpinner.visible') === false, 'completed movie search', 45000);
      const { focus } = await shelfItem(environment, `${destination}.#resultsGroup`, movie.Id, 'Movie');
      await press(environment, key);
      if (key === 'Ok') {
        const details = await page(environment, 'Movie');
        await waitFor(async () => await value(environment, `${details}.loadRequest.itemId`) === movie.Id, 'Search movie details');
        await assertNoPlayback(environment);
      } else {
        await waitForVideo(environment, movie.Id);
        assert.equal(await value(environment, '#dynamicPageHost.getChildCount()'), 1);
        await closeVideo(environment, destination, focus);
      }
    });

    it(`${key} on a season episode ${key === 'Ok' ? 'opens details' : 'plays its queue and restores the episode'}`, async function () {
      const environment = await ensureAuthenticated();
      const { episode, destination, focus } = await seasonEpisode(environment);
      await press(environment, key);
      if (key === 'Ok') {
        const details = await page(environment, 'TVEpisode');
        await waitFor(async () => await value(environment, `${details}.#mediaToolbar.playItem.Id`) === episode.Id, 'selected episode details');
        await assertNoPlayback(environment);
      } else {
        await waitForVideo(environment, episode.Id);
        const queue = await readPlaybackQueue(environment);
        assert.equal(queue.currentItemId, episode.Id);
        assert.equal(await value(environment, '#dynamicPageHost.getChildCount()'), 3, 'PLAY must not create episode details.');
        await closeVideo(environment, destination, focus);
      }
    });
  }

  it('PLAY on movie description focus launches and returns to movie details', async function () {
    const environment = await ensureAuthenticated();
    const movie = await openMovie(environment);
    await environment.odc.focusNode({ base: 'scene', keyPath: `${movie.details}.#overviewDescription` });
    await press(environment, 'Play');
    await waitForVideo(environment, movie.id);
    await closeVideo(environment, movie.details);
    assert.equal(await value(environment, `${movie.details}.loadRequest.itemId`), movie.id);
  });

  it('PLAY on episode description focus launches and returns to episode details', async function () {
    const environment = await ensureAuthenticated();
    const { episode } = await seasonEpisode(environment);
    await press(environment, 'Ok');
    const details = await page(environment, 'TVEpisode');
    await waitFor(async () => await value(environment, `${details}.#mediaToolbar.playItem.Id`) === episode.Id
      && Boolean(await value(environment, `${details}.#mediaToolbar.mediaInfoText`))
      && await value(environment, '#loadingSpinner.visible') === false, 'loaded episode metadata');
    await environment.odc.focusNode({ base: 'scene', keyPath: `${details}.#overviewDescription` });
    await press(environment, 'Play');
    await waitForVideo(environment, episode.Id);
    await closeVideo(environment, details);
  });

  for (const key of ['Back', 'Ok']) {
    it(`${key} on next-episode prompt after season PLAY ${key === 'Back' ? 'cancels to the season' : 'continues and retains the season destination'}`, async function () {
      const environment = await ensureAuthenticated();
      const { episode, destination, focus } = await seasonEpisode(environment);
      await press(environment, 'Play');
      await waitForVideo(environment, episode.Id);
      const queue = await readPlaybackQueue(environment);
      assert.equal(queue.nextItemPlayback, 'show-up-next', 'Run with the automation default next-item prompt setting.');
      assert.ok(queue.nextItemId, 'Configured episode needs a following episode.');
      const nextId = queue.nextItemId;
      const duration = await value(environment, '#videoPlayer.duration');
      assert.ok(duration > 5, 'Episode duration must allow a completion seek.');
      // Seek real playback near the end so the normal completion path presents the prompt.
      await set(environment, '#videoPlayer.seek', duration - 2);
      const prompt = await page(environment, 'TVEpisodeUpNextAutoPlay');
      assert.equal(await value(environment, `${prompt}.autoPlayRequest.nextItem.itemId`), nextId);
      await press(environment, key);
      if (key === 'Ok') {
        await waitForVideo(environment, nextId);
        const content = `${focus.control}.content${focus.row ? '.0' : ''}`;
        const count = await value(environment, `${content}.getChildCount()`);
        let nextIndex = -1;
        for (let index = 0; index < count; index++) {
          if (await value(environment, `${content}.${index}.raw.Id`) === nextId) nextIndex = index;
        }
        assert.ok(nextIndex >= 0, 'The following episode must be present in the originating season.');
        // Season progress restores focus to the latest played episode after queue advancement.
        await closeVideo(environment, destination, {
          ...focus, id: nextId, position: focus.row ? [0, nextIndex] : nextIndex
        });
      } else {
        await assertNoPlayback(environment);
        await assertFocus(environment, destination, focus);
      }
    });
  }

  it('PLAY on a My Media library does not launch or navigate', async function () {
    const environment = await ensureAuthenticated();
    const { focus } = await shelfItem(environment, '#shelvesGroup', undefined, 'CollectionFolder');
    const count = await value(environment, '#dynamicPageHost.getChildCount()');
    await press(environment, 'Play');
    await assertNoPlayback(environment);
    assert.equal(await value(environment, '#dynamicPageHost.getChildCount()'), count);
    await assertFocus(environment, '#homePage', focus);
  });

  it('PLAY while a library sort dialog has focus does not play the underlying movie', async function () {
    const environment = await ensureAuthenticated();
    const destination = await openLibrary(environment, environment.movieLibrary, 'movies');
    await focusItem(environment, `${destination}.#itemsGrid`, environment.deepLinkCases.movieId);
    await environment.odc.focusNode({ base: 'scene', keyPath: `${destination}.#browseByButton` });
    await press(environment, 'Ok');
    await waitFor(async () => await value(environment, '#overlayHost.getChildCount()') === 1, 'library sort dialog');
    assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#overlayHost' }), true);
    await press(environment, 'Play');
    await assertNoPlayback(environment);
    assert.equal(await value(environment, '#overlayHost.getChildCount()'), 1);
    assert.equal(await value(environment, `${destination}.visible`), true);
  });
});
