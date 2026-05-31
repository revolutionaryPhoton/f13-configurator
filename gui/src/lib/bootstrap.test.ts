import { beforeEach, describe, expect, it, vi } from "vitest";

// Hoist mock factories — vi.mock() calls are hoisted so the factories run
// before any import.  The explicit factory shapes mirror what bootstrap.ts
// actually uses from each module.
vi.mock("@tauri-apps/api/core", () => ({ invoke: vi.fn() }));
vi.mock("./tauriRunner.js", () => ({ createTauriRunner: vi.fn(() => ({})) }));
vi.mock("./engineContext.js", () => ({ setEngine: vi.fn() }));
vi.mock("./engine.js", () => ({ createEngine: vi.fn(() => ({})) }));

// Reset module registry before every test so each test gets a fresh module
// instance with its own module-level `bootstrapped` and `_generatedDir`.
beforeEach(() => {
  vi.resetModules();
  vi.resetAllMocks();
});

describe("getGeneratedDir()", () => {
  it("returns null before bootstrapEngine() is called", async () => {
    const { getGeneratedDir } = await import("./bootstrap.js");
    expect(getGeneratedDir()).toBeNull();
  });

  it("returns the path from invoke('get_generated_dir') after bootstrap", async () => {
    const { invoke } = await import("@tauri-apps/api/core");
    const appLocalPath =
      "/Users/alice/Library/Application Support/de.f13-os.configurator/generated";
    vi.mocked(invoke)
      .mockResolvedValueOnce("/Applications/F13 Configurator.app/Contents/Resources/bin")
      .mockResolvedValueOnce(appLocalPath);

    const { bootstrapEngine, getGeneratedDir } = await import("./bootstrap.js");
    await bootstrapEngine();

    expect(getGeneratedDir()).toBe(appLocalPath);
  });

  it("returns null when invoke() rejects (Tauri IPC unavailable)", async () => {
    const { invoke } = await import("@tauri-apps/api/core");
    vi.mocked(invoke).mockRejectedValue(new Error("tauri IPC not available"));

    const { bootstrapEngine, getGeneratedDir } = await import("./bootstrap.js");
    await bootstrapEngine();

    expect(getGeneratedDir()).toBeNull();
  });
});

describe("bootstrapEngine()", () => {
  it("is idempotent — second call skips invoke", async () => {
    const { invoke } = await import("@tauri-apps/api/core");
    vi.mocked(invoke)
      .mockResolvedValueOnce("/bundled/bin")
      .mockResolvedValueOnce("/bundled/generated");

    const { bootstrapEngine } = await import("./bootstrap.js");
    await bootstrapEngine();
    await bootstrapEngine(); // no-op — bootstrapped flag is set

    // Promise.all fires exactly two invoke() calls on the first bootstrap
    // and zero on the second.
    expect(vi.mocked(invoke)).toHaveBeenCalledTimes(2);
  });

  it("wires the engine with bin paths derived from get_bin_dir", async () => {
    const { invoke } = await import("@tauri-apps/api/core");
    vi.mocked(invoke).mockResolvedValueOnce("/res/bin").mockResolvedValueOnce("/data/generated");

    const engineModule = await import("./engine.js");
    const { bootstrapEngine } = await import("./bootstrap.js");
    await bootstrapEngine();

    expect(vi.mocked(engineModule.createEngine)).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        config: "/res/bin/f13-config",
        stop: "/res/bin/f13-stop",
        reset: "/res/bin/f13-reset",
      })
    );
  });

  it("resets bootstrapped flag on failure so a retry is possible", async () => {
    const { invoke } = await import("@tauri-apps/api/core");
    // First call fails
    vi.mocked(invoke).mockRejectedValueOnce(new Error("IPC error"));
    const { bootstrapEngine, getGeneratedDir } = await import("./bootstrap.js");
    await bootstrapEngine();
    expect(getGeneratedDir()).toBeNull();

    // Second call succeeds — should work because the flag was reset
    vi.mocked(invoke).mockResolvedValueOnce("/bin").mockResolvedValueOnce("/gen");
    await bootstrapEngine();
    expect(getGeneratedDir()).toBe("/gen");
  });
});
