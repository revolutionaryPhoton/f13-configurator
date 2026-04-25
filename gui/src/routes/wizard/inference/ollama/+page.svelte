<script lang="ts">
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import Footer from "$lib/components/Footer.svelte";
  import PageBody from "$lib/components/PageBody.svelte";
  import PageTitle from "$lib/components/PageTitle.svelte";
  import StepHeader from "$lib/components/StepHeader.svelte";
  import type { Engine } from "$lib/engine.js";
  import { getEngine } from "$lib/engineContext.js";
  import { setWizardVia } from "$lib/wizardPath.js";
  import { setWizardState } from "$lib/wizardState.js";

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
      setWizardState({ ollamaModel: selected });
      setWizardVia("ollama");
      goto("/wizard/ports");
    }
  }
</script>

<div class="flex flex-col h-screen bg-bg">
  <StepHeader step={3} total={4} onBack={() => goto("/wizard/inference")} />

  <PageBody narrow>
    <PageTitle
      kicker="Ollama"
      title="Choose a model"
      subtitle="Pick which Ollama model the chat service should use."
    />

    <!-- GPU / cloud warning — colored left-border accent -->
    <div
      class="mb-3.5 px-3 py-2.5 rounded-lg text-[12px] leading-relaxed text-muted"
      style:background="var(--f13-warning-bg)"
      style:border="1px solid rgba(245,124,0,0.25)"
      style:border-left="3px solid var(--f13-warning)"
      role="note"
    >
      <div
        class="font-bold uppercase mb-1"
        style:font-size="11px"
        style:letter-spacing="0.5px"
        style:color="var(--f13-warning)"
      >
        GPU recommended
      </div>
      Larger models need a capable GPU. Cloud-tagged models (e.g.
      <code
        class="px-1"
        style:font-family="var(--f13-font-mono)"
        style:font-size="11px"
        style:background="var(--f13-surface)"
      >gemma4:31b-cloud</code>) require a signed-in Ollama account.
    </div>

    {#if loadState === "loading"}
      <div class="flex items-center gap-2.5 px-3 py-3 text-[13px] text-muted">
        <span
          class="inline-block w-3.5 h-3.5 rounded-full border-2 border-current border-t-transparent"
          style:animation="f13-spin 700ms linear infinite"
          aria-hidden="true"
        ></span>
        Checking Ollama…
      </div>
    {:else if loadState === "not-running"}
      <div
        class="rounded-xl bg-surface border border-border p-4 flex flex-col gap-3"
        data-testid="not-running"
      >
        <p class="m-0 text-[14px] font-medium text-text">
          Ollama is not running
        </p>
        <p class="m-0 text-[12px] text-muted">
          Start Ollama, then click <strong>Retry</strong> to load your models.
        </p>
        <div class="rounded-lg bg-bg border border-border px-3 py-2">
          <p
            class="m-0 mb-1 text-[11px] text-subtle font-medium"
          >Install &amp; start Ollama</p>
          <pre
            class="m-0 text-[11.5px] text-text leading-snug whitespace-pre"
            style:font-family="var(--f13-font-mono)"
          >brew install ollama
ollama serve</pre>
        </div>
        <div>
          <Button onclick={refresh}>Retry</Button>
        </div>
      </div>
    {:else if models.length === 0}
      <p class="m-0 py-1.5 text-[13px] text-muted">
        No models installed. Pull one with:
        <code
          class="px-1 rounded"
          style:font-family="var(--f13-font-mono)"
          style:background="var(--f13-surface)"
          style:font-size="11.5px"
        >ollama pull gemma4:31b-cloud</code>
      </p>
    {:else}
      <div
        class="flex flex-col gap-1"
        role="radiogroup"
        aria-label="Ollama model"
      >
        {#each models as model (model)}
          {@const cloud = isCloud(model)}
          <label
            class="flex items-center gap-3 px-3 py-2.5 cursor-pointer rounded-lg transition-all duration-150"
            style:background={selected === model
              ? "var(--f13-surface-raised)"
              : "transparent"}
            style:border={selected === model
              ? "1px solid var(--f13-text)"
              : "1px solid transparent"}
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
              class="inline-flex flex-shrink-0 rounded-full border-2"
              style:width="14px"
              style:height="14px"
              style:border-color={selected === model
                ? "var(--f13-text)"
                : "var(--f13-border-strong)"}
              style:background={selected === model
                ? "var(--f13-text)"
                : "transparent"}
              style:box-shadow={selected === model
                ? "inset 0 0 0 3px var(--f13-surface)"
                : "none"}
              aria-hidden="true"
            ></span>
            <span
              class="flex-1 break-all text-text"
              style:font-family="var(--f13-font-mono)"
              style:font-size="12.5px"
            >
              {model}
            </span>
            {#if cloud}
              <span
                class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full font-semibold uppercase"
                style:font-size="10px"
                style:letter-spacing="0.3px"
                style:background="var(--f13-info-bg)"
                style:color="var(--f13-info)"
                style:border="1px solid rgba(30,64,175,0.2)"
                data-testid="cloud-badge"
                aria-label="cloud-tagged model"
              >
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                  <path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z" />
                </svg>
                cloud
              </span>
            {/if}
          </label>
        {/each}
      </div>

      <!-- Refresh link -->
      <button
        type="button"
        class="mt-2.5 inline-flex items-center gap-1 px-2 py-1 text-[11px] text-muted hover:text-text hover:bg-surface-raised rounded-md transition-colors"
        onclick={refresh}
        aria-label="Refresh model list"
      >
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <polyline points="23 4 23 10 17 10" />
          <polyline points="1 20 1 14 7 14" />
          <path d="M3.5 9a9 9 0 0 1 14.8-3.4L23 10M1 14l4.7 4.4A9 9 0 0 0 20.5 15" />
        </svg>
        Refresh list
      </button>
    {/if}
  </PageBody>

  <Footer>
    {#snippet status()}
      {#if loadState === "not-running"}
        Start Ollama to continue.
      {:else if loadState === "loading"}
        Loading models…
      {:else if selected === null}
        Select a model.
      {:else}
        <span style:font-family="var(--f13-font-mono)">{selected}</span> selected.
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
