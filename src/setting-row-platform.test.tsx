// @vitest-environment jsdom
import { act } from "react";
import { createRoot } from "react-dom/client";
import { describe, expect, it, vi } from "vitest";
import { SettingRow } from "./components/SettingRow";
import type { RuntimeOption } from "./types";

(globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean })
  .IS_REACT_ACT_ENVIRONMENT = true;

const macosOption: RuntimeOption = {
  key: "macos-titlebar-style",
  description: "macOS titlebar style.",
  defaultValues: ["native"],
  currentValues: [],
  category: "macOS",
  kind: "text",
  choices: [],
  repeatable: false,
  platform: "macOS",
  since: null,
  risk: "advanced",
  editable: false,
};

describe("platform-filtered setting rows", () => {
  it("shows configured foreign-platform values as read-only", () => {
    const container = document.createElement("div");
    document.body.append(container);
    const root = createRoot(container);
    act(() => root.render(
      <SettingRow
        option={macosOption}
        value="native"
        baselineValue="native"
        configuredInEditingLayer
        effectiveValueKnown
        sourceLabel="XDG · config"
        platformRestricted
        currentPlatform="linux"
        onValueChange={vi.fn()}
        onReset={vi.fn()}
      />,
    ));

    expect(container.textContent).toContain("仅适用于 macOS；当前 Linux 平台只读");
    expect(container.querySelector<HTMLInputElement>("input")?.value).toBe("native");
    expect(container.querySelector<HTMLInputElement>("input")?.disabled).toBe(true);

    act(() => root.unmount());
    container.remove();
  });
});
