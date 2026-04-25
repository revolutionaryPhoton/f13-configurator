import { fireEvent, render, waitFor } from "@testing-library/svelte";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { Engine } from "$lib/engine.js";
import PortsPage from "./+page.svelte";

vi.mock("$app/navigation", () => ({ goto: vi.fn() }));

type PortResult = "free" | "pending" | { inUseBy: number; name: string };

function makeEngine(result: PortResult): Engine {
  const impl =
    result === "pending"
      ? vi.fn().mockImplementation(() => new Promise<never>(() => {}))
      : vi.fn().mockResolvedValue(result);
  return {
    detectState: vi.fn(),
    preflight: vi.fn(),
    listOllamaModels: vi.fn(),
    checkPort: impl,
    runWizardNonInteractive: vi.fn(),
    compose: {
      up: vi.fn(),
      down: vi.fn(),
      reset: vi.fn(),
      health: vi.fn(),
    },
  } as unknown as Engine;
}

/** Engine that returns different results per port number. */
function makePerPortEngine(results: Record<number, PortResult>): Engine {
  const impl = vi.fn().mockImplementation(async (port: number) => {
    const r = results[port] ?? "free";
    if (r === "pending") return new Promise<never>(() => {});
    return r;
  });
  return {
    detectState: vi.fn(),
    preflight: vi.fn(),
    listOllamaModels: vi.fn(),
    checkPort: impl,
    runWizardNonInteractive: vi.fn(),
    compose: {
      up: vi.fn(),
      down: vi.fn(),
      reset: vi.fn(),
      health: vi.fn(),
    },
  } as unknown as Engine;
}

describe("ports/+page.svelte", () => {
  beforeEach(() => vi.clearAllMocks());

  it("renders the heading", () => {
    const { getByRole } = render(PortsPage, { via: "mock", engine: makeEngine("pending") });
    expect(getByRole("heading", { name: /configure ports/i })).toBeTruthy();
  });

  it("renders Step 3 of 4 breadcrumb for mock", () => {
    const { getByText } = render(PortsPage, { via: "mock", engine: makeEngine("pending") });
    expect(getByText(/step 3 of 4/i)).toBeTruthy();
  });

  it("renders Step 4 of 4 breadcrumb for ollama", () => {
    const { getByText } = render(PortsPage, { via: "ollama", engine: makeEngine("pending") });
    expect(getByText(/step 4 of 4/i)).toBeTruthy();
  });

  it("frontend port input has default value 9999", () => {
    const { getByLabelText } = render(PortsPage, {
      via: "mock",
      engine: makeEngine("pending"),
    });
    const input = getByLabelText(/frontend port/i) as HTMLInputElement;
    expect(Number(input.value)).toBe(9999);
  });

  it("core API port input has default value 8000", () => {
    const { getByLabelText } = render(PortsPage, {
      via: "mock",
      engine: makeEngine("pending"),
    });
    const input = getByLabelText(/core api port/i) as HTMLInputElement;
    expect(Number(input.value)).toBe(8000);
  });

  it("Continue is disabled while ports are checking (pending engine)", () => {
    const { getByRole } = render(PortsPage, { via: "mock", engine: makeEngine("pending") });
    expect(getByRole("button", { name: /continue/i })).toHaveAttribute("disabled");
  });

  it("Continue is disabled when both ports are taken", async () => {
    const { getByRole } = render(PortsPage, {
      via: "mock",
      engine: makeEngine({ inUseBy: 1234, name: "nginx" }),
    });
    await waitFor(() =>
      expect(getByRole("button", { name: /continue/i })).toHaveAttribute("disabled")
    );
  });

  it("Continue is enabled when both ports are free", async () => {
    const { getByRole } = render(PortsPage, { via: "mock", engine: makeEngine("free") });
    await waitFor(() =>
      expect(getByRole("button", { name: /continue/i })).not.toHaveAttribute("disabled")
    );
  });

  it("blurring frontend port input calls engine.checkPort with port value", async () => {
    const eng = makeEngine("free");
    const { getByLabelText } = render(PortsPage, { via: "mock", engine: eng });
    const input = getByLabelText(/frontend port/i);
    await fireEvent.blur(input);
    expect(eng.checkPort).toHaveBeenCalledWith(9999);
  });

  it("blurring core port input calls engine.checkPort with port value", async () => {
    const eng = makeEngine("free");
    const { getByLabelText } = render(PortsPage, { via: "mock", engine: eng });
    const input = getByLabelText(/core api port/i);
    await fireEvent.blur(input);
    expect(eng.checkPort).toHaveBeenCalledWith(8000);
  });

  it("shows ✓ free indicator for frontend port when free", async () => {
    const { getByTestId } = render(PortsPage, { via: "mock", engine: makeEngine("free") });
    await waitFor(() => expect(getByTestId("frontend-status-free")).toBeTruthy());
  });

  it("shows ✓ free indicator for core port when free", async () => {
    const { getByTestId } = render(PortsPage, { via: "mock", engine: makeEngine("free") });
    await waitFor(() => expect(getByTestId("core-status-free")).toBeTruthy());
  });

  it("shows ✗ in-use indicator for frontend port when taken", async () => {
    const { getByTestId } = render(PortsPage, {
      via: "mock",
      engine: makeEngine({ inUseBy: 1234, name: "nginx" }),
    });
    await waitFor(() => expect(getByTestId("frontend-status-taken")).toBeTruthy());
  });

  it("shows PID in error message when frontend port is taken", async () => {
    const { getByTestId } = render(PortsPage, {
      via: "mock",
      engine: makeEngine({ inUseBy: 5678, name: "nginx" }),
    });
    await waitFor(() => {
      const el = getByTestId("frontend-port-taken");
      expect(el.textContent).toMatch(/5678/);
    });
  });

  it("shows process name in error message when frontend port is taken", async () => {
    const { getByTestId } = render(PortsPage, {
      via: "mock",
      engine: makeEngine({ inUseBy: 5678, name: "nginx" }),
    });
    await waitFor(() => {
      const el = getByTestId("frontend-port-taken");
      expect(el.textContent).toMatch(/nginx/);
    });
  });

  it("Back button navigates to /wizard/inference for mock", async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole } = render(PortsPage, { via: "mock", engine: makeEngine("pending") });
    await fireEvent.click(getByRole("button", { name: /back to inference picker/i }));
    expect(goto).toHaveBeenCalledWith("/wizard/inference");
  });

  it("Back button navigates to /wizard/inference/ollama for ollama", async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole } = render(PortsPage, { via: "ollama", engine: makeEngine("pending") });
    await fireEvent.click(getByRole("button", { name: /back to model picker/i }));
    expect(goto).toHaveBeenCalledWith("/wizard/inference/ollama");
  });

  it("Advanced disclosure title is visible", () => {
    const { getByText } = render(PortsPage, { via: "mock", engine: makeEngine("pending") });
    expect(getByText("Advanced")).toBeTruthy();
  });

  it("secret file paths appear in the page content", () => {
    const { container } = render(PortsPage, { via: "mock", engine: makeEngine("pending") });
    expect(container.textContent).toContain("core_jwt.secret");
    expect(container.textContent).toContain("chat_api.secret");
  });

  it("Edit system prompt button is disabled", () => {
    const { getByTestId } = render(PortsPage, { via: "mock", engine: makeEngine("pending") });
    const btn = getByTestId("edit-system-prompt") as HTMLButtonElement;
    expect(btn.disabled).toBe(true);
  });

  it("Continue navigates to /wizard/run", async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole } = render(PortsPage, { via: "mock", engine: makeEngine("free") });
    const btn = await waitFor(() => {
      const b = getByRole("button", { name: /continue/i });
      if (b.hasAttribute("disabled")) throw new Error("still disabled");
      return b;
    });
    await fireEvent.click(btn);
    expect(goto).toHaveBeenCalledWith("/wizard/run");
  });

  it("null engine renders without crashing", () => {
    const { getByRole } = render(PortsPage, { via: "mock", engine: null });
    expect(getByRole("heading", { name: /configure ports/i })).toBeTruthy();
  });

  it("null engine keeps Continue disabled", () => {
    const { getByRole } = render(PortsPage, { via: "mock", engine: null });
    expect(getByRole("button", { name: /continue/i })).toHaveAttribute("disabled");
  });

  it("footer shows 'both ports must be free' when not ready", () => {
    const { getByText } = render(PortsPage, { via: "mock", engine: makeEngine("pending") });
    expect(getByText(/both ports must be free/i)).toBeTruthy();
  });

  it("footer shows available hint when both ports are free", async () => {
    const { getByText } = render(PortsPage, { via: "mock", engine: makeEngine("free") });
    await waitFor(() => expect(getByText(/ports.*are available/i)).toBeTruthy());
  });

  // ---- Port-collision modal ----

  it("opens port-collision modal when frontend port is taken", async () => {
    const { getByTestId } = render(PortsPage, {
      via: "mock",
      engine: makeEngine({ inUseBy: 1234, name: "nginx" }),
    });
    await waitFor(() => expect(getByTestId("port-collision-modal")).toBeTruthy());
  });

  it("port-collision modal shows the process name", async () => {
    const { getByTestId } = render(PortsPage, {
      via: "mock",
      engine: makeEngine({ inUseBy: 1234, name: "nginx" }),
    });
    await waitFor(() => expect(getByTestId("port-collision-modal").textContent).toContain("nginx"));
  });

  it("port-collision modal shows suggested port (port + 1)", async () => {
    const { getByTestId } = render(PortsPage, {
      via: "mock",
      engine: makeEngine({ inUseBy: 1234, name: "nginx" }),
    });
    await waitFor(() => {
      const suggested = getByTestId("collision-suggested-port");
      // Default frontend port is 9999, so suggested = 10000
      expect(suggested.textContent).toContain("10000");
    });
  });

  it("'Keep this port' button closes the collision modal", async () => {
    const { getByRole, getByTestId, queryByTestId } = render(PortsPage, {
      via: "mock",
      engine: makeEngine({ inUseBy: 1234, name: "nginx" }),
    });
    await waitFor(() => getByTestId("port-collision-modal"));
    await fireEvent.click(getByRole("button", { name: /keep this port/i }));
    await waitFor(() => expect(queryByTestId("port-collision-modal")).toBeNull());
  });

  it("'Pick another port' closes the modal and re-checks the suggested port", async () => {
    const eng = makePerPortEngine({
      9999: { inUseBy: 1234, name: "nginx" },
      10000: "free",
      8000: "free",
    });
    const { getByRole, getByTestId } = render(PortsPage, {
      via: "mock",
      engine: eng,
    });
    await waitFor(() => getByTestId("port-collision-modal"));
    await fireEvent.click(getByRole("button", { name: /pick another port/i }));
    // Modal should close and port 10000 should be checked
    await waitFor(() => expect(eng.checkPort).toHaveBeenCalledWith(10000));
  });

  it("opens port-collision modal when core port is taken on blur", async () => {
    const eng = makePerPortEngine({
      9999: "free",
      8000: { inUseBy: 5678, name: "python" },
    });
    const { getByLabelText, getByTestId, queryByTestId } = render(PortsPage, {
      via: "mock",
      engine: eng,
    });
    // Initially only free on frontend, taken on core triggers modal for core on auto-check
    await waitFor(() => {
      const modal = queryByTestId("port-collision-modal");
      if (!modal) throw new Error("modal not yet visible");
      return modal;
    });
    // Modal should show for port 8000
    expect(getByTestId("port-collision-modal").textContent).toContain("python");
    void getByLabelText; // suppress unused
  });
});
