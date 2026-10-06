import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { stopPlaybackForCleanup, returnToHome } from '../support/tv-series.mjs';

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
    const environment = await ensureAuthenticated();
    await stopPlaybackForCleanup(environment);
    await returnToHome();
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
    const item = await value(environment, '#overlayHost.0.optionsContext.item');
    assert.equal(item.MediaSources[0].Id, movie.MediaSources[1].Id);
    assert.equal(item.RunTimeTicks, movie.MediaSources[1].RunTimeTicks);
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
      const firstRequest = await value(environment, '#playbackInfoTask.response.requestId');
      await openOptions(environment, true);
      const capturedPosition = await value(environment, '#videoPlayer.position');
      await chooseVersion(environment, 1);
      await captureEvidence(this, `movie-versions-player-${paused ? 'paused' : 'playing'}-pending`);
      await closeOptions(environment);
      await waitFor(async () => await value(environment, '#playbackInfoTask.response.requestId') > firstRequest
        && await value(environment, '#playbackInfoTask.response.mediaSourceId') === movie.MediaSources[1].Id
        && await value(environment, '#videoPlayer.state') === (paused ? 'paused' : 'playing'), 'version restart and state restoration', 60000);
      const request = await value(environment, '#playbackController.0.playRequest');
      assert.equal(request.mediaSourceId, movie.MediaSources[1].Id);
      assert.equal(request.startPaused, paused);
      assert.ok(Math.abs(request.startPositionTicks / 10000000 - capturedPosition) <= 4);
      assert.equal(request.movieVersions.sources.length, movie.MediaSources.length);
      assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: '#playbackControls.#mediaInfoButton' }), true);
      await captureEvidence(this, `movie-versions-player-${paused ? 'paused' : 'playing'}-restored`);
      await stopPlaybackForCleanup(environment);
      await openOptions(environment);
      assert.equal(await value(environment, '#overlayHost.0.optionsContext.selection.mediaSourceId'), movie.MediaSources[1].Id);
      await closeOptions(environment);
    });
  }
});
