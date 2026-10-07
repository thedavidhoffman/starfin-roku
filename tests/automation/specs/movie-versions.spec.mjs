import assert from 'node:assert/strict';
import { ensureAuthenticated, relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { stopPlaybackForCleanup } from '../support/tv-series.mjs';

async function value(environment, keyPath) {
  return (await environment.odc.getValue({ base: 'scene', keyPath })).value;
}

async function findMovie(environment) {
  const account = environment.testAccount;
  const server = account.server.includes('://') ? account.server : `http://${account.server}`;
  const authorization = 'MediaBrowser Client="Starfin Automation", Device="Tests", DeviceId="starfin-version-tests", Version="1"';
  const response = await fetch(`${server}/Users/AuthenticateByName`, {
    method: 'POST', headers: { Authorization: authorization, 'Content-Type': 'application/json' },
    body: JSON.stringify({ Username: account.username, Pw: account.password })
  });
  assert.equal(response.ok, true, 'The automation account must authenticate.');
  const session = await response.json();
  const itemsResponse = await fetch(`${server}/Users/${session.User.Id}/Items?Recursive=true&IncludeItemTypes=Movie&Fields=MediaSources&Limit=2000`, {
    headers: { 'X-Emby-Token': session.AccessToken }
  });
  assert.equal(itemsResponse.ok, true, 'The movie catalog must load.');
  const catalog = await itemsResponse.json();
  return catalog.Items.find(item => item.MediaSources?.filter(source => source.Id).length > 1);
}

async function openMovie(environment, movie) {
  await environment.odc.setValue({ base: 'scene', keyPath: '#homePage.selectedMovie', value: { itemId: movie.Id, item: movie } });
  await waitFor(async () => await value(environment, '#dynamicPageHost.0.subtype()') === 'Movie'
    && await value(environment, '#mediaToolbar.mediaInfoText') !== '', 'movie version details');
}

async function openOptions(environment, playback = false) {
  if (playback) {
    await environment.ecp.sendKeypress(environment.ecp.Key.Up);
    await environment.odc.callFunc({ base: 'scene', keyPath: '#playbackControls', funcName: 'focusMediaOptions' });
  } else {
    await environment.odc.callFunc({ base: 'scene', keyPath: '#mediaToolbar', funcName: 'activate' });
    for (let i = 0; i < 10 && !await environment.odc.hasFocus({ base: 'scene', keyPath: '#mediaInfoButton' }); i++) {
      await environment.ecp.sendKeypress(environment.ecp.Key.Right);
    }
    assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: '#mediaInfoButton' }), true);
  }
  await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
  await waitFor(async () => await value(environment, '#overlayHost.0.title') === 'Media Options › Media Info', 'movie Media Options');
}

async function chooseVersion(environment, index) {
  await environment.ecp.sendKeypress(environment.ecp.Key.Down);
  await environment.ecp.sendKeypress(environment.ecp.Key.Down);
  assert.equal(await value(environment, '#categories.content.2.title'), 'Versions');
  await environment.ecp.sendKeypress(environment.ecp.Key.Right);
  const current = await value(environment, '#optionList.itemFocused');
  const key = index > current ? environment.ecp.Key.Down : environment.ecp.Key.Up;
  for (let i = 0; i < Math.abs(index - current); i++) await environment.ecp.sendKeypress(key);
  await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
  await waitFor(async () => await value(environment, '#versionStatus.text') === ''
    && await value(environment, '#optionList.checkedItem') === index, 'pending version metadata');
}

async function closeOptions(environment) {
  await environment.ecp.sendKeypress(environment.ecp.Key.Back);
  await waitFor(async () => await value(environment, '#overlayHost.getChildCount()') === 0, 'movie options to close');
}

describe('Starfin movie versions', function () {
  let movie;
  before(async function () {
    const environment = await ensureAuthenticated();
    movie = await findMovie(environment);
    if (!movie) this.skip();
  });

  afterEach(async function () {
    try {
      if (this.currentTest?.state === 'failed') {
        await captureEvidence(this, `before cleanup ${this.currentTest.fullTitle()}`, { failure: true });
      }
    } catch (error) {
      console.warn(`Unable to capture failure evidence before cleanup: ${error.message}`);
    } finally {
      // A failed assertion can leave Movie, playback, or an overlay open with Home hidden.
      await relaunchAuthenticatedStarfin();
    }
  });

  it('stages detail versions, commits their summary, and reopens the selection', async function () {
    this.timeout(120000);
    const environment = await ensureAuthenticated();
    await openMovie(environment, movie);
    const summary = await value(environment, '#mediaToolbar.mediaInfoText');
    await openOptions(environment);
    const initialId = await value(environment, '#overlayHost.0.optionsContext.selection.mediaSourceId');
    assert.equal(initialId, movie.MediaSources[0].Id);
    await chooseVersion(environment, 1);
    assert.equal(await value(environment, '#overlayHost.0.optionsContext.selection.mediaSourceId'), initialId);
    assert.equal(await value(environment, '#mediaToolbar.mediaInfoText'), summary);
    await captureEvidence(this, 'movie-versions-detail-pending');
    await closeOptions(environment);
    await openOptions(environment);
    assert.equal(await value(environment, '#overlayHost.0.optionsContext.selection.mediaSourceId'), movie.MediaSources[1].Id);
    // Resolve fields on Roku, where associative-array keys are case-insensitive.
    assert.equal(await value(environment, '#overlayHost.0.optionsContext.item.MediaSources.0.Id'), movie.MediaSources[1].Id);
    assert.equal(await value(environment, '#overlayHost.0.optionsContext.item.RunTimeTicks'), movie.MediaSources[1].RunTimeTicks);
    await captureEvidence(this, 'movie-versions-selected-information');
    await closeOptions(environment);
  });

  for (const paused of [false, true]) {
    it(`switches versions during ${paused ? 'paused' : 'playing'} playback and restores movie details`, async function () {
      this.timeout(180000);
      const environment = await ensureAuthenticated();
      await openMovie(environment, movie);
      await environment.odc.setValue({ base: 'scene', keyPath: '#mediaToolbar.restartSelected', value: true });
      await waitFor(async () => await value(environment, '#videoPlayer.state') === 'playing', 'movie playback', 60000);
      if (paused) {
        await environment.ecp.sendKeypress(environment.ecp.Key.Play);
        await waitFor(async () => await value(environment, '#videoPlayer.state') === 'paused', 'movie pause');
      }
      const taskPath = '#playbackController.0.#playbackInfoTask';
      const firstRequest = await value(environment, `${taskPath}.response.requestId`);
      assert.ok(Number.isInteger(firstRequest), 'Initial playback negotiation must have a request ID.');
      await openOptions(environment, true);
      const capturedPosition = await value(environment, '#videoPlayer.position');
      await chooseVersion(environment, 1);
      await captureEvidence(this, `movie-versions-player-${paused ? 'paused' : 'playing'}-pending`);
      await closeOptions(environment);
      await waitFor(async () => {
        const state = {
          requestId: await value(environment, `${taskPath}.response.requestId`),
          ok: await value(environment, `${taskPath}.response.ok`),
          errorMessage: await value(environment, `${taskPath}.response.errorMessage`),
          mediaSourceId: await value(environment, `${taskPath}.response.mediaSourceId`),
          requestedSourceId: await value(environment, '#playbackController.0.playRequest.mediaSourceId'),
          videoState: await value(environment, '#videoPlayer.state')
        };
        if (state.requestId > firstRequest && state.ok === true
          && state.mediaSourceId === movie.MediaSources[1].Id
          && state.videoState === (paused ? 'paused' : 'playing')) return true;
        throw new Error(`Version restart expected source ${movie.MediaSources[1].Id}, request ID > ${firstRequest}, state ${paused ? 'paused' : 'playing'}; observed ${JSON.stringify(state)}`);
      }, 'version restart and state restoration', 60000);
      const requestPath = '#playbackController.0.playRequest';
      assert.equal(await value(environment, `${requestPath}.mediaSourceId`), movie.MediaSources[1].Id);
      assert.equal(await value(environment, `${requestPath}.startPaused`), paused);
      const positionTicks = await value(environment, `${requestPath}.startPositionTicks`);
      assert.ok(Math.abs(positionTicks / 10000000 - capturedPosition) <= 4);
      const sources = await value(environment, `${requestPath}.movieVersions.sources`);
      assert.ok(Array.isArray(sources), 'Playback must retain the complete version catalog.');
      assert.equal(sources.length, movie.MediaSources.length);
      assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: '#playbackControls.#mediaOptionsButton' }), true);
      await captureEvidence(this, `movie-versions-player-${paused ? 'paused' : 'playing'}-restored`);
      await stopPlaybackForCleanup(environment);
      await openOptions(environment);
      assert.equal(await value(environment, '#overlayHost.0.optionsContext.selection.mediaSourceId'), movie.MediaSources[1].Id);
      await closeOptions(environment);
    });
  }
});
