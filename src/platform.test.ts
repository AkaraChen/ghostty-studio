import { describe, expect, it } from "vitest";
import { modifierLabelForPlatform, platformRestrictionLabel } from "./platform";

describe("platform copy", () => {
  it("uses native modifier labels on macOS and Linux", () => {
    expect(modifierLabelForPlatform("macos")).toBe("⌘");
    expect(modifierLabelForPlatform("Darwin")).toBe("⌘");
    expect(modifierLabelForPlatform("linux")).toBe("Ctrl");
  });

  it("explains why a configured cross-platform option is read-only", () => {
    expect(platformRestrictionLabel("macOS", "linux"))
      .toBe("仅适用于 macOS；当前 Linux 平台只读");
    expect(platformRestrictionLabel("Linux", "macos"))
      .toBe("仅适用于 Linux；当前 macOS 平台只读");
  });
});
