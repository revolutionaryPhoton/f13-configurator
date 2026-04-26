// Wires the production engine: asks the Rust side for the absolute bin/ path,
// constructs the engine with a Tauri-shell-backed ProcessRunner, and registers
// it via setEngine() so getEngine() returns a working instance.
//
// Also resolves the absolute generated/ path (mirrors the shell wizard's
// default) so wizard pages don't fall back to a relative "./generated"
// against Tauri's CWD (which lands in target/debug/).
//
// Called once on app start from +layout.svelte. Idempotent.

import { invoke } from "@tauri-apps/api/core";
import { type BinPaths, createEngine } from "./engine.js";
import { setEngine } from "./engineContext.js";
import { createTauriRunner } from "./tauriRunner.js";

let bootstrapped = false;
let _generatedDir: string | null = null;

/**
 * Absolute path to the configurator's `generated/` directory, populated
 * once at app start by `bootstrapEngine()`. Returns null until bootstrap
 * has run successfully — callers should fall back to "./generated" only
 * when this is null AND no other source of truth exists (e.g. tests).
 */
export function getGeneratedDir(): string | null {
  return _generatedDir;
}

export async function bootstrapEngine(): Promise<void> {
  if (bootstrapped) return;
  bootstrapped = true;

  try {
    const [binDir, generatedDir] = await Promise.all([
      invoke<string>("get_bin_dir"),
      invoke<string>("get_generated_dir"),
    ]);
    _generatedDir = generatedDir;
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
    _generatedDir = null;
    bootstrapped = false;
  }
}
