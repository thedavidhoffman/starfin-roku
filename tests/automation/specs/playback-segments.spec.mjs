import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { captureEvidence, addEvidenceMetadata } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { value, press, readPlaybackQueue, waitForVideo } from '../support/remote-keys.mjs';
import { returnToHome } from '../support/tv-series.mjs';
import {
  loadSegmentFixture, restoreFixture, playFixture, seekFixture, samplePlayback, playbackPreferences
} from '../support/segment-fixture.mjs';

describe('Starfin official Intro and Outro playback', function () {
  this.timeout(300000);
  let environment, fixture, originalPreferences;
  beforeEach(async function () {
    environment = await ensureAuthenticated();
    fixture = undefined;
    originalPreferences = undefined;
    fixture = await loadSegmentFixture(environment);
    originalPreferences = await playbackPreferences({
      autoSkipIntrosOptions: 0, autoSkipCreditsOptions: 0, nextItemPlaybackOptions: 0
    });
    addEvidenceMetadata(this, { segmentFixture: {
      series: fixture.series.Name, episode: fixture.episode.Name,
      duration: fixture.duration, ranges: fixture.ranges
    } });
  });
  afterEach(async function () {
    try {
      if (fixture) await restoreFixture(environment, fixture);
    } finally {
      if (originalPreferences) await playbackPreferences(originalPreferences);
      await returnToHome();
    }
  });

  async function assertNoSkipButton() {
    assert.notEqual(await value(environment, '#playbackActionButton.visible'), true);
  }

  async function waitForQueue() {
    await waitFor(async () => (await readPlaybackQueue(environment)).nextItemId === fixture.next.Id,
      'S1E2 to become the next queued item', 30000);
  }

  async function waitForUpNext() {
    const path = await waitFor(async () => {
      const count = await value(environment, '#dynamicPageHost.getChildCount()');
      for (let index = 0; index < count; index++) {
        const candidate = `#dynamicPageHost.${index}`;
        if (await value(environment, `${candidate}.subtype()`) === 'TVEpisodeUpNextAutoPlay'
          && await value(environment, `${candidate}.visible`) === true) return candidate;
      }
      return false;
    }, 'Up Next before the unskipped Outro could naturally finish', 15000);
    // Freeze the UI countdown after arrival so assertions/evidence cannot race its expiry.
    await environment.odc.setValue({ base: 'scene', keyPath: `${path}.#countdownTimer.control`, value: 'stop' });
    assert.equal(await value(environment, '#playbackController.getChildCount()'), 0);
    assert.equal(await value(environment, `${path}.autoPlayRequest.nextItem.itemId`), fixture.next.Id);
    return path;
  }

  async function assertNoUpNext() {
    const count = await value(environment, '#dynamicPageHost.getChildCount()');
    for (let index = 0; index < count; index++) {
      const path = `#dynamicPageHost.${index}`;
      if (await value(environment, `${path}.subtype()`) === 'TVEpisodeUpNextAutoPlay') {
        assert.notEqual(await value(environment, `${path}.visible`), true, 'Up Next must not be shown.');
      }
    }
  }

  it('shows the manual Intro button with automatic intro skipping Off', async function () {
    await playFixture(environment, fixture);
    await waitFor(async () => await value(environment, '#playbackActionButton.visible') === true
      && await value(environment, '#playbackActionButton.text') === 'Skip Intro', 'manual Intro action');
    await samplePlayback(environment, 2, async () => {
      assert.ok(await value(environment, '#videoPlayer.position') < fixture.ranges.Intro.end);
    });
    await captureEvidence(this, 'intro-manual');
    await press(environment, 'Ok');
    await waitFor(async () => await value(environment, '#videoPlayer.position') >= fixture.ranges.Intro.end - 1,
      'manual Intro seek', 15000);
  });

  it('automatically skips the Intro without showing its manual action', async function () {
    await playbackPreferences({ autoSkipIntrosOptions: 1 });
    await playFixture(environment, fixture);
    const deadline = Date.now() + 15000;
    let arrived = false;
    do {
      await assertNoSkipButton();
      arrived = await value(environment, '#videoPlayer.position') >= fixture.ranges.Intro.end - 1;
      if (!arrived) await new Promise(resolve => setTimeout(resolve, 200));
    } while (!arrived && Date.now() < deadline);
    assert.ok(arrived, 'Automatic Intro seek must happen before the Intro naturally finishes.');
    assert.ok(Math.abs(await value(environment, '#videoPlayer.seek') - fixture.ranges.Intro.end) < 1,
      'The Video node must have received the segment-end seek, not just played through the Intro.');
    await samplePlayback(environment, 2, assertNoSkipButton);
    assert.equal(await value(environment, '#playbackController.0.playRequest.itemId'), fixture.episode.Id);
    await captureEvidence(this, 'intro-automatic');
  });

  it('offers the manual Outro action and waits for selection with automatic credits Off', async function () {
    await playFixture(environment, fixture);
    await waitForQueue();
    await seekFixture(environment, fixture.ranges.Outro.start + 4);
    await waitFor(async () => await value(environment, '#playbackActionButton.visible') === true
      && await value(environment, '#playbackActionButton.text') === 'Skip Credits', 'manual credits action', 15000);
    await samplePlayback(environment, 2, async () => {
      assert.equal(await value(environment, '#playbackController.0.playRequest.itemId'), fixture.episode.Id);
      assert.equal(await value(environment, '#playbackActionButton.visible'), true,
        `Credits action vanished: state=${await value(environment, '#videoPlayer.state')}, position=${await value(environment, '#videoPlayer.position')}, seek=${await value(environment, '#videoPlayer.seek')}, end=${fixture.ranges.Outro.end}`);
    });
    await captureEvidence(this, 'outro-manual');
    await press(environment, 'Ok');
    await waitForUpNext();
  });

  it('offers Play Next during credits and immediately plays S1E2 after selection', async function () {
    await playbackPreferences({ nextItemPlaybackOptions: 1 });
    await fixture.api(`/UserItems/${fixture.next.Id}/UserData`, {}, {
      ...fixture.next.UserData, PlaybackPositionTicks: 0
    });
    await playFixture(environment, fixture);
    await waitForQueue();
    await seekFixture(environment, fixture.ranges.Outro.start + 4);
    await waitFor(async () => await value(environment, '#playbackActionButton.visible') === true
      && await value(environment, '#playbackActionButton.text') === 'Play Next', 'manual Play Next action', 15000);
    await samplePlayback(environment, 2, async () => {
      assert.equal(await value(environment, '#playbackController.0.playRequest.itemId'), fixture.episode.Id);
      assert.equal(await value(environment, '#playbackActionButton.visible'), true,
        `Credits action vanished: state=${await value(environment, '#videoPlayer.state')}, position=${await value(environment, '#videoPlayer.position')}, seek=${await value(environment, '#videoPlayer.seek')}, end=${fixture.ranges.Outro.end}`);
      await assertNoUpNext();
    });
    await captureEvidence(this, 'outro-manual-play-next');
    // Bound the assertion before natural completion so playing through cannot pass.
    const transitionTimeout = Math.min(15000,
      Math.floor((fixture.duration - await value(environment, '#videoPlayer.position') - 2) * 1000));
    assert.ok(transitionTimeout > 0, 'Credits must still be playing before selection.');
    await press(environment, 'Ok');
    await waitFor(async () => {
      await assertNoUpNext();
      return await value(environment, '#playbackController.0.playRequest.itemId') === fixture.next.Id;
    }, 'manual immediate continuation to S1E2', transitionTimeout);
    await waitForVideo(environment, fixture.next.Id);
    await assertNoUpNext();
    await captureEvidence(this, 'outro-manual-next-playing');
  });

  it('offers Skip Credits on S4E26 with no successor and closes playback after selection', async function () {
    fixture = await loadSegmentFixture(environment, {
      season: 4, episodeNumber: 26, nextEpisodeNumber: null, segmentTypes: ['Outro']
    });
    addEvidenceMetadata(this, { segmentFixture: {
      series: fixture.series.Name, season: 4, episodeNumber: 26, episode: fixture.episode.Name,
      duration: fixture.duration, ranges: fixture.ranges
    } });
    // Immediate continuation must still label a final episode Skip Credits.
    await playbackPreferences({ nextItemPlaybackOptions: 1 });
    await playFixture(environment, fixture);
    await waitFor(async () => await value(environment, '#episodeQueueTask.response.ok') === true
      && await value(environment, '#episodeQueueTask.response.payload.reachedSeriesEnd') === true,
    'the production queue to resolve the series endpoint', 30000);
    const queue = await readPlaybackQueue(environment);
    assert.equal(queue.currentItemId, fixture.episode.Id);
    assert.equal(queue.nextItemId, undefined);
    await seekFixture(environment, fixture.ranges.Outro.start + 4);
    await waitFor(async () => await value(environment, '#playbackActionButton.visible') === true
      && await value(environment, '#playbackActionButton.text') === 'Skip Credits', 'final-episode Skip Credits', 15000);
    await samplePlayback(environment, 2, async () => {
      assert.equal(await value(environment, '#playbackController.0.playRequest.itemId'), fixture.episode.Id);
      assert.equal(await value(environment, '#playbackActionButton.visible'), true,
        `Credits action vanished: state=${await value(environment, '#videoPlayer.state')}, position=${await value(environment, '#videoPlayer.position')}, seek=${await value(environment, '#videoPlayer.seek')}, end=${fixture.ranges.Outro.end}`);
    });
    await captureEvidence(this, 'outro-finale-skip-credits');
    // Bound the assertion before natural completion so playing through cannot pass.
    const transitionTimeout = Math.min(15000,
      Math.floor((fixture.duration - await value(environment, '#videoPlayer.position') - 2) * 1000));
    assert.ok(transitionTimeout > 0, 'Credits must still be playing before selection.');
    await press(environment, 'Ok');
    await waitFor(async () => {
      await assertNoUpNext();
      return await value(environment, '#playbackController.getChildCount()') === 0;
    }, 'final-episode credits selection to close playback', transitionTimeout);
    await samplePlayback(environment, 2, async () => {
      assert.equal(await value(environment, '#playbackController.getChildCount()'), 0);
      await assertNoUpNext();
    });
    await captureEvidence(this, 'outro-finale-closed');
  });

  for (const immediate of [false, true]) {
    it(`automatically completes the Outro using ${immediate ? 'immediate continuation' : 'Up Next'}`, async function () {
      await playbackPreferences({ autoSkipIntrosOptions: 1, autoSkipCreditsOptions: 1, nextItemPlaybackOptions: immediate ? 1 : 0 });
      await fixture.api(`/UserItems/${fixture.next.Id}/UserData`, {}, {
        ...fixture.next.UserData, PlaybackPositionTicks: 0
      });
      await playFixture(environment, fixture);
      await waitForQueue();
      // Seek just before the marker so the test observes normal playback entering it.
      await seekFixture(environment, fixture.ranges.Outro.start - 3);
      const deadline = Date.now() + 20000;
      let transitioned = false;
      do {
        await assertNoSkipButton();
        const count = await value(environment, '#playbackController.getChildCount()');
        const id = await value(environment, '#playbackController.0.playRequest.itemId');
        transitioned = immediate ? id === fixture.next.Id : count === 0;
        if (!transitioned) await new Promise(resolve => setTimeout(resolve, 200));
      } while (!transitioned && Date.now() < deadline);
      assert.ok(transitioned, 'Automatic completion must occur before credits naturally finish.');
      if (immediate) await waitForVideo(environment, fixture.next.Id);
      else await waitForUpNext();
      await captureEvidence(this, `outro-auto-${immediate ? 'immediate' : 'up-next'}`);
    });
  }

  for (const type of ['Intro', 'Outro']) {
    it(`resumes a stream-option change opened paused inside the ${type} and skips automatically`, async function () {
      await playFixture(environment, fixture);
      await waitForQueue();
      const target = fixture.ranges[type].start + 10;
      const fullItem = await fixture.api(`/Items/${fixture.episode.Id}`);
      // Public playback request provides a deterministic paused starting point.
      // A fresh player avoids inheriting handled ranges from a preceding skip.
      await environment.odc.setValue({
        base: 'scene', keyPath: '#playbackController.playRequest',
        value: {
          ...fixture.session, itemId: fixture.episode.Id, item: fullItem,
          startPositionTicks: Math.round(target * 1e7), startPaused: true,
          autoSkipIntros: true, autoSkipCredits: true, nextItemPlayback: 'show-up-next',
          videoMode: 'automatic', tracksPlaybackProgress: true,
          playbackQueue: [fixture.episode, fixture.next].map(item => ({ itemId: item.Id, item })),
          playbackQueueIndex: 0
        }
      });
      await waitFor(async () => await value(environment, '#videoPlayer.state') === 'paused'
        && Math.abs(await value(environment, '#videoPlayer.position') - target) <= 3,
      'paused startup inside the segment', 120000);
      if (!await value(environment, '#playbackControls.visible')) await press(environment, 'Up');
      await environment.odc.callFunc({ base: 'scene', keyPath: '#playbackControls', funcName: 'focusMediaOptions' });
      await press(environment, 'Ok');
      await waitFor(async () => await value(environment, '#overlayHost.0.subtype()') === 'MediaOptionsDialog', 'Media Options');
      const requestPath = '#playbackController.0.#playbackInfoTask.request';
      const previousRequest = await value(environment, `${requestPath}.requestId`);
      assert.ok(Number.isInteger(previousRequest), 'The active video playback request must have an ID.');
      await press(environment, 'Down');
      await press(environment, 'Right');
      for (let i = 0; i < 3; i++) await press(environment, 'Down');
      await press(environment, 'Ok');
      await press(environment, 'Back');
      await waitFor(async () => await value(environment, '#overlayHost.getChildCount()') === 0,
        'Media Options to close');
      if (type === 'Intro') {
        await waitFor(async () => await value(environment, `${requestPath}.requestId`) > previousRequest
          && await value(environment, '#playbackController.0.playRequest.videoMode') === 'transcode-no-remux'
          && await value(environment, '#videoPlayer.state') === 'playing', 'changed stream to resume', 120000);
      }
      if (type === 'Intro') {
        await waitFor(async () => await value(environment, '#videoPlayer.position') >= fixture.ranges.Intro.end - 1,
          'resumed Intro to skip', 15000);
      } else {
        await waitForUpNext();
      }
      await assertNoSkipButton();
      await captureEvidence(this, `resumed-change-${type.toLowerCase()}`);
    });
  }
});
