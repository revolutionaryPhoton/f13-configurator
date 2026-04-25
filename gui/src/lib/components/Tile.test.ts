import { fireEvent, render } from "@testing-library/svelte";
import axe from "axe-core";
import { describe, expect, it, vi } from "vitest";
import Tile from "./Tile.svelte";

const BASE_PROPS = { icon: "🧪", title: "Mock backend" };

describe("Tile", () => {
  it("renders title and icon", () => {
    const { getByText } = render(Tile, BASE_PROPS);
    expect(getByText("Mock backend")).toBeTruthy();
    expect(getByText("🧪")).toBeTruthy();
  });

  it("is not selected by default", () => {
    const { getByRole } = render(Tile, BASE_PROPS);
    expect(getByRole("radio")).toHaveAttribute("aria-checked", "false");
  });

  it("reflects selected state via aria-checked", () => {
    const { getByRole } = render(Tile, { ...BASE_PROPS, selected: true });
    expect(getByRole("radio")).toHaveAttribute("aria-checked", "true");
  });

  it("shows recommended badge when prop is set", () => {
    const { getByText } = render(Tile, { ...BASE_PROPS, recommended: true });
    expect(getByText("Recommended")).toBeTruthy();
  });

  it("renders pros list", () => {
    const { getByText } = render(Tile, {
      ...BASE_PROPS,
      pros: ["No GPU needed", "Fast"],
    });
    expect(getByText("No GPU needed")).toBeTruthy();
  });

  it("fires onclick when clicked", async () => {
    const handler = vi.fn();
    const { getByRole } = render(Tile, { ...BASE_PROPS, onclick: handler });
    await fireEvent.click(getByRole("radio"));
    expect(handler).toHaveBeenCalledOnce();
  });

  it("has no axe violations", async () => {
    const { container } = render(Tile, {
      ...BASE_PROPS,
      description: "Good for demos",
      pros: ["No GPU"],
      cons: ["Fake responses"],
    });
    const results = await axe.run(container, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(results.violations).toHaveLength(0);
  });
});
