/**
 * KALLAX Knowledge Base — inverted index FTS + tag index + RAG search.
 */

import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

// ── Types ──────────────────────────────────────────────────────────────────

export interface KnowledgeEntry {
  readonly id: string;
  readonly title: string;
  readonly content: string;
  readonly tags: readonly string[];
  readonly source: string;
  readonly createdAt: number;
  readonly updatedAt: number;
  readonly metadata?: Record<string, unknown>;
}

export interface SearchResult {
  readonly entry: KnowledgeEntry;
  readonly score: number;
  readonly matchedTerms: string[];
}

export interface SearchQuery {
  readonly terms?: string[];
  readonly tags?: string[];
  readonly source?: string;
  readonly limit?: number;
  readonly offset?: number;
  readonly sortBy?: 'relevance' | 'date';
}

export interface KnowledgeBase {
  add: (entry: Omit<KnowledgeEntry, 'id' | 'createdAt' | 'updatedAt'>) => KallaxResult<KnowledgeEntry>;
  update: (id: string, updates: Partial<Omit<KnowledgeEntry, 'id' | 'createdAt'>>) => KallaxResult<KnowledgeEntry>;
  remove: (id: string) => KallaxResult<void>;
  get: (id: string) => KallaxResult<KnowledgeEntry>;
  search: (query: SearchQuery) => KallaxResult<SearchResult[]>;
  searchByTag: (tag: string) => KallaxResult<KnowledgeEntry[]>;
  list: (options?: { limit?: number; offset?: number }) => KallaxResult<KnowledgeEntry[]>;
  getStats: () => KnowledgeStats;
  gc: (olderThanMs: number) => KallaxResult<number>;
  clear: () => void;
}

export interface KnowledgeStats {
  readonly totalEntries: number;
  readonly totalWords: number;
  readonly totalTags: number;
  readonly indexSize: number;
}

// ── Implementation ─────────────────────────────────────────────────────────

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9一-鿿\s]/g, ' ') // Keep Chinese chars
    .split(/\s+/)
    .filter((w) => w.length > 1);
}

function generateId(): string {
  return `kb_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export function createKnowledgeBase(): KnowledgeBase {
  const entries = new Map<string, KnowledgeEntry>();
  const wordIndex = new Map<string, Set<string>>(); // word → Set<entryId>
  const tagIndex = new Map<string, Set<string>>(); // tag → Set<entryId>

  function indexEntry(entry: KnowledgeEntry): void {
    // Index words
    const words = tokenize(`${entry.title} ${entry.content}`);
    for (const word of words) {
      let ids = wordIndex.get(word);
      if (!ids) {
        ids = new Set();
        wordIndex.set(word, ids);
      }
      ids.add(entry.id);
    }

    // Index tags
    for (const tag of entry.tags) {
      let ids = tagIndex.get(tag);
      if (!ids) {
        ids = new Set();
        tagIndex.set(tag, ids);
      }
      ids.add(entry.id);
    }
  }

  function deindexEntry(entry: KnowledgeEntry): void {
    const words = tokenize(`${entry.title} ${entry.content}`);
    for (const word of words) {
      const ids = wordIndex.get(word);
      if (ids) {
        ids.delete(entry.id);
        if (ids.size === 0) wordIndex.delete(word);
      }
    }
    for (const tag of entry.tags) {
      const ids = tagIndex.get(tag);
      if (ids) {
        ids.delete(entry.id);
        if (ids.size === 0) tagIndex.delete(tag);
      }
    }
  }

  function computeScore(entry: KnowledgeEntry, queryTerms: string[]): { score: number; matchedTerms: string[] } {
    let score = 0;
    const matchedTerms: string[] = [];
    const titleWords = tokenize(entry.title);
    const contentWords = tokenize(entry.content);

    for (const term of queryTerms) {
      const termLower = term.toLowerCase();
      // Title match = 3x weight
      const titleMatches = titleWords.filter((w) => w.includes(termLower)).length;
      score += titleMatches * 3;

      // Content match = 1x weight
      const contentMatches = contentWords.filter((w) => w.includes(termLower)).length;
      score += contentMatches;

      // Exact word match bonus
      if (titleWords.includes(termLower)) score += 2;
      if (contentWords.includes(termLower)) score += 1;

      if (titleMatches > 0 || contentMatches > 0) {
        matchedTerms.push(term);
      }
    }

    // Recency boost (logarithmic, max +3)
    const ageDays = (Date.now() - entry.createdAt) / (86400_000);
    if (ageDays < 30) {
      score += Math.max(0, 3 - Math.log2(ageDays + 1));
    }

    return { score, matchedTerms };
  }

  return {
    add(input): KallaxResult<KnowledgeEntry> {
      const now = Date.now();
      const entry: KnowledgeEntry = {
        id: generateId(),
        ...input,
        createdAt: now,
        updatedAt: now,
      };

      entries.set(entry.id, entry);
      indexEntry(entry);

      logger.debug({ entryId: entry.id, title: entry.title, tagCount: entry.tags.length }, 'knowledge entry added');
      return ok(entry);
    },

    update(id: string, updates): KallaxResult<KnowledgeEntry> {
      const existing = entries.get(id);
      if (!existing) {
        return err(new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, `Knowledge entry ${id} not found`));
      }

      // De-index old version
      deindexEntry(existing);

      // Update
      const updated: KnowledgeEntry = {
        ...existing,
        ...updates,
        tags: updates.tags ?? existing.tags,
        updatedAt: Date.now(),
      };

      entries.set(id, updated);
      indexEntry(updated);

      logger.debug({ entryId: id }, 'knowledge entry updated');
      return ok(updated);
    },

    remove(id: string): KallaxResult<void> {
      const entry = entries.get(id);
      if (!entry) {
        return err(new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, `Knowledge entry ${id} not found`));
      }

      deindexEntry(entry);
      entries.delete(id);

      logger.debug({ entryId: id }, 'knowledge entry removed');
      return ok(undefined);
    },

    get(id: string): KallaxResult<KnowledgeEntry> {
      const entry = entries.get(id);
      if (!entry) {
        return err(new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, `Knowledge entry ${id} not found`));
      }
      return ok(entry);
    },

    search(query: SearchQuery): KallaxResult<SearchResult[]> {
      const limit = query.limit ?? 20;
      const offset = query.offset ?? 0;
      const results: SearchResult[] = [];

      // Collect candidate entries
      let candidates: Set<string> | null = null;

      // Filter by tags (AND — entry must have ALL specified tags)
      if (query.tags && query.tags.length > 0) {
        for (const tag of query.tags) {
          const ids = tagIndex.get(tag);
          if (!ids) return ok([]);
          if (candidates === null) {
            candidates = new Set(ids);
          } else {
            candidates = new Set([...candidates].filter((id: string) => ids.has(id)));
          }
          if (candidates.size === 0) return ok([]);
        }
      }

      // Filter by source
      if (query.source) {
        const sourceIds = new Set(
          Array.from(entries.values())
            .filter((e) => e.source === query.source)
            .map((e) => e.id),
        );
        if (candidates === null) {
          candidates = sourceIds;
        } else {
          candidates = new Set([...candidates].filter((id: string) => sourceIds.has(id)));
        }
        if (candidates.size === 0) return ok([]);
      }

      // Text search
      const searchTerms = query.terms ?? [];
      if (searchTerms.length > 0) {
        let termCandidates: Set<string> | null = null;
        for (const term of searchTerms) {
          const ids = wordIndex.get(term.toLowerCase());
          if (!ids) return ok([]);
          if (termCandidates === null) {
            termCandidates = new Set(ids);
          } else {
            // Intersection for multi-term AND search
            termCandidates = new Set([...termCandidates].filter((id: string) => ids.has(id)));
          }
          if (termCandidates.size === 0) return ok([]);
        }

        if (candidates === null) {
          candidates = termCandidates;
        } else {
          candidates = new Set([...candidates].filter((id: string) => termCandidates!.has(id)));
        }
      }

      // If no filters, return all
      const resultIds = candidates ?? new Set(entries.keys());

      // Score and collect
      for (const id of resultIds) {
        const entry = entries.get(id);
        if (!entry) continue;
        const { score, matchedTerms } = computeScore(entry, searchTerms);
        if (searchTerms.length > 0 && score === 0) continue; // No match
        results.push({ entry, score, matchedTerms });
      }

      // Sort
      if (query.sortBy === 'date') {
        results.sort((a, b) => b.entry.updatedAt - a.entry.updatedAt);
      } else {
        results.sort((a, b) => b.score - a.score);
      }

      // Paginate
      const page = results.slice(offset, offset + limit);
      return ok(page);
    },

    searchByTag(tag: string): KallaxResult<KnowledgeEntry[]> {
      const ids = tagIndex.get(tag);
      if (!ids) return ok([]);
      const results = Array.from(ids)
        .map((id) => entries.get(id))
        .filter((e): e is KnowledgeEntry => e !== undefined);
      return ok(results);
    },

    list(options?: { limit?: number; offset?: number }): KallaxResult<KnowledgeEntry[]> {
      const all = Array.from(entries.values());
      const offset = options?.offset ?? 0;
      const limit = options?.limit ?? all.length;
      return ok(all.slice(offset, offset + limit));
    },

    getStats(): KnowledgeStats {
      return {
        totalEntries: entries.size,
        totalWords: wordIndex.size,
        totalTags: tagIndex.size,
        indexSize: wordIndex.size + tagIndex.size,
      };
    },

    gc(olderThanMs: number): KallaxResult<number> {
      const cutoff = Date.now() - olderThanMs;
      let removed = 0;
      for (const [id, entry] of entries) {
        if (entry.updatedAt < cutoff) {
          deindexEntry(entry);
          entries.delete(id);
          removed++;
        }
      }
      logger.info({ removed, cutoff: new Date(cutoff).toISOString() }, 'knowledge base GC completed');
      return ok(removed);
    },

    clear(): void {
      entries.clear();
      wordIndex.clear();
      tagIndex.clear();
      logger.info({}, 'knowledge base cleared');
    },
  };
}

// Default singleton
let defaultKB: KnowledgeBase | null = null;

export function getKnowledgeBase(): KnowledgeBase {
  if (defaultKB === null) {
    defaultKB = createKnowledgeBase();
  }
  return defaultKB;
}
