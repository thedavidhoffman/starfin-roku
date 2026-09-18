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

describe('Starfin TV toggle settings persistence', function () {
  const settings = [
    { label: 'season summary card', nodeId: 'showSeasonSummaryCardOptions', key: 'show-season-summary-card' }
  ];

  for (const setting of settings) {
    for (const enabled of [true, false]) {
      const value = enabled ? 'on' : 'off';
      it(`persists ${setting.label} ${value}`, async function () {
        // Save the opposite value first so this case verifies a write even in isolation.
        const { environment } = await openSettings(categories.tv);
        await selectRadioOption(environment, setting.nodeId, enabled ? 0 : 1);
        await closeAndSaveSettings(environment);

        await exerciseRadioSetting(this, {
          category: categories.tv,
          nodeId: setting.nodeId,
          index: enabled ? 1 : 0,
          scope: 'account',
          key: setting.key,
          value,
          checkpoint: `settings-tv-${setting.key}-${value}`
        });
      });
    }
  }
});


async function assertRenderedOverlays(environment, rows, withLogo) {
  const nodeRefKey = 'episode-overlays';
  await environment.odc.storeNodeReferences({ nodeRefKey, includeArrayGridChildren: true });
  for (const row of rows) {
    const { nodeRefs } = await environment.odc.getNodesWithProperties({ nodeRefKey, properties: [
      { field: 'id', value: 'presentation' },
      { keyPath: 'itemContent.raw.Id', value: row.id }
    ] });
    assert.ok(nodeRefs.length, `${row.key} episode card must be rendered`);
    for (const ref of nodeRefs) {
      for (const id of ['logoOverlay', 'logoGradient']) {
        await waitFor(async () => {
          const response = await environment.odc.getValue({ base: 'nodeRef', nodeRefKey, keyPath: `${ref}.#${id}.visible` });
          return response.value === withLogo;
        }, `${row.key} ${id} visibility after image loading`);
      }
    }
  }
  await environment.odc.deleteNodeReferences({ nodeRefKey });
}

describe('Starfin Home episode images', function () {
  const modes = ['off', 'on-with-logo', 'on-without-logo'];
  const transitions = modes.flatMap(from => modes.filter(to => to !== from).map(to => ({ from, to })));
  for (const { from, to } of transitions) {
    const enabled = to !== 'off';
    it(`updates both Home rows from ${from} to ${to} and restores on restart`, async function () {
      const { environment, accountKey } = await openSettings(categories.tv);
      // Force a change so even the default Off mode gets a registry write.
      await selectRadioOption(environment, 'homeEpisodeImagesOptions', modes.indexOf(to));
      await closeAndSaveSettings(environment);
      await openSettings(categories.tv);
      await selectRadioOption(environment, 'homeEpisodeImagesOptions', modes.indexOf(from));
      await closeAndSaveSettings(environment);
      await assertSettingPersisted(environment, accountKey, 'account', 'home-episode-images', from);
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
            if (!seriesId || !seriesTag || !raw.ParentLogoItemId || !raw.ParentLogoImageTag) continue;
            rows.push({ key, path: `${path}.${item}`, id: raw.Id, seriesId, logoId: raw.ParentLogoItemId, logoTag: raw.ParentLogoImageTag });
            break;
          }
        }
        assert.deepEqual(rows.map(row => row.key).sort(), ['continueWatching', 'nextUp'], 'Both rows need an episode with a still, series artwork, and a parent logo.');
        return rows;
      };
      const rows = await inspectRows();
      for (const row of rows) {
        const startingImage = from === 'off' ? `/Items/${row.seriesId}/Images/Thumb` : `/Items/${row.id}/Images/Primary`;
        await waitFor(async () => String(await read(`${row.path}.HDPosterUrl`)).includes(startingImage), `${row.key} to show the opposite artwork before editing`);
      }
      const previousUrls = await Promise.all(rows.map(row => read(`${row.path}.HDPosterUrl`)));
      const previousLogos = await Promise.all(rows.map(row => read(`${row.path}.logoOverlayUrl`)));
      await selectRadioOption(environment, 'homeEpisodeImagesOptions', modes.indexOf(to));
      assert.deepEqual(await Promise.all(rows.map(row => read(`${row.path}.HDPosterUrl`))), previousUrls, 'Editing should not affect Home until Settings closes.');
      assert.deepEqual(await Promise.all(rows.map(row => read(`${row.path}.logoOverlayUrl`))), previousLogos, 'Editing must not change logos before saving.');
      await captureEvidence(this, `settings-episode-images-${from}-to-${to}`);
      const queryBefore = await read('#nextUpTask.request.homeQueryId');
      await closeAndSaveSettings(environment);
      await assertSettingPersisted(environment, accountKey, 'account', 'home-episode-images', to);
      for (const row of rows) {
        const expected = enabled ? `/Items/${row.id}/Images/Primary` : `/Items/${row.seriesId}/Images/Thumb`;
        await waitFor(async () => String(await read(`${row.path}.HDPosterUrl`)).includes(expected), `${row.key} artwork to update`);
        const logo = String(await read(`${row.path}.logoOverlayUrl`));
        if (to === 'on-with-logo') {
          assert.ok(logo.includes(`/Items/${row.logoId}/Images/Logo?tag=${row.logoTag}`), `${row.key} uses the inherited logo`);
        } else {
          assert.equal(logo, '', `${row.key} leaves show artwork and missing logos unadorned`);
        }
      }
      assert.equal(await read('#nextUpTask.request.homeQueryId'), queryBefore, 'Changing artwork must not request Home data again.');
      await assertRenderedOverlays(environment, rows, to === 'on-with-logo');
      await captureEvidence(this, `home-episode-images-${from}-to-${to}`);

      await relaunchAuthenticatedStarfin();
      await waitFor(async () => await read('#homePage.ready') === true, 'Home to finish loading after restart');
      for (const row of await inspectRows()) {
        const expected = enabled ? `/Items/${row.id}/Images/Primary` : `/Items/${row.seriesId}/Images/Thumb`;
        assert.ok(String(await read(`${row.path}.HDPosterUrl`)).includes(expected));
        const logo = String(await read(`${row.path}.logoOverlayUrl`));
        if (to === 'on-with-logo') {
          assert.ok(logo.includes(`/Items/${row.logoId}/Images/Logo?tag=${row.logoTag}`));
        } else {
          assert.equal(logo, '');
        }
      }
    });
  }
});
