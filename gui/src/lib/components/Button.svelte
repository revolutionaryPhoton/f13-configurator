<script lang="ts">
  import type { Snippet } from "svelte";

  type Variant = "primary" | "secondary" | "ghost";
  type Size = "sm" | "md" | "lg";

  interface Props {
    variant?: Variant;
    size?: Size;
    disabled?: boolean;
    type?: "button" | "submit" | "reset";
    class?: string;
    onclick?: (e: MouseEvent) => void;
    children: Snippet;
  }

  let {
    variant = "primary",
    size = "md",
    disabled = false,
    type = "button",
    class: extraClass = "",
    onclick,
    children,
  }: Props = $props();

  const base =
    "inline-flex items-center justify-center font-medium transition-colors duration-150 " +
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 " +
    "disabled:pointer-events-none disabled:opacity-50 select-none";

  const variants: Record<Variant, string> = {
    primary:
      "bg-primary text-primary-fg hover:bg-primary-hover rounded-full shadow-sm",
    secondary:
      "border border-border bg-surface text-text hover:bg-surface-raised rounded-lg",
    ghost:
      "text-text hover:bg-text/5 rounded-lg",
  };

  const sizes: Record<Size, string> = {
    sm: "px-3 py-1.5 text-xs gap-1",
    md: "px-4 py-2 text-sm gap-1.5",
    lg: "px-5 py-2.5 text-base gap-2",
  };
</script>

<button
  {type}
  {disabled}
  class="{base} {variants[variant]} {sizes[size]} {extraClass}"
  {onclick}
>
  {@render children()}
</button>
