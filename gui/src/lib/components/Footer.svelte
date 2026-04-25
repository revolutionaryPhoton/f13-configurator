<script lang="ts">
  import type { Snippet } from "svelte";

  interface Props {
    status?: Snippet;
    action?: Snippet;
  }
  let { status, action }: Props = $props();
</script>

<div
  class="flex items-center justify-between gap-3 px-[22px] py-[14px] border-t border-border bg-bg flex-shrink-0"
>
  <div class="text-xs text-muted">
    {#if status}{@render status()}{/if}
  </div>
  <div>
    {#if action}{@render action()}{/if}
  </div>
</div>
