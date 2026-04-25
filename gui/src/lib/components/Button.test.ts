import { fireEvent, render } from "@testing-library/svelte";
import axe from "axe-core";
import { createRawSnippet } from "svelte";
import { describe, expect, it, vi } from "vitest";
import Button from "./Button.svelte";

function textSnippet(text: string) {
  return createRawSnippet(() => ({ render: () => `<span>${text}</span>` }));
}

describe("Button", () => {
  it("renders with label text", () => {
    const { getByRole } = render(Button, { children: textSnippet("Click me") });
    expect(getByRole("button", { name: "Click me" })).toBeTruthy();
  });

  it("applies primary variant by default", () => {
    const { getByRole } = render(Button, { children: textSnippet("Go") });
    const btn = getByRole("button");
    expect(btn.className).toContain("rounded-full");
  });

  it("applies secondary variant classes", () => {
    const { getByRole } = render(Button, {
      children: textSnippet("Go"),
      variant: "secondary",
    });
    expect(getByRole("button").className).toContain("rounded-lg");
  });

  it("is disabled when disabled prop is set", () => {
    const { getByRole } = render(Button, {
      children: textSnippet("Go"),
      disabled: true,
    });
    expect(getByRole("button")).toBeDisabled();
  });

  it("fires onclick when clicked", async () => {
    const handler = vi.fn();
    const { getByRole } = render(Button, {
      children: textSnippet("Go"),
      onclick: handler,
    });
    await fireEvent.click(getByRole("button"));
    expect(handler).toHaveBeenCalledOnce();
  });

  it("has no axe violations", async () => {
    const { container } = render(Button, { children: textSnippet("Submit") });
    const results = await axe.run(container, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(results.violations).toHaveLength(0);
  });
});
