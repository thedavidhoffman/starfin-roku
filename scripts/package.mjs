import fs from 'node:fs/promises';
import path from 'node:path';
import rokuDeploy from 'roku-deploy';

const rootDir = process.cwd();
const outDir = path.join(rootDir, 'out');
const stagingDir = path.join(rootDir, 'build', 'staging');
const manifestPath = path.join(rootDir, 'manifest');

const files = [
  'components/**/*',
  'images/**/*',
  'source/**/*',
  'manifest'
];

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

await fs.mkdir(outDir, { recursive: true });

await rokuDeploy.prepublishToStaging({
  rootDir,
  stagingDir,
  files
});

await rokuDeploy.zipPackage({
  stagingDir,
  outDir,
  outFile
});

console.log(`Created package: ${path.join(outDir, `${outFile}.zip`)}`);
