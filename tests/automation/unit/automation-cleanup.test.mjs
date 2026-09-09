import assert from 'node:assert/strict';
import test from 'node:test';
import { cleanupAutomationRun } from '../support/cleanup.mjs';

function createOperations(overrides = () => ({})) {
  const calls = [];
  const environment = { id: 'environment' };
  return {
    calls,
    environment,
    operations: {
      relaunchAuthenticatedStarfin: async () => { calls.push('relaunch'); },
      resetSettingsDefaults: async () => { calls.push('reset'); },
      getAutomationEnvironment: async () => {
        calls.push('getEnvironment');
        return environment;
      },
      exitStarfin: async value => {
        assert.equal(value, environment);
        calls.push('exit');
      },
      closeAutomationEnvironment: async () => { calls.push('close'); },
      ...overrides(calls)
    }
  };
}

test('restores settings from authenticated Home before exiting Starfin', async () => {
  const { calls, operations } = createOperations();

  await cleanupAutomationRun(operations);

  assert.deepEqual(calls, ['relaunch', 'reset', 'getEnvironment', 'exit', 'close']);
});

test('exits Starfin and closes automation after settings restoration fails', async () => {
  const failure = new Error('settings reset failed');
  const { calls, operations } = createOperations(() => ({
    resetSettingsDefaults: async () => {
      calls.push('reset');
      throw failure;
    }
  }));

  await assert.rejects(cleanupAutomationRun(operations), failure);

  assert.deepEqual(calls, ['relaunch', 'reset', 'getEnvironment', 'exit', 'close']);
});

test('closes automation after exiting Starfin fails', async () => {
  const failure = new Error('device exit failed');
  const { calls, operations } = createOperations(() => ({
    exitStarfin: async () => {
      calls.push('exit');
      throw failure;
    }
  }));

  await assert.rejects(cleanupAutomationRun(operations), failure);

  assert.deepEqual(calls, ['relaunch', 'reset', 'getEnvironment', 'exit', 'close']);
});
