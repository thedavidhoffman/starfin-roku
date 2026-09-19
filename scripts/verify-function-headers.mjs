import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { performance } from 'node:perf_hooks';
import { checkProductionHeaders, newHeaderViolations } from './function-headers.mjs';

const start = performance.now();
const root = fileURLToPath(new URL('../', import.meta.url));
const baseline = JSON.parse(fs.readFileSync(new URL('./function-header-baseline.json', import.meta.url), 'utf8'));
const result = checkProductionHeaders(root);
const violations = newHeaderViolations(result.diagnostics, baseline);
for (const item of violations) {
  console.error(`${item.file}:${item.line}: missing or invalid function header for ${item.name}`);
  console.error(item.expected.join('\n'));
}
console.log(`Function headers: ${result.functions} functions in ${result.files} files; ${violations.length} new violations, ${result.diagnostics.length - violations.length} existing exceptions (${Math.round(performance.now() - start)} ms).`);
if (violations.length) process.exitCode = 1;
