import type { ConfigSession, RuntimeOption, RuntimeSchema } from "./types";

export function initialValues(options: RuntimeOption[]): Record<string, string> {
  return Object.fromEntries(
    options.map((option) => [option.key, option.defaultValues[0] ?? ""]),
  );
}

export function configuredFilteredOptions(
  schema: RuntimeSchema,
  session: ConfigSession | null,
): RuntimeOption[] {
  if (!session) return [];
  return schema.filteredOptions.filter(
    (option) => (session.values[option.key]?.length ?? 0) > 0,
  );
}

export function optionsForSession(
  schema: RuntimeSchema,
  session: ConfigSession | null,
): RuntimeOption[] {
  return [...schema.options, ...configuredFilteredOptions(schema, session)];
}

export function valuesForSession(
  schema: RuntimeSchema,
  session: ConfigSession,
): Record<string, string> {
  const values = initialValues(optionsForSession(schema, session));
  for (const [key, configuredValues] of Object.entries(session.values)) {
    if (configuredValues.length > 0 && key in values) {
      values[key] = configuredValues[configuredValues.length - 1];
    }
  }
  return values;
}
