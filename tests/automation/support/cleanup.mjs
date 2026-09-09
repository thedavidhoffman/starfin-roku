import { relaunchAuthenticatedStarfin } from './authentication.mjs';
import { closeAutomationEnvironment, getAutomationEnvironment } from './environment.mjs';
import { exitStarfin } from './lifecycle.mjs';
import { resetSettingsDefaults } from './settings.mjs';

const defaultOperations = {
  closeAutomationEnvironment,
  exitStarfin,
  getAutomationEnvironment,
  relaunchAuthenticatedStarfin,
  resetSettingsDefaults
};

export async function cleanupAutomationRun(operations = defaultOperations) {
  let cleanupError;

  try {
    await operations.relaunchAuthenticatedStarfin();
    await operations.resetSettingsDefaults();
  } catch (error) {
    cleanupError = error;
  }

  try {
    const environment = await operations.getAutomationEnvironment();
    await operations.exitStarfin(environment);
  } catch (error) {
    if (!cleanupError) cleanupError = error;
  }

  try {
    await operations.closeAutomationEnvironment();
  } catch (error) {
    if (!cleanupError) cleanupError = error;
  }

  if (cleanupError) throw cleanupError;
}
