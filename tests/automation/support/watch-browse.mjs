import assert from 'node:assert/strict';
import { value, set } from './remote-keys.mjs';
import { waitFor } from './lifecycle.mjs';

export async function waitForWatch(environment, mode, direction = 'Ascending', letter = 'ALL') {
  return waitFor(async () => {
    const state = await environment.odc.getValues({ requests: {
      loading: { base: 'scene', keyPath: '#loadingSpinner.visible' },
      watch: { base: 'scene', keyPath: '#videoLibraryTask.request.watchStatus' },
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
    if (r.loading?.value === true || r.watch?.value !== (mode === 'SortName' ? 'All' : mode) || r.sortBy?.value !== 'SortName' || r.direction?.value !== direction
      || r.letter?.value !== letter || r.ok?.value !== true
      || r.responseQuery?.value !== r.query?.value
      || r.responseStart?.value !== r.start?.value
      || !['done', 'stop'].includes(String(r.task?.value).toLowerCase())
      || r.selectedKey?.value !== mode
      || r.selectedOrder?.value !== direction
      || r.overlays?.value !== 0) return false;
    const count = r.count?.value ?? 0;
    if (count < r.next?.value) return false;
    return { count, total: r.total?.value };
  }, mode + ' ' + direction + ' results for ' + letter, 120000);
}

export async function loadWatchItems(environment, mode, direction = 'Ascending', letter = 'ALL') {
  const deadline = Date.now() + 180000;
  while (Date.now() < deadline) {
    const { count, total } = await waitForWatch(environment, mode, direction, letter);
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


export async function openWatchMenu(environment) {
  await set(environment, '#browseByButton.overlayRequested', {
    id: 'sort', componentName: 'BrowseDialog', openFunction: 'openBrowse',
    closeFields: ['closeRequested', 'sortSelected']
  });
  await waitFor(async () => await value(environment, '#overlayHost.0.subtype()') === 'BrowseDialog', 'Browse By menu');
  const count = await value(environment, '#sortList.content.getChildCount()');
  const labels = [];
  for (let i = 0; i < count; i++) labels.push(await value(environment, `#sortList.content.${i}.title`));
  return labels;
}

export async function selectWatch(environment, mode, direction = 'Ascending') {
  // Start at Title so selecting the same filtered option still starts ascending.
  if (mode !== 'SortName') {
    await openWatchMenu(environment);
    await set(environment, '#sortList.itemSelected', 0);
    await waitForWatch(environment, 'SortName');
  }
  const labels = await openWatchMenu(environment);
  const index = labels.indexOf(mode === 'SortName' ? 'Title' : mode);
  assert.ok(index >= 0, `${mode} must be available`);
  await set(environment, '#sortList.itemSelected', index);
  await waitForWatch(environment, mode);
  if (direction === 'Descending') {
    await set(environment, '#sortButton.sortOrderChanged', { sortOrder: direction });
    await waitForWatch(environment, mode, direction);
  }
}

export async function selectWatchLetter(environment, letter) {
  await set(environment, '#letterGutterButton.buttonSelected', true);
  await waitFor(async () => await value(environment, '#overlayHost.0.subtype()') === 'LetterGridDialog', 'letter dialog');
  await set(environment, '#overlayHost.0.activeLetter', letter);
  await waitFor(async () => await value(environment, '#overlayHost.0.activeLetter') === letter, 'active letter');
  await set(environment, '#overlayHost.0.letterSelected', letter);
}

export async function watchApi(environment) {
  const session = {};
  for (const key of ['server', 'userId', 'token']) session[key] = await value(environment, '#authController.authenticatedSession.' + key);
  const base = (session.server.includes('://') ? session.server : 'http://' + session.server).replace(/\/$/, '');
  const api = async (path, query = {}, body, method) => {
    const url = new URL(base + path);
    url.search = new URLSearchParams({ UserId: session.userId, ...query }).toString();
    const result = await fetch(url, {
      method: method ?? (body === undefined ? 'GET' : 'POST'),
      headers: { 'X-Emby-Token': session.token, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(120000)
    });
    assert.ok(result.ok, `${path}: HTTP ${result.status}`);
    const text = await result.text();
    return text ? JSON.parse(text) : undefined;
  };
  return { api, userId: session.userId };
}

// Query Jellyfin independently, including every page; the UI request is used only
// to identify the library, never to supply its filter or ordering expectations.
export async function expectedWatchItems(environment, mode, direction = 'Ascending', letter = 'ALL') {
  const { api, userId } = await watchApi(environment);
  const parentId = await value(environment, '#videoLibraryTask.request.libraryId');
  const type = await value(environment, '#videoLibraryTask.request.includeItemTypes');
  const items = [];
  let total;
  do {
    const query = { ParentId: parentId, IncludeItemTypes: type, Recursive: true,
      Fields: 'SortName', SortBy: 'SortName', SortOrder: direction,
      StartIndex: items.length, Limit: 100, EnableTotalRecordCount: true };
    if (mode !== 'SortName') query.Filters = mode === 'Watched' ? 'IsPlayed' : 'IsUnplayed';
    if (letter !== 'ALL' && letter !== '#') query.NameStartsWith = letter;
    const payload = await api(`/Users/${userId}/Items`, query);
    total ??= payload.TotalRecordCount;
    assert.equal(payload.TotalRecordCount, total);
    assert.ok(payload.Items.length || total === 0, 'Server paging must progress');
    items.push(...payload.Items);
  } while (items.length < total);
  // # uses the existing ASCII letter buckets. Preserve the server's title order.
  return letter === '#' ? items.filter(item => !/^[a-z]/i.test(item.SortName ?? item.Name ?? '')) : items;
}

export async function snapshotWatchItem(environment, item) {
  const { api, userId } = await watchApi(environment);
  const children = [];
  if (item.Type === 'Series') {
    for (const kind of ['Episodes', 'Seasons']) {
      const result = await api(`/Shows/${item.Id}/${kind}`);
      assert.equal(result.Items.length, result.TotalRecordCount, 'Snapshot must include every ' + kind);
      children.push(...result.Items);
    }
  }
  const snapshot = [...children, item].map(entry => {
    assert.ok(entry.UserData, `User data required for ${entry.Id}`);
    return { id: entry.Id, data: structuredClone(entry.UserData) };
  });
  return { api, userId, snapshot, episodes: children.filter(child => child.Type === 'Episode'),
    async played(id, played) {
      await api(`/Users/${userId}/PlayedItems/${id}`, {}, undefined, played ? 'POST' : 'DELETE');
    },
    async restore() {
      const failures = [];
      // Leaves before aggregates preserves partially watched series histories.
      for (const entry of snapshot) {
        try { await api(`/UserItems/${entry.id}/UserData`, {}, entry.data); }
        catch (error) { failures.push(error); }
      }
      for (const entry of snapshot) {
        try {
          const restored = (await api(`/Users/${userId}/Items/${entry.id}`)).UserData;
          for (const field of ['Played', 'PlayCount', 'PlaybackPositionTicks', 'IsFavorite', 'LastPlayedDate']) {
            assert.deepEqual(restored[field] ?? null, entry.data[field] ?? null, `${entry.id} restored ${field}`);
          }
        } catch (error) { failures.push(error); }
      }
      if (failures.length) throw new AggregateError(failures, 'Watched fixture cleanup failed');
    }
  };
}
