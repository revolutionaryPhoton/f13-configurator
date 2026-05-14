<script lang="ts">
  import "../app.css";
  import "$lib/i18n/locales.js";
  import { onMount } from "svelte";
  import type { Snippet } from "svelte";
  import { applyTheme, getTheme } from "$lib/theme.js";
  import { bootstrapEngine } from "$lib/bootstrap.js";
  import { zoom, zoomKeyHandler } from "$lib/zoom.js";

  let { children }: { children: Snippet } = $props();

  onMount(() => {
    applyTheme(getTheme());
    void bootstrapEngine();

    const unsubZoom = zoom.subscribe((factor) => {
      document.documentElement.style.zoom = String(factor);
    });

    function handleKey(e: KeyboardEvent) {
      zoomKeyHandler(e, zoom.zoomIn, zoom.zoomOut, zoom.reset);
    }
    window.addEventListener("keydown", handleKey);

    return () => {
      unsubZoom();
      window.removeEventListener("keydown", handleKey);
    };
  });
</script>

{@render children()}
