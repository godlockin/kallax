# KALLAX Skills for Continue.dev (v2.3.0)

> Continue.dev is a VS Code AI extension. It does not have a native slash
> command API, so KALLAX skills are exposed as **system prompts** in
> `~/.continue/config.json`.

## Quick Setup (2 minutes)

After running `./scripts/install.sh --target=continue`, the skills are at `~/.continue/skills/kallax/`.

Add the following to `~/.continue/config.json`:

```json
{
  "models": [...],
  "systemPrompts": [
    {
      "name": "kallax",
      "content": "Read and apply KALLAX skill files from ~/.continue/skills/kallax/ as context. See SKILL.md for the main usage patterns and Quick Reference table."
    }
  ],
  "customCommands": [
    {
      "name": "kallax",
      "description": "Apply KALLAX multi-agent framework (4 default + 5 extended experts + Conductor, EPIC-056-A 3-phase governance)",
      "prompt": "Apply the KALLAX skill at ~/.continue/skills/kallax/SKILL.md. Quick Reference: setup (init/start/mode/role), status (status/help/board/list/instances/check-progress/phase-review), work (task/claim/submit-pr/merge/save/resume), review (verify-pr/review-pr/review-merge/review-analysis), expert (expert/panel/ask/skill), analysis (analyze/office-hours), onboard (onramp/takeover). Load relevant expert files in default/ and extended/ subdirectories."
    }
  ]
}
```

Then in VS Code, the slash command `/kallax` (or via the Continue panel) loads the KALLAX context.

## Available Skills (跟 v2.3.0 SKILL.md 同步)

Continue doesn't have native slash commands, but the KALLAX skill content is mirrored here so the LLM can use it as context:

- **Main skill** (`SKILL.md`): top-level usage patterns + Quick Reference table (10 类 29 命令)
- **Detail** (`SKILL-DETAIL.md`): Detailed reference (daemon invocation, zombie defense, Performer onboarding)
- **4 default experts** (`default/`): backend, frontend, ux, product
  - **Note**: architect 跟 Conductor 合并 (EPIC-056-A v2.0.3 治 A4 协调开销)
- **5 extended experts** (`extended/`): security-tool-bypass, process-engineering-self-verify, auditor-independent-witness, compliance-rule-merge, decision-gate-complex-only

## Usage Pattern

After config, open VS Code with Continue and use the slash command:

```bash
# In VS Code, open Continue panel
# Type: /kallax

# Or trigger by natural language:
# "I need to refactor the auth module"
# → Continue matches to /kallax-panel [topic] = auth refactor
# → Loads 4 default + 5 extended expert context
# → Returns multi-perspective review
```

## See Also

- [INSTALL-MULTI-TOOL.md](../../../docs/guides/INSTALL-MULTI-TOOL.md) — 10-tool install guide
- [KALLAX-GLOSSARY.md](../../../docs/KALLAX-GLOSSARY.md) — 60+5 terms (multi-tool section)
- [slash-commands.md](../../../docs/reference/slash-commands.md) — Full 26-command reference
- https://continue.dev/docs/customize — Continue config reference
