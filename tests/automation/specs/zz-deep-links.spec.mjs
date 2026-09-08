// The zz- prefix intentionally makes this suite run last under Mocha's filename
// ordering. These tests repeatedly exit and relaunch the development channel,
// and the unauthenticated-launch case clears Starfin's registry, leaving device
// and authentication state unsuitable for the ordinary smoke tests that follow.
import assert from 'node:assert/strict';
import { ensureAuthenticated, relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { clearStarfinRegistry, waitFor, waitForMainScene } from '../support/lifecycle.mjs';

async function exitStarfin(environment) {
  await environment.ecp.sendKeypress(environment.ecp.Key.Home);
  await waitFor(async () => {
    const response = await environment.ecp.getActiveApp();
    return response.app?.id !== 'dev';
  }, 'Starfin to exit before a deep-link launch');
}

async function sendColdDeepLink(environment, contentId, mediaType) {
  await exitStarfin(environment);
  await environment.ecp.sendLaunchChannel({
    channelId: 'dev',
    params: { contentId, mediaType },
    verifyLaunch: true,
    verifyLaunchTimeOut: 15000
  });
  await waitForMainScene(environment);
}

async function sendRuntimeDeepLink(environment, contentId, mediaType) {
  await environment.ecp.sendInput({ params: { contentId, mediaType } });
}

async function waitForPlayback(environment, expectedItemId) {
  return waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        playerCount: { base: 'scene', keyPath: '#playbackController.getChildCount()' },
        itemId: { base: 'scene', keyPath: '#playbackController.playRequest.itemId' },
        state: { base: 'scene', keyPath: '#videoPlayer.state' }
      }
    });
    if (values.results.playerCount?.value !== 1) return false;
    if (expectedItemId && values.results.itemId?.value !== expectedItemId) return false;
    return values.results.state?.value === 'playing';
  }, `${expectedItemId || 'series'} deep-link playback to reach playing`, 45000);
}

async function waitForSeason(environment, expectedEpisodeId) {
  return waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        pageType: { base: 'scene', keyPath: '#dynamicPageHost.0.subtype()' },
        pageVisible: { base: 'scene', keyPath: '#dynamicPageHost.0.visible' },
        initialFocusEpisodeId: { base: 'scene', keyPath: '#dynamicPageHost.0.initialFocusEpisodeId' },
        horizontalVisible: { base: 'scene', keyPath: '#episodesList.visible' },
        rowItemFocused: { base: 'scene', keyPath: '#episodesList.rowItemFocused' },
        itemFocused: { base: 'scene', keyPath: '#episodesGrid.itemFocused' }
      }
    });
    if (values.results.pageType?.value !== 'TVSeason') return false;
    if (values.results.pageVisible?.value !== true) return false;
    if (values.results.initialFocusEpisodeId?.value !== '') return false;

    const horizontal = values.results.horizontalVisible?.value === true;
    const focused = horizontal
      ? values.results.rowItemFocused?.value?.[1]
      : values.results.itemFocused?.value;
    if (!Number.isInteger(focused) || focused < 0) return false;

    const contentPath = horizontal
      ? `#episodesList.content.0.${focused}.itemId`
      : `#episodesGrid.content.${focused}.itemId`;
    const focusedId = await environment.odc.getValue({ base: 'scene', keyPath: contentPath });
    return focusedId.value === expectedEpisodeId;
  }, 'the deep-linked season to render and apply initial focus', 45000);
}

async function waitForHomeFallback(environment) {
  return waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        homeVisible: { base: 'scene', keyPath: '#homePage.visible' },
        statusVisible: { base: 'scene', keyPath: '#statusLabel.visible' },
        statusText: { base: 'scene', keyPath: '#statusLabel.0.text' },
        destinationType: { base: 'scene', keyPath: '#deepLinkController.destinationRequested.type' },
        destinationMessage: { base: 'scene', keyPath: '#deepLinkController.destinationRequested.message' }
      }
    });
    return values.results.homeVisible?.value === true
      && values.results.statusVisible?.value === true
      && String(values.results.statusText?.value ?? '').length > 0
      && values.results.destinationType?.value === 'homeFallback'
      && String(values.results.destinationMessage?.value ?? '').length > 0;
  }, 'an invalid deep link to fall back to Home', 45000);
}

async function signIn(environment) {
  await environment.odc.setValue({ base: 'scene', keyPath: '#login.serverValue', value: environment.testAccount.server });
  await environment.odc.setValue({ base: 'scene', keyPath: '#login.usernameValue', value: environment.testAccount.username });
  await environment.odc.setValue({ base: 'scene', keyPath: '#login.passwordValue', value: environment.testAccount.password });
  await environment.odc.callFunc({ base: 'scene', keyPath: '#login', funcName: 'focusLoginButton' });
  await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
}

describe('Starfin deep-link certification', function () {
  before(async function () {
    await ensureAuthenticated();
  });

  for (const mode of ['cold', 'runtime']) {
    for (const mediaType of ['movie', 'episode', 'series', 'season']) {
      const article = mediaType === 'episode' ? 'an' : 'a';
      it(`${mode}-opens ${article} ${mediaType} deep link`, async function () {
        const environment = await relaunchAuthenticatedStarfin();
        const contentId = mediaType === 'movie'
          ? environment.deepLinkCases.movieId
          : environment.deepLinkCases.episodeId;

        if (mode === 'cold') await sendColdDeepLink(environment, contentId, mediaType);
        else await sendRuntimeDeepLink(environment, contentId, mediaType);

        if (mediaType === 'season') await waitForSeason(environment, contentId);
        else await waitForPlayback(environment, mediaType === 'series' ? undefined : contentId);
      });
    }
  }

  it('falls back to Home for an invalid ID', async function () {
    const environment = await relaunchAuthenticatedStarfin();

    await sendRuntimeDeepLink(environment, environment.deepLinkCases.invalidId, 'movie');

    await waitForHomeFallback(environment);
  });

  it('retains an unauthenticated cold launch through sign-in', async function () {
    const environment = await relaunchAuthenticatedStarfin();
    await clearStarfinRegistry(environment.odc);

    await sendColdDeepLink(environment, environment.deepLinkCases.movieId, 'movie');
    const login = await environment.odc.getValue({ base: 'scene', keyPath: '#login.visible' });
    assert.equal(login.value, true);

    await signIn(environment);
    await waitForPlayback(environment, environment.deepLinkCases.movieId);
  });
});
