import assert from 'node:assert/strict';
import { captureEvidence } from '../support/evidence.mjs';
import { relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { categories, exerciseRadioSetting, openSettings, selectRadioOption, closeAndSaveSettings, assertSettingPersisted } from '../support/settings.mjs';

const cases = [
  { label: 'horizontal episode list', index: 0, value: 'horizontal' },
  { label: 'vertical episode list', index: 1, value: 'vertical' }
];

describe('Starfin TV settings persistence', function () {
  for (const testCase of cases) {
    it(`persists ${testCase.label}`, async function () {
      await exerciseRadioSetting(this, {
        category: categories.tv,
        nodeId: 'tvEpisodeListDisplayOptions',
        index: testCase.index,
        scope: 'account',
        key: 'tv-ep-list-scroll',
        value: testCase.value,
        checkpoint: `settings-tv-${testCase.value}`
      });
    });
  }
});

describe('Starfin Home episode images', function () {
  for (const enabled of [false, true]) {
    it(`updates both Home rows with episode images ${enabled ? 'on' : 'off'} and restores on restart`, async function () {
      const { environment, accountKey } = await openSettings(categories.tv);
      await selectRadioOption(environment, 'homeEpisodeImagesOptions', enabled ? 0 : 1);
      await closeAndSaveSettings(environment);
      await assertSettingPersisted(environment, accountKey, 'account', 'home-episode-images', enabled ? 'off' : 'on');
      await openSettings(categories.tv);
      const read = async keyPath => (await environment.odc.getValue({ base: 'scene', keyPath })).value;
      const inspectRows = async () => {
        const count = await read('#shelvesGroup.getChildCount()');
        const rows = [];
        for (let shelf = 0; shelf < count; shelf++) {
          const path = `#shelvesGroup.${shelf}.rowContent`;
          const key = await read(`${path}.rowKey`);
          if (!['nextUp', 'continueWatching'].includes(key)) continue;
          const itemCount = await read(`${path}.getChildCount()`);
          for (let item = 0; item < itemCount; item++) {
            const raw = await read(`${path}.${item}.raw`);
            if (raw?.Type !== 'Episode' || !raw.ImageTags?.Primary) continue;
            const seriesId = raw.ParentThumbItemId || raw.ParentThumbImageItemId;
            const seriesTag = raw.ParentThumbImageTag;
            if (!seriesId || !seriesTag) continue;
            rows.push({ key, path: `${path}.${item}`, id: raw.Id, seriesId });
            break;
          }
        }
        assert.deepEqual(rows.map(row => row.key).sort(), ['continueWatching', 'nextUp'], 'Both rows need an episode with a still and series artwork.');
        return rows;
      };
      const rows = await inspectRows();
      for (const row of rows) {
        const startingImage = enabled ? `/Items/${row.seriesId}/Images/Thumb` : `/Items/${row.id}/Images/Primary`;
        await waitFor(async () => String(await read(`${row.path}.HDPosterUrl`)).includes(startingImage), `${row.key} to show the opposite artwork before editing`);
      }
      const previousUrls = await Promise.all(rows.map(row => read(`${row.path}.HDPosterUrl`)));
      await selectRadioOption(environment, 'homeEpisodeImagesOptions', enabled ? 1 : 0);
      assert.deepEqual(await Promise.all(rows.map(row => read(`${row.path}.HDPosterUrl`))), previousUrls, 'Editing should not affect Home until Settings closes.');
      await captureEvidence(this, `settings-episode-images-${enabled ? 'on' : 'off'}`);
      const queryBefore = await read('#nextUpTask.request.homeQueryId');
      await closeAndSaveSettings(environment);
      await assertSettingPersisted(environment, accountKey, 'account', 'home-episode-images', enabled ? 'on' : 'off');
      for (const row of rows) {
        const expected = enabled ? `/Items/${row.id}/Images/Primary` : `/Items/${row.seriesId}/Images/Thumb`;
        await waitFor(async () => String(await read(`${row.path}.HDPosterUrl`)).includes(expected), `${row.key} artwork to update`);
      }
      assert.equal(await read('#nextUpTask.request.homeQueryId'), queryBefore, 'Changing artwork must not request Home data again.');
      await captureEvidence(this, `home-episode-images-${enabled ? 'on' : 'off'}`);

      await relaunchAuthenticatedStarfin();
      await waitFor(async () => await read('#homePage.ready') === true, 'Home to finish loading after restart');
      for (const row of await inspectRows()) {
        const expected = enabled ? `/Items/${row.id}/Images/Primary` : `/Items/${row.seriesId}/Images/Thumb`;
        assert.ok(String(await read(`${row.path}.HDPosterUrl`)).includes(expected));
      }
    });
  }
});
