import assert from 'node:assert/strict';
import { captureEvidence } from './evidence.mjs';
import { waitFor } from './lifecycle.mjs';

async function selectBrowseMode(environment, browseMode) {
  if (browseMode === 'Title' || browseMode === 'Album') return;

  const optionIndex = browseMode === 'Artist' ? 1 : -1;
  assert.notEqual(optionIndex, -1, `Unsupported automated letter-grid browse mode: ${browseMode}`);

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
        optionTitle: { base: 'scene', keyPath: `#sortList.content.${optionIndex}.title` }
      }
    });
    return values.results.overlayType?.value === 'BrowseDialog'
      && values.results.overlayVisible?.value === true
      && values.results.optionTitle?.value === browseMode;
  }, `the Browse by ${browseMode} option`);

  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#sortList.itemSelected',
    value: optionIndex
  });

  await waitFor(async () => {
    const values = await environment.odc.getValues({
      requests: {
        gridCount: { base: 'scene', keyPath: '#musicGrid.content.getChildCount()' },
        overlayCount: { base: 'scene', keyPath: '#overlayHost.getChildCount()' },
        responseOk: { base: 'scene', keyPath: '#musicArtistsTask.response.ok' },
        taskState: { base: 'scene', keyPath: '#musicArtistsTask.state' }
      }
    });
    return values.results.overlayCount?.value === 0
      && values.results.gridCount?.value > 0
      && values.results.responseOk?.value === true
      && ['done', 'stop'].includes(String(values.results.taskState?.value ?? '').toLowerCase());
  }, `${browseMode} browsing to load`, 120000);
}

async function selectLetterFromGrid(context, environment, surface, letter) {
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
  await captureEvidence(context, `${surface}-letter-grid-${letter.toLowerCase()}-dialog-open`);

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
  await captureEvidence(context, `${surface}-letter-grid-${letter.toLowerCase()}-selected`);

  await environment.odc.setValue({
    base: 'scene',
    keyPath: '#overlayHost.0.letterSelected',
    value: letter
  });
}

async function loadEveryFilteredItem(environment, options) {
  return waitFor(async () => {
    const state = await environment.odc.getValues({
      requests: {
        gridCount: { base: 'scene', keyPath: `#${options.gridId}.content.getChildCount()` },
        overlayCount: { base: 'scene', keyPath: '#overlayHost.getChildCount()' },
        requestLetter: { base: 'scene', keyPath: `#${options.taskId}.request.startsWith` },
        responseOk: { base: 'scene', keyPath: `#${options.taskId}.response.ok` },
        taskState: { base: 'scene', keyPath: `#${options.taskId}.state` },
        totalCount: { base: 'scene', keyPath: `#${options.taskId}.response.totalRecordCount` }
      }
    });
    const taskState = String(state.results.taskState?.value ?? '').toLowerCase();
    if (state.results.requestLetter?.value !== options.letter) return false;
    if (state.results.responseOk?.value !== true || !['done', 'stop'].includes(taskState)) return false;
    if (state.results.overlayCount?.value !== 0) return false;

    const gridCount = state.results.gridCount?.value ?? 0;
    const totalCount = state.results.totalCount?.value ?? -1;
    if (totalCount <= 0 || gridCount <= 0) return false;
    if (gridCount >= totalCount) return { gridCount, totalCount };

    await environment.odc.setValue({
      base: 'scene',
      keyPath: `#${options.gridId}.itemFocused`,
      value: gridCount - 1
    });
    return false;
  }, `all ${options.itemLabel} starting with ${options.letter} to load`, 120000);
}

async function assertEverySortNameStartsWith(environment, options) {
  const batchSize = 25;
  let readCount = 0;
  for (let batchStart = 0; batchStart < options.itemCount; batchStart += batchSize) {
    const batchEnd = Math.min(batchStart + batchSize, options.itemCount);
    const requests = {};
    for (let index = batchStart; index < batchEnd; index += 1) {
      requests[index] = {
        base: 'scene',
        keyPath: `#${options.gridId}.content.${index}.raw.SortName`
      };
    }
    const response = await environment.odc.getValues({ requests });
    for (let index = batchStart; index < batchEnd; index += 1) {
      const sortName = response.results[index]?.value;
      assert.equal(typeof sortName, 'string', 'Every rendered item should expose its SortName.');
      assert.equal(
        sortName.toUpperCase().startsWith(options.letter),
        true,
        `SortName "${sortName}" should start with ${options.letter}.`
      );
      readCount += 1;
    }
  }
  assert.equal(readCount, options.itemCount, 'Every rendered item should be validated.');
}

export {
  assertEverySortNameStartsWith,
  loadEveryFilteredItem,
  selectBrowseMode,
  selectLetterFromGrid
};
