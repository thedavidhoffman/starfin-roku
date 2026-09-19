import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';

export function checkFunctionHeaders(text, file) {
  const lines = text.replace(/^\uFEFF/, '').split(/\r?\n/);
  const diagnostics = [];
  const namespaces = [];
  let classDepth = 0;
  let functions = 0;
  for (let index = 0; index < lines.length; index++) {
    const namespace = /^\s*namespace\s+([a-z_]\w*(?:\.[a-z_]\w*)*)\b/i.exec(lines[index]);
    if (namespace) namespaces.push(namespace[1]);
    if (/^\s*end\s+namespace\b/i.test(lines[index])) namespaces.pop();
    if (/^\s*class\s+[a-z_]\w*\b/i.test(lines[index])) classDepth++;
    if (/^\s*end\s+class\b/i.test(lines[index])) classDepth--;
    const declaration = /^([ \t]*)(?:(?:public|private|protected|override)\s+)*(?:sub|function)\s+([a-z_]\w*)\s*\(/i.exec(lines[index]);
    if (!declaration) continue;
    functions++;
    const [, indent, name] = declaration;
    const headerName = namespaces.length && classDepth === 0 ? `${namespaces.join('.')}.${name}` : name;
    const rule = `${indent}'${'-'.repeat(Math.max(1, 79 - indent.length))}`;
    const expected = [rule, `${indent}' ${headerName}`, rule];
    const actual = lines.slice(Math.max(0, index - 3), index);
    if (indent.includes('\t') || actual.length !== 3 || expected.some((line, offset) => line !== actual[offset])) {
      // Bind a legacy exception to its existing header and declaration, not its line number.
      const fingerprint = createHash('sha256').update(JSON.stringify([...actual, lines[index]])).digest('hex');
      diagnostics.push({ file, line: index + 1, name, expected, fingerprint });
    }
  }
  return { functions, diagnostics };
}

export function checkProductionHeaders(root) {
  const diagnostics = [];
  let files = 0;
  let functions = 0;
  function visit(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const fullPath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        visit(fullPath);
      } else if (entry.isFile() && /\.(bs|brs)$/i.test(entry.name)) {
        const file = path.relative(root, fullPath).split(path.sep).join('/');
        const result = checkFunctionHeaders(fs.readFileSync(fullPath, 'utf8'), file);
        files++;
        functions += result.functions;
        diagnostics.push(...result.diagnostics);
      }
    }
  }
  for (const directory of ['components', 'source']) visit(path.join(root, directory));
  return { files, functions, diagnostics };
}

export function newHeaderViolations(diagnostics, baseline) {
  const counts = new Map();
  const key = item => JSON.stringify([item.file, item.name, item.fingerprint]);
  for (const item of baseline) counts.set(key(item), (counts.get(key(item)) ?? 0) + 1);
  return diagnostics.filter(item => {
    const remaining = counts.get(key(item)) ?? 0;
    if (!remaining) return true;
    counts.set(key(item), remaining - 1);
    return false;
  });
}
