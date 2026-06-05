import * as fs from 'node:fs';
import * as path from 'node:path';
import { logger } from '../../utils/logger.js';

export interface ArchiveEntry { readonly originalFile: string; readonly archiveFile: string; readonly archivedAt: number; readonly ageDays: number; }
export interface ArchiveStats { readonly totalArchived: number; readonly archiveSizeBytes: number; }
export interface ContextArchiver {
  run(): ArchiveEntry[]; stats(): ArchiveStats; clean(retentionDays?: number): number; startPeriodic(intervalMs?: number): () => void;
}
const CTX = '.kallax/context'; const ARC = '.kallax/archive'; const IDX = '.kallax/archive/index.json';
function ed(dir: string): void { if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true }); }
function loadIdx(): Record<string, unknown>[] { try { if (fs.existsSync(IDX)) return JSON.parse(fs.readFileSync(IDX, 'utf-8')); } catch { /* */ } return []; }
function saveIdx(e: Record<string, unknown>[]): void { ed(ARC); fs.writeFileSync(IDX, JSON.stringify(e, null, 2)); }

export function createContextArchiver(): ContextArchiver {
  let iv: ReturnType<typeof setInterval> | null = null;
  return {
    run(): ArchiveEntry[] {
      ed(CTX); ed(ARC); const entries: ArchiveEntry[] = []; const idx = loadIdx();
      const now = Date.now(); const cutoff = now - (7 * 86_400_000);
      for (const f of fs.readdirSync(CTX).filter(f => f.endsWith('.json'))) {
        const fp = path.join(CTX, f); const st = fs.statSync(fp);
        if (st.mtimeMs >= cutoff) continue;
        const an = `${f.replace('.json','')}-${now.toString(36)}.json`;
        fs.renameSync(fp, path.join(ARC, an));
        entries.push({ originalFile: f, archiveFile: an, archivedAt: now, ageDays: Math.round((now - st.mtimeMs) / 86_400_000) });
      }
      if (entries.length > 0) { for (const e of entries) idx.push(e); saveIdx(idx); logger.info({ count: entries.length }, 'archive cycle'); }
      return entries;
    },
    stats(): ArchiveStats {
      ed(ARC); const fs2 = fs.readdirSync(ARC).filter(f => f.endsWith('.json') && f !== 'index.json');
      let sz = 0; for (const f of fs2) { try { sz += fs.statSync(path.join(ARC, f)).size; } catch { /* */ } }
      return { totalArchived: fs2.length, archiveSizeBytes: sz };
    },
    clean(retentionDays = 90): number {
      ed(ARC); const cutoff = Date.now() - (retentionDays * 86_400_000); const idx = loadIdx();
      let rm = 0; const kp: Record<string, unknown>[] = [];
      for (const e of idx) {
        if ((e.archivedAt as number) < cutoff) { try { fs.unlinkSync(path.join(ARC, e.archiveFile as string)); rm++; } catch { /* */ } }
        else kp.push(e);
      }
      saveIdx(kp); logger.info({ rm, kp: kp.length }, 'archive cleaned'); return rm;
    },
    startPeriodic(ms = 3_600_000): () => void {
      if (iv) clearInterval(iv); iv = setInterval(() => this.run(), ms);
      return () => { if (iv) { clearInterval(iv); iv = null; } };
    },
  };
}
let inst: ContextArchiver | null = null;
export function getContextArchiver(): ContextArchiver { return inst ?? (inst = createContextArchiver()); }
