import assert from 'node:assert/strict';
import { captureEvidence } from '../support/evidence.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import {
  categories,
  closeAndSaveSettings,
  openSettings,
  selectRadioOption
} from '../support/settings.mjs';

async function setAccountBadge(context, enabled) {
  const { environment } = await openSettings(categories.general);
  const value = enabled ? 'on' : 'off';

  await selectRadioOption(environment, 'displayAccountBadgeOptions', enabled ? 1 : 0);
  await captureEvidence(context, `account-badge-setting-${value}`);
  await closeAndSaveSettings(environment);

  await waitFor(async () => {
    const response = await environment.odc.getValue({
      base: 'scene',
      keyPath: '#accountBadge.visible'
    });
    return response.found && response.value === enabled;
  }, `the account badge to be ${enabled ? 'visible' : 'hidden'}`);

  const visible = await environment.odc.getValue({ base: 'scene', keyPath: '#accountBadge.visible' });
  assert.equal(visible.value, enabled, `The account badge should be ${enabled ? 'visible' : 'hidden'}.`);
  await captureEvidence(context, `account-badge-${value}`);
}

describe('Starfin account badge display', function () {
  it('shows and hides the account badge when the system setting changes', async function () {
    await setAccountBadge(this, true);
    await setAccountBadge(this, false);
  });
});
