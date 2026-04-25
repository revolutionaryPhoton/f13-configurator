<script lang="ts">
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import Tile from "$lib/components/Tile.svelte";
  import { setWizardVia } from "$lib/wizardPath.js";

  type Backend = "mock" | "ollama";

  let selected = $state<Backend | null>(null);

  const canContinue = $derived(selected !== null);

  function select(backend: Backend) {
    selected = backend;
  }

  function handleContinue() {
    if (selected === "ollama") {
      goto("/wizard/inference/ollama");
    } else {
      setWizardVia("mock");
      goto("/wizard/ports");
    }
  }
</script>

<div class="min-h-screen flex flex-col bg-bg">
  <!-- Slim header -->
  <header class="flex items-center justify-between px-5 py-3 border-b border-border">
    <button
      onclick={() => goto("/wizard/preflight")}
      class="text-xs text-muted hover:text-text transition-colors duration-150
             flex items-center gap-1 rounded focus-visible:outline-none
             focus-visible:ring-2 focus-visible:ring-primary/30"
      aria-label="Back to preflight"
    >
      ← Back
    </button>
    <span class="text-xs text-subtle">Step 2 of 4</span>
  </header>

  <!-- Scrollable content -->
  <main class="flex-1 overflow-y-auto px-5 py-5">
    <div class="max-w-md mx-auto space-y-4">
      <!-- Title -->
      <div>
        <h1 class="text-lg font-semibold text-text">Choose inference backend</h1>
        <p class="text-sm text-muted mt-0.5">
          How should the chat service generate responses?
        </p>
      </div>

      <!-- Tile group -->
      <div
        role="radiogroup"
        aria-label="Inference backend"
        class="grid grid-cols-1 gap-3 sm:grid-cols-2"
      >
        <Tile
          icon="🧪"
          title="Mock"
          description="Built-in stub — no GPU required."
          pros={["Zero config", "Works offline", "Fast to start"]}
          cons={["Fake responses only"]}
          selected={selected === "mock"}
          recommended={true}
          onclick={() => select("mock")}
        />

        <Tile
          icon="🦙"
          title="Ollama"
          description="Your local Ollama instance."
          pros={["Real model output", "Full control"]}
          cons={["Requires Ollama running", "GPU recommended"]}
          selected={selected === "ollama"}
          onclick={() => select("ollama")}
        />
      </div>
    </div>
  </main>

  <!-- Sticky footer -->
  <footer class="sticky bottom-0 bg-bg/90 backdrop-blur-sm border-t border-border px-5 py-3">
    <div class="max-w-md mx-auto flex items-center justify-between gap-3">
      <p class="text-xs text-muted">
        {#if selected === null}
          Select a backend to continue.
        {:else if selected === "mock"}
          Mock selected — skipping model config.
        {:else}
          Ollama selected — pick a model next.
        {/if}
      </p>
      <Button disabled={!canContinue} onclick={handleContinue}>
        Continue
      </Button>
    </div>
  </footer>
</div>
