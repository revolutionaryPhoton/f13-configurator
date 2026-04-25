import type { Engine } from "./engine.js";

let _engine: Engine | null = null;

export function setEngine(engine: Engine): void {
  _engine = engine;
}

export function getEngine(): Engine | null {
  return _engine;
}
