import { categories, exerciseRadioSetting, openSettings, selectRadioOption, closeAndSaveSettings } from '../support/settings.mjs';

const cases = [
  { label: 'Play next immediately', index: 1, value: 'play-next-immediately' },
  { label: 'Show "Up Next"', index: 0, value: 'show-up-next' }
];

describe('Starfin Playback settings persistence', function () {
  for (const testCase of cases) {
    it(`persists ${testCase.label}`, async function () {
      await exerciseRadioSetting(this, {
        category: categories.playback,
        nodeId: 'nextItemPlaybackOptions',
        index: testCase.index,
        scope: 'account',
        key: 'next-item-playback',
        value: testCase.value,
        checkpoint: `settings-playback-${testCase.value}`
      });
    });
  }
});

describe('Starfin automatic skipping preferences', function () {
  for (const [nodeId, key] of [['autoSkipIntrosOptions', 'auto-skip-intros'], ['autoSkipCreditsOptions', 'auto-skip-credits']]) {
    for (const [index, value] of ['off', 'on'].entries()) {
      it(`persists ${key} ${value}`, async function () {
        const { environment } = await openSettings(categories.playback);
        await selectRadioOption(environment, nodeId, 1 - index);
        await closeAndSaveSettings(environment);
        await exerciseRadioSetting(this, {
          category: categories.playback, nodeId, index, scope: 'account', key, value,
          checkpoint: `settings-${key}-${value}`
        });
      });
    }
  }
});
