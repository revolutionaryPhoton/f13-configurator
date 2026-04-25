<script lang="ts">
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import type { Engine } from "$lib/engine.js";
  import { getEngine } from "$lib/engineContext.js";

  interface Props {
    engine?: Engine | null;
  }

  let { engine: injectedEngine = null }: Props = $props();

  type LoadState = "loading" | "running" | "not-running";

  let loadState = $state<LoadState>("loading");
  let models = $state<string[]>([]);
  let selected = $state<string | null>(null);
  let refreshKey = $state(0);

  $effect(() => {
    void refreshKey;
    const eng = injectedEngine ?? getEngine();

    if (!eng) {
      loadState = "not-running";
      return;
    }

    let cancelled = false;
    loadState = "loading";

    eng.listOllamaModels().then((result) => {
      if (cancelled) return;
      if (result === "not-running") {
        loadState = "not-running";
        models = [];
      } else {
        loadState = "running";
        models = result;
        if (selected === null || !result.includes(selected)) {
          const preferred = result.find((m) => m === "gemma4:31b-cloud");
          selected = preferred ?? result[0] ?? null;
        }
      }
    });

    return () => {
      cancelled = true;
    };
  });

  function refresh() {
    refreshKey += 1;
  }

  function isCloud(name: string): boolean {
    const idx = name.indexOf(":");
    if (idx === -1) return false;
    return name.slice(idx + 1).endsWith("cloud");
  }

  const canContinue = $derived(loadState === "running" && selected !== null);

  function handleContinue() {
    if (selected) {
      goto("/wizard/ports");
    }
  }
</script>

<div class="min-h-screen flex flex-col bg-bg">
  <!-- Slim header -->
  <header class="flex items-center justify-between px-5 py-3 border-b border-border">
    <button
      onclick={() => goto("/wizard/inference")}
      class="text-xs text-muted hover:text-text transition-colors duration-150
             flex items-center gap-1 rounded focus-visible:outline-none
             focus-visible:ring-2 focus-visible:ring-primary/30"
      aria-label="Back to inference picker"
    >
      ← Back
    </button>
    <span class="text-xs text-subtle">Step 3 of 4</span>
  </header>

  <!-- Scrollable content -->
  <main class="flex-1 overflow-y-auto px-5 py-5">
    <div class="max-w-md mx-auto space-y-4">
      <!-- Title -->
      <div>
        <h1 class="text-lg font-semibold text-text">Choose an Ollama model</h1>
        <p class="text-sm text-muted mt-0.5">
          Select the model Ollama will use for chat responses.
        </p>
      </div>

      <!-- GPU / cloud warning -->
      <div
        class="rounded-xl border border-warning/30 bg-warning/8 px-4 py-3 space-y-1.5"
        role="note"
        aria-label="GPU and cloud model requirements"
      >
        <p class="text-xs font-semibold text-warning">GPU recommended</p>
        <p class="text-xs text-muted leading-relaxed">
          Larger models require a capable GPU; on CPU-only hardware responses can take
          many seconds per token.
        </p>
        <p class="text-xs text-muted leading-relaxed">
          Models whose tag ends in <code class="font-mono bg-surface rounded px-0.5">cloud</code>
          (e.g. <code class="font-mono bg-surface rounded px-0.5">gemma4:31b-cloud</code>)
          require a signed-in Ollama account — pull them after signing in.
        </p>
      </div>

      <!-- Content area: loading / not-running / model list -->
      {#if loadState === "loading"}
        <div
          class="flex items-center gap-2 text-sm text-muted py-4"
          aria-label="Loading models"
        >
          <span
            class="inline-block h-3.5 w-3.5 flex-shrink-0 rounded-full border-2
                   border-primary/40 border-t-primary animate-spin"
            aria-hidden="true"
          ></span>
          Checking Ollama…
        </div>

      {:else if loadState === "not-running"}
        <div
          class="rounded-xl bg-surface shadow-sm p-4 space-y-3"
          data-testid="not-running"
        >
          <p class="text-sm font-medium text-text">Ollama is not running</p>
          <p class="text-xs text-muted">
            Start Ollama, then click <strong>Retry</strong> to load your models.
          </p>
          <div
            class="rounded-lg bg-bg border border-border px-3 py-2.5 space-y-1"
          >
            <p class="text-xs text-subtle font-medium mb-1">Install &amp; start Ollama</p>
            <pre class="text-xs font-mono text-text leading-snug whitespace-pre">brew install ollama
ollama serve</pre>
          </div>
          <div>
            <Button onclick={refresh}>Retry</Button>
          </div>
        </div>

      {:else}
        <!-- Running: model list -->
        {#if models.length === 0}
          <p class="text-sm text-muted py-2">
            No models installed. Pull one with:
            <code class="font-mono bg-surface rounded px-1 text-xs">
              ollama pull gemma4:31b-cloud
            </code>
          </p>
        {:else}
          <div
            class="space-y-0.5"
            role="radiogroup"
            aria-label="Ollama model"
          >
            {#each models as model (model)}
              {@const cloud = isCloud(model)}
              <label
                class="flex items-center gap-3 rounded-xl px-3 py-2.5 cursor-pointer
                       hover:bg-surface transition-colors duration-150
                       {selected === model ? 'bg-surface ring-1 ring-primary/20' : ''}"
              >
                <input
                  type="radio"
                  name="ollama-model"
                  value={model}
                  checked={selected === model}
                  onchange={() => { selected = model; }}
                  class="sr-only"
                  aria-label={model}
                />
                <span
                  class="inline-flex h-4 w-4 flex-shrink-0 rounded-full border-2 transition-colors duration-150
                         {selected === model
                           ? 'border-primary bg-primary'
                           : 'border-secondary/40 bg-transparent'}"
                  aria-hidden="true"
                ></span>
                <span class="text-sm text-text flex-1 font-mono break-all">{model}</span>
                {#if cloud}
                  <span
                    class="inline-flex items-center gap-0.5 flex-shrink-0 rounded-full
                           bg-info/10 border border-info/20 px-1.5 py-0.5 text-xs text-info"
                    data-testid="cloud-badge"
                    aria-label="cloud-tagged model"
                  >
                    ☁ cloud
                  </span>
                {/if}
              </label>
            {/each}
          </div>
        {/if}

        <!-- Refresh link -->
        <button
          onclick={refresh}
          class="text-xs text-muted hover:text-text transition-colors duration-150
                 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/30
                 rounded"
          aria-label="Refresh model list"
        >
          ↻ Refresh list
        </button>
      {/if}
    </div>
  </main>

  <!-- Sticky footer -->
  <footer
    class="sticky bottom-0 bg-bg/90 backdrop-blur-sm border-t border-border px-5 py-3"
  >
    <div class="max-w-md mx-auto flex items-center justify-between gap-3">
      <p class="text-xs text-muted">
        {#if loadState === "not-running"}
          Start Ollama to continue.
        {:else if loadState === "loading"}
          Loading models…
        {:else if selected === null}
          Select a model to continue.
        {:else}
          <span class="font-mono">{selected}</span> selected.
        {/if}
      </p>
      <Button disabled={!canContinue} onclick={handleContinue}>
        Continue
      </Button>
    </div>
  </footer>
</div>
