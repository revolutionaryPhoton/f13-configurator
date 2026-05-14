<script lang="ts">
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import Footer from "$lib/components/Footer.svelte";
  import { t } from "$lib/i18n/index.js";
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
      kicker={t("inference.kicker")}
      title={t("inference.title")}
      subtitle={t("inference.subtitle")}
    />

    <div
      role="radiogroup"
      aria-label={t("inference.radioLabel")}
      class="grid grid-cols-2 gap-3"
    >
      <Tile
        icon="🧪"
        title={t("inference.mock.title")}
        description={t("inference.mock.description")}
        pros={[t("inference.mock.pro1"), t("inference.mock.pro2"), t("inference.mock.pro3")]}
        cons={[t("inference.mock.con1")]}
        selected={selected === "mock"}
        recommended={true}
        onclick={() => select("mock")}
      />

      <Tile
        icon="🦙"
        title={t("inference.ollama.title")}
        description={t("inference.ollama.description")}
        pros={[t("inference.ollama.pro1"), t("inference.ollama.pro2")]}
        cons={[t("inference.ollama.con1"), t("inference.ollama.con2")]}
        selected={selected === "ollama"}
        onclick={() => select("ollama")}
      />
    </div>
  </PageBody>

  <Footer>
    {#snippet status()}
      {#if selected === null}
        {t("inference.footer.none")}
      {:else if selected === "mock"}
        {t("inference.footer.mock")}
      {:else}
        {t("inference.footer.ollama")}
      {/if}
    {/snippet}
    {#snippet action()}
      <Button disabled={!canContinue} onclick={handleContinue}>
        {t("common.continue")}
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <line x1="5" y1="12" x2="19" y2="12" />
          <polyline points="12 5 19 12 12 19" />
        </svg>
      </Button>
    {/snippet}
  </Footer>
</div>
