# KALLAX Makefile
# v2.7.4 cleanup, 跟 4 团队 review 报告 CFG5 联合
# 0 增 Rule 0 增命令 持平, 跟"翻篇&精进" 战略 一致
# Dual-engine (Node.js + Rust) + 6 AI tools (claude/trae/antigravity/opencode/codex/gemini/cursor/windsurf)

.PHONY: help build test lint clean install web bench

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build:  ## Build all engines (Node + Rust)
	@echo "→ Building Node.js runtime"
	cd node && npm install
	@echo "→ Building Rust workspace"
	cd rust && cargo build --release

test:  ## Run all tests (Node vitest + shell integration + Rust)
	@echo "→ Running Node vitest"
	cd node && npm test
	@echo "→ Running shell integration tests"
	@for t in tests/integration/*-test.sh; do bash "$$t" || exit 1; done
	@echo "→ Running Rust tests"
	cd rust && cargo test

lint:  ## Lint all engines
	@echo "→ Linting Node.js"
	cd node && npm run lint
	@echo "→ Linting Rust"
	cd rust && cargo clippy --all-targets -- -D warnings
	@echo "→ Linting shell scripts"
	bash scripts/check-9-hard-rules.sh
	bash scripts/check-doc-hygiene.sh
	bash scripts/check-pr-size.sh

clean:  ## Clean build artifacts
	@echo "→ Cleaning Rust target"
	cd rust && cargo clean
	@echo "→ Cleaning Node dist"
	rm -rf node/dist
	@echo "→ Cleaning KALLAX runtime state"
	rm -rf .kallax/data .kallax/logs .kallax/queue .kallax/instances .kallax/benchmarks

install:  ## Install KALLAX for all 10 AI tools (跟 install.sh v2.3.0 --symlink default 联合)
	./scripts/install.sh --target=all

web:  ## Run web dashboard
	cd web && python3 -m http.server 8080

bench:  ## Run k6 load test
	k6 run tests/load/k6/load-test.js
