import { render } from "@testing-library/svelte";
import axe from "axe-core";
import { describe, expect, it } from "vitest";
import ProgressBar from "./ProgressBar.svelte";

describe("ProgressBar", () => {
  it("renders progressbar role", () => {
    const { getByRole } = render(ProgressBar, { label: "Loading" });
    expect(getByRole("progressbar")).toBeTruthy();
  });

  it("shows label text", () => {
    const { getByText } = render(ProgressBar, { label: "Building image" });
    expect(getByText("Building image")).toBeTruthy();
  });

  it("sets aria-valuenow for determinate bar", () => {
    const { getByRole } = render(ProgressBar, { value: 42, label: "Progress" });
    expect(getByRole("progressbar")).toHaveAttribute("aria-valuenow", "42");
  });

  it("omits aria-valuenow for indeterminate bar", () => {
    const { getByRole } = render(ProgressBar, { label: "Loading" });
    expect(getByRole("progressbar")).not.toHaveAttribute("aria-valuenow");
  });

  it("clamps value to 0–100", () => {
    const { getByRole } = render(ProgressBar, { value: 150, label: "Done" });
    expect(getByRole("progressbar")).toHaveAttribute("aria-valuenow", "100");
  });

  it("has no axe violations (determinate)", async () => {
    const { container } = render(ProgressBar, { value: 60, label: "Uploading" });
    const results = await axe.run(container, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(results.violations).toHaveLength(0);
  });

  it("has no axe violations (indeterminate)", async () => {
    const { container } = render(ProgressBar, { label: "Working…" });
    const results = await axe.run(container, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(results.violations).toHaveLength(0);
  });
});
