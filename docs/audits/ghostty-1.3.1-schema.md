# Ghostty 1.3.1 schema audit

- Audited: 2026-08-05
- Official input: stable Ghostty snap, amd64 revision 820
- Comparison input: pkgforge-dev Ghostty 1.3.1 x86_64 AppImage
- Command: `scripts/audit-ghostty-1.3.1-schema.sh`
- Machine-readable record: `tests/fixtures/ghostty-1.3.1-schema-audit.json`

Both binaries were executed in the same Ubuntu 22.04 amd64 container with `LC_ALL=C.UTF-8`.
The script pins and verifies the complete package SHA-256 values before extracting either package.
The official snap is run with its pinned core24 base and snap launcher environment.

## Result

The complete `+show-config --default --docs` byte streams are identical:

```text
official  acc95fe8726531505334a222b82c0eaef59acd4986fb4ccd8bb054eedbb83a9d
pkgforge  acc95fe8726531505334a222b82c0eaef59acd4986fb4ccd8bb054eedbb83a9d
```

Consequently every `audited_contract` key has the same Linux default and the same documented
value domain. The machine-readable record stores each key's defaults and documentation hash;
the Rust regression test also requires its key set, kind, and select choices to remain synchronized
with the runtime policy.

An official macOS build is not a valid default-value comparator for this Linux contract: for
example, Ghostty 1.3.1 defaults `font-size` to 13 on macOS and 12 on Linux. The audit therefore
uses platform-equivalent official and community Linux packages while still retaining the official
macOS schema as a separate, exact version/hash contract.
