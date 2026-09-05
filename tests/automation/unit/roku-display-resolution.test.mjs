import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildResolutionResultsDirectoryName,
  normalizeDeviceResolution,
  parseDisplayResolution,
  promptForRokuDisplayResolution,
  readVerifiedDeviceResolution,
  supportedDisplayResolutions
} from '../../../scripts/roku-display-resolution.mjs';
import { qualifySuiteTitles } from '../support/report-titles.mjs';

test('validates and maps supported display resolutions', () => {
  assert.equal(parseDisplayResolution([]), undefined);
  assert.equal(parseDisplayResolution(['--resolution', '1080p']), '1080p');
  assert.equal(parseDisplayResolution(['--resolution', '720p']), '720p');
  assert.equal(supportedDisplayResolutions['1080p'].rtaResolution, 'fhd');
  assert.equal(supportedDisplayResolutions['720p'].rtaResolution, 'hd');
  assert.throws(() => parseDisplayResolution(['--resolution', '4k']));
});

test('qualifies resolution-specific result directories without changing normal runs', () => {
  const runId = '2026-09-05T12-04-07-670Z';
  assert.equal(buildResolutionResultsDirectoryName(runId), runId);
  assert.equal(
    buildResolutionResultsDirectoryName(runId, '1080p'),
    '2026-09-05T12-04-07-670Z (1080p)'
  );
  assert.equal(
    buildResolutionResultsDirectoryName(runId, '720p'),
    '2026-09-05T12-04-07-670Z (720p)'
  );
});

test('normalizes and verifies Roku device resolution values', async () => {
  assert.equal(normalizeDeviceResolution('FHD'), '1080p');
  assert.equal(normalizeDeviceResolution('HD'), '720p');
  const client = { queryDeviceInfo: async () => ({ uiResolution: '1080p', modelNumber: '4630X' }) };
  assert.equal((await readVerifiedDeviceResolution(client, '1080p')).info.modelNumber, '4630X');
  await assert.rejects(readVerifiedDeviceResolution(client, '720p'), /expected 720p/);
});

test('does not prompt when the requested mode is already active', async () => {
  let prompts = 0;
  const client = {
    queryDeviceInfo: async () => ({ uiResolution: '720p' })
  };
  await promptForRokuDisplayResolution(client, '720p', async () => { prompts += 1; });
  assert.equal(prompts, 0);
});

test('prompts again until Roku reports the requested display mode', async () => {
  const resolutions = ['1080p', '1080p', '1080p', '720p'];
  let prompts = 0;
  const client = {
    queryDeviceInfo: async () => ({ uiResolution: resolutions.shift() })
  };
  await promptForRokuDisplayResolution(client, '720p', async () => { prompts += 1; });
  assert.equal(prompts, 2);
});

test('qualifies suite titles without changing test titles or duplicating qualifiers', () => {
  const testCase = { title: 'signs in' };
  const nested = { title: 'Nested context', suites: [] };
  const suite = { title: 'Starfin authenticated smoke test', suites: [nested], tests: [testCase] };
  const root = { suites: [suite] };

  qualifySuiteTitles(root, '1080p');
  qualifySuiteTitles(root, '1080p');

  assert.equal(suite.title, 'Starfin authenticated smoke test (1080p)');
  assert.equal(nested.title, 'Nested context (1080p)');
  assert.equal(testCase.title, 'signs in');
});
