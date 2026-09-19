import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { checkFunctionHeaders, checkProductionHeaders, newHeaderViolations } from '../../scripts/function-headers.mjs';

function header(name, indent = '') {
  const rule = `${indent}'${'-'.repeat(79 - indent.length)}`;
  return `${rule}\n${indent}' ${name}\n${rule}\n`;
}

test('accepts a named sub with its exact header', () => {
  assert.equal(checkFunctionHeaders(`${header('init')}sub init()\nend sub`, 'example.bs').diagnostics.length, 0);
});

test('accepts indented private functions with BOM and CRLF', () => {
  const source = `\uFEFF${header('calculate', '    ')}    private function calculate() as integer\n    end function`.replaceAll('\n', '\r\n');
  assert.equal(checkFunctionHeaders(source, 'example.bs').diagnostics.length, 0);
});

test('accepts the qualified name of a namespace helper', () => {
  const source = `namespace Number\n${header('Number.ToFloat', '    ')}    function ToFloat()\n    end function\nend namespace`;
  assert.equal(checkFunctionHeaders(source, 'source/Number.bs').diagnostics.length, 0);
});

test('requires qualification for namespace helpers', () => {
  const source = `namespace Number\n${header('ToFloat', '    ')}    function ToFloat()\n    end function\nend namespace`;
  const result = checkFunctionHeaders(source, 'source/Number.bs');
  assert.equal(result.diagnostics.length, 1);
  assert.equal(result.diagnostics[0].expected[1], "    ' Number.ToFloat");
});

test('rejects a header qualified with the wrong namespace', () => {
  const source = `namespace Number\n${header('Other.ToFloat', '    ')}    function ToFloat()\n    end function\nend namespace`;
  assert.equal(checkFunctionHeaders(source, 'source/Number.bs').diagnostics.length, 1);
});

test('uses a full dotted namespace path', () => {
  const source = `namespace Api.Media\n${header('Api.Media.Load', '    ')}    sub Load()\n    end sub\nend namespace`;
  assert.equal(checkFunctionHeaders(source, 'source/example.bs').diagnostics.length, 0);
});

test('restores the outer namespace after a nested namespace ends', () => {
  const source = `namespace Api\nnamespace Media\n${header('Api.Media.Load')}sub Load()\nend sub\nend namespace\n${header('Api.Save')}sub Save()\nend sub\nend namespace`;
  assert.equal(checkFunctionHeaders(source, 'source/example.bs').diagnostics.length, 0);
});

test('does not retain qualification after leaving a namespace', () => {
  const source = `namespace Number\nend namespace\n${header('calculate')}function calculate()\nend function`;
  assert.equal(checkFunctionHeaders(source, 'source/example.bs').diagnostics.length, 0);
});

test('uses declared method names for classes inside namespaces', () => {
  const source = `namespace Tools\nclass Logger\n${header('write', '    ')}    public sub write()\n    end sub\nend class\n${header('Tools.Create')}function Create()\nend function\nend namespace`;
  assert.equal(checkFunctionHeaders(source, 'source/example.bs').diagnostics.length, 0);
});

test('rejects qualification on component-local functions', () => {
  assert.equal(checkFunctionHeaders(`${header('Login.init')}sub init()`, 'components/Login.bs').diagnostics.length, 1);
});

test('reports a missing header with file and declaration line', () => {
  const result = checkFunctionHeaders('\nsub init()\nend sub', 'components/Example.bs');
  assert.equal(result.diagnostics[0].file, 'components/Example.bs');
  assert.equal(result.diagnostics[0].line, 2);
  assert.equal(result.diagnostics[0].name, 'init');
});

test('rejects a header naming a different function', () => {
  assert.equal(checkFunctionHeaders(`${header('oldName')}function newName()`, 'example.bs').diagnostics.length, 1);
});

test('rejects separator lines shorter than column 80', () => {
  assert.equal(checkFunctionHeaders("'---\n' init\n'---\nsub init()", 'example.bs').diagnostics.length, 1);
});

test('rejects a blank line between header and declaration', () => {
  assert.equal(checkFunctionHeaders(`${header('init')}\nsub init()`, 'example.bs').diagnostics.length, 1);
});

test('does not overlook tab-indented declarations', () => {
  assert.equal(checkFunctionHeaders('\tsub init()', 'example.bs').diagnostics.length, 1);
});

test('grandfathers an unchanged legacy header after line numbers shift', () => {
  const original = checkFunctionHeaders('\n\n\nsub legacy()', 'source/legacy.bs').diagnostics;
  const moved = checkFunctionHeaders('\n\n\n\nsub legacy()', 'source/legacy.bs').diagnostics;
  assert.equal(newHeaderViolations(moved, original).length, 0);
});

test('rejects a new missing header in a file with a legacy exception', () => {
  const original = checkFunctionHeaders('sub legacy()', 'source/legacy.bs').diagnostics;
  const changed = checkFunctionHeaders('sub legacy()\nend sub\nsub added()', 'source/legacy.bs').diagnostics;
  assert.deepEqual(newHeaderViolations(changed, original).map(item => item.name), ['added']);
});

test('does not extend a legacy exception to a different file', () => {
  const original = checkFunctionHeaders('sub legacy()', 'source/legacy.bs').diagnostics;
  const copied = checkFunctionHeaders('sub legacy()', 'source/new.bs').diagnostics;
  assert.equal(newHeaderViolations(copied, original).length, 1);
});

test('rejects an altered invalid header on a legacy function', () => {
  const original = checkFunctionHeaders('sub legacy()', 'source/legacy.bs').diagnostics;
  const changed = checkFunctionHeaders("' altered\nsub legacy()", 'source/legacy.bs').diagnostics;
  assert.equal(newHeaderViolations(changed, original).length, 1);
});

test('ignores commented declarations and anonymous callbacks', () => {
  const result = checkFunctionHeaders("' sub ignored()\nrem function ignored()\ncallback = function()\nend function", 'example.bs');
  assert.equal(result.functions, 0);
});

test('includes untracked production files and excludes tests and generated output', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'starfin-headers-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  for (const directory of ['components/nested', 'source', 'tests', 'build', 'out']) {
    fs.mkdirSync(path.join(root, directory), { recursive: true });
  }
  for (const file of ['components/nested/Example.bs', 'source/helper.brs', 'tests/Example.spec.bs', 'build/output.brs', 'out/output.brs']) {
    fs.writeFileSync(path.join(root, file), 'sub missing()\nend sub');
  }
  const result = checkProductionHeaders(root);
  assert.equal(result.files, 2);
  assert.deepEqual(result.diagnostics.map(item => item.file), ['components/nested/Example.bs', 'source/helper.brs']);
});

test('CLI returns failure for violations even when run from another directory', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'starfin-header-cli-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  for (const directory of ['components', 'source', 'scripts']) fs.mkdirSync(path.join(root, directory));
  for (const file of ['function-headers.mjs', 'verify-function-headers.mjs']) {
    fs.copyFileSync(new URL(`../../scripts/${file}`, import.meta.url), path.join(root, 'scripts', file));
  }
  fs.writeFileSync(path.join(root, 'scripts/function-header-baseline.json'), '[]');
  fs.writeFileSync(path.join(root, 'source/example.bs'), 'sub missing()\nend sub');
  const result = spawnSync(process.execPath, [path.join(root, 'scripts/verify-function-headers.mjs')], { cwd: os.tmpdir(), encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /source\/example.bs:1: missing or invalid function header for missing/);
});
