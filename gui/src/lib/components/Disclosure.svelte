<script lang="ts">
  import type { Snippet } from "svelte";
  import { untrack } from "svelte";

  interface Props {
    title: string;
    open?: boolean;
    children: Snippet;
  }

  let { title, open = false, children }: Props = $props();

  // untrack reads the initial prop value without creating a reactive dependency,
  // so local state is independent after mount (user can toggle freely)
  let isOpen = $state(untrack(() => open));
</script>

<details
  bind:open={isOpen}
  class="rounded-lg border border-border bg-surface overflow-hidden"
>
  <summary
    class="flex cursor-pointer items-center justify-between
           px-3 py-2.5 text-sm font-medium text-text
           hover:bg-surface-raised transition-colors duration-150
           list-none select-none"
  >
    <span>{title}</span>
    <svg
      class="h-4 w-4 text-text-muted transition-transform duration-150
             {isOpen ? 'rotate-180' : ''}"
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 20 20"
      fill="currentColor"
      aria-hidden="true"
    >
      <path
        fill-rule="evenodd"
        clip-rule="evenodd"
        d="M5.22 8.22a.75.75 0 0 1 1.06 0L10 11.94l3.72-3.72a.75.75 0
           1 1 1.06 1.06l-4.25 4.25a.75.75 0 0 1-1.06 0L5.22
           9.28a.75.75 0 0 1 0-1.06z"
      />
    </svg>
  </summary>

  <div class="px-3 pb-3 pt-2 text-sm text-text-muted">
    {@render children()}
  </div>
</details>
