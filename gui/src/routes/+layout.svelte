<script lang="ts">
  import "../app.css";
  import { onMount } from "svelte";
  import type { Snippet } from "svelte";
  import { applyTheme, getTheme } from "$lib/theme.js";
  import { bootstrapEngine } from "$lib/bootstrap.js";

  let { children }: { children: Snippet } = $props();

  onMount(() => {
    applyTheme(getTheme());
    void bootstrapEngine();
  });
</script>

{@render children()}
