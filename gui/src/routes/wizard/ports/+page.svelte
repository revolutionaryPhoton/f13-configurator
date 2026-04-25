<script lang="ts">
  import { untrack } from "svelte";
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import Disclosure from "$lib/components/Disclosure.svelte";
  import type { Engine } from "$lib/engine.js";
  import { getEngine } from "$lib/engineContext.js";
  import { getWizardVia, type WizardVia } from "$lib/wizardPath.js";

  interface Props {
    via?: WizardVia | null;
    engine?: Engine | null;
  }

  let { via: viaProp = null, engine: injectedEngine = null }: Props = $props();

  const via = $derived(viaProp ?? getWizardVia());
  const step = $derived(via === "ollama" ? "Step 4 of 4" : "Step 3 of 4");
  const backRoute = $derived(
    via === "ollama" ? "/wizard/inference/ollama" : "/wizard/inference"
  );
  const backLabel = $derived(
    via === "ollama" ? "Back to model picker" : "Back to inference picker"
  );

  type PortStatus = "idle" | "checking" | "free" | { pid: number; name: string };

  let frontendPort = $state(9999);
  let corePort = $state(8000);
  let frontendStatus = $state<PortStatus>("idle");
  let coreStatus = $state<PortStatus>("idle");

  const canContinue = $derived(
    frontendStatus === "free" && coreStatus === "free"
  );

  // Auto-check default ports on mount; untrack port values to avoid
  // re-running on every keypress (blur handlers handle manual re-checks).
  $effect(() => {
    const eng = injectedEngine ?? getEngine();
    if (!eng) return;
    let cancelled = false;
    const fp = untrack(() => frontendPort);
    const cp = untrack(() => corePort);
    frontendStatus = "checking";
    coreStatus = "checking";
    eng.checkPort(fp).then((r) => {
      if (cancelled) return;
      frontendStatus = r === "free" ? "free" : { pid: r.inUseBy, name: r.name };
    });
    eng.checkPort(cp).then((r) => {
      if (cancelled) return;
      coreStatus = r === "free" ? "free" : { pid: r.inUseBy, name: r.name };
    });
    return () => {
      cancelled = true;
    };
  });

  async function checkFrontend() {
    const eng = injectedEngine ?? getEngine();
    if (!eng) return;
    frontendStatus = "checking";
    const result = await eng.checkPort(frontendPort);
    frontendStatus = result === "free" ? "free" : { pid: result.inUseBy, name: result.name };
  }

  async function checkCore() {
    const eng = injectedEngine ?? getEngine();
    if (!eng) return;
    coreStatus = "checking";
    const result = await eng.checkPort(corePort);
    coreStatus = result === "free" ? "free" : { pid: result.inUseBy, name: result.name };
  }

  function handleContinue() {
    goto("/wizard/run");
  }
</script>

<div class="min-h-screen flex flex-col bg-bg">
  <!-- Slim header -->
  <header class="flex items-center justify-between px-5 py-3 border-b border-border">
    <button
      onclick={() => goto(backRoute)}
      class="text-xs text-muted hover:text-text transition-colors duration-150
             flex items-center gap-1 rounded focus-visible:outline-none
             focus-visible:ring-2 focus-visible:ring-primary/30"
      aria-label={backLabel}
    >
      ← Back
    </button>
    <span class="text-xs text-subtle">{step}</span>
  </header>

  <!-- Scrollable content -->
  <main class="flex-1 overflow-y-auto px-5 py-5">
    <div class="max-w-md mx-auto space-y-4">
      <!-- Title -->
      <div>
        <h1 class="text-lg font-semibold text-text">Configure ports</h1>
        <p class="text-sm text-muted mt-0.5">
          Choose which TCP ports the F13 services will listen on.
        </p>
      </div>

      <!-- Port inputs -->
      <div class="space-y-3">
        <!-- Frontend port -->
        <div class="rounded-xl bg-surface shadow-sm p-4 space-y-2">
          <label for="frontend-port" class="block text-sm font-medium text-text">
            Frontend port
          </label>
          <div class="flex items-center gap-2">
            <input
              id="frontend-port"
              type="number"
              min="1024"
              max="65535"
              bind:value={frontendPort}
              onblur={checkFrontend}
              aria-label="Frontend port"
              aria-describedby="frontend-port-hint"
              class="flex-1 rounded-xl border border-border bg-bg px-3 py-2 text-sm text-text
                     focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40
                     transition-colors duration-150"
            />
            <span class="flex-shrink-0 w-6 text-center text-sm" aria-live="polite">
              {#if frontendStatus === "checking"}
                <span
                  class="inline-block h-3.5 w-3.5 rounded-full border-2
                         border-primary/40 border-t-primary animate-spin"
                  aria-hidden="true"
                ></span>
                <span class="sr-only">Checking</span>
              {:else if frontendStatus === "free"}
                <span
                  class="text-success font-medium"
                  data-testid="frontend-status-free"
                  aria-hidden="true"
                >✓</span>
                <span class="sr-only">Free</span>
              {:else if typeof frontendStatus === "object"}
                <span
                  class="text-error font-medium"
                  data-testid="frontend-status-taken"
                  aria-hidden="true"
                >✗</span>
                <span class="sr-only">In use</span>
              {/if}
            </span>
          </div>
          <p id="frontend-port-hint" class="text-xs">
            {#if typeof frontendStatus === "object"}
              <span class="text-error" data-testid="frontend-port-taken">
                Port {frontendPort} is in use by PID {frontendStatus.pid}{frontendStatus.name
                  ? ` (${frontendStatus.name})`
                  : ""}.
              </span>
            {:else}
              <span class="text-muted">The F13 web interface — default 9999.</span>
            {/if}
          </p>
        </div>

        <!-- Core API port -->
        <div class="rounded-xl bg-surface shadow-sm p-4 space-y-2">
          <label for="core-port" class="block text-sm font-medium text-text">
            Core API port
          </label>
          <div class="flex items-center gap-2">
            <input
              id="core-port"
              type="number"
              min="1024"
              max="65535"
              bind:value={corePort}
              onblur={checkCore}
              aria-label="Core API port"
              aria-describedby="core-port-hint"
              class="flex-1 rounded-xl border border-border bg-bg px-3 py-2 text-sm text-text
                     focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40
                     transition-colors duration-150"
            />
            <span class="flex-shrink-0 w-6 text-center text-sm" aria-live="polite">
              {#if coreStatus === "checking"}
                <span
                  class="inline-block h-3.5 w-3.5 rounded-full border-2
                         border-primary/40 border-t-primary animate-spin"
                  aria-hidden="true"
                ></span>
                <span class="sr-only">Checking</span>
              {:else if coreStatus === "free"}
                <span
                  class="text-success font-medium"
                  data-testid="core-status-free"
                  aria-hidden="true"
                >✓</span>
                <span class="sr-only">Free</span>
              {:else if typeof coreStatus === "object"}
                <span
                  class="text-error font-medium"
                  data-testid="core-status-taken"
                  aria-hidden="true"
                >✗</span>
                <span class="sr-only">In use</span>
              {/if}
            </span>
          </div>
          <p id="core-port-hint" class="text-xs">
            {#if typeof coreStatus === "object"}
              <span class="text-error" data-testid="core-port-taken">
                Port {corePort} is in use by PID {coreStatus.pid}{coreStatus.name
                  ? ` (${coreStatus.name})`
                  : ""}.
              </span>
            {:else}
              <span class="text-muted">The backend API service — default 8000.</span>
            {/if}
          </p>
        </div>
      </div>

      <!-- Advanced disclosure -->
      <Disclosure title="Advanced">
        <div class="space-y-3 pt-1">
          <div>
            <p class="text-xs font-medium text-text mb-1.5">Secret file locations</p>
            <div class="rounded-lg bg-bg border border-border px-3 py-2.5 space-y-0.5">
              <p class="font-mono text-xs text-muted">~/.f13/generated/core_jwt.secret</p>
              <p class="font-mono text-xs text-muted">~/.f13/generated/chat_api.secret</p>
            </div>
            <p class="text-xs text-muted mt-1.5">
              Generated on first run; never committed to git.
            </p>
          </div>
          <div>
            <button
              disabled
              aria-disabled="true"
              aria-label="Edit system prompt (coming soon)"
              data-testid="edit-system-prompt"
              class="rounded-lg border border-border/50 px-3 py-1.5 text-xs text-muted
                     cursor-not-allowed opacity-50"
            >
              Edit system prompt
            </button>
            <p class="text-xs text-subtle mt-1">Available in a future release.</p>
          </div>
        </div>
      </Disclosure>
    </div>
  </main>

  <!-- Sticky footer -->
  <footer
    class="sticky bottom-0 bg-bg/90 backdrop-blur-sm border-t border-border px-5 py-3"
  >
    <div class="max-w-md mx-auto flex items-center justify-between gap-3">
      <p class="text-xs text-muted">
        {#if canContinue}
          Ports {frontendPort} and {corePort} are available.
        {:else}
          Both ports must be free to continue.
        {/if}
      </p>
      <Button disabled={!canContinue} onclick={handleContinue}>
        Continue
      </Button>
    </div>
  </footer>
</div>
