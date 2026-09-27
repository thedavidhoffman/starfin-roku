import assert from 'node:assert/strict';
import { waitFor } from '../support/lifecycle.mjs';
import { categories, exerciseRadioSetting, openSettings, closeAndSaveSettings, selectRadioOption } from '../support/settings.mjs';

const values = ['0', '15', '30', '45', '60', '75', '90', '105', '120'];

describe('Starfin Credits settings persistence', function () {
  it('navigates presets and returns to categories with the remote', async function () {
    const { environment } = await openSettings(categories.credits);
    await environment.ecp.sendKeypress(environment.ecp.Key.Down);
    await environment.ecp.sendKeypress(environment.ecp.Key.Down);
    await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
    await waitFor(async () => {
      const result = await environment.odc.getValue({ base: 'scene', keyPath: '#nextEpisodePromptSecondsOptions.checkedItem' });
      return result.value === 2;
    }, 'the remote to select 30 seconds');

    await environment.ecp.sendKeypress(environment.ecp.Key.Left);
    await waitFor(() => environment.odc.isInFocusChain({ base: 'scene', keyPath: '#userCategoryList' }), 'Left to return to user categories');
    await closeAndSaveSettings(environment);
  });

  for (const [index, value] of values.entries()) {
    it(`persists and restores the ${value} second fallback`, async function () {
      if (value === '0') {
        const { environment } = await openSettings(categories.credits);
        await selectRadioOption(environment, 'nextEpisodePromptSecondsOptions', 1);
        await closeAndSaveSettings(environment);
      }
      await exerciseRadioSetting(this, {
        category: categories.credits,
        scope: 'account',
        nodeId: 'nextEpisodePromptSecondsOptions',
        index,
        key: 'next-episode-prompt-seconds',
        value,
        checkpoint: `settings-credits-${value}`
      });
      const { environment } = await openSettings(categories.credits);
      const selected = await environment.odc.getValue({ base: 'scene', keyPath: '#nextEpisodePromptSecondsOptions.checkedItem' });
      assert.equal(selected.value, index, 'Reopening Credits should restore the saved preset.');
      await closeAndSaveSettings(environment);
    });
  }
});
