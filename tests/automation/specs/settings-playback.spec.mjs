import { categories, exerciseRadioSetting } from '../support/settings.mjs';

const cases = [
  { label: 'Play Next Immediately', index: 1, value: 'play-next-immediately' },
  { label: 'Show Up Next', index: 0, value: 'show-up-next' }
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
