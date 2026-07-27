# Version Management

> EPIC-147 — prevent root/node/rust version drift.
>
> Historical debt: v3.10.0 → v3.29.0 (5+ releases) shipped with drifted versions
> (root `3.18.0`, `node` `1.0.0`, `rust` `3.5.0`, git tag `v3.29.0`).
> Cause: only git tag + `gh release` bumped; the 3 canonical source files never
> got updated. Detected by `scripts/build-tools/version-check.sh` (prebuild hook
> in root `npm run build`). Fixed in v3.30.1 (EPIC-147).

## 3 Canonical Version Sources

| File | Field | Notes |
|------|-------|-------|
| `package.json`               | `"version"`                     | root workspace |
| `node/package.json`          | `"version"`                     | `@kallax/node`, published to npm |
| `rust/Cargo.toml`            | `[workspace.package] version`   | inherited by all `rust/crates/*` via `version.workspace = true` |

All 3 must match — enforced by `scripts/build-tools/version-check.sh` (exit 1 on drift).

## When to Bump

Bump immediately **before tagging a release**:

1. All EPICs merged into `miao`.
2. Working tree clean (`git status` empty).
3. Run `bump-version.sh <next-version>`.
4. Regenerate `Cargo.lock`.
5. Commit → tag → push → release.

Do not bump mid-EPIC.

## How to Bump

```bash
# Dry run (see the diff, no files touched):
bash scripts/build-tools/bump-version.sh --dry-run 3.30.2

# Real bump:
bash scripts/build-tools/bump-version.sh 3.30.2

# Regen Cargo.lock (workspace.package.version change forces lockfile update):
cd rust && cargo check --workspace && cd ..

# Verify:
bash scripts/build-tools/version-check.sh    # must exit 0
npm run build                                # prebuild hook runs version-check
```

### Guards

- Format: `X.Y.Z` (semver-simple, no pre-release suffix). Reject otherwise.
- Refuses to run if any of the 3 target files has uncommitted changes
  (avoids overwriting your work). Override with `--force` if you really mean it.
- Post-update self-verification: re-reads the 3 files and refuses to exit 0
  unless all match target.

## Sample Release Workflow

```bash
# 1. on miao, clean tree
git checkout miao && git pull

# 2. dry-run to see the diff
bash scripts/build-tools/bump-version.sh --dry-run 3.31.0

# 3. actual bump + lockfile regen
bash scripts/build-tools/bump-version.sh 3.31.0
cd rust && cargo check --workspace && cd ..

# 4. verify (must exit 0)
bash scripts/build-tools/version-check.sh
npm run build

# 5. commit + tag + push
git add package.json node/package.json rust/Cargo.toml rust/Cargo.lock
git commit -m "chore: bump version to 3.31.0"
git tag v3.31.0
git push origin miao --tags

# 6. gh release
gh release create v3.31.0 --title "v3.31.0" --notes-file CHANGELOG.md
```

## Prevention

- `prebuild` hook (`package.json` root) runs `version-check.sh` — any drift
  fails `npm run build` immediately, catching the bug at build time not release time.
- Pre-tag CI should also run `bash scripts/build-tools/version-check.sh`.
