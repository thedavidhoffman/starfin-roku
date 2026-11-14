import dgram from 'node:dgram';
import http from 'node:http';
import { once } from 'node:events';
import { Readable } from 'node:stream';

// Hold only theme discovery; metadata and real audio still come from Jellyfin.
export async function startThemeProxy(rokuHost, upstream) {
  const route = dgram.createSocket('udp4');
  let address;
  try {
    route.connect(8060, rokuHost);
    await once(route, 'connect');
    address = route.address().address;
  } finally {
    route.close();
  }
  upstream = upstream.includes('://') ? upstream : 'http://' + upstream;
  let held;
  let released = false;
  const server = http.createServer(async (request, response) => {
    const abort = new AbortController();
    response.once('close', () => abort.abort());
    try {
      if (/\/ThemeSongs(?:\?|$)/i.test(request.url) && !released) {
        await new Promise(resolve => {
          held = resolve;
          response.once('close', resolve);
        });
        if (response.destroyed) return;
      }
      const chunks = [];
      for await (const chunk of request) chunks.push(chunk);
      const headers = { ...request.headers };
      delete headers.host;
      delete headers.connection;
      // fetch decompresses responses; do not forward the original encoding/length.
      headers['accept-encoding'] = 'identity';
      const result = await fetch(upstream.replace(/\/$/, '') + request.url, {
        method: request.method, headers,
        body: ['GET', 'HEAD'].includes(request.method) ? undefined : Buffer.concat(chunks),
        signal: AbortSignal.any([abort.signal, AbortSignal.timeout(60000)])
      });
      response.writeHead(result.status, Object.fromEntries(
        [...result.headers].filter(([key]) => !['content-encoding', 'content-length', 'transfer-encoding', 'connection'].includes(key))
      ));
      if (result.body) Readable.fromWeb(result.body).on('error', () => response.destroy()).pipe(response);
      else response.end();
    } catch {
      if (!response.headersSent) response.writeHead(502);
      response.end();
    }
  });
  server.listen(0, address);
  await once(server, 'listening');
  return {
    url: `http://${address}:${server.address().port}`,
    get pending() { return Boolean(held) && !released; },
    release() { released = true; held?.(); },
    async close() {
      released = true;
      held?.();
      const closed = new Promise(resolve => server.close(resolve));
      server.closeAllConnections();
      await closed;
    }
  };
}
