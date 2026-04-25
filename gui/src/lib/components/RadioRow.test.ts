import { fireEvent, render } from "@testing-library/svelte";
import axe from "axe-core";
import { describe, expect, it, vi } from "vitest";
import RadioRow from "./RadioRow.svelte";

const BASE_PROPS = { name: "backend", value: "mock", label: "Mock backend" };

describe("RadioRow", () => {
  it("renders label", () => {
    const { getByLabelText } = render(RadioRow, BASE_PROPS);
    expect(getByLabelText("Mock backend")).toBeTruthy();
  });

  it("renders description when provided", () => {
    const { getByText } = render(RadioRow, {
      ...BASE_PROPS,
      description: "No GPU needed",
    });
    expect(getByText("No GPU needed")).toBeTruthy();
  });

  it("is unchecked by default", () => {
    const { getByRole } = render(RadioRow, BASE_PROPS);
    expect(getByRole("radio")).not.toBeChecked();
  });

  it("reflects checked prop", () => {
    const { getByRole } = render(RadioRow, { ...BASE_PROPS, checked: true });
    expect(getByRole("radio")).toBeChecked();
  });

  it("calls onchange with value on change", async () => {
    const handler = vi.fn();
    const { getByRole } = render(RadioRow, {
      ...BASE_PROPS,
      onchange: handler,
    });
    await fireEvent.change(getByRole("radio"));
    expect(handler).toHaveBeenCalledWith("mock");
  });

  it("has no axe violations", async () => {
    const { container } = render(RadioRow, {
      ...BASE_PROPS,
      description: "Deterministic responses",
    });
    const results = await axe.run(container, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(results.violations).toHaveLength(0);
  });
});
