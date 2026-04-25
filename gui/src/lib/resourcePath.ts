/**
 * Resolves shell-script bin paths from the Tauri resource directory.
 *
 * In a packaged Tauri build the shell scripts live inside the app bundle at
 * {resourceDir}/bin/. In dev / test environments (no window.__TAURI__)
 * they are resolved as plain relative paths from the project root.
 */
import type { BinPaths } from "./engine";

declare const window: Window & { __TAURI__?: unknown };

function isTauriContext(): boolean {
  return typeof window !== "undefined" && "__TAURI__" in window;
}

/**
 * Returns BinPaths with fully-resolved script locations.
 *
 * @param resourceDirOverride Inject an absolute resource dir for tests or when
 *   the caller has already resolved `resourceDir()` via Tauri APIs.  When
 *   omitted, detection is automatic.
 */
export async function resolveBinPaths(resourceDirOverride?: string): Promise<BinPaths> {
  let dir: string | undefined = resourceDirOverride;

  if (dir === undefined && isTauriContext()) {
    const { resourceDir } = await import("@tauri-apps/api/path");
    dir = await resourceDir();
  }

  if (dir !== undefined) {
    return {
      config: `${dir}/bin/f13-config`,
      stop: `${dir}/bin/f13-stop`,
      reset: `${dir}/bin/f13-reset`,
    };
  }

  // Dev / test environment: relative to the shell project root.
  return {
    config: "bin/f13-config",
    stop: "bin/f13-stop",
    reset: "bin/f13-reset",
  };
}
