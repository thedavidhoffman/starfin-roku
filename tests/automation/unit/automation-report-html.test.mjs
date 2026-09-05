import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { enhanceAutomationReport } from '../../../scripts/automation-report-html.mjs';

async function createReport() {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'starfin-report-html-'));
  const reportPath = path.join(tempDir, 'report.html');
  await fs.writeFile(reportPath, '<html><head></head><body><div id="report"></div></body></html>');
  return { reportPath, tempDir };
}

test('adds the visibility toggle and preserves screenshot link enhancement', async t => {
  const { reportPath, tempDir } = await createReport();
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }));

  assert.equal(await enhanceAutomationReport(reportPath), true);

  const html = await fs.readFile(reportPath, 'utf8');
  assert.match(html, /starfin-expand-toggle/);
  assert.match(html, /Expand All/);
  assert.match(html, /Collapse All/);
  assert.match(html, /aria-expanded/);
  assert.match(html, /#report details\[class\*="test--details"\]/);
  assert.match(html, /top: -3px/);
  assert.match(html, /quick-summary--list/);
  assert.match(html, /quickSummary\.insertBefore\(button, quickSummaryList\)/);
  assert.match(html, /new MutationObserver/);
  assert.match(html, /textNode\.replaceWith\(link\)/);

  const injectedScript = html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
  assert.ok(injectedScript, 'The report enhancement script should be present.');
  assert.doesNotThrow(() => new Function(injectedScript), injectedScript);

  let loadHandler;
  let insertedButton;
  const buttonListeners = {};
  const details = [{ open: false }, { open: false }];
  const suiteDetails = { open: true };
  const quickSummary = {
    closest: () => quickSummary,
    insertBefore(button) {
      insertedButton = button;
    },
    parentNode: {}
  };
  const report = { addEventListener() {} };
  const document = {
    body: {},
    createElement: () => ({
      addEventListener(eventName, handler) {
        buttonListeners[eventName] = handler;
      },
      setAttribute(name, value) {
        this[name] = value;
      }
    }),
    createTreeWalker: () => ({ nextNode: () => false }),
    querySelector(selector) {
      if (selector === '.starfin-expand-toggle') return insertedButton;
      if (selector === '[class*="quick-summary--list"]') return quickSummary;
      if (selector === '#report') return report;
      return undefined;
    },
    querySelectorAll: selector => selector === '#report details[class*="test--details"]'
      ? details
      : [suiteDetails]
  };
  const window = {
    addEventListener(eventName, handler) {
      if (eventName === 'load') loadHandler = handler;
    }
  };

  new Function('window', 'document', 'NodeFilter', 'MutationObserver', 'setTimeout', injectedScript)(
    window,
    document,
    { SHOW_TEXT: 4 },
    class {},
    handler => handler()
  );
  loadHandler();

  assert.equal(insertedButton.textContent, 'Expand All');
  buttonListeners.click();
  assert.deepEqual(details.map(detail => detail.open), [true, true]);
  assert.equal(insertedButton.textContent, 'Collapse All');
  buttonListeners.click();
  assert.deepEqual(details.map(detail => detail.open), [false, false]);
  assert.equal(suiteDetails.open, true, 'Suite details should remain expanded.');
  assert.equal(insertedButton.textContent, 'Expand All');
});

test('does not duplicate report enhancements', async t => {
  const { reportPath, tempDir } = await createReport();
  t.after(() => fs.rm(tempDir, { recursive: true, force: true }));

  assert.equal(await enhanceAutomationReport(reportPath), true);
  assert.equal(await enhanceAutomationReport(reportPath), false);

  const html = await fs.readFile(reportPath, 'utf8');
  assert.equal(html.match(/id="starfin-report-enhancements-v3"/g)?.length, 1);
});
