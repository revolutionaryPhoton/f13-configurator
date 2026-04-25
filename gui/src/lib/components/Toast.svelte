<script lang="ts">
  import { onMount } from "svelte";

  type ToastType = "success" | "error" | "warning" | "info";

  interface Props {
    message: string;
    type?: ToastType;
    /** Auto-dismiss after this many ms. 0 = persist. */
    duration?: number;
    onclose?: () => void;
  }

  let {
    message,
    type = "info",
    duration = 4000,
    onclose,
  }: Props = $props();

  const icons: Record<ToastType, string> = {
    success: "✅",
    error:   "❌",
    warning: "⚠️",
    info:    "ℹ️",
  };

  const colorClasses: Record<ToastType, string> = {
    success: "bg-success-bg text-success border-success/20",
    error:   "bg-error-bg text-error border-error/20",
    warning: "bg-warning-bg text-warning border-warning/20",
    info:    "bg-info-bg text-info border-info/20",
  };

  onMount(() => {
    if (duration > 0) {
      const t = setTimeout(() => onclose?.(), duration);
      return () => clearTimeout(t);
    }
    return () => {};
  });
</script>

<div
  role={type === "error" ? "alert" : "status"}
  aria-live={type === "error" ? "assertive" : "polite"}
  aria-atomic="true"
  class="flex items-start gap-2.5 rounded-xl border px-3 py-2.5 text-sm
         shadow-sm {colorClasses[type]}"
>
  <span class="shrink-0 text-base leading-snug" aria-hidden="true">
    {icons[type]}
  </span>

  <span class="flex-1 leading-snug">{message}</span>

  <button
    type="button"
    aria-label="Dismiss notification"
    onclick={onclose}
    class="shrink-0 rounded-full p-0.5 opacity-60 hover:opacity-100
           transition-opacity duration-150"
  >
    <svg
      class="h-3.5 w-3.5"
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
</div>
