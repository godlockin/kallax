# KALLAX Skills for Aider (v2.3.0)

> Aider is a CLI AI pair programming tool. It does not have a native slash
> command API, so KALLAX skills are exposed as **context files** that
> aider reads via `--read` flags or the `read` directive in `~/.aider.conf.yml`.

## Quick Setup (1 minute)

After running `./scripts/install.sh --target=aider`, the skills are at `~/.aider/skills/kallax/`.

Add the following to `~/.aider.conf.yml`:

```yaml
# KALLAX integration (v2.3.0 — auto-loaded as context)
read:
  - ~/.aider/skills/kallax/SKILL.md
  - ~/.aider/skills/kallax/SKILL-DETAIL.md
  - ~/.aider/skills/kallax/default/architect.md
  - ~/.aider/skills/kallax/default/backend.md
  - ~/.aider/skills/kallax/default/frontend.md
  - ~/.aider/skills/kallax/default/ux.md
  - ~/.aider/skills/kallax/default/product.md
  - ~/.aider/skills/kallax/extended/security-tool-bypass.md
  - ~/.aider/skills/kallax/extended/process-engineering-self-verify.md
  - ~/.aider/skills/kallax/extended/auditor-independent-witness.md
  - ~/.aider/skills/kallax/extended/compliance-rule-merge.md
  - ~/.aider/skills/kallax/extended/decision-gate-complex-only.md
```

Or pass on the command line (one-off, no config edit):

```bash
aider --read ~/.aider/skills/kallax/SKILL.md \
      --read ~/.aider/skills/kallax/default/backend.md \
      --read ~/.aider/skills/kallax/extended/auditor-independent-witness.md
```

## Available Skills (跟 v2.3.0 SKILL.md 同步)

Aider doesn't have slash commands, but the KALLAX skill content is
mirrored here so the LLM can use it as context:

- **Main skill** (`SKILL.md`): top-level usage patterns + Quick Reference table (10 类 29 命令)
- **Detail** (`SKILL-DETAIL.md`): Detailed reference (daemon invocation, zombie defense, Performer onboarding)
- **4 default experts** (`default/`): backend, frontend, ux, product
  - **Note**: architect 跟 Conductor 合并 (EPIC-056-A v2.0.3 治 A4 协调开销)
- **5 extended experts** (`extended/`): security-tool-bypass, process-engineering-self-verify, auditor-independent-witness, compliance-rule-merge, decision-gate-complex-only

## Usage Pattern

After config, just start aider normally. The KALLAX skills auto-load as context:

```bash
# aider auto-loads SKILL.md + 9 expert files
cd my-project
aider

# Inside aider, you can ask:
# "Run /kallax-panel on the auth refactor"
# "Apply /kallax-expert backend to design the new API"
# "Use /kallax-verify-pr on PR #42"
```

Aider doesn't have native slash commands, so the LLM reads the skill files as context and matches the user's natural language to the closest `/kallax-*` command.

## See Also

- [INSTALL-MULTI-TOOL.md](../../../docs/guides/INSTALL-MULTI-TOOL.md) — 10-tool install guide
- [KALLAX-GLOSSARY.md](../../../docs/KALLAX-GLOSSARY.md) — 60+5 terms (multi-tool section)
- [slash-commands.md](../../../docs/reference/slash-commands.md) — Full 26-command reference
- https://aider.chat/docs/config.html — aider config reference
