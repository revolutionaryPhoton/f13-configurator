<script lang="ts">
  // Pixel-style F13 mark — matches the design canvas spec.
  // 64×22 base; scale via the `size` prop.
  interface Props {
    size?: number;
    color?: string;
    title?: string;
  }
  let { size = 1, color = "currentColor", title = "F13" }: Props = $props();

  const w = $derived(64 * size);
  const h = $derived(22 * size);
</script>

<svg
  viewBox="0 0 64 22"
  width={w}
  height={h}
  fill={color}
  role="img"
  aria-label={title}
>
  <title>{title}</title>
  <!-- F -->
  <rect x="0" y="0" width="3" height="22" />
  <rect x="0" y="0" width="11" height="3" />
  <rect x="0" y="9" width="8" height="3" />
  <!-- 1 -->
  <rect x="20" y="0" width="3" height="22" />
  <rect x="17" y="0" width="3" height="3" />
  <!-- 3 -->
  <rect x="32" y="0" width="11" height="3" />
  <rect x="40" y="0" width="3" height="11" />
  <rect x="32" y="9" width="11" height="3" />
  <rect x="40" y="11" width="3" height="11" />
  <rect x="32" y="19" width="11" height="3" />
</svg>
