import assert from 'node:assert/strict';
import test from 'node:test';
import { waitFor } from '../support/lifecycle.mjs';
import { startAccountSelectionFixture } from '../support/account-selection-fixture.mjs';

test('distinguishes servers by port with the same user identity', async t => {
  const fixture = await startAccountSelectionFixture('127.0.0.1');
  t.after(() => fixture.close());
  assert.notEqual(new URL(fixture.url('a')).port, new URL(fixture.url('b')).port);
  for (const id of ['a', 'b']) {
    const response = await fetch(`${fixture.url(id)}/Users/u0`);
    assert.equal(response.status, 200);
    assert.equal((await response.json()).Id, 'u0');
  }
  assert.deepEqual(fixture.requests.map(request => request.server), ['a', 'b']);
});

for (const status of [401, 503]) {
  test(`returns controlled authorization status ${status}`, async t => {
    const fixture = await startAccountSelectionFixture('127.0.0.1');
    t.after(() => fixture.close());
    fixture.state('b').authStatus = status;
    const response = await fetch(`${fixture.url('b')}/Users/u0`);
    assert.equal(response.status, status);
  });
}

test('returns distinct Home libraries for each server', async t => {
  const fixture = await startAccountSelectionFixture('127.0.0.1');
  t.after(() => fixture.close());
  const a = await (await fetch(`${fixture.url('a')}/userviews`)).json();
  const b = await (await fetch(`${fixture.url('b')}/UserViews`)).json();
  assert.equal(a.Items[0].Id, 'a-library');
  assert.equal(b.Items[0].Id, 'b-library');
});

test('holds authorization until explicitly released', async t => {
  const fixture = await startAccountSelectionFixture('127.0.0.1');
  t.after(() => fixture.close());
  fixture.state('a').holdAuth = true;
  let completed = false;
  const response = fetch(`${fixture.url('a')}/Users/u0`).then(result => { completed = true; return result; });
  await waitFor(() => fixture.pendingCount('a', 'auth') === 1, 'fixture authorization held');
  assert.equal(completed, false);
  fixture.release('a', 'auth');
  assert.equal((await response).status, 200);
});

test('holds outgoing Home responses independently of another server', async t => {
  const fixture = await startAccountSelectionFixture('127.0.0.1');
  t.after(() => fixture.close());
  fixture.state('a').holdHome = true;
  const held = fetch(`${fixture.url('a')}/UserViews`);
  await waitFor(() => fixture.pendingCount('a', 'home') === 1, 'fixture Home held');
  assert.equal((await fetch(`${fixture.url('b')}/UserViews`)).status, 200);
  fixture.release('a', 'home');
  assert.equal((await held).status, 200);
});
