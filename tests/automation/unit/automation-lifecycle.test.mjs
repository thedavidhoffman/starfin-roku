import assert from 'node:assert/strict';
import test from 'node:test';
import { clearStarfinRegistry } from '../support/lifecycle.mjs';

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
