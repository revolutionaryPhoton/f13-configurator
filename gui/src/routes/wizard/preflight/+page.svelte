<script lang="ts">
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import Footer from "$lib/components/Footer.svelte";
  import PageBody from "$lib/components/PageBody.svelte";
  import PageTitle from "$lib/components/PageTitle.svelte";
  import StepHeader from "$lib/components/StepHeader.svelte";
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

  // Total expected checks — drives the progress-bar fill.
  const TOTAL = 9;

  const hasFailure = $derived(checks.some((c) => c.status === "fail"));
  const canContinue = $derived(!streaming && !hasFailure && checks.length > 0);
  const progressPct = $derived(
    Math.min(100, (checks.length / TOTAL) * 100),
  );

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
</script>

<div class="flex flex-col h-screen bg-bg">
  <StepHeader step={1} total={4} onBack={() => goto("/")} />

  <PageBody narrow>
    <PageTitle
      kicker="Preflight"
      title={streaming
        ? "Scanning environment…"
        : hasFailure
          ? "Some requirements missing"
          : "Environment ready"}
      subtitle="Checking Docker, system tools, and disk space."
    />

    <!-- Scan progress bar with shimmer overlay while streaming -->
    <div
      class="relative overflow-hidden mb-[18px]"
      style:height="8px"
      style:background="var(--f13-surface-raised)"
      style:border-radius="4px"
    >
      <div
        class="absolute inset-0 transition-[width] duration-300"
        style:width="{progressPct}%"
        style:background={streaming
          ? "linear-gradient(90deg, var(--f13-text) 0%, var(--f13-text) 60%, transparent 100%)"
          : "var(--f13-text)"}
      ></div>
      {#if streaming}
        <div
          class="absolute inset-0 pointer-events-none"
          style:background="linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent)"
          style:background-size="200% 100%"
          style:animation="f13-shimmer 1.6s linear infinite"
        ></div>
      {/if}
    </div>

    <!-- Check rows -->
    <div
      class="flex flex-col gap-1"
      role="list"
      aria-label="Preflight checks"
      aria-live="polite"
      aria-busy={streaming}
    >
      {#each checks as check, i (i)}
        <div
          role="listitem"
          style:animation="f13-fadeUp 250ms cubic-bezier(0.4,0,1,1) both"
        >
          <div
            class="flex items-center gap-2.5 px-3 py-2 rounded-lg bg-surface border border-border"
          >
            <span
              class="flex-none flex items-center justify-center"
              style:width="18px"
              style:height="18px"
              style:color={check.status === "ok"
                ? "#16a34a"
                : check.status === "fail"
                  ? "var(--f13-error)"
                  : "var(--f13-text-muted)"}
              aria-label={check.status === "ok"
                ? "Passed"
                : check.status === "fail"
                  ? "Failed"
                  : "Info"}
            >
              {#if check.status === "ok"}
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                  <polyline points="20 6 9 17 4 12" />
                </svg>
              {:else if check.status === "fail"}
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              {:else}
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                  <circle cx="12" cy="12" r="10" />
                  <line x1="12" y1="16" x2="12" y2="12" />
                  <circle cx="12" cy="8" r="0.6" fill="currentColor" />
                </svg>
              {/if}
            </span>
            <span
              class="flex-1 text-[13px] font-medium text-text"
              style:font-family="var(--f13-font-mono)"
            >
              {check.name}
            </span>
            {#if check.detail}
              <span class="text-[11.5px] text-muted text-right max-w-[48%] leading-snug">
                {check.detail}
              </span>
            {/if}
          </div>

          <!-- Fail: collapsible fix hint -->
          {#if check.status === "fail" && FIX_HINTS[check.name]}
            {@const hint = FIX_HINTS[check.name]}
            <details class="group ml-6 mt-1">
              <summary
                class="flex items-center gap-1 text-[11px] text-error cursor-pointer select-none list-none hover:opacity-80 transition-opacity"
              >
                <svg
                  class="w-2.5 h-2.5 transition-transform group-open:rotate-90"
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
                  class="text-[11px] bg-surface rounded-md p-2.5 overflow-x-auto text-text whitespace-pre leading-relaxed"
                  style:font-family="var(--f13-font-mono)"
                >{hint.cmd}</pre>
                {#if hint.note}
                  <p class="text-[11px] text-muted">{hint.note}</p>
                {/if}
              </div>
            </details>
          {/if}

          <!-- Info (ollama): nested model list once loaded -->
          {#if check.name === "ollama" && check.status === "info" && ollamaModels !== null}
            <div
              class="ml-6 mt-1 px-3 py-2 rounded-md bg-surface-raised text-[11px] text-muted"
            >
              {#if ollamaModels.length > 0}
                <div class="mb-1">{ollamaModels.length} models available</div>
                <div class="flex flex-wrap gap-1">
                  {#each ollamaModels.slice(0, 4) as model (model)}
                    <span
                      class="px-1.5 py-0.5 rounded bg-surface border border-border text-[10.5px]"
                      style:font-family="var(--f13-font-mono)"
                    >
                      {model}
                    </span>
                  {/each}
                  {#if ollamaModels.length > 4}
                    <span class="text-subtle">
                      +{ollamaModels.length - 4} more
                    </span>
                  {/if}
                </div>
              {:else}
                <span>No models installed — <code style:font-family="var(--f13-font-mono)">ollama pull &lt;model&gt;</code></span>
              {/if}
            </div>
          {/if}
        </div>
      {/each}

      {#if streaming && checks.length < TOTAL}
        <div class="flex items-center gap-2.5 px-3 py-2 text-[12px] text-muted">
          <span
            class="inline-block w-3.5 h-3.5 rounded-full border-2 border-current border-t-transparent"
            style:animation="f13-spin 700ms linear infinite"
            aria-hidden="true"
          ></span>
          Checking…
        </div>
      {/if}
    </div>
  </PageBody>

  <Footer>
    {#snippet status()}
      {#if streaming}
        Running checks…
      {:else if hasFailure}
        Resolve issues to continue.
      {:else}
        All checks passed.
      {/if}
    {/snippet}
    {#snippet action()}
      <Button
        disabled={!canContinue}
        onclick={() => goto("/wizard/inference")}
      >
        Continue
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <line x1="5" y1="12" x2="19" y2="12" />
          <polyline points="12 5 19 12 12 19" />
        </svg>
      </Button>
    {/snippet}
  </Footer>
</div>
