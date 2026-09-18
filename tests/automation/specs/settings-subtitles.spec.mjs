import { categories, exerciseRadioSetting } from '../support/settings.mjs';

const cases = [
  { label: 'Prefer external subtitles', index: 1, value: 'prefer-external' },
  { label: 'Always burn in', index: 2, value: 'always' },
  { label: 'During transcoding', index: 0, value: 'during-transcoding' }
];

describe('Starfin Subtitles settings persistence', function () {
  for (const testCase of cases) {
    it(`persists ${testCase.label}`, async function () {
      await exerciseRadioSetting(this, {
        category: categories.subtitles,
        nodeId: 'subtitleBurnInOptions',
        index: testCase.index,
        scope: 'global',
        key: 'subtitle-burn-in-mode',
        value: testCase.value,
        checkpoint: `settings-subtitles-${testCase.value}`
      });
    });
  }
});
