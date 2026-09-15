import { readdir, stat, readFile, mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

// Temporary investigation tool: preserve near-ending HLS files before cleanup.
const cache = process.argv[2] || 'C:/ProgramData/Jellyfin/Server/cache/transcodes';
const output = path.resolve(process.argv[3] || `out/hls-capture/${new Date().toISOString().replaceAll(':', '-')}`);
const minimumSegment = Number(process.argv[4] ?? 1240);
await mkdir(output, { recursive: true });
const seen = new Map();
let stopping = false;
process.on('SIGINT', () => { stopping = true; });
process.on('SIGTERM', () => { stopping = true; });
console.log(`Capture directory: ${output}`);
console.log(`Watching cache playlists and TS segments numbered ${minimumSegment} or higher. Ctrl+C stops capture.`);
const deadline = Date.now() + 30 * 60 * 1000;
while (!stopping && Date.now() < deadline) {
    for (const name of await readdir(cache)) {
        const segment = name.match(/^[a-f0-9]{32}(\d+)\.ts$/i);
        if (!name.endsWith('.m3u8') && !(segment && Number(segment[1]) >= minimumSegment)) continue;
        try {
            const source = path.join(cache, name);
            const before = await stat(source);
            const signature = `${before.size}:${before.mtimeMs}`;
            if (!before.size || seen.get(name) === signature) continue;
            const bytes = await readFile(source);
            const after = await stat(source);
            if (before.size !== after.size || before.mtimeMs !== after.mtimeMs || bytes.length !== after.size) continue;
            const stamp = new Date().toISOString().replaceAll(':', '-');
            await writeFile(path.join(output, `${stamp}--${name}`), bytes);
            seen.set(name, signature);
            console.log(`${stamp} saved ${name} (${bytes.length} bytes)`);
        } catch (error) {
            if (error.code !== 'ENOENT') console.error(`Cannot capture ${name}: ${error.code || error.message}`);
        }
    }
    await new Promise(resolve => setTimeout(resolve, 100));
}
console.log('Capture stopped. Copies may include intermediate files; compare successive versions before analysis.');
