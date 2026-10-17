import assert from 'node:assert/strict';
import { categories, openSettingsFromSystemMenu, closeAndSaveSettings } from '../support/settings.mjs';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { value, press } from '../support/remote-keys.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { captureEvidence } from '../support/evidence.mjs';

async function focus(environment, id, item) {
  await waitFor(async () => await environment.odc.isInFocusChain({ base: 'scene', keyPath: '#' + id })
    && (item === undefined || await value(environment, `#${id}.itemFocused`) === item),
  `focus on ${id}${item === undefined ? '' : ` option ${item}`}`);
}

async function reachPicker(environment) {
  await focus(environment, 'nextItemPlaybackOptions');
  await press(environment, 'Down');
  await focus(environment, 'nextItemPlaybackOptions', 1);
  await press(environment, 'Down');
  await focus(environment, 'autoSkipIntrosOptions');
  await press(environment, 'Right');
  await focus(environment, 'autoSkipCreditsOptions');
  await press(environment, 'Left');
  await focus(environment, 'autoSkipIntrosOptions');
  await press(environment, 'Down');
  await focus(environment, 'autoSkipIntrosOptions', 1);
  await press(environment, 'Down');
  await focus(environment, 'nextEpisodePromptButton');
  await press(environment, 'Ok');
  await waitFor(async () => await value(environment, '#confirmationOverlayHost.0.subtype()') === 'NextEpisodePromptDialog',
    'remote OK to open the prompt picker');
}

describe('Starfin Playback remote navigation and layout', function () {
  for (const commit of [false, true]) {
    it(`returns focus after ${commit ? 'selecting an interval' : 'cancelling the interval picker'} with the remote`, async function () {
      const { environment } = await openSettingsFromSystemMenu(await ensureAuthenticated(), categories.playback);
      const original = await value(environment, '#nextEpisodePromptButton.text');
      let previous;
      try {
        await reachPicker(environment);
        await focus(environment, 'promptOptions');
        previous = await value(environment, '#promptOptions.checkedItem');
        const direction = previous === 8 ? 'Up' : 'Down';
        await press(environment, direction);
        await waitFor(async () => await value(environment, '#promptOptions.itemFocused') === previous + (direction === 'Up' ? -1 : 1),
          'remote navigation to update the candidate interval');
        const selected = await value(environment, '#promptOptions.itemFocused');
        assert.notEqual(selected, previous, 'Remote navigation must change the candidate interval.');
        await press(environment, commit ? 'Ok' : 'Back');
        await waitFor(async () => await value(environment, '#confirmationOverlayHost.getChildCount()') === 0, 'picker closure');
        await focus(environment, 'nextEpisodePromptButton');
        assert.equal(await value(environment, '#overlayHost.0.subtype()'), 'SettingsDialog');
        const label = await value(environment, '#nextEpisodePromptButton.text');
        if (commit) assert.notEqual(label, original);
        else assert.equal(label, original);
        await captureEvidence(this, `playback-picker-remote-${commit ? 'selected' : 'cancelled'}`);
      } finally {
        if (await value(environment, '#confirmationOverlayHost.getChildCount()') > 0) await press(environment, 'Back');
        if (previous !== undefined) {
          // Cleanup uses fields so it still works after a remote navigation assertion fails.
          await environment.odc.setValue({ base: 'scene', keyPath: '#nextEpisodePromptButton.buttonSelected', value: true });
          await waitFor(async () => await value(environment, '#confirmationOverlayHost.0.subtype()') === 'NextEpisodePromptDialog', 'cleanup picker');
          await environment.odc.setValue({ base: 'scene', keyPath: '#promptOptions.itemSelected', value: previous });
          await waitFor(async () => await value(environment, '#confirmationOverlayHost.getChildCount()') === 0, 'restored interval');
        }
        await closeAndSaveSettings(environment);
      }
    });
  }

  it('keeps all playback descriptions inside their cards without ellipses', async function () {
    const { environment } = await openSettingsFromSystemMenu(await ensureAuthenticated(), categories.playback);
    try {
      // Both next-item descriptions depend on option focus, not the saved selection.
      for (const option of [0, 1]) {
        if (option) {
          await press(environment, 'Down');
          await focus(environment, 'nextItemPlaybackOptions', option);
        }
        for (const id of ['nextItemPlaybackCard', 'autoSkipIntrosCard', 'autoSkipCreditsCard', 'nextEpisodePromptCard']) {
          const card = '#' + id;
          const count = await value(environment, `${card}.getChildCount()`);
          let measured = 0;
          for (let index = 0; index < count; index++) {
            const label = `${card}.${index}`;
            if (await value(environment, `${label}.subtype()`) !== 'Label') continue;
            if (await value(environment, `${label}.wrap`) !== true || !await value(environment, `${label}.text`)) continue;
            const rect = await value(environment, `${label}.boundingRect()`);
            const translation = await value(environment, `${label}.translation`);
            assert.equal(await value(environment, `${label}.isTextEllipsized`), false, id);
            assert.ok(rect.height > 0, `${id} description must render.`);
            assert.ok(translation[1] + rect.height <= await value(environment, `${card}.cardHeight`), `${id} description fits vertically.`);
            assert.ok(translation[0] + rect.width <= await value(environment, `${card}.cardWidth`), `${id} description fits horizontally.`);
            measured++;
          }
          assert.equal(measured, 1, `${id} must have one visible description.`);
        }
        await captureEvidence(this, `playback-description-layout-${option}`);
      }
    } finally { await closeAndSaveSettings(environment); }
  });
});
