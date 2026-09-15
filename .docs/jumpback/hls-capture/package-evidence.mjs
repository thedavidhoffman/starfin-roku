import fs from 'node:fs/promises';
import path from 'node:path';
import { createWriteStream } from 'node:fs';
import { finished } from 'node:stream/promises';
import yazl from 'yazl';

const root = path.resolve('out/hls-capture');
const capture = path.join(root, '2026-09-11T18-54-00.612Z');
const destination = path.join(root, 'official-roku-evidence');
await fs.mkdir(destination, { recursive: true });
const prefix = '7e6ad766012374ef0181d7de51435e01';
const entries = [];
async function save(name, text) {
    await fs.writeFile(path.join(destination, name), text);
    entries.push(name);
}
function sanitize(text) {
    return text.replaceAll(prefix, 'segment-')
        .replace(/D:\\+Jellyfin Media Library\\+movies\\+20,000 Leagues Under the Sea\\+20,000 Leagues Under the Sea\.mp4/g, 'sample.mp4')
        .replace(/C:\\+ProgramData\\+Jellyfin\\+Server\\+cache\\+transcodes\\+/g, 'cache/')
        .replaceAll('20,000 Leagues Under the Sea', 'sample')
        .replaceAll('d941a3f9dc58ff8df8891da51dfba9d9', 'REDACTED_ITEM_ID')
        .replaceAll('a7455a3b39126009d1e3da6941e088e5', 'REDACTED_ETAG');
}
for (const name of (await fs.readdir(capture)).sort()) {
    if (name.endsWith('.log')) {
        const stamp = name.match(/2026-09-11_(\d\d-\d\d-\d\d)/)[1];
        await save(`ffmpeg-${stamp}.log`, sanitize(await fs.readFile(path.join(capture, name), 'utf8')));
    } else if (name.endsWith('.m3u8')) {
        await save(name.replace(prefix, 'segment-'), sanitize(await fs.readFile(path.join(capture, name), 'utf8')));
    } else if (/^packets-\d+\.json$/.test(name)) {
        await save(name, await fs.readFile(path.join(capture, name), 'utf8'));
    }
}
const comparisons = [];
for (const [earlier, later] of [[1260,1265],[1261,1266],[1262,1267],[1263,1268],[1264,1269],[1263,1270],[1264,1271]]) {
    const a = JSON.parse(await fs.readFile(path.join(destination, `packets-${earlier}.json`), 'utf8')).packets;
    const b = JSON.parse(await fs.readFile(path.join(destination, `packets-${later}.json`), 'utf8')).packets;
    const payloadsMatch = a.length === b.length && a.every((packet, i) => packet.data_hash === b[i].data_hash);
    const ptsMatch = a.length === b.length && a.every((packet, i) => packet.pts_time === b[i].pts_time);
    if (!payloadsMatch || !ptsMatch) throw new Error(`Comparison failed: ${earlier}/${later}`);
    comparisons.push({ earlier, later, packets: a.length, allOrderedPayloadHashesMatch: payloadsMatch, allPresentationTimestampsMatch: ptsMatch });
}
await save('packet-comparisons.json', JSON.stringify(comparisons, null, 2));
await save('bug-report.md', sanitize(await fs.readFile(path.join(root, 'jellyfin-bug-report.md'), 'utf8')));
await save('README.txt', `Official Jellyfin Roku reproduction, September 11, 2026.

Includes four FFmpeg logs, three timestamped FFmpeg cache playlist snapshots,
twelve video packet reports, verified comparison results, and the issue draft.
Capture filename timestamps are UTC; FFmpeg log filename times are EDT.

Paths, media title, item ID, ETag and output prefix were replaced with stable
placeholders. Packet SHA256 hashes, timestamps and durations are unchanged.
segment-N.ts in a playlist refers to segment number N; raw TS/media files are
not included. Cache playlists are NOT the HTTP playlists delivered to Roku.
Packet reports contain hashes and timing metadata, not encoded video payloads.

Compare packets-N.json arrays in order using data_hash and pts_time. All seven
pairs in packet-comparisons.json matched for every video packet and PTS.
Raw files and unmodified logs are preserved privately outside this archive.
The report still identifies unknown environment versions and evidence limits.
`);
for (const name of entries) {
    const text = await fs.readFile(path.join(destination, name), 'utf8');
    if (/starfin|moonfin|D:\\|C:\\|20,000 Leagues|d941a3f9|a7455a3b|7e6ad766|(?:api_key|apikey|token|password)=/i.test(text)) throw new Error(`Sanitization check failed: ${name}`);
    if (/\b(?:10\.10\.10\.\d+|192\.168\.\d+\.\d+)\b/.test(text)) throw new Error(`Private IP found: ${name}`);
}
const archive = path.join(root, 'jellyfin-12-official-roku-hls-replay-evidence.zip');
const zip = new yazl.ZipFile();
for (const name of entries) zip.addFile(path.join(destination, name), name);
const output = createWriteStream(archive);
zip.outputStream.pipe(output);
zip.end();
await finished(output);
console.log(JSON.stringify({ archive, entries: entries.length, bytes: (await fs.stat(archive)).size, comparisons: comparisons.length }));
