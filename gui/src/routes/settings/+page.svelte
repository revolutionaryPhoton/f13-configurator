<script lang="ts">
  import { goto } from "$app/navigation";
  import { onMount } from "svelte";
  import Button from "$lib/components/Button.svelte";
  import Modal from "$lib/components/Modal.svelte";
  import Toast from "$lib/components/Toast.svelte";
  import { getTheme, setTheme as persistTheme, type Theme } from "$lib/theme.js";

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
    generatedDir = "./generated",
    copyToClipboard: clipProp,
  }: Props = $props();

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
      pushToast("success", `${file.label} copied`);
    } catch {
      pushToast("error", "Failed to copy to clipboard");
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
      aria-label="Back to status"
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
    <h1 class="text-lg font-semibold text-text">Settings</h1>
  </header>

  <!-- Appearance -->
  <section
    aria-labelledby="appearance-heading"
    class="rounded-xl bg-surface shadow-sm p-4 space-y-3"
  >
    <h2 id="appearance-heading" class="text-sm font-semibold text-text">Appearance</h2>
    <div class="flex items-center justify-between gap-4">
      <span class="text-sm text-text-muted">Theme</span>
      <div
        role="radiogroup"
        aria-label="Theme"
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
  </section>

  <!-- Generated config -->
  <section
    aria-labelledby="config-heading"
    class="rounded-xl bg-surface shadow-sm p-4 space-y-3"
  >
    <div>
      <h2 id="config-heading" class="text-sm font-semibold text-text">Generated config</h2>
      <p class="text-xs text-text-muted mt-0.5">
        Read-only view of files in
        <code class="rounded bg-surface-raised px-1 py-0.5 font-mono">{generatedDir}</code>.
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
                {file.copying ? "Copying…" : "Copy"}
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
                  Loading…
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
      <h2 id="prompts-heading" class="text-sm font-semibold text-text">System prompts</h2>
      <p class="text-xs text-text-muted mt-0.5">Customise the AI's default instructions.</p>
    </div>
    <div class="flex items-center justify-between gap-4">
      <p class="text-xs text-text-subtle">Available in a future release.</p>
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
        Edit system prompt
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
  title="Custom system prompts"
  open={comingSoonOpen}
  onclose={() => {
    comingSoonOpen = false;
  }}
>
  <p class="text-sm text-text-muted leading-relaxed">
    Custom system prompts are on the F13 roadmap. In a future release you'll be able to
    edit the default AI instructions without editing YAML files.
  </p>
  <div class="pt-2 flex justify-end">
    <Button
      variant="secondary"
      size="sm"
      onclick={() => {
        comingSoonOpen = false;
      }}
    >
      Got it
    </Button>
  </div>
</Modal>
