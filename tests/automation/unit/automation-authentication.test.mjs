import assert from 'node:assert/strict';
import test from 'node:test';
import { ensureAuthenticated } from '../support/authentication.mjs';

function environmentFor(initial) {
  let surface = initial;
  const writes = [];
  return {
    writes,
    testAccount: { server: 'https://configured', username: 'test-user', password: 'test-password' },
    odc: {
      getValues: async () => ({ results: {
        picker: { value: surface === 'picker' }, login: { value: surface === 'login' }, home: { value: surface === 'home' }
      } }),
      setValue: async request => {
        writes.push(request);
        if (request.keyPath.includes('signInButton')) surface = 'login';
      },
      callFunc: async request => writes.push(request)
    },
    ecp: { Key: { Ok: 'Select' }, sendKeypress: async () => { surface = 'home'; } }
  };
}

test('uses configured credentials through Login when startup displays the picker', async () => {
  const environment = environmentFor('picker');
  assert.equal(await ensureAuthenticated(environment), environment);
  assert.equal(environment.writes[0].keyPath, '#startupAccountHost.0.#signInButton.buttonSelected');
  assert.ok(environment.writes.some(request => request.keyPath === '#login.serverValue' && request.value === 'https://configured'));
  assert.ok(environment.writes.some(request => request.keyPath === '#login.usernameValue' && request.value === 'test-user'));
  assert.equal(environment.writes.some(request => request.keyPath?.includes('accountSelected')), false);
});

test('retains the existing Login authentication path', async () => {
  const environment = environmentFor('login');
  await ensureAuthenticated(environment);
  assert.equal(environment.writes[0].keyPath, '#login.serverValue');
});

test('does not change credentials when already authenticated', async () => {
  const environment = environmentFor('home');
  await ensureAuthenticated(environment);
  assert.deepEqual(environment.writes, []);
});

test('waits for a delayed startup picker before choosing the configured login path', async () => {
  const environment = environmentFor('picker');
  const getValues = environment.odc.getValues;
  let reads = 0;
  environment.odc.getValues = async () => ++reads === 1 ? { results: {} } : getValues();
  await ensureAuthenticated(environment);
  assert.ok(reads >= 3);
  assert.equal(environment.writes[0].keyPath, '#startupAccountHost.0.#signInButton.buttonSelected');
});
