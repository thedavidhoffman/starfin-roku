import { fileURLToPath } from 'node:url';
import { performance } from 'node:perf_hooks';
import { checkProductionHeaders } from './function-headers.mjs';

const start = performance.now();
const root = fileURLToPath(new URL('../', import.meta.url));
const result = checkProductionHeaders(root);
const violations = result.diagnostics;
for (const item of violations) {
  console.error(`${item.file}:${item.line}: missing or invalid function header for ${item.name}`);
  console.error(item.expected.join('\n'));
}
console.log(`Function headers: ${result.functions} functions in ${result.files} files; ${violations.length} violations (${Math.round(performance.now() - start)} ms).`);
if (violations.length) process.exitCode = 1;
