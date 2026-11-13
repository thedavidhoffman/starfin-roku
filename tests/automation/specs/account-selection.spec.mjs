import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { startAccountSelectionFixture } from '../support/account-selection-fixture.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { exitStarfin, relaunchStarfin, waitFor, waitForMainScene, waitForStartup } from '../support/lifecycle.mjs';
import { categories, openSettings, selectRadioOption, closeAndSaveSettings } from '../support/settings.mjs';

const picker = '#startupAccountHost.0';
const homePaths = new Set(['/userviews', '/items/latest', '/useritems/resume', '/shows/nextup']);
const encode = value => encodeURIComponent(value).replace(/[!'()*]/g, char => `%${char.charCodeAt(0).toString(16).toUpperCase()}`);
const keyFor = (server, userId) => `v2/${encode(server)}/${encode(userId)}`;

describe('Starfin startup account selection and switching', function () {
  this.timeout(120000);
  let environment;
  let fixture;
  let snapshot;
  const value = async keyPath => (await environment.odc.getValue({ base: 'scene', keyPath })).value;
  const set = (keyPath, value) => environment.odc.setValue({ base: 'scene', keyPath, value });
  const press = key => environment.ecp.sendKeypress(key);
  const focused = keyPath => environment.odc.isInFocusChain({ base: 'scene', keyPath });
  const visible = path => waitFor(async () => await value(`${path}.visible`) === true, `${path} visible`);
  const ready = () => waitFor(async () => await value('#homePage.visible') === true && await value('#homePage.ready') === true, 'fixture Home ready', 45000);
  const account = (server = 'a', index = 0) => ({ server: fixture.url(server), userId: `u${index}`, username: `User u${index}`, token: `${server}-token` });

  async function deleteStarfinSections() {
    const registry = await environment.odc.readRegistry();
    const sections = Object.keys(registry.values ?? {}).filter(name => name.toUpperCase().startsWith('STARFIN_'));
    if (sections.length) await environment.odc.deleteRegistrySections({ sections });
  }

  async function seed(accounts, enabled = true, launchParams = undefined) {
    await deleteStarfinSections();
    const values = { STARFIN_ROKU: { 'select-account-at-startup': enabled ? 'on' : 'off' } };
    for (const [index, entry] of accounts.entries()) {
      const key = keyFor(entry.server, entry.userId);
      values[`STARFIN_ACCOUNT_${key}`] = {
        server: entry.server, 'user-id': entry.userId, username: entry.username,
        token: entry.token, theme: index === 0 ? 'blue' : 'grey', 'theme-music': 'off'
      };
      if (index === 0) Object.assign(values.STARFIN_ROKU, { 'active-account-key': key, server: entry.server });
    }
    await environment.odc.writeRegistry({ values });
    fixture.requests.length = 0;
    if (launchParams) {
      await exitStarfin(environment);
      await environment.ecp.sendLaunchChannel({ channelId: 'dev', params: launchParams, verifyLaunch: true, verifyLaunchTimeOut: 15000 });
      await waitForMainScene(environment);
    } else await relaunchStarfin(environment);
    await waitForStartup(environment);
  }

  async function openSwitcher() {
    await set('#header.switchAccountSelected', true);
    await waitFor(async () => await value('#overlayHost.0.subtype()') === 'AccountPickerDialog', 'account switcher');
  }

  async function signInFromPicker() {
    await set(`${picker}.#signInButton.buttonSelected`, true);
    await visible('#login');
  }

  async function assertGate() {
    assert.equal(await value('#authenticatedContent.visible'), false);
    assert.equal(await value('#header.visible'), false);
    assert.equal(await value('#homePage.visible'), false);
    assert.ok(await value('#homePage.loadRequest') == null);
    assert.equal(fixture.requests.filter(request => homePaths.has(request.path)).length, 0);
    assert.equal(fixture.requests.filter(request => /^\/users\/u\d+$/.test(request.path)).length, 0);
  }

  before(async () => {
    environment = await ensureAuthenticated();
    await ready();
    fixture = await startAccountSelectionFixture(environment.selectedDevice.host);
  });
  beforeEach(async () => {
    const registry = await environment.odc.readRegistry();
    snapshot = Object.fromEntries(Object.entries(registry.values ?? {}).filter(([name]) => name.toUpperCase().startsWith('STARFIN_')));
    for (const id of ['a', 'b']) Object.assign(fixture.state(id), { authStatus: 200, holdAuth: false, holdHome: false, approved: false });
  });
  afterEach(async () => {
    // Restore all Starfin sections, including any accounts created by sign-in.
    // No fixture credentials or startup preference may leak into later suites.
    for (const id of ['a', 'b']) {
      fixture.release(id, 'auth');
      fixture.release(id, 'home');
    }
    await set('#authController.quickConnectCancelRequested', true);
    await waitFor(async () => await value('#loadingSpinner.blockInteraction') !== true, 'authentication to settle before restoring registry', 45000);
    await deleteStarfinSections();
    await environment.odc.writeRegistry({ values: snapshot });
    await relaunchStarfin(environment);
    await waitForStartup(environment);
  });
  after(async () => { if (fixture) await fixture.close(); });

  it('opens Login for zero signed-in accounts', async () => {
    await seed([]);
    await visible('#login');
    assert.equal(fixture.requests.length, 0);
  });

  it('authorizes a sole account without showing the picker', async () => {
    await seed([account()]);
    await ready();
    assert.notEqual(await value(`${picker}.visible`), true);
    assert.equal(await value('#authController.authenticatedSession.server'), fixture.url('a'));
  });

  it('resumes the active account with startup selection off', async () => {
    await seed([account(), account('b')], false);
    await ready();
    assert.equal(fixture.requests.some(request => request.server === 'b'), false);
  });

  it('persists the General setting and gates the next launch', async () => {
    await seed([account(), account('b')], false);
    await ready();
    await openSettings(categories.general);
    await selectRadioOption(environment, 'selectAccountAtStartupOptions', 1);
    await closeAndSaveSettings(environment);
    assert.equal(await value('#homePage.visible'), true);
    await relaunchStarfin(environment);
    await visible(picker);
  });

  it('makes no Home or authorization requests until selection and blocks duplicate remote selections', async () => {
    await seed([account(), account('b')]);
    await visible(picker);
    await assertGate();
    fixture.state('a').holdAuth = true;
    await press('Select');
    await waitFor(() => fixture.pendingCount('a', 'auth') === 1, 'held authorization');
    await press('Select');
    await press('Down');
    await press('Select');
    assert.equal(fixture.requests.filter(request => /^\/users\/u\d+$/.test(request.path)).length, 1);
    assert.equal(fixture.requests.filter(request => homePaths.has(request.path)).length, 0);
    assert.equal(await value('#homePage.visible'), false);
    assert.equal(await value('#header.visible'), false);
    assert.ok(await value('#homePage.loadRequest') == null);
    fixture.release('a', 'auth');
    await ready();
  });

  it('scrolls six horizontal startup accounts and returns from the footer', async function () {
    await seed(Array.from({ length: 6 }, (_, index) => account('a', index)));
    assert.equal(await value(`${picker}.#accountRows.translation.0`), 74);
    for (let i = 0; i < 5; i++) await press('Right');
    await waitFor(async () => (await value(`${picker}.#accountRows.rowItemFocused`))?.[1] === 5, 'sixth horizontal account');
    assert.equal(await value(`${picker}.#rightChevron.visible`), false);
    assert.equal(await value(`${picker}.#leftChevron.visible`), true);
    await captureEvidence(this, 'startup-horizontal-sixth-account');
    await press('Down');
    assert.equal(await focused(`${picker}.#signInButton`), true);
    await press('Up');
    assert.deepEqual(await value(`${picker}.#accountRows.rowItemFocused`), [0, 5]);
  });

  it('scrolls six vertical accounts and preserves focus after forget cancellation', async function () {
    await seed(Array.from({ length: 6 }, (_, index) => account(index % 2 ? 'b' : 'a', index)));
    assert.equal(await value(`${picker}.#verticalAccounts.numRows`), 5);
    for (let i = 0; i < 5; i++) await press('Down');
    await waitFor(async () => await value(`${picker}.#verticalAccounts.itemFocused`) === 5, 'sixth vertical account');
    await captureEvidence(this, 'startup-vertical-sixth-account');
    await press('Info');
    await visible(`${picker}.#removalPreview`);
    await press('Back');
    assert.equal(await value(`${picker}.#verticalAccounts.itemFocused`), 5);
    await press('Down');
    assert.equal(await focused(`${picker}.#signInButton`), true);
    await press('Up');
    assert.equal(await value(`${picker}.#verticalAccounts.itemFocused`), 5);
  });

  it('forgets the other-server account without automatically authenticating the remaining user', async () => {
    await seed([account(), account('b')]);
    await press('Down');
    await waitFor(async () => await value(`${picker}.#verticalAccounts.itemFocused`) === 1, 'inactive account focus before forgetting');
    await press('Info');
    await visible(`${picker}.#removalPreview`);
    await press('Select');
    await visible(`${picker}.#accountRows`);
    assert.equal((await value(`${picker}.accounts`)).length, 1);
    await assertGate();
  });

  it('lets the last-used startup account open and cancel forgetting without clearing its reference', async () => {
    await seed([account(), account('b')]);
    assert.equal(await value(`${picker}.#verticalAccounts.content.0.accountStatus`), '* to forget');
    await press('Info');
    await visible(`${picker}.#removalPreview`);
    await press('Back');
    assert.equal(await value(`${picker}.#removalPreview.visible`), false);
    assert.equal((await value(`${picker}.accounts`)).length, 2);
    assert.equal((await environment.odc.readRegistry()).values.STARFIN_ROKU['active-account-key'], keyFor(fixture.url('a'), 'u0'));
  });

  it('clears the last-used reference only after confirmed startup forgetting', async () => {
    await seed([account(), account('b')]);
    await press('Info');
    await visible(`${picker}.#removalPreview`);
    await press('Select');
    await waitFor(async () => (await value(`${picker}.accounts`)).length === 1, 'last-used account removed');
    const registry = (await environment.odc.readRegistry()).values;
    assert.equal(registry.STARFIN_ROKU['active-account-key'], undefined);
    assert.equal(registry[`STARFIN_ACCOUNT_${keyFor(fixture.url('a'), 'u0')}`], undefined);
    await assertGate();
  });

  it('keeps the authenticated account protected in the switcher dialog', async () => {
    await seed([account(), account('b')], false);
    await ready();
    await openSwitcher();
    assert.equal(await value('#overlayHost.0.#verticalAccounts.content.0.accountStatus'), 'Active');
    await press('Info');
    assert.equal(await value('#overlayHost.0.#removalPreview.visible'), false);
    await press('Back');
  });

  it('returns a connection failure to the selected startup account', async () => {
    fixture.state('b').authStatus = 503;
    await seed([account(), account('b')]);
    await press('Down');
    await press('Select');
    await visible('#messageOverlayHost');
    await press('Select');
    await waitFor(async () => await focused(`${picker}.#verticalAccounts`), 'picker focus after error');
    assert.equal(await value(`${picker}.#verticalAccounts.itemFocused`), 1);
    assert.equal(fixture.requests.filter(request => homePaths.has(request.path)).length, 0);
  });

  it('removes an expired token and refreshes eligibility when Login is cancelled', async () => {
    fixture.state('b').authStatus = 401;
    await seed([account(), account('b')]);
    await press('Down');
    await press('Select');
    await visible('#login');
    assert.equal(await value('#login.serverValue'), fixture.url('b'));
    assert.equal(await value('#login.usernameValue'), 'User u0');
    await press('Back');
    await visible(`${picker}.#accountRows`);
    assert.equal((await value(`${picker}.accounts`)).length, 1);
    const registry = await environment.odc.readRegistry();
    assert.equal(registry.values[`STARFIN_ACCOUNT_${keyFor(fixture.url('b'), 'u0')}`].token, undefined);
  });

  for (const nested of ['keyboard', 'discovery', 'quick-connect']) {
    it(`lets ${nested} consume Back before returning from Login to startup`, async () => {
      await seed([account(), account('b')]);
      await signInFromPicker();
      if (nested === 'keyboard') {
        await press('Down');
        await press('Select');
        await waitFor(async () => await value('dialog.subtype()') === 'StandardKeyboardDialog', 'username keyboard');
      } else if (nested === 'discovery') {
        await press('Select');
        await waitFor(async () => await value('#overlayHost.0.subtype()') === 'ServerDiscoveryDialog', 'server discovery');
      } else {
        await set('#login.quickConnectRequested', { server: fixture.url('a') });
        await visible('#quickConnectPanel');
      }
      await press('Back');
      assert.equal(await value('#login.visible'), true);
      assert.equal(await value(`${picker}.visible`), false);
      await press('Back');
      await visible(picker);
    });
  }

  it('completes startup through Quick Connect', async () => {
    await seed([account(), account('b')]);
    await signInFromPicker();
    fixture.state('b').approved = true;
    await set('#login.quickConnectRequested', { server: fixture.url('b') });
    await ready();
    assert.equal(await value('#authController.authenticatedSession.server'), fixture.url('b'));
  });

  it('completes startup through additional password sign-in', async () => {
    await seed([account(), account('b')]);
    await signInFromPicker();
    await set('#login.serverValue', fixture.url('b'));
    await set('#login.usernameValue', 'u2');
    await set('#login.passwordValue', 'fixture-password');
    await environment.odc.callFunc({ base: 'scene', keyPath: '#login', funcName: 'focusLoginButton' });
    await press('Select');
    await ready();
    assert.equal(await value('#authController.authenticatedSession.userId'), 'u2');
  });

  it('retains a cold deep link until selection and resolves it against the selected server', async () => {
    await seed([account(), account('b')], true, { contentId: 'missing-item', mediaType: 'movie' });
    await assertGate();
    assert.equal(fixture.requests.some(request => request.path === '/items/missing-item'), false);
    await press('Down');
    await press('Select');
    await waitFor(async () => await value('#deepLinkController.destinationRequested.type') === 'homeFallback', 'deep-link fallback');
    await ready();
    assert.deepEqual(fixture.requests.filter(request => request.path === '/items/missing-item').map(request => request.server), ['b']);
  });

  it('reopens a failed dialog selection and leaves Home usable after cancellation', async () => {
    await seed([account(), account('b')], false);
    await ready();
    fixture.state('b').authStatus = 503;
    await openSwitcher();
    await press('Down');
    await press('Select');
    await visible('#messageOverlayHost');
    await press('Select');
    await waitFor(async () => await focused('#overlayHost.0.#verticalAccounts'), 'restored dialog focus');
    assert.equal(await value('#overlayHost.0.#verticalAccounts.itemFocused'), 1);
    await press('Back');
    assert.equal(await value('#homePage.visible'), true);
    assert.equal(await value('#authController.authenticatedSession.server'), fixture.url('a'));
  });

  it('changes server and settings together while discarding delayed outgoing Home results', async () => {
    await seed([account(), account('b')], false);
    await ready();
    fixture.state('a').holdHome = true;
    await environment.odc.callFunc({ base: 'scene', keyPath: '#homePage', funcName: 'activate', funcParams: [true] });
    await waitFor(() => fixture.pendingCount('a', 'home') > 0, 'delayed old Home requests');
    await openSwitcher();
    await press('Down');
    await press('Select');
    await waitFor(async () => await value('#authController.authenticatedSession.server') === fixture.url('b'), 'new session committed');
    await ready();
    fixture.release('a', 'home');
    assert.equal(await value('#homePage.loadRequest.server'), fixture.url('b'));
    assert.equal(await value('#homePage.loadRequest.token'), 'b-token');
    assert.equal(await value('#homePage.settings.theme'), 'grey');
    assert.equal(await value('#authController.authenticatedSession.accountKey'), keyFor(fixture.url('b'), 'u0'));
    await openSwitcher();
    assert.equal(await value('#shelvesGroup.0.rowContent.0.raw.Id'), 'b-library');
    assert.equal(await value('#overlayHost.0.#verticalAccounts.content.0.description'), fixture.url('b'));
    await press('Back');
  });

  it('scrolls the fourth horizontal dialog account within three visible slots', async function () {
    await seed(Array.from({ length: 4 }, (_, index) => account('a', index)), false);
    await ready();
    await openSwitcher();
    assert.deepEqual(await value('#overlayHost.0.#accountRows.itemSize'), [693, 264]);
    for (let index = 0; index < 3; index++) await press('Right');
    await waitFor(async () => (await value('#overlayHost.0.#accountRows.rowItemFocused'))?.[1] === 3, 'fourth dialog account');
    assert.equal(await value('#overlayHost.0.#rightChevron.visible'), false);
    await captureEvidence(this, 'dialog-horizontal-fourth-account');
    await press('Back');
  });

  it('keeps long addresses within fixed vertical rows', async function () {
    const long = { ...account('b'), server: `${fixture.url('b')}/${'long-segment/'.repeat(8)}endpoint` };
    await seed([account(), long]);
    assert.deepEqual(await value(`${picker}.#verticalAccounts.itemSize`), [640, 120]);
    assert.equal(await value(`${picker}.#verticalAccounts.content.1.description`), long.server);
    await press('Down');
    await captureEvidence(this, 'startup-long-address');
    assert.equal(await focused(`${picker}.#verticalAccounts`), true);
    assert.equal(await value(`${picker}.#signInButton.translation.1`), 288);
  });

  it('keeps failed additional password sign-in on Login and permits returning to startup', async () => {
    await seed([account(), account('b')]);
    await signInFromPicker();
    await set('#login.serverValue', fixture.url('b'));
    await set('#login.usernameValue', 'u0');
    await set('#login.passwordValue', 'wrong-password');
    await environment.odc.callFunc({ base: 'scene', keyPath: '#login', funcName: 'focusLoginButton' });
    await press('Select');
    await waitFor(async () => String(await value('#login.statusMessage')).startsWith('Login failed:'), 'password rejection');
    assert.equal(await value('#homePage.visible'), false);
    await press('Back');
    await visible(picker);
    assert.equal((await value(`${picker}.accounts`)).length, 2);
  });

  it('exits on Back from the startup picker without authorizing an account', async () => {
    await seed([account(), account('b')]);
    await press('Back');
    await waitFor(async () => (await environment.ecp.getActiveApp()).app?.id !== 'dev', 'startup Back exit');
    assert.equal(fixture.requests.filter(request => /^\/users\/u\d+$/.test(request.path)).length, 0);
    // Reattach RTA so afterEach can restore the saved registry snapshot.
    await environment.ecp.sendLaunchChannel({ channelId: 'dev', verifyLaunch: true, verifyLaunchTimeOut: 15000 });
    await waitForMainScene(environment);
    await visible(picker);
  });

  it('migrates a saved account before startup and preserves its credentials settings and active identity', async () => {
    await seed([account(), account('b')]);
    const server = fixture.url('a');
    const oldKey = `${new URL(server).host}/u0`;
    const newKey = keyFor(server, 'u0');
    await environment.odc.deleteRegistrySections({ sections: [`STARFIN_ACCOUNT_${newKey}`] });
    await environment.odc.writeRegistry({ values: {
      [`STARFIN_ACCOUNT_${oldKey}`]: { server, 'user-id': 'u0', username: 'Legacy User', token: 'a-token', theme: 'grey', 'library-view': 'preserved' },
      STARFIN_ROKU: { 'active-account-key': oldKey }
    } });
    await relaunchStarfin(environment);
    await visible(picker);
    const migrated = (await environment.odc.readRegistry()).values;
    assert.equal(migrated[`STARFIN_ACCOUNT_${oldKey}`], undefined);
    assert.equal(migrated.STARFIN_ROKU['active-account-key'], newKey);
    assert.equal(migrated[`STARFIN_ACCOUNT_${newKey}`].token, 'a-token');
    assert.equal(migrated[`STARFIN_ACCOUNT_${newKey}`]['library-view'], 'preserved');
    await press('Select');
    await ready();
    assert.equal(await value('#homePage.settings.theme'), 'grey');
    assert.equal(await value('#authController.authenticatedSession.accountKey'), newKey);
  });

});
