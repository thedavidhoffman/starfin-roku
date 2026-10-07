import assert from 'node:assert/strict';
import { categories, openSettings, openSettingsFromSystemMenu, selectRadioOption, closeAndSaveSettings } from '../support/settings.mjs';
import { openConfiguredTVLibrary, findSeries, openSeries, returnToHome } from '../support/tv-series.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { captureEvidence } from '../support/evidence.mjs';

describe('Starfin TV series shell layout', function () {
  afterEach(async function () {
    await returnToHome();
  });

  it('renders Full Backdrop when opening a series with the saved preference', async function () {
    const { environment } = await openSeriesWithLayout(0);
    await assertBackdrop(environment, 'full-screen');
    await captureEvidence(this, 'tv-series-full-backdrop-load');
  });

  it('applies Full Backdrop and Corner Backdrop live after saving Settings', async function () {
    const { environment } = await openSeriesWithLayout(1);
    await assertBackdrop(environment, 'partial-screen');
    const originalSeasons = (await environment.odc.getValue({ base: 'scene', keyPath: '#seasonsGrid.content.getChildCount()' })).value;

    for (const [index, mode] of [[0, 'full-screen'], [1, 'partial-screen']]) {
      await openSettingsFromSystemMenu(environment, categories.mediaShell);
      await selectRadioOption(environment, 'seriesShellLayoutOptions', index);
      await closeAndSaveSettings(environment);
      await assertBackdrop(environment, mode);
      assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: '#seasonsGrid.content.getChildCount()' })).value, originalSeasons);
      await captureEvidence(this, `tv-series-live-${mode}`);
    }
  });
});

async function openSeriesWithLayout(index) {
  const { environment } = await openSettings(categories.mediaShell);
  await selectRadioOption(environment, 'seriesShellLayoutOptions', index);
  await closeAndSaveSettings(environment);
  await openConfiguredTVLibrary(environment);
  const { item, itemIndex } = await findSeries(environment);
  await openSeries(environment, itemIndex, item);
  return { environment };
}

async function assertBackdrop(environment, mode) {
  await waitFor(async () => (await environment.odc.getValue({ base: 'scene', keyPath: '#mediaShell.backgroundDisplay' })).value === mode, `the series ${mode} layout`);
  assert.ok((await environment.odc.getValue({ base: 'scene', keyPath: '#mediaShell.mediaContent.backdropUrl' })).value, 'The configured series needs a backdrop to verify rendering.');
  assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: '#mediaBackgroundFull.visible' })).value, mode === 'full-screen');
  assert.equal((await environment.odc.getValue({ base: 'scene', keyPath: '#mediaBackgroundPartialGroup.visible' })).value, mode === 'partial-screen');
}
