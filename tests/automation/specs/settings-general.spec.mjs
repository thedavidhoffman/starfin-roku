import {
  categories,
  exerciseRadioSetting
} from '../support/settings.mjs';

const accountBadgeCases = [
  { label: 'Account Badge on', index: 1, value: 'on' },
  { label: 'Account Badge off', index: 0, value: 'off' }
];

describe('Starfin General settings persistence', function () {
  for (const testCase of accountBadgeCases) {
    it(`persists ${testCase.label}`, async function () {
      await exerciseRadioSetting(this, {
        category: categories.general,
        nodeId: 'displayAccountBadgeOptions',
        index: testCase.index,
        scope: 'global',
        key: 'display-account-badge',
        value: testCase.value,
        checkpoint: `settings-general-account-badge-${testCase.value}`
      });
    });
  }

});
