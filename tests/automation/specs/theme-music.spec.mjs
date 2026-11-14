import assert from 'node:assert/strict';
import { relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { categories, getAccountKey, readSetting, selectRadioOption, closeAndSaveSettings, openSettingsFromSystemMenu } from '../support/settings.mjs';
import { watchApi, snapshotWatchItem } from '../support/watch-browse.mjs';
import { stopPlaybackForCleanup } from '../support/tv-series.mjs';
import { addEvidenceMetadata, captureEvidence } from '../support/evidence.mjs';
import { startThemeProxy } from '../support/theme-proxy.mjs';

const audio = '#themeAudioController.#audio';
const read = async (env, keyPath) => (await env.odc.getValue({ base: 'scene', keyPath })).value;
const set = (env, keyPath, value) => env.odc.setValue({ base: 'scene', keyPath, value });

async function preferences(env, music, shortcut) {
  assert.equal(await read(env, '#homePage.visible'), true, 'Theme preferences must be changed from Home.');
  assert.equal(await read(env, '#header.visible'), true, 'The System menu must be available.');
  await openSettingsFromSystemMenu(env, categories.tv);
  await selectRadioOption(env, 'skipSingleSeasonSeriesOptions', shortcut === 'on' ? 1 : 0);
  await set(env, '#userCategoryList.itemSelected', categories.mediaShell.index);
  await waitFor(async () => await read(env, '#mediaShellPanel.visible') === true, 'media preferences');
  await env.odc.focusNode({ base: 'scene', keyPath: '#episodeShellLayoutOptions' });
  await set(env, '#episodeShellLayoutOptions.jumpToItem', 2);
  await env.ecp.sendKeypress(env.ecp.Key.Down, { wait: 400 });
  await waitFor(async () => await read(env, '#mediaShellPageNumber.text') === '2 / 2', 'theme preferences');
  await selectRadioOption(env, 'themeMusicOptions', music === 'on' ? 1 : 0);
  await closeAndSaveSettings(env);
}

async function fixture(env, prefix, single) {
  const { api } = await watchApi(env);
  const result = await api('/Items', { Recursive: true, IncludeItemTypes: 'Series', SearchTerm: prefix });
  const matches = result.Items.filter(item => item.Name.toLowerCase().startsWith(prefix.toLowerCase()));
  assert.equal(matches.length, 1, `Exactly one series matching ${prefix} is required; use an unambiguous library title.`);
  const item = matches[0];
  const seasons = (await api(`/Shows/${item.Id}/Seasons`)).Items;
  assert.ok(single ? seasons.length === 1 : seasons.length > 1, `${item.Name} must have ${single ? 'one season' : 'multiple seasons'} including Specials.`);
  const songs = (await api(`/Items/${item.Id}/ThemeSongs`)).Items;
  assert.ok(songs[0]?.Id, `${item.Name} must have a playable Jellyfin theme song.`);
  return { item, seasons, song: songs[0], api };
}

async function openSeries(env, item, page) {
  await set(env, '#homePage.selectedSeries', { itemId: item.Id, item });
  await waitFor(async () => await read(env, '#dynamicPageHost.0.subtype()') === page, `${item.Name} ${page}`);
  if (page === 'TVSeason') await waitFor(async () => await read(env, '#dynamicPageHost.0.ready') === true, 'shortcut season ready', 60000);
  else await waitFor(async () => (await read(env, '#seasonsGrid.content.getChildCount()')) > 0, 'season cards', 60000);
}

async function enterSeason(env) {
  await set(env, '#seasonsGrid.itemSelected', 0);
  await waitFor(async () => await read(env, '#dynamicPageHost.1.subtype()') === 'TVSeason'
    && await read(env, '#dynamicPageHost.1.ready') === true, 'season ready', 60000);
}

async function playing(env, expectedSong) {
  await waitFor(async () => await read(env, audio + '.state') === 'playing', 'real theme Audio playing', 60000);
  // Scalar reads avoid RTA associative-array key normalization and exposing tokens.
  const url = await read(env, audio + '.content.url');
  assert.ok(url?.includes(expectedSong.Id), 'Audio content must identify the expected Jellyfin theme song.');
  return { state: 'playing', songId: expectedSong.Id };
}

async function lookupGenerations(env) {
  return Promise.all(['themeSongsTask', 'themeSongsTaskAlternate'].map(
    async id => await read(env, `#themeAudioController.#${id}.request.requestId`) ?? null
  ));
}

async function noThemeLookup(env) {
  for (const id of ['themeSongsTask', 'themeSongsTaskAlternate']) {
    assert.equal(await read(env, `#themeAudioController.#${id}.request.itemId`) ?? '', '',
      'Direct or disabled entry must not request a theme.');
  }
}

async function staysSilent(env) {
  // Observe a bounded interval so a late response cannot pass an instantaneous check.
  const end = Date.now() + 2500;
  do {
    assert.notEqual(await read(env, audio + '.state'), 'playing');
    assert.ok(!await read(env, audio + '.content.url'), 'Stopped theme audio must clear its content.');
    await new Promise(resolve => setTimeout(resolve, 250));
  } while (Date.now() < end);
}

describe('Starfin theme music playback', function () {
  this.timeout(240000);
  let env, original, proxy, watched;

  beforeEach(async function () {
    proxy = undefined;
    watched = undefined;
    original = undefined;
    env = await relaunchAuthenticatedStarfin();
    await waitFor(async () => await read(env, '#homePage.ready') === true, 'Home ready', 60000);
    assert.equal(await read(env, audio + '.subtype()'), 'Audio', 'Observe the real controller Audio node.');
    const key = await getAccountKey(env);
    original = {
      music: await readSetting(env, key, 'account', 'theme-music') ?? 'off',
      shortcut: await readSetting(env, key, 'account', 'skip-single-season-series') ?? 'off'
    };
  });

  afterEach(async function () {
    const errors = [];
    for (const cleanup of [
      async () => { await stopPlaybackForCleanup(env); },
      async () => {
        env = await relaunchAuthenticatedStarfin();
        await waitFor(async () => await read(env, '#homePage.ready') === true, 'cleanup Home ready', 60000);
      },
      async () => { if (watched) await watched.restore(); },
      async () => { if (original) await preferences(env, original.music, original.shortcut); },
      async () => { if (proxy) await proxy.close(); }
    ]) {
      try { await cleanup(); } catch (error) { errors.push(error); }
    }
    if (errors.length) throw new AggregateError(errors, 'Theme automation cleanup failed');
  });

  it('plays Buck Rogers through the shortcut and stops on Back to Home', async function () {
    const title = await fixture(env, 'Buck Rogers', true);
    await preferences(env, 'on', 'on');
    await openSeries(env, title.item, 'TVSeason');
    assert.equal(await read(env, '#dynamicPageHost.getChildCount()'), 1, 'Skipped TVShow must be removed.');
    assert.equal(await read(env, '#dynamicPageHost.0.loadRequest.seriesId'), title.item.Id);
    addEvidenceMetadata(this, await playing(env, title.song));
    await captureEvidence(this, 'buck-rogers-shortcut-theme');
    await env.ecp.sendKeypress(env.ecp.Key.Back);
    await waitFor(async () => await read(env, '#homePage.visible') === true, 'Back to Home');
    await staysSilent(env);
  });

  it('keeps Magnum P.I. music playing without a new lookup when entering a season', async function () {
    const title = await fixture(env, 'Magnum, P.I.', false);
    await preferences(env, 'on', 'on');
    await openSeries(env, title.item, 'TVShow');
    await playing(env, title.song);
    const generations = await lookupGenerations(env);
    const url = await read(env, audio + '.content.url');
    await enterSeason(env);
    addEvidenceMetadata(this, await playing(env, title.song));
    assert.ok(await read(env, audio + '.content.url') === url, 'Season entry must retain the same audio stream.');
    assert.deepEqual(await lookupGenerations(env), generations, 'Season entry must not launch or restart theme discovery.');
    await captureEvidence(this, 'magnum-season-theme');
  });

  it('finishes a held Magnum P.I. lookup after entering a season', async function () {
    const title = await fixture(env, 'Magnum, P.I.', false);
    await preferences(env, 'on', 'off');
    const session = await read(env, '#authController.authenticatedSession');
    proxy = await startThemeProxy(env.selectedDevice.host, session.server);
    // Network-fixture setup only: route this live session through the proxy before
    // opening any detail page. Saved authentication remains pointed at Jellyfin;
    // cleanup relaunches it. This is not an authentication/navigation assertion.
    await set(env, '#authController.authenticatedSession', { ...session, server: proxy.url });
    await waitFor(async () => await read(env, '#homePage.loadRequest.server') === proxy.url
      && await read(env, '#homePage.ready') === true, 'proxy-backed Home ready', 60000);
    await openSeries(env, title.item, 'TVShow');
    await waitFor(() => proxy.pending, 'held theme lookup');
    assert.notEqual(await read(env, audio + '.state'), 'playing');
    await enterSeason(env);
    proxy.release();
    addEvidenceMetadata(this, await playing(env, title.song));
    await captureEvidence(this, 'magnum-delayed-theme');
  });

  it('does not restart the theme after disabling music from Home and reopening the show', async function () {
    const title = await fixture(env, 'Magnum, P.I.', false);
    await preferences(env, 'on', 'off');
    await openSeries(env, title.item, 'TVShow');
    await playing(env, title.song);
    await env.ecp.sendKeypress(env.ecp.Key.Back);
    await waitFor(async () => await read(env, '#homePage.visible') === true, 'Back to Home before Settings');
    await staysSilent(env);
    const generations = await lookupGenerations(env);
    await preferences(env, 'off', 'off');
    await openSeries(env, title.item, 'TVShow');
    assert.deepEqual(await lookupGenerations(env), generations, 'Disabled music must not start another lookup on reopening.');
    await staysSilent(env);
  });

  it('does not start Buck Rogers theme music when disabled', async function () {
    const title = await fixture(env, 'Buck Rogers', true);
    await preferences(env, 'off', 'on');
    await openSeries(env, title.item, 'TVSeason');
    await noThemeLookup(env);
    await staysSilent(env);
  });

  it('does not start a theme when entering a season from episode details directly', async function () {
    const title = await fixture(env, 'Magnum, P.I.', false);
    const episode = (await title.api(`/Shows/${title.item.Id}/Episodes`, { SeasonId: title.seasons[0].Id, Limit: 1 })).Items[0];
    assert.ok(episode?.Id, 'Direct season entry requires an episode.');
    await preferences(env, 'on', 'off');
    await set(env, '#homePage.selectedEpisode', { itemId: episode.Id, item: episode });
    await waitFor(async () => await read(env, '#dynamicPageHost.0.subtype()') === 'TVEpisode', 'episode details');
    await set(env, '#dynamicPageHost.0.selectedSeason', {
      seriesId: title.item.Id, seasonId: title.seasons[0].Id,
      series: title.item, season: title.seasons[0], seasons: title.seasons
    });
    await waitFor(async () => await read(env, '#dynamicPageHost.0.subtype()') === 'TVSeason'
      && await read(env, '#dynamicPageHost.0.ready') === true, 'direct season ready', 60000);
    await noThemeLookup(env);
    await staysSilent(env);
  });

  it('stops the theme when an episode starts playing', async function () {
    const title = await fixture(env, 'Buck Rogers', true);
    watched = await snapshotWatchItem(env, title.item);
    const episode = watched.episodes[0];
    assert.ok(episode?.Id, 'Playback requires an episode.');
    await preferences(env, 'on', 'on');
    await openSeries(env, title.item, 'TVSeason');
    await playing(env, title.song);
    await set(env, '#dynamicPageHost.0.playbackSelected', { itemId: episode.Id, item: episode });
    await waitFor(async () => await read(env, '#videoPlayer.state') === 'playing', 'episode playing', 60000);
    await staysSilent(env);
    await captureEvidence(this, 'episode-stops-theme');
  });
});
