import { fireEvent, render } from "@testing-library/svelte";
import axe from "axe-core";
import { createRawSnippet } from "svelte";
import { describe, expect, it, vi } from "vitest";
import Modal from "./Modal.svelte";

function textSnippet(text: string) {
  return createRawSnippet(() => ({ render: () => `<p>${text}</p>` }));
}

describe("Modal", () => {
  it("renders nothing when closed", () => {
    const { queryByRole } = render(Modal, {
      open: false,
      children: textSnippet("Content"),
    });
    expect(queryByRole("dialog")).toBeNull();
  });

  it("renders dialog when open", () => {
    const { getByRole } = render(Modal, {
      open: true,
      children: textSnippet("Content"),
    });
    expect(getByRole("dialog")).toBeTruthy();
  });

  it("renders title when provided", () => {
    const { getByText } = render(Modal, {
      open: true,
      title: "Confirm reset",
      children: textSnippet("Are you sure?"),
    });
    expect(getByText("Confirm reset")).toBeTruthy();
  });

  it("has aria-modal=true on dialog", () => {
    const { getByRole } = render(Modal, {
      open: true,
      children: textSnippet("Hello"),
    });
    expect(getByRole("dialog")).toHaveAttribute("aria-modal", "true");
  });

  it("calls onclose when close button is clicked", async () => {
    const handler = vi.fn();
    const { getByLabelText } = render(Modal, {
      open: true,
      onclose: handler,
      children: textSnippet("Content"),
    });
    await fireEvent.click(getByLabelText("Close dialog"));
    expect(handler).toHaveBeenCalledOnce();
  });

  it("has no axe violations when open", async () => {
    const { container } = render(Modal, {
      open: true,
      title: "Confirm",
      children: textSnippet("This action cannot be undone."),
    });
    const results = await axe.run(container, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(results.violations).toHaveLength(0);
  });
});
