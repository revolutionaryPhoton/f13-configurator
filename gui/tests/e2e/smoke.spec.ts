/**
 * F13 Configurator — end-to-end wizard smoke test.
 *
 * Guard: only runs when F13_E2E=1.  Requires:
 *   - macOS (Tauri 2.x WebDriver only runs against a native window)
 *   - Docker running (F13 stack will be launched inside it)
 *   - tauri-driver on PATH  (`cargo install tauri-driver`)
 *   - Debug app built: `cargo tauri build --debug` (from gui/)
 *   - E2E deps installed: `npm install` (from gui/tests/e2e/)
 *
 * NOT run during CI (no Docker) or loop iterations (headless Linux).
 *
 * Run from gui/tests/e2e/:
 *   F13_E2E=1 npm test
 */

import { browser, $, $$ } from "@wdio/globals";

// ---------------------------------------------------------------------------
// Guard — skip the entire suite if F13_E2E is not set.
// This prevents accidental execution in CI or the loop container.
// ---------------------------------------------------------------------------
const E2E_ENABLED = process.env["F13_E2E"] === "1";
const suiteFn: (name: string, fn: () => void) => void = E2E_ENABLED
  ? describe
  : (name, _fn) => describe.skip(name, () => it("skipped — set F13_E2E=1", () => {}));

// Core API port (mirror the ports-screen default; override via env if changed).
const CORE_PORT = process.env["F13_CORE_PORT"] ?? "8000";

// ---------------------------------------------------------------------------
// Helper: wait for navigation to a given route substring.
// ---------------------------------------------------------------------------
async function waitForRoute(
  fragment: string,
  timeoutMs = 10_000
): Promise<void> {
  await browser.waitUntil(
    async () => (await browser.getUrl()).includes(fragment),
    { timeout: timeoutMs, timeoutMsg: `Timed out waiting for route: ${fragment}` }
  );
}

// ---------------------------------------------------------------------------
// Helper: wait for a button to become enabled, then click it.
// ---------------------------------------------------------------------------
async function waitAndClick(selector: string, timeoutMs = 30_000): Promise<void> {
  const el = await $(selector);
  await el.waitUntil(
    async () => !(await el.getAttribute("disabled")),
    { timeout: timeoutMs, timeoutMsg: `Button '${selector}' stayed disabled for ${timeoutMs}ms` }
  );
  await el.click();
}

// ===========================================================================
suiteFn("F13 Configurator — wizard smoke test", () => {
  // -------------------------------------------------------------------------
  // Step 1: Welcome screen
  //   Assert heading is visible and click "Begin setup".
  // -------------------------------------------------------------------------
  it("welcome screen: shows heading and navigates to preflight", async () => {
    const h1 = await $("h1");
    await h1.waitForDisplayed({ timeout: 10_000 });
    expect(await h1.getText()).toContain("F13 Configurator");

    await (await $("button=Begin setup")).click();
    await waitForRoute("/wizard/preflight");
  });

  // -------------------------------------------------------------------------
  // Step 2: Preflight screen
  //   Stream completes with all checks passing; click Continue.
  // -------------------------------------------------------------------------
  it("preflight: all checks pass, continues to inference picker", async () => {
    const h1 = await $("h1");
    await h1.waitForDisplayed({ timeout: 5_000 });
    expect(await h1.getText()).toContain("Preflight");

    // The Continue button is enabled once streaming is done and no hard fail exists.
    await waitAndClick("button=Continue", 30_000);

    // Assert no fail row remained after the stream settled.
    const failRows = await $$("[data-status='fail']");
    // Note: we check AFTER clicking Continue (button was enabled ⇒ no hard fails).
    expect(failRows.length).toBe(0);

    await waitForRoute("/wizard/inference");
  });

  // -------------------------------------------------------------------------
  // Step 3: Inference picker
  //   Select the Mock tile (first [role=radio] in the radiogroup), continue.
  // -------------------------------------------------------------------------
  it("inference picker: selects Mock backend and navigates to ports", async () => {
    const h1 = await $("h1");
    await h1.waitForDisplayed({ timeout: 5_000 });
    expect(await h1.getText()).toContain("inference backend");

    // Mock tile is the first radio inside the radiogroup.
    const mockTile = await $("[role='radiogroup'] [role='radio']:first-child");
    await mockTile.waitForDisplayed({ timeout: 5_000 });
    await mockTile.click();

    // aria-checked must switch to "true" after click.
    expect(await mockTile.getAttribute("aria-checked")).toBe("true");

    await waitAndClick("button=Continue");
    await waitForRoute("/wizard/ports");
  });

  // -------------------------------------------------------------------------
  // Step 4: Ports screen
  //   Wait for both default ports to report "free", then continue.
  // -------------------------------------------------------------------------
  it("ports screen: defaults are free, continues to run pipeline", async () => {
    // Auto-check fires on mount; wait for both status indicators.
    const frontendFree = await $("[data-testid='frontend-status-free']");
    await frontendFree.waitForDisplayed({
      timeout: 20_000,
      timeoutMsg: "Frontend port (9999) did not become free in 20s",
    });

    const coreFree = await $("[data-testid='core-status-free']");
    await coreFree.waitForDisplayed({
      timeout: 20_000,
      timeoutMsg: "Core API port (8000) did not become free in 20s",
    });

    await waitAndClick("button=Continue");
    await waitForRoute("/wizard/run");
  });

  // -------------------------------------------------------------------------
  // Step 5: Build / launch pipeline
  //   Wait for each of the 6 pipeline steps to reach data-status="done".
  //   Asserts no step reached "failed".
  // -------------------------------------------------------------------------
  it("pipeline: all 6 steps complete successfully", async () => {
    const STEP_KEYS = ["secrets", "render", "build", "pull", "start", "health"] as const;

    for (const key of STEP_KEYS) {
      const stepEl = await $(`[data-testid='step-${key}']`);
      await stepEl.waitForDisplayed({ timeout: 10_000 });

      await stepEl.waitUntil(
        async () => {
          const status = await stepEl.getAttribute("data-status");
          return status === "done" || status === "failed";
        },
        {
          timeout: 300_000,
          timeoutMsg: `Pipeline step '${key}' did not complete within 5 minutes`,
        }
      );

      const finalStatus = await stepEl.getAttribute("data-status");
      expect(finalStatus).toBe("done");
    }

    // After all steps finish the page auto-navigates to /status.
    await waitForRoute("/status", 30_000);
  });

  // -------------------------------------------------------------------------
  // Step 6: Status screen
  //   Assert the health badge reaches "Healthy" and the core /health HTTP
  //   endpoint returns 200 from the test runner's network.
  // -------------------------------------------------------------------------
  it("status screen: health badge is Healthy and core /health returns 200", async () => {
    const badge = await $("[data-testid='health-badge']");
    await badge.waitForDisplayed({ timeout: 10_000 });

    await badge.waitUntil(
      async () => (await badge.getText()).toLowerCase().includes("healthy"),
      {
        timeout: 60_000,
        timeoutMsg: "Health badge did not reach 'Healthy' within 60s",
      }
    );

    // Verify from the test runner side (outside the WebView).
    const resp = await fetch(`http://localhost:${CORE_PORT}/health`);
    expect(resp.status).toBe(200);
  });

  // -------------------------------------------------------------------------
  // Teardown: stop the F13 stack.
  //   Clicks the "Stop F13" button if visible; navigates back to welcome.
  //   Falls back silently — tauri-driver kills the process on exit anyway.
  // -------------------------------------------------------------------------
  after(async () => {
    try {
      const stopBtn = await $("button*=Stop F13");
      if (await stopBtn.isDisplayed()) {
        await stopBtn.click();
        // Wait for the stop-confirmation modal that asks the user to type "RESET".
        // The Stop action doesn't open a modal — only Full Reset does.
        await browser.waitUntil(
          async () => (await browser.getUrl()).endsWith("/"),
          { timeout: 30_000, timeoutMsg: "Did not navigate home after stopping" }
        );
      }
    } catch {
      // Best-effort cleanup; not a test failure.
    }
  });
});
