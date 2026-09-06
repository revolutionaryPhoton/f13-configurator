<script lang="ts">
  import { goto } from "$app/navigation";
  import { getGeneratedDir } from "$lib/bootstrap.js";
  import Button from "$lib/components/Button.svelte";
  import F13Logo from "$lib/components/F13Logo.svelte";
  import Modal from "$lib/components/Modal.svelte";
  import Toast from "$lib/components/Toast.svelte";
  import type { Engine } from "$lib/engine.js";
  import { getEngine } from "$lib/engineContext.js";
  import { t } from "$lib/i18n/index.js";
  import { getWizardState } from "$lib/wizardState.js";

  interface Props {
    engine?: Engine | null;
    /** Injectable for tests and Tauri production (tauri-apps/plugin-opener). */
    openUrl?: (url: string) => void;
    frontendPort?: number;
    generatedDir?: string;
  }

  let {
    engine: injectedEngine = null,
    openUrl: openUrlProp,
    frontendPort: frontendPortProp,
    generatedDir: generatedDirProp,
  }: Props = $props();

  const generatedDir = $derived(
    generatedDirProp ?? getGeneratedDir() ?? "./generated",
  );

  type HealthStatus = "checking" | "healthy" | "unhealthy" | "unknown";

  interface ToastItem {
    id: number;
    type: "success" | "error" | "warning" | "info";
    message: string;
    duration: number;
  }

  let healthStatus = $state<HealthStatus>("checking");
  let healthMessage = $state<string | undefined>(undefined);
  let toasts = $state<ToastItem[]>([]);
  let toastCounter = 0;

  let stopping = $state(false);
  let starting = $state(false);
  let reconfiguring = $state(false);
  let resetting = $state(false);

  let resetConfirmOpen = $state(false);
  let resetConfirmText = $state("");
  const resetConfirmValid = $derived(resetConfirmText === "RESET");

  const wizState = getWizardState();
  const port = $derived(frontendPortProp ?? wizState.frontendPort ?? 9999);
  const frontendUrl = $derived(`http://localhost:${port}`);
  const corePort = $derived(wizState.corePort ?? 8000);
  const backend = $derived(wizState.backend ?? "mock");

  function addToast(type: ToastItem["type"], message: string, duration = 4000): number {
    const id = ++toastCounter;
    toasts = [...toasts, { id, type, message, duration }];
    return id;
  }

  function removeToast(id: number) {
    toasts = toasts.filter((t) => t.id !== id);
  }

  $effect(() => {
    const eng = injectedEngine ?? getEngine();
    if (!eng) return;
    const safeEng: Engine = eng;

    let cancelled = false;

    async function poll() {
      if (cancelled) return;
      try {
        for await (const evt of safeEng.compose.health(generatedDir)) {
          if (cancelled) break;
          if (evt.type === "health") {
            healthStatus = evt.status === "healthy" ? "healthy" : "unhealthy";
            healthMessage = evt.message;
            return;
          }
        }
        if (!cancelled) healthStatus = "unknown";
      } catch {
        if (!cancelled) healthStatus = "unknown";
      }
    }

    void poll();
    const interval = setInterval(() => void poll(), 5000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  });

  function handleOpenBrowser() {
    if (openUrlProp) {
      openUrlProp(frontendUrl);
      return;
    }
    void import("@tauri-apps/plugin-opener")
      .then(({ openUrl }) => openUrl(frontendUrl))
      .catch((err) => {
        // eslint-disable-next-line no-console
        console.error("[status] failed to open browser:", err);
      });
  }

  async function handleStop() {
    const eng = injectedEngine ?? getEngine();
    if (!eng || stopping) return;
    stopping = true;
    const loadingId = addToast("info", t("status.toast.stopping"), 0);
    try {
      await eng.compose.down(generatedDir);
      removeToast(loadingId);
      addToast("success", t("status.toast.stopped"), 3000);
      // Stay on /status so the user sees the new stopped state and can
      // click Start to bring it back up. Re-poll health immediately so
      // the hero flips from healthy → stopped without waiting 5s.
      healthStatus = "unhealthy";
    } catch (e) {
      removeToast(loadingId);
      addToast("error", t("status.toast.stopFailed", { error: e instanceof Error ? e.message : "unknown error" }), 6000);
    } finally {
      stopping = false;
    }
  }

  // Reconfigure on a running stack must bring it down before the wizard
  // re-enters port selection — otherwise the ports the user just chose
  // are still bound by the previous run's containers (HF4). compose.down
  // is idempotent so the call is safe even if the stack is already
  // stopped or never started.
  async function handleReconfigure() {
    const eng = injectedEngine ?? getEngine();
    if (!eng || reconfiguring) return;
    reconfiguring = true;
    const loadingId = addToast("info", t("status.toast.stoppingForReconfig"), 0);
    try {
      if (healthStatus !== "unhealthy") {
        await eng.compose.down(generatedDir);
      }
      removeToast(loadingId);
      goto("/wizard/preflight");
    } catch (e) {
      removeToast(loadingId);
      addToast(
        "error",
        t("status.toast.stopForReconfigFailed", { error: e instanceof Error ? e.message : "unknown error" }),
        6000
      );
      reconfiguring = false;
    }
    // No finally-reset on success: navigation tears the page down.
  }

  async function handleStart() {
    const eng = injectedEngine ?? getEngine();
    if (!eng || starting) return;
    starting = true;
    const loadingId = addToast("info", t("status.toast.starting"), 0);
    try {
      await eng.compose.up(generatedDir);
      removeToast(loadingId);
      addToast("success", t("status.toast.started"), 3000);
      healthStatus = "checking";
      // Force one immediate health probe so the hero flips quickly.
      try {
        for await (const evt of eng.compose.health(generatedDir)) {
          if (evt.type === "health") {
            healthStatus = evt.status === "healthy" ? "healthy" : "unhealthy";
            break;
          }
        }
      } catch {
        // ignore — the 5s poll will catch up
      }
    } catch (e) {
      removeToast(loadingId);
      addToast("error", t("status.toast.startFailed", { error: e instanceof Error ? e.message : "unknown error" }), 6000);
    } finally {
      starting = false;
    }
  }

  function handleReset() {
    if (resetting) return;
    resetConfirmText = "";
    resetConfirmOpen = true;
  }

  function handleCloseResetModal() {
    resetConfirmOpen = false;
    resetConfirmText = "";
  }

  async function handleConfirmReset() {
    const eng = injectedEngine ?? getEngine();
    if (!eng || resetting || !resetConfirmValid) return;
    resetConfirmOpen = false;
    resetting = true;
    const loadingId = addToast("warning", t("status.toast.resetting"), 0);
    try {
      await eng.compose.reset(generatedDir);
      removeToast(loadingId);
      addToast("success", t("status.toast.resetDone"), 3000);
      goto("/");
    } catch (e) {
      removeToast(loadingId);
      addToast("error", t("status.toast.resetFailed", { error: e instanceof Error ? e.message : "unknown error" }), 6000);
    } finally {
      resetting = false;
    }
  }

  function handleViewLogs() {
    addToast("info", t("status.toast.viewLogs"), 8000);
  }

  // Service grid data
  // Image strings are duplicated here for display only; the source of
  // truth is bin/f13-config (_wizard_compute_vars) and the compose
  // template. Keep these in sync when bumping pins.
  const services = $derived([
    { name: "frontend", port, image: "f13-frontend:v3.0.1_based" },
    { name: "core", port: corePort, image: "apisix:3.15.0-ubuntu" },
    { name: "opa", image: "opa:1.18.1-debug" },
    { name: "chat", image: "chat:v3.0.0", extra: backend },
    { name: "feedback-db", image: "postgres:18-alpine" },
    { name: "feedback", image: "feedback:v1.0.1" },
  ]);

  const isHealthy = $derived(healthStatus === "healthy");
  const dotColor = $derived(
    healthStatus === "healthy"
      ? "#4ade80"
      : healthStatus === "checking"
        ? "#fbbf24"
        : "#ef4444",
  );
</script>

<div class="flex flex-col h-screen bg-bg relative">
  <!-- Header -->
  <div
    class="flex items-center justify-between px-[22px] py-[14px] border-b border-border"
  >
    <div class="flex items-center gap-2.5">
      <div class="text-text">
        <F13Logo size={0.8} />
      </div>
      <span
        class="text-[13px] font-semibold"
        style:letter-spacing="-0.1px"
        data-testid="page-heading"
      >{t("status.heading")}</span>
    </div>
    <button
      type="button"
      onclick={handleReconfigure}
      disabled={reconfiguring}
      class="inline-flex items-center gap-1 px-2 py-1 text-xs text-muted hover:text-text hover:bg-surface-raised rounded-md transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
      aria-label={t("status.reconfigure") + " F13"}
      data-testid="reconfigure-btn"
    >
      {reconfiguring ? t("status.reconfiguring") : t("status.reconfigure")}
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <line x1="5" y1="12" x2="19" y2="12" />
        <polyline points="12 5 19 12 12 19" />
      </svg>
    </button>
  </div>

  <!-- Body -->
  <div class="flex-1 overflow-y-auto p-[22px]">
    <div
      class="mx-auto flex flex-col gap-3"
      style:max-width="460px"
      style:animation="f13-fadeUp 350ms cubic-bezier(0.4,0,1,1) both"
    >
      <!-- Hero status card -->
      <div
        class="relative overflow-hidden p-[22px] rounded-[16px] text-white"
        style:background="linear-gradient(135deg, #0a0a0c, #18181b)"
        data-testid="health-card"
      >
        <!-- Decorative concentric circles -->
        <div
          class="absolute pointer-events-none rounded-full"
          style:top="-30px"
          style:right="-30px"
          style:width="160px"
          style:height="160px"
          style:border="1px solid rgba(255,255,255,0.08)"
        ></div>
        <div
          class="absolute pointer-events-none rounded-full"
          style:top="-10px"
          style:right="-10px"
          style:width="120px"
          style:height="120px"
          style:border="1px solid rgba(255,255,255,0.1)"
        ></div>

        <!-- Health badge -->
        <div
          class="relative inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full mb-3.5 font-bold uppercase"
          style:font-size="10px"
          style:letter-spacing="1.5px"
          style:border="1px solid rgba(255,255,255,0.25)"
          data-testid="health-badge"
        >
          <span
            class="inline-block rounded-full"
            style:width="6px"
            style:height="6px"
            style:background={dotColor}
            style:box-shadow="0 0 8px {dotColor}"
            style:animation="f13-pulse 1.4s ease-in-out infinite"
            aria-hidden="true"
          ></span>
          {#if healthStatus === "healthy"}
            {t("status.badge.healthy")}
          {:else if healthStatus === "checking"}
            {t("status.badge.checking")}
          {:else}
            {t("status.badge.stopped")}
          {/if}
        </div>

        <!-- Big title -->
        <div
          class="relative font-bold mb-1"
          style:font-size="24px"
          style:letter-spacing="-0.3px"
        >
          {#if isHealthy}
            {t("status.hero.healthy")}
          {:else if healthStatus === "checking"}
            {t("status.hero.checking")}
          {:else}
            {t("status.hero.stopped")}
          {/if}
        </div>
        <div
          class="relative mb-[18px]"
          style:font-size="13px"
          style:opacity="0.7"
          style:font-family="var(--f13-font-mono)"
        >
          localhost:{port}
        </div>

        {#if healthMessage}
          <div
            class="relative mb-3 text-[11px]"
            style:opacity="0.7"
            data-testid="health-message"
          >
            {healthMessage}
          </div>
        {/if}

        <!-- Contextual hero CTA: Start when stopped, Open browser when healthy -->
        {#if isHealthy}
          <button
            type="button"
            onclick={handleOpenBrowser}
            class="relative w-full inline-flex items-center justify-center gap-2 font-semibold cursor-pointer"
            style:padding="11px 14px"
            style:background="#fff"
            style:color="#000"
            style:border="none"
            style:border-radius="10px"
            style:font-size="13px"
            style:font-family="var(--f13-font)"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <circle cx="12" cy="12" r="10" />
              <line x1="2" y1="12" x2="22" y2="12" />
              <path d="M12 2a15 15 0 0 1 4 10 15 15 0 0 1-4 10 15 15 0 0 1-4-10 15 15 0 0 1 4-10z" />
            </svg>
            {t("status.openBrowser")}
          </button>
        {:else}
          <button
            type="button"
            onclick={handleStart}
            disabled={starting || healthStatus === "checking"}
            class="relative w-full inline-flex items-center justify-center gap-2 font-semibold cursor-pointer disabled:opacity-60 disabled:cursor-wait"
            style:padding="11px 14px"
            style:background="#fff"
            style:color="#000"
            style:border="none"
            style:border-radius="10px"
            style:font-size="13px"
            style:font-family="var(--f13-font)"
            data-testid="status-start-btn"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <polygon points="6 4 20 12 6 20 6 4" />
            </svg>
            {starting ? t("status.starting") : healthStatus === "checking" ? t("status.checking") : t("status.start")}
          </button>
        {/if}
      </div>

      <!-- Service grid -->
      <div class="grid grid-cols-2 gap-2">
        {#each services as svc (svc.name)}
          <div class="p-3 bg-surface border border-border rounded-[10px]">
            <div class="flex items-center gap-1.5 mb-1.5">
              <span
                class="inline-block rounded-full"
                style:width="7px"
                style:height="7px"
                style:background={isHealthy ? "#22c55e" : "#9ca3af"}
                aria-hidden="true"
              ></span>
              <span
                class="text-[12px] font-semibold"
                style:font-family="var(--f13-font-mono)"
              >{svc.name}</span>
            </div>
            <div
              class="text-[10px] text-muted"
              style:font-family="var(--f13-font-mono)"
            >
              {svc.image}
            </div>
            {#if svc.port}
              <div
                class="text-[10.5px] text-subtle mt-[3px]"
                style:font-family="var(--f13-font-mono)"
              >
                :{svc.port}
              </div>
            {/if}
            {#if svc.extra}
              <div class="text-[10px] text-subtle mt-[3px]">
                backend: {svc.extra}
              </div>
            {/if}
          </div>
        {/each}
      </div>

      <!-- Actions panel -->
      <div class="p-3.5 bg-surface border border-border rounded-xl">
        <div
          class="text-[10px] font-bold text-subtle uppercase mb-2.5"
          style:letter-spacing="1px"
        >
          {t("status.actions.title")}
        </div>
        <div class="flex flex-wrap gap-1.5">
          <Button variant="secondary" size="sm" onclick={handleViewLogs}>
            {t("status.actions.viewLogs")}
          </Button>
          <Button
            variant="secondary"
            size="sm"
            disabled={stopping || !isHealthy}
            onclick={handleStop}
          >
            {stopping ? t("status.actions.stopping") : t("status.actions.stop")}
          </Button>
          <button
            type="button"
            disabled={resetting}
            onclick={handleReset}
            class="inline-flex items-center gap-1 px-2.5 py-1 text-[12px] cursor-pointer rounded-md hover:bg-error/10 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            style:color="var(--f13-error)"
          >
            {resetting ? t("status.actions.resetting") : t("status.actions.reset")}
          </button>
        </div>
      </div>

      <!-- Disclaimer -->
      <p
        class="m-0 text-center text-[10.5px] text-subtle leading-relaxed"
      >
        {t("status.disclaimer")}
      </p>
    </div>
  </div>

  <!-- Sticky toast stack -->
  {#if toasts.length > 0}
    <div
      role="region"
      aria-label="Notifications"
      aria-live="polite"
      class="fixed bottom-4 right-4 flex flex-col gap-2 z-50 w-full max-w-sm"
      data-testid="toast-stack"
    >
      {#each toasts as toast (toast.id)}
        <Toast
          message={toast.message}
          type={toast.type}
          duration={toast.duration}
          onclose={() => removeToast(toast.id)}
        />
      {/each}
    </div>
  {/if}
</div>

<!-- Reset confirmation modal -->
<Modal
  open={resetConfirmOpen}
  title={t("status.reset.modal.title")}
  onclose={handleCloseResetModal}
>
  <div class="flex flex-col gap-3">
    <p class="m-0 text-[13px] text-text leading-snug">
      {t("status.reset.modal.body")}
    </p>
    <div class="flex flex-col gap-1.5">
      <label
        for="reset-confirm-input"
        class="block text-[11px] font-semibold text-text"
      >
        {t("status.reset.modal.inputLabel")}
      </label>
      <input
        id="reset-confirm-input"
        type="text"
        bind:value={resetConfirmText}
        placeholder="RESET"
        data-testid="reset-confirm-input"
        autocomplete="off"
        spellcheck={false}
        onkeydown={(e) => {
          if (e.key === "Enter" && resetConfirmValid) {
            e.preventDefault();
            void handleConfirmReset();
          }
        }}
        class="w-full rounded-lg px-2.5 py-2 outline-none focus:ring-2"
        style:font-family="var(--f13-font-mono)"
        style:font-size="13px"
        style:background="var(--f13-bg)"
        style:border="1px solid var(--f13-border-strong)"
        style:color="var(--f13-text)"
      />
      <p class="m-0 text-[10.5px] text-subtle">
        {t("status.reset.modal.enterHintBefore")}<kbd
          class="px-1 py-[1px] rounded border text-[10px]"
          style:font-family="var(--f13-font-mono)"
          style:border-color="var(--f13-border)"
          style:background="var(--f13-surface-raised)"
        >Enter</kbd>{t("status.reset.modal.enterHintAfter")}
      </p>
    </div>
    <div class="flex justify-end gap-2 pt-1">
      <Button variant="secondary" size="sm" onclick={handleCloseResetModal}>
        {t("status.reset.modal.cancel")}
      </Button>
      <Button
        variant="primary"
        size="sm"
        disabled={!resetConfirmValid}
        onclick={handleConfirmReset}
      >
        {t("status.reset.modal.confirm")}
      </Button>
    </div>
  </div>
</Modal>
