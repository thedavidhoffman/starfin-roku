import assert from 'node:assert/strict';
import { relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { openLibrary, focusItem, page, press, value, set } from '../support/remote-keys.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { expectedWatchItems, loadWatchItems, openWatchMenu, selectWatch, selectWatchLetter,
  snapshotWatchItem, waitForWatch } from '../support/watch-browse.mjs';

for (const surface of [
  { type: 'movies', name: 'movieLibrary', itemType: 'Movie', details: 'Movie' },
  { type: 'tvshows', name: 'tvLibrary', itemType: 'Series', details: 'TVShow' }
]) {
  describe(`Starfin ${surface.type} watched browsing`, function () {
    this.timeout(900000);
    let environment;
    let fixtures;

    beforeEach(async function () {
      fixtures = [];
      environment = await relaunchAuthenticatedStarfin();
      await openLibrary(environment, environment[surface.name], surface.type);
      await selectWatch(environment, 'SortName');
    });

    afterEach(async function () {
      const failures = [];
      // Exit the old channel before restoring history so no late event can overwrite it.
      try { environment = await relaunchAuthenticatedStarfin(); }
      catch (error) { failures.push(error); }
      for (const fixture of fixtures) {
        try { await fixture.restore(); } catch (error) { failures.push(error); }
      }
      try {
        await openLibrary(environment, environment[surface.name], surface.type);
        await selectWatch(environment, 'SortName');
      } catch (error) { failures.push(error); }
      if (failures.length) throw new AggregateError(failures, 'Watched browse cleanup');
    });

    for (const mode of ['Watched', 'Unwatched']) {
      for (const direction of ['Ascending', 'Descending']) {
        it(`matches every Jellyfin ${mode} item in ${direction} order`, async function () {
          await selectWatch(environment, mode, direction);
          const expected = await expectedWatchItems(environment, mode, direction);
          const actual = await loadWatchItems(environment, mode, direction);
          assert.deepEqual(actual.map(item => item.Id), expected.map(item => item.Id));
          if (!expected.length) {
            assert.equal(await value(environment, '#emptyBrowseLabel.text'), `No ${mode.toLowerCase()} items to display.`);
            assert.ok(await environment.odc.hasFocus({ base: 'scene', keyPath: '#browseByButton' }));
          }
        });
      }

      it(`restores ${mode} descending after relaunch`, async function () {
        await selectWatch(environment, mode, 'Descending');
        environment = await relaunchAuthenticatedStarfin();
        await openLibrary(environment, environment[surface.name], surface.type);
        await waitForWatch(environment, mode, 'Descending');
        assert.equal(await value(environment, '#browseByButton.#sortLabel.text'), mode);
        assert.equal(await value(environment, '#letterGutterButton.visible'), true);
      });

      for (const bucket of ['letter', '#']) {
        it(`filters ${mode} by ${bucket} without losing descending order`, async function () {
          await selectWatch(environment, mode, 'Descending');
          const all = await expectedWatchItems(environment, mode, 'Descending');
          const letter = bucket === '#' ? '#' : all.find(item => /^[a-z]/i.test(item.SortName ?? ''))?.SortName[0].toUpperCase();
          assert.ok(letter, 'An alphabetic title is required for letter coverage.');
          const expected = await expectedWatchItems(environment, mode, 'Descending', letter);
          await selectWatchLetter(environment, letter);
          if (!expected.length) {
            // Empty letter selections retain the old bucket and keep the picker open.
            await waitFor(async () => await value(environment, '#videoLibraryTask.response.ok') === true
              && await value(environment, '#videoLibraryTask.response.totalRecordCount') === 0,
            'empty letter response');
            assert.equal(await value(environment, '#overlayHost.0.subtype()'), 'LetterGridDialog');
            await press(environment, 'Back');
            return;
          }
          const actual = await loadWatchItems(environment, mode, 'Descending', letter);
          assert.deepEqual(actual.map(item => item.Id), expected.map(item => item.Id));
        });
      }

      it(`refreshes ${mode} after a controlled status change and restores nearby focus`, async function () {
        const items = await expectedWatchItems(environment, 'SortName');
        const item = items.find(entry => entry.Type === surface.itemType);
        assert.ok(item, 'A mutable movie or series fixture is required.');
        const fixture = await snapshotWatchItem(environment, item);
        fixtures.push(fixture);
        await fixture.played(item.Id, mode === 'Watched');
        await selectWatch(environment, mode, 'Descending');
        const before = await loadWatchItems(environment, mode, 'Descending');
        const focus = await focusItem(environment, '#itemsGrid', item.Id);
        const oldQuery = await value(environment, '#videoLibraryTask.request.queryId');
        await press(environment, 'Ok');
        await page(environment, surface.details);
        await fixture.played(item.Id, mode !== 'Watched');
        await press(environment, 'Back');
        await page(environment, 'VideoLibrary');
        await waitFor(async () => await value(environment, '#videoLibraryTask.request.queryId') > oldQuery, 'return refresh');
        const expected = await expectedWatchItems(environment, mode, 'Descending');
        await waitForWatch(environment, mode, 'Descending');
        await waitFor(async () => await value(environment, '#itemsGrid.content.getChildCount()') === expected.length,
          'replacement of the entire previously loaded range', 120000);
        if (expected.length) {
          assert.equal(await value(environment, '#itemsGrid.itemFocused'), Math.min(focus.position, expected.length - 1));
        }
        const actual = await loadWatchItems(environment, mode, 'Descending');
        assert.deepEqual(actual.map(entry => entry.Id), expected.map(entry => entry.Id));
        assert.ok(!actual.some(entry => entry.Id === item.Id));
        assert.ok(before.some(entry => entry.Id === item.Id));
      });

      it(`focuses Browse By when the retained ${mode} letter bucket becomes empty`, async function () {
        const all = await expectedWatchItems(environment, 'SortName');
        const groups = new Map();
        for (const item of all.filter(entry => entry.Type === surface.itemType)) {
          const letter = item.SortName?.[0]?.toUpperCase();
          if (/^[A-Z]$/.test(letter ?? '')) groups.set(letter, (groups.get(letter) ?? 0) + 1);
        }
        const letter = [...groups].sort((a, b) => a[1] - b[1])[0]?.[0];
        assert.ok(letter, 'An alphabetic bucket is required.');
        const bucket = await expectedWatchItems(environment, 'SortName', 'Ascending', letter);
        assert.ok(bucket.length && bucket.every(item => item.Type === surface.itemType), 'Use a bucket of movie/show cards.');
        for (const item of bucket) {
          const fixture = await snapshotWatchItem(environment, item);
          fixtures.push(fixture);
          await fixture.played(item.Id, mode === 'Watched');
        }
        await selectWatch(environment, mode);
        await selectWatchLetter(environment, letter);
        await loadWatchItems(environment, mode, 'Ascending', letter);
        await focusItem(environment, '#itemsGrid', bucket[0].Id);
        const oldQuery = await value(environment, '#videoLibraryTask.request.queryId');
        await press(environment, 'Ok');
        await page(environment, surface.details);
        for (let i = 0; i < fixtures.length; i++) await fixtures[i].played(bucket[i].Id, mode !== 'Watched');
        await press(environment, 'Back');
        await page(environment, 'VideoLibrary');
        await waitFor(async () => await value(environment, '#videoLibraryTask.request.queryId') > oldQuery, 'empty return refresh');
        await waitForWatch(environment, mode, 'Ascending', letter);
        assert.equal(await value(environment, '#itemsGrid.content.getChildCount()'), 0);
        assert.equal(await value(environment, '#emptyBrowseLabel.text'), `No ${mode.toLowerCase()} items to display.`);
        assert.equal(await value(environment, '#emptyBrowseLabel.visible'), true);
        assert.ok(await environment.odc.hasFocus({ base: 'scene', keyPath: '#browseByButton' }));
      });
    }

    it('scrolls the seven-row menu to Genre and back to Watched', async function () {
      const labels = await openWatchMenu(environment);
      const expected = surface.type === 'tvshows'
        ? ['Title', 'Release Date', 'Date Show Added', 'Date Episode Added', 'Favorites', 'Watched', 'Unwatched', 'Decade', 'Genre']
        : ['Title', 'Release Date', 'Date Added', 'Favorites', 'Watched', 'Unwatched', 'Decade', 'Genre'];
      assert.deepEqual(labels, expected, 'Fixture library must supply Genre and Decade.');
      assert.equal(await value(environment, '#sortList.numRows'), 7);
      await environment.odc.focusNode({ base: 'scene', keyPath: '#sortList' });
      await set(environment, '#sortList.jumpToItem', 0);
      for (let index = 1; index < labels.length; index++) {
        await press(environment, 'Down');
        await waitFor(async () => await value(environment, '#sortList.itemFocused') === index, `menu row ${index}`);
      }
      await press(environment, 'Ok');
      await waitFor(async () => await value(environment, '#browseByButton.selectedSort.optionKey') === 'Genre', 'Genre selected');
      await selectWatch(environment, 'Watched');
    });

    if (surface.type === 'tvshows') {
      it('keeps a partially watched series under Unwatched as a show card', async function () {
        const all = await expectedWatchItems(environment, 'SortName');
        const item = all.find(entry => entry.Type === 'Series');
        assert.ok(item, 'A TV series fixture is required.');
        const fixture = await snapshotWatchItem(environment, item);
        fixtures.push(fixture);
        assert.ok(fixture.episodes.length > 1, 'A series with at least two episodes is required.');
        await fixture.played(item.Id, false);
        await fixture.played(fixture.episodes[0].Id, true);
        await selectWatch(environment, 'Unwatched');
        const actual = await loadWatchItems(environment, 'Unwatched');
        const show = actual.find(entry => entry.Id === item.Id);
        assert.equal(show?.Type, 'Series');
        assert.equal(show.UserData.Played, false);
        await selectWatch(environment, 'Watched');
        assert.ok(!(await loadWatchItems(environment, 'Watched')).some(entry => entry.Id === item.Id));
      });
    }
  });
}
