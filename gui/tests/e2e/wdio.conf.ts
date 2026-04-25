/**
 * WebdriverIO configuration for F13 Configurator E2E smoke tests.
 *
 * Prerequisites (run once on macOS):
 *   cargo install tauri-driver
 *   cd gui/tests/e2e && npm install
 *   cargo tauri build --debug   (from gui/)
 *
 * Run:
 *   F13_E2E=1 npm test   (from gui/tests/e2e/)
 */

import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Debug binary produced by `cargo tauri build --debug` from gui/
// On macOS the Tauri binary name matches productName in tauri.conf.json.
const APP_BINARY = path.resolve(
  __dirname,
  "../../src-tauri/target/debug/F13 Configurator"
);

export const config: WebdriverIO.Config = {
  runner: "local",

  // Only run files in this directory; does not affect vitest (src/**).
  specs: [path.join(__dirname, "smoke.spec.ts")],

  maxInstances: 1,

  capabilities: [
    {
      // Empty string — tauri-driver supplies the underlying driver.
      browserName: "",
      maxInstances: 1,
      "tauri:options": {
        application: APP_BINARY,
      },
    },
  ],

  // wdio-tauri-service starts/stops tauri-driver automatically.
  services: [["tauri", {}]],

  framework: "mocha",
  reporters: ["spec"],

  mochaOpts: {
    ui: "bdd",
    // Pipeline steps (especially docker pull + build) can take several minutes.
    timeout: 600_000,
  },
};
