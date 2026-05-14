import enMessages from "./en.json";

export type Locale = "en" | "de" | "fr" | "es";

export const SUPPORTED_LOCALES: readonly Locale[] = ["en", "de", "fr", "es"] as const;

export const LS_KEY = "f13.configurator.locale";
const LEGACY_LS_KEY = "f13_locale"; // pre-v0.4.0 key — migrate on read, then delete

// Catalog registry — de/fr/es are populated by registerCatalog() in S43.
const catalogs: Partial<Record<Locale, Record<string, string>>> = {
  en: enMessages as Record<string, string>,
};

function isValidLocale(value: string | null): value is Locale {
  return value !== null && (SUPPORTED_LOCALES as readonly string[]).includes(value);
}

function readStoredLocale(): Locale {
  try {
    const stored = localStorage.getItem(LS_KEY);
    if (isValidLocale(stored)) return stored;

    // Migrate from the pre-v0.4.0 key if present, then delete it so
    // future reads use the new key directly. New writes always land
    // under LS_KEY via setLocale().
    const legacy = localStorage.getItem(LEGACY_LS_KEY);
    if (isValidLocale(legacy)) {
      localStorage.setItem(LS_KEY, legacy);
      localStorage.removeItem(LEGACY_LS_KEY);
      return legacy;
    }
  } catch {
    // localStorage unavailable (test isolation, SSR)
  }
  return "en";
}

let _locale: Locale = readStoredLocale();

export function getLocale(): Locale {
  return _locale;
}

export function setLocale(locale: Locale): void {
  _locale = locale;
  try {
    localStorage.setItem(LS_KEY, locale);
  } catch {
    // localStorage unavailable
  }
}

// Register a translation catalog for a given locale (used by S43).
export function registerCatalog(locale: Locale, messages: Record<string, string>): void {
  catalogs[locale] = messages;
}

// Translate a message key, with optional {var} interpolation.
// Falls back to the English catalog for missing keys; falls back to the key
// itself if the key is absent from English too.
export function t(key: string, vars?: Record<string, string | number>): string {
  const messages = catalogs[_locale] ?? catalogs.en ?? {};
  let msg: string = messages[key] ?? catalogs.en?.[key] ?? key;
  if (vars) {
    for (const [k, v] of Object.entries(vars)) {
      msg = msg.replaceAll(`{${k}}`, String(v));
    }
  }
  return msg;
}
