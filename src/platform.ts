export function isMacPlatform(platform: string | null | undefined): boolean {
  return /mac|darwin/i.test(platform ?? "");
}

export function modifierLabelForPlatform(platform: string | null | undefined): "⌘" | "Ctrl" {
  return isMacPlatform(platform) ? "⌘" : "Ctrl";
}

export function platformRestrictionLabel(
  optionPlatform: string | null,
  currentPlatform: string | null | undefined,
): string {
  const target = optionPlatform ?? "其他平台";
  const current = isMacPlatform(currentPlatform) ? "macOS" : "Linux";
  return `仅适用于 ${target}；当前 ${current} 平台只读`;
}
