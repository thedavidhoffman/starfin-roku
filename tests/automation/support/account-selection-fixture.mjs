import dgram from 'node:dgram';
import http from 'node:http';
import { once } from 'node:events';

// Two base paths deliberately share an authority and user IDs. This exercises
// server identity without creating users or changing data on a real Jellyfin.
export async function startAccountSelectionFixture(rokuHost) {
  const route = dgram.createSocket('udp4');
  let address;
  try {
    route.connect(8060, rokuHost);
    await once(route, 'connect');
    address = route.address().address;
  } finally {
    route.close();
  }
  const requests = [];
  const pending = [];
  const states = new Map(['a', 'b'].map(id => [id, { authStatus: 200, holdAuth: false, holdHome: false, approved: false }]));
  const user = id => ({ Id: id, Name: `User ${id}`, Policy: { EnableLiveTvAccess: false }, Configuration: { LatestItemsExcludes: [] } });
  const send = (res, status, body) => {
    if (res.destroyed) return;
    res.writeHead(status, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(body));
  };
  const server = http.createServer(async (req, res) => {
    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    const url = new URL(req.url, 'http://fixture');
    const [, id, ...parts] = url.pathname.split('/');
    const path = `/${parts.join('/')}`.toLowerCase();
    const state = states.get(id);
    requests.push({ server: id, path, method: req.method });
    if (!state) return send(res, 404, {});
    let status = 200;
    let body;
    let kind;
    if (/^\/users\/u\d+$/.test(path)) {
      kind = 'auth';
      status = state.authStatus;
      body = user(parts[1]);
    } else if (path === '/users/authenticatebyname') {
      const credentials = JSON.parse(Buffer.concat(chunks).toString() || '{}');
      status = credentials.Pw === 'fixture-password' ? 200 : 401;
      body = { AccessToken: `${id}-token`, User: user(credentials.Username || 'u0') };
    } else if (path === '/quickconnect/initiate') {
      body = { Secret: 'fixture-secret', Code: '123456' };
    } else if (path === '/quickconnect/connect') {
      body = { Authenticated: state.approved };
    } else if (path === '/users/authenticatewithquickconnect') {
      body = { AccessToken: `${id}-token`, User: user('u0') };
    } else if (path === '/userviews') {
      kind = 'home';
      body = { Items: [{ Id: `${id}-library`, Name: `Library ${id}`, Type: 'CollectionFolder', CollectionType: 'movies' }] };
    } else if (path === '/items/latest') {
      kind = 'home';
      body = [];
    } else if (path === '/useritems/resume' || path === '/shows/nextup') {
      kind = 'home';
      body = { Items: [] };
    } else {
      // Deep-link tests intentionally request an unavailable item, exercising
      // resolution and the final Home fallback without needing video media.
      status = 404;
      body = {};
    }
    if ((kind === 'auth' && state.holdAuth) || (kind === 'home' && state.holdHome)) {
      pending.push({ id, kind, res, status, body });
    } else send(res, status, body);
  });
  server.listen(0, address);
  await once(server, 'listening');
  return {
    requests,
    url: id => `http://${address}:${server.address().port}/${id}`,
    state: id => states.get(id),
    pendingCount: (id, kind) => pending.filter(entry => entry.id === id && entry.kind === kind && !entry.res.destroyed).length,
    release(id, kind) {
      for (let i = pending.length - 1; i >= 0; i--) {
        const entry = pending[i];
        if (entry.id === id && entry.kind === kind) {
          pending.splice(i, 1);
          send(entry.res, entry.status, entry.body);
        }
      }
    },
    async close() {
      server.closeAllConnections();
      await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    }
  };
}
