import { fireEvent, render, waitFor } from "@testing-library/svelte";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { Engine, PreflightEvent } from "$lib/engine.js";
import PreflightPage from "./+page.svelte";

vi.mock("$app/navigation", () => ({ goto: vi.fn() }));

async function* makeStream(events: PreflightEvent[]): AsyncIterable<PreflightEvent> {
  for (const evt of events) {
    yield evt;
  }
}

function ok(name: string, detail?: string): PreflightEvent {
  return { type: "preflight", name, status: "ok", detail };
}

function fail(name: string, detail?: string): PreflightEvent {
  return { type: "preflight", name, status: "fail", detail };
}

function info(name: string, detail: string): PreflightEvent {
  return { type: "preflight", name, status: "info", detail };
}

function makeEngine(events: PreflightEvent[], models: string[] | "not-running" = []): Engine {
  return {
    detectState: vi.fn(),
    preflight: vi.fn(() => makeStream(events)),
    listOllamaModels: vi.fn().mockResolvedValue(models),
    checkPort: vi.fn(),
    runWizardNonInteractive: vi.fn(),
    compose: {
      up: vi.fn(),
      down: vi.fn(),
      reset: vi.fn(),
      health: vi.fn(),
    },
  } as unknown as Engine;
}

describe("preflight/+page.svelte", () => {
  beforeEach(() => vi.clearAllMocks());

  it("renders the Preflight kicker / scanning heading", () => {
    const { getByRole, container } = render(PreflightPage, { engine: makeEngine([]) });
    // Heading is one of the three streaming-state strings; assert generally.
    expect(getByRole("heading", { level: 1 })).toBeTruthy();
    expect(container.textContent?.toLowerCase()).toContain("preflight");
  });

  it("shows a checking indicator while streaming", () => {
    // Provide an engine that never resolves (never yields)
    const neverEngine = {
      ...makeEngine([]),
      preflight: vi.fn(() =>
        (async function* () {
          await new Promise<void>(() => {}); // hangs forever
          yield ok("docker");
        })()
      ),
    } as unknown as Engine;

    const { container } = render(PreflightPage, { engine: neverEngine });
    expect(container.textContent).toContain("Checking…");
  });

  it("shows ok checks with a ✓ icon after streaming", async () => {
    const { getAllByLabelText } = render(PreflightPage, {
      engine: makeEngine([ok("docker"), ok("bash")]),
    });
    await waitFor(() => {
      const passed = getAllByLabelText(/passed/i);
      expect(passed.length).toBe(2);
    });
  });

  it("shows fail checks with a ✕ icon", async () => {
    const { getByLabelText } = render(PreflightPage, {
      engine: makeEngine([fail("docker", "not found")]),
    });
    await waitFor(() => expect(getByLabelText(/failed/i)).toBeTruthy());
  });

  it("shows a 'Fix this' disclosure for known failing checks", async () => {
    const { getByText } = render(PreflightPage, {
      engine: makeEngine([fail("docker", "not found")]),
    });
    await waitFor(() => expect(getByText(/fix this/i)).toBeTruthy());
  });

  it("disclosure contains a brew install command for docker", async () => {
    const { getByText } = render(PreflightPage, {
      engine: makeEngine([fail("docker", "not found")]),
    });
    await waitFor(() => expect(getByText(/brew install --cask docker/i)).toBeTruthy());
  });

  it("shows info row with ⓘ icon for ollama", async () => {
    const { getByLabelText } = render(PreflightPage, {
      engine: makeEngine([info("ollama", "not detected")]),
    });
    await waitFor(() => expect(getByLabelText(/info/i)).toBeTruthy());
  });

  it("shows nested model list when ollama is detected", async () => {
    const { getByText } = render(PreflightPage, {
      engine: makeEngine([info("ollama", "detected, 2 model(s)")], ["gemma2:9b", "llama3.1:8b"]),
    });
    await waitFor(() => {
      expect(getByText("gemma2:9b")).toBeTruthy();
      expect(getByText("llama3.1:8b")).toBeTruthy();
    });
  });

  it("shows empty-models message when ollama detected but no models", async () => {
    const { getByText } = render(PreflightPage, {
      engine: makeEngine([info("ollama", "detected, 0 model(s)")], []),
    });
    await waitFor(() => expect(getByText(/no models installed/i)).toBeTruthy());
  });

  it("does not show model list for ollama 'not detected'", async () => {
    const eng = makeEngine([info("ollama", "not detected")], []);
    const { queryByLabelText } = render(PreflightPage, { engine: eng });
    await waitFor(() => expect(eng.preflight).toHaveBeenCalled());
    // listOllamaModels should NOT be called if ollama not detected
    expect(eng.listOllamaModels).not.toHaveBeenCalled();
    expect(queryByLabelText(/ollama models/i)).toBeNull();
  });

  it("Continue is disabled while streaming", () => {
    const neverEngine = {
      ...makeEngine([]),
      preflight: vi.fn(() =>
        (async function* () {
          await new Promise<void>(() => {});
          yield ok("docker");
        })()
      ),
    } as unknown as Engine;

    const { getByRole } = render(PreflightPage, { engine: neverEngine });
    const btn = getByRole("button", { name: /continue/i });
    expect(btn).toHaveAttribute("disabled");
  });

  it("Continue is disabled when a failure exists", async () => {
    const { getByRole } = render(PreflightPage, {
      engine: makeEngine([fail("docker", "not found")]),
    });
    await waitFor(() =>
      expect(getByRole("button", { name: /continue/i })).toHaveAttribute("disabled")
    );
  });

  it("Continue is enabled when all checks pass", async () => {
    const { getByRole } = render(PreflightPage, {
      engine: makeEngine([ok("docker"), ok("bash"), ok("curl")]),
    });
    await waitFor(() =>
      expect(getByRole("button", { name: /continue/i })).not.toHaveAttribute("disabled")
    );
  });

  it("Continue navigates to /wizard/inference", async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole } = render(PreflightPage, {
      engine: makeEngine([ok("docker")]),
    });
    const btn = await waitFor(() => {
      const b = getByRole("button", { name: /continue/i });
      if (b.hasAttribute("disabled")) throw new Error("still disabled");
      return b;
    });
    await fireEvent.click(btn);
    expect(goto).toHaveBeenCalledWith("/wizard/inference");
  });

  it("shows 'Back' button that navigates to /", async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole } = render(PreflightPage, { engine: makeEngine([]) });
    const back = getByRole("button", { name: /^back$/i });
    await fireEvent.click(back);
    expect(goto).toHaveBeenCalledWith("/");
  });

  it("handles missing engine gracefully (streaming=false, Continue disabled)", async () => {
    const { getByRole } = render(PreflightPage, { engine: null });
    await waitFor(() =>
      expect(getByRole("button", { name: /continue/i })).toHaveAttribute("disabled")
    );
  });
});
