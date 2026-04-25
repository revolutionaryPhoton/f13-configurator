import { fireEvent, render, waitFor } from "@testing-library/svelte";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { ComposeEvent, Engine } from "$lib/engine.js";
import StatusPage from "./+page.svelte";

vi.mock("$app/navigation", () => ({ goto: vi.fn() }));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function* makeHealthEvents(events: ComposeEvent[]): AsyncGenerator<ComposeEvent> {
  for (const evt of events) yield evt;
}

function makeNeverHealthEngine(): Engine {
  return {
    detectState: vi.fn(),
    preflight: vi.fn(),
    listOllamaModels: vi.fn(),
    checkPort: vi.fn(),
    runWizardNonInteractive: vi.fn(),
    compose: {
      up: vi.fn().mockResolvedValue(undefined),
      down: vi.fn().mockResolvedValue(undefined),
      reset: vi.fn().mockResolvedValue(undefined),
      health: vi.fn().mockReturnValue({
        [Symbol.asyncIterator]() {
          return { next: () => new Promise<never>(() => {}) };
        },
      }),
    },
  } as unknown as Engine;
}

function makeEngine(healthEvents: ComposeEvent[] = []): Engine {
  return {
    detectState: vi.fn(),
    preflight: vi.fn(),
    listOllamaModels: vi.fn(),
    checkPort: vi.fn(),
    runWizardNonInteractive: vi.fn(),
    compose: {
      up: vi.fn().mockResolvedValue(undefined),
      down: vi.fn().mockResolvedValue(undefined),
      reset: vi.fn().mockResolvedValue(undefined),
      health: vi.fn().mockImplementation(() => makeHealthEvents(healthEvents)),
    },
  } as unknown as Engine;
}

const healthyEvent: ComposeEvent = { type: "health", status: "healthy" };
const unhealthyEvent: ComposeEvent = {
  type: "health",
  status: "unhealthy",
  message: "core not responding",
};

// Open the reset modal, type RESET, and click Confirm reset.
async function openAndConfirmReset(
  getByRole: (r: string, opts?: { name?: RegExp }) => HTMLElement,
  getByTestId: (id: string) => HTMLElement
) {
  await fireEvent.click(getByRole("button", { name: /full reset/i }));
  const input = (await waitFor(() => getByTestId("reset-confirm-input"))) as HTMLElement;
  await fireEvent.input(input, { target: { value: "RESET" } });
  await waitFor(() => {
    const btn = getByRole("button", { name: /confirm reset/i }) as HTMLButtonElement;
    if (btn.disabled) throw new Error("still disabled");
  });
  await fireEvent.click(getByRole("button", { name: /confirm reset/i }));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("status/+page.svelte", () => {
  beforeEach(() => vi.clearAllMocks());
  afterEach(() => vi.useRealTimers());

  it("renders the page heading", () => {
    const { getByTestId } = render(StatusPage, { engine: makeNeverHealthEngine() });
    expect(getByTestId("page-heading").textContent).toContain("F13 Status");
  });

  it("renders the health card", () => {
    const { getByTestId } = render(StatusPage, { engine: makeNeverHealthEngine() });
    expect(getByTestId("health-card")).toBeTruthy();
  });

  it("renders health badge", () => {
    const { getByTestId } = render(StatusPage, { engine: makeNeverHealthEngine() });
    expect(getByTestId("health-badge")).toBeTruthy();
  });

  it("shows 'Checking…' badge initially (before health resolves)", () => {
    const { getByTestId } = render(StatusPage, { engine: makeNeverHealthEngine() });
    expect(getByTestId("health-badge").textContent).toContain("Checking");
  });

  it("shows 'Healthy' badge after a healthy event", async () => {
    const { getByTestId } = render(StatusPage, {
      engine: makeEngine([healthyEvent]),
    });
    await waitFor(() => expect(getByTestId("health-badge").textContent).toContain("Healthy"));
  });

  it("shows 'Unhealthy' badge after an unhealthy event", async () => {
    const { getByTestId } = render(StatusPage, {
      engine: makeEngine([unhealthyEvent]),
    });
    await waitFor(() => expect(getByTestId("health-badge").textContent).toContain("Unhealthy"));
  });

  it("shows health message when unhealthy event includes message", async () => {
    const { getByTestId } = render(StatusPage, {
      engine: makeEngine([unhealthyEvent]),
    });
    await waitFor(() =>
      expect(getByTestId("health-message").textContent).toContain("core not responding")
    );
  });

  it("calls engine.compose.health on mount", async () => {
    const engine = makeEngine([healthyEvent]);
    render(StatusPage, { engine });
    await waitFor(() => expect(engine.compose.health).toHaveBeenCalledTimes(1));
  });

  it("polls health again after 5 seconds", async () => {
    vi.useFakeTimers();
    const engine = makeEngine([healthyEvent]);
    render(StatusPage, { engine });
    await waitFor(() => expect(engine.compose.health).toHaveBeenCalledTimes(1));
    vi.advanceTimersByTime(5000);
    await waitFor(() => expect(engine.compose.health).toHaveBeenCalledTimes(2));
  });

  it("renders 'Open F13 in browser' button", () => {
    const { getByRole } = render(StatusPage, { engine: makeNeverHealthEngine() });
    expect(getByRole("button", { name: /open f13 in browser/i })).toBeTruthy();
  });

  it("Open F13 button calls openUrl with the frontend URL", async () => {
    const openUrl = vi.fn();
    const { getByRole } = render(StatusPage, {
      engine: makeNeverHealthEngine(),
      openUrl,
      frontendPort: 9999,
    });
    await fireEvent.click(getByRole("button", { name: /open f13 in browser/i }));
    expect(openUrl).toHaveBeenCalledWith("http://localhost:9999");
  });

  it("Open F13 uses injected frontendPort in URL", async () => {
    const openUrl = vi.fn();
    const { getByRole } = render(StatusPage, {
      engine: makeNeverHealthEngine(),
      openUrl,
      frontendPort: 7777,
    });
    await fireEvent.click(getByRole("button", { name: /open f13 in browser/i }));
    expect(openUrl).toHaveBeenCalledWith("http://localhost:7777");
  });

  it("renders Stop F13 button", () => {
    const { getByRole } = render(StatusPage, { engine: makeNeverHealthEngine() });
    expect(getByRole("button", { name: /stop f13/i })).toBeTruthy();
  });

  it("Stop F13 calls engine.compose.down", async () => {
    const engine = makeEngine();
    const { getByRole } = render(StatusPage, { engine });
    await fireEvent.click(getByRole("button", { name: /stop f13/i }));
    await waitFor(() => expect(engine.compose.down).toHaveBeenCalled());
  });

  it("Stop F13 shows info toast while stopping", async () => {
    const engine = makeEngine();
    (engine.compose.down as ReturnType<typeof vi.fn>).mockReturnValue(new Promise(() => {}));
    const { getByRole, getByTestId } = render(StatusPage, { engine });
    await fireEvent.click(getByRole("button", { name: /stop f13/i }));
    await waitFor(() => expect(getByTestId("toast-stack")).toBeTruthy());
  });

  it("Stop F13 shows success toast on completion", async () => {
    const engine = makeEngine();
    const { container, getByRole } = render(StatusPage, { engine });
    await fireEvent.click(getByRole("button", { name: /stop f13/i }));
    await waitFor(() => expect(container.textContent).toContain("F13 stopped."));
  });

  it("Stop F13 navigates to / on success", async () => {
    const { goto } = await import("$app/navigation");
    const engine = makeEngine();
    const { getByRole } = render(StatusPage, { engine });
    await fireEvent.click(getByRole("button", { name: /stop f13/i }));
    await waitFor(() => expect(goto).toHaveBeenCalledWith("/"));
  });

  it("renders Full Reset button", () => {
    const { getByRole } = render(StatusPage, { engine: makeNeverHealthEngine() });
    expect(getByRole("button", { name: /full reset/i })).toBeTruthy();
  });

  // ---- Reset confirmation modal ----

  it("Full Reset button opens confirmation modal", async () => {
    const { getByRole, getByTestId } = render(StatusPage, {
      engine: makeNeverHealthEngine(),
    });
    await fireEvent.click(getByRole("button", { name: /full reset/i }));
    await waitFor(() => expect(getByTestId("reset-confirm-input")).toBeTruthy());
  });

  it("Confirm reset button is disabled until RESET is typed", async () => {
    const { getByRole, getByTestId } = render(StatusPage, {
      engine: makeNeverHealthEngine(),
    });
    await fireEvent.click(getByRole("button", { name: /full reset/i }));
    await waitFor(() => getByTestId("reset-confirm-input"));
    const confirmBtn = getByRole("button", { name: /confirm reset/i }) as HTMLButtonElement;
    expect(confirmBtn.disabled).toBe(true);
  });

  it("Confirm reset button is enabled when RESET is typed", async () => {
    const { getByRole, getByTestId } = render(StatusPage, {
      engine: makeNeverHealthEngine(),
    });
    await fireEvent.click(getByRole("button", { name: /full reset/i }));
    const input = (await waitFor(() => getByTestId("reset-confirm-input"))) as HTMLElement;
    await fireEvent.input(input, { target: { value: "RESET" } });
    await waitFor(() => {
      const btn = getByRole("button", { name: /confirm reset/i }) as HTMLButtonElement;
      expect(btn.disabled).toBe(false);
    });
  });

  it("Cancel button in reset modal closes modal without resetting", async () => {
    const engine = makeEngine();
    const { getByRole, getByTestId, queryByTestId } = render(StatusPage, { engine });
    await fireEvent.click(getByRole("button", { name: /full reset/i }));
    await waitFor(() => getByTestId("reset-confirm-input"));
    await fireEvent.click(getByRole("button", { name: /^cancel$/i }));
    await waitFor(() => expect(queryByTestId("reset-confirm-input")).toBeNull());
    expect(engine.compose.reset).not.toHaveBeenCalled();
  });

  it("Full Reset calls engine.compose.reset after confirming", async () => {
    const engine = makeEngine();
    const { getByRole, getByTestId } = render(StatusPage, { engine });
    await openAndConfirmReset(
      (r, o) => getByRole(r, o) as HTMLElement,
      (id) => getByTestId(id) as HTMLElement
    );
    await waitFor(() => expect(engine.compose.reset).toHaveBeenCalled());
  });

  it("Full Reset shows warning toast while resetting", async () => {
    const engine = makeEngine();
    (engine.compose.reset as ReturnType<typeof vi.fn>).mockReturnValue(new Promise(() => {}));
    const { getByRole, getByTestId } = render(StatusPage, { engine });
    await fireEvent.click(getByRole("button", { name: /full reset/i }));
    const input = (await waitFor(() => getByTestId("reset-confirm-input"))) as HTMLElement;
    await fireEvent.input(input, { target: { value: "RESET" } });
    await waitFor(() => {
      const btn = getByRole("button", { name: /confirm reset/i }) as HTMLButtonElement;
      if (btn.disabled) throw new Error("still disabled");
    });
    await fireEvent.click(getByRole("button", { name: /confirm reset/i }));
    await waitFor(() => expect(getByTestId("toast-stack")).toBeTruthy());
  });

  it("Full Reset navigates to / on success", async () => {
    const { goto } = await import("$app/navigation");
    const engine = makeEngine();
    const { getByRole, getByTestId } = render(StatusPage, { engine });
    await openAndConfirmReset(
      (r, o) => getByRole(r, o) as HTMLElement,
      (id) => getByTestId(id) as HTMLElement
    );
    await waitFor(() => expect(goto).toHaveBeenCalledWith("/"));
  });

  it("View logs shows info toast with docker command", async () => {
    const { container, getByRole } = render(StatusPage, { engine: makeNeverHealthEngine() });
    await fireEvent.click(getByRole("button", { name: /view logs/i }));
    await waitFor(() => expect(container.textContent).toContain("docker compose"));
  });

  it("Reconfigure button navigates to /wizard/preflight", async () => {
    const { goto } = await import("$app/navigation");
    const { getByTestId } = render(StatusPage, { engine: makeNeverHealthEngine() });
    await fireEvent.click(getByTestId("reconfigure-btn"));
    await waitFor(() => expect(goto).toHaveBeenCalledWith("/wizard/preflight"));
  });

  it("null engine renders without crashing", () => {
    const { getByTestId } = render(StatusPage, { engine: null });
    expect(getByTestId("page-heading")).toBeTruthy();
  });

  it("null engine shows checking status (no health call)", () => {
    const { getByTestId } = render(StatusPage, { engine: null });
    expect(getByTestId("health-badge").textContent).toContain("Checking");
  });

  it("Stop F13 shows error toast on failure", async () => {
    const engine = makeEngine();
    (engine.compose.down as ReturnType<typeof vi.fn>).mockRejectedValue(new Error("stop failed"));
    const { container, getByRole } = render(StatusPage, { engine });
    await fireEvent.click(getByRole("button", { name: /stop f13/i }));
    await waitFor(() => expect(container.textContent).toContain("stop failed"));
  });

  it("Full Reset shows success toast on completion", async () => {
    const engine = makeEngine();
    const { container, getByRole, getByTestId } = render(StatusPage, { engine });
    await openAndConfirmReset(
      (r, o) => getByRole(r, o) as HTMLElement,
      (id) => getByTestId(id) as HTMLElement
    );
    await waitFor(() => expect(container.textContent).toContain("Reset complete"));
  });
});
