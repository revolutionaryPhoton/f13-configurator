<script lang="ts">
  import { tick } from "svelte";

  interface Props {
    lines: string[];
    /** Maximum visible lines before scrolling (default 12) */
    maxLines?: number;
    label?: string;
  }

  let { lines, maxLines = 12, label = "Log output" }: Props = $props();

  let viewport: HTMLElement | null = $state(null);

  const lineHeight = 20; // px, matches text-xs leading
  const maxHeight = $derived(`${maxLines * lineHeight}px`);

  $effect(() => {
    // Scroll to bottom whenever lines change
    void lines.length;
    tick().then(() => {
      if (viewport) viewport.scrollTop = viewport.scrollHeight;
    });
  });
</script>

<div
  role="log"
  aria-label={label}
  aria-live="polite"
  aria-relevant="additions"
  bind:this={viewport}
  class="overflow-y-auto rounded-lg bg-surface-raised border border-border
         font-mono text-xs text-text-muted leading-5 p-2 space-y-0.5"
  style="max-height: {maxHeight}"
>
  {#if lines.length === 0}
    <span class="text-text-subtle italic">No output yet…</span>
  {:else}
    {#each lines as line (line)}
      <div class="whitespace-pre-wrap break-all">{line}</div>
    {/each}
  {/if}
</div>
