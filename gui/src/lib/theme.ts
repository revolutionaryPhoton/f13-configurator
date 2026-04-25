export type Theme = "light" | "dark" | "system";

const STORAGE_KEY = "f13-theme";

export function getTheme(): Theme {
  if (typeof localStorage === "undefined") return "system";
  const stored = localStorage.getItem(STORAGE_KEY);
  if (stored === "light" || stored === "dark" || stored === "system") return stored;
  return "system";
}

export function applyTheme(theme: Theme): void {
  if (typeof document === "undefined") return;
  const prefersDark =
    typeof window !== "undefined" &&
    window.matchMedia != null &&
    window.matchMedia("(prefers-color-scheme: dark)").matches;
  const useDark = theme === "dark" || (theme === "system" && prefersDark);
  document.documentElement.classList.toggle("dark", useDark);
}

export function setTheme(theme: Theme): void {
  if (typeof localStorage !== "undefined") {
    localStorage.setItem(STORAGE_KEY, theme);
  }
  applyTheme(theme);
}
