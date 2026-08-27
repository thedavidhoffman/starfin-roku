import fs from 'node:fs/promises';
import path from 'node:path';

const manifestPath = path.join(process.cwd(), 'manifest');
const manifest = await fs.readFile(manifestPath, 'utf8');

const match = manifest.match(/^build_version=(\d+)$/m);
if (!match) {
  console.error('Unable to find build_version in manifest.');
  process.exit(1);
}

const currentBuildVersion = Number.parseInt(match[1], 10);
if (!Number.isSafeInteger(currentBuildVersion)) {
  console.error(`Invalid build_version in manifest: ${match[1]}`);
  process.exit(1);
}

const nextBuildVersion = currentBuildVersion + 1;
const updatedManifest = manifest.replace(
  /^build_version=\d+$/m,
  `build_version=${nextBuildVersion}`
);

await fs.writeFile(manifestPath, updatedManifest, 'utf8');
console.log(`Incremented build version (${currentBuildVersion} -> ${nextBuildVersion})`);
