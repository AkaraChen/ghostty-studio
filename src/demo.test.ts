import { describe, expect, it } from "vitest";
import {
  demoEnvironment,
  demoEnvironmentFor,
  demoPlatformFor,
  demoSchema,
} from "./demo";

describe("browser demo fixture", () => {
  it("has unique option keys and a value for every control", () => {
    const keys = demoSchema.options.map((option) => option.key);
    expect(new Set(keys).size).toBe(keys.length);
    for (const option of demoSchema.options) {
      expect(option.currentValues[0] ?? option.defaultValues[0]).toBeDefined();
    }
  });

  it("cannot accidentally become a writable local-file backend", () => {
    expect(demoEnvironment.candidates.length).toBeGreaterThan(0);
    expect(demoEnvironment.candidates.every((candidate) => candidate.path.startsWith("~"))).toBe(true);
  });

  it("uses Linux paths and executable names for Linux browser previews", () => {
    const linux = demoEnvironmentFor("linux");
    expect(linux.platform).toBe("Linux");
    expect(linux.ghostty.executablePath).toBe("/usr/bin/ghostty");
    expect(linux.candidates.every((candidate) => !candidate.path.includes("Library"))).toBe(true);
    expect(linux.candidates[0].path).toBe("~/.config/ghostty/config");
  });

  it("retains the macOS fixture when the browser identifies as Apple", () => {
    const macos = demoEnvironmentFor("macos");
    expect(macos.platform).toBe("macOS");
    expect(macos.ghostty.executablePath).toContain("/Applications/Ghostty.app/");
    expect(macos.candidates.some((candidate) => candidate.path.includes("Library/Application Support"))).toBe(true);
    expect(demoPlatformFor("MacIntel", "Mozilla/5.0")).toBe("macos");
    expect(demoPlatformFor("Linux x86_64", "Mozilla/5.0 (X11; Linux x86_64)")).toBe("linux");
  });
});
