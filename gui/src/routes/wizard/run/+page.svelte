<script lang="ts">
  import { goto } from "$app/navigation";
  import { getGeneratedDir } from "$lib/bootstrap.js";
  import Button from "$lib/components/Button.svelte";
  import ProgressBar from "$lib/components/ProgressBar.svelte";
  import type { Engine, StepEvent, DoneEvent } from "$lib/engine.js";
  import { getEngine } from "$lib/engineContext.js";
  import { getWizardState } from "$lib/wizardState.js";

  interface Props {
    engine?: Engine | null;
    backend?: "mock" | "ollama";
    ollamaModel?: string;
    frontendPort?: number;
    corePort?: number;
    generatedDir?: string;
  }

  let {
    engine: injectedEngine = null,
    backend: backendProp,
    ollamaModel: ollamaModelProp,
    frontendPort: frontendPortProp,
    corePort: corePortProp,
    generatedDir: generatedDirProp,
  }: Props = $props();

  const generatedDir = $derived(
    generatedDirProp ?? getGeneratedDir() ?? "./generated",
  );

  type StepStatus = "pending" | "running" | "done" | "failed";

  interface RunStep {
    key: string;
    label: string;
    short: string;
    status: StepStatus;
    skipped: boolean;
    logs: string[];
  }

  // Six visible stages, matching the design canvas STEP_DEFS.
  let steps = $state<RunStep[]>([
    { key: "secrets", label: "Secrets",    short: "SEC", status: "pending", skipped: false, logs: [] },
    { key: "render",  label: "Compose",    short: "CMP", status: "pending", skipped: false, logs: [] },
    { key: "build",   label: "Frontend",   short: "BLD", status: "pending", skipped: false, logs: [] },
    { key: "pull",    label: "Images",     short: "PUL", status: "pending", skipped: false, logs: [] },
    { key: "start",   label: "Containers", short: "RUN", status: "pending", skipped: false, logs: [] },
    { key: "health",  label: "Health",     short: "HLT", status: "pending", skipped: false, logs: [] },
  ]);

  let pipelineRunning = $state(false);
  let pipelineDone = $state(false);
  let errorMessage = $state<string | null>(null);
  let cancelling = $state(false);

  const cancelToken = { cancelled: false };

  // Header data — pulled from wizard state for display.
  const wizState = $derived.by(() => getWizardState());
  const headerBackend = $derived(backendProp ?? wizState.backend);
  const headerPort = $derived(frontendPortProp ?? wizState.frontendPort ?? 9999);

  function setStep(key: string, status: StepStatus, logLine?: string, skipped?: boolean) {
    steps = steps.map((s) =>
      s.key === key
        ? {
            ...s,
            status,
            skipped: skipped ?? s.skipped,
            logs: logLine !== undefined ? [...s.logs, logLine] : s.logs,
          }
        : s,
    );
  }

  function handleStepEvent(evt: StepEvent) {
    // Skipped events from the keep path: mark done immediately, no animation.
    if (evt.skipped) {
      setStep(evt.name, "done", undefined, true);
      return;
    }
    if (evt.status === "fail") {
      const uiKey = evt.name === "start" ? "pull" : evt.name;
      setStep(uiKey, "failed", evt.message);
      if (!errorMessage) errorMessage = evt.message ?? "Step failed";
      return;
    }
    switch (evt.name) {
      case "secrets":
      case "render":
      case "build":
        setStep(evt.name, evt.status === "started" ? "running" : "done", evt.message);
        break;
      case "start":
        if (evt.status === "started") {
          setStep("pull", "running", evt.message);
        } else {
          steps = steps.map((s) => {
            if (s.key === "pull" || s.key === "start") return { ...s, status: "done" as StepStatus };
            if (s.key === "health") return { ...s, status: "running" as StepStatus };
            return s;
          });
        }
        break;
    }
  }

  function handleDoneEvent(evt: DoneEvent) {
    if (evt.status === "ok") {
      setStep("health", "done");
      pipelineDone = true;
      goto("/status");
    } else {
      steps = steps.map((s) =>
        s.status === "running" ? { ...s, status: "failed" as StepStatus } : s,
      );
      errorMessage = evt.message ?? "Pipeline failed";
    }
  }

  $effect(() => {
    const eng = injectedEngine ?? getEngine();
    if (!eng) return;

    const ws = getWizardState();
    const backend = backendProp ?? ws.backend;
    const ollamaModel = ollamaModelProp ?? (ws.ollamaModel || undefined);
    const frontendPort = frontendPortProp ?? ws.frontendPort;
    const corePort = corePortProp ?? ws.corePort;

    cancelToken.cancelled = false;
    pipelineRunning = true;
    pipelineDone = false;
    errorMessage = null;

    async function run(engine: Engine) {
      try {
        for await (const evt of engine.runWizardNonInteractive({
          backend,
          ...(ollamaModel !== undefined ? { ollamaModel } : {}),
          frontendPort,
          corePort,
          generatedDir,
        })) {
          if (cancelToken.cancelled) break;
          if (evt.type === "step") handleStepEvent(evt as StepEvent);
          else if (evt.type === "done") handleDoneEvent(evt as DoneEvent);
        }
      } catch {
        if (!cancelToken.cancelled && !pipelineDone) {
          errorMessage = "Pipeline ended unexpectedly";
        }
      } finally {
        if (!cancelToken.cancelled) pipelineRunning = false;
      }
    }

    void run(eng);
    return () => {
      cancelToken.cancelled = true;
    };
  });

  async function handleCancel() {
    cancelling = true;
    cancelToken.cancelled = true;
    pipelineRunning = false;

    const eng = injectedEngine ?? getEngine();
    if (eng) {
      try {
        await eng.compose.down(generatedDir);
      } catch {
        // ignore cleanup errors
      }
    }

    cancelling = false;
    goto("/wizard/ports");
  }

  // ── Pipeline graph geometry — fixed 540×130 viewBox ──
  const W = 540;
  const NODE = 56;
  const GAP = $derived((W - NODE * steps.length) / (steps.length - 1));
  const LINE_Y = NODE / 2 + 16;

  // ── Build progress bar ──
  const buildRunning = $derived(steps.find((s) => s.key === "build")?.status === "running");

  // ── Active log ──
  // Flatten all log lines across steps for the terminal-style viewer.
  const allLogLines = $derived.by(() =>
    steps.flatMap((s) =>
      s.logs.map((line) => ({ stepKey: s.key, label: s.label, line, status: s.status })),
    ),
  );

  // Auto-scroll the log viewer to the bottom on new lines.
  let logEl = $state<HTMLDivElement | null>(null);
  $effect(() => {
    void allLogLines.length;
    if (logEl) logEl.scrollTop = logEl.scrollHeight;
  });
</script>

<div class="flex flex-col h-screen bg-bg">
  <!-- Slim header with kicker + run context -->
  <div
    class="flex items-center justify-between px-[22px] py-[14px] border-b border-border"
  >
    <div class="flex items-center gap-2">
      {#if errorMessage}
        <button
          onclick={() => goto("/wizard/ports")}
          class="-ml-2 inline-flex items-center gap-1 px-2 py-1 text-xs text-muted hover:text-text hover:bg-surface-raised rounded-md transition-colors"
          aria-label="Back to ports"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <line x1="19" y1="12" x2="5" y2="12" />
            <polyline points="12 19 5 12 12 5" />
          </svg>
          Back
        </button>
      {/if}
      <div
        class="text-[11px] text-subtle font-semibold uppercase"
        style:letter-spacing="1.5px"
      >
        Launching F13
      </div>
    </div>
    <div
      class="text-[11px] text-muted"
      style:font-family="var(--f13-font-mono)"
    >
      {headerBackend ?? "—"} · :{headerPort}
    </div>
  </div>

  <!-- Body -->
  <div class="flex-1 overflow-y-auto px-[22px] py-6">
    <div class="mx-auto" style:max-width="540px">
      <!-- Title block -->
      <div class="mb-[22px]">
        <h1
          class="m-0 text-[20px] font-semibold text-text"
          style:letter-spacing="-0.2px"
        >
          {pipelineDone
            ? "F13 is up."
            : errorMessage
              ? "Setup failed"
              : "Setting up your F13 instance…"}
        </h1>
        <p class="m-0 mt-1.5 text-[13px] text-muted">
          {pipelineDone
            ? "Redirecting to status…"
            : errorMessage
              ? errorMessage
              : "Six stages will run in sequence. This usually takes about a minute."}
        </p>
      </div>

      <!-- Pipeline graph — SVG, six nodes connected by lines -->
      <div class="relative mb-[22px] py-2">
        <svg
          viewBox="0 0 {W} 130"
          class="w-full h-auto block"
          aria-label="Launch pipeline"
        >
          <!-- Connecting lines -->
          {#each steps as step, i (step.key)}
            {#if i < steps.length - 1}
              {@const x1 = i * (NODE + GAP) + NODE}
              {@const x2 = (i + 1) * (NODE + GAP)}
              {@const filled = step.status === "done"}
              {@const flowing =
                step.status === "done" && steps[i + 1].status === "running"}
              <g>
                <line
                  x1={x1}
                  y1={LINE_Y}
                  x2={x2}
                  y2={LINE_Y}
                  stroke={filled
                    ? "var(--f13-text)"
                    : "var(--f13-border-strong)"}
                  stroke-width="2"
                />
                {#if flowing}
                  <line
                    x1={x1}
                    y1={LINE_Y}
                    x2={x2}
                    y2={LINE_Y}
                    stroke="var(--f13-text)"
                    stroke-width="2"
                    stroke-dasharray="4 4"
                    style:animation="f13-flowDash 600ms linear infinite"
                  />
                {/if}
              </g>
            {/if}
          {/each}

          <!-- Nodes -->
          {#each steps as step, i (step.key)}
            {@const x = i * (NODE + GAP)}
            {@const y = 16}
            {@const isPending = step.status === "pending"}
            {@const isRunning = step.status === "running"}
            {@const isDone = step.status === "done"}
            <g
              data-testid="step-{step.key}"
              data-status={step.status}
              data-skipped={step.skipped ? "true" : undefined}
            >
              {#if step.skipped}
                <title>skipped — existing state</title>
              {/if}
              {#if isRunning}
                <rect
                  x={x - 3}
                  y={y - 3}
                  width={NODE + 6}
                  height={NODE + 6}
                  rx="12"
                  fill="none"
                  stroke="var(--f13-text)"
                  stroke-width="1"
                  opacity="0.25"
                  style:animation="f13-pulse 1.4s ease-in-out infinite"
                />
              {/if}
              <rect
                x={x}
                y={y}
                width={NODE}
                height={NODE}
                rx="10"
                fill={isDone && !step.skipped
                  ? "var(--f13-text)"
                  : isDone && step.skipped
                    ? "var(--f13-surface-raised)"
                    : isRunning
                      ? "var(--f13-surface)"
                      : "var(--f13-surface-raised)"}
                stroke={isDone && !step.skipped
                  ? "var(--f13-text)"
                  : isDone && step.skipped
                    ? "var(--f13-border-strong)"
                    : isRunning
                      ? "var(--f13-text)"
                      : "var(--f13-border-strong)"}
                stroke-width={isRunning ? 2 : 1.5}
                opacity={step.skipped ? 0.6 : 1}
              />
              {#if isDone}
                <path
                  d="M {x + 18} {y + 28} L {x + 25} {y + 35} L {x + 38} {y + 22}"
                  stroke={step.skipped ? "var(--f13-text-subtle)" : "var(--f13-primary-fg)"}
                  stroke-width={step.skipped ? 2 : 3}
                  fill="none"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  opacity={step.skipped ? 0.5 : 1}
                />
              {/if}
              {#if isRunning}
                <circle
                  cx={x + NODE / 2}
                  cy={y + NODE / 2}
                  r="10"
                  fill="none"
                  stroke="var(--f13-text)"
                  stroke-width="2.5"
                  stroke-dasharray="40 100"
                  style:transform-origin="{x + NODE / 2}px {y + NODE / 2}px"
                  style:animation="f13-spin 900ms linear infinite"
                />
              {/if}
              {#if isPending}
                <circle
                  cx={x + NODE / 2}
                  cy={y + NODE / 2}
                  r="4"
                  fill="var(--f13-text-subtle)"
                />
              {/if}
              <text
                x={x + NODE / 2}
                y={y + NODE + 18}
                text-anchor="middle"
                font-size="10"
                font-family="var(--f13-font-mono)"
                font-weight={isRunning || isDone ? 600 : 400}
                fill={isPending
                  ? "var(--f13-text-subtle)"
                  : step.skipped
                    ? "var(--f13-text-subtle)"
                    : "var(--f13-text)"}
              >
                {step.short}
              </text>
              <text
                x={x + NODE / 2}
                y={y + NODE + 30}
                text-anchor="middle"
                font-size="9"
                fill="var(--f13-text-muted)"
              >
                {step.label}
              </text>
            </g>
          {/each}
        </svg>
      </div>

      <!-- Build indeterminate progress bar (best-effort; docker build output is not separately streamed) -->
      {#if buildRunning}
        <div class="mb-[14px]" data-testid="build-progress">
          <ProgressBar label="Building frontend image…" />
        </div>
      {/if}

      <!-- Terminal-style live log -->
      <div
        bind:this={logEl}
        class="rounded-xl px-3.5 py-3 overflow-y-auto"
        style:background="#0a0a0c"
        style:color="#d4d4d8"
        style:border="1px solid #27272a"
        style:font-family="var(--f13-font-mono)"
        style:font-size="11px"
        style:height="200px"
        style:line-height="1.7"
        role="log"
        aria-live="polite"
        aria-label="Pipeline log"
      >
        {#if allLogLines.length === 0}
          <div style:color="#71717a">$ f13-config --start</div>
        {:else}
          {#each allLogLines as l, i (i)}
            <div>
              <span style:color="#71717a">[{l.stepKey}]</span>{" "}<span
                style:color={l.status === "done" ? "#86efac" : "#e4e4e7"}
                >{l.line}</span
              >
            </div>
          {/each}
        {/if}
        {#if pipelineDone}
          <div style:color="#86efac" class="mt-1.5">
            ✓ all services healthy — open http://localhost:{headerPort}
          </div>
        {/if}
        {#if errorMessage}
          <div style:color="#fca5a5" class="mt-1.5">
            ✕ {errorMessage}
          </div>
        {/if}
      </div>
    </div>
  </div>

  <!-- Footer -->
  <div
    class="flex items-center justify-between px-[22px] py-[14px] border-t border-border bg-bg flex-shrink-0"
  >
    <div class="text-[12px] text-muted">
      {#if errorMessage}
        Setup did not complete.
      {:else if pipelineDone}
        All systems healthy.
      {:else if pipelineRunning}
        Setting up…
      {:else}
        Ready to start.
      {/if}
    </div>

    {#if pipelineRunning}
      <Button variant="secondary" size="sm" disabled={cancelling} onclick={handleCancel}>
        {cancelling ? "Cancelling…" : "Cancel"}
      </Button>
    {:else if errorMessage}
      <Button variant="secondary" size="sm" onclick={() => goto("/wizard/ports")}>
        Back to ports
      </Button>
    {/if}
  </div>
</div>
