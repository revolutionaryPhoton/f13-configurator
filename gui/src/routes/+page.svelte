<script lang="ts">
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import type { Engine, StateEvent } from "$lib/engine.js";
  import { getEngine } from "$lib/engineContext.js";

  interface Props {
    engine?: Engine | null;
    generatedDir?: string;
  }

  let {
    engine: injectedEngine = null,
    generatedDir = "./generated",
  }: Props = $props();

  let stateEvent = $state<StateEvent | null>(null);
  let loading = $state(true);

  const hasState = $derived(stateEvent !== null && stateEvent.exists === true);

  $effect(() => {
    let cancelled = false;
    const eng = injectedEngine ?? getEngine();
    if (!eng) {
      loading = false;
      return;
    }
    void eng
      .detectState(generatedDir)
      .then((evt) => {
        if (!cancelled) {
          stateEvent = evt;
          loading = false;
        }
      })
      .catch(() => {
        if (!cancelled) loading = false;
      });
    return () => {
      cancelled = true;
    };
  });
</script>

<div
  class="min-h-screen flex flex-col items-center justify-center bg-bg px-6 py-8"
>
  <div class="flex flex-col items-center gap-5 max-w-xs w-full">
    <!-- F13 logo (inline for currentColor theming) -->
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 120 40"
      fill="none"
      class="w-24 h-8 text-text"
      role="img"
      aria-label="F13"
    >
      <!-- F -->
      <rect x="2" y="4" width="4" height="32" fill="currentColor" />
      <rect x="2" y="4" width="16" height="4" fill="currentColor" />
      <rect x="2" y="18" width="12" height="4" fill="currentColor" />
      <!-- 1 -->
      <rect x="30" y="4" width="4" height="32" fill="currentColor" />
      <rect x="26" y="4" width="4" height="4" fill="currentColor" />
      <!-- 3 -->
      <rect x="44" y="4" width="16" height="4" fill="currentColor" />
      <rect x="56" y="4" width="4" height="16" fill="currentColor" />
      <rect x="44" y="18" width="16" height="4" fill="currentColor" />
      <rect x="56" y="22" width="4" height="14" fill="currentColor" />
      <rect x="44" y="32" width="16" height="4" fill="currentColor" />
    </svg>

    <!-- Heading + tagline -->
    <div class="text-center space-y-1.5">
      <h1 class="text-xl font-semibold text-text">F13 Configurator</h1>
      <p class="text-xs text-muted tracking-wide">
        Minimal · Batteries included · One command
      </p>
    </div>

    <!-- Preset badge -->
    <span
      class="inline-flex items-center rounded-full bg-surface border border-border
             px-2.5 py-0.5 text-xs text-muted font-medium"
    >
      v1 · core + frontend + chat
    </span>

    <!-- CTA buttons -->
    <div class="flex flex-col items-center gap-2 w-full mt-1">
      <Button
        size="lg"
        class="w-full"
        onclick={() => goto("/wizard/preflight")}
      >
        Begin setup
      </Button>

      {#if !loading && hasState}
        <Button
          variant="secondary"
          size="md"
          class="w-full"
          onclick={() => goto("/status")}
        >
          Open existing setup
        </Button>
      {/if}
    </div>

    <!-- Footer hint -->
    <p class="text-xs text-subtle text-center mt-2">
      Keycloak guest mode · No hand-editing required
    </p>
  </div>
</div>
