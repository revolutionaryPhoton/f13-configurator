import { fireEvent, render, waitFor } from "@testing-library/svelte";
import { beforeEach, describe, expect, it, vi } from "vitest";
import InferencePage from "./+page.svelte";

vi.mock("$app/navigation", () => ({ goto: vi.fn() }));

function getRadio(radios: HTMLElement[], label: string): HTMLElement {
  const el = radios.find((r) => r.textContent?.includes(label));
  if (!el) throw new Error(`radio "${label}" not found`);
  return el;
}

describe("inference/+page.svelte", () => {
  beforeEach(() => vi.clearAllMocks());

  it("renders the heading", () => {
    const { getByRole } = render(InferencePage);
    expect(getByRole("heading", { name: /choose inference backend/i })).toBeTruthy();
  });

  it("renders Step 2 of 4 breadcrumb", () => {
    const { getByText } = render(InferencePage);
    expect(getByText(/step 2 of 4/i)).toBeTruthy();
  });

  it("renders Mock and Ollama tiles", () => {
    const { getByText } = render(InferencePage);
    expect(getByText("Mock")).toBeTruthy();
    expect(getByText("Ollama")).toBeTruthy();
  });

  it("Mock tile has Recommended badge", () => {
    const { getByText } = render(InferencePage);
    // Exact match to avoid colliding with "GPU recommended" in Ollama cons
    expect(getByText("Recommended")).toBeTruthy();
  });

  it("Continue is disabled when nothing is selected", () => {
    const { getByRole } = render(InferencePage);
    expect(getByRole("button", { name: /continue/i })).toHaveAttribute("disabled");
  });

  it("clicking Mock tile selects it (aria-checked=true)", async () => {
    const { getAllByRole } = render(InferencePage);
    const mockRadio = getRadio(getAllByRole("radio"), "Mock");
    await fireEvent.click(mockRadio);
    await waitFor(() => expect(mockRadio).toHaveAttribute("aria-checked", "true"));
  });

  it("clicking Ollama tile selects it (aria-checked=true)", async () => {
    const { getAllByRole } = render(InferencePage);
    const ollamaRadio = getRadio(getAllByRole("radio"), "Ollama");
    await fireEvent.click(ollamaRadio);
    await waitFor(() => expect(ollamaRadio).toHaveAttribute("aria-checked", "true"));
  });

  it("selecting Mock unselects Ollama", async () => {
    const { getAllByRole } = render(InferencePage);
    const radios = getAllByRole("radio");
    const mockRadio = getRadio(radios, "Mock");
    const ollamaRadio = getRadio(radios, "Ollama");

    await fireEvent.click(ollamaRadio);
    await waitFor(() => expect(ollamaRadio).toHaveAttribute("aria-checked", "true"));

    await fireEvent.click(mockRadio);
    await waitFor(() => {
      expect(mockRadio).toHaveAttribute("aria-checked", "true");
      expect(ollamaRadio).toHaveAttribute("aria-checked", "false");
    });
  });

  it("Continue is enabled after selecting Mock", async () => {
    const { getByRole, getAllByRole } = render(InferencePage);
    await fireEvent.click(getRadio(getAllByRole("radio"), "Mock"));
    await waitFor(() =>
      expect(getByRole("button", { name: /continue/i })).not.toHaveAttribute("disabled")
    );
  });

  it("Continue is enabled after selecting Ollama", async () => {
    const { getByRole, getAllByRole } = render(InferencePage);
    await fireEvent.click(getRadio(getAllByRole("radio"), "Ollama"));
    await waitFor(() =>
      expect(getByRole("button", { name: /continue/i })).not.toHaveAttribute("disabled")
    );
  });

  it("Continue navigates to /wizard/ports when Mock is selected", async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole, getAllByRole } = render(InferencePage);
    await fireEvent.click(getRadio(getAllByRole("radio"), "Mock"));
    const btn = await waitFor(() => {
      const b = getByRole("button", { name: /continue/i });
      if (b.hasAttribute("disabled")) throw new Error("still disabled");
      return b;
    });
    await fireEvent.click(btn);
    expect(goto).toHaveBeenCalledWith("/wizard/ports");
  });

  it("Continue navigates to /wizard/inference/ollama when Ollama is selected", async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole, getAllByRole } = render(InferencePage);
    await fireEvent.click(getRadio(getAllByRole("radio"), "Ollama"));
    const btn = await waitFor(() => {
      const b = getByRole("button", { name: /continue/i });
      if (b.hasAttribute("disabled")) throw new Error("still disabled");
      return b;
    });
    await fireEvent.click(btn);
    expect(goto).toHaveBeenCalledWith("/wizard/inference/ollama");
  });

  it("Back button navigates to /wizard/preflight", async () => {
    const { goto } = await import("$app/navigation");
    const { getByRole } = render(InferencePage);
    const back = getByRole("button", { name: /back to preflight/i });
    await fireEvent.click(back);
    expect(goto).toHaveBeenCalledWith("/wizard/preflight");
  });

  it("footer hint says 'Select a backend' initially", () => {
    const { getByText } = render(InferencePage);
    expect(getByText(/select a backend to continue/i)).toBeTruthy();
  });

  it("footer hint updates when Mock is selected", async () => {
    const { getByText, getAllByRole } = render(InferencePage);
    await fireEvent.click(getRadio(getAllByRole("radio"), "Mock"));
    await waitFor(() => expect(getByText(/mock selected/i)).toBeTruthy());
  });

  it("footer hint updates when Ollama is selected", async () => {
    const { getByText, getAllByRole } = render(InferencePage);
    await fireEvent.click(getRadio(getAllByRole("radio"), "Ollama"));
    await waitFor(() => expect(getByText(/ollama selected/i)).toBeTruthy());
  });

  it("renders a radiogroup with aria-label", () => {
    const { getByRole } = render(InferencePage);
    expect(getByRole("radiogroup", { name: /inference backend/i })).toBeTruthy();
  });
});
