import { categories, exerciseRadioSetting } from '../support/settings.mjs';

const cases = [
  { label: 'partial screen', nodeId: 'mediaShellBackgroundOptions', index: 1, key: 'media-shell-background', value: 'partial-screen' },
  { label: 'cinematic', nodeId: 'mediaShellBackgroundOptions', index: 2, key: 'media-shell-background', value: 'cinematic' },
  { label: 'full screen', nodeId: 'mediaShellBackgroundOptions', index: 0, key: 'media-shell-background', value: 'full-screen' },
  { label: 'theme music on', nodeId: 'themeMusicOptions', index: 1, key: 'theme-music', value: 'on' },
  { label: 'theme music off', nodeId: 'themeMusicOptions', index: 0, key: 'theme-music', value: 'off' }
];

describe('Starfin Media Shell settings persistence', function () {
  for (const testCase of cases) {
    it(`persists ${testCase.label}`, async function () {
      await exerciseRadioSetting(this, {
        ...testCase,
        category: categories.mediaShell,
        scope: 'account',
        checkpoint: `settings-media-shell-${testCase.value}`
      });
    });
  }
});
