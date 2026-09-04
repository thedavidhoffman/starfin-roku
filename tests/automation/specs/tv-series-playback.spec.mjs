import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { addEvidenceMetadata, captureEvidence } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import {
  findSeries,
  isPlayerAttached,
  openConfiguredTVLibrary,
  openSeasonOne,
  openSeries,
  readPlaybackSnapshot,
  readSeasonCards,
  returnToHome,
  selectConfiguredEpisode,
  startEpisodePlayback,
  stopPlayback,
  stopPlaybackForCleanup,
  verifyPlaybackCheckpoints
} from '../support/tv-series.mjs';

async function openConfiguredEpisode(context, environment) {
  await openConfiguredTVLibrary(environment);
  const { item, itemIndex } = await findSeries(environment);
  await openSeries(environment, itemIndex, item);
  await captureEvidence(context, 'tv-series-playback-series-page');

  const seasonCards = await readSeasonCards(environment);
  await openSeasonOne(environment, seasonCards);
  await captureEvidence(context, 'tv-series-playback-season-1-page');

  const episode = await selectConfiguredEpisode(context, environment);
  await captureEvidence(context, 'tv-series-playback-episode-detail');
  return episode;
}

async function runWithPlaybackCleanup(environment, operation) {
  let playbackStopped = false;
  try {
    await operation(async () => {
      playbackStopped = true;
    });
  } finally {
    if (!playbackStopped && await isPlayerAttached(environment)) {
      await stopPlaybackForCleanup(environment);
    }
  }
}

async function waitForPlayerState(environment, expectedState, description) {
  return waitFor(async () => {
    const snapshot = await readPlaybackSnapshot(environment, undefined);
    if (['error', 'finished', 'stopped'].includes(snapshot.state) && snapshot.state !== expectedState) {
      throw new Error(`Playback entered ${snapshot.state} at position ${snapshot.position} of ${snapshot.duration}.`);
    }
    return snapshot.playerCount === 1 && snapshot.state === expectedState ? snapshot : false;
  }, description, 30000);
}

async function waitForEpisodePlayback(environment, season, episode, description) {
  return waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        playerCount: { base: 'scene', keyPath: '#playbackController.getChildCount()' },
        itemId: { base: 'scene', keyPath: '#playbackController.0.playRequest.itemId' },
        season: { base: 'scene', keyPath: '#playbackController.0.playRequest.item.ParentIndexNumber' },
        episode: { base: 'scene', keyPath: '#playbackController.0.playRequest.item.IndexNumber' },
        state: { base: 'scene', keyPath: '#videoPlayer.state' },
        position: { base: 'scene', keyPath: '#videoPlayer.position' },
        duration: { base: 'scene', keyPath: '#videoPlayer.duration' }
      }
    });
    const state = String(values.results.state?.value ?? '').toLowerCase();
    if (state === 'error') throw new Error(`Playback failed while loading Season ${season} Episode ${episode}.`);
    return values.results.playerCount?.value === 1
      && Number(values.results.season?.value) === season
      && Number(values.results.episode?.value) === episode
      && state === 'playing'
      ? {
          itemId: values.results.itemId?.value,
          season,
          episode,
          state,
          position: Number(values.results.position?.value),
          duration: Number(values.results.duration?.value)
        }
      : false;
  }, description, 120000);
}

describe('Starfin TV episode playback', function () {
  afterEach(async function () {
    await returnToHome();
  });

  it('plays the configured episode through the 20-second checkpoint', async function () {
    const environment = await ensureAuthenticated();
    const episode = await openConfiguredEpisode(this, environment);

    await runWithPlaybackCleanup(environment, async markStopped => {
      const initialSnapshot = await startEpisodePlayback(environment, episode);
      const checkpoints = await verifyPlaybackCheckpoints(environment, initialSnapshot);
      addEvidenceMetadata(this, { playback: { initial: initialSnapshot, checkpoints } });

      await stopPlayback(this, environment, episode);
      markStopped();
    });
  });

  it('pauses and resumes the configured episode', async function () {
    const environment = await ensureAuthenticated();
    const episode = await openConfiguredEpisode(this, environment);

    await runWithPlaybackCleanup(environment, async markStopped => {
      const started = await startEpisodePlayback(environment, episode);
      await waitFor(async () => {
        const snapshot = await readPlaybackSnapshot(environment, undefined);
        return snapshot.state === 'playing' && snapshot.position > started.position + 2 ? snapshot : false;
      }, 'playback position to advance before pausing', 15000);

      await environment.ecp.sendKeypress(environment.ecp.Key.Play);
      const paused = await waitForPlayerState(environment, 'paused', 'the configured episode to pause');
      await new Promise(resolve => setTimeout(resolve, 3000));
      const stillPaused = await readPlaybackSnapshot(environment, undefined);
      assert.equal(stillPaused.state, 'paused', 'Playback should remain paused.');
      assert.ok(
        Math.abs(stillPaused.position - paused.position) <= 1,
        `Paused position should remain stable; before=${paused.position}, after=${stillPaused.position}.`
      );

      await environment.ecp.sendKeypress(environment.ecp.Key.Play);
      const resumed = await waitForPlayerState(environment, 'playing', 'the configured episode to resume');
      const advanced = await waitFor(async () => {
        const snapshot = await readPlaybackSnapshot(environment, undefined);
        return snapshot.state === 'playing' && snapshot.position > resumed.position + 2 ? snapshot : false;
      }, 'resumed playback position to advance', 15000);
      addEvidenceMetadata(this, { pauseResume: { paused, stillPaused, resumed, advanced } });

      await stopPlayback(this, environment, episode);
      markStopped();
    });
  });

  it('plays the next episode and returns to the previous episode', async function () {
    const environment = await ensureAuthenticated();
    const episode = await openConfiguredEpisode(this, environment);
    const expected = environment.tvSeriesSmokeTest.testEpisode;

    await runWithPlaybackCleanup(environment, async markStopped => {
      await startEpisodePlayback(environment, episode);
      await waitFor(async () => {
        const response = await environment.odc.getValue({ base: 'scene', keyPath: '#playbackControls.skipForwardEnabled' });
        return response.value === true;
      }, 'the next-episode playback control to become available', 30000);

      await environment.odc.setValue({
        base: 'scene',
        keyPath: '#playbackControls.skipForwardPressed',
        value: true
      });
      const nextEpisode = await waitForEpisodePlayback(
        environment,
        expected.season,
        expected.episode + 1,
        'the next episode to start playing'
      );

      await environment.odc.setValue({
        base: 'scene',
        keyPath: '#playbackControls.skipBackPressed',
        value: true
      });
      const previousEpisode = await waitForEpisodePlayback(
        environment,
        expected.season,
        expected.episode,
        'the previous episode to start playing'
      );
      assert.equal(previousEpisode.itemId, episode.Id, 'Previous should return to the originally configured episode.');
      addEvidenceMetadata(this, { episodeNavigation: { nextEpisode, previousEpisode } });

      await stopPlayback(this, environment, episode, { verifyProgress: false });
      markStopped();
    });
  });
});
