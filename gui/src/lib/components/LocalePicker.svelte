<script lang="ts">
  import { SUPPORTED_LOCALES, getLocale, setLocale, type Locale } from "$lib/i18n/index.js";

  const LOCALE_LABELS: Record<Locale, { code: string; name: string }> = {
    en: { code: "EN", name: "English" },
    de: { code: "DE", name: "German" },
    fr: { code: "FR", name: "French" },
    es: { code: "ES", name: "Spanish" },
  };

  let current = $state(getLocale());

  function select(locale: Locale) {
    if (locale === current) return;
    setLocale(locale);
    current = locale;
    window.location.reload();
  }
</script>

<div class="flex items-center gap-0.5" role="group" aria-label="Language">
  {#each SUPPORTED_LOCALES as locale (locale)}
    {@const active = locale === current}
    <button
      class="px-1.5 py-0.5 rounded text-[10px] transition-colors duration-150 cursor-default"
      class:bg-surface={active}
      class:text-text={active}
      class:text-muted={!active}
      class:hover:text-subtle={!active}
      style:font-family="var(--f13-font-mono)"
      aria-label="{LOCALE_LABELS[locale].name}{active ? ' (current)' : ''}"
      aria-pressed={active}
      onclick={() => select(locale)}
    >
      {LOCALE_LABELS[locale].code}
    </button>
  {/each}
</div>
