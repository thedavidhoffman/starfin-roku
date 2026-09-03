import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { getAutomationEnvironment } from '../support/environment.mjs';
import { waitFor } from '../support/lifecycle.mjs';

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
        if (item?.Name === environment.letterGridSearchLibrary) {
          return { item, shelfIndex };
        }
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
        childCount: { base: 'scene', keyPath: '#dynamicPageHost.getChildCount()' },
        pageType: { base: 'scene', keyPath: '#dynamicPageHost.0.subtype()' },
        pageVisible: { base: 'scene', keyPath: '#dynamicPageHost.0.visible' },
        responseOk: { base: 'scene', keyPath: '#videoLibraryTask.response.ok' },
        taskState: { base: 'scene', keyPath: '#videoLibraryTask.state' }
      }
    });
    return values.results.childCount?.value === 1
      && values.results.pageType?.value === 'VideoLibrary'
      && values.results.pageVisible?.value === true
      && values.results.responseOk?.value === true
      && ['done', 'stop'].includes(String(values.results.taskState?.value ?? '').toLowerCase());
  }, `the ${environment.letterGridSearchLibrary} movie library to load`, 120000);
}

async function selectLetterFromGrid(context, environment, letter) {
  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#letterGutterButton.buttonSelected',
    value: true
  });

  await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        overlayCount: { base: 'scene', keyPath: '#overlayHost.getChildCount()' },
        overlayType: { base: 'scene', keyPath: '#overlayHost.0.subtype()' },
        overlayVisible: { base: 'scene', keyPath: '#overlayHost.0.visible' }
      }
    });
    return values.results.overlayCount?.value === 1
      && values.results.overlayType?.value === 'LetterGridDialog'
      && values.results.overlayVisible?.value === true;
  }, 'the letter grid to open');

  await captureEvidence(context, `movie-library-letter-grid-${letter.toLowerCase()}-dialog-open`);

  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#overlayHost.0.activeLetter',
    value: letter
  });

  const letterIndex = letter.charCodeAt(0) - 63;
  await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        activeLetter: { base: 'scene', keyPath: '#overlayHost.0.activeLetter' },
        focused: { base: 'scene', keyPath: `#lettersGroup.${letterIndex}.itemHasFocus` },
        selected: { base: 'scene', keyPath: `#lettersGroup.${letterIndex}.isSelected` },
        title: { base: 'scene', keyPath: `#lettersGroup.${letterIndex}.itemContent.title` }
      }
    });
    return values.results.activeLetter?.value === letter
      && values.results.focused?.value === true
      && values.results.selected?.value === true
      && values.results.title?.value === letter;
  }, `${letter} to be selected in the letter grid`);

  await captureEvidence(context, `movie-library-letter-grid-${letter.toLowerCase()}-selected`);

  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#overlayHost.0.letterSelected',
    value: letter
  });
}

async function loadEveryFilteredItem(environment, letter) {
  return waitFor(async () => {
    const state = await environment.odc.getValues({
      requests: {
        gridCount: { base: 'scene', keyPath: '#itemsGrid.content.getChildCount()' },
        overlayCount: { base: 'scene', keyPath: '#overlayHost.getChildCount()' },
        requestLetter: { base: 'scene', keyPath: '#videoLibraryTask.request.startsWith' },
        responseOk: { base: 'scene', keyPath: '#videoLibraryTask.response.ok' },
        taskState: { base: 'scene', keyPath: '#videoLibraryTask.state' },
        totalCount: { base: 'scene', keyPath: '#videoLibraryTask.response.totalRecordCount' }
      }
    });
    const taskState = String(state.results.taskState?.value ?? '').toLowerCase();
    if (state.results.requestLetter?.value !== letter) return false;
    if (state.results.responseOk?.value !== true || !['done', 'stop'].includes(taskState)) return false;
    if (state.results.overlayCount?.value !== 0) return false;

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
  }, `all titles starting with ${letter} to load`, 120000);
}

async function readSortNames(environment, itemCount) {
  const requests = {};
  for (let itemIndex = 0; itemIndex < itemCount; itemIndex += 1) {
    requests[itemIndex] = {
      base: 'scene',
      keyPath: `#itemsGrid.content.${itemIndex}.raw.SortName`
    };
  }

  const response = await environment.odc.getValues({ requests });
  return Array.from({ length: itemCount }, (_, itemIndex) => response.results[itemIndex]?.value);
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

describe('Starfin movie library letter grid', function () {
  afterEach(async function () {
    await returnToHome();
  });

  const letterGridCases = JSON.parse(process.env.STARFIN_AUTOMATION_LETTERGRID_CASES ?? '[]');
  for (const letter of letterGridCases) {
    it(`shows every movie whose sort name starts with ${letter}`, async function () {
      const environment = await ensureAuthenticated();

      await openConfiguredMovieLibrary(environment);
      await selectLetterFromGrid(this, environment, letter);
      const { gridCount, totalCount } = await loadEveryFilteredItem(environment, letter);
      const sortNames = await readSortNames(environment, gridCount);

      assert.equal(gridCount, totalCount, `The grid should render all ${totalCount} matching titles.`);
      assert.equal(sortNames.length, totalCount, 'Every rendered item should expose its SortName.');
      for (const sortName of sortNames) {
        assert.equal(typeof sortName, 'string', 'Every rendered item should have a SortName.');
        assert.equal(
          sortName.toUpperCase().startsWith(letter),
          true,
          `SortName "${sortName}" should start with ${letter}.`
        );
      }

      await captureEvidence(this, `movie-library-letter-grid-${letter.toLowerCase()}`);
    });
  }
});
