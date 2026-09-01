import { captureEvidence } from './evidence.mjs';
import { closeAutomationEnvironment } from './environment.mjs';
import { resetRegistryAndRelaunch } from './lifecycle.mjs';

export const mochaHooks = {
  async beforeAll() {
    await resetRegistryAndRelaunch();
  },

  async afterEach() {
    if (this.currentTest?.state !== 'failed') return;

    try {
      await captureEvidence(this, this.currentTest.fullTitle(), { failure: true });
    } catch (error) {
      console.warn(`Unable to capture failure evidence: ${error.message}`);
    }
  },

  async afterAll() {
    await closeAutomationEnvironment();
  }
};
