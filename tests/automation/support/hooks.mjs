import { captureEvidence } from './evidence.mjs';
import { cleanupAutomationRun } from './cleanup.mjs';
import { resetRegistryAndRelaunch } from './lifecycle.mjs';
import { qualifySuiteTitles } from './report-titles.mjs';

export const mochaHooks = {
  async beforeAll() {
    qualifySuiteTitles(this.test?.parent, process.env.STARFIN_AUTOMATION_RESOLUTION);
    await resetRegistryAndRelaunch();
  },

  async afterEach() {
    if (this.currentTest?.state !== 'failed') return;

    console.error(`Failed: ${this.currentTest.fullTitle()}`);
    console.error(this.currentTest.err?.stack ?? this.currentTest.err?.message ?? 'No test error was recorded.');

    try {
      await captureEvidence(this, this.currentTest.fullTitle(), { failure: true });
    } catch (error) {
      console.warn(`Unable to capture failure evidence: ${error.message}`);
    }
  },

  async afterAll() {
    await cleanupAutomationRun();
  }
};
