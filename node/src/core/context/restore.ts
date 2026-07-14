import * as fs from 'node:fs';
import * as path from 'node:path';
import { logger } from '../../utils/logger.js';

export interface ContextBrief {
  readonly performerId: string; readonly lastSession: number | null;
  readonly pendingActions: string[]; readonly recentDecisions: string[];
  readonly learnedLessons: string[]; readonly summary: string;
}
export interface ContextRestore {
  restore(performerId: string): ContextBrief; getProjectContext(): ContextBrief;
  listSessions(performerId?: string): Array<{ file: string; timestamp: number; itemCount: number }>;
}
const CTX = '.kallax/context'; const ARC = '.kallax/archive';

function readFiles(pid?: string): unknown[] {
  const items: unknown[] = [];
  for (const dir of [CTX, ARC]) {
    if (!fs.existsSync(dir)) continue;
    for (const f of fs.readdirSync(dir)) {
      if (!f.endsWith('.json') || f === 'index.json') continue;
      if (pid != null && !f.startsWith(pid)) continue;
      try { items.push(JSON.parse(fs.readFileSync(path.join(dir, f), 'utf-8'))); } catch { /* */ }
    }
  }
  return items;
}

export function createContextRestore(): ContextRestore {
  return {
    restore(pid: string): ContextBrief {
      const items = readFiles(pid); const acts: string[] = []; const decs: string[] = [];
      let last: number | null = null;
      for (const item of items) {
        const d = item as Record<string, unknown>;
        if (typeof d['savedAt'] === 'string') { const ts = new Date(d['savedAt']).getTime(); if (last === null || ts > last) last = ts; }
        if (typeof d['summary'] === 'string') {
          if ((d['summary']).includes('TODO') || (d['summary']).includes('待做')) acts.push(d['summary']);
          else if ((d['summary']).includes('决定') || (d['summary']).includes('decision')) decs.push(d['summary']);
        }
      }
      logger.info({ pid, files: items.length }, 'context restored');
      return { performerId: pid, lastSession: last, pendingActions: acts.slice(0, 10), recentDecisions: decs.slice(0, 10), learnedLessons: [], summary: `${String(items.length)} files restored. ${String(acts.length)} actions pending.` };
    },
    getProjectContext(): ContextBrief { return this.restore('*'); },
    listSessions(pid?: string): Array<{ file: string; timestamp: number; itemCount: number }> {
      const sessions: Array<{ file: string; timestamp: number; itemCount: number }> = [];
      for (const dir of [CTX, ARC]) {
        if (!fs.existsSync(dir)) continue;
        for (const f of fs.readdirSync(dir)) {
          if (!f.endsWith('.json') || f === 'index.json') continue;
          if (pid != null && !f.startsWith(pid)) continue;
          try {
            const st = fs.statSync(path.join(dir, f)); let ic = 0;
            try { const c = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf-8')) as { itemCount?: number; items?: unknown[] }; ic = c.itemCount ?? c.items?.length ?? 0; } catch { /* */ }
            sessions.push({ file: path.join(dir, f), timestamp: st.mtimeMs, itemCount: ic });
          } catch { /* */ }
        }
      }
      return sessions.sort((a, b) => b.timestamp - a.timestamp);
    },
  };
}
let inst: ContextRestore | null = null;
export function getContextRestore(): ContextRestore { return inst ?? (inst = createContextRestore()); }
