/**
 * Engine adapter — typed wrapper over the F13 shell CLI.
 *
 * All side effects route through a ProcessRunner that can be swapped out
 * for a mock in unit tests.  In production, wire up a TauriRunner in
 * the app layout before calling createEngine().
 */

// ---------------------------------------------------------------------------
// Event types emitted by the CLI with --emit-events
// ---------------------------------------------------------------------------

export interface PreflightEvent {
  type: "preflight";
  name: string;
  status: "ok" | "fail" | "info";
  detail?: string;
}

export interface StepEvent {
  type: "step";
  name: string;
  status: "started" | "done" | "fail";
  skipped?: boolean;
  message?: string;
}

export interface PortEvent {
  type: "port";
  port: number;
  status: "free" | "taken";
  pid?: number;
  name?: string;
}

export type ModelsEvent =
  | { type: "models"; status: "running"; models: string[] }
  | { type: "models"; status: "not-running" };

export type StateEvent =
  | { type: "state"; exists: false }
  | {
      type: "state";
      exists: true;
      preset: string;
      backend: string;
      ollama_model: string;
      frontend_port: string;
      core_port: string;
      timestamp: string;
    };

export interface ComposeEvent {
  type: "compose" | "health";
  action?: string;
  status: string;
  message?: string;
}

export interface DoneEvent {
  type: "done";
  status: "ok" | "error";
  message?: string;
}

export type EngineEvent =
  | PreflightEvent
  | StepEvent
  | PortEvent
  | ModelsEvent
  | StateEvent
  | ComposeEvent
  | DoneEvent;

// ---------------------------------------------------------------------------
// Process runner abstraction (injectable for tests)
// ---------------------------------------------------------------------------

export interface ProcessRunner {
  run(cmd: string, args: string[], env?: Record<string, string>): AsyncIterable<string>;
}

// ---------------------------------------------------------------------------
// Bin paths (overridable for tests / packaging)
// ---------------------------------------------------------------------------

export interface BinPaths {
  config: string;
  stop: string;
  reset: string;
}

const DEFAULT_BINS: BinPaths = {
  config: "bin/f13-config",
  stop: "bin/f13-stop",
  reset: "bin/f13-reset",
};

// ---------------------------------------------------------------------------
// Event parsing
// ---------------------------------------------------------------------------

function coerceEvent(raw: Record<string, unknown>): EngineEvent | null {
  const type = raw.type;
  if (typeof type !== "string") return null;

  switch (type) {
    case "preflight":
      return {
        type: "preflight",
        name: String(raw.name ?? ""),
        status: (raw.status as "ok" | "fail" | "info") ?? "info",
        ...(raw.detail != null ? { detail: String(raw.detail) } : {}),
      };

    case "step":
      return {
        type: "step",
        name: String(raw.name ?? ""),
        status: (raw.status as "started" | "done" | "fail") ?? "started",
        ...(raw.skipped != null ? { skipped: raw.skipped === "true" || raw.skipped === true } : {}),
        ...(raw.message != null ? { message: String(raw.message) } : {}),
      };

    case "port": {
      const pidStr = String(raw.pid ?? "");
      const nameStr = String(raw.name ?? "");
      return {
        type: "port",
        port: Number(raw.port),
        status: (raw.status as "free" | "taken") ?? "free",
        ...(pidStr !== "" ? { pid: Number(pidStr) } : {}),
        ...(nameStr !== "" ? { name: nameStr } : {}),
      };
    }

    case "models":
      if (raw.status === "not-running") {
        return { type: "models", status: "not-running" };
      }
      return {
        type: "models",
        status: "running",
        models:
          raw.models != null && String(raw.models) !== ""
            ? String(raw.models).split(" ").filter(Boolean)
            : [],
      };

    case "state":
      if (raw.exists === "false" || raw.exists === false) {
        return { type: "state", exists: false };
      }
      return {
        type: "state",
        exists: true,
        preset: String(raw.preset ?? ""),
        backend: String(raw.backend ?? ""),
        ollama_model: String(raw.ollama_model ?? ""),
        frontend_port: String(raw.frontend_port ?? ""),
        core_port: String(raw.core_port ?? ""),
        timestamp: String(raw.timestamp ?? ""),
      };

    case "compose":
    case "health":
      return {
        type: type as "compose" | "health",
        ...(raw.action != null ? { action: String(raw.action) } : {}),
        status: String(raw.status ?? ""),
        ...(raw.message != null ? { message: String(raw.message) } : {}),
      };

    case "done":
      return {
        type: "done",
        status: (raw.status as "ok" | "error") ?? "ok",
        ...(raw.message != null ? { message: String(raw.message) } : {}),
      };

    default:
      return null;
  }
}

export function parseEvent(line: string): EngineEvent | null {
  try {
    const raw = JSON.parse(line) as unknown;
    if (typeof raw !== "object" || raw === null) return null;
    return coerceEvent(raw as Record<string, unknown>);
  } catch {
    return null;
  }
}

async function* readEvents(stream: AsyncIterable<string>): AsyncGenerator<EngineEvent> {
  for await (const line of stream) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    const evt = parseEvent(trimmed);
    if (evt !== null) yield evt;
  }
}

// ---------------------------------------------------------------------------
// Engine interface
// ---------------------------------------------------------------------------

export interface Engine {
  /** Stream preflight check results. */
  preflight(): AsyncIterable<PreflightEvent>;
  /** Return the saved wizard state, or { exists: false } if none. */
  detectState(generatedDir: string): Promise<StateEvent>;
  /** Return available Ollama model names, or 'not-running'. */
  listOllamaModels(): Promise<string[] | "not-running">;
  /** Check whether a TCP port is free on the host. */
  checkPort(port: number): Promise<"free" | { inUseBy: number; name: string }>;
  /** Run the full wizard non-interactively; stream step and done events. */
  runWizardNonInteractive(opts: WizardOptions): AsyncIterable<StepEvent | DoneEvent>;
  compose: {
    up(generatedDir: string): Promise<void>;
    down(generatedDir: string): Promise<void>;
    reset(generatedDir: string): Promise<void>;
    health(generatedDir: string): AsyncIterable<ComposeEvent>;
  };
}

export interface WizardOptions {
  backend: "mock" | "ollama";
  ollamaModel?: string;
  frontendPort?: number;
  corePort?: number;
  dryRun?: boolean;
  generatedDir?: string;
  skipBuild?: boolean;
  stateAction?: "keep" | "edit" | "reset";
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

export function createEngine(runner: ProcessRunner, bins: BinPaths = DEFAULT_BINS): Engine {
  return {
    async *preflight() {
      const stream = runner.run(bins.config, [
        "--non-interactive",
        "--emit-events",
        "--preflight-only",
      ]);
      for await (const evt of readEvents(stream)) {
        if (evt.type === "preflight") yield evt as PreflightEvent;
      }
    },

    async detectState(generatedDir: string): Promise<StateEvent> {
      const stream = runner.run(
        bins.config,
        ["--non-interactive", "--emit-events", "--detect-state"],
        { F13_GENERATED_DIR: generatedDir }
      );
      for await (const evt of readEvents(stream)) {
        if (evt.type === "state") return evt as StateEvent;
      }
      return { type: "state", exists: false };
    },

    async listOllamaModels(): Promise<string[] | "not-running"> {
      const stream = runner.run(bins.config, [
        "--non-interactive",
        "--emit-events",
        "--list-models",
      ]);
      for await (const evt of readEvents(stream)) {
        if (evt.type === "models") {
          const e = evt as ModelsEvent;
          return e.status === "running" ? e.models : "not-running";
        }
      }
      return "not-running";
    },

    async checkPort(port: number): Promise<"free" | { inUseBy: number; name: string }> {
      const stream = runner.run(bins.config, [
        "--non-interactive",
        "--emit-events",
        "--check-port",
        String(port),
      ]);
      for await (const evt of readEvents(stream)) {
        if (evt.type === "port") {
          const e = evt as PortEvent;
          if (e.status === "free") return "free";
          return { inUseBy: e.pid ?? 0, name: e.name ?? "" };
        }
      }
      return "free";
    },

    async *runWizardNonInteractive(opts: WizardOptions) {
      const env: Record<string, string> = {
        F13_CONFIG_NONINTERACTIVE: "1",
        CHAT_BACKEND: opts.backend,
      };
      if (opts.ollamaModel) env.OLLAMA_MODEL = opts.ollamaModel;
      if (opts.frontendPort) env.FRONTEND_PORT = String(opts.frontendPort);
      if (opts.corePort) env.CORE_PORT = String(opts.corePort);
      if (opts.generatedDir) env.F13_GENERATED_DIR = opts.generatedDir;
      if (opts.skipBuild) env.F13_SKIP_BUILD = "1";
      if (opts.stateAction) env.F13_STATE_ACTION = opts.stateAction;

      const args = ["--non-interactive", "--emit-events"];
      if (opts.dryRun) args.push("--dry-run");

      const stream = runner.run(bins.config, args, env);
      for await (const evt of readEvents(stream)) {
        if (evt.type === "step" || evt.type === "done") {
          yield evt as StepEvent | DoneEvent;
        }
      }
    },

    compose: {
      async up(generatedDir: string): Promise<void> {
        const stream = runner.run(
          bins.config,
          ["--non-interactive", "--emit-events", "--compose-up"],
          { F13_GENERATED_DIR: generatedDir }
        );
        for await (const evt of readEvents(stream)) {
          if (evt.type === "done" && (evt as DoneEvent).status === "error") {
            throw new Error((evt as DoneEvent).message ?? "compose up failed");
          }
        }
      },

      async down(generatedDir: string): Promise<void> {
        const stream = runner.run(bins.stop, ["--emit-events"], {
          F13_GENERATED_DIR: generatedDir,
        });
        for await (const evt of readEvents(stream)) {
          if (evt.type === "done" && (evt as DoneEvent).status === "error") {
            throw new Error((evt as DoneEvent).message ?? "compose down failed");
          }
        }
      },

      async reset(generatedDir: string): Promise<void> {
        const stream = runner.run(bins.reset, ["--emit-events"], {
          F13_GENERATED_DIR: generatedDir,
        });
        for await (const evt of readEvents(stream)) {
          if (evt.type === "done" && (evt as DoneEvent).status === "error") {
            throw new Error((evt as DoneEvent).message ?? "compose reset failed");
          }
        }
      },

      async *health(generatedDir: string) {
        const stream = runner.run(
          bins.config,
          ["--non-interactive", "--emit-events", "--compose-health"],
          { F13_GENERATED_DIR: generatedDir }
        );
        for await (const evt of readEvents(stream)) {
          if (evt.type === "health" || evt.type === "compose") {
            yield evt as ComposeEvent;
          }
        }
      },
    },
  };
}
