# Rust Supply-Chain Gate

> EPIC-136-C · `.github/workflows/cargo-audit.yml`
> Rust-side counterpart to the Node `pnpm.overrides` gate.

## What runs

Every PR touching `rust/**` — plus a weekly Mon 03:00 UTC cron — executes:

1. `cargo audit --deny warnings` (fails on CVEs, yanked crates, unmaintained flags)
2. `cargo tree --duplicates` (informational — duplicates bloat binaries + fragment CVE fixes)
3. `cargo check --locked --workspace` (fails if `Cargo.toml` drifted from `Cargo.lock`)
4. `git diff --exit-code -- Cargo.lock` (defense-in-depth: no in-CI lockfile mutation)

## Why `--deny warnings`

`cargo audit` classifies findings as:

- **Vulnerabilities** — always error.
- **Warnings** — yanked crates + `unmaintained`/`unsound`/`notice` advisories.

Without `--deny warnings`, a yanked or unmaintained crate silently passes CI. We treat both as blocking; use the CVE response playbook below to unblock.

## Weekly schedule rationale

New advisories are published against lockfiles that haven't changed. Cron re-runs audit against `main` so we learn about a Monday-morning CVE before Friday's release, not after.

## Responding to a CVE alert

1. **Identify the crate**: `cargo audit` output includes `RUSTSEC-YYYY-NNNN` + the affected crate.
2. **Try a direct upgrade first**: `cargo update -p <crate>` — this rewrites `Cargo.lock` in place if the semver range allows.
3. **Bump the manifest** if the safe version is outside the current range: edit `rust/<workspace-member>/Cargo.toml` (or workspace root), then `cargo update -p <crate>`.
4. **Transitive-only fix**: when we don't own the direct dep, use `[patch.crates-io]` at the workspace root:
   ```toml
   [patch.crates-io]
   vulnerable-crate = { git = "https://github.com/org/vulnerable-crate", tag = "v1.2.3" }
   ```
5. **No fix available yet**: file an internal tracking ticket + add an `ignore = ["RUSTSEC-YYYY-NNNN"]` entry to `rust/.cargo/audit.toml` with an expiry date. Never ignore without a ticket.
6. Commit the updated `Cargo.lock` in the same PR — the lockfile-integrity step will fail otherwise.

## Reproduce locally

```bash
cargo install cargo-audit --locked
cd rust && cargo audit
cd rust && cargo tree --duplicates
cd rust && cargo check --locked --workspace
```

## See also

- Node counterpart: `pnpm.overrides` gate (EPIC-136 sibling).
- Advisory DB: <https://rustsec.org/>.
