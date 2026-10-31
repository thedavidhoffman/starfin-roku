import dgram from 'node:dgram';
import http from 'node:http';
import { once } from 'node:events';

// Only Home uses this fixture. The authenticated app session keeps its real server.
export async function startHomeRefreshFixture(rokuHost, movie, initialLatestItems = [movie]) {
  const route = dgram.createSocket('udp4');
  let address;
  try {
    route.connect(8060, rokuHost);
    await once(route, 'connect');
    address = route.address().address;
  } finally {
    route.close();
  }

  let hold = false;
  let latestItems = initialLatestItems;
  let latestRequestCount = 0;
  const pending = new Map();
  const send = (response, status, body) => {
    response.writeHead(status, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify(body));
  };
  const server = http.createServer((request, response) => {
    request.resume();
    const url = new URL(request.url, 'http://fixture');
    const path = url.pathname.toLowerCase();
    const audio = url.searchParams.get('MediaTypes') === 'Audio';
    const section = path === '/shows/nextup' ? 'nextUp'
      : path === '/useritems/resume' && !audio ? 'continueWatching' : undefined;
    if (hold && section) {
      pending.set(section, response);
      response.on('close', () => {
        if (pending.get(section) === response) pending.delete(section);
      });
      return;
    }
    if (path === '/userviews') {
      send(response, 200, { Items: [{ Id: 'fixture-movies', Name: 'Movies', Type: 'CollectionFolder', CollectionType: 'movies' }] });
    } else if (path === '/items/latest') {
      latestRequestCount++;
      send(response, 200, latestItems);
    } else if (path === '/useritems/resume' || path === '/shows/nextup') {
      send(response, 200, { Items: [] });
    } else {
      send(response, 404, {});
    }
  });
  server.listen(0, address);
  await once(server, 'listening');
  return {
    url: `http://${address}:${server.address().port}`,
    setLatestItems(items) { latestItems = items; },
    get latestRequestCount() { return latestRequestCount; },
    holdRefresh() { hold = true; },
    hasPending(section) { return pending.has(section); },
    release(section, status) {
      const response = pending.get(section);
      if (!response) throw new Error(`Home fixture has no pending ${section} request`);
      pending.delete(section);
      send(response, status, status === 200 ? { Items: [] } : { error: 'Controlled Home refresh failure' });
    },
    async close() {
      server.closeAllConnections();
      await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    }
  };
}
