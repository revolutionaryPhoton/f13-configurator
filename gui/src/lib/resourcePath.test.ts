import { describe, expect, it } from "vitest";
import { resolveBinPaths } from "./resourcePath";

// ---------------------------------------------------------------------------
// resolveBinPaths() — unit tests
// ---------------------------------------------------------------------------
// The test environment has no window.__TAURI__, so the non-Tauri (dev) branch
// is exercised automatically.  Tauri-build-mode behaviour is tested by
// providing a resourceDirOverride that simulates app.path().resource_dir().
// ---------------------------------------------------------------------------

describe("resolveBinPaths() — dev / test mode (no Tauri context)", () => {
  it("returns relative default paths when no override is given", async () => {
    const bins = await resolveBinPaths();
    expect(bins.config).toBe("bin/f13-config");
    expect(bins.stop).toBe("bin/f13-stop");
    expect(bins.reset).toBe("bin/f13-reset");
  });
});

describe("resolveBinPaths() — build mode (resourceDirOverride simulates resource_dir)", () => {
  const macosResourceDir = "/Applications/F13 Configurator.app/Contents/Resources";

  it("prefixes every script with the resource dir", async () => {
    const bins = await resolveBinPaths(macosResourceDir);
    expect(bins.config).toBe(`${macosResourceDir}/bin/f13-config`);
    expect(bins.stop).toBe(`${macosResourceDir}/bin/f13-stop`);
    expect(bins.reset).toBe(`${macosResourceDir}/bin/f13-reset`);
  });

  it("bin/f13-config path ends with the script name", async () => {
    const bins = await resolveBinPaths(macosResourceDir);
    expect(bins.config.endsWith("/bin/f13-config")).toBe(true);
  });

  it("all three scripts are under the same bin sub-directory", async () => {
    const bins = await resolveBinPaths(macosResourceDir);
    for (const p of [bins.config, bins.stop, bins.reset]) {
      expect(p.startsWith(`${macosResourceDir}/bin/`)).toBe(true);
    }
  });

  it("works with the tauri dev-mode target path (macOS debug build)", async () => {
    const devDir = "/Users/maintainer/f13-configurator/gui/src-tauri/target/debug/_up_/Resources";
    const bins = await resolveBinPaths(devDir);
    expect(bins.config).toContain("/bin/f13-config");
    expect(bins.stop).toContain("/bin/f13-stop");
    expect(bins.reset).toContain("/bin/f13-reset");
  });
});
