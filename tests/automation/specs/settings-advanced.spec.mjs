import assert from 'node:assert/strict';
import { captureEvidence } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import {
  categories,
  closeAndSaveSettings,
  openSettings,
  readSetting
} from '../support/settings.mjs';

describe('Starfin Advanced settings safety', function () {
  it('aborts Reset Starfin without changing stored data', async function () {
    const { environment, accountKey } = await openSettings(categories.advanced);
    const valueBefore = await readSetting(environment, accountKey, 'account', 'tv-library-layout');

    await environment.odc.setValue({
      base: 'scene',
      keyPath: '#resetStarfinButton.buttonSelected',
      value: true
    });
    await waitFor(async () => {
      const response = await environment.odc.getValue({
        base: 'scene',
        keyPath: '#resetConfirmation.visible'
      });
      return response.found && response.value === true;
    }, 'the Reset Starfin confirmation');

    await captureEvidence(this, 'settings-advanced-reset-confirmation');
    await environment.odc.setValue({
      base: 'scene',
      keyPath: '#abortResetButton.buttonSelected',
      value: true
    });
    await waitFor(async () => {
      const response = await environment.odc.getValue({
        base: 'scene',
        keyPath: '#resetStarfinButton.visible'
      });
      return response.found && response.value === true;
    }, 'Reset Starfin confirmation to close');

    await closeAndSaveSettings(environment);
    const valueAfter = await readSetting(environment, accountKey, 'account', 'tv-library-layout');
    assert.equal(valueAfter, valueBefore, 'Aborting Reset Starfin should preserve stored settings.');

    const surface = await environment.odc.getValues({
      requests: {
        home: { base: 'scene', keyPath: '#homePage.visible' },
        login: { base: 'scene', keyPath: '#login.visible' }
      }
    });
    assert.equal(surface.results.home?.value, true, 'Home should remain visible after aborting reset.');
    assert.equal(surface.results.login?.value, false, 'Login should remain hidden after aborting reset.');
  });
});
