import { fireEvent, render, waitFor } from "@testing-library/svelte";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { Engine, StateEvent } from "$lib/engine.js";
import WelcomePage from "./+page.svelte";

vi.mock("$app/navigation", () => ({ goto: vi.fn() }));

function makeEngine(stateExists: boolean): Engine {
  const evt: StateEvent = stateExists
    ? {
        type: "state",
        exists: true,
        preset: "core+frontend+chat",
        backend: "mock",
        ollama_model: "",
        frontend_port: "9999",
        core_port: "8000",
        timestamp: "2026-04-25T00:00:00Z",
      }
    : { type: "state", exists: false };

  return {
    detectState: vi.fn().mockResolvedValue(evt),
    preflight: vi.fn(),
    listOllamaModels: vi.fn(),
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

describe("+page.svelte (Welcome screen)", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders the F13 Configurator heading", () => {
    const { getByRole } = render(WelcomePage, { engine: makeEngine(false) });
    expect(getByRole("heading", { name: /f13 configurator/i })).toBeTruthy();
  });

  it('renders the "Begin setup" button', () => {
    const { getByRole } = render(WelcomePage, { engine: makeEngine(false) });
    expect(getByRole("button", { name: /begin setup/i })).toBeTruthy();
  });

  it('hides "Open existing setup" when no state exists', async () => {
    const eng = makeEngine(false);
    const { queryByRole } = render(WelcomePage, { engine: eng });
    await waitFor(() => expect(eng.detectState).toHaveBeenCalled());
    expect(queryByRole("button", { name: /open existing setup/i })).toBeNull();
  });

  it('shows "Open existing setup" when state exists', async () => {
    const { getByRole } = render(WelcomePage, { engine: makeEngine(true) });
    await waitFor(() => expect(getByRole("button", { name: /open existing setup/i })).toBeTruthy());
  });

  it('navigates to /wizard/preflight when "Begin setup" is clicked', async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole } = render(WelcomePage, { engine: makeEngine(false) });
    await fireEvent.click(getByRole("button", { name: /begin setup/i }));
    expect(goto).toHaveBeenCalledWith("/wizard/preflight");
  });

  it('navigates to /status when "Open existing setup" is clicked', async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole } = render(WelcomePage, { engine: makeEngine(true) });
    const btn = await waitFor(() => getByRole("button", { name: /open existing setup/i }));
    await fireEvent.click(btn);
    expect(goto).toHaveBeenCalledWith("/status");
  });
});
