import { fireEvent, render, waitFor } from "@testing-library/svelte";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { DoneEvent, Engine, StepEvent } from "$lib/engine.js";
import RunPage from "./+page.svelte";

vi.mock("$app/navigation", () => ({ goto: vi.fn() }));

async function* makeEvents(
  events: Array<StepEvent | DoneEvent>
): AsyncGenerator<StepEvent | DoneEvent> {
  for (const evt of events) yield evt;
}

function makeNeverEngine(): Engine {
  return {
    detectState: vi.fn(),
    preflight: vi.fn(),
    listOllamaModels: vi.fn(),
    checkPort: vi.fn(),
    runWizardNonInteractive: vi.fn().mockReturnValue({
      [Symbol.asyncIterator]() {
        return { next: () => new Promise<never>(() => {}) };
      },
    }),
    compose: {
      up: vi.fn().mockResolvedValue(undefined),
      down: vi.fn().mockResolvedValue(undefined),
      reset: vi.fn().mockResolvedValue(undefined),
      health: vi.fn(),
    },
  } as unknown as Engine;
}

function makeEngine(events: Array<StepEvent | DoneEvent>): Engine {
  return {
    detectState: vi.fn(),
    preflight: vi.fn(),
    listOllamaModels: vi.fn(),
    checkPort: vi.fn(),
    runWizardNonInteractive: vi.fn().mockImplementation(() => makeEvents(events)),
    compose: {
      up: vi.fn().mockResolvedValue(undefined),
      down: vi.fn().mockResolvedValue(undefined),
      reset: vi.fn().mockResolvedValue(undefined),
      health: vi.fn(),
    },
  } as unknown as Engine;
}

describe("wizard/run/+page.svelte", () => {
  beforeEach(() => vi.clearAllMocks());

  it("renders the launch heading", () => {
    const { getByRole } = render(RunPage, { engine: makeNeverEngine(), backend: "mock" });
    // Heading reflects pipeline state — pre-events it reads "Setting up…"
    expect(getByRole("heading", { level: 1 }).textContent).toMatch(
      /setting up|f13 is up|setup failed/i
    );
  });

  it("shows 'Launching' breadcrumb text", () => {
    const { getByText } = render(RunPage, { engine: makeNeverEngine(), backend: "mock" });
    expect(getByText(/launching/i)).toBeTruthy();
  });

  it("renders all 6 pipeline step cards", () => {
    const { getByTestId } = render(RunPage, { engine: makeNeverEngine(), backend: "mock" });
    for (const key of ["secrets", "render", "build", "pull", "start", "health"]) {
      expect(getByTestId(`step-${key}`)).toBeTruthy();
    }
  });

  it("all steps begin as pending", () => {
    const { getByTestId } = render(RunPage, { engine: makeNeverEngine(), backend: "mock" });
    for (const key of ["secrets", "render", "build", "pull", "start", "health"]) {
      expect(getByTestId(`step-${key}`)).toHaveAttribute("data-status", "pending");
    }
  });

  it("secrets step transitions to running on started event", async () => {
    const engine = makeEngine([{ type: "step", name: "secrets", status: "started" } as StepEvent]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() =>
      expect(getByTestId("step-secrets")).toHaveAttribute("data-status", "running")
    );
  });

  it("secrets step transitions to done on done event", async () => {
    const engine = makeEngine([
      { type: "step", name: "secrets", status: "started" } as StepEvent,
      { type: "step", name: "secrets", status: "done" } as StepEvent,
    ]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(getByTestId("step-secrets")).toHaveAttribute("data-status", "done"));
  });

  it("build step transitions to running on started event", async () => {
    const engine = makeEngine([{ type: "step", name: "build", status: "started" } as StepEvent]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() =>
      expect(getByTestId("step-build")).toHaveAttribute("data-status", "running")
    );
  });

  it("build step shows progress bar while running", async () => {
    const engine = makeEngine([{ type: "step", name: "build", status: "started" } as StepEvent]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(getByTestId("build-progress")).toBeTruthy());
  });

  it("build step hides progress bar when done", async () => {
    const engine = makeEngine([
      { type: "step", name: "build", status: "started" } as StepEvent,
      { type: "step", name: "build", status: "done" } as StepEvent,
    ]);
    const { queryByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(queryByTestId("build-progress")).toBeNull());
  });

  it("start-started event marks pull as running", async () => {
    const engine = makeEngine([{ type: "step", name: "start", status: "started" } as StepEvent]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(getByTestId("step-pull")).toHaveAttribute("data-status", "running"));
  });

  it("start-done event marks pull done, start done, health running", async () => {
    const engine = makeEngine([
      { type: "step", name: "start", status: "started" } as StepEvent,
      { type: "step", name: "start", status: "done" } as StepEvent,
    ]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => {
      expect(getByTestId("step-pull")).toHaveAttribute("data-status", "done");
      expect(getByTestId("step-start")).toHaveAttribute("data-status", "done");
      expect(getByTestId("step-health")).toHaveAttribute("data-status", "running");
    });
  });

  it("done-ok event marks health as done", async () => {
    const engine = makeEngine([
      { type: "step", name: "start", status: "started" } as StepEvent,
      { type: "step", name: "start", status: "done" } as StepEvent,
      { type: "done", status: "ok" } as DoneEvent,
    ]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(getByTestId("step-health")).toHaveAttribute("data-status", "done"));
  });

  it("done-ok event navigates to /status", async () => {
    const { goto } = await import("$app/navigation");
    const engine = makeEngine([{ type: "done", status: "ok" } as DoneEvent]);
    render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(goto).toHaveBeenCalledWith("/status"));
  });

  it("done-error event shows error message in heading", async () => {
    const engine = makeEngine([
      { type: "done", status: "error", message: "compose up failed" } as DoneEvent,
    ]);
    const { getByRole } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(getByRole("heading", { name: /setup failed/i })).toBeTruthy());
  });

  it("done-error event shows error message in subtitle", async () => {
    const engine = makeEngine([
      { type: "done", status: "error", message: "compose up failed" } as DoneEvent,
    ]);
    const { getAllByText } = render(RunPage, { engine, backend: "mock" });
    // Error appears in BOTH the subtitle paragraph AND the terminal log,
    // so use getAllByText (>=1 match) instead of getByText (exactly 1).
    await waitFor(() => expect(getAllByText(/compose up failed/i).length).toBeGreaterThan(0));
  });

  it("done-error event marks any running step as failed", async () => {
    const engine = makeEngine([
      { type: "step", name: "secrets", status: "started" } as StepEvent,
      { type: "done", status: "error", message: "oops" } as DoneEvent,
    ]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() =>
      expect(getByTestId("step-secrets")).toHaveAttribute("data-status", "failed")
    );
  });

  it("step-fail event marks step as failed", async () => {
    const engine = makeEngine([
      { type: "step", name: "render", status: "fail", message: "template error" } as StepEvent,
    ]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() =>
      expect(getByTestId("step-render")).toHaveAttribute("data-status", "failed")
    );
  });

  it("step message appears as a log entry in the step", async () => {
    const engine = makeEngine([
      {
        type: "step",
        name: "secrets",
        status: "started",
        message: "writing secrets...",
      } as StepEvent,
    ]);
    const { container } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(container.textContent).toContain("writing secrets..."));
  });

  it("Cancel button is visible while pipeline is running", async () => {
    const { getByRole } = render(RunPage, { engine: makeNeverEngine(), backend: "mock" });
    await waitFor(() => expect(getByRole("button", { name: /cancel/i })).toBeTruthy());
  });

  it("Cancel button calls engine.compose.down", async () => {
    const engine = makeNeverEngine();
    const { getByRole } = render(RunPage, { engine, backend: "mock" });
    const cancelBtn = await waitFor(() => getByRole("button", { name: /cancel/i }));
    await fireEvent.click(cancelBtn);
    await waitFor(() => expect(engine.compose.down).toHaveBeenCalled());
  });

  it("Cancel button navigates to /wizard/ports", async () => {
    const { goto } = await import("$app/navigation");
    const engine = makeNeverEngine();
    const { getByRole } = render(RunPage, { engine, backend: "mock" });
    const cancelBtn = await waitFor(() => getByRole("button", { name: /cancel/i }));
    await fireEvent.click(cancelBtn);
    await waitFor(() => expect(goto).toHaveBeenCalledWith("/wizard/ports"));
  });

  // HF2: Cancel must abort the AbortSignal we pass into the engine so
  // the underlying bash subprocess dies, not just the JS-side loop.
  it("Cancel aborts the AbortSignal handed to runWizardNonInteractive (HF2)", async () => {
    // Capture the signal the page passes to the engine.
    let capturedSignal: AbortSignal | undefined;
    const engine = {
      detectState: vi.fn().mockResolvedValue({ type: "state", exists: false }),
      preflight: vi.fn(),
      listOllamaModels: vi.fn(),
      checkPort: vi.fn(),
      runWizardNonInteractive: vi
        .fn()
        .mockImplementation((_opts: unknown, signal?: AbortSignal) => {
          capturedSignal = signal;
          return {
            [Symbol.asyncIterator]() {
              return { next: () => new Promise<never>(() => {}) };
            },
          };
        }),
      compose: {
        up: vi.fn().mockResolvedValue(undefined),
        down: vi.fn().mockResolvedValue(undefined),
        reset: vi.fn().mockResolvedValue(undefined),
        health: vi.fn(),
      },
    } as unknown as Engine;
    const { getByRole } = render(RunPage, { engine, backend: "mock" });
    const cancelBtn = await waitFor(() => getByRole("button", { name: /cancel/i }));
    await waitFor(() => expect(capturedSignal).toBeDefined());
    expect(capturedSignal?.aborted).toBe(false);
    await fireEvent.click(cancelBtn);
    await waitFor(() => expect(capturedSignal?.aborted).toBe(true));
  });

  it("error state shows 'Back to ports' button", async () => {
    const engine = makeEngine([{ type: "done", status: "error", message: "oops" } as DoneEvent]);
    const { getByRole } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(getByRole("button", { name: /back to ports/i })).toBeTruthy());
  });

  it("error state shows '← Back' header button", async () => {
    const engine = makeEngine([{ type: "done", status: "error", message: "oops" } as DoneEvent]);
    const { getByRole } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(getByRole("button", { name: /back to ports/i })).toBeTruthy());
  });

  it("null engine renders without crashing", () => {
    const { getByRole } = render(RunPage, { engine: null, backend: "mock" });
    // Heading reflects pipeline state — pre-events it reads "Setting up…"
    expect(getByRole("heading", { level: 1 }).textContent).toMatch(
      /setting up|f13 is up|setup failed/i
    );
  });

  it("null engine shows no Cancel button", () => {
    const { queryByRole } = render(RunPage, { engine: null, backend: "mock" });
    expect(queryByRole("button", { name: /cancel/i })).toBeNull();
  });

  it("calls runWizardNonInteractive with the provided backend", async () => {
    const engine = makeEngine([]);
    render(RunPage, { engine, backend: "ollama", ollamaModel: "llama3:8b" });
    await waitFor(() =>
      expect(engine.runWizardNonInteractive).toHaveBeenCalledWith(
        expect.objectContaining({ backend: "ollama", ollamaModel: "llama3:8b" }),
        expect.anything() // HF2: second arg is the AbortSignal
      )
    );
  });

  // ---------------------------------------------------------------------------
  // Skipped events (S34)
  // ---------------------------------------------------------------------------

  it("skipped step is marked done instantly without running state", async () => {
    const engine = makeEngine([
      { type: "step", name: "secrets", status: "done", skipped: true } as StepEvent,
    ]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(getByTestId("step-secrets")).toHaveAttribute("data-status", "done"));
  });

  it("skipped step has data-skipped=true attribute", async () => {
    const engine = makeEngine([
      { type: "step", name: "render", status: "done", skipped: true } as StepEvent,
    ]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(getByTestId("step-render")).toHaveAttribute("data-skipped", "true"));
  });

  it("skipped secrets+render+build steps then normal start flow fills all stages", async () => {
    const engine = makeEngine([
      { type: "step", name: "secrets", status: "done", skipped: true } as StepEvent,
      { type: "step", name: "render", status: "done", skipped: true } as StepEvent,
      { type: "step", name: "build", status: "done", skipped: true } as StepEvent,
      { type: "step", name: "start", status: "started" } as StepEvent,
      { type: "step", name: "start", status: "done" } as StepEvent,
      { type: "done", status: "ok" } as DoneEvent,
    ]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => {
      expect(getByTestId("step-secrets")).toHaveAttribute("data-status", "done");
      expect(getByTestId("step-render")).toHaveAttribute("data-status", "done");
      expect(getByTestId("step-build")).toHaveAttribute("data-status", "done");
      expect(getByTestId("step-pull")).toHaveAttribute("data-status", "done");
      expect(getByTestId("step-start")).toHaveAttribute("data-status", "done");
      expect(getByTestId("step-health")).toHaveAttribute("data-status", "done");
    });
  });

  it("non-skipped done event does not set data-skipped", async () => {
    const engine = makeEngine([{ type: "step", name: "secrets", status: "done" } as StepEvent]);
    const { getByTestId } = render(RunPage, { engine, backend: "mock" });
    await waitFor(() => expect(getByTestId("step-secrets")).toHaveAttribute("data-status", "done"));
    expect(getByTestId("step-secrets")).not.toHaveAttribute("data-skipped");
  });

  // HF4: when state already exists, the wizard must run with
  // stateAction:"edit" — otherwise the default "keep" branch silently
  // no-ops and the user's new backend choice is never written.
  it("passes stateAction:'edit' to the wizard when state exists (HF4)", async () => {
    const engine = makeEngine([{ type: "done", status: "ok" } as DoneEvent]);
    (engine.detectState as ReturnType<typeof vi.fn>).mockResolvedValue({
      type: "state",
      exists: true,
      preset: "core+frontend+chat",
      backend: "mock",
      model: "",
      frontendPort: 9999,
      corePort: 8000,
      timestamp: "2026-04-27T08:00:00Z",
    });
    render(RunPage, { engine, backend: "ollama" });
    await waitFor(() => {
      expect(engine.runWizardNonInteractive).toHaveBeenCalled();
    });
    const args = (engine.runWizardNonInteractive as ReturnType<typeof vi.fn>).mock.calls[0][0];
    expect(args.stateAction).toBe("edit");
  });

  it("omits stateAction on a fresh init (HF4)", async () => {
    const engine = makeEngine([{ type: "done", status: "ok" } as DoneEvent]);
    (engine.detectState as ReturnType<typeof vi.fn>).mockResolvedValue({
      type: "state",
      exists: false,
    });
    render(RunPage, { engine, backend: "mock" });
    await waitFor(() => {
      expect(engine.runWizardNonInteractive).toHaveBeenCalled();
    });
    const args = (engine.runWizardNonInteractive as ReturnType<typeof vi.fn>).mock.calls[0][0];
    expect(args.stateAction).toBeUndefined();
  });
});
