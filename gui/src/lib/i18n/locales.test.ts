import { describe, expect, it } from "vitest";
import deMessages from "./de.json";
import enMessages from "./en.json";
import esMessages from "./es.json";
import frMessages from "./fr.json";

const enKeys = Object.keys(enMessages);
const enKeySet = new Set(enKeys);

const catalogs: Record<string, Record<string, string>> = {
  de: deMessages as Record<string, string>,
  fr: frMessages as Record<string, string>,
  es: esMessages as Record<string, string>,
};

describe("locale catalog completeness", () => {
  for (const [locale, catalog] of Object.entries(catalogs)) {
    it(`${locale}: contains all ${enKeys.length} English keys`, () => {
      const missing = enKeys.filter((k) => !(k in catalog));
      expect(missing, `Missing keys in ${locale}: ${missing.join(", ")}`).toEqual([]);
    });

    it(`${locale}: has no extra keys absent from the English catalog`, () => {
      const extra = Object.keys(catalog).filter((k) => !enKeySet.has(k));
      expect(extra, `Extra keys in ${locale}: ${extra.join(", ")}`).toEqual([]);
    });

    it(`${locale}: all values are non-empty strings`, () => {
      const empty = Object.entries(catalog)
        .filter(([, v]) => typeof v !== "string" || v.trim() === "")
        .map(([k]) => k);
      expect(empty, `Empty values in ${locale}: ${empty.join(", ")}`).toEqual([]);
    });

    it(`${locale}: preserves {var} placeholder structure for interpolated keys`, () => {
      const interpolatedKeys = enKeys.filter((k) =>
        (enMessages as Record<string, string>)[k].includes("{")
      );
      for (const key of interpolatedKeys) {
        const enVal = (enMessages as Record<string, string>)[key];
        const locVal = catalog[key] ?? "";
        const enPlaceholders = [...enVal.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();
        const locPlaceholders = [...locVal.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();
        expect(
          locPlaceholders,
          `${locale} key "${key}" placeholder mismatch: en has ${JSON.stringify(enPlaceholders)}, ${locale} has ${JSON.stringify(locPlaceholders)}`
        ).toEqual(enPlaceholders);
      }
    });
  }
});
