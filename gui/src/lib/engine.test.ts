import { describe, expect, it } from "vitest";
import {
  type BinPaths,
  type ComposeEvent,
  createEngine,
  type DoneEvent,
  type EngineEvent,
  type PreflightEvent,
  type ProcessRunner,
  parseEvent,
  type StateEvent,
  type StepEvent,
} from "./engine";

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function makeRunner(lines: string[]): ProcessRunner {
  return {
    run(_cmd, _args, _env) {
      return (async function* () {
        for (const line of lines) {
          yield line;
        }
      })();
    },
  };
}

const TEST_BINS: BinPaths = {
  config: "bin/f13-config",
  stop: "bin/f13-stop",
  reset: "bin/f13-reset",
};

async function collect<T>(iter: AsyncIterable<T>): Promise<T[]> {
  const results: T[] = [];
  for await (const item of iter) {
    results.push(item);
  }
  return results;
}

// ---------------------------------------------------------------------------
// parseEvent — unit tests for the JSON parser
// ---------------------------------------------------------------------------

describe("parseEvent()", () => {
  it("returns null for non-JSON input", () => {
    expect(parseEvent("not json")).toBeNull();
    expect(parseEvent("")).toBeNull();
    expect(parseEvent("  ✅  docker")).toBeNull();
  });

  it("returns null for JSON without a type field", () => {
    expect(parseEvent('{"name":"docker"}')).toBeNull();
  });

  it("returns null for JSON with unknown type", () => {
    expect(parseEvent('{"type":"unknown","x":"y"}')).toBeNull();
  });

  it("parses preflight ok event", () => {
    const evt = parseEvent('{"type":"preflight","name":"docker","status":"ok"}');
    expect(evt).toEqual({ type: "preflight", name: "docker", status: "ok" });
  });

  it("parses preflight fail event with detail", () => {
    const evt = parseEvent(
      '{"type":"preflight","name":"docker","status":"fail","detail":"not running"}'
    );
    expect(evt).toEqual({
      type: "preflight",
      name: "docker",
      status: "fail",
      detail: "not running",
    });
  });

  it("parses preflight info event", () => {
    const evt = parseEvent(
      '{"type":"preflight","name":"ollama","status":"info","detail":"not detected"}'
    );
    expect((evt as PreflightEvent).status).toBe("info");
    expect((evt as PreflightEvent).detail).toBe("not detected");
  });

  it("parses step started event", () => {
    const evt = parseEvent('{"type":"step","name":"render","status":"started"}');
    expect(evt).toEqual({ type: "step", name: "render", status: "started" });
  });

  it("parses step fail event with message", () => {
    const evt = parseEvent(
      '{"type":"step","name":"preflight","status":"fail","message":"checks failed"}'
    );
    expect((evt as StepEvent).message).toBe("checks failed");
  });

  it("parses port free event", () => {
    const evt = parseEvent('{"type":"port","port":"9999","status":"free"}');
    expect(evt).toEqual({ type: "port", port: 9999, status: "free" });
  });

  it("parses port taken event with pid and name", () => {
    const evt = parseEvent(
      '{"type":"port","port":"9999","status":"taken","pid":"1234","name":"nginx"}'
    );
    expect(evt).toEqual({
      type: "port",
      port: 9999,
      status: "taken",
      pid: 1234,
      name: "nginx",
    });
  });

  it("parses port taken event without pid (empty string)", () => {
    const evt = parseEvent('{"type":"port","port":"9999","status":"taken","pid":"","name":""}');
    expect((evt as EngineEvent & { pid?: number }).pid).toBeUndefined();
  });

  it("parses models running event with space-separated list", () => {
    const evt = parseEvent(
      '{"type":"models","status":"running","models":"gemma4:31b-cloud llama3.2:8b"}'
    );
    expect(evt).toEqual({
      type: "models",
      status: "running",
      models: ["gemma4:31b-cloud", "llama3.2:8b"],
    });
  });

  it("parses models running event with empty models string", () => {
    const evt = parseEvent('{"type":"models","status":"running","models":""}');
    expect(evt).toEqual({ type: "models", status: "running", models: [] });
  });

  it("parses models not-running event", () => {
    const evt = parseEvent('{"type":"models","status":"not-running"}');
    expect(evt).toEqual({ type: "models", status: "not-running" });
  });

  it("parses state exists=false event", () => {
    const evt = parseEvent('{"type":"state","exists":"false"}');
    expect(evt).toEqual({ type: "state", exists: false });
  });

  it("parses state exists=true event with all fields", () => {
    const evt = parseEvent(
      '{"type":"state","exists":"true","preset":"v1","backend":"mock",' +
        '"ollama_model":"","frontend_port":"9999","core_port":"8000",' +
        '"timestamp":"2024-01-01T00:00:00Z"}'
    );
    expect((evt as StateEvent & { exists: true }).backend).toBe("mock");
    expect((evt as StateEvent & { exists: true }).frontend_port).toBe("9999");
    expect((evt as StateEvent & { exists: true }).exists).toBe(true);
  });

  it("parses compose event", () => {
    const evt = parseEvent('{"type":"compose","action":"up","status":"started"}');
    expect(evt).toEqual({
      type: "compose",
      action: "up",
      status: "started",
    });
  });

  it("parses health event", () => {
    const evt = parseEvent('{"type":"health","status":"healthy"}');
    expect(evt).toEqual({ type: "health", status: "healthy" });
  });

  it("parses done ok event", () => {
    const evt = parseEvent('{"type":"done","status":"ok"}');
    expect(evt).toEqual({ type: "done", status: "ok" });
  });

  it("parses done error event with message", () => {
    const evt = parseEvent('{"type":"done","status":"error","message":"preflight failed"}');
    expect((evt as DoneEvent).message).toBe("preflight failed");
  });
});

// ---------------------------------------------------------------------------
// createEngine() — engine method tests
// ---------------------------------------------------------------------------

describe("engine.preflight()", () => {
  it("yields PreflightEvents from fixture stream", async () => {
    const engine = createEngine(
      makeRunner([
        '{"type":"preflight","name":"docker","status":"ok"}',
        '{"type":"preflight","name":"bash","status":"ok"}',
        '{"type":"done","status":"ok"}',
        "  ✅  docker",
      ]),
      TEST_BINS
    );
    const events = await collect(engine.preflight());
    expect(events).toHaveLength(2);
    expect(events[0]).toEqual({
      type: "preflight",
      name: "docker",
      status: "ok",
    });
    expect(events[1]).toEqual({ type: "preflight", name: "bash", status: "ok" });
  });

  it("handles fail events", async () => {
    const engine = createEngine(
      makeRunner(['{"type":"preflight","name":"docker","status":"fail","detail":"not found"}']),
      TEST_BINS
    );
    const events = await collect(engine.preflight());
    expect(events[0]).toMatchObject({ status: "fail", detail: "not found" });
  });

  it("skips non-JSON lines silently", async () => {
    const engine = createEngine(
      makeRunner(["some pretty output", '{"type":"preflight","name":"curl","status":"ok"}', ""]),
      TEST_BINS
    );
    const events = await collect(engine.preflight());
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ name: "curl" });
  });
});

describe("engine.detectState()", () => {
  it("returns exists=false when fixture has no state event", async () => {
    const engine = createEngine(makeRunner([""]), TEST_BINS);
    const state = await engine.detectState("/tmp/gen");
    expect(state).toEqual({ type: "state", exists: false });
  });

  it("returns state=false from fixture", async () => {
    const engine = createEngine(makeRunner(['{"type":"state","exists":"false"}']), TEST_BINS);
    const state = await engine.detectState("/tmp/gen");
    expect(state).toEqual({ type: "state", exists: false });
  });

  it("returns full state from fixture", async () => {
    const engine = createEngine(
      makeRunner([
        '{"type":"state","exists":"true","preset":"v1","backend":"ollama",' +
          '"ollama_model":"gemma4:31b-cloud","frontend_port":"9999",' +
          '"core_port":"8000","timestamp":"2024-01-01T00:00:00Z"}',
      ]),
      TEST_BINS
    );
    const state = await engine.detectState("/tmp/gen");
    expect(state).toMatchObject({
      type: "state",
      exists: true,
      backend: "ollama",
      ollama_model: "gemma4:31b-cloud",
    });
  });
});

describe("engine.listOllamaModels()", () => {
  it("returns not-running when fixture has not-running event", async () => {
    const engine = createEngine(
      makeRunner(['{"type":"models","status":"not-running"}']),
      TEST_BINS
    );
    expect(await engine.listOllamaModels()).toBe("not-running");
  });

  it("returns model list when fixture has running event", async () => {
    const engine = createEngine(
      makeRunner(['{"type":"models","status":"running","models":"gemma4:31b-cloud llama3.2:8b"}']),
      TEST_BINS
    );
    const models = await engine.listOllamaModels();
    expect(models).toEqual(["gemma4:31b-cloud", "llama3.2:8b"]);
  });

  it("returns not-running when fixture is empty", async () => {
    const engine = createEngine(makeRunner([]), TEST_BINS);
    expect(await engine.listOllamaModels()).toBe("not-running");
  });
});

describe("engine.checkPort()", () => {
  it("returns free when fixture has free event", async () => {
    const engine = createEngine(
      makeRunner(['{"type":"port","port":"9999","status":"free"}']),
      TEST_BINS
    );
    expect(await engine.checkPort(9999)).toBe("free");
  });

  it("returns inUseBy object when fixture has taken event", async () => {
    const engine = createEngine(
      makeRunner(['{"type":"port","port":"9999","status":"taken","pid":"1234","name":"nginx"}']),
      TEST_BINS
    );
    const result = await engine.checkPort(9999);
    expect(result).toEqual({ inUseBy: 1234, name: "nginx" });
  });

  it("returns free when fixture is empty", async () => {
    const engine = createEngine(makeRunner([]), TEST_BINS);
    expect(await engine.checkPort(9999)).toBe("free");
  });
});

describe("engine.runWizardNonInteractive()", () => {
  it("yields step and done events", async () => {
    const engine = createEngine(
      makeRunner([
        '{"type":"step","name":"preflight","status":"started"}',
        '{"type":"step","name":"preflight","status":"done"}',
        '{"type":"step","name":"render","status":"started"}',
        '{"type":"step","name":"render","status":"done"}',
        '{"type":"done","status":"ok"}',
      ]),
      TEST_BINS
    );
    const events = await collect(engine.runWizardNonInteractive({ backend: "mock" }));
    expect(events).toHaveLength(5);
    expect(events[4]).toEqual({ type: "done", status: "ok" });
  });

  it("filters out non-step/done events", async () => {
    const engine = createEngine(
      makeRunner([
        '{"type":"preflight","name":"docker","status":"ok"}',
        '{"type":"step","name":"render","status":"done"}',
        '{"type":"done","status":"ok"}',
      ]),
      TEST_BINS
    );
    const events = await collect(engine.runWizardNonInteractive({ backend: "mock" }));
    const types = events.map((e) => (e as StepEvent | DoneEvent).type);
    expect(types).not.toContain("preflight");
    expect(types).toContain("step");
    expect(types).toContain("done");
  });
});

describe("engine.compose", () => {
  it("up() resolves when stream ends without error done", async () => {
    const engine = createEngine(
      makeRunner([
        '{"type":"compose","action":"up","status":"healthy"}',
        '{"type":"done","status":"ok"}',
      ]),
      TEST_BINS
    );
    await expect(engine.compose.up("/tmp/gen")).resolves.toBeUndefined();
  });

  it("up() throws when done status=error", async () => {
    const engine = createEngine(
      makeRunner(['{"type":"done","status":"error","message":"timeout"}']),
      TEST_BINS
    );
    await expect(engine.compose.up("/tmp/gen")).rejects.toThrow("timeout");
  });

  it("down() resolves on success", async () => {
    const engine = createEngine(
      makeRunner([
        '{"type":"compose","action":"down","status":"stopped"}',
        '{"type":"done","status":"ok"}',
      ]),
      TEST_BINS
    );
    await expect(engine.compose.down("/tmp/gen")).resolves.toBeUndefined();
  });

  it("reset() resolves on success", async () => {
    const engine = createEngine(makeRunner(['{"type":"done","status":"ok"}']), TEST_BINS);
    await expect(engine.compose.reset("/tmp/gen")).resolves.toBeUndefined();
  });

  it("health() yields ComposeEvents", async () => {
    const engine = createEngine(
      makeRunner([
        '{"type":"health","status":"healthy"}',
        '{"type":"compose","action":"health","status":"ok"}',
      ]),
      TEST_BINS
    );
    const events = await collect(engine.compose.health("/tmp/gen"));
    expect(events).toHaveLength(2);
    expect((events[0] as ComposeEvent).type).toBe("health");
  });
});

// ---------------------------------------------------------------------------
// S32: env-var passthrough — F13_GENERATED_DIR reaches the subprocess
// ---------------------------------------------------------------------------

function makeCapturingRunner(lines: string[] = ['{"type":"done","status":"ok"}']): {
  captured: Array<{ cmd: string; args: string[]; env?: Record<string, string> }>;
  runner: ProcessRunner;
} {
  const captured: Array<{ cmd: string; args: string[]; env?: Record<string, string> }> = [];
  const runner: ProcessRunner = {
    run(cmd, args, env) {
      captured.push({ cmd, args, env });
      return (async function* () {
        for (const l of lines) yield l;
      })();
    },
  };
  return { captured, runner };
}

describe("engine.compose env-var passthrough (S32)", () => {
  it("reset() passes F13_GENERATED_DIR to subprocess", async () => {
    const { captured, runner } = makeCapturingRunner();
    const engine = createEngine(runner, TEST_BINS);
    await engine.compose.reset("/custom/generated");
    expect(captured[0].env).toMatchObject({ F13_GENERATED_DIR: "/custom/generated" });
  });

  it("down() passes F13_GENERATED_DIR to subprocess", async () => {
    const { captured, runner } = makeCapturingRunner();
    const engine = createEngine(runner, TEST_BINS);
    await engine.compose.down("/custom/generated");
    expect(captured[0].env).toMatchObject({ F13_GENERATED_DIR: "/custom/generated" });
  });

  it("up() passes F13_GENERATED_DIR to subprocess", async () => {
    const { captured, runner } = makeCapturingRunner();
    const engine = createEngine(runner, TEST_BINS);
    await engine.compose.up("/custom/generated");
    expect(captured[0].env).toMatchObject({ F13_GENERATED_DIR: "/custom/generated" });
  });

  it("health() passes F13_GENERATED_DIR to subprocess", async () => {
    const { captured, runner } = makeCapturingRunner(['{"type":"health","status":"healthy"}']);
    const engine = createEngine(runner, TEST_BINS);
    await collect(engine.compose.health("/custom/generated"));
    expect(captured[0].env).toMatchObject({ F13_GENERATED_DIR: "/custom/generated" });
  });

  it("reset() uses the bins.reset binary path", async () => {
    const { captured, runner } = makeCapturingRunner();
    const engine = createEngine(runner, TEST_BINS);
    await engine.compose.reset("/custom/generated");
    expect(captured[0].cmd).toBe(TEST_BINS.reset);
  });

  it("down() uses the bins.stop binary path", async () => {
    const { captured, runner } = makeCapturingRunner();
    const engine = createEngine(runner, TEST_BINS);
    await engine.compose.down("/custom/generated");
    expect(captured[0].cmd).toBe(TEST_BINS.stop);
  });
});
