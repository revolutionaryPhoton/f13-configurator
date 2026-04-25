<script lang="ts">
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import Footer from "$lib/components/Footer.svelte";
  import PageBody from "$lib/components/PageBody.svelte";
  import PageTitle from "$lib/components/PageTitle.svelte";
  import StepHeader from "$lib/components/StepHeader.svelte";
  import Tile from "$lib/components/Tile.svelte";
  import { setWizardVia } from "$lib/wizardPath.js";
  import { setWizardState } from "$lib/wizardState.js";

  type Backend = "mock" | "ollama";

  let selected = $state<Backend | null>(null);

  const canContinue = $derived(selected !== null);

  function select(backend: Backend) {
    selected = backend;
  }

  function handleContinue() {
    if (selected === "ollama") {
      setWizardState({ backend: "ollama" });
      goto("/wizard/inference/ollama");
    } else {
      setWizardState({ backend: "mock" });
      setWizardVia("mock");
      goto("/wizard/ports");
    }
  }
</script>

<div class="flex flex-col h-screen bg-bg">
  <StepHeader step={2} total={4} onBack={() => goto("/wizard/preflight")} />

  <PageBody>
    <PageTitle
      kicker="Inference"
      title="Where should chat run?"
      subtitle="Pick how the chat service generates responses. You can change this later."
    />

    <div
      role="radiogroup"
      aria-label="Inference backend"
      class="grid grid-cols-2 gap-3"
    >
      <Tile
        icon="🧪"
        title="Mock"
        description="Built-in stub — deterministic responses, no GPU."
        pros={["Zero config", "Works offline", "Fast"]}
        cons={["Fake responses"]}
        selected={selected === "mock"}
        recommended={true}
        onclick={() => select("mock")}
      />

      <Tile
        icon="🦙"
        title="Ollama"
        description="Connect to your local ollama serve."
        pros={["Real model output", "Full control"]}
        cons={["Needs Ollama running", "GPU recommended"]}
        selected={selected === "ollama"}
        onclick={() => select("ollama")}
      />
    </div>
  </PageBody>

  <Footer>
    {#snippet status()}
      {#if selected === null}
        Select an option.
      {:else if selected === "mock"}
        Mock selected — skipping model picker.
      {:else}
        Ollama selected — pick a model next.
      {/if}
    {/snippet}
    {#snippet action()}
      <Button disabled={!canContinue} onclick={handleContinue}>
        Continue
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <line x1="5" y1="12" x2="19" y2="12" />
          <polyline points="12 5 19 12 12 19" />
        </svg>
      </Button>
    {/snippet}
  </Footer>
</div>
