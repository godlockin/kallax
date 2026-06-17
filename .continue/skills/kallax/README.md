# KALLAX Skills for Continue.dev (v2.1.0)

> Continue.dev is a VS Code AI extension. It does not have a native slash
> command API, so KALLAX skills are exposed as **system prompts** in
> `~/.continue/config.json`.

## Setup

Add the following to `~/.continue/config.json`:

```json
{
  "models": [...],
  "systemPrompts": [
    {
      "name": "kallax",
      "content": "Read and apply KALLAX skill files from ~/.continue/skills/kallax/ as context. See SKILL.md for the main usage patterns."
    }
  ],
  "customCommands": [
    {
      "name": "kallax",
      "description": "Apply KALLAX multi-agent framework (5 core + 5 extended experts)",
      "prompt": "Apply the KALLAX skill at ~/.continue/skills/kallax/SKILL.md and the relevant expert files in default/ and extended/ subdirectories."
    }
  ]
}
```

Then in VS Code, the slash command `/kallax` (or via the Continue panel)
loads the KALLAX context.

## Available Skills

Continue doesn't have native slash commands, but the KALLAX skill content
is mirrored here so the LLM can use it as context:

- **5 Core experts** (`default/`): architect, backend, frontend, ux, product
- **5 Extended experts** (`extended/`): auditor, compliance, decision-gate, process-engineering, security
- **Main skill** (`SKILL.md`): top-level usage patterns

## See Also

- [INSTALL-MULTI-TOOL.md](../../../docs/guides/INSTALL-MULTI-TOOL.md) — 8-tool install guide
- [KALLAX-GLOSSARY.md](../../../docs/KALLAX-GLOSSARY.md) — 39 terms (Section 8.6-8.13 multi-tool)
- https://continue.dev/docs/customize — Continue config reference
