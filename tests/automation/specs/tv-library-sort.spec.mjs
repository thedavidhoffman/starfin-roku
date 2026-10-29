import assert from 'node:assert/strict';
import { ensureAuthenticated, relaunchAuthenticatedStarfin } from '../support/authentication.mjs';
import { getAutomationEnvironment } from '../support/environment.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { selectLetterFromGrid } from '../support/letter-grid.mjs';
import { openConfiguredLibrary } from '../support/library-navigation.mjs';
import { waitFor } from '../support/lifecycle.mjs';
import { value, set } from '../support/remote-keys.mjs';

const titleOption = { label: 'Title', sortBy: 'SortName', index: 0 };
const dateOptions = [
  { label: 'Date Show Added', sortBy: 'DateCreated', index: 2 },
  { label: 'Date Episode Added', sortBy: 'DateLastContentAdded', index: 3 }
];

async function openTVLibrary(environment) {
  await openConfiguredLibrary(environment, {
    collectionType: 'tvshows', libraryName: environment.tvLibrary,
    pageType: 'VideoLibrary', taskId: 'videoLibraryTask'
  });
}

// Match each response to its request before inspecting rendered content; the previous
// successful response remains on the task while a new sort is loading.
async function waitForSort(environment, option, direction = 'Ascending', letter = 'ALL') {
  return waitFor(async () => {
    const state = await environment.odc.getValues({ requests: {
      sortBy: { base: 'scene', keyPath: '#videoLibraryTask.request.sortBy' },
      direction: { base: 'scene', keyPath: '#videoLibraryTask.request.sortOrder' },
      letter: { base: 'scene', keyPath: '#videoLibraryTask.request.startsWith' },
      query: { base: 'scene', keyPath: '#videoLibraryTask.request.queryId' },
      start: { base: 'scene', keyPath: '#videoLibraryTask.request.pageStartIndex' },
      ok: { base: 'scene', keyPath: '#videoLibraryTask.response.ok' },
      responseQuery: { base: 'scene', keyPath: '#videoLibraryTask.response.queryId' },
      responseStart: { base: 'scene', keyPath: '#videoLibraryTask.response.startIndex' },
      next: { base: 'scene', keyPath: '#videoLibraryTask.response.nextStartIndex' },
      total: { base: 'scene', keyPath: '#videoLibraryTask.response.totalRecordCount' },
      task: { base: 'scene', keyPath: '#videoLibraryTask.state' },
      selectedKey: { base: 'scene', keyPath: '#browseByButton.selectedSort.optionKey' },
      selectedOrder: { base: 'scene', keyPath: '#browseByButton.selectedSort.sortOrder' },
      count: { base: 'scene', keyPath: '#itemsGrid.content.getChildCount()' },
      overlays: { base: 'scene', keyPath: '#overlayHost.getChildCount()' }
    } });
    const r = state.results;
    if (r.sortBy?.value !== option.sortBy || r.direction?.value !== direction
      || r.letter?.value !== letter || r.ok?.value !== true
      || r.responseQuery?.value !== r.query?.value
      || r.responseStart?.value !== r.start?.value
      || !['done', 'stop'].includes(String(r.task?.value).toLowerCase())
      || r.selectedKey?.value !== option.sortBy
      || r.selectedOrder?.value !== direction
      || r.overlays?.value !== 0) return false;
    const count = r.count?.value ?? 0;
    if (count < r.next?.value) return false;
    return { count, total: r.total?.value };
  }, option.label + ' ' + direction + ' results for ' + letter, 120000);
}

async function selectOption(environment, option, direction = 'Ascending') {
  await set(environment, '#browseByButton.overlayRequested', {
    id: 'sort', componentName: 'BrowseDialog', openFunction: 'openBrowse',
    closeFields: ['closeRequested', 'sortSelected']
  });
  await waitFor(async () =>
    await value(environment, '#overlayHost.0.subtype()') === 'BrowseDialog'
      && await value(environment, '#sortList.content.' + option.index + '.title') === option.label,
  option.label + ' in Browse By');
  await set(environment, '#sortList.itemSelected', option.index);
  await waitForSort(environment, option);
  if (direction === 'Descending') {
    await set(environment, '#sortButton.sortOrderChanged', { sortOrder: direction });
    await waitForSort(environment, option, direction);
  }
}

async function loadAllItems(environment, option, direction = 'Ascending') {
  const deadline = Date.now() + 180000;
  while (Date.now() < deadline) {
    const { count, total } = await waitForSort(environment, option, direction);
    assert.ok(total > 0, 'The configured TV library must contain items.');
    assert.ok(count <= total, 'Paging must not duplicate rendered items.');
    if (count === total) {
      const items = [];
      for (let start = 0; start < count; start += 25) {
        const requests = {};
        for (let index = start; index < Math.min(start + 25, count); index++) {
          requests[index] = { base: 'scene', keyPath: '#itemsGrid.content.' + index + '.raw' };
        }
        const result = await environment.odc.getValues({ requests });
        for (const entry of Object.values(result.results)) items.push(entry.value);
      }
      assert.equal(items.length, total);
      assert.equal(new Set(items.map(item => item.Id)).size, total);
      return items;
    }
    assert.ok(count > 0, 'A nonempty page must render before paging.');
    await set(environment, '#itemsGrid.itemFocused', count - 1);
    await waitFor(async () =>
      await value(environment, '#itemsGrid.content.getChildCount()') > count,
    'the next sorted page', 120000);
  }
  assert.fail('Timed out loading the complete sorted TV library.');
}

// Use an independent, read-only Jellyfin query as the ordering oracle, including
// any grouped collection cards. Do not infer episode dates from series DateCreated.
async function serverItems(environment, sortBy, direction) {
  const request = {};
  for (const field of ['server', 'userId', 'libraryId', 'includeItemTypes', 'token']) {
    request[field] = await value(environment, '#videoLibraryTask.request.' + field);
  }
  const server = request.server.replace(/\/$/, '');
  const items = [];
  let total;
  do {
    const url = new URL(server + '/Users/' + encodeURIComponent(request.userId) + '/Items');
    url.search = new URLSearchParams({
      UserId: request.userId, ParentId: request.libraryId, Recursive: 'true',
      IncludeItemTypes: request.includeItemTypes, Fields: 'SortName',
      SortBy: sortBy, SortOrder: direction, StartIndex: String(items.length),
      Limit: '100', EnableTotalRecordCount: 'true'
    }).toString();
    const response = await fetch(url, {
      headers: { 'X-Emby-Token': request.token }, signal: AbortSignal.timeout(120000)
    });
    assert.equal(response.ok, true, 'Jellyfin sorting query HTTP ' + response.status);
    const payload = await response.json();
    assert.ok(Array.isArray(payload.Items));
    assert.ok(Number.isInteger(payload.TotalRecordCount));
    total ??= payload.TotalRecordCount;
    assert.equal(payload.TotalRecordCount, total, 'Keep the library unchanged during automation.');
    assert.ok(payload.Items.length > 0 || total === 0, 'Jellyfin paging must make progress.');
    items.push(...payload.Items);
  } while (items.length < total);
  assert.equal(items.length, total);
  return items;
}

async function assertButtonLayout(environment, label, width, lettersVisible) {
  await waitFor(async () =>
    await value(environment, '#browseByButton.#sortLabel.text') === label
      && await value(environment, '#browseByButton.buttonWidth') === width,
  label + ' button layout');
  assert.equal(await value(environment, '#browseByButton.#sortLabel.isTextEllipsized'), false,
    label + ' must render without clipping.');
  assert.equal(await value(environment, '#browseByButton.#sortLabel.width'), width);
  assert.equal(await value(environment, '#browseByButton.#background.width'), width);
  assert.equal(await value(environment, '#letterGutterButton.visible'), lettersVisible);
  const browse = await value(environment, '#browseByButton.translation');
  const sort = await value(environment, '#sortButton.translation');
  const heading = await value(environment, '#dynamicPageHost.0.#titleLabel.translation');
  const headingWidth = await value(environment, '#dynamicPageHost.0.#titleLabel.width');
  assert.equal(sort[0] - (browse[0] + width), 8, 'Keep the sort-button gap.');
  assert.equal(sort[1], browse[1], 'Align the controls vertically.');
  assert.ok(heading[0] + headingWidth <= browse[0] - 24, 'Keep the heading clear of Browse By.');
}

describe('Starfin TV library date sorting', function () {
  this.timeout(600000);

  beforeEach(async function () {
    const environment = await ensureAuthenticated();
    await openTVLibrary(environment);
    await selectOption(environment, titleOption);
  });

  afterEach(async function () {
    // Relaunch also recovers failed scenarios with an open overlay. Restore Title
    // explicitly because other library smoke scenarios start from title browsing.
    const environment = await relaunchAuthenticatedStarfin();
    try {
      await openTVLibrary(environment);
      await selectOption(environment, titleOption);
    } finally {
      await relaunchAuthenticatedStarfin();
    }
  });

  for (const option of dateOptions) {
    for (const direction of ['Ascending', 'Descending']) {
      it('matches Jellyfin for every item by ' + option.label + ' ' + direction, async function () {
        const environment = await getAutomationEnvironment();
        await selectOption(environment, option, direction);
        const expected = await serverItems(environment, option.sortBy, direction);
        const actual = await loadAllItems(environment, option, direction);
        assert.deepEqual(actual.map(item => item.Id), expected.map(item => item.Id),
          'Every rendered item, including later pages, must follow Jellyfin order.');
        await captureEvidence(this, 'tv-date-sort-' + option.sortBy + '-' + direction);
      });
    }

    it('restores ' + option.label + ' descending after relaunch', async function () {
      let environment = await getAutomationEnvironment();
      await selectOption(environment, option, 'Descending');
      environment = await relaunchAuthenticatedStarfin();
      await openTVLibrary(environment);
      await waitForSort(environment, option, 'Descending');
      await assertButtonLayout(environment, option.label, 300, false);
      await captureEvidence(this, 'tv-date-restored-' + option.sortBy);
    });

    it('clears a letter filter when selecting ' + option.label, async function () {
      const environment = await getAutomationEnvironment();
      const items = await serverItems(environment, 'SortName', 'Ascending');
      const letterItem = items.find(item => /^[a-z]/i.test(item.SortName ?? ''));
      assert.ok(letterItem, 'The TV library needs an alphabetic sort name for the letter-filter scenario.');
      const letter = letterItem.SortName[0].toUpperCase();
      await selectLetterFromGrid(this, environment, 'tv-date-sort', letter);
      await waitForSort(environment, titleOption, 'Ascending', letter);
      await selectOption(environment, option);
      assert.equal(await value(environment, '#videoLibraryTask.request.startsWith'), 'ALL');
      const expected = await serverItems(environment, option.sortBy, 'Ascending');
      const actual = await loadAllItems(environment, option);
      assert.deepEqual(actual.map(item => item.Id), expected.map(item => item.Id),
        'Date sorting must restore the full library, not retain the letter subset.');
      await assertButtonLayout(environment, option.label, 300, false);
    });

    it('fits ' + option.label + ' and shrinks again for Title', async function () {
      const environment = await getAutomationEnvironment();
      await selectOption(environment, option);
      await assertButtonLayout(environment, option.label, 300, false);
      await captureEvidence(this, 'tv-date-label-' + option.sortBy);
      await selectOption(environment, titleOption);
      await assertButtonLayout(environment, 'Title', 190, true);
      await captureEvidence(this, 'tv-date-label-reset-' + option.sortBy);
    });
  }
});
