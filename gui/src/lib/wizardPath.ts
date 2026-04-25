export type WizardVia = "mock" | "ollama";

let _via: WizardVia = "mock";

export function setWizardVia(via: WizardVia): void {
  _via = via;
}

export function getWizardVia(): WizardVia {
  return _via;
}
