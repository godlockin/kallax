# KALLAX Skills for Aider (v2.1.0)

> Aider is a CLI AI pair programming tool. It does not have a native slash
> command API, so KALLAX skills are exposed as **context files** that
> aider reads via `--read` flags or the `read` directive in `~/.aider.conf.yml`.

## Setup

Add the following to `~/.aider.conf.yml`:

```yaml
# KALLAX integration
read:
  - ~/.aider/skills/kallax/SKILL.md
  - ~/.aider/skills/kallax/default/architect.md
  - ~/.aider/skills/kallax/default/backend.md
  - ~/.aider/skills/kallax/default/frontend.md
  - ~/.aider/skills/kallax/default/ux.md
  - ~/.aider/skills/kallax/default/product.md
  - ~/.aider/skills/kallax/extended/security-tool-bypass.md
  - ~/.aider/skills/kallax/extended/auditor-independent-witness.md
  - ~/.aider/skills/kallax/extended/decision-gate-complex-only.md
  - ~/.aider/skills/kallax/extended/process-engineering-self-verify.md
  - ~/.aider/skills/kallax/extended/compliance-rule-merge.md
```

Or pass on the command line:

```bash
aider --read ~/.aider/skills/kallax/SKILL.md --read ~/.aider/skills/kallax/default/backend.md
```

## Available Skills

Aider doesn't have slash commands, but the KALLAX skill content is
mirrored here so the LLM can use it as context:

- **5 Core experts** (`default/`): architect, backend, frontend, ux, product
- **5 Extended experts** (`extended/`): auditor, compliance, decision-gate, process-engineering, security
- **Main skill** (`SKILL.md`): top-level usage patterns

## See Also

- [INSTALL-MULTI-TOOL.md](../../../docs/guides/INSTALL-MULTI-TOOL.md) — 8-tool install guide
- [KALLAX-GLOSSARY.md](../../../docs/KALLAX-GLOSSARY.md) — 39 terms (Section 8.6-8.13 multi-tool)
- https://aider.chat/docs/config.html — aider config reference
