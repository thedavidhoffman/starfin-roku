import { captureEvidence } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { categories, openSettings, closeAndSaveSettings, assertSettingPersisted } from '../support/settings.mjs';

const settingsContent = '#overlayHost.0.#content.0';

const cases = [
  { label: 'Prefer external subtitles', index: 1, value: 'prefer-external' },
  { label: 'Always burn in', index: 2, value: 'always' },
  { label: 'During transcoding', index: 0, value: 'during-transcoding' }
];

describe('Starfin Subtitles settings persistence', function () {
  for (const testCase of cases) {
    it(`persists ${testCase.label}`, async function () {
      const { environment, accountKey } = await openSettings(categories.subtitles);
      const value = async (keyPath) => (await environment.odc.getValue({ base: 'scene', keyPath: `${settingsContent}.${keyPath}` })).value;
      const focused = async (nodeId) => environment.odc.isInFocusChain({ base: 'scene', keyPath: `${settingsContent}.#${nodeId}` });
      await waitFor(async () => await focused('accountSubtitleModes') === true,
        'subtitle modes to load and receive focus', 35000);
      await environment.odc.setValue({
        base: 'scene', keyPath: `${settingsContent}.#accountSubtitleModes.jumpToItem`, value: 4
      });
      await waitFor(async () => await value('#accountSubtitleModes.itemFocused') === 4, 'the last subtitle mode');
      await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      await waitFor(async () => await focused('accountSubtitleLanguage') === true, 'Edit to receive focus');
      await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      await waitFor(async () =>
        await value('#subtitleLocalPage.visible') === true &&
        await value('#subtitleAccountPage.visible') === false &&
        await focused('subtitleBurnInOptions') === true &&
        await value('#subtitleBurnInOptions.itemFocused') === 0,
      'burn-in page to open with its first option focused');

      for (let index = 0; index < testCase.index; index++) {
        await environment.ecp.sendKeypress(environment.ecp.Key.Down);
      }
      await environment.ecp.sendKeypress(environment.ecp.Key.Ok);
      await waitFor(async () => await value('#subtitleBurnInOptions.checkedItem') === testCase.index, 'burn-in selection');
      await captureEvidence(this, `settings-subtitles-${testCase.value}`);
      await closeAndSaveSettings(environment);
      await assertSettingPersisted(environment, accountKey, 'account', 'subtitle-burn-in-mode', testCase.value);
    });
  }
});
