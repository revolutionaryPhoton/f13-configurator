import { writable } from "svelte/store";

export const ZOOM_KEY = "f13.configurator.zoom";
export const ZOOM_MIN = 0.6;
export const ZOOM_MAX = 2.0;
export const ZOOM_STEP = 0.1;
export const ZOOM_DEFAULT = 1.0;

/** Round to one decimal place, then clamp to [ZOOM_MIN, ZOOM_MAX]. */
export function clampZoom(value: number): number {
  return Math.min(ZOOM_MAX, Math.max(ZOOM_MIN, Math.round(value * 10) / 10));
}

/**
 * Handle a keydown event for zoom shortcuts (Ctrl/Cmd +/-/0).
 * Returns true if the event was consumed.
 */
export function zoomKeyHandler(
  e: KeyboardEvent,
  inFn: () => void,
  outFn: () => void,
  resetFn: () => void
): boolean {
  if (!e.ctrlKey && !e.metaKey) return false;
  if (e.key === "+" || e.key === "=") {
    e.preventDefault();
    inFn();
    return true;
  }
  if (e.key === "-") {
    e.preventDefault();
    outFn();
    return true;
  }
  if (e.key === "0") {
    e.preventDefault();
    resetFn();
    return true;
  }
  return false;
}

function readStored(): number {
  try {
    const raw = localStorage.getItem(ZOOM_KEY);
    if (!raw) return ZOOM_DEFAULT;
    const parsed = parseFloat(raw);
    return Number.isNaN(parsed) ? ZOOM_DEFAULT : clampZoom(parsed);
  } catch {
    return ZOOM_DEFAULT;
  }
}

function persist(value: number): void {
  try {
    if (value === ZOOM_DEFAULT) {
      localStorage.removeItem(ZOOM_KEY);
    } else {
      localStorage.setItem(ZOOM_KEY, String(value));
    }
  } catch {
    // localStorage unavailable (SSR, test isolation)
  }
}

function createZoomStore() {
  const { subscribe, set, update } = writable(readStored());
  return {
    subscribe,
    zoomIn() {
      update((v) => {
        const next = clampZoom(v + ZOOM_STEP);
        persist(next);
        return next;
      });
    },
    zoomOut() {
      update((v) => {
        const next = clampZoom(v - ZOOM_STEP);
        persist(next);
        return next;
      });
    },
    reset() {
      persist(ZOOM_DEFAULT);
      set(ZOOM_DEFAULT);
    },
    setZoom(value: number) {
      const clamped = clampZoom(value);
      persist(clamped);
      set(clamped);
    },
  };
}

export const zoom = createZoomStore();
