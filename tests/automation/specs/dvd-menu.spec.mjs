import assert from 'node:assert/strict';
import { relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { categories, openSettingsFromSystemMenu, selectRadioOption, closeAndSaveSettings, readSetting } from '../support/settings.mjs';
import { startDvdPreviewProxy } from '../support/dvd-preview-proxy.mjs';

const read = async (env, keyPath) => (await env.odc.getValue({ base: 'scene', keyPath })).value;
const focused = (env, id) => env.odc.hasFocus({ base: 'scene', keyPath: `#${id}` });
const key = (env, name) => env.ecp.sendKeypress(env.ecp.Key[name], { wait: 200 });

async function badge(env, enabled) {
  await openSettingsFromSystemMenu(env, categories.general);
  await selectRadioOption(env, 'displayAccountBadgeOptions', enabled ? 1 : 0);
  await closeAndSaveSettings(env);
}

async function enter(env, manifest) {
  await waitFor(async () => await read(env, '#homePage.ready') === true, 'Home ready', 60000);
  // All workflow navigation starts with remote keys from the visible Home surface.
  for (let i = 0; i < 20 && !await focused(env, 'homeButton'); i++) {
    const inHeader = await env.odc.isInFocusChain({ base: 'scene', keyPath: '#header' });
    await key(env, inHeader ? 'Left' : 'Up');
  }
  assert.equal(await focused(env, 'homeButton'), true);
  await key(env, 'Left');
  assert.equal(await focused(env, 'dvdDemoButton'), true);
  await key(env, 'Ok');
  await screen(env, manifest, 'home');
}

async function screen(env, manifest, name) {
  const asset = manifest.disc.menuAssets.find(asset => asset.id === manifest.menuMap.screens[name].assetId);
  await waitFor(async () => (await read(env, '#dvdPlayer.#menuImage.uri'))?.endsWith(asset.image)
    && await read(env, '#dvdPlayer.#menuImage.loadStatus') === 'ready', `DVD ${name} artwork`, 60000);
}

async function choose(env, manifest, name, target) {
  const asset = manifest.disc.menuAssets.find(asset => asset.id === manifest.menuMap.screens[name].assetId);
  const buttons = asset.navigation[0].buttons.filter(button => button.group === 1);
  let current;
  for (const button of buttons) if (await focused(env, `dvdButton${button.number}`)) current = button.number;
  assert.ok(current, 'A real menu hotspot must own focus.');
  const queue = [[current, []]], seen = new Set();
  let path;
  while (queue.length) {
    const [number, steps] = queue.shift();
    if (number === target) { path = steps; break; }
    if (seen.has(number)) continue;
    seen.add(number);
    const button = buttons.find(button => button.number === number);
    if (!button) continue;
    for (const direction of ['up', 'down', 'left', 'right']) {
      queue.push([button[direction], [...steps, direction[0].toUpperCase() + direction.slice(1)]]);
    }
  }
  assert.ok(path, `Button ${target} must be reachable through DVD neighbors.`);
  for (const direction of path) await key(env, direction);
  assert.equal(await focused(env, `dvdButton${target}`), true);
  await key(env, 'Ok');
}

async function acknowledgment(env) {
  await waitFor(async () => await read(env, '#messageOverlayHost.getChildCount()') === 1, 'DVD selection acknowledgment');
  return read(env, '#messageOverlayHost.0.message');
}

describe('Starfin DVD menu demo', function () {
  this.timeout(180000);
  let env, manifest, originalBadge, session, proxy;

  beforeEach(async function () {
    proxy = undefined;
    session = undefined;
    originalBadge = undefined;
    env = await relaunchAuthenticatedStarfin();
    await waitFor(async () => await read(env, '#homePage.ready') === true, 'Home ready', 60000);
    originalBadge = await readSetting(env, '', 'global', 'display-account-badge') ?? 'off';
    if (originalBadge === 'on') await badge(env, false);
    session = await read(env, '#authController.authenticatedSession');
    const response = await fetch(session.server.replace(/\/$/, '') + '/Starfin/Dvd/Demos/robots-of-death-special-edition/Manifest', {
      headers: { Authorization: `MediaBrowser Token="${session.token}"` }
    });
    assert.equal(response.status, 200, 'The configured server must have the authenticated DVD demo plugin installed.');
    manifest = await response.json();
  });

  afterEach(async function () {
    try {
      if (proxy && session) {
        await env.odc.setValue({ base: 'scene', keyPath: '#authController.authenticatedSession', value: session });
      }
      env = await relaunchAuthenticatedStarfin();
      if (originalBadge === 'on') await badge(env, true);
    } finally {
      if (proxy) await proxy.close();
    }
  });

  it('selects Play All through the original menu and returns focus after acknowledgment', async function () {
    await enter(env, manifest);
    await captureEvidence(this, 'dvd-original-menu');
    await choose(env, manifest, 'home', 1);
    assert.match(await acknowledgment(env), /Play All - title 6, chapter 1/);
    assert.match(await acknowledgment(env), /Playback unavailable/);
    await key(env, 'Ok');
    await waitFor(() => focused(env, 'dvdButton1'), 'restored DVD hotspot');
    await key(env, 'Back');
    await waitFor(() => focused(env, 'dvdDemoButton'), 'DVD exit entry focus');
    assert.equal(await read(env, '#homePage.visible'), true);
  });

  it('opens scene selection and reports the selected chapter', async function () {
    await enter(env, manifest);
    await choose(env, manifest, 'home', 3);
    await screen(env, manifest, 'scenes1');
    await choose(env, manifest, 'scenes1', 2);
    assert.match(await acknowledgment(env), /title 2, chapter 2/);
    await captureEvidence(this, 'dvd-chapter-selection');
    await key(env, 'Back');
    await waitFor(() => focused(env, 'dvdButton2'), 'chapter hotspot focus');
    await key(env, 'Back');
    await screen(env, manifest, 'home');
  });

  it('retains audio, subtitle and Info Text intent across submenus', async function () {
    await enter(env, manifest);
    await choose(env, manifest, 'home', 5);
    await screen(env, manifest, 'subtitles-off');
    await choose(env, manifest, 'subtitles-off', 1);
    await screen(env, manifest, 'subtitles-on');
    await key(env, 'Back');
    await screen(env, manifest, 'home');
    await choose(env, manifest, 'home', 4);
    await screen(env, manifest, 'extras1');
    await choose(env, manifest, 'extras1', 8);
    await screen(env, manifest, 'extras2-off');
    await choose(env, manifest, 'extras2-off', 3);
    await screen(env, manifest, 'extras2-on');
    await choose(env, manifest, 'extras2-on', 2);
    await screen(env, manifest, 'audio1');
    await choose(env, manifest, 'audio1', 2);
    await screen(env, manifest, 'audio2');
    await choose(env, manifest, 'audio2', 4);
    const message = await acknowledgment(env);
    assert.match(message, /Audio track 2/);
    assert.match(message, /Subtitles: On requested/);
    assert.match(message, /Info Text: On requested/);
    await captureEvidence(this, 'dvd-track-intent');
  });

  it('keeps the still and remote navigation usable when the preview fails', async function () {
    proxy = await startDvdPreviewProxy(env.selectedDevice.host, session.server);
    // Configure network failure before entering the workflow; no menu state is injected.
    await env.odc.setValue({ base: 'scene', keyPath: '#authController.authenticatedSession', value: { ...session, server: proxy.url } });
    await waitFor(async () => await read(env, '#homePage.loadRequest.server') === proxy.url
      && await read(env, '#homePage.ready') === true, 'proxy-backed Home', 60000);
    await enter(env, manifest);
    await waitFor(() => proxy.previewFailures > 0, 'preview failure request');
    await waitFor(async () => !await read(env, '#dvdPlayer.#menuPreview.subtype()'), 'preview fallback', 30000);
    assert.equal(await read(env, '#dvdPlayer.#menuImage.loadStatus'), 'ready');
    await choose(env, manifest, 'home', 2);
    await screen(env, manifest, 'episodes');
    await captureEvidence(this, 'dvd-preview-fallback-navigation');
  });
});
