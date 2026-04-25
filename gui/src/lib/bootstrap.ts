// Wires the production engine: asks the Rust side for the absolute bin/ path,
// constructs the engine with a Tauri-shell-backed ProcessRunner, and registers
// it via setEngine() so getEngine() returns a working instance.
//
// Called once on app start from +layout.svelte. Idempotent.

import { invoke } from "@tauri-apps/api/core";
import { type BinPaths, createEngine } from "./engine.js";
import { setEngine } from "./engineContext.js";
import { createTauriRunner } from "./tauriRunner.js";

let bootstrapped = false;

export async function bootstrapEngine(): Promise<void> {
  if (bootstrapped) return;
  bootstrapped = true;

  try {
    const binDir = await invoke<string>("get_bin_dir");
    const bins: BinPaths = {
      config: `${binDir}/f13-config`,
      stop: `${binDir}/f13-stop`,
      reset: `${binDir}/f13-reset`,
    };
    const engine = createEngine(createTauriRunner(), bins);
    setEngine(engine);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error("[bootstrap] failed to wire engine:", err);
    // Leave engine unset; UI components fall back to a "no engine" state
    // (preflight stops streaming, etc.) rather than crashing.
    bootstrapped = false;
  }
}
