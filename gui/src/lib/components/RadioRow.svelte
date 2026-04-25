<script lang="ts">
  interface Props {
    name: string;
    value: string;
    label: string;
    description?: string;
    checked?: boolean;
    onchange?: (value: string) => void;
  }

  let {
    name,
    value,
    label,
    description,
    checked = false,
    onchange,
  }: Props = $props();

  const id = $derived(`radio-${name}-${value}`);

  function handleChange() {
    onchange?.(value);
  }
</script>

<label
  class="flex items-start gap-3 rounded-lg px-3 py-2.5 cursor-pointer
         hover:bg-surface-raised transition-colors duration-150
         has-[:checked]:bg-surface-raised has-[:checked]:shadow-sm"
  for={id}
>
  <input
    {id}
    type="radio"
    {name}
    {value}
    {checked}
    onchange={handleChange}
    class="mt-0.5 shrink-0 h-4 w-4 accent-primary cursor-pointer"
  />

  <span class="flex flex-col gap-0.5">
    <span class="text-sm font-medium text-text">{label}</span>
    {#if description}
      <span class="text-xs text-text-muted leading-snug">{description}</span>
    {/if}
  </span>
</label>
