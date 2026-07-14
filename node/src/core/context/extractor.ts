import { logger } from '../../utils/logger.js';

export interface ExtractedContext {
  readonly decisions: string[]; readonly actionItems: string[];
  readonly learnedContext: string[]; readonly summary: string; readonly timestamp: number;
}
export interface ContextExtractor {
  extract(messages: Array<{ role: string; content: string }>): ExtractedContext;
  extractFromText(text: string): Partial<ExtractedContext>;
}
const DEC = [/决定[：:]\s*(.+)/g, /方案[是：:]\s*(.+)/g, /最终确认[：:]\s*(.+)/g, /we decided[：:]\s*(.+)/gi, /CONCLUSION[：:]\s*(.+)/g];
const ACT = [/TODO[：:]\s*(.+)/gi, /下一步[：:]\s*(.+)/gi, /需要实现[：:]\s*(.+)/g, /待做[：:]\s*(.+)/g, /NEXT[：:]\s*(.+)/g];
const LRN = [/修复[：:]\s*(.+)/g, /root cause[：:]\s*(.+)/g, /教训[：:]\s*(.+)/g, /注意[：:]\s*(.+)/g];

function extractPatterns(text: string, patterns: RegExp[]): string[] {
  const results: string[] = [];
  for (const p of patterns) {
    const r = new RegExp(p.source, p.flags); let m;
    while ((m = r.exec(text)) !== null) { const v = (m[1] ?? '').trim().slice(0, 200); if (v && !results.includes(v)) results.push(v); }
  }
  return results;
}
export function createContextExtractor(): ContextExtractor {
  return {
    extract(messages): ExtractedContext {
      const text = messages.map(m => `${m.role}: ${m.content}`).join('\n');
      const e = this.extractFromText(text);
      const decisionsCount = e.decisions?.length ?? 0;
      const actionsCount = e.actionItems?.length ?? 0;
      const result: ExtractedContext = {
        decisions: e.decisions ?? [], actionItems: e.actionItems ?? [], learnedContext: e.learnedContext ?? [],
        summary: [decisionsCount ? `${String(decisionsCount)} decisions` : '', actionsCount ? `${String(actionsCount)} actions` : ''].filter(Boolean).join(', ') || 'No key items',
        timestamp: Date.now(),
      };
      logger.info({ d: result.decisions.length, a: result.actionItems.length }, 'context extracted');
      return result;
    },
    extractFromText(text): Partial<ExtractedContext> {
      return { decisions: extractPatterns(text, DEC), actionItems: extractPatterns(text, ACT), learnedContext: extractPatterns(text, LRN) };
    },
  };
}
let inst: ContextExtractor | null = null;
export function getContextExtractor(): ContextExtractor { return inst ?? (inst = createContextExtractor()); }
