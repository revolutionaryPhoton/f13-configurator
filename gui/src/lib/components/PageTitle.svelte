<script lang="ts">
  interface Props {
    kicker?: string;
    title: string;
    subtitle?: string;
  }
  let { kicker, title, subtitle }: Props = $props();
</script>

<div class="mb-5">
  {#if kicker}
    <div
      class="text-[11px] text-subtle mb-1.5 font-semibold uppercase"
      style:letter-spacing="1.5px"
    >
      {kicker}
    </div>
  {/if}
  <h1
    class="m-0 text-[20px] font-semibold text-text"
    style:letter-spacing="-0.2px"
  >
    {title}
  </h1>
  {#if subtitle}
    <p class="mt-1.5 mb-0 text-muted text-[13.5px] leading-relaxed">
      {subtitle}
    </p>
  {/if}
</div>
