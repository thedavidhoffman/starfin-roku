import { captureEvidence } from '../support/evidence.mjs';
import { relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import {
  assertSettingPersisted,
  categories,
  closeAndSaveSettings,
  openSettings
} from '../support/settings.mjs';

async function exerciseTmdbApiKey(context, value, checkpoint) {
  try {
    const { environment, accountKey } = await openSettings(categories.general);
    await environment.odc.focusNode({
      base: 'scene',
      keyPath: '#tmdbApiKeyInput'
    });
    await environment.ecp.sendKeypress(environment.ecp.Key.Ok);

    await waitFor(async () => {
      const response = await environment.odc.getValue({
        base: 'scene',
        keyPath: 'dialog.title'
      });
      return response.found && response.value === 'Enter TMDB API Key';
    }, 'the TMDB API key keyboard');

    await environment.odc.setValue({ base: 'scene', keyPath: 'dialog.text', value });
    await environment.odc.setValue({ base: 'scene', keyPath: 'dialog.buttonSelected', value: 0 });

    await waitFor(async () => {
      const response = await environment.odc.getValue({
        base: 'scene',
        keyPath: '#tmdbApiKeyInput.text'
      });
      return response.found && response.value === value;
    }, 'the TMDB API key field to update');

    await captureEvidence(context, checkpoint);
    await closeAndSaveSettings(environment);
    await assertSettingPersisted(environment, accountKey, 'global', 'tmdb-api-key', value);
  } finally {
    await relaunchAuthenticatedStarfin();
  }
}

describe('Starfin TMDB API key settings persistence', function () {
  it('persists a synthetic TMDB API key', async function () {
    await exerciseTmdbApiKey(this, 'starfin-automation-tmdb-key', 'settings-general-tmdb-key-set');
  });

  it('persists an empty TMDB API key', async function () {
    await exerciseTmdbApiKey(this, '', 'settings-general-tmdb-key-empty');
  });
});
