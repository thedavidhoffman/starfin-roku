import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { addEvidenceMetadata } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { value, press } from '../support/remote-keys.mjs';
import { loadSegmentFixture, restoreFixture } from '../support/segment-fixture.mjs';

describe('Starfin stream restart position', function () {
  this.timeout(300000);
  let environment, fixture;

  beforeEach(async function () {
    environment = await ensureAuthenticated();
    fixture = undefined;
    fixture = await loadSegmentFixture(environment);
  });

  afterEach(async function () {
    if (fixture) await restoreFixture(environment, fixture);
  });

  for (const target of [10, 40]) {
    it(`preserves the first restart landing near ${target} seconds when changing video mode`, async function () {
      const item = await fixture.api(`/Items/${fixture.episode.Id}`);
      await environment.odc.setValue({
        base: 'scene', keyPath: '#playbackController.playRequest',
        value: {
          ...fixture.session, itemId: item.Id, item,
          startPositionTicks: 0, startPaused: false,
          autoSkipIntros: false, autoSkipCredits: false,
          videoMode: 'automatic', tracksPlaybackProgress: true
        }
      });
      // Reach setup positions by normal playback so default seek rounding cannot
      // fail setup before the stream restart under test.
      await waitFor(async () => await value(environment, '#videoPlayer.state') === 'playing'
        && await value(environment, '#videoPlayer.position') >= target, 'initial playback target', 120000);
      await press(environment, 'Play');
      await waitFor(async () => await value(environment, '#videoPlayer.state') === 'paused', 'paused initial playback');
      const capturedPosition = await value(environment, '#videoPlayer.position');
      assert.ok(Math.abs(capturedPosition - target) <= 2, `Initial playback must be near ${target}; got ${capturedPosition}.`);
      const player = '#playbackController.0';
      const previousRequest = await value(environment, `${player}.#playbackInfoTask.response.requestId`);
      if (!await value(environment, '#playbackControls.visible')) await press(environment, 'Up');
      await environment.odc.callFunc({ base: 'scene', keyPath: '#playbackControls', funcName: 'focusMediaOptions' });
      await press(environment, 'Ok');
      await waitFor(async () => await value(environment, '#overlayHost.0.subtype()') === 'MediaOptionsDialog', 'Media Options');
      await press(environment, 'Down');
      await press(environment, 'Right');
      for (let index = 0; index < 3; index++) await press(environment, 'Down');
      await press(environment, 'Ok');
      await press(environment, 'Back');

      // Do not wait for the position to enter the expected range: that would let
      // an early landing play forward and conceal the rewind we are testing.
      const firstPlaying = await waitFor(async () => {
        const paths = {
          requestId: `${player}.#playbackInfoTask.response.requestId`,
          mode: `${player}.playRequest.videoMode`,
          requestedTicks: `${player}.playRequest.startPositionTicks`,
          state: '#videoPlayer.state', position: '#videoPlayer.position',
          playStart: '#videoPlayer.content.PlayStart',
          actualStart: '#videoPlayer.bufferingStatus.actualStart',
          seekMode: '#videoPlayer.seekMode'
        };
        const response = await environment.odc.getValues({ requests: Object.fromEntries(
          Object.entries(paths).map(([key, keyPath]) => [key, { base: 'scene', keyPath }])) });
        const snapshot = Object.fromEntries(Object.keys(paths).map(key => [key, response.results[key]?.value]));
        return snapshot.requestId > previousRequest && snapshot.mode === 'transcode-no-remux'
          && snapshot.state === 'playing' && snapshot.position > 0 ? snapshot : false;
      }, 'first playing position after stream restart', 120000);
      addEvidenceMetadata(this, { target, capturedPosition, firstPlaying });
      assert.equal(firstPlaying.requestedTicks / 1e7, Math.floor(capturedPosition), 'Restart request must retain the captured whole-second position.');
      assert.equal(firstPlaying.playStart, Math.floor(firstPlaying.requestedTicks / 1e7));
      assert.ok(firstPlaying.position >= firstPlaying.playStart - 1
        && firstPlaying.position <= firstPlaying.playStart + 3,
      `First restart landing must be near PlayStart=${firstPlaying.playStart}; got ${firstPlaying.position} (seekMode=${firstPlaying.seekMode}).`);
    });
  }
});
