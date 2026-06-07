# Instance Pre-Clean Runbook

> KALLAX instance lifecycle cleanup SOP for CLOSING/ZOMBIE instances

## Trigger Conditions

| Condition | Threshold | Action |
|-----------|-----------|--------|
| CLOSING state | > 24 hours | Eligible for cleanup |
| CLOSING state | > 7 days no heartbeat | High priority cleanup |
| ZOMBIE state | Any | Eligible for cleanup |
| CLOSING count | > 30 instances | Alert triggered |

## Cleanup Decision Tree

```
audit-closing-instances.sh
        │
        ▼
  ┌────┴────┐
   │ CLOSING?│
   └────┬────┘
        │yes │no
        ▼ ▼
   >24h since Done
   last_beat?
   / \
  yes         no
   │           │
   ▼           ▼
 ELIGIBLE    NOT YET
 FOR CLEAN (recheck24h)
```

## 3-Step Cleanup Process

### Step 1: Audit (always run first)

```bash
cd /Users/chenchen/working/sourcecode/tools/dev-tools/kallax
bash scripts/audit-closing-instances.sh 2>&1
```

Output shows:
- CLOSING instances with age since last_beat
- ZOMBIE instances
- Warning if CLOSING count > 30

### Step 2: Dry Run

```bash
cd /Users/chenchen/working/sourcecode/tools/dev-tools/kallax
bash scripts/kallax-cleanup.sh --dry-run 2>&1
```

Verify:
- Lists STALE instances (last_beat > 5min)
- Lists ORPHAN heartbeat daemons (etime > 1h, no instance_dir)
- No unexpected modifications

### Step 3: Force (requires master approval)

```bash
# ONLY run after master approval
cd /Users/chenchen/working/sourcecode/tools/dev-tools/kallax
bash scripts/kallax-cleanup.sh --force 2>&1
```

Effects:
- STALE instances (no heartbeat > 5min) → marked ZOMBIE
- Orphan heartbeat daemons (running > 1h, instance dir missing) → killed

## Rollback Path

### If cleanup causes issues:

1. **Identify affected instances** from cleanup log output
2. **Restore state.json** from backup:
   ```bash
   # Backup location: .kallax/backups/instances/<date>/
   cp .kallax/backups/instances/$(date +%Y%m%d)/<instance_id>/state.json \
      .kallax/instances/<instance_id>/state.json
   ```
3. **Restart heartbeat** for affected instances:
   ```bash
   bash scripts/heartbeat-daemon.sh <instance_id>
   ```

### State.json backup

Before running --force, backups are created at:
```
.kallax/backups/instances/$(date +%Y%m%d)/<instance_id>/state.json
```

## Cron Schedule Recommendation

```cron
# Daily 3am UTC — minimum business impact
0 3 * * * cd /Users/chenchen/working/sourcecode/tools/dev-tools/kallax && bash scripts/audit-closing-instances.sh >> .kallax/logs/instance-audit.log 2>&1
```

## Monitoring & Alerting

| Metric | Threshold | Alert |
|--------|-----------|-------|
| CLOSING instances | > 30 | PagerDuty alert to master |
| CLOSING age | > 7 days | Warning in audit output |
| ZOMBIE instances | > 10 | Warning in audit output |
| Cleanup failures | Any | Error alert |

## Safety Guards

1. **24h rule**: CLOSING instances < 24h since last_beat are NEVER cleaned
2. **Instance guard**: Orphan killer only kills if instance_dir no longer exists
3. **Dry-run default**: Without --force, cleanup only reports
4. **Audit trail**: All orphan kills logged to `.kallax/logs/orphan_kills.jsonl`

## Quick Reference

```bash
# Audit only (safe, no modifications)
bash scripts/audit-closing-instances.sh

# Dry run (safe, shows what would be cleaned)
bash scripts/kallax-cleanup.sh --dry-run

# Force cleanup (master approval required)
bash scripts/kallax-cleanup.sh --force
```

## Troubleshooting

### "instance not found" during cleanup
- Instance was likely manually removed
- Check .kallax/logs/orphan_kills.jsonl for audit record

### Heartbeat daemon won't start after restore
- Verify state.json has valid JSON
- Check instance_id matches directory name
- Run `bash scripts/kallax-cleanup.sh --dry-run` to diagnose