export interface WizardState {
  backend: "mock" | "ollama";
  ollamaModel: string;
  frontendPort: number;
  corePort: number;
}

const _state: WizardState = {
  backend: "mock",
  ollamaModel: "",
  frontendPort: 9999,
  corePort: 8000,
};

export function setWizardState(patch: Partial<WizardState>): void {
  Object.assign(_state, patch);
}

export function getWizardState(): WizardState {
  return { ..._state };
}
