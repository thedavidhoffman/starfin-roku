import path from "node:path";
import { createRequire } from "node:module";

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

await import("rooibos-roku/dist/cli.js");
