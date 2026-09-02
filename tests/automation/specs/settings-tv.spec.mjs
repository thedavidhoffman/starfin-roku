import { categories, exerciseRadioSetting } from '../support/settings.mjs';

const cases = [
  { label: 'horizontal episode list', index: 0, value: 'horizontal' },
  { label: 'vertical episode list', index: 1, value: 'vertical' }
];

describe('Starfin TV settings persistence', function () {
  for (const testCase of cases) {
    it(`persists ${testCase.label}`, async function () {
      await exerciseRadioSetting(this, {
        category: categories.tv,
        nodeId: 'tvEpisodeListDisplayOptions',
        index: testCase.index,
        scope: 'account',
        key: 'tv-ep-list-scroll',
        value: testCase.value,
        checkpoint: `settings-tv-${testCase.value}`
      });
    });
  }
});
