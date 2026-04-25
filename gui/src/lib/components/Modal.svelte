<script lang="ts">
  import type { Snippet } from "svelte";

  interface Props {
    open?: boolean;
    title?: string;
    onclose?: () => void;
    children: Snippet;
  }

  let { open = false, title, onclose, children }: Props = $props();

  function handleBackdrop(e: MouseEvent) {
    if (e.target === e.currentTarget) onclose?.();
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === "Escape") onclose?.();
  }
</script>

{#if open}
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    role="presentation"
    class="fixed inset-0 z-50 flex items-center justify-center
           bg-black/40 backdrop-blur-sm p-4"
    onclick={handleBackdrop}
    onkeydown={handleKeydown}
  >
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby={title ? "modal-title" : undefined}
      class="relative w-full max-w-sm rounded-2xl bg-surface shadow-md
             border border-border p-4 space-y-3"
    >
      {#if title}
        <h2 id="modal-title" class="text-base font-semibold text-text pr-6">
          {title}
        </h2>
      {/if}

      <button
        type="button"
        aria-label="Close dialog"
        onclick={onclose}
        class="absolute top-3 right-3 rounded-full p-1 text-text-muted
               hover:bg-surface-raised hover:text-text transition-colors duration-150"
      >
        <svg
          class="h-4 w-4"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
          aria-hidden="true"
        >
          <path
            d="M6.28 5.22a.75.75 0 0 0-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0
               1 0 1.06 1.06L10 11.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L11.06
               10l3.72-3.72a.75.75 0 0 0-1.06-1.06L10 8.94 6.28 5.22z"
          />
        </svg>
      </button>

      <div class="text-sm text-text">
        {@render children()}
      </div>
    </div>
  </div>
{/if}
