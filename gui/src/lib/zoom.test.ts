import { get } from "svelte/store";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  clampZoom,
  ZOOM_DEFAULT,
  ZOOM_KEY,
  ZOOM_MAX,
  ZOOM_MIN,
  zoom,
  zoomKeyHandler,
} from "./zoom.js";

// ---------------------------------------------------------------------------
// clampZoom — pure function
// ---------------------------------------------------------------------------

describe("clampZoom", () => {
  it("returns value unchanged when within range", () => {
    expect(clampZoom(1.0)).toBe(1.0);
    expect(clampZoom(1.5)).toBe(1.5);
  });

  it("clamps below minimum to ZOOM_MIN", () => {
    expect(clampZoom(0.1)).toBe(ZOOM_MIN);
    expect(clampZoom(-1)).toBe(ZOOM_MIN);
  });

  it("clamps above maximum to ZOOM_MAX", () => {
    expect(clampZoom(3.0)).toBe(ZOOM_MAX);
    expect(clampZoom(99)).toBe(ZOOM_MAX);
  });

  it("rounds to one decimal place", () => {
    expect(clampZoom(1.04)).toBe(1.0);
    expect(clampZoom(1.05)).toBe(1.1);
    expect(clampZoom(1.94)).toBe(1.9);
    expect(clampZoom(1.95)).toBe(2.0);
  });
});

// ---------------------------------------------------------------------------
// zoomKeyHandler — callback-based, no side effects
// ---------------------------------------------------------------------------

describe("zoomKeyHandler", () => {
  function makeEvent(key: string, meta: boolean): KeyboardEvent {
    return new KeyboardEvent("keydown", {
      key,
      ctrlKey: meta,
      metaKey: false,
      cancelable: true,
      bubbles: true,
    });
  }

  it("consumes Ctrl++ and calls inFn", () => {
    const inFn = vi.fn();
    const e = makeEvent("+", true);
    expect(zoomKeyHandler(e, inFn, vi.fn(), vi.fn())).toBe(true);
    expect(inFn).toHaveBeenCalledOnce();
  });

  it("consumes Ctrl+= and calls inFn (US keyboard unshifted)", () => {
    const inFn = vi.fn();
    const e = makeEvent("=", true);
    expect(zoomKeyHandler(e, inFn, vi.fn(), vi.fn())).toBe(true);
    expect(inFn).toHaveBeenCalledOnce();
  });

  it("consumes Ctrl+- and calls outFn", () => {
    const outFn = vi.fn();
    const e = makeEvent("-", true);
    expect(zoomKeyHandler(e, vi.fn(), outFn, vi.fn())).toBe(true);
    expect(outFn).toHaveBeenCalledOnce();
  });

  it("consumes Ctrl+0 and calls resetFn", () => {
    const resetFn = vi.fn();
    const e = makeEvent("0", true);
    expect(zoomKeyHandler(e, vi.fn(), vi.fn(), resetFn)).toBe(true);
    expect(resetFn).toHaveBeenCalledOnce();
  });

  it("ignores keys without meta modifier", () => {
    const inFn = vi.fn();
    const e = makeEvent("+", false);
    expect(zoomKeyHandler(e, inFn, vi.fn(), vi.fn())).toBe(false);
    expect(inFn).not.toHaveBeenCalled();
  });

  it("ignores unrelated meta keys", () => {
    const inFn = vi.fn();
    const e = makeEvent("a", true);
    expect(zoomKeyHandler(e, inFn, vi.fn(), vi.fn())).toBe(false);
    expect(inFn).not.toHaveBeenCalled();
  });
});

// ---------------------------------------------------------------------------
// zoom store — operations and localStorage persistence
// ---------------------------------------------------------------------------

describe("zoom store", () => {
  beforeEach(() => {
    localStorage.clear();
    zoom.reset();
  });

  it("starts at ZOOM_DEFAULT (1.0)", () => {
    expect(get(zoom)).toBe(ZOOM_DEFAULT);
  });

  it("zoomIn increments by 0.1", () => {
    zoom.zoomIn();
    expect(get(zoom)).toBe(1.1);
  });

  it("zoomOut decrements by 0.1", () => {
    zoom.zoomOut();
    expect(get(zoom)).toBe(0.9);
  });

  it("chained zoomIn calls accumulate", () => {
    zoom.zoomIn();
    zoom.zoomIn();
    expect(get(zoom)).toBe(1.2);
  });

  it("zoomIn clamps at ZOOM_MAX", () => {
    zoom.setZoom(ZOOM_MAX);
    zoom.zoomIn();
    expect(get(zoom)).toBe(ZOOM_MAX);
  });

  it("zoomOut clamps at ZOOM_MIN", () => {
    zoom.setZoom(ZOOM_MIN);
    zoom.zoomOut();
    expect(get(zoom)).toBe(ZOOM_MIN);
  });

  it("reset returns to ZOOM_DEFAULT", () => {
    zoom.zoomIn();
    zoom.zoomIn();
    zoom.reset();
    expect(get(zoom)).toBe(ZOOM_DEFAULT);
  });

  it("reset removes localStorage key", () => {
    zoom.zoomIn();
    zoom.reset();
    expect(localStorage.getItem(ZOOM_KEY)).toBeNull();
  });

  it("zoomIn persists value to localStorage", () => {
    zoom.zoomIn();
    expect(localStorage.getItem(ZOOM_KEY)).toBe("1.1");
  });

  it("zoomOut persists value to localStorage", () => {
    zoom.zoomOut();
    expect(localStorage.getItem(ZOOM_KEY)).toBe("0.9");
  });

  it("setZoom persists clamped value", () => {
    zoom.setZoom(1.5);
    expect(get(zoom)).toBe(1.5);
    expect(localStorage.getItem(ZOOM_KEY)).toBe("1.5");
  });

  it("setZoom clamps above ZOOM_MAX", () => {
    zoom.setZoom(5.0);
    expect(get(zoom)).toBe(ZOOM_MAX);
  });

  it("setZoom clamps below ZOOM_MIN", () => {
    zoom.setZoom(0.1);
    expect(get(zoom)).toBe(ZOOM_MIN);
  });

  it("setZoom(ZOOM_DEFAULT) removes localStorage key", () => {
    zoom.setZoom(1.5);
    zoom.setZoom(ZOOM_DEFAULT);
    expect(localStorage.getItem(ZOOM_KEY)).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// zoom store — fresh module initialises from localStorage
// ---------------------------------------------------------------------------

describe("zoom store — init from localStorage", () => {
  afterEach(() => {
    localStorage.clear();
    vi.resetModules();
  });

  it("reads stored zoom factor on module load", async () => {
    localStorage.setItem(ZOOM_KEY, "1.4");
    vi.resetModules();
    const { zoom: freshZoom } = await import("./zoom.js");
    expect(get(freshZoom)).toBe(1.4);
  });

  it("falls back to ZOOM_DEFAULT when localStorage is empty", async () => {
    vi.resetModules();
    const { zoom: freshZoom, ZOOM_DEFAULT: def } = await import("./zoom.js");
    expect(get(freshZoom)).toBe(def);
  });

  it("clamps stored value outside range on load", async () => {
    localStorage.setItem(ZOOM_KEY, "99");
    vi.resetModules();
    const { zoom: freshZoom, ZOOM_MAX: max } = await import("./zoom.js");
    expect(get(freshZoom)).toBe(max);
  });
});
