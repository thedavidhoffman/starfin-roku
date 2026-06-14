import fs from 'node:fs';
import fsp from 'node:fs/promises';
import http from 'node:http';
import net from 'node:net';
import path from 'node:path';

const rootDir = process.cwd();
const configPath = path.join(rootDir, 'rokudeploy.json');
const logFilePath = path.join(rootDir, 'logs', 'rokuDevice.log');
const logMode = process.argv.includes('--socket') ? 'socket' : 'file';
const debugPort = 8085;
const defaultViewerPort = 4175;
const maxViewerPortAttempts = 20;
const maxHistory = 5000;
const reconnectDelayMs = 3000;

const history = [];
const clients = new Set();
let rokuSocket = null;
let rokuHost = '';
let reconnectTimer = invalidTimer();
let connectionState = 'starting';
let lineBuffer = '';
let reconnectBlocked = false;
let watchedLogSize = 0;
let fileWatchTimer = invalidTimer();

function invalidTimer() {
  return undefined;
}

async function loadConfig() {
  let rawConfig;
  try {
    rawConfig = await fsp.readFile(configPath, 'utf8');
  } catch (error) {
    console.error('Missing rokudeploy.json. Copy rokudeploy.example.json to rokudeploy.json and set your Roku host.');
    process.exit(1);
  }

  let config;
  try {
    config = JSON.parse(rawConfig);
  } catch (error) {
    console.error('rokudeploy.json must be valid JSON.');
    process.exit(1);
  }

  if (!config.host) {
    console.error('rokudeploy.json must include "host".');
    process.exit(1);
  }

  return config;
}

async function startFileTail() {
  await ensureLogFile();
  setState('waiting-for-log-file');
  addLogLine(`Watching ${logFilePath}`);
  await pollLogFile();

  fileWatchTimer = setInterval(() => {
    pollLogFile().catch(error => {
      setState('file-error');
      addLogLine(`Log file read error: ${error.message}`);
    });
  }, 500);
}

async function ensureLogFile() {
  await fsp.mkdir(path.dirname(logFilePath), {
    recursive: true
  });

  const file = await fsp.open(logFilePath, 'a');
  await file.close();
}

async function pollLogFile() {
  let stat;
  try {
    stat = await fsp.stat(logFilePath);
  } catch (error) {
    if (error.code === 'ENOENT') {
      setState('waiting-for-log-file');
      return;
    }

    throw error;
  }

  if (stat.size < watchedLogSize) {
    watchedLogSize = 0;
    lineBuffer = '';
    addLogLine('Log file was reset. Continuing from the beginning of the new file.');
  }

  if (stat.size === watchedLogSize) {
    if (connectionState !== 'tailing') setState('tailing');
    return;
  }

  const stream = fs.createReadStream(logFilePath, {
    encoding: 'utf8',
    start: watchedLogSize,
    end: stat.size - 1
  });

  watchedLogSize = stat.size;

  await new Promise((resolve, reject) => {
    stream.on('data', handleLogFileData);
    stream.on('error', reject);
    stream.on('end', resolve);
  });

  setState('tailing');
}

function handleLogFileData(chunk) {
  lineBuffer += chunk.toString();
  const lines = lineBuffer.split(/\n/);
  lineBuffer = lines.pop() ?? '';

  for (const line of lines) {
    addLogLine(line);
  }
}

function setState(state) {
  connectionState = state;
  broadcast({
    type: 'status',
    state
  });
}

function addLogLine(raw) {
  const line = raw.replace(/\r$/, '');
  const entry = {
    id: Date.now().toString(36) + '-' + Math.random().toString(36).slice(2),
    raw: line
  };

  history.push(entry);
  if (history.length > maxHistory) history.shift();

  broadcast({
    type: 'log',
    entry
  });
}

function broadcast(payload) {
  const text = `data: ${JSON.stringify(payload)}\n\n`;

  for (const response of clients) {
    response.write(text);
  }
}

function handleRokuData(chunk) {
  lineBuffer += chunk.toString('utf8');
  const lines = lineBuffer.split(/\n/);
  lineBuffer = lines.pop() ?? '';

  for (const line of lines) {
    if (line.toLowerCase().includes('console connection is already in use')) {
      reconnectBlocked = true;
      addLogLine('Console connection is already in use. Close the VS Code BrightScript log/debug session or any other Roku console client, then restart this log viewer.');
      setState('blocked');
      if (rokuSocket !== null) rokuSocket.destroy();
      return;
    }

    addLogLine(line);
  }
}

function scheduleReconnect() {
  if (reconnectBlocked) return;
  if (reconnectTimer !== undefined) return;

  setState('reconnecting');
  reconnectTimer = setTimeout(() => {
    reconnectTimer = undefined;
    connectRoku();
  }, reconnectDelayMs);
}

function connectRoku() {
  if (rokuSocket !== null) {
    rokuSocket.destroy();
    rokuSocket = null;
  }

  setState('connecting');
  lineBuffer = '';

  const socket = net.createConnection({
    host: rokuHost,
    port: debugPort
  });

  rokuSocket = socket;

  socket.setEncoding('utf8');

  socket.on('connect', () => {
    setState('connected');
  });

  socket.on('data', handleRokuData);

  socket.on('error', error => {
    addLogLine(`Log viewer connection error: ${error.message}`);
  });

  socket.on('close', () => {
    if (rokuSocket === socket) rokuSocket = null;
    if (reconnectBlocked) return;
    scheduleReconnect();
  });
}

function sendSseHeaders(response) {
  response.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no'
  });
}

function handleEvents(request, response) {
  sendSseHeaders(response);
  response.write(`data: ${JSON.stringify({
    type: 'status',
    state: connectionState
  })}\n\n`);
  response.write(`data: ${JSON.stringify({
    type: 'history',
    entries: history
  })}\n\n`);

  clients.add(response);
  request.on('close', () => {
    clients.delete(response);
  });
}

function createServer() {
  return http.createServer((request, response) => {
    if (request.url === '/events') {
      handleEvents(request, response);
      return;
    }

    if (request.url === '/' || request.url === '/index.html') {
      response.writeHead(200, {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-cache'
      });
      response.end(getHtml());
      return;
    }

    response.writeHead(404, {
      'Content-Type': 'text/plain; charset=utf-8'
    });
    response.end('Not found');
  });
}

async function createServerOnAvailablePort(startPort, attempts) {
  for (let offset = 0; offset < attempts; offset += 1) {
    const port = startPort + offset;
    const server = createServer();

    try {
      await listen(server, port);
      return {
        server,
        port
      };
    } catch (error) {
      server.close();

      if (error.code === 'EADDRINUSE') continue;
      throw error;
    }
  }

  throw new Error(`Log viewer ports ${startPort}-${startPort + attempts - 1} are already in use.`);
}

function listen(server, port) {
  return new Promise((resolve, reject) => {
    const onError = error => {
      server.off('listening', onListening);
      reject(error);
    };

    const onListening = () => {
      server.off('error', onError);
      resolve();
    };

    server.once('error', onError);
    server.once('listening', onListening);
    server.listen(port, '127.0.0.1');
  });
}

function getHtml() {
  return String.raw`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Roku Log Viewer</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #1b1d21;
      --panel: #24272d;
      --panel-strong: #2d3138;
      --border: #3a3f48;
      --text: #e5e7eb;
      --muted: #a8adb7;
      --accent: #8ab4f8;
      --accent-strong: #e5e7eb;
      --green: #42d392;
      --yellow: #ffcc66;
      --red: #ff6b7a;
      --row: #202328;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      min-height: 100vh;
      background: var(--bg);
      color: var(--text);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      letter-spacing: 0;
    }

    .app {
      min-height: 100vh;
      display: grid;
      grid-template-rows: auto 1fr;
    }

    .toolbar {
      position: sticky;
      top: 0;
      z-index: 5;
      display: grid;
      grid-template-columns: minmax(240px, 1fr) auto;
      gap: 18px;
      align-items: center;
      padding: 18px 22px;
      background: rgba(11, 15, 20, 0.92);
      border-bottom: 1px solid var(--border);
      backdrop-filter: blur(16px);
    }

    .brand {
      min-width: 0;
    }

    h1 {
      margin: 0;
      font-size: 19px;
      font-weight: 720;
    }

    .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin-top: 7px;
      color: var(--muted);
      font-size: 13px;
    }

    .status {
      display: inline-flex;
      gap: 7px;
      align-items: center;
    }

    .status-dot {
      width: 9px;
      height: 9px;
      border-radius: 999px;
      background: var(--yellow);
      box-shadow: 0 0 18px currentColor;
    }

    .status.connected .status-dot {
      background: var(--green);
    }

    .status.disconnected .status-dot,
    .status.reconnecting .status-dot {
      background: var(--red);
    }

    .controls {
      display: flex;
      flex-wrap: wrap;
      justify-content: flex-end;
      gap: 10px;
    }

    button,
    label.toggle {
      height: 38px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 0 13px;
      border: 1px solid var(--border);
      border-radius: 7px;
      background: var(--panel);
      color: var(--text);
      font: inherit;
      font-size: 13px;
      cursor: pointer;
    }

    button:hover,
    label.toggle:hover {
      border-color: #3d526d;
      background: var(--panel-strong);
    }

    button.primary {
      border-color: rgba(72, 184, 255, 0.55);
      color: #eaf8ff;
      background: rgba(72, 184, 255, 0.16);
    }

    input[type="checkbox"] {
      accent-color: var(--accent);
    }

    .filter {
      width: 260px;
      height: 38px;
      border: 1px solid var(--border);
      border-radius: 7px;
      padding: 0 12px;
      background: #0c121a;
      color: var(--text);
      font: inherit;
      font-size: 13px;
      outline: none;
    }

    .filter:focus {
      border-color: var(--accent);
      box-shadow: 0 0 0 3px rgba(72, 184, 255, 0.14);
    }

    .viewer {
      min-height: 0;
      padding: 18px 22px 22px;
    }

    .table {
      overflow: hidden;
      min-height: calc(100vh - 128px);
      border: 1px solid var(--border);
      border-radius: 8px;
      background: rgba(16, 23, 33, 0.78);
      box-shadow: 0 24px 80px rgba(0, 0, 0, 0.24);
    }

    .head,
    .row {
      display: grid;
      grid-template-columns: 172px 250px minmax(0, 1fr);
      column-gap: 36px;
      align-items: start;
    }

    .head {
      position: sticky;
      top: 75px;
      z-index: 2;
      background: #151f2d;
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
    }

    .cell {
      min-width: 0;
      padding: 9px 12px;
      border-bottom: 1px solid rgba(38, 51, 69, 0.68);
    }

    .row {
      background: var(--row);
      font-family: "Cascadia Mono", "SFMono-Regular", Consolas, "Liberation Mono", monospace;
      font-size: 17px;
      line-height: 1.45;
    }

    .timestamp {
      color: var(--text);
      white-space: nowrap;
    }

    .message,
    .full {
      color: var(--text);
      overflow-wrap: anywhere;
      white-space: pre-wrap;
    }

    .label-pill {
      display: inline;
      max-width: 100%;
      min-height: 24px;
      align-items: center;
      border: 0;
      border-radius: 0;
      padding: 0;
      background: transparent;
      color: var(--text);
      overflow-wrap: anywhere;
    }

    .span-message {
      grid-column: 2 / 4;
    }

    .full {
      grid-column: 1 / 4;
      color: #d8dee8;
    }

    .empty {
      padding: 48px 20px;
      color: var(--muted);
      text-align: center;
      font-size: 14px;
    }

    @media (max-width: 900px) {
      .toolbar {
        grid-template-columns: 1fr;
      }

      .controls {
        justify-content: flex-start;
      }

      .filter {
        width: min(100%, 420px);
      }

      .head,
      .row {
        grid-template-columns: 142px 180px minmax(0, 1fr);
      }
    }
  </style>
</head>
<body>
  <main class="app">
    <section class="toolbar">
      <div class="brand">
        <h1>Roku Log Viewer</h1>
        <div class="meta">
          <span id="status" class="status"><span class="status-dot"></span><span id="statusText">starting</span></span>
          <span><span id="visibleCount">0</span> shown</span>
          <span><span id="totalCount">0</span> received</span>
        </div>
      </div>
      <div class="controls">
        <input id="filter" class="filter" type="search" placeholder="Filter logs">
        <label class="toggle"><input id="autoScroll" type="checkbox" checked> Auto-scroll</label>
        <button id="pauseButton" class="primary" type="button">Pause</button>
        <button id="clearButton" type="button">Clear</button>
      </div>
    </section>

    <section class="viewer">
      <div class="table">
        <div class="head">
          <div class="cell">Timestamp</div>
          <div class="cell">Label</div>
          <div class="cell">Message</div>
        </div>
        <div id="rows">
          <div class="empty">Waiting for Roku log output...</div>
        </div>
      </div>
    </section>
  </main>

  <script>
    const rowsEl = document.getElementById('rows');
    const filterEl = document.getElementById('filter');
    const pauseButton = document.getElementById('pauseButton');
    const clearButton = document.getElementById('clearButton');
    const autoScrollEl = document.getElementById('autoScroll');
    const statusEl = document.getElementById('status');
    const statusTextEl = document.getElementById('statusText');
    const visibleCountEl = document.getElementById('visibleCount');
    const totalCountEl = document.getElementById('totalCount');

    let entries = [];
    let paused = false;
    let pausedQueue = [];

    function parseLine(raw) {
      const timestampMatch = raw.match(/^(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3})\s*(.*)$/);
      if (!timestampMatch) {
        return {
          timestamp: '',
          label: '',
          message: raw,
          mode: 'full'
        };
      }

      const timestamp = timestampMatch[1];
      const rest = timestampMatch[2] || '';
      const bracketMatch = rest.match(/^\[([^\]]+)\]\s*(.*)$/);
      if (bracketMatch) {
        return {
          timestamp,
          label: bracketMatch[1],
          message: bracketMatch[2] || '',
          mode: 'columns'
        };
      }

      return {
        timestamp,
        label: '',
        message: rest,
        mode: 'timestamp-message'
      };
    }

    function setStatus(state) {
      statusEl.className = 'status ' + state;
      statusTextEl.textContent = state;
    }

    function createCell(className, text) {
      const cell = document.createElement('div');
      cell.className = 'cell ' + className;
      cell.textContent = text;
      return cell;
    }

    function createRow(entry) {
      const parsed = parseLine(entry.raw);
      const row = document.createElement('div');
      row.className = 'row';
      row.dataset.raw = entry.raw.toLowerCase();
      row.title = entry.raw;

      if (parsed.mode === 'full') {
        row.appendChild(createCell('full', parsed.message));
        return row;
      }

      row.appendChild(createCell('timestamp', parsed.timestamp));

      if (parsed.mode === 'timestamp-message') {
        row.appendChild(createCell('message span-message', parsed.message));
        return row;
      }

      const labelCell = createCell('label', '');
      const label = document.createElement('span');
      label.className = 'label-pill';
      label.textContent = parsed.label;
      labelCell.appendChild(label);
      row.appendChild(labelCell);
      row.appendChild(createCell('message', parsed.message));

      return row;
    }

    function render() {
      const filter = filterEl.value.trim().toLowerCase();
      const fragment = document.createDocumentFragment();
      let visible = 0;

      for (const entry of entries) {
        if (filter !== '' && entry.raw.toLowerCase().includes(filter) === false) continue;
        fragment.appendChild(createRow(entry));
        visible += 1;
      }

      rowsEl.replaceChildren(fragment);
      if (visible === 0) {
        const empty = document.createElement('div');
        empty.className = 'empty';
        empty.textContent = entries.length === 0 ? 'Waiting for Roku log output...' : 'No logs match the current filter.';
        rowsEl.appendChild(empty);
      }

      visibleCountEl.textContent = visible.toString();
      totalCountEl.textContent = entries.length.toString();

      if (autoScrollEl.checked) {
        window.scrollTo({
          top: document.body.scrollHeight,
          behavior: 'instant'
        });
      }
    }

    function appendEntry(entry) {
      entries.push(entry);
      render();
    }

    pauseButton.addEventListener('click', () => {
      paused = !paused;
      pauseButton.textContent = paused ? 'Resume' : 'Pause';
      pauseButton.classList.toggle('primary', !paused);

      if (!paused && pausedQueue.length > 0) {
        entries.push(...pausedQueue);
        pausedQueue = [];
        render();
      }
    });

    clearButton.addEventListener('click', () => {
      entries = [];
      pausedQueue = [];
      render();
    });

    filterEl.addEventListener('input', render);
    autoScrollEl.addEventListener('change', render);

    const events = new EventSource('/events');
    events.onmessage = event => {
      const payload = JSON.parse(event.data);
      if (payload.type === 'status') {
        setStatus(payload.state);
        return;
      }

      if (payload.type === 'history') {
        entries = payload.entries || [];
        render();
        return;
      }

      if (payload.type === 'log') {
        if (paused) {
          pausedQueue.push(payload.entry);
        } else {
          appendEntry(payload.entry);
        }
      }
    };

    events.onerror = () => {
      setStatus('disconnected');
    };
  </script>
</body>
</html>`;
}

if (logMode === 'socket') {
  const config = await loadConfig();
  rokuHost = config.host;
}

let viewer;
try {
  viewer = await createServerOnAvailablePort(defaultViewerPort, maxViewerPortAttempts);
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

console.log(`Roku log viewer: http://localhost:${viewer.port}`);
if (logMode === 'socket') {
  console.log(`Connecting to Roku debug console at ${rokuHost}:${debugPort}`);
  connectRoku();
} else {
  console.log(`Watching VS Code Roku device log at ${logFilePath}`);
  console.log('Start the Roku Starter Kit VS Code debug configuration to generate the log file.');
  await startFileTail();
}
