# build.rs Inventory — Rust Workspace

> **Purpose**: 防止 upstream crate 悄悄加 `build.rs` (任意代码执行面).
> 每个 build.rs 一行说明. 加/删 build.rs 必须同步更新本文档.
>
> **EPIC**: EPIC-136-D (borrow-from-cindy supply-chain audit)
> **Companion script**: [`scripts/audit/list-build-rs.sh`](../../scripts/audit/list-build-rs.sh)
> **CI check**: `bash scripts/audit/list-build-rs.sh --diff-against docs/reference/build-rs-inventory.md`

---

## Current Inventory

- scanned: 2026-07-26
- root: `rust/`
- **count: 0**

**Status**: 0 build.rs in Rust workspace as of 2026-07-26.

This document is a **sentinel** — if a `build.rs` is added to any crate under `rust/crates/*/`, this doc must be updated before merge (CI enforces via `--diff-against`).

### Table (empty)

| Crate | File | Bytes | Purpose | Owner | Added-in EPIC |
|-------|------|-------|---------|-------|---------------|
| _(none)_ | | | | | |

---

## Why This Matters (supply-chain surface)

`build.rs` runs during `cargo build` with full host privileges — it can:

- Read / write arbitrary files
- Execute shell commands (`std::process::Command`)
- Access network (fetch remote artifacts, phone home)
- Modify emitted linkage (link malicious C libs)

Cindy's philosophy (borrowed here): **explicit allowlist over silent trust**. If a first-party crate adds `build.rs`, an audit note lands in this table. If an upstream dep adds one, we see it in `cargo tree --format '{p} {b}'` or `find target/ -name build.rs`, and the CI sentinel catches source-tree drift.

---

## Maintainer Workflow

When adding a `build.rs`:

1. Add the file to the crate
2. Run `bash scripts/audit/list-build-rs.sh --format human` to confirm it's picked up
3. Add a row to the table above with:
   - **Crate**: parent crate name (`kallax-core` etc.)
   - **File**: relative path from repo root
   - **Bytes**: `wc -c` value
   - **Purpose**: one-line honest description (link libX, codegen protobuf, detect target arch — mark `<TODO: check>` if unsure and file a follow-up ticket)
   - **Owner**: git commit author or maintainer
   - **Added-in EPIC**: EPIC-XXX or `pre-EPIC / origin`
4. Re-run `bash scripts/audit/list-build-rs.sh --diff-against docs/reference/build-rs-inventory.md` — must exit 0

When removing a `build.rs`:

1. Delete the file
2. Remove the corresponding row from the table
3. Re-run the diff check

---

## Reproduce This Inventory

```bash
# from repo root
bash scripts/audit/list-build-rs.sh --format human
# JSON for machine consumption
bash scripts/audit/list-build-rs.sh --format json

# CI check (exit 1 on drift)
bash scripts/audit/list-build-rs.sh --diff-against docs/reference/build-rs-inventory.md
```

---

## Related

- Node counterpart: `pnpm.onlyBuiltDependencies` allowlist in `node/package.json` (currently: `better-sqlite3`, `esbuild`)
- Decision doc: `confluence/decisions/borrow-from-cindy-2026-07-26.md`
