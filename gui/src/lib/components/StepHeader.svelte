<script lang="ts">
  import type { Snippet } from "svelte";
  import { t } from "$lib/i18n/index.js";

  // Step indicator + optional Back button. Matches the design canvas spec.
  interface Props {
    step: number;
    total: number;
    onBack?: () => void;
    backLabel?: string;
  }
  let { step, total, onBack, backLabel }: Props = $props();
  const resolvedBackLabel = $derived(backLabel ?? t("common.back"));

  const dots = $derived(Array.from({ length: total }, (_, i) => i + 1));
</script>

<div
  class="flex items-center justify-between px-[22px] py-[14px] border-b border-border"
>
  {#if onBack}
    <button
      type="button"
      class="-ml-2 inline-flex items-center gap-1 px-2 py-1 text-xs text-muted hover:text-text hover:bg-surface-raised rounded-md transition-colors"
      onclick={onBack}
    >
      <svg
        width="14"
        height="14"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <line x1="19" y1="12" x2="5" y2="12" />
        <polyline points="12 19 5 12 12 5" />
      </svg>
      {resolvedBackLabel}
    </button>
  {:else}
    <span></span>
  {/if}

  <div
    class="flex items-center gap-2 text-[11px] text-subtle font-sans"
    aria-label={t("stepHeader.stepOf", { step, total })}
  >
    {#each dots as i (i)}
      <span
        class="rounded-sm transition-all duration-300"
        style:width={i <= step ? "18px" : "6px"}
        style:height="3px"
        style:background={i <= step
          ? "var(--f13-text)"
          : "var(--f13-border-strong)"}
      ></span>
    {/each}
    <span class="ml-1.5">{t("stepHeader.stepOf", { step, total })}</span>
  </div>
</div>
