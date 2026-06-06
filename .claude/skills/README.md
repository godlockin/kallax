# KALLAX Skills

Skills are loaded from the system-level directory:

```
~/.claude/skills/kallax/
├── SKILL.md              # Command index
├── experts/              # 40+ expert profiles
├── skills/               # 20+ skill definitions
└── references/           # Cross-platform tool mappings
```

## Session Init

```
/kallax-init --role master       # Take over as Master
/kallax 初始化为新的conductor    # Initialize as Conductor
```

## Sync

```bash
# System → Project (pull latest)
cp -r ~/.claude/skills/kallax/ .claude/skills/kallax/

# Project → System (push updates)  
cp -r .claude/skills/kallax/ ~/.claude/skills/kallax/
```
