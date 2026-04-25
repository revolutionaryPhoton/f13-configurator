import { render } from "@testing-library/svelte";
import axe from "axe-core";
import { describe, expect, it } from "vitest";
import LogViewer from "./LogViewer.svelte";

describe("LogViewer", () => {
  it("renders log role", () => {
    const { getByRole } = render(LogViewer, { lines: [] });
    expect(getByRole("log")).toBeTruthy();
  });

  it("shows empty state when no lines", () => {
    const { getByText } = render(LogViewer, { lines: [] });
    expect(getByText(/No output yet/)).toBeTruthy();
  });

  it("renders each log line", () => {
    const lines = ["Step 1 complete", "Step 2 complete"];
    const { getByText } = render(LogViewer, { lines });
    expect(getByText("Step 1 complete")).toBeTruthy();
    expect(getByText("Step 2 complete")).toBeTruthy();
  });

  it("uses provided label for aria-label", () => {
    const { getByRole } = render(LogViewer, {
      lines: [],
      label: "Docker build output",
    });
    expect(getByRole("log", { name: "Docker build output" })).toBeTruthy();
  });

  it("is aria-live polite", () => {
    const { getByRole } = render(LogViewer, { lines: [] });
    expect(getByRole("log")).toHaveAttribute("aria-live", "polite");
  });

  it("has no axe violations (empty)", async () => {
    const { container } = render(LogViewer, { lines: [] });
    const results = await axe.run(container, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(results.violations).toHaveLength(0);
  });

  it("has no axe violations (with lines)", async () => {
    const { container } = render(LogViewer, {
      lines: ["Pulling image...", "Done."],
    });
    const results = await axe.run(container, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(results.violations).toHaveLength(0);
  });
});
