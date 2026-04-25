<script lang="ts">
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import Modal from "$lib/components/Modal.svelte";
  import Toast from "$lib/components/Toast.svelte";
  import type { Engine } from "$lib/engine.js";
  import { getEngine } from "$lib/engineContext.js";
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
    generatedDir = "./generated",
  }: Props = $props();

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
  let resetting = $state(false);

  // Reset confirmation modal
  let resetConfirmOpen = $state(false);
  let resetConfirmText = $state("");
  const resetConfirmValid = $derived(resetConfirmText === "RESET");

  const wizState = getWizardState();
  const port = $derived(frontendPortProp ?? wizState.frontendPort ?? 9999);
  const frontendUrl = $derived(`http://localhost:${port}`);
  const corePort = $derived(wizState.corePort ?? 8000);

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
    // Production default: Tauri's opener plugin actually opens the user's
    // default browser. window.open is a no-op inside a Tauri webview.
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
    const loadingId = addToast("info", "Stopping F13…", 0);
    try {
      await eng.compose.down(generatedDir);
      removeToast(loadingId);
      addToast("success", "F13 stopped.", 3000);
      goto("/");
    } catch (e) {
      removeToast(loadingId);
      addToast("error", `Stop failed: ${e instanceof Error ? e.message : "unknown error"}`, 6000);
    } finally {
      stopping = false;
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
    const loadingId = addToast("warning", "Resetting F13…", 0);
    try {
      await eng.compose.reset(generatedDir);
      removeToast(loadingId);
      addToast("success", "Reset complete. Starting fresh.", 3000);
      goto("/");
    } catch (e) {
      removeToast(loadingId);
      addToast("error", `Reset failed: ${e instanceof Error ? e.message : "unknown error"}`, 6000);
    } finally {
      resetting = false;
    }
  }

  function handleViewLogs() {
    addToast(
      "info",
      "In your terminal: docker compose -f generated/docker-compose.yml logs -f",
      8000,
    );
  }

  const healthBadgeClass = $derived(
    healthStatus === "healthy"
      ? "bg-success-bg text-success"
      : healthStatus === "unhealthy"
        ? "bg-error-bg text-error"
        : "bg-surface-raised text-muted",
  );

  const healthDotClass = $derived(
    healthStatus === "healthy"
      ? "bg-success"
      : healthStatus === "unhealthy"
        ? "bg-error"
        : "bg-text-muted animate-pulse",
  );

  const healthLabel = $derived(
    healthStatus === "healthy"
      ? "Healthy"
      : healthStatus === "unhealthy"
        ? "Unhealthy"
        : healthStatus === "checking"
          ? "Checking…"
          : "Unknown",
  );
</script>

<div class="min-h-screen flex flex-col bg-bg">
  <!-- Slim header -->
  <header class="flex items-center justify-between px-5 py-3 border-b border-border">
    <h1 class="text-sm font-semibold text-text" data-testid="page-heading">F13 Status</h1>
    <button
      onclick={() => goto("/wizard/preflight")}
      class="text-xs text-muted hover:text-text transition-colors duration-150 rounded
             focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/30"
      aria-label="Reconfigure F13"
      data-testid="reconfigure-btn"
    >
      Reconfigure →
    </button>
  </header>

  <!-- Scrollable content -->
  <main class="flex-1 overflow-y-auto px-5 py-5">
    <div class="max-w-md mx-auto space-y-4">

      <!-- Health card -->
      <div class="rounded-xl bg-surface shadow-sm p-4 space-y-2" data-testid="health-card">
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-text">System health</span>
          <span
            data-testid="health-badge"
            class="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs
                   font-medium {healthBadgeClass}"
          >
            <span class="w-1.5 h-1.5 rounded-full {healthDotClass}" aria-hidden="true"></span>
            {healthLabel}
          </span>
        </div>
        {#if healthMessage}
          <p class="text-xs text-muted" data-testid="health-message">{healthMessage}</p>
        {/if}
        <p class="text-xs text-subtle">
          Core API · <span class="font-mono">localhost:{corePort}</span>
        </p>
      </div>

      <!-- Open in browser CTA -->
      <div class="rounded-xl bg-surface shadow-sm p-4 space-y-3">
        <div>
          <p class="text-sm font-medium text-text">F13 is running</p>
          <p class="text-xs text-muted mt-0.5">
            Frontend · <span class="font-mono">{frontendUrl}</span>
          </p>
        </div>
        <Button variant="primary" onclick={handleOpenBrowser}>
          🌐 Open F13 in browser
        </Button>
      </div>

      <!-- Actions -->
      <div class="rounded-xl bg-surface shadow-sm p-4">
        <p class="text-xs font-medium text-muted uppercase tracking-wide mb-3">Actions</p>
        <div class="flex flex-wrap gap-2">
          <Button variant="secondary" size="sm" onclick={handleViewLogs}>
            View logs
          </Button>
          <Button
            variant="secondary"
            size="sm"
            disabled={stopping}
            onclick={handleStop}
          >
            {stopping ? "Stopping…" : "Stop F13"}
          </Button>
          <Button
            variant="ghost"
            size="sm"
            disabled={resetting}
            onclick={handleReset}
          >
            {resetting ? "Resetting…" : "Full reset"}
          </Button>
        </div>
      </div>

    </div>
  </main>

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
  title="Confirm full reset"
  onclose={handleCloseResetModal}
>
  <div class="space-y-3">
    <p class="text-sm text-text leading-snug">
      This will stop all containers and delete all generated config files.
      <strong>This cannot be undone.</strong>
    </p>
    <div class="space-y-1.5">
      <label for="reset-confirm-input" class="block text-xs font-medium text-text">
        Type <span class="font-mono font-semibold">RESET</span> to confirm
      </label>
      <input
        id="reset-confirm-input"
        type="text"
        bind:value={resetConfirmText}
        placeholder="RESET"
        data-testid="reset-confirm-input"
        autocomplete="off"
        spellcheck={false}
        class="w-full rounded-xl border border-border bg-bg px-3 py-2 text-sm text-text
               focus:outline-none focus:ring-2 focus:ring-error/20 focus:border-error/40
               transition-colors duration-150"
      />
    </div>
    <div class="flex justify-end gap-2 pt-1">
      <Button variant="secondary" size="sm" onclick={handleCloseResetModal}>
        Cancel
      </Button>
      <Button
        variant="primary"
        size="sm"
        disabled={!resetConfirmValid}
        onclick={handleConfirmReset}
      >
        Confirm reset
      </Button>
    </div>
  </div>
</Modal>
