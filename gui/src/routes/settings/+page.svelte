<script lang="ts">
  import { goto } from "$app/navigation";
  import { onMount } from "svelte";
  import { getGeneratedDir } from "$lib/bootstrap.js";
  import Button from "$lib/components/Button.svelte";
  import Modal from "$lib/components/Modal.svelte";
  import Toast from "$lib/components/Toast.svelte";
  import { t } from "$lib/i18n/index.js";
  import { getTheme, setTheme as persistTheme, type Theme } from "$lib/theme.js";
  import { zoom, ZOOM_MIN, ZOOM_MAX } from "$lib/zoom.js";

  interface Props {
    /** Injectable for tests and Tauri production (tauri-apps/plugin-fs). */
    readFile?: (path: string) => Promise<string>;
    /** Base dir for generated config files. */
    generatedDir?: string;
    /** Injectable for tests: write text to clipboard. */
    copyToClipboard?: (text: string) => Promise<void>;
  }

  let {
    readFile: readFileProp,
    generatedDir: generatedDirProp,
    copyToClipboard: clipProp,
  }: Props = $props();

  const generatedDir = $derived(
    generatedDirProp ?? getGeneratedDir() ?? "./generated",
  );

  // ---------------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------------

  const themeOptions: Theme[] = ["system", "light", "dark"];
  let theme = $state<Theme>("system");

  onMount(() => {
    theme = getTheme();
  });

  function handleThemeSelect(t: Theme) {
    theme = t;
    persistTheme(t);
  }

  // ---------------------------------------------------------------------------
  // Config files
  // ---------------------------------------------------------------------------

  interface FileEntry {
    label: string;
    path: string;
    content: string | null;
    error: string | null;
    expanded: boolean;
    copying: boolean;
    loading: boolean;
  }

  let configFiles = $state<FileEntry[]>([
    {
      label: "docker-compose.yml",
      path: "docker-compose.yml",
      content: null,
      error: null,
      expanded: false,
      copying: false,
      loading: false,
    },
    {
      label: ".env",
      path: ".env",
      content: null,
      error: null,
      expanded: false,
      copying: false,
      loading: false,
    },
    {
      label: "core/general.yml",
      path: "core/general.yml",
      content: null,
      error: null,
      expanded: false,
      copying: false,
      loading: false,
    },
    {
      label: "chat/llm_models.yml",
      path: "chat/llm_models.yml",
      content: null,
      error: null,
      expanded: false,
      copying: false,
      loading: false,
    },
  ]);

  async function loadFile(file: FileEntry): Promise<void> {
    if (file.content !== null || file.error !== null || file.loading) return;
    file.loading = true;
    const rf = readFileProp;
    if (!rf) {
      file.error = "File reading not available";
      file.loading = false;
      return;
    }
    try {
      file.content = await rf(`${generatedDir}/${file.path}`);
    } catch (e) {
      file.error = e instanceof Error ? e.message : "Could not read file";
    } finally {
      file.loading = false;
    }
  }

  function toggleFile(file: FileEntry) {
    file.expanded = !file.expanded;
    if (file.expanded) void loadFile(file);
  }

  async function copyFile(file: FileEntry) {
    if (!file.content) return;
    file.copying = true;
    try {
      const clip = clipProp ?? ((t: string) => navigator.clipboard.writeText(t));
      await clip(file.content);
      pushToast("success", t("settings.config.toast.copied", { label: file.label }));
    } catch {
      pushToast("error", t("settings.config.toast.copyFailed"));
    } finally {
      file.copying = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Coming-soon modal
  // ---------------------------------------------------------------------------

  let comingSoonOpen = $state(false);

  // ---------------------------------------------------------------------------
  // Toast
  // ---------------------------------------------------------------------------

  interface ToastItem {
    id: number;
    type: "success" | "error" | "warning" | "info";
    message: string;
  }

  let toasts = $state<ToastItem[]>([]);
  let toastSeq = 0;

  function pushToast(type: ToastItem["type"], message: string) {
    const id = ++toastSeq;
    toasts = [...toasts, { id, type, message }];
  }

  function dismissToast(id: number) {
    toasts = toasts.filter((t) => t.id !== id);
  }
</script>

<div class="min-h-screen bg-bg px-4 py-3 max-w-2xl mx-auto space-y-4">
  <!-- Header -->
  <header class="flex items-center gap-2">
    <button
      type="button"
      aria-label={t("settings.back")}
      onclick={() => goto("/status")}
      class="rounded-full p-1.5 text-text-muted hover:bg-text/5 transition-colors duration-150
             focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/30"
    >
      <svg
        class="h-4 w-4"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 20 20"
        fill="currentColor"
        aria-hidden="true"
      >
        <path
          fill-rule="evenodd"
          d="M11.78 5.22a.75.75 0 0 1 0 1.06L8.06 10l3.72 3.72a.75.75 0 1 1-1.06
             1.06l-4.25-4.25a.75.75 0 0 1 0-1.06l4.25-4.25a.75.75 0 0 1 1.06 0z"
          clip-rule="evenodd"
        />
      </svg>
    </button>
    <h1 class="text-lg font-semibold text-text">{t("settings.title")}</h1>
  </header>

  <!-- Appearance -->
  <section
    aria-labelledby="appearance-heading"
    class="rounded-xl bg-surface shadow-sm p-4 space-y-3"
  >
    <h2 id="appearance-heading" class="text-sm font-semibold text-text">{t("settings.appearance.title")}</h2>
    <div class="flex items-center justify-between gap-4">
      <span class="text-sm text-text-muted">{t("settings.appearance.theme")}</span>
      <div
        role="radiogroup"
        aria-label={t("settings.appearance.theme")}
        class="flex gap-0.5 rounded-lg bg-surface-raised p-0.5"
      >
        {#each themeOptions as option}
          <button
            type="button"
            role="radio"
            aria-checked={theme === option}
            data-testid={`theme-${option}`}
            onclick={() => handleThemeSelect(option)}
            class="rounded-md px-3 py-1 text-xs font-medium capitalize transition-colors
                   duration-150 focus-visible:outline-none focus-visible:ring-2
                   focus-visible:ring-primary/30
                   {theme === option
                     ? 'bg-surface shadow-sm text-text'
                     : 'text-text-muted hover:text-text'}"
          >
            {option}
          </button>
        {/each}
      </div>
    </div>

    <!-- Zoom control -->
    <div class="flex items-center justify-between gap-4">
      <span class="text-sm text-text-muted">{t("settings.appearance.zoom")}</span>
      <div
        role="group"
        aria-label={t("settings.appearance.zoom")}
        class="flex items-center gap-0.5 rounded-lg bg-surface-raised p-0.5"
      >
        <button
          type="button"
          aria-label={t("settings.appearance.zoomOut")}
          data-testid="zoom-out"
          disabled={$zoom <= ZOOM_MIN}
          onclick={() => zoom.zoomOut()}
          class="rounded-md w-7 h-7 flex items-center justify-center text-sm font-medium
                 text-text-muted hover:text-text hover:bg-surface
                 disabled:opacity-40 disabled:pointer-events-none
                 transition-colors duration-150 focus-visible:outline-none
                 focus-visible:ring-2 focus-visible:ring-primary/30"
        >−</button>
        <button
          type="button"
          aria-label={t("settings.appearance.zoomReset")}
          data-testid="zoom-reset"
          onclick={() => zoom.reset()}
          class="rounded-md px-2.5 py-0.5 text-xs font-mono font-medium text-text
                 hover:bg-surface transition-colors duration-150 min-w-[3.25rem] text-center
                 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/30"
        >{Math.round($zoom * 100)}%</button>
        <button
          type="button"
          aria-label={t("settings.appearance.zoomIn")}
          data-testid="zoom-in"
          disabled={$zoom >= ZOOM_MAX}
          onclick={() => zoom.zoomIn()}
          class="rounded-md w-7 h-7 flex items-center justify-center text-sm font-medium
                 text-text-muted hover:text-text hover:bg-surface
                 disabled:opacity-40 disabled:pointer-events-none
                 transition-colors duration-150 focus-visible:outline-none
                 focus-visible:ring-2 focus-visible:ring-primary/30"
        >+</button>
      </div>
    </div>
  </section>

  <!-- Generated config -->
  <section
    aria-labelledby="config-heading"
    class="rounded-xl bg-surface shadow-sm p-4 space-y-3"
  >
    <div>
      <h2 id="config-heading" class="text-sm font-semibold text-text">{t("settings.config.title")}</h2>
      <p class="text-xs text-text-muted mt-0.5">
        {t("settings.config.subtitle", { dir: generatedDir })}
      </p>
    </div>

    <ul class="space-y-1" role="list">
      {#each configFiles as file (file.path)}
        <li class="rounded-lg border border-border overflow-hidden">
          <!-- row: toggle + copy -->
          <div class="flex items-center">
            <button
              type="button"
              onclick={() => toggleFile(file)}
              aria-expanded={file.expanded}
              data-testid={`toggle-${file.path}`}
              class="flex-1 flex items-center gap-2 px-3 py-2 text-left hover:bg-surface-raised
                     transition-colors duration-150 focus-visible:outline-none
                     focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-primary/30"
            >
              <svg
                class="h-3.5 w-3.5 shrink-0 text-text-muted transition-transform duration-150
                       {file.expanded ? 'rotate-90' : ''}"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fill-rule="evenodd"
                  d="M7.21 14.77a.75.75 0 0 1 .02-1.06L11.168 10 7.23 6.29a.75.75 0 1
                     1 1.04-1.08l4.5 4.25a.75.75 0 0 1 0 1.08l-4.5 4.25a.75.75 0 0
                     1-1.06-.02z"
                  clip-rule="evenodd"
                />
              </svg>
              <span class="font-mono text-xs text-text-muted">{file.label}</span>
            </button>

            {#if file.expanded && file.content !== null}
              <button
                type="button"
                disabled={file.copying}
                onclick={() => void copyFile(file)}
                data-testid={`copy-${file.path}`}
                class="shrink-0 mr-2 rounded-lg px-2 py-0.5 text-xs font-medium border
                       border-border bg-transparent text-text-muted hover:text-text
                       hover:bg-surface-raised disabled:opacity-50
                       disabled:pointer-events-none transition-colors duration-150
                       focus-visible:outline-none focus-visible:ring-2
                       focus-visible:ring-primary/30"
              >
                {file.copying ? t("settings.config.copying") : t("settings.config.copy")}
              </button>
            {/if}
          </div>

          <!-- accordion body -->
          {#if file.expanded}
            <div class="border-t border-border bg-surface-raised px-3 py-2">
              {#if file.loading}
                <p
                  class="text-xs text-text-muted animate-pulse"
                  data-testid={`loading-${file.path}`}
                >
                  {t("settings.config.loading")}
                </p>
              {:else if file.content !== null}
                <pre
                  class="text-xs font-mono text-text-subtle whitespace-pre overflow-x-auto
                         leading-relaxed max-h-48 overflow-y-auto"
                  data-testid={`content-${file.path}`}>{file.content}</pre>
              {:else if file.error !== null}
                <p class="text-xs text-error" data-testid={`error-${file.path}`}>
                  {file.error}
                </p>
              {/if}
            </div>
          {/if}
        </li>
      {/each}
    </ul>
  </section>

  <!-- System prompts -->
  <section
    aria-labelledby="prompts-heading"
    class="rounded-xl bg-surface shadow-sm p-4 space-y-3"
  >
    <div>
      <h2 id="prompts-heading" class="text-sm font-semibold text-text">{t("settings.prompts.title")}</h2>
      <p class="text-xs text-text-muted mt-0.5">{t("settings.prompts.subtitle")}</p>
    </div>
    <div class="flex items-center justify-between gap-4">
      <p class="text-xs text-text-subtle">{t("settings.prompts.hint")}</p>
      <button
        type="button"
        aria-disabled="true"
        data-testid="edit-prompt-btn"
        onclick={() => {
          comingSoonOpen = true;
        }}
        class="inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-medium
               border border-border text-text-subtle bg-surface-raised opacity-60
               cursor-not-allowed hover:opacity-70 transition-opacity duration-150
               focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/30"
      >
        {t("settings.prompts.edit")}
      </button>
    </div>
  </section>
</div>

<!-- Toasts -->
{#if toasts.length > 0}
  <div class="fixed bottom-4 right-4 z-50 space-y-2 w-72" aria-live="polite">
    {#each toasts as toast (toast.id)}
      <Toast
        message={toast.message}
        type={toast.type}
        onclose={() => dismissToast(toast.id)}
      />
    {/each}
  </div>
{/if}

<!-- Coming-soon modal -->
<Modal
  title={t("settings.prompts.modal.title")}
  open={comingSoonOpen}
  onclose={() => {
    comingSoonOpen = false;
  }}
>
  <p class="text-sm text-text-muted leading-relaxed">
    {t("settings.prompts.modal.body")}
  </p>
  <div class="pt-2 flex justify-end">
    <Button
      variant="secondary"
      size="sm"
      onclick={() => {
        comingSoonOpen = false;
      }}
    >
      {t("settings.prompts.modal.gotIt")}
    </Button>
  </div>
</Modal>
