export const supportedDisplayResolutions = Object.freeze({
  '720p': { rtaResolution: 'hd', screenshot: { width: 1280, height: 720 } },
  '1080p': { rtaResolution: 'fhd', screenshot: { width: 1920, height: 1080 } }
});

export function parseDisplayResolution(args = process.argv.slice(2)) {
  const index = args.indexOf('--resolution');
  if (index < 0) return undefined;
  const resolution = args[index + 1];
  if (!supportedDisplayResolutions[resolution]) {
    throw new Error('--resolution must be either 1080p or 720p.');
  }
  return resolution;
}

export function normalizeDeviceResolution(value) {
  const normalized = String(value ?? '').trim().toLowerCase();
  if (normalized === '1080p' || normalized === 'fhd') return '1080p';
  if (normalized === '720p' || normalized === 'hd') return '720p';
  return normalized;
}

export function buildResolutionResultsDirectoryName(runId, resolution) {
  return resolution ? `${runId} (${resolution})` : runId;
}

export async function readVerifiedDeviceResolution(client, expectedResolution) {
  const info = await client.queryDeviceInfo();
  const actualResolution = normalizeDeviceResolution(info.uiResolution);
  if (expectedResolution && actualResolution !== expectedResolution) {
    throw new Error(`Roku display resolution is ${actualResolution || 'unknown'}; expected ${expectedResolution}.`);
  }
  return { actualResolution, info };
}

export async function promptForRokuDisplayResolution(client, targetResolution, ask) {
  if (!supportedDisplayResolutions[targetResolution]) {
    throw new Error(`Unsupported display resolution: ${targetResolution}.`);
  }

  while (true) {
    const current = await readVerifiedDeviceResolution(client);
    if (current.actualResolution === targetResolution) return current.info;

    await ask(
      `Set the Roku display type to ${targetResolution}, confirm the change on the TV, then press Enter to verify: `
    );
    const verified = await readVerifiedDeviceResolution(client);
    if (verified.actualResolution === targetResolution) return verified.info;
    console.warn(`Roku still reports ${verified.actualResolution || 'an unknown resolution'}; ${targetResolution} is required.`);
  }
}
