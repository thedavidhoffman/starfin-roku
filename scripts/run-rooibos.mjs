import path from "node:path";
import { createRequire } from "node:module";
import fs from "node:fs";
import { startHttpFixture } from "./rooibos-http-fixture.mjs";

const require = createRequire(import.meta.url);
const { RokuDeploy } = require("rooibos-roku/node_modules/roku-deploy");
const { TelnetAdapter } = require("roku-debug");
const getOutputZipFilePath = RokuDeploy.prototype.getOutputZipFilePath;
const publish = RokuDeploy.prototype.publish;
const addTelnetListener = TelnetAdapter.prototype.on;
let deploymentComplete = false;

RokuDeploy.prototype.getOutputZipFilePath = function (options) {
  const resolvedOptions = this.getOptions(options);
  if (path.isAbsolute(resolvedOptions.outFile)) {
    return resolvedOptions.outFile;
  }

  return getOutputZipFilePath.call(this, options);
};

RokuDeploy.prototype.publish = async function (options) {
  const result = await publish.call(this, options);
  deploymentComplete = true;
  return result;
};

TelnetAdapter.prototype.on = function (eventName, listener) {
  if (eventName !== "app-exit") {
    return addTelnetListener.call(this, eventName, listener);
  }

  return addTelnetListener.call(this, eventName, (...args) => {
    if (deploymentComplete) listener(...args);
  });
};

const hostArgument = process.argv.find(argument => argument.startsWith('--host='));
const hostIndex = process.argv.indexOf('--host');
const fixtureHost = hostArgument?.slice('--host='.length) ?? (hostIndex >= 0 ? process.argv[hostIndex + 1] : undefined);
if (fixtureHost && !process.argv.includes('--help')) {
  const fixture = await startHttpFixture(fixtureHost);
  const fixtureDirectory = path.resolve('build/rooibos-fixtures');
  const fixtureConfig = path.join(fixtureDirectory, 'http-fixture.json');
  fs.mkdirSync(fixtureDirectory, { recursive: true });
  fs.writeFileSync(fixtureConfig, JSON.stringify(fixture.config));
  process.once('exit', () => {
    fixture.server.closeAllConnections();
    fixture.server.close();
    fs.writeFileSync(path.join(fixtureDirectory, 'http-requests.json'), JSON.stringify(fixture.requests, null, 2));
    fs.rmSync(fixtureConfig, { force: true });
    console.log(`HTTP fixture: ${fixture.requests.length} request(s), ${fixture.requests.filter(request => request.accepted).length} authenticated.`);
  });
  for (const [signal, code] of [['SIGINT', 130], ['SIGTERM', 143]]) {
    process.once(signal, () => process.exit(code));
  }
}

await import("rooibos-roku/dist/cli.js");
