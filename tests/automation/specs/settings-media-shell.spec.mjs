import assert from 'node:assert/strict';
import { categories, openSettings, closeAndSaveSettings, assertSettingPersisted, selectRadioOption } from '../support/settings.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { captureEvidence } from '../support/evidence.mjs';

const cards = [
  { label: 'Movie', key: 'movie-shell-layout', nodeId: 'movieShellLayoutOptions', modes: ['full-screen', 'partial-screen', 'cinematic', 'poster'] },
  { label: 'TV Series', key: 'tv-series-shell-layout', nodeId: 'seriesShellLayoutOptions', modes: ['full-screen', 'partial-screen', 'poster'] },
  { label: 'TV Episode', key: 'tv-episode-shell-layout', nodeId: 'episodeShellLayoutOptions', modes: ['full-screen', 'partial-screen', 'cinematic'] },
  { label: 'Music', key: 'music-shell-layout', nodeId: 'musicShellLayoutOptions', modes: ['full-screen', 'partial-screen'] }
];

describe('Starfin Media shell settings persistence', function () {
  // Start with an alternative so the first movie case makes a real edit and saves defaults.
  for (const card of cards) {
    for (const value of [...card.modes.slice(1), card.modes[0]]) {
      const index = card.modes.indexOf(value);
      it(`persists ${card.label} ${value} independently`, async function () {
        const { environment, accountKey } = await openSettings(categories.mediaShell);
        const before = {};
        for (const other of cards) {
          const checked = await environment.odc.getValue({ base: 'scene', keyPath: `#${other.nodeId}.checkedItem` });
          before[other.key] = other.modes[checked.value];
        }
        await selectRadioOption(environment, card.nodeId, index);
        await captureEvidence(this, `settings-${card.key}-${value}`);
        await closeAndSaveSettings(environment);
        await assertSettingPersisted(environment, accountKey, 'account', card.key, value);
        for (const other of cards.filter(candidate => candidate.key !== card.key)) {
          await assertSettingPersisted(environment, accountKey, 'account', other.key, before[other.key]);
        }
        await openSettings(categories.mediaShell);
        const reloaded = await environment.odc.getValue({ base: 'scene', keyPath: `#${card.nodeId}.checkedItem` });
        assert.equal(reloaded.value, index);
        await closeAndSaveSettings(environment);
      });
    }
  }
  it('pages to Theme music and returns to the originating TV card', async function () {
    const { environment } = await openSettings(categories.mediaShell);
    await assertMediaPage(environment, 1);
    await environment.odc.focusNode({ base: 'scene', keyPath: '#movieShellLayoutOptions' });
    await environment.odc.setValue({ base: 'scene', keyPath: '#movieShellLayoutOptions.jumpToItem', value: 3 });
    await environment.ecp.sendKeypress(environment.ecp.Key.Right, { wait: 400 });
    await waitFor(async () => await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#musicShellLayoutOptions' }), 'Music card focus');
    const music = await environment.odc.getValue({ base: 'scene', keyPath: '#musicShellLayoutOptions.itemFocused' });
    assert.equal(music.value, 1);
    await environment.ecp.sendKeypress(environment.ecp.Key.Down, { wait: 400 });
    assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#episodeShellLayoutOptions' }), true);
    await environment.ecp.sendKeypress(environment.ecp.Key.Left, { wait: 400 });
    assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#seriesShellLayoutOptions' }), true);
    await environment.odc.setValue({ base: 'scene', keyPath: '#seriesShellLayoutOptions.jumpToItem', value: 2 });
    await environment.ecp.sendKeypress(environment.ecp.Key.Down, { wait: 400 });
    assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#themeMusicOptions' }), true);
    await assertMediaPage(environment, 2);
    assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: '#overlayHost.0.title' })).value, 'Settings › Media shell');
    await captureEvidence(this, 'settings-media-shell-page-two');
    await environment.ecp.sendKeypress(environment.ecp.Key.Up, { wait: 400 });
    assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#seriesShellLayoutOptions' }), true);
    const series = await environment.odc.getValue({ base: 'scene', keyPath: '#seriesShellLayoutOptions.itemFocused' });
    assert.equal(series.value, 2);
    await assertMediaPage(environment, 1);
    await captureEvidence(this, 'settings-media-shell-page-one');
    await closeAndSaveSettings(environment);
  });
  it('returns from Theme music to the episode card when entered from that card', async function () {
    const { environment } = await openSettings(categories.mediaShell);
    await enterThemeMusic(environment);
    await environment.ecp.sendKeypress(environment.ecp.Key.Up, { wait: 400 });
    await assertMediaPage(environment, 1);
    assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#episodeShellLayoutOptions' }), true);
    assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: '#episodeShellLayoutOptions.itemFocused' })).value, 2);
    await closeAndSaveSettings(environment);
  });

  it('keeps pending layout changes and checkmarks across both pages', async function () {
    const { environment } = await openSettings(categories.mediaShell);
    await selectRadioOption(environment, 'movieShellLayoutOptions', 3);
    await selectRadioOption(environment, 'musicShellLayoutOptions', 1);
    await enterThemeMusic(environment);
    await environment.ecp.sendKeypress(environment.ecp.Key.Up, { wait: 400 });
    await assertMediaPage(environment, 1);
    assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: '#movieShellLayoutOptions.checkedItem' })).value, 3);
    assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: '#musicShellLayoutOptions.checkedItem' })).value, 1);
    await closeAndSaveSettings(environment);
  });

  it('resets to page one on category reentry', async function () {
    const { environment } = await openSettings(categories.mediaShell);
    await enterThemeMusic(environment);
    await environment.odc.setValue({ base: 'scene', keyPath: '#userCategoryList.itemSelected', value: categories.theme.index });
    await environment.odc.setValue({ base: 'scene', keyPath: '#userCategoryList.itemSelected', value: categories.mediaShell.index });
    await assertMediaPage(environment, 1);
    await closeAndSaveSettings(environment);
  });

  for (const [index, value] of ['off', 'on'].entries()) {
    it(`persists theme music ${value} from page two and restores it on reopening`, async function () {
      const { environment, accountKey } = await openSettings(categories.mediaShell);
      await enterThemeMusic(environment);
      if (index === 1) await environment.ecp.sendKeypress(environment.ecp.Key.Down, { wait: 400 });
      await environment.ecp.sendKeypress(environment.ecp.Key.Ok, { wait: 400 });
      assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: '#themeMusicOptions.checkedItem' })).value, index);
      await captureEvidence(this, `settings-theme-music-${value}`);
      await closeAndSaveSettings(environment);
      await assertSettingPersisted(environment, accountKey, 'account', 'theme-music', value);
      await openSettings(categories.mediaShell);
      await assertMediaPage(environment, 1);
      await enterThemeMusic(environment);
      assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: '#themeMusicOptions.checkedItem' })).value, index);
      await closeAndSaveSettings(environment);
    });
  }
});

async function enterThemeMusic(environment) {
  await environment.odc.focusNode({ base: 'scene', keyPath: '#episodeShellLayoutOptions' });
  await environment.odc.setValue({ base: 'scene', keyPath: '#episodeShellLayoutOptions.jumpToItem', value: 2 });
  await environment.ecp.sendKeypress(environment.ecp.Key.Down, { wait: 400 });
  await assertMediaPage(environment, 2);
  assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#themeMusicOptions' }), true);
}

async function assertMediaPage(environment, page) {
  await waitFor(async () => (await environment.odc.getValue({ base: 'scene', keyPath: '#mediaShellPageNumber.text' })).value === `${page} / 2`, `media shell page ${page}`);
  for (const [nodeId, visible] of [
    ['mediaShellLayoutsPage', page === 1], ['mediaShellThemeMusicPage', page === 2],
    ['mediaShellPageDown', page === 1], ['mediaShellPageUp', page === 2]
  ]) {
    assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: `#${nodeId}.visible` })).value, visible);
  }
  assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: '#mediaShellPageHint.text' })).value, 'Additional settings');
}
