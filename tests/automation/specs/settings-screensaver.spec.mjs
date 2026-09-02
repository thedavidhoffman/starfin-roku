import { categories, exerciseRadioSetting } from '../support/settings.mjs';

const cases = [
  { label: 'Bouncing artwork screensaver', nodeId: 'screensaverTypeOptions', index: 1, key: 'screensaver-type', value: 'bounce' },
  { label: 'Starfield screensaver', nodeId: 'screensaverTypeOptions', index: 2, key: 'screensaver-type', value: 'starfield' },
  { label: 'None screensaver', nodeId: 'screensaverTypeOptions', index: 0, key: 'screensaver-type', value: 'none' },
  { label: '5-minute delay', nodeId: 'screensaverDelayOptions', index: 1, key: 'screensaver-delay', value: '5' },
  { label: '15-minute delay', nodeId: 'screensaverDelayOptions', index: 2, key: 'screensaver-delay', value: '15' },
  { label: '30-minute delay', nodeId: 'screensaverDelayOptions', index: 3, key: 'screensaver-delay', value: '30' },
  { label: '1-minute delay', nodeId: 'screensaverDelayOptions', index: 0, key: 'screensaver-delay', value: '1' }
];

describe('Starfin Screensaver settings persistence', function () {
  for (const testCase of cases) {
    it(`persists ${testCase.label}`, async function () {
      await exerciseRadioSetting(this, {
        ...testCase,
        category: categories.screensaver,
        scope: 'account',
        checkpoint: `settings-screensaver-${testCase.key}-${testCase.value}`
      });
    });
  }
});
