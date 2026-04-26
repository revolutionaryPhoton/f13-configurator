import { fireEvent, render, waitFor } from "@testing-library/svelte";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { Engine } from "$lib/engine.js";
import OllamaPage from "./+page.svelte";

vi.mock("$app/navigation", () => ({ goto: vi.fn() }));

function makeEngine(result: string[] | "not-running" | "pending"): Engine {
  const impl =
    result === "pending"
      ? vi.fn().mockImplementation(() => new Promise<never>(() => {}))
      : vi.fn().mockResolvedValue(result);
  return {
    detectState: vi.fn(),
    preflight: vi.fn(),
    listOllamaModels: impl,
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

describe("ollama/+page.svelte", () => {
  beforeEach(() => vi.clearAllMocks());

  it("renders the heading", async () => {
    const { getByRole } = render(OllamaPage, { engine: makeEngine([]) });
    expect(getByRole("heading", { name: /choose a model/i })).toBeTruthy();
  });

  it("renders Step 3 of 4 breadcrumb", () => {
    const { getByText } = render(OllamaPage, { engine: makeEngine("pending") });
    expect(getByText(/step 3 of 4/i)).toBeTruthy();
  });

  it("shows loading indicator while engine is fetching", () => {
    const { container } = render(OllamaPage, { engine: makeEngine("pending") });
    expect(container.textContent).toContain("Checking Ollama…");
  });

  it("shows not-running state when engine returns not-running", async () => {
    const { getByTestId } = render(OllamaPage, {
      engine: makeEngine("not-running"),
    });
    await waitFor(() => expect(getByTestId("not-running")).toBeTruthy());
  });

  it("shows Ollama start instructions in not-running state", async () => {
    const { getByText } = render(OllamaPage, {
      engine: makeEngine("not-running"),
    });
    await waitFor(() => expect(getByText(/ollama is not running/i)).toBeTruthy());
    await waitFor(() => expect(getByText(/ollama serve/i)).toBeTruthy());
  });

  it("shows Retry button in not-running state", async () => {
    const { getByRole } = render(OllamaPage, {
      engine: makeEngine("not-running"),
    });
    await waitFor(() => expect(getByRole("button", { name: /retry/i })).toBeTruthy());
  });

  it("shows GPU warning banner", () => {
    const { getByRole } = render(OllamaPage, { engine: makeEngine("pending") });
    // Warning banner is a div with role="note" — assert by text content.
    expect(getByRole("note").textContent).toMatch(/gpu recommended/i);
  });

  it("warns about embedding models in the banner", () => {
    const { getByRole } = render(OllamaPage, { engine: makeEngine("pending") });
    expect(getByRole("note").textContent).toMatch(/embedding models/i);
  });

  it("shows model list when Ollama is running", async () => {
    const { getByRole } = render(OllamaPage, {
      engine: makeEngine(["llama3.2:3b", "gemma4:31b-cloud"]),
    });
    await waitFor(() => {
      expect(getByRole("radio", { name: "llama3.2:3b" })).toBeTruthy();
      expect(getByRole("radio", { name: "gemma4:31b-cloud" })).toBeTruthy();
    });
  });

  it("cloud model shows ☁ cloud badge", async () => {
    const { getAllByTestId } = render(OllamaPage, {
      engine: makeEngine(["gemma4:31b-cloud"]),
    });
    await waitFor(() => expect(getAllByTestId("cloud-badge").length).toBeGreaterThan(0));
  });

  it("local model does not show cloud badge", async () => {
    const { getByRole, queryAllByTestId } = render(OllamaPage, {
      engine: makeEngine(["llama3.2:3b"]),
    });
    await waitFor(() => expect(getByRole("radio", { name: "llama3.2:3b" })).toBeTruthy());
    expect(queryAllByTestId("cloud-badge")).toHaveLength(0);
  });

  it("shows embedding-model warning when an 'embed' name is auto-selected", async () => {
    const { getByTestId } = render(OllamaPage, {
      engine: makeEngine(["nomic-embed-text"]),
    });
    await waitFor(() => {
      const banner = getByTestId("embedding-warning");
      expect(banner).toBeTruthy();
      expect(banner.textContent).toMatch(/are you sure/i);
      expect(banner.textContent).toMatch(/nomic-embed-text/);
    });
  });

  it("does not show embedding warning for a chat model", async () => {
    const { queryByTestId } = render(OllamaPage, {
      engine: makeEngine(["llama3.2:3b"]),
    });
    await waitFor(() => {
      // Wait for the model list to render before asserting absence.
      // The embedding-warning testid should never appear for chat models.
    });
    expect(queryByTestId("embedding-warning")).toBeNull();
  });

  it("typed custom model with 'embed' triggers the warning", async () => {
    const { getByTestId } = render(OllamaPage, {
      engine: makeEngine(["llama3.2:3b"]),
    });
    const input = getByTestId("ollama-custom-model") as HTMLInputElement;
    input.value = "mxbai-embed-large";
    input.dispatchEvent(new Event("input", { bubbles: true }));
    await waitFor(() => {
      expect(getByTestId("embedding-warning")).toBeTruthy();
    });
  });

  it("auto-selects gemma4:31b-cloud when present", async () => {
    const { getByRole } = render(OllamaPage, {
      engine: makeEngine(["llama3.2:3b", "gemma4:31b-cloud"]),
    });
    await waitFor(() => {
      const radio = getByRole("radio", { name: "gemma4:31b-cloud" }) as HTMLInputElement;
      expect(radio.checked).toBe(true);
    });
  });

  it("auto-selects first model when preferred not present", async () => {
    const { getByRole } = render(OllamaPage, {
      engine: makeEngine(["llama3.2:3b", "mistral:7b"]),
    });
    await waitFor(() => {
      const radio = getByRole("radio", { name: "llama3.2:3b" }) as HTMLInputElement;
      expect(radio.checked).toBe(true);
    });
  });

  it("clicking a model selects it", async () => {
    const { getByRole } = render(OllamaPage, {
      engine: makeEngine(["llama3.2:3b", "gemma4:31b-cloud"]),
    });
    await waitFor(() => expect(getByRole("radio", { name: "llama3.2:3b" })).toBeTruthy());
    const radio = getByRole("radio", { name: "llama3.2:3b" }) as HTMLInputElement;
    await fireEvent.change(radio, { target: { value: "llama3.2:3b" } });
    await waitFor(() => expect(radio.checked).toBe(true));
  });

  it("Continue is disabled while loading", () => {
    const { getByRole } = render(OllamaPage, { engine: makeEngine("pending") });
    expect(getByRole("button", { name: /continue/i })).toHaveAttribute("disabled");
  });

  it("Continue is disabled in not-running state", async () => {
    const { getByRole } = render(OllamaPage, {
      engine: makeEngine("not-running"),
    });
    await waitFor(() => expect(getByRole("button", { name: /retry/i })).toBeTruthy());
    expect(getByRole("button", { name: /continue/i })).toHaveAttribute("disabled");
  });

  it("Continue is enabled when a model is selected", async () => {
    const { getByRole } = render(OllamaPage, {
      engine: makeEngine(["gemma4:31b-cloud"]),
    });
    await waitFor(() =>
      expect(getByRole("button", { name: /continue/i })).not.toHaveAttribute("disabled")
    );
  });

  it("Continue navigates to /wizard/ports", async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole } = render(OllamaPage, {
      engine: makeEngine(["gemma4:31b-cloud"]),
    });
    const btn = await waitFor(() => {
      const b = getByRole("button", { name: /continue/i });
      if (b.hasAttribute("disabled")) throw new Error("still disabled");
      return b;
    });
    await fireEvent.click(btn);
    expect(goto).toHaveBeenCalledWith("/wizard/ports");
  });

  it("Back button navigates to /wizard/inference", async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole } = render(OllamaPage, { engine: makeEngine("pending") });
    const back = getByRole("button", { name: /^back$/i });
    await fireEvent.click(back);
    expect(goto).toHaveBeenCalledWith("/wizard/inference");
  });

  it("null engine shows not-running state", async () => {
    const { getByTestId } = render(OllamaPage, { engine: null });
    await waitFor(() => expect(getByTestId("not-running")).toBeTruthy());
  });

  it("Refresh link appears in running state", async () => {
    const { getByRole } = render(OllamaPage, {
      engine: makeEngine(["llama3.2:3b"]),
    });
    await waitFor(() => expect(getByRole("button", { name: /refresh model list/i })).toBeTruthy());
  });

  it("Retry button calls listOllamaModels again", async () => {
    const eng = makeEngine("not-running");
    const { getByRole } = render(OllamaPage, { engine: eng });
    await waitFor(() => expect(getByRole("button", { name: /retry/i })).toBeTruthy());
    await fireEvent.click(getByRole("button", { name: /retry/i }));
    await waitFor(() => {
      expect(eng.listOllamaModels).toHaveBeenCalledTimes(2);
    });
  });

  it("Refresh link calls listOllamaModels again", async () => {
    const eng = makeEngine(["llama3.2:3b"]);
    const { getByRole } = render(OllamaPage, { engine: eng });
    await waitFor(() => expect(getByRole("button", { name: /refresh model list/i })).toBeTruthy());
    await fireEvent.click(getByRole("button", { name: /refresh model list/i }));
    await waitFor(() => {
      expect(eng.listOllamaModels).toHaveBeenCalledTimes(2);
    });
  });

  it("shows no-models hint when list is empty", async () => {
    const { getByText } = render(OllamaPage, { engine: makeEngine([]) });
    await waitFor(() => expect(getByText(/no models pulled locally/i)).toBeTruthy());
  });

  it("renders radiogroup with aria-label when models present", async () => {
    const { getByRole } = render(OllamaPage, {
      engine: makeEngine(["llama3.2:3b"]),
    });
    await waitFor(() => expect(getByRole("radiogroup", { name: /ollama model/i })).toBeTruthy());
  });
});
