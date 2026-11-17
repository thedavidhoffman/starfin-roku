import dgram from 'node:dgram';
import http from 'node:http';
import { once } from 'node:events';
import { Readable } from 'node:stream';

// Network setup before UI entry: preserve the real plugin, fail only MP4 assets.
export async function startDvdPreviewProxy(rokuHost, upstream) {
  const route = dgram.createSocket('udp4');
  let address;
  try {
    route.connect(8060, rokuHost);
    await once(route, 'connect');
    address = route.address().address;
  } finally {
    route.close();
  }
  let previewFailures = 0;
  const server = http.createServer(async (request, response) => {
    const abort = new AbortController();
    response.once('close', () => abort.abort());
    try {
      if (/\/Starfin\/Dvd\/Demos\/[^/]+\/Assets\/[^/]+\.mp4(?:\?|$)/i.test(request.url)) {
        request.resume();
        previewFailures++;
        response.writeHead(503);
        response.end();
        return;
      }
      const chunks = [];
      for await (const chunk of request) chunks.push(chunk);
      const headers = { ...request.headers, 'accept-encoding': 'identity' };
      delete headers.host;
      delete headers.connection;
      const result = await fetch(upstream.replace(/\/$/, '') + request.url, {
        method: request.method, headers,
        body: ['GET', 'HEAD'].includes(request.method) ? undefined : Buffer.concat(chunks),
        signal: AbortSignal.any([abort.signal, AbortSignal.timeout(60000)])
      });
      response.writeHead(result.status, Object.fromEntries([...result.headers].filter(
        ([key]) => !['content-encoding', 'content-length', 'transfer-encoding', 'connection'].includes(key)
      )));
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
    get previewFailures() { return previewFailures; },
    async close() {
      const closed = new Promise(resolve => server.close(resolve));
      server.closeAllConnections();
      await closed;
    }
  };
}
