<script lang="ts">
  interface Props {
    /** Emoji or short text icon shown next to the title */
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
</script>

<button
  role="radio"
  type="button"
  aria-checked={selected}
  {onclick}
  class="relative w-full text-left p-4 rounded-xl flex flex-col gap-2.5 transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 {extraClass}"
  style:background={selected ? "var(--f13-text)" : "var(--f13-surface)"}
  style:color={selected ? "var(--f13-primary-fg)" : "var(--f13-text)"}
  style:border={selected
    ? "1.5px solid var(--f13-text)"
    : "1.5px solid var(--f13-border)"}
>
  {#if recommended}
    <span
      class="absolute -top-2 right-3 px-2 py-[2px] rounded-full uppercase font-bold"
      style:font-size="9px"
      style:letter-spacing="0.8px"
      style:background={selected ? "#fff" : "var(--f13-text)"}
      style:color={selected ? "#000" : "#fff"}
    >
      Recommended
    </span>
  {/if}

  <div class="flex items-center gap-2.5">
    <span class="leading-none" style:font-size="22px" aria-hidden="true">{icon}</span>
    <div class="text-[15px] font-semibold">{title}</div>
  </div>

  {#if description}
    <div class="text-[12px] leading-relaxed" style:opacity="0.85">
      {description}
    </div>
  {/if}

  {#if pros.length > 0 || cons.length > 0}
    <div class="flex flex-col gap-[3px] mt-1">
      {#each pros as pro (pro)}
        <div class="flex gap-1.5 text-[11px]" style:opacity="0.9">
          <span style:color={selected ? "#86efac" : "#16a34a"}>+</span>
          <span>{pro}</span>
        </div>
      {/each}
      {#each cons as con (con)}
        <div class="flex gap-1.5 text-[11px]" style:opacity="0.65">
          <span aria-hidden="true">−</span>
          <span>{con}</span>
        </div>
      {/each}
    </div>
  {/if}
</button>
