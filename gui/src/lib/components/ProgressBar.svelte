<script lang="ts">
  type Status = "pending" | "running" | "done" | "error";

  interface Props {
    /** 0–100. Omit for indeterminate. */
    value?: number;
    label?: string;
    status?: Status;
  }

  let { value, label, status = "running" }: Props = $props();

  const isIndeterminate = $derived(value === undefined);
  const pct = $derived(isIndeterminate ? 0 : Math.min(100, Math.max(0, value ?? 0)));

  const trackClass: Record<Status, string> = {
    pending: "bg-surface-raised",
    running: "bg-surface-raised",
    done:    "bg-success-bg",
    error:   "bg-error-bg",
  };

  const fillClass: Record<Status, string> = {
    pending: "bg-text-subtle",
    running: "bg-primary",
    done:    "bg-success",
    error:   "bg-error",
  };
</script>

<div class="flex flex-col gap-1">
  {#if label}
    <div class="flex items-center justify-between">
      <span class="text-xs font-medium text-text-muted">{label}</span>
      {#if !isIndeterminate}
        <span class="text-xs text-text-subtle" aria-hidden="true">{pct}%</span>
      {/if}
    </div>
  {/if}

  <div
    role="progressbar"
    aria-label={label ?? "Progress"}
    aria-valuenow={isIndeterminate ? undefined : pct}
    aria-valuemin={isIndeterminate ? undefined : 0}
    aria-valuemax={isIndeterminate ? undefined : 100}
    class="h-1.5 w-full overflow-hidden rounded-full {trackClass[status]}"
  >
    {#if isIndeterminate}
      <div
        class="h-full w-1/3 rounded-full {fillClass[status]}
               animate-[slide_1.5s_ease-in-out_infinite]"
        style="animation: progressIndeterminate 1.5s ease-in-out infinite"
      ></div>
    {:else}
      <div
        class="h-full rounded-full transition-all duration-300 {fillClass[status]}"
        style="width: {pct}%"
      ></div>
    {/if}
  </div>
</div>

<style>
  @keyframes progressIndeterminate {
    0%   { transform: translateX(-100%); }
    100% { transform: translateX(400%); }
  }
</style>
