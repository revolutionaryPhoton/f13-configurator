import { fireEvent, render, waitFor } from "@testing-library/svelte";
import { beforeEach, describe, expect, it, vi } from "vitest";
import SettingsPage from "./+page.svelte";

vi.mock("$app/navigation", () => ({ goto: vi.fn() }));
vi.mock("$lib/theme.js", () => ({
  getTheme: vi.fn().mockReturnValue("system"),
  setTheme: vi.fn(),
  applyTheme: vi.fn(),
}));

import { goto } from "$app/navigation";
import { setTheme as persistTheme } from "$lib/theme.js";

describe("settings/+page.svelte", () => {
  beforeEach(() => vi.clearAllMocks());

  it("renders the Settings heading", () => {
    const { getByRole } = render(SettingsPage);
    expect(getByRole("heading", { level: 1, name: /settings/i })).toBeTruthy();
  });

  it("renders theme radiogroup with system/light/dark options", () => {
    const { getByTestId } = render(SettingsPage);
    for (const opt of ["system", "light", "dark"]) {
      expect(getByTestId(`theme-${opt}`)).toBeTruthy();
    }
  });

  it("system theme is selected by default (aria-checked)", async () => {
    const { getByTestId } = render(SettingsPage);
    await waitFor(() =>
      expect(getByTestId("theme-system").getAttribute("aria-checked")).toBe("true")
    );
  });

  it("clicking a theme option calls persistTheme with that value", async () => {
    const { getByTestId } = render(SettingsPage);
    await fireEvent.click(getByTestId("theme-dark"));
    expect(persistTheme).toHaveBeenCalledWith("dark");
  });

  it("clicked theme option becomes selected (aria-checked)", async () => {
    const { getByTestId } = render(SettingsPage);
    await fireEvent.click(getByTestId("theme-light"));
    await waitFor(() =>
      expect(getByTestId("theme-light").getAttribute("aria-checked")).toBe("true")
    );
  });

  it("renders four config file accordion toggles", () => {
    const { getByTestId } = render(SettingsPage);
    expect(getByTestId("toggle-docker-compose.yml")).toBeTruthy();
    expect(getByTestId("toggle-.env")).toBeTruthy();
    expect(getByTestId("toggle-core/general.yml")).toBeTruthy();
    expect(getByTestId("toggle-chat/llm_models.yml")).toBeTruthy();
  });

  it("toggling a file loads and displays its content", async () => {
    const yaml = "services:\n  core:\n";
    const readFile = vi.fn().mockResolvedValue(yaml);
    const { getByTestId } = render(SettingsPage, {
      props: { readFile, generatedDir: "/gen" },
    });
    await fireEvent.click(getByTestId("toggle-docker-compose.yml"));
    await waitFor(() => expect(getByTestId("content-docker-compose.yml")).toBeTruthy());
    expect(readFile).toHaveBeenCalledWith("/gen/docker-compose.yml");
    expect(getByTestId("content-docker-compose.yml").textContent).toContain("services");
  });

  it("shows error when readFile rejects", async () => {
    const readFile = vi.fn().mockRejectedValue(new Error("not found"));
    const { getByTestId } = render(SettingsPage, { props: { readFile } });
    await fireEvent.click(getByTestId("toggle-.env"));
    await waitFor(() => expect(getByTestId("error-.env")).toBeTruthy());
    expect(getByTestId("error-.env").textContent).toContain("not found");
  });

  it("shows 'not available' error when no readFile prop given", async () => {
    const { getByTestId } = render(SettingsPage);
    await fireEvent.click(getByTestId("toggle-.env"));
    await waitFor(() => expect(getByTestId("error-.env")).toBeTruthy());
    expect(getByTestId("error-.env").textContent).toContain("not available");
  });

  it("copy button appears after file loads", async () => {
    const readFile = vi.fn().mockResolvedValue("content");
    const { getByTestId } = render(SettingsPage, { props: { readFile } });
    await fireEvent.click(getByTestId("toggle-.env"));
    await waitFor(() => expect(getByTestId("copy-.env")).toBeTruthy());
  });

  it("clicking copy calls copyToClipboard with file content", async () => {
    const readFile = vi.fn().mockResolvedValue("key: value\n");
    const copyToClipboard = vi.fn().mockResolvedValue(undefined);
    const { getByTestId } = render(SettingsPage, {
      props: { readFile, copyToClipboard },
    });
    await fireEvent.click(getByTestId("toggle-.env"));
    await waitFor(() => expect(getByTestId("copy-.env")).toBeTruthy());
    await fireEvent.click(getByTestId("copy-.env"));
    await waitFor(() => expect(copyToClipboard).toHaveBeenCalledWith("key: value\n"));
  });

  it("copy success shows a success toast", async () => {
    const readFile = vi.fn().mockResolvedValue("yaml");
    const copyToClipboard = vi.fn().mockResolvedValue(undefined);
    const { getByTestId, getByRole } = render(SettingsPage, {
      props: { readFile, copyToClipboard },
    });
    await fireEvent.click(getByTestId("toggle-.env"));
    await waitFor(() => expect(getByTestId("copy-.env")).toBeTruthy());
    await fireEvent.click(getByTestId("copy-.env"));
    await waitFor(() => expect(getByRole("status")).toBeTruthy());
  });

  it("copy failure shows an error toast", async () => {
    const readFile = vi.fn().mockResolvedValue("yaml");
    const copyToClipboard = vi.fn().mockRejectedValue(new Error("no clipboard"));
    const { getByTestId, getByRole } = render(SettingsPage, {
      props: { readFile, copyToClipboard },
    });
    await fireEvent.click(getByTestId("toggle-.env"));
    await waitFor(() => expect(getByTestId("copy-.env")).toBeTruthy());
    await fireEvent.click(getByTestId("copy-.env"));
    await waitFor(() => expect(getByRole("alert")).toBeTruthy());
  });

  it("renders edit-prompt button with aria-disabled=true", () => {
    const { getByTestId } = render(SettingsPage);
    expect(getByTestId("edit-prompt-btn").getAttribute("aria-disabled")).toBe("true");
  });

  it("clicking edit-prompt button opens coming-soon modal", async () => {
    const { getByTestId, getByRole } = render(SettingsPage);
    await fireEvent.click(getByTestId("edit-prompt-btn"));
    await waitFor(() =>
      expect(getByRole("dialog", { name: /custom system prompts/i })).toBeTruthy()
    );
  });

  it("coming-soon modal shows roadmap text", async () => {
    const { getByTestId, getByText } = render(SettingsPage);
    await fireEvent.click(getByTestId("edit-prompt-btn"));
    await waitFor(() => expect(getByText(/roadmap/i)).toBeTruthy());
  });

  it("Got it button closes the coming-soon modal", async () => {
    const { getByTestId, getByRole, queryByRole } = render(SettingsPage);
    await fireEvent.click(getByTestId("edit-prompt-btn"));
    await waitFor(() => expect(getByRole("dialog")).toBeTruthy());
    await fireEvent.click(getByRole("button", { name: /got it/i }));
    await waitFor(() => expect(queryByRole("dialog")).toBeFalsy());
  });

  it("back button navigates to /status", async () => {
    const { getByRole } = render(SettingsPage);
    await fireEvent.click(getByRole("button", { name: /back to status/i }));
    expect(goto).toHaveBeenCalledWith("/status");
  });
});
