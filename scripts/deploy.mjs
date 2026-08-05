import fs from 'node:fs/promises';
import path from 'node:path';
import rokuDeploy from 'roku-deploy';

const rootDir = process.cwd();
const configPath = path.join(rootDir, 'rokudeploy.json');
const outDir = path.join(rootDir, 'out');
const outFile = 'starfin';
const stagingDir = path.join(rootDir, 'build', 'staging');

const files = [
  'components/**/*',
  'images/**/*',
  'source/**/*',
  'manifest'
];

let rawConfig;
try {
  rawConfig = await fs.readFile(configPath, 'utf8');
} catch (error) {
  console.error('Missing rokudeploy.json. Copy rokudeploy.example.json to rokudeploy.json and fill in your Roku device details.');
  process.exit(1);
}

const config = JSON.parse(rawConfig);

if (!config.host || !config.password) {
  console.error('rokudeploy.json must include "host" and "password".');
  process.exit(1);
}

await rokuDeploy.deploy({
  ...config,
  rootDir,
  outDir,
  outFile,
  stagingDir,
  files
});

console.log(`Deployed ${outFile} to Roku device at ${config.host}`);
