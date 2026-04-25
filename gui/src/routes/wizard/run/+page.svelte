<script lang="ts">
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import LogViewer from "$lib/components/LogViewer.svelte";
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
    generatedDir = "./generated",
  }: Props = $props();

  type StepStatus = "pending" | "running" | "done" | "failed";

  interface RunStep {
    key: string;
    label: string;
    status: StepStatus;
    logs: string[];
  }

  let steps = $state<RunStep[]>([
    { key: "secrets", label: "Generating secrets",        status: "pending", logs: [] },
    { key: "render",  label: "Rendering compose",          status: "pending", logs: [] },
    { key: "build",   label: "Building patched frontend",  status: "pending", logs: [] },
    { key: "pull",    label: "Pulling images",             status: "pending", logs: [] },
    { key: "start",   label: "Starting containers",        status: "pending", logs: [] },
    { key: "health",  label: "Waiting for health",         status: "pending", logs: [] },
  ]);

  let pipelineRunning = $state(false);
  let pipelineDone = $state(false);
  let errorMessage = $state<string | null>(null);
  let cancelling = $state(false);

  // Plain object token — shared between $effect closure and handleCancel
  const cancelToken = { cancelled: false };

  function setStep(key: string, status: StepStatus, logLine?: string) {
    steps = steps.map((s) =>
      s.key === key
        ? { ...s, status, logs: logLine !== undefined ? [...s.logs, logLine] : s.logs }
        : s
    );
  }

  function handleStepEvent(evt: StepEvent) {
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
          // start done: pull and start both complete; health now running
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
        s.status === "running" ? { ...s, status: "failed" as StepStatus } : s
      );
      errorMessage = evt.message ?? "Pipeline failed";
    }
  }

  $effect(() => {
    const eng = injectedEngine ?? getEngine();
    if (!eng) return;

    const wizState = getWizardState();
    const backend = backendProp ?? wizState.backend;
    const ollamaModel = ollamaModelProp ?? (wizState.ollamaModel || undefined);
    const frontendPort = frontendPortProp ?? wizState.frontendPort;
    const corePort = corePortProp ?? wizState.corePort;

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

  function stepIconClass(status: StepStatus): string {
    if (status === "running") return "border-primary/30 border-t-primary animate-spin";
    return "border-border/40";
  }

  function stepCardClass(status: StepStatus): string {
    if (status === "pending") return "bg-surface opacity-50";
    if (status === "running") return "bg-surface shadow-sm ring-1 ring-primary/15";
    if (status === "done") return "bg-surface shadow-sm";
    return "bg-error/5 border border-error/20 shadow-sm";
  }

  function labelClass(status: StepStatus): string {
    if (status === "pending") return "text-muted";
    if (status === "failed") return "text-error";
    return "text-text";
  }
</script>

<div class="min-h-screen flex flex-col bg-bg">
  <!-- Slim header -->
  <header class="flex items-center justify-between px-5 py-3 border-b border-border">
    <div>
      {#if errorMessage}
        <button
          onclick={() => goto("/wizard/ports")}
          class="text-xs text-muted hover:text-text transition-colors duration-150
                 flex items-center gap-1 rounded focus-visible:outline-none
                 focus-visible:ring-2 focus-visible:ring-primary/30"
          aria-label="Back to ports"
        >
          ← Back
        </button>
      {/if}
    </div>
    <span class="text-xs text-subtle">Launching</span>
  </header>

  <!-- Scrollable content -->
  <main class="flex-1 overflow-y-auto px-5 py-5">
    <div class="max-w-md mx-auto space-y-4">
      <!-- Page title -->
      <div>
        <h1 class="text-lg font-semibold text-text">
          {#if pipelineDone}
            F13 is up! ✓
          {:else if errorMessage}
            Setup failed
          {:else}
            Launch F13
          {/if}
        </h1>
        <p class="text-sm text-muted mt-0.5">
          {#if pipelineDone}
            Redirecting to status…
          {:else if errorMessage}
            {errorMessage}
          {:else if pipelineRunning}
            Setting up your F13 instance…
          {:else}
            Preparing to launch.
          {/if}
        </p>
      </div>

      <!-- Pipeline steps -->
      <div
        role="list"
        aria-label="Launch pipeline"
        aria-live="polite"
        aria-busy={pipelineRunning}
        class="space-y-2"
      >
        {#each steps as step (step.key)}
          <div
            role="listitem"
            class="rounded-xl overflow-hidden {stepCardClass(step.status)}"
            data-testid="step-{step.key}"
            data-status={step.status}
          >
            <!-- Step header row -->
            <div class="flex items-center gap-3 px-4 py-3">
              {#if step.status === "pending" || step.status === "running"}
                <span
                  class="flex-none w-4 h-4 rounded-full border-2 {stepIconClass(step.status)}"
                  aria-hidden="true"
                ></span>
              {:else if step.status === "done"}
                <span
                  class="flex-none text-success text-sm font-medium leading-none"
                  aria-hidden="true"
                >✓</span>
              {:else}
                <span
                  class="flex-none text-error text-sm font-medium leading-none"
                  aria-hidden="true"
                >✕</span>
              {/if}

              <span class="flex-1 text-sm font-medium {labelClass(step.status)}">
                {step.label}
              </span>
              <span class="sr-only">{step.status}</span>
            </div>

            <!-- Indeterminate progress bar for the build step while running -->
            {#if step.key === "build" && step.status === "running"}
              <div class="px-4 pb-3" data-testid="build-progress">
                <ProgressBar status="running" label="Building docker image…" />
              </div>
            {/if}

            <!-- Collapsible log viewer for steps that have output -->
            {#if step.logs.length > 0}
              <details class="px-4 pb-3">
                <summary
                  class="text-xs text-muted cursor-pointer select-none list-none
                         hover:text-text transition-colors duration-150"
                  aria-label="View log for {step.label}"
                >
                  View log ({step.logs.length}
                  {step.logs.length === 1 ? "line" : "lines"})
                </summary>
                <div class="mt-1.5">
                  <LogViewer lines={step.logs} label="{step.label} log" />
                </div>
              </details>
            {/if}
          </div>
        {/each}
      </div>

      <div class="h-1"></div>
    </div>
  </main>

  <!-- Sticky footer -->
  <footer
    class="sticky bottom-0 bg-bg/90 backdrop-blur-sm border-t border-border px-5 py-3"
  >
    <div class="max-w-md mx-auto flex items-center justify-between gap-3">
      <p class="text-xs text-muted">
        {#if errorMessage}
          Setup did not complete. Check the logs above.
        {:else if pipelineDone}
          All done!
        {:else if pipelineRunning}
          Setting up…
        {:else}
          Ready to start.
        {/if}
      </p>

      {#if pipelineRunning}
        <Button variant="secondary" disabled={cancelling} onclick={handleCancel}>
          {cancelling ? "Cancelling…" : "Cancel"}
        </Button>
      {:else if errorMessage}
        <Button variant="secondary" onclick={() => goto("/wizard/ports")}>
          Back to ports
        </Button>
      {/if}
    </div>
  </footer>
</div>
