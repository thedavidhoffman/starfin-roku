import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { getAutomationEnvironment } from '../support/environment.mjs';
import { waitFor } from '../support/lifecycle.mjs';

const sortCases = [
  { label: 'Title', optionIndex: 0, sortBy: 'SortName', sortOrder: 'Ascending' },
  { label: 'Title', optionIndex: 0, sortBy: 'SortName', sortOrder: 'Descending' },
  { label: 'Release Date', optionIndex: 1, sortBy: 'PremiereDate', sortOrder: 'Ascending' },
  { label: 'Release Date', optionIndex: 1, sortBy: 'PremiereDate', sortOrder: 'Descending' }
];

async function findConfiguredMovieLibrary(environment) {
  return waitFor(async () => {
    const shelfCountResponse = await environment.odc.getValue({
      base: 'scene',
      keyPath: '#shelvesGroup.getChildCount()'
    });
    const shelfCount = shelfCountResponse.found ? shelfCountResponse.value : 0;

    for (let shelfIndex = 0; shelfIndex < shelfCount; shelfIndex += 1) {
      const shelf = await environment.odc.getValues({
        requests: {
          title: { base: 'scene', keyPath: `#shelvesGroup.${shelfIndex}.rowContent.title` },
          itemCount: { base: 'scene', keyPath: `#shelvesGroup.${shelfIndex}.rowContent.getChildCount()` }
        }
      });
      if (shelf.results.title?.value !== 'My Media') continue;

      const itemCount = shelf.results.itemCount?.value ?? 0;
      for (let itemIndex = 0; itemIndex < itemCount; itemIndex += 1) {
        const itemResponse = await environment.odc.getValue({
          base: 'scene',
          keyPath: `#shelvesGroup.${shelfIndex}.rowContent.${itemIndex}.raw`
        });
        const item = itemResponse.value;
        if (item?.Name === environment.letterGridSearchLibrary) return { item, shelfIndex };
      }
    }

    return false;
  }, `the ${environment.letterGridSearchLibrary} library in My Media`, 45000);
}

async function openConfiguredMovieLibrary(environment) {
  const { item, shelfIndex } = await findConfiguredMovieLibrary(environment);

  await environment.odc.setValue({
    base: 'scene',
    keyPath: `#shelvesGroup.${shelfIndex}.selectedItem`,
    value: { item, rowKey: 'libraries' }
  });

  await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        pageType: { base: 'scene', keyPath: '#dynamicPageHost.0.subtype()' },
        pageVisible: { base: 'scene', keyPath: '#dynamicPageHost.0.visible' },
        responseOk: { base: 'scene', keyPath: '#videoLibraryTask.response.ok' },
        taskState: { base: 'scene', keyPath: '#videoLibraryTask.state' }
      }
    });
    return values.results.pageType?.value === 'VideoLibrary'
      && values.results.pageVisible?.value === true
      && values.results.responseOk?.value === true
      && ['done', 'stop'].includes(String(values.results.taskState?.value ?? '').toLowerCase());
  }, `the ${environment.letterGridSearchLibrary} movie library to load`, 120000);
}

async function selectBrowseOption(environment, sortCase) {
  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#browseByButton.overlayRequested',
    value: {
      id: 'sort',
      componentName: 'BrowseDialog',
      openFunction: 'openBrowse',
      closeFields: ['closeRequested', 'sortSelected']
    }
  });

  await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        overlayType: { base: 'scene', keyPath: '#overlayHost.0.subtype()' },
        overlayVisible: { base: 'scene', keyPath: '#overlayHost.0.visible' },
        optionTitle: { base: 'scene', keyPath: `#sortList.content.${sortCase.optionIndex}.title` }
      }
    });
    return values.results.overlayType?.value === 'BrowseDialog'
      && values.results.overlayVisible?.value === true
      && values.results.optionTitle?.value === sortCase.label;
  }, `the Browse by ${sortCase.label} option`);

  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#sortList.itemSelected',
    value: sortCase.optionIndex
  });

  if (sortCase.sortOrder === 'Descending') {
    await waitFor(async () => {
      const request = await environment.odc.getValues({
        requests: {
          sortBy: { base: 'scene', keyPath: '#videoLibraryTask.request.sortBy' },
          sortOrder: { base: 'scene', keyPath: '#videoLibraryTask.request.sortOrder' }
        }
      });
      return request.results.sortBy?.value === sortCase.sortBy
        && request.results.sortOrder?.value === 'Ascending';
    }, `${sortCase.label} ascending selection to apply`);

    await environment.odc.setValue({
      base: 'scene',
      keyPath: '#sortButton.sortOrderChanged',
      value: {
        optionKey: sortCase.sortBy,
        sortKey: sortCase.sortBy,
        sortOrder: 'Descending',
        label: sortCase.label
      }
    });
  }
}

async function loadEverySortedItem(environment, sortCase) {
  return waitFor(async () => {
    const state = await environment.odc.getValues({
      requests: {
        gridCount: { base: 'scene', keyPath: '#itemsGrid.content.getChildCount()' },
        requestSortBy: { base: 'scene', keyPath: '#videoLibraryTask.request.sortBy' },
        requestSortOrder: { base: 'scene', keyPath: '#videoLibraryTask.request.sortOrder' },
        responseOk: { base: 'scene', keyPath: '#videoLibraryTask.response.ok' },
        taskState: { base: 'scene', keyPath: '#videoLibraryTask.state' },
        totalCount: { base: 'scene', keyPath: '#videoLibraryTask.response.totalRecordCount' }
      }
    });
    const taskState = String(state.results.taskState?.value ?? '').toLowerCase();
    if (state.results.requestSortBy?.value !== sortCase.sortBy) return false;
    if (state.results.requestSortOrder?.value !== sortCase.sortOrder) return false;
    if (state.results.responseOk?.value !== true || !['done', 'stop'].includes(taskState)) return false;

    const gridCount = state.results.gridCount?.value ?? 0;
    const totalCount = state.results.totalCount?.value ?? -1;
    if (totalCount <= 0 || gridCount <= 0) return false;
    if (gridCount >= totalCount) return { gridCount, totalCount };

    await environment.odc.setValue({
      base: 'scene',
      keyPath: '#itemsGrid.itemFocused',
      value: gridCount - 1
    });
    return false;
  }, `all movies sorted by ${sortCase.label} ${sortCase.sortOrder}`, 120000);
}

async function readSortedItems(environment, itemCount) {
  const fields = ['Name', 'SortName', 'PremiereDate', 'ProductionYear'];
  const items = [];
  const batchSize = 25;

  for (let batchStart = 0; batchStart < itemCount; batchStart += batchSize) {
    const batchEnd = Math.min(batchStart + batchSize, itemCount);
    const requests = {};
    for (let itemIndex = batchStart; itemIndex < batchEnd; itemIndex += 1) {
      for (const field of fields) {
        requests[`${itemIndex}-${field}`] = {
          base: 'scene',
          keyPath: `#itemsGrid.content.${itemIndex}.raw.${field}`
        };
      }
    }

    const response = await environment.odc.getValues({ requests });
    for (let itemIndex = batchStart; itemIndex < batchEnd; itemIndex += 1) {
      items.push(Object.fromEntries(fields.map(field => [
        field,
        response.results[`${itemIndex}-${field}`]?.value
      ])));
    }
  }

  return items;
}

function compareTitles(left, right) {
  return left.SortName.toLocaleLowerCase('en-US').localeCompare(
    right.SortName.toLocaleLowerCase('en-US'),
    'en-US',
    { numeric: true }
  );
}

function releaseDateValue(item) {
  const premiereTime = Date.parse(item.PremiereDate);
  if (Number.isFinite(premiereTime)) return premiereTime;

  const productionYear = Number(item.ProductionYear);
  if (Number.isInteger(productionYear) && productionYear > 0) return Date.UTC(productionYear, 0, 1);

  return Number.NEGATIVE_INFINITY;
}

function assertSorted(items, sortCase) {
  const direction = sortCase.sortOrder === 'Descending' ? -1 : 1;

  for (let index = 1; index < items.length; index += 1) {
    const previous = items[index - 1];
    const current = items[index];
    assert.equal(typeof previous.SortName, 'string', `${previous.Name} should expose SortName.`);
    assert.equal(typeof current.SortName, 'string', `${current.Name} should expose SortName.`);
    const dateDifference = releaseDateValue(previous) - releaseDateValue(current);
    const comparison = sortCase.sortBy === 'PremiereDate'
      ? (dateDifference === 0 ? compareTitles(previous, current) * direction : dateDifference * direction)
      : compareTitles(previous, current) * direction;
    assert.ok(
      comparison <= 0,
      `${previous.Name} (${previous.PremiereDate ?? 'no PremiereDate'}, ${previous.ProductionYear ?? 'no ProductionYear'}) `
        + `should sort before ${current.Name} (${current.PremiereDate ?? 'no PremiereDate'}, `
        + `${current.ProductionYear ?? 'no ProductionYear'}) by ${sortCase.label} ${sortCase.sortOrder}.`
    );
  }
}

async function returnToHome() {
  const environment = await getAutomationEnvironment();
  const page = await environment.odc.getValue({
    base: 'scene',
    keyPath: '#dynamicPageHost.0.visible'
  });
  if (!page.found || page.value !== true) return;

  await environment.ecp.sendKeypress(environment.ecp.Key.Back);
  await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        childCount: { base: 'scene', keyPath: '#dynamicPageHost.getChildCount()' },
        homeVisible: { base: 'scene', keyPath: '#homePage.visible' }
      }
    });
    return values.results.childCount?.value === 0
      && values.results.homeVisible?.value === true;
  }, 'the movie library to return to Home');
}

describe('Starfin movie library sorting', function () {
  afterEach(async function () {
    await returnToHome();
  });

  for (const sortCase of sortCases) {
    it(`sorts every movie by ${sortCase.label} ${sortCase.sortOrder}`, async function () {
      const environment = await ensureAuthenticated();

      await openConfiguredMovieLibrary(environment);
      await selectBrowseOption(environment, sortCase);
      const { gridCount, totalCount } = await loadEverySortedItem(environment, sortCase);
      const items = await readSortedItems(environment, gridCount);

      assert.equal(gridCount, totalCount, `The grid should render all ${totalCount} movies.`);
      assertSorted(items, sortCase);

      await captureEvidence(
        this,
        `movie-library-sort-${sortCase.sortBy}-${sortCase.sortOrder}`
      );
    });
  }
});
