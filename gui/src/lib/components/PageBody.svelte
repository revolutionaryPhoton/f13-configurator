<script lang="ts">
  import type { Snippet } from "svelte";

  interface Props {
    narrow?: boolean;
    children: Snippet;
  }
  let { narrow = false, children }: Props = $props();
</script>

<div class="flex-1 overflow-y-auto px-[22px] py-[22px] flex justify-center">
  <div
    class="w-full"
    style:max-width={narrow ? "420px" : "520px"}
    style:animation="f13-fadeUp 400ms cubic-bezier(0.4,0,1,1) both"
  >
    {@render children()}
  </div>
</div>
