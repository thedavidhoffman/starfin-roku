import assert from 'node:assert/strict';
import test from 'node:test';
import { clearStarfinRegistry, waitForStartup } from '../support/lifecycle.mjs';

test('waits for initial authentication to publish the login surface', async () => {
  let reads = 0;
  const environment = { odc: { getValues: async () => {
    reads += 1;
    return { results: { login: { value: reads === 2 }, home: { value: false }, ready: { value: false } } };
  } } };

  await waitForStartup(environment);

  assert.equal(reads, 2);
});

test('waits for authenticated Home loading to finish before registry reset', async () => {
  let reads = 0;
  const environment = { odc: { getValues: async () => {
    reads += 1;
    return { results: { login: { value: false }, home: { value: true }, ready: { value: reads === 2 } } };
  } } };

  await waitForStartup(environment);

  assert.equal(reads, 2);
});

test('does not accept a ready Home surface while it is hidden', async () => {
  let reads = 0;
  const environment = { odc: { getValues: async () => {
    reads += 1;
    return { results: { login: { value: false }, home: { value: reads === 2 }, ready: { value: true } } };
  } } };

  await waitForStartup(environment);

  assert.equal(reads, 2);
});

test('accepts a clean registry while preserving the RTA runtime section', async () => {
  let fullDeletes = 0;
  const odc = {
    deleteEntireRegistry: async () => { fullDeletes += 1; },
    readRegistry: async () => ({ values: { rokuTestAutomation: { port: '9000' } } })
  };

  await clearStarfinRegistry(odc);

  assert.equal(fullDeletes, 1);
});

test('retries Starfin sections that are rewritten during registry deletion', async () => {
  const targetedDeletes = [];
  const reads = [
    { values: { STARFIN_ROKU: {}, STARFIN_ACCOUNT_TEST: {}, rokuTestAutomation: {} } },
    { values: { rokuTestAutomation: {} } }
  ];
  const odc = {
    deleteEntireRegistry: async () => {},
    deleteRegistrySections: async request => targetedDeletes.push(request.sections),
    readRegistry: async () => reads.shift()
  };

  await clearStarfinRegistry(odc);

  assert.deepEqual(targetedDeletes, [['STARFIN_ROKU', 'STARFIN_ACCOUNT_TEST']]);
});

test('fails after the bounded registry reset attempts are exhausted', async () => {
  const odc = {
    deleteEntireRegistry: async () => {},
    deleteRegistrySections: async () => {},
    readRegistry: async () => ({ values: { STARFIN_ROKU: {} } })
  };

  await assert.rejects(clearStarfinRegistry(odc, 3), /after 3 reset attempts: STARFIN_ROKU/);
});
