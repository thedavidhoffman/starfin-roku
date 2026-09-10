import assert from 'node:assert/strict';
import test from 'node:test';
import { startHttpFixture } from '../../../scripts/rooibos-http-fixture.mjs';

test('captures an authenticated tile request', async () => {
  const fixture = await startHttpFixture('127.0.0.1');
  try {
    const authorization = `MediaBrowser Client="Fixture", Token="${fixture.config.token}"`;
    const response = await fetch(fixture.config.server + fixture.config.tilePath, {
      headers: { Authorization: authorization }
    });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      accepted: true, method: 'GET', path: fixture.config.tilePath,
      authorization, itemId: fixture.config.itemId
    });
    assert.equal(fixture.requests.length, 1);
  } finally {
    await fixture.close();
  }
});

test('rejects a download without the replacement header', async () => {
  const fixture = await startHttpFixture('127.0.0.1');
  try {
    const response = await fetch(fixture.config.server + fixture.config.tilePath);
    assert.equal(response.status, 401);
    assert.equal((await response.json()).accepted, false);
  } finally {
    await fixture.close();
  }
});

test('rejects query authentication even with a valid header', async () => {
  const fixture = await startHttpFixture('127.0.0.1');
  try {
    const response = await fetch(fixture.config.server + fixture.config.tilePath + '?ApiKey=old', {
      headers: { Authorization: `MediaBrowser Client="Fixture", Token="${fixture.config.token}"` }
    });
    assert.equal(response.status, 401);
    assert.equal((await response.json()).accepted, false);
  } finally {
    await fixture.close();
  }
});
