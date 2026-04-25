<script lang="ts">
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import type { Engine, PreflightEvent } from "$lib/engine.js";
  import { getEngine } from "$lib/engineContext.js";

  interface Props {
    engine?: Engine | null;
    generatedDir?: string;
  }

  let {
    engine: injectedEngine = null,
    generatedDir = "./generated",
  }: Props = $props();

  interface CheckRow {
    name: string;
    status: "ok" | "fail" | "info";
    detail?: string;
  }

  // Install hints for each known failing check (macOS / Homebrew)
  const FIX_HINTS: Record<string, { cmd: string; note?: string }> = {
    docker: {
      cmd: "brew install --cask docker",
      note: "Launch Docker.app after installation",
    },
    "docker-compose": {
      cmd: "# Bundled with Docker Desktop.\n# Reinstall: https://www.docker.com/products/docker-desktop",
    },
    bash: { cmd: "brew install bash" },
    curl: { cmd: "brew install curl" },
    awk: { cmd: "brew install gawk" },
    sed: { cmd: "# sed is built-in on macOS.\n# If missing: brew install gnu-sed" },
    envsubst: {
      cmd: "brew install gettext\nbrew link --force gettext",
      note: "Restart your shell after linking",
    },
    disk: {
      cmd: "# Free up at least 2 GB of disk space\ndu -sh ~ 2>/dev/null | sort -rh | head -20",
    },
    git: { cmd: "brew install git" },
  };

  let checks = $state<CheckRow[]>([]);
  let streaming = $state(true);
  let ollamaModels = $state<string[] | null>(null);

  const hasFailure = $derived(checks.some((c) => c.status === "fail"));
  // Require at least one check to have arrived before enabling Continue —
  // guards both the null-engine case and engines that emit empty streams.
  const canContinue = $derived(!streaming && !hasFailure && checks.length > 0);

  $effect(() => {
    const eng = injectedEngine ?? getEngine();
    if (!eng) {
      streaming = false;
      return;
    }

    let cancelled = false;

    async function run(engine: Engine) {
      try {
        for await (const evt of engine.preflight()) {
          if (cancelled) break;
          const row: CheckRow = { name: evt.name, status: evt.status, detail: evt.detail };
          checks = [...checks, row];

          // When Ollama is detected, fetch the model list to show nested
          if (evt.name === "ollama" && evt.status === "info" && evt.detail?.includes("detected,")) {
            engine
              .listOllamaModels()
              .then((result) => {
                if (!cancelled && Array.isArray(result)) {
                  ollamaModels = result as string[];
                }
              })
              .catch(() => {});
          }
        }
      } catch {
        // stream ended or engine unavailable
      } finally {
        if (!cancelled) streaming = false;
      }
    }

    void run(eng);
    return () => {
      cancelled = true;
    };
  });

  function rowBg(status: CheckRow["status"]): string {
    if (status === "fail") return "bg-error-bg";
    if (status === "info") return "bg-info-bg";
    return "bg-surface";
  }

  function detailColor(status: CheckRow["status"]): string {
    if (status === "fail") return "text-error";
    if (status === "info") return "text-info";
    return "text-muted";
  }
</script>

<div class="min-h-screen flex flex-col bg-bg">
  <!-- Slim header -->
  <header class="flex items-center justify-between px-5 py-3 border-b border-border">
    <button
      onclick={() => goto("/")}
      class="text-xs text-muted hover:text-text transition-colors duration-150
             flex items-center gap-1 rounded focus-visible:outline-none
             focus-visible:ring-2 focus-visible:ring-primary/30"
      aria-label="Back to home"
    >
      ← Back
    </button>
    <span class="text-xs text-subtle">Step 1 of 4</span>
  </header>

  <!-- Scrollable content -->
  <main class="flex-1 overflow-y-auto px-5 py-5">
    <div class="max-w-md mx-auto space-y-4">
      <!-- Title row -->
      <div>
        <h1 class="text-lg font-semibold text-text">System Check</h1>
        <p class="text-sm text-muted mt-0.5">
          {#if streaming}
            Checking your environment…
          {:else if hasFailure}
            Some requirements are missing — see below.
          {:else}
            All requirements met.
          {/if}
        </p>
      </div>

      <!-- Check list -->
      <div
        class="space-y-1.5"
        role="list"
        aria-label="Preflight checks"
        aria-live="polite"
        aria-busy={streaming}
      >
        {#each checks as check, i (i)}
          <div role="listitem" class="rounded-xl overflow-hidden {rowBg(check.status)}">
            <!-- Row header -->
            <div class="flex items-center gap-2.5 px-3 py-2">
              {#if check.status === "ok"}
                <span class="flex-none text-success text-sm leading-none" aria-label="Passed">✓</span>
              {:else if check.status === "fail"}
                <span class="flex-none text-error text-sm leading-none" aria-label="Failed">✕</span>
              {:else}
                <span class="flex-none text-info text-sm leading-none" aria-label="Info">ⓘ</span>
              {/if}

              <span class="text-sm font-medium text-text flex-1">{check.name}</span>

              {#if check.detail}
                <span class="text-xs {detailColor(check.status)} ml-auto max-w-[48%] text-right leading-snug">
                  {check.detail}
                </span>
              {/if}
            </div>

            <!-- Fail: collapsible fix hint -->
            {#if check.status === "fail" && FIX_HINTS[check.name]}
              {@const hint = FIX_HINTS[check.name]}
              <details class="group px-3 pb-2.5">
                <summary
                  class="flex items-center gap-1 text-xs text-error cursor-pointer select-none
                         list-none pb-1 hover:opacity-80 transition-opacity duration-150"
                >
                  <svg
                    class="h-2.5 w-2.5 transition-transform duration-150 group-open:rotate-90"
                    viewBox="0 0 10 10"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path d="M3 1.5l5 3.5-5 3.5V1.5z" />
                  </svg>
                  Fix this
                </summary>
                <div class="mt-1.5 space-y-1.5">
                  <pre
                    class="text-xs font-mono bg-surface rounded-lg p-2.5 overflow-x-auto
                           text-text whitespace-pre leading-relaxed"
                  >{hint.cmd}</pre>
                  {#if hint.note}
                    <p class="text-xs text-muted">{hint.note}</p>
                  {/if}
                </div>
              </details>
            {/if}

            <!-- Info (ollama): nested model list once loaded -->
            {#if check.name === "ollama" && check.status === "info" && ollamaModels !== null}
              <div class="px-3 pb-2.5">
                {#if ollamaModels.length > 0}
                  <p class="text-xs text-info mb-1.5">Available models:</p>
                  <ul class="space-y-0.5" aria-label="Ollama models">
                    {#each ollamaModels as model}
                      <li
                        class="text-xs font-mono text-text bg-surface rounded-lg px-2 py-1 leading-snug"
                      >
                        {model}
                      </li>
                    {/each}
                  </ul>
                {:else}
                  <p class="text-xs text-info">
                    No models installed —
                    <code class="font-mono">ollama pull &lt;model&gt;</code> to add one.
                  </p>
                {/if}
              </div>
            {/if}
          </div>
        {/each}

        <!-- Spinner row while streaming -->
        {#if streaming}
          <div
            class="flex items-center gap-2.5 px-3 py-2 rounded-xl bg-surface"
            aria-label="Running checks"
          >
            <span
              class="flex-none w-3 h-3 rounded-full border-2 border-border border-t-text-subtle
                     animate-spin"
              aria-hidden="true"
            ></span>
            <span class="text-xs text-muted">Checking…</span>
          </div>
        {/if}
      </div>

      <!-- Bottom spacer so content clears the sticky footer -->
      <div class="h-1"></div>
    </div>
  </main>

  <!-- Sticky footer -->
  <footer class="sticky bottom-0 bg-bg/90 backdrop-blur-sm border-t border-border px-5 py-3">
    <div class="max-w-md mx-auto flex items-center justify-between gap-3">
      <p class="text-xs text-muted">
        {#if streaming}
          Running checks…
        {:else if hasFailure}
          Resolve the issues above to continue.
        {:else}
          All checks passed ✓
        {/if}
      </p>
      <Button
        disabled={!canContinue}
        onclick={() => goto("/wizard/inference")}
      >
        Continue
      </Button>
    </div>
  </footer>
</div>
