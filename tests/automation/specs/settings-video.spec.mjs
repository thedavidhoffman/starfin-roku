import { categories, exerciseRadioSetting } from '../support/settings.mjs';

const cases = [
  { label: 'Automatic with remux disabled', index: 1, value: 'automatic-no-remux' },
  { label: 'Force transcode with remux allowed', index: 2, value: 'transcode-allow-remux' },
  { label: 'Force transcode with remux disabled', index: 3, value: 'transcode-no-remux' },
  { label: 'Automatic', index: 0, value: 'automatic' }
];

describe('Starfin Video settings persistence', function () {
  for (const testCase of cases) {
    it(`persists ${testCase.label}`, async function () {
      await exerciseRadioSetting(this, {
        category: categories.video,
        nodeId: 'videoStreamingModeOptions',
        index: testCase.index,
        scope: 'global',
        key: 'video-streaming-mode',
        value: testCase.value,
        checkpoint: `settings-video-${testCase.value}`
      });
    });
  }
});
