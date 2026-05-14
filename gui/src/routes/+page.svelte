<script lang="ts">
  import { goto } from "$app/navigation";
  import { getGeneratedDir } from "$lib/bootstrap.js";
  import Button from "$lib/components/Button.svelte";
  import { t } from "$lib/i18n/index.js";
  import F13Logo from "$lib/components/F13Logo.svelte";
  import LocalePicker from "$lib/components/LocalePicker.svelte";
  import type { Engine, StateEvent } from "$lib/engine.js";
  import { getEngine } from "$lib/engineContext.js";

  interface Props {
    engine?: Engine | null;
    generatedDir?: string;
  }

  let {
    engine: injectedEngine = null,
    generatedDir: generatedDirProp,
  }: Props = $props();

  const generatedDir = $derived(
    generatedDirProp ?? getGeneratedDir() ?? "./generated",
  );

  let stateEvent = $state<StateEvent | null>(null);
  let loading = $state(true);
  let isRunning = $state<boolean | null>(null);
  let stopping = $state(false);
  let stopError = $state<string | null>(null);

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
      .then(async (evt) => {
        if (cancelled) return;
        stateEvent = evt;
        loading = false;

        if (!evt.exists) return;

        // Check if the deployment is currently healthy.
        try {
          for await (const healthEvt of eng.compose.health(generatedDir)) {
            if (cancelled) break;
            if (healthEvt.type === "health") {
              if (!cancelled) isRunning = healthEvt.status === "healthy";
              break;
            }
          }
        } catch {
          // health check failed — treat as not running
        }
      })
      .catch(() => {
        if (!cancelled) loading = false;
      });
    return () => {
      cancelled = true;
    };
  });

  async function handleStopAndReconfigure() {
    const eng = injectedEngine ?? getEngine();
    if (!eng || stopping) return;
    stopping = true;
    stopError = null;
    try {
      await eng.compose.down(generatedDir);
      goto("/wizard/preflight");
    } catch (e) {
      stopError = e instanceof Error ? e.message : "unknown error";
      stopping = false;
    }
  }
</script>

<div
  class="min-h-screen flex flex-col items-center justify-center bg-bg px-6 py-10 relative"
>
  <div
    class="flex flex-col items-center w-full"
    style:max-width="360px"
    style:gap="22px"
    style:animation="f13-fadeUp 500ms cubic-bezier(0.4,0,1,1) both"
  >
    <!-- Pixel-style F13 mark -->
    <div class="text-text">
      <F13Logo size={1.6} />
    </div>

    <!-- Heading + tagline -->
    <div class="text-center">
      <h1
        class="m-0 text-xl font-semibold text-text"
        style:letter-spacing="-0.2px"
      >
        {t("welcome.title")}
      </h1>
      <p
        class="mt-1.5 mb-0 text-[12px] text-subtle"
        style:letter-spacing="0.3px"
      >
        {t("welcome.tagline")}
      </p>
    </div>

    <!-- Preset badge — green status dot + monospaced descriptor -->
    <span
      class="inline-flex items-center gap-1.5 px-3 py-[5px] rounded-full border text-[11px] text-muted"
      style:border-color="var(--f13-border-strong)"
      style:font-family="var(--f13-font-mono)"
    >
      <span
        class="inline-block w-1.5 h-1.5 rounded-full"
        style:background="#22c55e"
        aria-hidden="true"
      ></span>
      v1 · core + frontend + chat
    </span>

    <!-- Already running banner -->
    {#if isRunning}
      <div
        class="w-full rounded-xl bg-success-bg border border-success/20 px-4 py-3 space-y-3"
        data-testid="already-running-banner"
      >
        <div class="flex items-center gap-2">
          <span class="w-2 h-2 rounded-full bg-success" aria-hidden="true"></span>
          <p class="text-sm font-medium text-success">{t("welcome.alreadyRunning.title")}</p>
        </div>
        <div class="flex flex-col gap-2">
          <Button
            variant="primary"
            size="sm"
            onclick={() => goto("/status")}
          >
            {t("welcome.alreadyRunning.showStatus")}
          </Button>
          <Button
            variant="secondary"
            size="sm"
            disabled={stopping}
            onclick={handleStopAndReconfigure}
          >
            {stopping ? t("welcome.alreadyRunning.stopping") : t("welcome.alreadyRunning.stopAndReconfigure")}
          </Button>
          {#if stopError}
            <p class="text-xs text-error" data-testid="stop-error">{stopError}</p>
          {/if}
        </div>
      </div>
    {:else}
      <!-- CTA buttons (normal flow) -->
      <div class="flex flex-col items-center gap-2 w-full mt-1">
        <Button
          size="lg"
          class="w-full"
          onclick={() => goto("/wizard/preflight")}
        >
          {t("welcome.beginSetup")}
        </Button>

        {#if !loading && hasState}
          <Button
            variant="secondary"
            size="md"
            class="w-full"
            onclick={() => goto("/status")}
          >
            {t("welcome.openExisting")}
          </Button>
        {/if}
      </div>
    {/if}

    <!-- Footer hint -->
    <p
      class="m-0 mt-1.5 text-[11px] text-subtle text-center leading-relaxed"
    >
      {t("welcome.footer")}
    </p>
  </div>

  <!-- Absolute bottom bar: copyright + locale picker -->
  <div
    class="absolute bottom-3.5 left-0 right-0 flex items-center justify-between px-6 text-[10px] text-subtle"
    style:font-family="var(--f13-font-mono)"
  >
    <span>MIT · © 2026 David Moch</span>
    <LocalePicker />
  </div>
</div>
