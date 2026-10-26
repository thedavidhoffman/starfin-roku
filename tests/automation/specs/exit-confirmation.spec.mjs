import assert from 'node:assert/strict';
import { relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { value, press, focusItem } from '../support/remote-keys.mjs';
import { waitFor } from '../support/lifecycle.mjs';

async function openHomeItem(index) {
  const environment = await relaunchAuthenticatedStarfin();
  const target = await waitFor(async () => {
    const count = await value(environment, '#shelvesGroup.getChildCount()');
    for (let row = 0; row < count; row++) {
      const shelf = `#shelvesGroup.${row}`;
      if (await value(environment, `${shelf}.rowContent.getChildCount()`) <= index) continue;
      const id = await value(environment, `${shelf}.rowContent.${index}.raw.Id`);
      if (id) return { control: `${shelf}.#items`, id };
    }
    return false;
  }, `Home shelf with item ${index}`, 45000);
  await focusItem(environment, target.control, target.id, true);
  return { environment, ...target };
}

async function openConfirmation(environment) {
  await press(environment, 'Back');
  await waitFor(async () => await value(environment, '#overlayHost.0.subtype()') === 'ExitConfirmationDialog',
    'Home Back to open exit confirmation');
  assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: '#overlayHost.0.#exit' }), true);
  assert.equal(await value(environment, 'closeRequested'), false);
}

describe('Starfin Home exit confirmation', function () {
  for (const index of [0, 1]) {
    for (const dismissal of ['Back', 'Ok']) {
      it(`restores Home item ${index} after ${dismissal === 'Ok' ? 'Cancel' : 'Back'}`, async function () {
        const { environment, control, id } = await openHomeItem(index);
        try {
          await openConfirmation(environment);
          if (dismissal === 'Ok') {
            await press(environment, 'Left');
            await waitFor(async () => await environment.odc.hasFocus({ base: 'scene', keyPath: '#overlayHost.0.#cancel' }),
              'Cancel button focus');
          }
          await press(environment, dismissal);
          await waitFor(async () => await value(environment, '#overlayHost.getChildCount()') === 0,
            'exit confirmation to close');
          assert.equal(await environment.odc.hasFocus({ base: 'scene', keyPath: control }), true);
          const position = await value(environment, `${control}.rowItemFocused`);
          assert.equal(await value(environment, `${control}.content.${position[0]}.${position[1]}.raw.Id`), id);
          assert.equal(await value(environment, 'closeRequested'), false);
        } finally {
          if (await value(environment, '#overlayHost.getChildCount()') > 0) await press(environment, 'Back');
        }
      });
    }
  }

  it('exits when OK selects the default Exit button', async function () {
    const { environment } = await openHomeItem(0);
    try {
      await openConfirmation(environment);
      await press(environment, 'Ok');
      await waitFor(async () => (await environment.ecp.getActiveApp()).app?.id !== 'dev',
        'confirmed application exit');
    } finally {
      await relaunchAuthenticatedStarfin();
    }
  });
});
