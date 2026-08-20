import fs from 'node:fs/promises';
import path from 'node:path';

const rootDir = process.cwd();
const outDir = path.join(rootDir, 'out');
const manifestPath = path.join(rootDir, 'manifest');
const compilerPackagePath = path.join(outDir, 'starfin-roku.zip');

function getManifestValue(manifest, key) {
  const match = manifest.match(new RegExp(`^${key}=(\\d+)$`, 'm'));
  if (!match) {
    throw new Error(`Unable to find ${key} in manifest.`);
  }

  return match[1];
}

const manifest = await fs.readFile(manifestPath, 'utf8');
const majorVersion = getManifestValue(manifest, 'major_version');
const minorVersion = getManifestValue(manifest, 'minor_version');
const buildVersion = getManifestValue(manifest, 'build_version');
const outFile = `starfin.${majorVersion}.${minorVersion}.${buildVersion}`;
const packagePath = path.join(outDir, `${outFile}.zip`);

await fs.mkdir(outDir, { recursive: true });
await fs.copyFile(compilerPackagePath, packagePath);

console.log(`Created package: ${packagePath}`);
