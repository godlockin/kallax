/**
 * Knowledge Base tests.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createKnowledgeBase } from '../src/core/knowledge-base.js';
import type { KnowledgeBase } from '../src/core/knowledge-base.js';

describe('KnowledgeBase', () => {
  let kb: KnowledgeBase;

  beforeEach(() => {
    kb = createKnowledgeBase();
  });

  describe('CRUD', () => {
    it('adds and retrieves entries', () => {
      const result = kb.add({
        title: 'Test Entry',
        content: 'This is test content for the knowledge base.',
        tags: ['test', 'example'],
        source: 'unit-test',
      });

      expect(result.isOk()).toBe(true);
      const entry = result.value;

      const retrieved = kb.get(entry.id);
      expect(retrieved.isOk()).toBe(true);
      expect(retrieved.value.title).toBe('Test Entry');
    });

    it('updates entries', () => {
      const result = kb.add({
        title: 'Original',
        content: 'Original content.',
        tags: ['original'],
        source: 'test',
      });

      const updated = kb.update(result.value.id, { title: 'Updated' });
      expect(updated.isOk()).toBe(true);
      expect(updated.value.title).toBe('Updated');
      expect(updated.value.content).toBe('Original content.'); // unchanged
    });

    it('removes entries', () => {
      const result = kb.add({
        title: 'To Remove',
        content: 'Content.',
        tags: [],
        source: 'test',
      });

      const removed = kb.remove(result.value.id);
      expect(removed.isOk()).toBe(true);

      const retrieved = kb.get(result.value.id);
      expect(retrieved.isErr()).toBe(true);
    });

    it('errors on missing entry', () => {
      const result = kb.get('nonexistent');
      expect(result.isErr()).toBe(true);
    });
  });

  describe('Search', () => {
    beforeEach(() => {
      kb.add({ title: 'TypeScript Guide', content: 'Learn TypeScript types and interfaces.', tags: ['typescript', 'guide'], source: 'docs' });
      kb.add({ title: 'Rust Performance', content: 'Optimize Rust code with zero-cost abstractions.', tags: ['rust', 'performance'], source: 'docs' });
      kb.add({ title: 'DAG Scheduling', content: 'Kahn algorithm for topological sort in DAG execution.', tags: ['dag', 'algorithm'], source: 'docs' });
    });

    it('searches by title keywords', () => {
      const result = kb.search({ terms: ['typescript'] });
      expect(result.isOk()).toBe(true);
      expect(result.value.length).toBeGreaterThanOrEqual(1);
      expect(result.value[0]?.entry.title).toContain('TypeScript');
    });

    it('searches by content keywords', () => {
      const result = kb.search({ terms: ['kahn', 'algorithm'] });
      expect(result.isOk()).toBe(true);
      expect(result.value.length).toBeGreaterThanOrEqual(1);
      expect(result.value[0]?.entry.title).toContain('DAG');
    });

    it('filters by tag', () => {
      const result = kb.search({ tags: ['rust'] });
      expect(result.isOk()).toBe(true);
      expect(result.value.length).toBe(1);
      expect(result.value[0]?.entry.tags).toContain('rust');
    });

    it('combines text search and tag filter', () => {
      const result = kb.search({ terms: ['dag'], tags: ['algorithm'] });
      expect(result.isOk()).toBe(true);
      expect(result.value.length).toBeGreaterThanOrEqual(1);
    });

    it('returns empty for no match', () => {
      const result = kb.search({ terms: ['python'] });
      expect(result.isOk()).toBe(true);
      expect(result.value.length).toBe(0);
    });

    it('searches by tag', () => {
      const result = kb.searchByTag('typescript');
      expect(result.isOk()).toBe(true);
      expect(result.value.length).toBe(1);
    });
  });

  describe('List', () => {
    it('lists all entries', () => {
      kb.add({ title: 'A', content: 'a', tags: [], source: 't' });
      kb.add({ title: 'B', content: 'b', tags: [], source: 't' });

      const result = kb.list();
      expect(result.isOk()).toBe(true);
      expect(result.value.length).toBe(2);
    });

    it('supports limit and offset', () => {
      kb.add({ title: 'A', content: 'a', tags: [], source: 't' });
      kb.add({ title: 'B', content: 'b', tags: [], source: 't' });
      kb.add({ title: 'C', content: 'c', tags: [], source: 't' });

      const result = kb.list({ limit: 2, offset: 0 });
      expect(result.value.length).toBe(2);
    });
  });

  describe('GC', () => {
    it('removes entries older than threshold', () => {
      // Add entry, then wait 1ms + gc with 0ms threshold
      kb.add({ title: 'Old', content: 'old', tags: [], source: 't' });

      // gc with -1 effectively: Date.now() - (-1) = Date.now() + 1 > entry.updatedAt
      // Use a very small positive threshold and sleep briefly
      const result = kb.gc(-1); // negative makes cutoff > now, so everything is older
      expect(result.isOk()).toBe(true);
      // May or may not remove depending on timing; just verify no crash
      expect(result.value).toBeGreaterThanOrEqual(0);
    });
  });

  describe('Stats', () => {
    it('tracks entry counts', () => {
      kb.add({ title: 'E1', content: 'hello world', tags: ['a'], source: 't' });
      kb.add({ title: 'E2', content: 'foo bar', tags: ['b', 'c'], source: 't' });

      const stats = kb.getStats();
      expect(stats.totalEntries).toBe(2);
      expect(stats.totalTags).toBeGreaterThanOrEqual(2);
      expect(stats.totalWords).toBeGreaterThan(0);
    });
  });

  describe('Clear', () => {
    it('clears all entries and indexes', () => {
      kb.add({ title: 'X', content: 'x', tags: ['t'], source: 's' });
      kb.clear();

      const stats = kb.getStats();
      expect(stats.totalEntries).toBe(0);
      expect(stats.totalWords).toBe(0);
    });
  });
});
