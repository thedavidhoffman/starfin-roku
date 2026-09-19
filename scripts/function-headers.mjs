import fs from 'node:fs';
import path from 'node:path';

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
    let headerEnd = index;
    if (!matchesHeader(lines, headerEnd, expected) && lines[index - 1] === rule) {
      // An optional example section sits between the header and its closing separator.
      let cursor = index - 2;
      while (cursor >= 0 && lines[cursor] !== rule &&
        (lines[cursor] === `${indent}'` || lines[cursor].startsWith(`${indent}' `))) cursor--;
      if (cursor < index - 2 && lines[cursor + 1].startsWith(`${indent}' Example:`)) {
        headerEnd = cursor + 1;
      }
    }
    if (indent.includes('\t') || !matchesHeader(lines, headerEnd, expected)) {
      diagnostics.push({ file, line: index + 1, name, expected });
    }
  }
  return { functions, diagnostics };
}

function matchesHeader(lines, end, expected) {
  return end >= expected.length && expected.every((line, offset) => lines[end - expected.length + offset] === line);
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
