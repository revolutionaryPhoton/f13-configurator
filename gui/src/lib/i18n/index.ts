import enMessages from "./en.json";

export type Locale = "en" | "de" | "fr" | "es";

// Catalog registry — de/fr/es are populated by registerCatalog() in S43.
const catalogs: Partial<Record<Locale, Record<string, string>>> = {
  en: enMessages as Record<string, string>,
};

let _locale: Locale = "en";

export function getLocale(): Locale {
  return _locale;
}

export function setLocale(locale: Locale): void {
  _locale = locale;
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
