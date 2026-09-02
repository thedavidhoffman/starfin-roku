import assert from 'node:assert/strict';
import { ensureAuthenticated } from '../support/authentication.mjs';
import { captureEvidence } from '../support/evidence.mjs';
import { getAutomationEnvironment } from '../support/environment.mjs';
import { waitFor } from '../support/lifecycle.mjs';

const searchCases = JSON.parse(process.env.STARFIN_AUTOMATION_SEARCH_CASES ?? '[]');
const sectionTitles = {
  moviesAndSeries: 'Movies & TV Shows',
  episodes: 'Episodes',
  people: 'People'
};

async function openSearch(environment) {
  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#header.searchSelected',
    value: true
  });

  await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        childCount: { base: 'scene', keyPath: '#dynamicPageHost.getChildCount()' },
        pageType: { base: 'scene', keyPath: '#dynamicPageHost.0.subtype()' },
        pageVisible: { base: 'scene', keyPath: '#dynamicPageHost.0.visible' }
      }
    });
    return values.results.childCount?.value === 1
      && values.results.pageType?.value === 'Search'
      && values.results.pageVisible?.value === true;
  }, 'a fresh Search page');
}

async function readRenderedResults(environment) {
  const countResponse = await environment.odc.getValue({
    base: 'scene',
    keyPath: '#resultsGroup.getChildCount()'
  });
  const rowCount = countResponse.found ? countResponse.value : 0;
  const results = Object.fromEntries(Object.keys(sectionTitles).map(section => [section, []]));

  for (let rowIndex = 0; rowIndex < rowCount; rowIndex += 1) {
    const rowValues = await environment.odc.getValues({
      requests: {
        subtype: { base: 'scene', keyPath: `#resultsGroup.${rowIndex}.subtype()` },
        shelfTitle: { base: 'scene', keyPath: `#resultsGroup.${rowIndex}.rowContent.title` },
        shelfCount: { base: 'scene', keyPath: `#resultsGroup.${rowIndex}.rowContent.getChildCount()` },
        castTitle: { base: 'scene', keyPath: `#resultsGroup.${rowIndex}.title` },
        people: { base: 'scene', keyPath: `#resultsGroup.${rowIndex}.people` }
      }
    });
    const subtype = rowValues.results.subtype?.value;

    if (subtype === 'HomeShelf') {
      const title = rowValues.results.shelfTitle?.value;
      const section = Object.keys(sectionTitles).find(key => sectionTitles[key] === title);
      if (!section) continue;

      const itemCount = rowValues.results.shelfCount?.value ?? 0;
      const requests = {};
      for (let itemIndex = 0; itemIndex < itemCount; itemIndex += 1) {
        requests[itemIndex] = {
          base: 'scene',
          keyPath: `#resultsGroup.${rowIndex}.rowContent.${itemIndex}.raw.Name`
        };
      }
      if (itemCount > 0) {
        const itemValues = await environment.odc.getValues({ requests });
        results[section] = Array.from(
          { length: itemCount },
          (_, itemIndex) => itemValues.results[itemIndex]?.value
        ).filter(value => typeof value === 'string');
      }
    } else if (subtype === 'Cast' && rowValues.results.castTitle?.value === sectionTitles.people) {
      const people = rowValues.results.people?.value;
      results.people = Array.isArray(people)
        ? people.map(person => person?.Name).filter(value => typeof value === 'string')
        : [];
    }
  }

  return results;
}

async function waitForStableResults(environment, query) {
  let stableFingerprint;
  let stableSince = 0;

  return waitFor(async () => {
    const state = await environment.odc.getValues({
      requests: {
        task: { base: 'scene', keyPath: '#searchTask.state' },
        responseAction: { base: 'scene', keyPath: '#searchTask.response.action' },
        responseOk: { base: 'scene', keyPath: '#searchTask.response.ok' },
        responseQuery: { base: 'scene', keyPath: '#searchTask.response.query' },
        spinner: { base: 'scene', keyPath: '#loadingSpinner.visible' }
      }
    });
    if (!['done', 'stop'].includes(String(state.results.task?.value ?? '').toLowerCase())) return false;
    if (state.results.responseAction?.value !== 'search') return false;
    if (state.results.responseOk?.value !== true) return false;
    if (state.results.responseQuery?.value !== query) return false;
    if (state.results.spinner?.value !== false) return false;

    const results = await readRenderedResults(environment);
    const fingerprint = JSON.stringify(results);
    if (fingerprint !== stableFingerprint) {
      stableFingerprint = fingerprint;
      stableSince = Date.now();
      return false;
    }
    return Date.now() - stableSince >= 1000 ? results : false;
  }, 'Search results to finish rendering and become stable', 45000);
}

function assertExpectedResults(results, searchCase) {
  for (const section of Object.keys(sectionTitles)) {
    for (let index = 0; index < searchCase[section].length; index += 1) {
      assert.equal(
        results[section].includes(searchCase[section][index]),
        true,
        `Configured ${section} result ${index + 1} should be rendered.`
      );
    }
  }
}

async function returnToHome() {
  const environment = await getAutomationEnvironment();
  const searchVisible = await environment.odc.getValue({
    base: 'scene',
    keyPath: '#dynamicPageHost.0.visible'
  });
  if (!searchVisible.found || searchVisible.value !== true) return;

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
  }, 'Search to return to Home');
}

describe('Starfin Search results', function () {
  afterEach(async function () {
    await returnToHome();
  });

  for (let caseIndex = 0; caseIndex < searchCases.length; caseIndex += 1) {
    it(`returns configured results for search case ${caseIndex + 1}`, async function () {
      const environment = await ensureAuthenticated();
      const searchCase = searchCases[caseIndex];

      await openSearch(environment);
      await environment.odc.setValue({
        base: 'scene',
        keyPath: '#keyboard.text',
        value: searchCase.query
      });
      await environment.odc.setValue({
        base: 'scene',
        keyPath: '#searchButton.buttonSelected',
        value: true
      });

      const results = await waitForStableResults(environment, searchCase.query);
      assertExpectedResults(results, searchCase);

      const surface = await environment.odc.getValues({
        requests: {
          homeVisible: { base: 'scene', keyPath: '#homePage.visible' },
          searchVisible: { base: 'scene', keyPath: '#dynamicPageHost.0.visible' },
          statusVisible: { base: 'scene', keyPath: '#statusLabel.visible' }
        }
      });
      assert.equal(surface.results.homeVisible?.value, false, 'Home should remain hidden while Search is active.');
      assert.equal(surface.results.searchVisible?.value, true, 'Search should remain visible after results render.');
      assert.equal(surface.results.statusVisible?.value, false, 'Search should not display an application status error.');

      await captureEvidence(this, `search-results-case-${caseIndex + 1}`);
    });
  }
});
