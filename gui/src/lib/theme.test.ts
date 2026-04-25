import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { applyTheme, getTheme, setTheme } from "./theme.js";

describe("theme", () => {
  beforeEach(() => {
    localStorage.clear();
    document.documentElement.classList.remove("dark");
  });

  afterEach(() => {
    localStorage.clear();
    document.documentElement.classList.remove("dark");
  });

  it("getTheme returns system by default", () => {
    expect(getTheme()).toBe("system");
  });

  it("getTheme returns the stored value", () => {
    localStorage.setItem("f13-theme", "dark");
    expect(getTheme()).toBe("dark");
  });

  it("getTheme returns light when stored", () => {
    localStorage.setItem("f13-theme", "light");
    expect(getTheme()).toBe("light");
  });

  it("setTheme persists to localStorage", () => {
    setTheme("light");
    expect(localStorage.getItem("f13-theme")).toBe("light");
  });

  it("applyTheme dark adds .dark on documentElement", () => {
    applyTheme("dark");
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });

  it("applyTheme light removes .dark from documentElement", () => {
    document.documentElement.classList.add("dark");
    applyTheme("light");
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });
});
