<script lang="ts">
  import { untrack } from "svelte";
  import { goto } from "$app/navigation";
  import Button from "$lib/components/Button.svelte";
  import Disclosure from "$lib/components/Disclosure.svelte";
  import Footer from "$lib/components/Footer.svelte";
  import Modal from "$lib/components/Modal.svelte";
  import PageBody from "$lib/components/PageBody.svelte";
  import PageTitle from "$lib/components/PageTitle.svelte";
  import StepHeader from "$lib/components/StepHeader.svelte";
  import type { Engine } from "$lib/engine.js";
  import { getEngine } from "$lib/engineContext.js";
  import { getWizardVia, type WizardVia } from "$lib/wizardPath.js";
  import { setWizardState } from "$lib/wizardState.js";

  interface Props {
    via?: WizardVia | null;
    engine?: Engine | null;
  }

  let { via: viaProp = null, engine: injectedEngine = null }: Props = $props();

  const via = $derived(viaProp ?? getWizardVia());
  const stepNum = $derived(via === "ollama" ? 4 : 3);
  const backRoute = $derived(
    via === "ollama" ? "/wizard/inference/ollama" : "/wizard/inference",
  );

  type PortStatus = "idle" | "checking" | "free" | { pid: number; name: string };

  let frontendPort = $state(9999);
  let corePort = $state(8000);
  let frontendStatus = $state<PortStatus>("idle");
  let coreStatus = $state<PortStatus>("idle");

  interface CollisionModal {
    open: boolean;
    field: "frontend" | "core";
    port: number;
    pid: number;
    name: string;
    suggested: number;
  }

  let collisionModal = $state<CollisionModal>({
    open: false,
    field: "frontend",
    port: 9999,
    pid: 0,
    name: "",
    suggested: 10000,
  });

  const canContinue = $derived(
    frontendStatus === "free" && coreStatus === "free",
  );

  function openCollisionModal(
    field: "frontend" | "core",
    port: number,
    pid: number,
    name: string,
  ) {
    if (collisionModal.open) return;
    collisionModal = { open: true, field, port, pid, name, suggested: port + 1 };
  }

  $effect(() => {
    const eng = injectedEngine ?? getEngine();
    if (!eng) return;
    let cancelled = false;
    const fp = untrack(() => frontendPort);
    const cp = untrack(() => corePort);
    frontendStatus = "checking";
    coreStatus = "checking";
    eng.checkPort(fp).then((r) => {
      if (cancelled) return;
      if (r === "free") frontendStatus = "free";
      else {
        frontendStatus = { pid: r.inUseBy, name: r.name };
        openCollisionModal("frontend", fp, r.inUseBy, r.name);
      }
    });
    eng.checkPort(cp).then((r) => {
      if (cancelled) return;
      if (r === "free") coreStatus = "free";
      else {
        coreStatus = { pid: r.inUseBy, name: r.name };
        openCollisionModal("core", cp, r.inUseBy, r.name);
      }
    });
    return () => {
      cancelled = true;
    };
  });

  async function checkFrontend() {
    const eng = injectedEngine ?? getEngine();
    if (!eng) return;
    frontendStatus = "checking";
    const result = await eng.checkPort(frontendPort);
    if (result === "free") frontendStatus = "free";
    else {
      frontendStatus = { pid: result.inUseBy, name: result.name };
      openCollisionModal("frontend", frontendPort, result.inUseBy, result.name);
    }
  }

  async function checkCore() {
    const eng = injectedEngine ?? getEngine();
    if (!eng) return;
    coreStatus = "checking";
    const result = await eng.checkPort(corePort);
    if (result === "free") coreStatus = "free";
    else {
      coreStatus = { pid: result.inUseBy, name: result.name };
      openCollisionModal("core", corePort, result.inUseBy, result.name);
    }
  }

  async function handlePickAnotherPort() {
    const eng = injectedEngine ?? getEngine();
    const { field, suggested } = collisionModal;
    collisionModal = { ...collisionModal, open: false };
    if (!eng) return;
    if (field === "frontend") {
      frontendPort = suggested;
      frontendStatus = "checking";
      const result = await eng.checkPort(suggested);
      frontendStatus = result === "free" ? "free" : { pid: result.inUseBy, name: result.name };
    } else {
      corePort = suggested;
      coreStatus = "checking";
      const result = await eng.checkPort(suggested);
      coreStatus = result === "free" ? "free" : { pid: result.inUseBy, name: result.name };
    }
  }

  function handleContinue() {
    setWizardState({ frontendPort, corePort });
    goto("/wizard/run");
  }
</script>

<div class="flex flex-col h-screen bg-bg">
  <StepHeader step={stepNum} total={4} onBack={() => goto(backRoute)} />

  <PageBody narrow>
    <PageTitle
      kicker="Ports"
      title="Configure ports"
      subtitle="Which TCP ports F13 services will listen on. We probed your machine."
    />

    <!-- Frontend port field -->
    <div class="mb-2.5 p-3.5 rounded-xl bg-surface border border-border">
      <label
        for="frontend-port"
        class="block text-[12px] font-semibold text-text mb-1.5"
      >
        Frontend port
      </label>
      <div class="flex items-center gap-2">
        <input
          id="frontend-port"
          type="number"
          min="1024"
          max="65535"
          bind:value={frontendPort}
          onblur={checkFrontend}
          aria-describedby="frontend-port-hint"
          class="flex-1 rounded-lg px-2.5 py-2 outline-none focus:ring-2"
          style:font-family="var(--f13-font-mono)"
          style:font-size="13px"
          style:background="var(--f13-bg)"
          style:border="1px solid var(--f13-border-strong)"
          style:color="var(--f13-text)"
        />
        <span class="w-6 text-center" aria-live="polite">
          {#if frontendStatus === "checking"}
            <span
              class="inline-block w-3.5 h-3.5 rounded-full border-2 border-current border-t-transparent text-muted"
              style:animation="f13-spin 700ms linear infinite"
              aria-hidden="true"
            ></span>
          {:else if frontendStatus === "free"}
            <span
              class="inline-flex"
              style:color="#16a34a"
              data-testid="frontend-status-free"
              aria-label="Free"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </span>
          {:else if typeof frontendStatus === "object"}
            <span
              class="inline-flex"
              style:color="var(--f13-error)"
              data-testid="frontend-status-taken"
              aria-label="In use"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </span>
          {/if}
        </span>
      </div>
      <p
        id="frontend-port-hint"
        class="m-0 mt-1.5 text-[11px]"
        style:color={typeof frontendStatus === "object"
          ? "var(--f13-error)"
          : "var(--f13-text-muted)"}
      >
        {#if typeof frontendStatus === "object"}
          <span data-testid="frontend-port-taken">
            Port {frontendPort} in use by PID {frontendStatus.pid} ({frontendStatus.name}).
          </span>
        {:else}
          The F13 web interface — default 9999.
        {/if}
      </p>
    </div>

    <!-- Core API port field -->
    <div class="mb-2.5 p-3.5 rounded-xl bg-surface border border-border">
      <label
        for="core-port"
        class="block text-[12px] font-semibold text-text mb-1.5"
      >
        Core API port
      </label>
      <div class="flex items-center gap-2">
        <input
          id="core-port"
          type="number"
          min="1024"
          max="65535"
          bind:value={corePort}
          onblur={checkCore}
          aria-describedby="core-port-hint"
          class="flex-1 rounded-lg px-2.5 py-2 outline-none focus:ring-2"
          style:font-family="var(--f13-font-mono)"
          style:font-size="13px"
          style:background="var(--f13-bg)"
          style:border="1px solid var(--f13-border-strong)"
          style:color="var(--f13-text)"
        />
        <span class="w-6 text-center" aria-live="polite">
          {#if coreStatus === "checking"}
            <span
              class="inline-block w-3.5 h-3.5 rounded-full border-2 border-current border-t-transparent text-muted"
              style:animation="f13-spin 700ms linear infinite"
              aria-hidden="true"
            ></span>
          {:else if coreStatus === "free"}
            <span
              class="inline-flex"
              style:color="#16a34a"
              data-testid="core-status-free"
              aria-label="Free"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </span>
          {:else if typeof coreStatus === "object"}
            <span
              class="inline-flex"
              style:color="var(--f13-error)"
              data-testid="core-status-taken"
              aria-label="In use"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </span>
          {/if}
        </span>
      </div>
      <p
        id="core-port-hint"
        class="m-0 mt-1.5 text-[11px]"
        style:color={typeof coreStatus === "object"
          ? "var(--f13-error)"
          : "var(--f13-text-muted)"}
      >
        {#if typeof coreStatus === "object"}
          <span data-testid="core-port-taken">
            Port {corePort} in use by PID {coreStatus.pid} ({coreStatus.name}).
          </span>
        {:else}
          The backend API service — default 8000.
        {/if}
      </p>
    </div>

    <!-- Advanced disclosure -->
    <Disclosure title="Advanced">
      <div class="pt-1 flex flex-col gap-3">
        <div>
          <p class="m-0 mb-1.5 text-[11px] font-medium text-text">
            Secret file locations
          </p>
          <div
            class="rounded-md bg-surface-raised px-3 py-2 text-[11px]"
            style:font-family="var(--f13-font-mono)"
            style:line-height="1.7"
          >
            <div>~/.f13/generated/core_jwt.secret</div>
            <div>~/.f13/generated/chat_api.secret</div>
          </div>
          <p class="m-0 mt-1.5 text-[11px] text-muted">
            Generated on first run; never committed to git.
          </p>
        </div>
        <div>
          <button
            disabled
            aria-disabled="true"
            aria-label="Edit system prompt (coming soon)"
            data-testid="edit-system-prompt"
            class="rounded-md border border-border px-3 py-1.5 text-[11px] text-muted cursor-not-allowed opacity-50"
          >
            Edit system prompt
          </button>
          <p class="m-0 mt-1 text-[11px] text-subtle">
            Available in a future release.
          </p>
        </div>
      </div>
    </Disclosure>
  </PageBody>

  <Footer>
    {#snippet status()}
      {#if canContinue}
        Ports {frontendPort} and {corePort} are available.
      {:else}
        Both ports must be free to continue.
      {/if}
    {/snippet}
    {#snippet action()}
      <Button disabled={!canContinue} onclick={handleContinue}>
        Launch
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <line x1="5" y1="12" x2="19" y2="12" />
          <polyline points="12 5 19 12 12 19" />
        </svg>
      </Button>
    {/snippet}
  </Footer>
</div>

<!-- Port-collision modal -->
<Modal
  open={collisionModal.open}
  title="Port in use"
  onclose={() => { collisionModal = { ...collisionModal, open: false }; }}
>
  <div class="flex flex-col gap-3" data-testid="port-collision-modal">
    <p class="m-0 text-[13px] text-text leading-snug">
      Port
      <span class="font-semibold" style:font-family="var(--f13-font-mono)">{collisionModal.port}</span>
      {#if collisionModal.name}
        is in use by <strong>{collisionModal.name}</strong> (PID {collisionModal.pid}).
      {:else}
        is in use by PID {collisionModal.pid}.
      {/if}
    </p>
    <p class="m-0 text-[12px] text-muted">
      Try port
      <span
        class="font-semibold"
        style:font-family="var(--f13-font-mono)"
        data-testid="collision-suggested-port"
      >{collisionModal.suggested}</span>
      instead?
    </p>
    <div class="flex justify-end gap-2 pt-1">
      <Button
        variant="secondary"
        size="sm"
        onclick={() => { collisionModal = { ...collisionModal, open: false }; }}
      >
        Keep this port
      </Button>
      <Button variant="primary" size="sm" onclick={handlePickAnotherPort}>
        Pick another port
      </Button>
    </div>
  </div>
</Modal>
