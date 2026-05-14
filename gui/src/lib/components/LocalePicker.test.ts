import { fireEvent, render } from "@testing-library/svelte";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { setLocale } from "$lib/i18n/index.js";
import LocalePicker from "./LocalePicker.svelte";

// jsdom doesn't implement location.reload — stub it.
const reloadMock = vi.fn();
vi.stubGlobal("location", { ...window.location, reload: reloadMock });

describe("LocalePicker", () => {
  beforeEach(() => {
    setLocale("en");
    reloadMock.mockClear();
    localStorage.clear();
  });

  afterEach(() => {
    setLocale("en");
    localStorage.clear();
  });

  it("renders buttons for all four locales", () => {
    const { getByRole } = render(LocalePicker);
    expect(getByRole("button", { name: /english/i })).toBeTruthy();
    expect(getByRole("button", { name: /german/i })).toBeTruthy();
    expect(getByRole("button", { name: /french/i })).toBeTruthy();
    expect(getByRole("button", { name: /spanish/i })).toBeTruthy();
  });

  it("marks English as active by default (aria-pressed=true)", () => {
    const { getByRole } = render(LocalePicker);
    expect(getByRole("button", { name: /english \(current\)/i }).getAttribute("aria-pressed")).toBe(
      "true"
    );
  });

  it("marks other locales as inactive (aria-pressed=false)", () => {
    const { getByRole } = render(LocalePicker);
    expect(getByRole("button", { name: /^german$/i }).getAttribute("aria-pressed")).toBe("false");
    expect(getByRole("button", { name: /^french$/i }).getAttribute("aria-pressed")).toBe("false");
    expect(getByRole("button", { name: /^spanish$/i }).getAttribute("aria-pressed")).toBe("false");
  });

  it("clicking an inactive locale calls window.location.reload", async () => {
    const { getByRole } = render(LocalePicker);
    await fireEvent.click(getByRole("button", { name: /^german$/i }));
    expect(reloadMock).toHaveBeenCalledOnce();
  });

  it("clicking an inactive locale persists it to localStorage", async () => {
    const { getByRole } = render(LocalePicker);
    await fireEvent.click(getByRole("button", { name: /^french$/i }));
    expect(localStorage.getItem("f13_locale")).toBe("fr");
  });

  it("clicking the active locale does NOT reload", async () => {
    const { getByRole } = render(LocalePicker);
    await fireEvent.click(getByRole("button", { name: /english \(current\)/i }));
    expect(reloadMock).not.toHaveBeenCalled();
  });

  it("has a group role with accessible label 'Language'", () => {
    const { getByRole } = render(LocalePicker);
    expect(getByRole("group", { name: /language/i })).toBeTruthy();
  });
});
