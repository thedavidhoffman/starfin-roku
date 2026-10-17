import assert from 'node:assert/strict';
import { waitFor } from '../support/lifecycle.mjs';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { categories, openSettings, openSettingsFromSystemMenu, closeAndSaveSettings, assertSettingPersisted } from '../support/settings.mjs';

async function openPicker(environment) {
  await environment.odc.setValue({ base: 'scene', keyPath: '#nextEpisodePromptButton.buttonSelected', value: true });
  await waitFor(async () => {
    const result = await environment.odc.getValue({ base: 'scene', keyPath: '#confirmationOverlayHost.0.subtype()' });
    return result.value === 'NextEpisodePromptDialog';
  }, 'the interval picker to open above Settings');
}

async function selectInterval(environment, index) {
  await environment.odc.setValue({ base: 'scene', keyPath: '#promptOptions.itemSelected', value: index });
  await waitFor(async () => {
    const result = await environment.odc.getValue({ base: 'scene', keyPath: '#confirmationOverlayHost.getChildCount()' });
    return result.value === 0;
  }, 'the interval picker to close');
}

describe('Starfin Playback prompt picker', function () {
  it('cancels with Back and restores selector focus', async function () {
    const { environment } = await openSettingsFromSystemMenu(await ensureAuthenticated(), categories.playback);
    await waitFor(() => environment.odc.isInFocusChain({ base: 'scene', keyPath: '#nextItemPlaybackOptions' }), 'initial playback option focus');
    for (const [id, item] of [['nextItemPlaybackOptions', 1], ['autoSkipIntrosOptions', 0], ['autoSkipIntrosOptions', 1], ['nextEpisodePromptButton', undefined]]) {
      await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      await waitFor(async () => {
        if (!await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#' + id })) return false;
        if (item === undefined) return true;
        return (await environment.odc.getValue({ base: 'scene', keyPath: `#${id}.itemFocused` })).value === item;
      }, `remote Down to reach ${id}${item === undefined ? '' : ` option ${item}`}`);
    }
    const before = await environment.odc.getValue({ base: 'scene', keyPath: '#nextEpisodePromptButton.text' });
    await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
    await waitFor(async () => (await environment.odc.getValue({ base: 'scene', keyPath: '#confirmationOverlayHost.0.subtype()' })).value === 'NextEpisodePromptDialog', 'remote OK to open the interval picker');
    await environment.ecp.sendKeypress(environment.ecp.Key.Back);
    await waitFor(() => environment.odc.isInFocusChain({ base: 'scene', keyPath: '#nextEpisodePromptButton' }), 'focus to return to the selector');
    const after = await environment.odc.getValue({ base: 'scene', keyPath: '#nextEpisodePromptButton.text' });
    assert.equal(after.value, before.value);
    await closeAndSaveSettings(environment);
  });

  for (const [index, value] of ['0', '15', '30', '45', '60', '75', '90', '105', '120'].entries()) {
    it(`persists and restores the ${value} second fallback`, async function () {
      const { environment, accountKey } = await openSettings(categories.playback);
      await openPicker(environment);
      await selectInterval(environment, index === 0 ? 1 : 0);
      await closeAndSaveSettings(environment);
      await openSettings(categories.playback);
      await openPicker(environment);
      await selectInterval(environment, index);
      await closeAndSaveSettings(environment);
      await assertSettingPersisted(environment, accountKey, 'account', 'next-episode-prompt-seconds', value);
      await openSettings(categories.playback);
      await openPicker(environment);
      const restored = await environment.odc.getValue({ base: 'scene', keyPath: '#promptOptions.checkedItem' });
      assert.equal(restored.value, index);
      await environment.ecp.sendKeypress(environment.ecp.Key.Back);
      await closeAndSaveSettings(environment);
    });
  }
});
