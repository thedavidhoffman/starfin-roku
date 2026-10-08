import assert from 'node:assert/strict';
import test from 'node:test';
import { focusItem } from '../support/remote-keys.mjs';

function gridEnvironment(pages, row = false) {
  const control = '#items';
  const content = `${control}.content${row ? '.0' : ''}`;
  const focusField = `${control}.${row ? 'rowItemFocused' : 'itemFocused'}`;
  const jumpField = `${control}.${row ? 'jumpToRowItem' : 'jumpToItem'}`;
  const batches = [];
  let page = 0;
  let focused = false;
  let position;
  const environment = {
    odc: {
      async getValue({ keyPath }) {
        if (keyPath === `${content}.getChildCount()`) return { value: pages[page].length };
        if (keyPath === focusField) return { value: position };
        assert.fail(`Unexpected individual read: ${keyPath}`);
      },
      async getValues({ requests }) {
        batches.push(Object.keys(requests).length);
        return { results: Object.fromEntries(Object.entries(requests).map(([index, request]) => {
          assert.equal(request.keyPath, `${content}.${index}.raw.Id`);
          return [index, { value: pages[page][Number(index)] }];
        })) };
      },
      async setValue({ keyPath, value }) {
        assert.ok(keyPath === jumpField || keyPath === focusField);
        position = value;
        if (keyPath === focusField && page < pages.length - 1) page++;
      },
      async focusNode({ keyPath }) {
        assert.equal(keyPath, control);
        focused = true;
      },
      async hasFocus() { return focused; }
    }
  };
  return { environment, batches, control };
}

test('focuses a movie in a large library using bounded batches', async () => {
  const ids = Array.from({ length: 251 }, (_, index) => `movie-${index}`);
  const { environment, batches, control } = gridEnvironment([ids]);

  const focus = await focusItem(environment, control, 'movie-250');

  assert.deepEqual(focus, { control, id: 'movie-250', row: false, position: 250 });
  assert.deepEqual(batches, [100, 100, 51]);
});

test('requests another page before focusing a later movie', async () => {
  const { environment, control } = gridEnvironment([['first'], ['first', 'target']]);

  const focus = await focusItem(environment, control, 'target');

  assert.equal(focus.position, 1);
});

test('rescans replaced content even when its count is unchanged', async () => {
  const { environment, control } = gridEnvironment([['old'], ['target']]);

  const focus = await focusItem(environment, control, 'target');

  assert.equal(focus.position, 0);
});

test('preserves row-list content paths and focus positions', async () => {
  const { environment, control } = gridEnvironment([['first', 'target']], true);

  const focus = await focusItem(environment, control, 'target', true);

  assert.deepEqual(focus, { control, id: 'target', row: true, position: [0, 1] });
});
