import assert from 'node:assert/strict';
import test from 'node:test';
import plugin from '../../rooibos/support/auth-store-factory-plugin.cjs';

test('substitutes the registry factory only in the emitted AuthStore test script', () => {
  const event = { file: { srcPath: 'C:\\dev\\starfin-roku\\source\\store\\AuthStore.bs' }, code: 'section = CreateObject("roRegistrySection", "test")' };
  plugin().afterFileTranspile(event);
  assert.ok(event.code.startsWith('section = AuthStoreTestCreateObject("roRegistrySection", "test")'));
  assert.ok(event.code.includes('function AuthStoreTestCreateObject('));
  assert.ok(event.code.includes('return CreateObject(kind, name)'));
});

test('leaves unrelated scripts unchanged', () => {
  const code = 'node = CreateObject("roSGNode", "Group")';
  const event = { file: { srcPath: 'C:/dev/starfin-roku/source/Other.bs' }, code };
  plugin().afterFileTranspile(event);
  assert.equal(event.code, code);
});
