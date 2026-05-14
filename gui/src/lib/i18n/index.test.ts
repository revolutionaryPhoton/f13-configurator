import { afterEach, describe, expect, it, vi } from "vitest";
import { getLocale, registerCatalog, SUPPORTED_LOCALES, setLocale, t } from "./index.js";

describe("i18n module", () => {
  afterEach(() => {
    // Reset to English and clear localStorage after each test so state doesn't leak.
    setLocale("en");
    localStorage.clear();
  });

  // ── Baseline English ────────────────────────────────────────────────────────

  it("defaults to English locale", () => {
    expect(getLocale()).toBe("en");
  });

  it("returns the English string for a known key", () => {
    expect(t("welcome.title")).toBe("F13 Configurator");
  });

  it("returns the key itself for an unknown key", () => {
    expect(t("this.key.does.not.exist")).toBe("this.key.does.not.exist");
  });

  it("returns non-empty string for every key in the English catalog", () => {
    const keys = [
      "common.continue",
      "common.back",
      "common.cancel",
      "welcome.beginSetup",
      "welcome.openExisting",
      "preflight.kicker",
      "preflight.title.scanning",
      "inference.title",
      "ollamaModel.title",
      "ports.title",
      "run.kicker",
      "status.heading",
      "settings.title",
    ];
    for (const key of keys) {
      const result = t(key);
      expect(result, `key "${key}" should not fall back to itself`).not.toBe(key);
      expect(result.length).toBeGreaterThan(0);
    }
  });

  // ── Locale switching ────────────────────────────────────────────────────────

  it("setLocale changes the current locale", () => {
    setLocale("de");
    expect(getLocale()).toBe("de");
  });

  it("falls back to English when locale catalog is not registered", () => {
    setLocale("de");
    // de catalog not yet registered — should return English value
    expect(t("welcome.title")).toBe("F13 Configurator");
  });

  it("uses a registered catalog when the locale matches", () => {
    registerCatalog("de", { "welcome.title": "F13 Konfigurator" });
    setLocale("de");
    expect(t("welcome.title")).toBe("F13 Konfigurator");
  });

  it("falls back to English for a key missing from the locale catalog", () => {
    registerCatalog("de", { "welcome.title": "F13 Konfigurator" });
    setLocale("de");
    // "welcome.beginSetup" is absent from the stub de catalog → English fallback
    expect(t("welcome.beginSetup")).toBe("Begin setup");
  });

  it("returns key when it is absent from both locale and English catalogs", () => {
    registerCatalog("fr", {});
    setLocale("fr");
    expect(t("no.such.key")).toBe("no.such.key");
  });

  // ── Interpolation ───────────────────────────────────────────────────────────

  it("interpolates a single {var} placeholder", () => {
    expect(t("preflight.ollama.modelsAvailable", { count: 3 })).toBe("3 models available");
  });

  it("interpolates multiple {var} placeholders", () => {
    expect(t("ports.frontend.inUse", { port: 9999, pid: 1234, name: "nginx" })).toBe(
      "Port 9999 in use by PID 1234 (nginx)."
    );
  });

  it("interpolates numeric values as strings", () => {
    expect(t("stepHeader.stepOf", { step: 2, total: 4 })).toBe("Step 2 of 4");
  });

  it("leaves unreplaced placeholders intact when a var is absent", () => {
    // Only supply {port} — {pid} and {name} remain as-is
    const result = t("ports.frontend.inUse", { port: 9999 });
    expect(result).toContain("{pid}");
    expect(result).toContain("{name}");
  });

  it("does not mutate the catalog string (replaceAll is non-destructive)", () => {
    t("ports.frontend.inUse", { port: 1, pid: 2, name: "x" });
    // Calling again should still produce the correct output
    expect(t("ports.frontend.inUse", { port: 9999, pid: 1234, name: "nginx" })).toBe(
      "Port 9999 in use by PID 1234 (nginx)."
    );
  });

  // ── Footer / status messages ────────────────────────────────────────────────

  it("returns correct run.log.allHealthy with port interpolation", () => {
    expect(t("run.log.allHealthy", { port: 9999 })).toContain("localhost:9999");
  });

  it("returns correct status.toast.stopFailed with error interpolation", () => {
    expect(t("status.toast.stopFailed", { error: "timeout" })).toBe("Stop failed: timeout");
  });

  it("returns correct settings.config.toast.copied with label interpolation", () => {
    expect(t("settings.config.toast.copied", { label: "docker-compose.yml" })).toBe(
      "docker-compose.yml copied"
    );
  });

  // ── SUPPORTED_LOCALES ───────────────────────────────────────────────────────

  it("SUPPORTED_LOCALES contains exactly en, de, fr, es", () => {
    expect(SUPPORTED_LOCALES).toEqual(["en", "de", "fr", "es"]);
  });

  // ── localStorage persistence ────────────────────────────────────────────────

  it("setLocale writes the locale to localStorage", () => {
    setLocale("de");
    expect(localStorage.getItem("f13.configurator.locale")).toBe("de");
  });

  it("setLocale('en') writes 'en' to localStorage", () => {
    setLocale("en");
    expect(localStorage.getItem("f13.configurator.locale")).toBe("en");
  });

  it("setLocale('fr') persists 'fr' and is readable back", () => {
    setLocale("fr");
    expect(localStorage.getItem("f13.configurator.locale")).toBe("fr");
    // getLocale() must reflect the in-memory change immediately
    expect(getLocale()).toBe("fr");
  });
});

// Migration is a one-shot read at module init, so we need a fresh
// import to exercise it. Each test in this block resets modules,
// seeds localStorage, then dynamically re-imports.
describe("i18n module — pre-v0.4.0 key migration", () => {
  afterEach(() => {
    localStorage.clear();
    vi.resetModules();
  });

  it("migrates legacy 'f13_locale' to 'f13.configurator.locale' and deletes the legacy key", async () => {
    localStorage.setItem("f13_locale", "de");
    vi.resetModules();
    const { getLocale: getLocaleFresh } = await import("./index.js");
    expect(getLocaleFresh()).toBe("de");
    expect(localStorage.getItem("f13.configurator.locale")).toBe("de");
    expect(localStorage.getItem("f13_locale")).toBeNull();
  });

  it("prefers the new key over the legacy key when both are present", async () => {
    localStorage.setItem("f13_locale", "de");
    localStorage.setItem("f13.configurator.locale", "fr");
    vi.resetModules();
    const { getLocale: getLocaleFresh } = await import("./index.js");
    expect(getLocaleFresh()).toBe("fr");
    // Legacy key is not touched in this case (new key won, no migration ran).
    expect(localStorage.getItem("f13_locale")).toBe("de");
  });

  it("ignores invalid legacy values and falls back to English", async () => {
    localStorage.setItem("f13_locale", "klingon");
    vi.resetModules();
    const { getLocale: getLocaleFresh } = await import("./index.js");
    expect(getLocaleFresh()).toBe("en");
    expect(localStorage.getItem("f13.configurator.locale")).toBeNull();
  });
});
