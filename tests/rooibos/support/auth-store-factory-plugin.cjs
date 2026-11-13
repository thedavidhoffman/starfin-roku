const fs = require('node:fs');
const path = require('node:path');
const factory = fs.readFileSync(path.join(__dirname, 'AuthStoreRegistry.brs'), 'utf8');

// Test-build-only substitution in the emitted AuthStore script. Appending the
// factory here keeps it in every component scope that imports AuthStore without
// changing production imports, interfaces, or non-test build configurations.
module.exports = () => ({
  name: 'auth-store-registry-fault-injection',
  afterFileTranspile(event) {
    const sourcePath = event.file.srcPath.replace(/\\/g, '/');
    if (!sourcePath.endsWith('/source/store/AuthStore.bs')) return;
    event.code = event.code.replace(/\bCreateObject\s*\(/gi, 'AuthStoreTestCreateObject(') + '\n' + factory;
  }
});
