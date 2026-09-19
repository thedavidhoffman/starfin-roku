import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import {
  findSeries, openConfiguredTVLibrary, openSeries, readSeasonCards,
  openSeasonOne, selectConfiguredEpisode, startEpisodePlayback,
  isPlayerAttached, stopPlaybackForCleanup, returnToHome
} from '../support/tv-series.mjs';

async function value(environment, keyPath) {
  const result = await environment.odc.getValue({ base: 'scene', keyPath });
  return result.value;
}

async function openOptions(environment, playback = false) {
  if (playback) {
    if (!await value(environment, '#playbackControls.visible')) {
      await environment.ecp.sendKeypress(environment.ecp.Key.Up);
    }
    await environment.odc.callFunc({ base: 'scene', keyPath: '#playbackControls', funcName: 'focusMediaOptions' });
  } else {
    await environment.odc.callFunc({ base: 'scene', keyPath: '#mediaToolbar', funcName: 'activate' });
    for (let index = 0; index < 10 && !await environment.odc.hasFocus({ base: 'scene', keyPath: '#mediaToolbar.#mediaInfoButton' }); index++) {
      await environment.ecp.sendKeypress(environment.ecp.Key.Right);
    }
    assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: '#mediaToolbar.#mediaInfoButton' }), true);
  }
  await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
  await waitFor(async () => await value(environment, '#overlayHost.0.title') === 'Media Options', 'Media Options to open');
}

async function closeOptions(environment) {
  await environment.ecp.sendKeypress(environment.ecp.Key.Back);
  await waitFor(async () => await value(environment, '#overlayHost.getChildCount()') === 0, 'Media Options to close');
}

describe('Starfin unified media options', function () {
  it('stages detail options and preserves playback state through a combined restart', async function () {
    this.timeout(240000);
    const environment = await ensureAuthenticated();
    try {
      await openConfiguredTVLibrary(environment);
      const { item, itemIndex } = await findSeries(environment);
      await openSeries(environment, itemIndex, item);
      await openSeasonOne(environment, await readSeasonCards(environment));
      const episode = await selectConfiguredEpisode(environment);
      await captureEvidence(this, 'media-options-detail-toolbar');

      await openOptions(environment);
      await captureEvidence(this, 'media-options-source-information');
      let subtitleCategory = 0;
      while (await value(environment, `#categories.content.${subtitleCategory}.title`) !== 'Subtitles') {
        assert.ok(subtitleCategory < 4, 'The configured episode must have subtitles.');
        await environment.ecp.sendKeypress(environment.ecp.Key.Down);
        subtitleCategory++;
      }
      await environment.ecp.sendKeypress(environment.ecp.Key.Right);
      assert.equal(await value(environment, '#optionList.checkedItem'), 0);
      assert.equal(await value(environment, '#overlayHost.0.optionsContext.selection.subtitleStreamIndex'), -2);
      await captureEvidence(this, 'media-options-initial-subtitles-off');
      await environment.ecp.sendKeypress(environment.ecp.Key.Left);
      for (let index = 0; index < subtitleCategory; index++) await environment.ecp.sendKeypress(environment.ecp.Key.Up);
      await environment.ecp.sendKeypress(environment.ecp.Key.Right);
      for (let index = 0; index < 8; index++) await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      await captureEvidence(this, 'media-options-information-scrolled');
      await environment.ecp.sendKeypress(environment.ecp.Key.Left);
      assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: '#categories' }), true);
      await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      await environment.ecp.sendKeypress(environment.ecp.Key.Right);
      for (let index = 0; index < 3; index++) await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
      assert.ok(await value(environment, '#overlayHost.0.result') == null);
      await captureEvidence(this, 'media-options-video-pending');
      for (let index = 0; index < 3; index++) await environment.ecp.sendKeypress(environment.ecp.Key.Up);
      await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
      await closeOptions(environment);
      assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: '#mediaToolbar.#mediaInfoButton' }), true);

      await startEpisodePlayback(environment, episode);
      await openOptions(environment, true);
      await waitFor(async () => await value(environment, '#videoPlayer.state') === 'paused', 'playback to pause for options');
      await captureEvidence(this, 'media-options-playing-information');
      const original = await value(environment, '#playbackController.0.playRequest.videoMode');
      await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      await environment.ecp.sendKeypress(environment.ecp.Key.Right);
      for (let index = 0; index < 3; index++) await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
      assert.deepEqual(await value(environment, '#playbackController.0.playRequest.videoMode'), original);
      await closeOptions(environment);
      await waitFor(async () => await value(environment, '#videoPlayer.state') === 'playing', 'changed playback to resume', 120000);
      const changed = await value(environment, '#playbackController.0.playRequest.videoMode');
      assert.equal(changed, 'transcode-no-remux');
      await captureEvidence(this, 'media-options-playback-toolbar');

      await environment.ecp.sendKeypress(environment.ecp.Key.Play);
      await waitFor(async () => await value(environment, '#videoPlayer.state') === 'paused', 'explicit playback pause');
      await openOptions(environment, true);
      await closeOptions(environment);
      assert.equal(await value(environment, '#videoPlayer.state'), 'paused');
      await openOptions(environment, true);
      await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      await environment.ecp.sendKeypress(environment.ecp.Key.Right);
      for (let index = 0; index < 3; index++) await environment.ecp.sendKeypress(environment.ecp.Key.Up);
      await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
      await closeOptions(environment);
      await waitFor(async () => {
        const request = await value(environment, '#playbackController.0.playRequest.videoMode');
        return request === 'automatic' && await value(environment, '#videoPlayer.state') === 'paused';
      }, 'changed playback to remain paused', 120000);
    } finally {
      if (await value(environment, '#overlayHost.0.title') === 'Media Options') await closeOptions(environment);
      if (await isPlayerAttached(environment)) await stopPlaybackForCleanup(environment);
      await returnToHome();
    }
  });
});
