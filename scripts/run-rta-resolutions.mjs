import path from 'node:path';
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline/promises';
import dotenv from 'dotenv';
import { EcpClient } from '@danecodes/roku-ecp';
import { promptForRokuDisplayResolution, readVerifiedDeviceResolution } from './roku-display-resolution.mjs';

const rootDir = process.cwd();
const environmentPath = path.join(rootDir, 'tests', 'automation', '.env.automation');

function runResolution(resolution) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [path.join(rootDir, 'scripts', 'run-rta.mjs'), '--release-report', '--resolution', resolution], {
      cwd: rootDir,
      stdio: 'inherit',
      shell: false
    });
    child.once('error', reject);
    child.once('exit', code => code === 0 ? resolve() : reject(new Error(`${resolution} RTA run exited with code ${code ?? 'unknown'}.`)));
  });
}

let workflowError;
let restorationError;
let prompts;
try {
  const parsed = dotenv.config({ path: environmentPath, quiet: true });
  if (parsed.error) throw new Error('Missing tests/automation/.env.automation.');
  const host = process.env.ROKU_HOST?.trim();
  if (!host) throw new Error('tests/automation/.env.automation must define ROKU_HOST.');
  const client = new EcpClient(host, { timeout: 15000, keyCooldown: 250 });
  prompts = createInterface({ input: process.stdin, output: process.stdout });
  const ask = prompt => prompts.question(prompt);

  try {
    for (const resolution of ['1080p', '720p']) {
      console.log(`Preparing Roku ${resolution} display mode...`);
      await promptForRokuDisplayResolution(client, resolution, ask);
      await readVerifiedDeviceResolution(client, resolution);
      await runResolution(resolution);
    }
  } catch (error) {
    workflowError = error;
  } finally {
    try {
      console.log('Restoring Roku 1080p display mode...');
      await promptForRokuDisplayResolution(client, '1080p', ask);
      await readVerifiedDeviceResolution(client, '1080p');
    } catch (error) {
      restorationError = error;
    }
  }
} catch (error) {
  workflowError = error;
} finally {
  prompts?.close();
}

if (workflowError) console.error(`Dual-resolution automation failed: ${workflowError.message}`);
if (restorationError) console.error(`Roku 1080p restoration failed: ${restorationError.message}`);
if (workflowError || restorationError) process.exitCode = 1;
