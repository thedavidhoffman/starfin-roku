import { categories, exerciseRadioSetting, openSettings, selectRadioOption, closeAndSaveSettings } from '../support/settings.mjs';

describe('Starfin combined Home preference', function () {
  for (const enabled of [true, false]) {
    const value = enabled ? 'on' : 'off';
    it(`persists combining ${value}`, async function () {
      const { environment } = await openSettings(categories.home);
      await selectRadioOption(environment, 'combineWatchingOptions', enabled ? 0 : 1);
      await closeAndSaveSettings(environment);

      await exerciseRadioSetting(this, {
        category: categories.home,
        nodeId: 'combineWatchingOptions',
        index: enabled ? 1 : 0,
        scope: 'account',
        key: 'combine-continue-watching-next-up',
        value,
        checkpoint: `settings-home-combine-${value}`
      });
    });
  }
});
