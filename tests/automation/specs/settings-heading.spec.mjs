import assert from 'node:assert/strict';
import { categories, openSettings, closeAndSaveSettings } from '../support/settings.mjs';
import { waitFor } from '../support/lifecycle.mjs';

const headings = [
  ['Libraries', categories.libraries], ['Media shell', categories.mediaShell],
  ['Theme', categories.theme], ['Playback', categories.playback],
  ['Subtitles', categories.accountSubtitles], ['Credits', categories.credits],
  ['TV', categories.tv], ['Screensaver', categories.screensaver],
  ['General', categories.general], ['Video', categories.video], ['Advanced', categories.advanced]
];

describe('Starfin Settings category heading', function () {
  for (const [title, category] of headings) {
    it(`identifies ${title} when its page has focus`, async function () {
      const { environment } = await openSettings(category);
      await waitFor(async () => (await environment.odc.getValue({ base: 'scene', keyPath: '#overlayHost.0.title' })).value === `Settings › ${title}`, 'the category heading');
      assert.equal(await environment.odc.isInFocusChain({ base: 'scene', keyPath: `#${category.panelNode}` }), true);
      await closeAndSaveSettings(environment);
    });
  }
});
