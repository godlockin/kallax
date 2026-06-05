/**
 * KALLAX Enterprise Audit — compliance-grade audit logging.
 * Append-only, immutable audit trail for all role-sensitive operations.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { logger } from '../utils/logger.js';

export interface AuditEntry {
  readonly id: string;
  readonly timestamp: number;
  readonly actor: string;        // performerId or 'conductor'/'master'
  readonly role: 'conductor' | 'performer' | 'master';
  readonly action: string;       // e.g., 'merge:testing', 'promote:miao', 'task:claim'
  readonly target: string;       // e.g., ticket ID, branch name
  readonly result: 'success' | 'failure' | 'blocked';
  readonly details: string;      // human-readable description
  readonly metadata: Record<string, unknown>;
}

export interface AuditFilter {
  actor?: string;
  role?: AuditEntry['role'];
  action?: string;
  since?: number;
  until?: number;
  result?: AuditEntry['result'];
  limit?: number;
}

export interface AuditStats {
  totalEntries: number;
  byAction: Record<string, number>;
  byRole: Record<string, number>;
  byResult: Record<string, number>;
  recentEntries: number; // last 24h
}

export interface EnterpriseAudit {
  /** Record an audit entry */
  log(entry: Omit<AuditEntry, 'id' | 'timestamp'>): AuditEntry;
  /** Query audit entries with filters */
  query(filter?: AuditFilter): AuditEntry[];
  /** Get audit statistics */
  stats(): AuditStats;
  /** Export audit log as JSON */
  export(format?: 'json' | 'csv'): string;
  /** Check if an action is allowed for a role */
  isAllowed(role: AuditEntry['role'], action: string): boolean;
}

const AUDIT_FILE = '.kallax/data/audit-log.jsonl';
const MAX_MEMORY_ENTRIES = 1000;

// Permission matrix
const PERMISSIONS: Record<string, string[]> = {
  conductor: ['merge:testing', 'promote:miao', 'review:pr', 'branch:feature', 'epic:create', 'epic:decompose', 'ticket:create', 'task:assign', 'performer:register', 'performer:unregister', 'expert:panel', 'system:doctor'],
  performer: ['task:claim', 'task:complete', 'task:release', 'pr:create', 'branch:push', 'test:run', 'lint:run', 'expert:consult'],
  master: ['merge:miao', 'promote:approve', 'tag:create', 'release:approve', 'performer:audit', 'system:configure', 'emergency:bypass'],
};

function generateId(): string { return `audit_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`; }

function ensureDir(filepath: string): void {
  const dir = path.dirname(filepath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

export function createEnterpriseAudit(): EnterpriseAudit {
  const entries: AuditEntry[] = [];

  // Load existing entries from disk
  try {
    if (fs.existsSync(AUDIT_FILE)) {
      const lines = fs.readFileSync(AUDIT_FILE, 'utf-8').trim().split('\n');
      for (const line of lines.slice(-MAX_MEMORY_ENTRIES)) {
        try { entries.push(JSON.parse(line)); } catch { /* skip corrupt lines */ }
      }
    }
  } catch { /* fresh start */ }

  ensureDir(AUDIT_FILE);

  return {
    log(entry: Omit<AuditEntry, 'id' | 'timestamp'>): AuditEntry {
      const full: AuditEntry = { ...entry, id: generateId(), timestamp: Date.now() };
      entries.push(full);
      if (entries.length > MAX_MEMORY_ENTRIES) entries.shift();

      // Append to disk
      try { fs.appendFileSync(AUDIT_FILE, JSON.stringify(full) + '\n'); } catch { /* best effort */ }

      if (entry.result === 'blocked' || entry.result === 'failure') {
        logger.warn({ actor: entry.actor, action: entry.action, result: entry.result }, 'audit: blocked/failed action');
      }
      return full;
    },

    query(filter: AuditFilter = {}): AuditEntry[] {
      let results = [...entries];
      if (filter.actor) results = results.filter(e => e.actor === filter.actor);
      if (filter.role) results = results.filter(e => e.role === filter.role);
      if (filter.action) results = results.filter(e => e.action.includes(filter.action!));
      if (filter.since) results = results.filter(e => e.timestamp >= filter.since!);
      if (filter.until) results = results.filter(e => e.timestamp <= filter.until!);
      if (filter.result) results = results.filter(e => e.result === filter.result);
      results.sort((a, b) => b.timestamp - a.timestamp);
      if (filter.limit) results = results.slice(0, filter.limit);
      return results;
    },

    stats(): AuditStats {
      const byAction: Record<string, number> = {};
      const byRole: Record<string, number> = {};
      const byResult: Record<string, number> = {};
      const cutoff = Date.now() - 86_400_000;
      let recent = 0;

      for (const e of entries) {
        byAction[e.action] = (byAction[e.action] ?? 0) + 1;
        byRole[e.role] = (byRole[e.role] ?? 0) + 1;
        byResult[e.result] = (byResult[e.result] ?? 0) + 1;
        if (e.timestamp >= cutoff) recent++;
      }

      return { totalEntries: entries.length, byAction, byRole, byResult, recentEntries: recent };
    },

    export(format: 'json' | 'csv' = 'json'): string {
      if (format === 'csv') {
        const header = 'id,timestamp,actor,role,action,target,result,details';
        const rows = entries.map(e => `${e.id},${e.timestamp},${e.actor},${e.role},${e.action},${e.target},${e.result},"${e.details}"`);
        return [header, ...rows].join('\n');
      }
      return JSON.stringify(entries, null, 2);
    },

    isAllowed(role: AuditEntry['role'], action: string): boolean {
      const allowed = PERMISSIONS[role] ?? [];
      return allowed.some(a => action.startsWith(a) || a.startsWith(action));
    },
  };
}

let instance: EnterpriseAudit | null = null;
export function getEnterpriseAudit(): EnterpriseAudit { return instance ?? (instance = createEnterpriseAudit()); }
