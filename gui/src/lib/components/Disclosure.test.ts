import { fireEvent, render } from "@testing-library/svelte";
import axe from "axe-core";
import { createRawSnippet } from "svelte";
import { describe, expect, it } from "vitest";
import Disclosure from "./Disclosure.svelte";

function textSnippet(text: string) {
  return createRawSnippet(() => ({ render: () => `<p>${text}</p>` }));
}

describe("Disclosure", () => {
  it("renders the title in summary", () => {
    const { getByText } = render(Disclosure, {
      title: "Advanced options",
      children: textSnippet("Hidden content"),
    });
    expect(getByText("Advanced options")).toBeTruthy();
  });

  it("is closed by default", () => {
    const { container } = render(Disclosure, {
      title: "Details",
      children: textSnippet("Body"),
    });
    const details = container.querySelector("details");
    expect(details?.open).toBe(false);
  });

  it("opens when open prop is true", () => {
    const { container } = render(Disclosure, {
      title: "Details",
      open: true,
      children: textSnippet("Body"),
    });
    const details = container.querySelector("details");
    expect(details?.open).toBe(true);
  });

  it("toggles open state when summary is clicked", async () => {
    const { container } = render(Disclosure, {
      title: "Toggle me",
      children: textSnippet("Content"),
    });
    const summary = container.querySelector("summary");
    if (!summary) throw new Error("summary element not found");
    await fireEvent.click(summary);
    expect(container.querySelector("details")?.open).toBe(true);
  });

  it("has no axe violations", async () => {
    const { container } = render(Disclosure, {
      title: "Fix this",
      children: textSnippet("Run: brew install docker"),
    });
    const results = await axe.run(container, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(results.violations).toHaveLength(0);
  });
});
