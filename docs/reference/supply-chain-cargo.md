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

## Real-world case: v3.29.0 canary CVE response (EPIC-140)

Post-`cargo-audit.yml` install (via EPIC-136-C), the very first CI run — PR #148 canary, run 30199368393 — flagged **4 vulnerabilities + 2 denied warnings** in the pre-existing `Cargo.lock`. These were historical debt from before the audit gate existed; the workflow caught them on day one.

Findings & resolution:

| ID | Crate | Old | New | Path |
|----|-------|-----|-----|------|
| RUSTSEC-2026-0190 | `anyhow` | 1.0.102 | dropped | transitively removed after reqwest 0.12 bump (see below); no direct dep on `anyhow` in workspace |
| RUSTSEC-2026-0204 | `crossbeam-epoch` | 0.9.18 | 0.9.20 | `cargo update -p crossbeam-epoch` (in-range) |
| RUSTSEC-2026-0098 | `rustls-webpki` | 0.101.7 | 0.103.13 | transitive via `reqwest`; **bumped `reqwest 0.11 → 0.12`** in workspace root + `kallax-server/Cargo.toml` dev-dep |
| RUSTSEC-2026-0099 | `rustls-webpki` | 0.101.7 | 0.103.13 | same as above |
| RUSTSEC-2026-0104 | `rustls-webpki` | 0.101.7 | 0.103.13 | same as above |
| RUSTSEC-2025-0134 | `rustls-pemfile` (unmaintained) | 1.0.4 | dropped | reqwest 0.12 no longer pulls the 1.x pemfile crate |

Files touched: 2 `Cargo.toml` (`rust/Cargo.toml` + `rust/crates/kallax-server/Cargo.toml`) + regenerated `Cargo.lock` (307 → 294 crates after dedup).

Verification:

- `cargo audit --deny warnings` — exit 0, "0 crate dependencies vulnerable" (raw: `/tmp/cargo-audit-after.txt`).
- `cargo check --locked --workspace` — clean.
- `cargo test --workspace --release --no-fail-fast` — all suites green, incl. `kallax-core` (25/25), `kallax-server` (1/1), `kallax-engine` unit + doc tests.

Response time: within one performer session after the canary alert. Zero `[patch.crates-io]` needed — all fixes were direct upstream releases; the semver bump (reqwest 0.11 → 0.12) was the only manifest change beyond `cargo update`.

Takeaway: **the audit gate paid for itself on install day**. Everything caught was pre-existing debt invisible to CI before EPIC-136-C.
