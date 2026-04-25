import { fireEvent, render } from "@testing-library/svelte";
import axe from "axe-core";
import { describe, expect, it, vi } from "vitest";
import Toast from "./Toast.svelte";

describe("Toast", () => {
  it("renders the message", () => {
    const { getByText } = render(Toast, { message: "Build complete" });
    expect(getByText("Build complete")).toBeTruthy();
  });

  it("uses role=status for non-error types", () => {
    const { getByRole } = render(Toast, {
      message: "Done",
      type: "success",
    });
    expect(getByRole("status")).toBeTruthy();
  });

  it("uses role=alert for error type", () => {
    const { getByRole } = render(Toast, {
      message: "Build failed",
      type: "error",
    });
    expect(getByRole("alert")).toBeTruthy();
  });

  it("calls onclose when dismiss button is clicked", async () => {
    const handler = vi.fn();
    const { getByLabelText } = render(Toast, {
      message: "Done",
      onclose: handler,
    });
    await fireEvent.click(getByLabelText("Dismiss notification"));
    expect(handler).toHaveBeenCalledOnce();
  });

  it("has aria-live=assertive for error", () => {
    const { getByRole } = render(Toast, {
      message: "Error!",
      type: "error",
    });
    expect(getByRole("alert")).toHaveAttribute("aria-live", "assertive");
  });

  it("has no axe violations (success)", async () => {
    const { container } = render(Toast, {
      message: "Stack is healthy",
      type: "success",
    });
    const results = await axe.run(container, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(results.violations).toHaveLength(0);
  });

  it("has no axe violations (error)", async () => {
    const { container } = render(Toast, {
      message: "Docker not found",
      type: "error",
    });
    const results = await axe.run(container, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(results.violations).toHaveLength(0);
  });
});
