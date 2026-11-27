import assert from 'node:assert/strict';
import { relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { captureEvidence } from '../support/evidence.mjs';

const read = async (env, keyPath) => (await env.odc.getValue({ base: 'scene', keyPath })).value;
const key = (env, name) => env.ecp.sendKeypress(env.ecp.Key[name], { wait: 200 });
const inFocus = async (env, keyPath) => env.odc.isInFocusChain({ base: 'scene', keyPath });

async function openDvdLibrary(env) {
  await waitFor(async () => await read(env, '#homePage.ready') === true, 'Home ready', 60000);
  await waitFor(async () => await read(env, '#dvdDiscovery.available') === true,
    'DVD plugin discovery (requires the current plugin and visible My Media row)', 15000);
  const shelves = '#homePage.#shelvesGroup';
  let target;
  const count = await read(env, `${shelves}.getChildCount()`);
  for (let row = 0; row < count; row++) {
    const shelf = `${shelves}.${row}`;
    const items = await read(env, `${shelf}.rowContent.getChildCount()`);
    for (let column = 0; column < items; column++) {
      if (await read(env, `${shelf}.rowContent.${column}.raw.Id`) === 'starfin-dvd-library') {
        target = { shelf, column };
      }
    }
  }
  assert.ok(target, 'Enable the My Media row before running the DVD workflow.');
  // Read UI state to choose remote keys; never inject selection or focus events.
  for (let i = 0; i < 30 && !await inFocus(env, '#header'); i++) await key(env, 'Up');
  for (let i = 0; i < count + 2 && !await inFocus(env, target.shelf); i++) await key(env, 'Down');
  assert.equal(await inFocus(env, target.shelf), true);
  for (let i = 0; i < 100; i++) {
    const focused = await read(env, `${target.shelf}.#items.rowItemFocused`);
    if (focused?.[1] === target.column) break;
    await key(env, focused?.[1] > target.column ? 'Left' : 'Right');
  }
  assert.equal((await read(env, `${target.shelf}.#items.rowItemFocused`))[1], target.column);
  await key(env, 'Ok');
  await waitFor(async () => await read(env, '#dvdLibrary.#posters.visible') === true,
    'DVD library cards or titles (requires scanned discs)', 60000);
  if (await read(env, '#dvdLibrary.#browseByButton.visible') !== true) {
    await key(env, 'Ok');
    await waitFor(async () => await read(env, '#dvdLibrary.#browseByButton.visible') === true
      && await read(env, '#dvdLibrary.#posters.visible') === true, 'DVD title grid', 60000);
  }
}

describe('DVD native library workflow', function () {
  this.timeout(180000);
  let env;

  beforeEach(async function () {
    env = await relaunchAuthenticatedStarfin();
    await openDvdLibrary(env);
  });

  afterEach(async function () {
    await relaunchAuthenticatedStarfin();
  });

  it('opens the title grid and returns focus after cancelling Browse By', async function () {
    assert.equal(await inFocus(env, '#dvdLibrary.#posters'), true);
    await key(env, 'Up');
    assert.equal(await inFocus(env, '#dvdLibrary.#browseByButton'), true);
    await key(env, 'Ok');
    await waitFor(async () => await read(env, '#overlayHost.getChildCount()') === 1, 'Browse dialog');
    await key(env, 'Back');
    await waitFor(() => inFocus(env, '#dvdLibrary.#browseByButton'), 'Browse focus restored');
    await key(env, 'Down');
    assert.equal(await inFocus(env, '#dvdLibrary.#posters'), true);
    await captureEvidence(this, 'dvd-native-library');
  });

  it('opens the selected native DVD and returns to the retained title grid', async function () {
    const selected = await read(env, '#dvdLibrary.#posters.itemFocused');
    await key(env, 'Ok');
    await waitFor(async () => await read(env, '#dvdPlayer.visible') === true
      || await read(env, '#overlayHost.getChildCount()') === 1, 'Disc selection or player');
    if (await read(env, '#dvdPlayer.visible') !== true) await key(env, 'Ok');
    await waitFor(async () => await read(env, '#dvdPlayer.visible') === true, 'Native DVD player');
    // Resume, when offered, uses the default choice and does not erase saved progress.
    if (await read(env, '#overlayHost.getChildCount()') === 1) await key(env, 'Ok');
    await captureEvidence(this, 'dvd-native-startup');
    for (let i = 0; i < 12 && await read(env, '#dvdLibrary.visible') !== true; i++) {
      await key(env, 'Back');
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    await waitFor(async () => await read(env, '#dvdLibrary.visible') === true, 'Retained library return', 15000);
    assert.equal(await read(env, '#dvdLibrary.#posters.itemFocused'), selected);
    assert.equal(await inFocus(env, '#dvdLibrary.#posters'), true);
  });
});
