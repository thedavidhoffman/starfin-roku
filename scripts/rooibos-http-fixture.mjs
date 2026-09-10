import dgram from 'node:dgram';
import http from 'node:http';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';

export async function startHttpFixture(rokuHost) {
  const route = dgram.createSocket('udp4');
  let address;
  try {
    route.connect(8060, rokuHost);
    await once(route, 'connect');
    address = route.address().address;
  } finally {
    route.close();
  }

  const itemId = `auth-fixture-${randomUUID()}`;
  const token = `fixture-${randomUUID()}`;
  const tilePath = `/Videos/${itemId}/Trickplay/320/0.jpg`;
  const requests = [];
  const server = http.createServer((request, response) => {
    if (request.url?.split('?')[0] !== tilePath) {
      response.writeHead(404).end();
      return;
    }
    const authorization = request.headers.authorization ?? '';
    const accepted = request.method === 'GET'
      && request.url === tilePath
      && authorization.startsWith('MediaBrowser ')
      && authorization.split(/,\s*/).some(part => part === `Token="${token}"`);
    const record = { accepted, method: request.method, path: request.url, authorization, itemId };
    requests.push(record);
    response.writeHead(accepted ? 200 : 401, { 'Content-Type': 'application/json' });
    // The task downloads bytes; echoing the wire request lets the device assert them.
    response.end(JSON.stringify(record));
  });
  server.listen(0, address);
  await once(server, 'listening');
  return {
    config: { server: `http://${address}:${server.address().port}`, token, itemId, tilePath },
    requests,
    server,
    async close() {
      server.closeAllConnections();
      await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    }
  };
}
