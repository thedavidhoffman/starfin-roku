import assert from 'node:assert/strict';
import { waitFor } from './lifecycle.mjs';
import { openConfiguredLibrary } from './library-navigation.mjs';
import { stopPlaybackForCleanup } from './tv-series.mjs';

export async function value(environment, keyPath) {
  return (await environment.odc.getValue({ base: 'scene', keyPath })).value;
}

export async function set(environment, keyPath, entry) {
  await environment.odc.setValue({ base: 'scene', keyPath, value: entry });
}

export async function press(environment, key) {
  await environment.ecp.sendKeypress(environment.ecp.Key[key]);
}

export async function page(environment, type) {
  return waitFor(async () => {
    const count = await value(environment, '#dynamicPageHost.getChildCount()');
    for (let index = 0; index < count; index++) {
      const path = `#dynamicPageHost.${index}`;
      if (await value(environment, `${path}.subtype()`) === type
        && await value(environment, `${path}.visible`) === true) return path;
    }
    return false;
  }, `visible ${type} page`, 120000);
}

export async function getItem(environment, id, type) {
  const session = {
    server: await value(environment, '#authController.authenticatedSession.server'),
    userId: await value(environment, '#authController.authenticatedSession.userId'),
    token: await value(environment, '#authController.authenticatedSession.token')
  };
  const server = (session.server.includes('://') ? session.server : `http://${session.server}`).replace(/\/$/, '');
  const url = new URL(`${server}/Users/${encodeURIComponent(session.userId)}/Items/${encodeURIComponent(id)}`);
  url.search = new URLSearchParams({ UserId: session.userId }).toString();
  const response = await fetch(url, { headers: { 'X-Emby-Token': session.token } });
  assert.equal(response.ok, true, `Item ${id} must load successfully (HTTP ${response.status}).`);
  const item = await response.json();
  assert.equal(item.Type, type, `Item ${id} must be ${type}.`);
  return item;
}

export async function openLibrary(environment, libraryName, collectionType) {
  await openConfiguredLibrary(environment, {
    libraryName, collectionType, pageType: 'VideoLibrary', taskId: 'videoLibraryTask'
  });
  return page(environment, 'VideoLibrary');
}

export async function focusItem(environment, control, id, row = false) {
  const content = `${control}.content${row ? '.0' : ''}`;
  const index = await waitFor(async () => {
    const count = await value(environment, `${content}.getChildCount()`);
    // A response can replace content without changing its count; rescan the current nodes.
    // Batch reads so large libraries do not exhaust the timeout on network round trips.
    for (let start = 0; start < count; start += 100) {
      const end = Math.min(start + 100, count);
      const requests = {};
      for (let index = start; index < end; index++) {
        requests[index] = { base: 'scene', keyPath: `${content}.${index}.raw.Id` };
      }
      const response = await environment.odc.getValues({ requests });
      for (let index = start; index < end; index++) {
        if (response.results[index]?.value === id) return { index };
      }
    }
    // Moving to the loaded end requests the next page on paginated surfaces.
    if (count > 0) {
      const end = row ? [0, count - 1] : count - 1;
      await set(environment, `${control}.${row ? 'jumpToRowItem' : 'jumpToItem'}`, end);
      // Paging observes the focused-item field, even before this control takes focus.
      await set(environment, `${control}.${row ? 'rowItemFocused' : 'itemFocused'}`, end);
    }
    return false;
  }, `rendered item ${id}`, 120000);
  const position = row ? [0, index.index] : index.index;
  await environment.odc.focusNode({ base: 'scene', keyPath: control });
  await set(environment, `${control}.${row ? 'jumpToRowItem' : 'jumpToItem'}`, position);
  await waitFor(async () => await environment.odc.hasFocus({ base: 'scene', keyPath: control })
    && JSON.stringify(await value(environment, `${control}.${row ? 'rowItemFocused' : 'itemFocused'}`)) === JSON.stringify(position), 'item focus');
  return { control, id, row, position };
}

export async function shelfItem(environment, group, id, type) {
  return waitFor(async () => {
    const count = await value(environment, `${group}.getChildCount()`);
    for (let row = 0; row < count; row++) {
      const shelf = `${group}.${row}`;
      if (await value(environment, `${shelf}.subtype()`) !== 'HomeShelf') continue;
      const items = await value(environment, `${shelf}.rowContent.getChildCount()`);
      for (let index = 0; index < items; index++) {
        const item = await value(environment, `${shelf}.rowContent.${index}.raw`);
        if ((id ? item?.Id === id : item?.Type === type)) {
          const focus = group === '#shelvesGroup'
            ? await focusHomeItem(environment, await value(environment, `${shelf}.rowContent.rowKey`), item.Id)
            : await focusItem(environment, `${shelf}.#items`, item.Id, true);
          return { item, focus };
        }
      }
    }
    return false;
  }, `${type ?? id} on ${group}`, 45000);
}

async function focusHomeItem(environment, rowKey, id) {
  await environment.odc.callFunc({ base: 'scene', keyPath: '#homePage', funcName: 'focusHome' });
  const shelfCount = await value(environment, '#shelvesGroup.getChildCount()');
  let control;
  // Navigate through Home so its tracked shelf agrees with SceneGraph focus.
  for (let step = 0; step < shelfCount; step++) {
    const rows = await waitFor(async () => {
      const count = await value(environment, '#shelvesGroup.getChildCount()');
      const entries = [];
      let focused = -1;
      let target = -1;
      for (let index = 0; index < count; index++) {
        const shelf = `#shelvesGroup.${index}`;
        const key = await value(environment, `${shelf}.rowContent.rowKey`);
        entries.push({ key, control: `${shelf}.#items` });
        if (key === rowKey) target = index;
        if (await environment.odc.hasFocus({ base: 'scene', keyPath: `${shelf}.#items` })) focused = index;
      }
      return focused >= 0 && target >= 0 ? { entries, focused, target } : false;
    }, `Home focus and target shelf ${rowKey}`);
    if (rows.focused === rows.target) {
      control = rows.entries[rows.target].control;
      break;
    }
    const next = rows.entries[rows.focused + (rows.target > rows.focused ? 1 : -1)];
    await press(environment, rows.target > rows.focused ? 'Down' : 'Up');
    await waitFor(async () => await environment.odc.hasFocus({ base: 'scene', keyPath: next.control })
      && await value(environment, `${next.control}.content.0.rowKey`) === next.key,
    `remote navigation to Home shelf ${next.key}`);
  }
  assert.ok(control, `Remote navigation must reach Home shelf ${rowKey}.`);
  const count = await value(environment, `${control}.content.0.getChildCount()`);
  let itemIndex = -1;
  for (let index = 0; index < count; index++) {
    if (await value(environment, `${control}.content.0.${index}.raw.Id`) === id) {
      itemIndex = index;
      break;
    }
  }
  assert.ok(itemIndex >= 0, `Home shelf ${rowKey} must still contain item ${id}.`);
  await set(environment, `${control}.jumpToRowItem`, [0, itemIndex]);
  const position = await waitFor(async () => {
    if (!await environment.odc.hasFocus({ base: 'scene', keyPath: control })) return false;
    if (await value(environment, `${control}.content.0.rowKey`) !== rowKey) return false;
    const focused = await value(environment, `${control}.rowItemFocused`);
    return focused?.[0] === 0
      && await value(environment, `${control}.content.0.${focused[1]}.raw.Id`) === id ? focused : false;
  }, `focused Home item ${id} in shelf ${rowKey}`);
  return { control, id, row: true, position, rowKey };
}

export async function homeShelfItem(environment, rowKind, type) {
  const rowLabel = { latest: 'Recently Added', continueWatching: 'Continue Watching', nextUp: 'Next Up' }[rowKind];
  const selected = await waitFor(async () => {
    const count = await value(environment, '#shelvesGroup.getChildCount()');
    for (let row = 0; row < count; row++) {
      const shelf = `#shelvesGroup.${row}`;
      if (await value(environment, `${shelf}.subtype()`) !== 'HomeShelf') continue;
      const rowKey = await value(environment, `${shelf}.rowContent.rowKey`);
      if (rowKind === 'latest' ? !rowKey?.startsWith('latest:') : rowKey !== rowKind) continue;
      const itemCount = await value(environment, `${shelf}.rowContent.getChildCount()`);
      for (let index = 0; index < itemCount; index++) {
        const path = `${shelf}.rowContent.${index}.raw`;
        if (await value(environment, `${path}.Type`) !== type) continue;
        const id = await value(environment, `${path}.Id`);
        if (!id || await value(environment, `${path}.IsMissing`) === true
          || await value(environment, `${path}.IsVirtualItem`) === true) continue;
        const savedPositionTicks = Number(await value(environment, `${path}.UserData.PlaybackPositionTicks`) ?? 0);
        if (rowKind === 'continueWatching' && !(savedPositionTicks > 0)) continue;
        return { id, type, savedPositionTicks, shelf, rowKey };
      }
    }
    return false;
  }, `required ${type} in ${rowLabel} on Home; the test account must expose a playable ${type}${rowKind === 'continueWatching' ? ' with saved progress' : ''}`, 45000);
  const focus = await focusHomeItem(environment, selected.rowKey, selected.id);
  return { ...selected, focus };
}

export async function waitForVideo(environment, id) {
  return waitFor(async () => {
    const itemId = await value(environment, '#playbackController.0.playRequest.itemId');
    const state = await value(environment, '#videoPlayer.state');
    assert.notEqual(state, 'error', 'Video playback must not fail.');
    return itemId === id && state === 'playing'
      && await value(environment, '#playbackController.0.visible') === true
      && await value(environment, '#videoPlayer.duration') > 0;
  }, `playing video ${id}`, 120000);
}

export async function readPlaybackQueue(environment) {
  const path = '#playbackController.0.playRequest';
  const queue = await value(environment, `${path}.playbackQueue`);
  const index = await value(environment, `${path}.playbackQueueIndex`);
  assert.ok(Array.isArray(queue), 'Playback queue must be available.');
  assert.ok(Number.isInteger(index) && index >= 0 && index < queue.length, 'Playback queue index must select an item.');
  // Read member fields on Roku; serialized associative-array key casing is not a JS contract.
  return {
    currentItemId: await value(environment, `${path}.playbackQueue.${index}.itemId`),
    nextItemId: index + 1 < queue.length
      ? await value(environment, `${path}.playbackQueue.${index + 1}.itemId`) : undefined,
    playlistItemIndex: await value(environment, `${path}.playbackQueue.${index}.playlistItemIndex`),
    nextItemPlayback: await value(environment, `${path}.nextItemPlayback`)
  };
}

export async function assertNoPlayback(environment) {
  // Allow asynchronous key handlers/task observers to run before checking guards.
  await new Promise(resolve => setTimeout(resolve, 1000));
  assert.equal(await value(environment, '#playbackController.getChildCount()'), 0);
  const count = await value(environment, '#dynamicPageHost.getChildCount()');
  for (let index = 0; index < count; index++) {
    assert.notEqual(await value(environment, `#dynamicPageHost.${index}.subtype()`), 'AudioPlayer');
  }
}

export async function assertFocus(environment, destination, focus) {
  const restored = await waitFor(async () => {
    if (await value(environment, `${destination}.visible`) !== true) return false;
    let control = focus.control;
    if (destination === '#homePage') {
      // Home refresh can rebuild or reorder entire shelves; locate the actual focused shelf.
      const count = await value(environment, '#shelvesGroup.getChildCount()');
      control = undefined;
      for (let row = 0; row < count; row++) {
        const candidate = `#shelvesGroup.${row}.#items`;
        if (await environment.odc.hasFocus({ base: 'scene', keyPath: candidate })) {
          if (focus.rowKey && await value(environment, `#shelvesGroup.${row}.rowContent.rowKey`) !== focus.rowKey) return false;
          control = candidate;
          break;
        }
      }
      if (!control) return false;
    } else if (!await environment.odc.hasFocus({ base: 'scene', keyPath: control })) return false;
    const position = await value(environment, `${control}.${focus.row ? 'rowItemFocused' : 'itemFocused'}`);
    const index = focus.row ? position?.[1] : position;
    return await value(environment, `${control}.content${focus.row ? '.0' : ''}.${index}.raw.Id`) === focus.id
      ? { position } : false;
  }, 'return destination and selected item focus');
  if (destination !== '#homePage') assert.deepEqual(restored.position, focus.position, 'Return must restore the selected item position.');
  assert.equal(await value(environment, '#messageOverlayHost.visible'), false, 'Return must not display an application error.');
}

export async function closeVideo(environment, destination, focus) {
  await stopPlaybackForCleanup(environment);
  assert.equal(await value(environment, '#playbackController.getChildCount()'), 0);
  if (focus) await assertFocus(environment, destination, focus);
  else await waitFor(async () => await value(environment, `${destination}.visible`) === true, 'playback return page');
}

export async function openMovie(environment) {
  const id = environment.deepLinkCases.movieId;
  const destination = await openLibrary(environment, environment.movieLibrary, 'movies');
  const focus = await focusItem(environment, `${destination}.#itemsGrid`, id);
  await press(environment, 'Ok');
  const details = await page(environment, 'Movie');
  await waitFor(async () => await value(environment, `${details}.loadRequest.itemId`) === id
    && Boolean(await value(environment, `${details}.#mediaToolbar.mediaInfoText`))
    && await value(environment, '#loadingSpinner.visible') === false, 'loaded movie metadata');
  return { id, destination, focus, details };
}
