import { categories, exerciseRadioSetting } from '../support/settings.mjs';

const cases = [
  { label: 'blue theme', nodeId: 'themeOptions', index: 0, key: 'theme', value: 'blue' },
  { label: 'black theme', nodeId: 'themeOptions', index: 1, key: 'theme', value: 'black' },
  { label: 'grey theme', nodeId: 'themeOptions', index: 2, key: 'theme', value: 'grey' }
];

describe('Starfin Theme settings persistence', function () {
  for (const testCase of cases) {
    it(`persists ${testCase.label}`, async function () {
      await exerciseRadioSetting(this, {
        ...testCase,
        category: categories.theme,
        scope: 'account',
        checkpoint: `settings-theme-${testCase.value}`
      });
    });
  }
});
