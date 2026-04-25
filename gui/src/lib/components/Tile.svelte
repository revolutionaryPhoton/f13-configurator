<script lang="ts">
  interface Props {
    /** Emoji or short text icon shown prominently */
    icon: string;
    title: string;
    description?: string;
    pros?: string[];
    cons?: string[];
    selected?: boolean;
    recommended?: boolean;
    onclick?: () => void;
    class?: string;
  }

  let {
    icon,
    title,
    description,
    pros = [],
    cons = [],
    selected = false,
    recommended = false,
    onclick,
    class: extraClass = "",
  }: Props = $props();

  const base =
    "relative flex flex-col gap-2 rounded-xl p-4 border cursor-pointer " +
    "transition-colors duration-150 focus-visible:outline-none " +
    "focus-visible:ring-2 focus-visible:ring-offset-2 text-left w-full";

  const stateClass = $derived(
    selected
      ? "border-primary bg-surface shadow-sm ring-1 ring-primary"
      : "border-border bg-surface hover:bg-surface-raised hover:border-text-muted"
  );
</script>

<button
  role="radio"
  aria-checked={selected}
  class="{base} {stateClass} {extraClass}"
  {onclick}
>
  {#if recommended}
    <span
      class="absolute top-3 right-3 rounded-full bg-primary text-primary-fg
             text-xs font-medium px-2 py-0.5"
    >
      Recommended
    </span>
  {/if}

  <span class="text-3xl leading-none" aria-hidden="true">{icon}</span>

  <span class="font-semibold text-text text-base">{title}</span>

  {#if description}
    <span class="text-text-muted text-sm leading-snug">{description}</span>
  {/if}

  {#if pros.length > 0}
    <ul class="mt-1 space-y-1" aria-label="Pros">
      {#each pros as pro}
        <li class="flex items-start gap-1.5 text-sm text-success">
          <span aria-hidden="true">✓</span>
          <span>{pro}</span>
        </li>
      {/each}
    </ul>
  {/if}

  {#if cons.length > 0}
    <ul class="mt-1 space-y-1" aria-label="Cons">
      {#each cons as con}
        <li class="flex items-start gap-1.5 text-sm text-text-muted">
          <span aria-hidden="true">–</span>
          <span>{con}</span>
        </li>
      {/each}
    </ul>
  {/if}
</button>
