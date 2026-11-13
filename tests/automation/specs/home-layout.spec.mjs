import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { value, set, press, focusHomeItem } from '../support/remote-keys.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { startHomeRefreshFixture } from '../support/home-refresh-fixture.mjs';

describe('Jellyfin Home layout', function () {
  this.timeout(180000);
  let environment, fixture, originalRequest, originalSettings;
  const movie = { Id: 'layout-movie', Name: 'Resumable movie', Type: 'Movie', ImageTags: {},
    UserData: { PlaybackPositionTicks: 100000000, LastPlayedDate: '2026-01-02T00:00:00Z' } };
  const episode = { Id: 'layout-episode', Name: 'Next episode', Type: 'Episode', SeriesId: 'layout-series', ImageTags: {} };
  const audio = { Id: 'layout-audio', Name: 'Listening item', Type: 'Audio', ImageTags: {} };

  const callHome = (funcName, ...funcParams) => environment.odc.callFunc({
    base: 'scene', keyPath: '#homePage', funcName, funcParams
  });
  const settled = () => waitFor(async () => await value(environment, '#homePage.ready') === true, 'Home layout settled');

  beforeEach(async function () {
    fixture = undefined;
    originalRequest = undefined;
    originalSettings = undefined;
    environment = await ensureAuthenticated();
    originalRequest = await value(environment, '#homePage.loadRequest');
    originalSettings = await value(environment, '#homePage.settings');
    fixture = await startHomeRefreshFixture(environment.selectedDevice.host, movie);
    fixture.setSectionItems('continueWatching', [movie]);
    fixture.setSectionItems('nextUp', [episode]);
    fixture.setSectionItems('continueListening', [audio]);
    fixture.setSectionItems('recentPlayedEpisodes', [{ SeriesId: 'layout-series', UserData: { LastPlayedDate: '2026-01-01T00:00:00Z' } }]);
    fixture.setSectionItems('liveTvOnNow', [{ Id: 'layout-program', Name: 'On now', Type: 'Program', ChannelId: 'channel', ImageTags: {} }]);
    await callHome('deactivate');
    await set(environment, '#homePage.loadRequest', {
      ...originalRequest, server: fixture.url, token: 'home-layout-fixture',
      permissions: { canAccessLiveTv: true }, homePreferences: { latestItemsExcludes: [] }
    });
  });

  afterEach(async function () {
    try {
      if (originalRequest) {
        await callHome('deactivate');
        await set(environment, '#homePage.loadRequest', originalRequest);
        await set(environment, '#homePage.settings', originalSettings);
        await callHome('activate', true);
        await settled();
      }
    } finally {
      if (fixture) await fixture.close();
    }
  });

  function preferences(slots) {
    const result = Object.fromEntries(Array.from({ length: 10 }, (_, i) => ['homesection' + i, 'none']));
    slots.forEach((section, index) => { result['homesection' + index] = section; });
    return result;
  }

  async function load(slots, combine) {
    fixture.setHomePreferences(preferences(slots));
    await set(environment, '#homePage.settings', {
      ...originalSettings, 'combine-continue-watching-next-up': combine ? 'on' : 'off'
    });
    fixture.requests.length = 0;
    await callHome('activate', true);
    await settled();
    await callHome('focusHome');
  }

  async function rows() {
    const result = [];
    const count = await value(environment, '#shelvesGroup.getChildCount()');
    for (let i = 0; i < count; i++) {
      result.push(await value(environment, '#shelvesGroup.' + i + '.rowContent.rowKey'));
    }
    return result;
  }

  async function focusedItem() {
    const count = await value(environment, '#shelvesGroup.getChildCount()');
    for (let i = 0; i < count; i++) {
      const control = '#shelvesGroup.' + i + '.#items';
      if (await environment.odc.hasFocus({ base: 'scene', keyPath: control })) {
        const position = await value(environment, control + '.rowItemFocused');
        return value(environment, control + '.content.0.' + position[1] + '.raw.Id');
      }
    }
    return undefined;
  }

  const matrix = [
    { name: 'watching first, separate', slots: ['resume', 'resumeaudio', 'nextup'], combine: false,
      rows: ['continueWatching', 'continueListening', 'nextUp'], sources: ['continueWatching', 'continueListening', 'nextUp'] },
    { name: 'next up first, separate', slots: ['nextup', 'resumeaudio', 'resume'], combine: false,
      rows: ['nextUp', 'continueListening', 'continueWatching'], sources: ['continueWatching', 'continueListening', 'nextUp'] },
    { name: 'watching in row three, next up in row five, combined', slots: ['none', 'none', 'resume', 'resumeaudio', 'nextup'], combine: true,
      rows: ['continueWatching', 'continueListening'], sources: ['continueWatching', 'continueListening', 'nextUp', 'recentPlayedEpisodes'] },
    { name: 'next up in row three, watching in row five, combined', slots: ['none', 'none', 'nextup', 'resumeaudio', 'resume'], combine: true,
      rows: ['continueWatching', 'continueListening'], sources: ['continueWatching', 'continueListening', 'nextUp', 'recentPlayedEpisodes'] },
    { name: 'watching only, combine off', slots: ['resume'], combine: false, rows: ['continueWatching'], sources: ['continueWatching'] },
    { name: 'watching only, combine on', slots: ['resume'], combine: true, rows: ['continueWatching'], sources: ['continueWatching'] },
    { name: 'next up only, combine off', slots: ['nextup'], combine: false, rows: ['nextUp'], sources: ['nextUp'] },
    { name: 'next up only, combine on', slots: ['nextup'], combine: true, rows: ['nextUp'], sources: ['nextUp'] },
    { name: 'neither watching source, combine off', slots: ['resumeaudio'], combine: false, rows: ['continueListening'], sources: ['continueListening'] },
    { name: 'neither watching source, combine on', slots: ['resumeaudio'], combine: true, rows: ['continueListening'], sources: ['continueListening'] }
  ];
  for (const scenario of matrix) {
    it(scenario.name, async function () {
      await load(scenario.slots, scenario.combine);

      assert.deepEqual(await rows(), scenario.rows);
      assert.deepEqual([...new Set(fixture.requests.map(request => request.section).filter(Boolean))].sort(),
        [...scenario.sources].sort());
      const firstTitle = await value(environment, '#shelvesGroup.0.rowContent.title');
      const combined = scenario.sources.includes('recentPlayedEpisodes');
      if (combined) {
        assert.equal(firstTitle, 'Continue Watching & Next Up');
        assert.equal(await value(environment, '#shelvesGroup.0.rowContent.getChildCount()'), 2);
      } else if (scenario.rows[0] === 'continueWatching') assert.equal(firstTitle, 'Continue Watching');
      else if (scenario.rows[0] === 'nextUp') assert.equal(firstTitle, 'Next Up');
      assert.equal(await value(environment, '#homePage.settings.combine-continue-watching-next-up'), scenario.combine ? 'on' : 'off');
    });
  }

  for (const scenario of [
    { wire: 'smalllibrarytiles', row: 'libraries', paths: ['/displaypreferences/usersettings', '/userviews'] },
    { wire: 'resumeaudio', row: 'continueListening', paths: ['/displaypreferences/usersettings', '/useritems/resume'] },
    { wire: 'latestmedia', row: 'latest:fixture-movies', paths: ['/displaypreferences/usersettings', '/userviews', '/items/latest'] },
    { wire: 'livetv', row: 'liveTvOnNow', paths: ['/displaypreferences/usersettings', '/livetv/programs/recommended'] }
  ]) {
    it('loads only ' + scenario.wire + ' and its dependencies', async function () {
      await load([scenario.wire], true);

      assert.deepEqual(await rows(), [scenario.row]);
      assert.deepEqual([...new Set(fixture.requests.filter(request => !request.path.includes('/images/')).map(request => request.path))].sort(), [...scenario.paths].sort());
    });
  }

  it('keeps the selected Next Up item when combining is enabled', async function () {
    await load(['nextup', 'resumeaudio', 'resume'], false);
    await focusHomeItem(environment, 'nextUp', episode.Id);

    await set(environment, '#homePage.settings', { ...originalSettings, 'combine-continue-watching-next-up': 'on' });
    await settled();

    assert.deepEqual(await rows(), ['continueWatching', 'continueListening']);
    assert.equal(await focusedItem(), episode.Id);
  });

  it('keeps the selected episode when the combined row splits', async function () {
    await load(['nextup', 'resumeaudio', 'resume'], true);
    await focusHomeItem(environment, 'continueWatching', episode.Id);

    await set(environment, '#homePage.settings', { ...originalSettings, 'combine-continue-watching-next-up': 'off' });
    await settled();

    assert.deepEqual(await rows(), ['nextUp', 'continueListening', 'continueWatching']);
    assert.equal(await focusedItem(), episode.Id);
  });

  it('focuses the first remaining row after reloading changed Jellyfin preferences', async function () {
    await load(['resume', 'resumeaudio', 'nextup'], true);
    await focusHomeItem(environment, 'continueWatching', movie.Id);
    fixture.setHomePreferences(preferences(['nextup', 'resumeaudio']));

    await callHome('activate', true);
    await settled();

    assert.deepEqual(await rows(), ['nextUp', 'continueListening']);
    assert.equal(await focusedItem(), episode.Id);
  });

  it('keeps hidden sources unloaded after playback reconciliation', async function () {
    await load(['nextup'], true);
    fixture.requests.length = 0;

    await callHome('deactivate');
    await callHome('recordMediaChange', { action: 'progress', itemId: movie.Id, itemType: 'Movie', positionTicks: 200000000 });
    await callHome('activate');
    await settled();

    assert.deepEqual([...new Set(fixture.requests.map(request => request.section).filter(Boolean))], ['nextUp']);
    assert.equal(fixture.requests.filter(request => request.path === '/displaypreferences/usersettings').length, 0);
    assert.deepEqual(await rows(), ['nextUp']);
  });

  it('finishes an empty Home and permits Up navigation to the header', async function () {
    await load(['resumebook', 'activerecordings'], true);

    assert.deepEqual(await rows(), []);
    assert.deepEqual(fixture.requests.map(request => request.path), ['/displaypreferences/usersettings']);
    assert.equal(await value(environment, '#loadingSpinner.control'), 'stop');
    await press(environment, 'Up');
    await waitFor(async () => await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#header' }), 'header focus from empty Home');
  });
});
