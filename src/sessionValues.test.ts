import { describe, expect, it } from "vitest";
import { configuredFilteredOptions, valuesForSession } from "./sessionValues";
import type { ConfigSession, RuntimeOption, RuntimeSchema } from "./types";

const option = (key: string, platform: string | null): RuntimeOption => ({
  key,
  description: key,
  defaultValues: ["default"],
  currentValues: [],
  category: platform ?? "通用",
  kind: "text",
  choices: [],
  repeatable: false,
  platform,
  since: null,
  risk: "normal",
  editable: platform === null,
});

const schema: RuntimeSchema = {
  ghosttyVersion: "1.3.1",
  schemaHash: "test",
  options: [option("font-size", null)],
  filteredOptions: [option("macos-titlebar-style", "macOS")],
  diagnostics: [],
};

function session(values: ConfigSession["values"]): ConfigSession {
  return {
    id: "session",
    candidateId: "candidate",
    path: "~/.config/ghostty/config",
    revision: "revision",
    readOnly: false,
    values,
    diagnostics: [],
  };
}

describe("configured platform-filtered options", () => {
  it("surfaces configured filtered values without making absent keys visible", () => {
    const configured = session({
      "font-size": ["13"],
      "macos-titlebar-style": ["native"],
    });
    expect(configuredFilteredOptions(schema, configured).map((item) => item.key))
      .toEqual(["macos-titlebar-style"]);
    expect(valuesForSession(schema, configured)["macos-titlebar-style"]).toBe("native");
    expect(configuredFilteredOptions(schema, session({ "font-size": ["13"] }))).toEqual([]);
  });
});
