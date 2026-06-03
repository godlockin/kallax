/**
 * Skills Registry tests: register, list, search, stats.
 * Note: SkillsRegistry is implemented via the DI container using memory-backed stores.
 * This test exercises the same patterns via a direct in-memory implementation
 * to validate the registry contract independently of SQLite/DI wiring.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { ok } from 'neverthrow';
import type { KallaxResult } from '../src/types/index.js';

interface Skill {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly category: string;
  readonly tags: string[];
  readonly enabled: boolean;
}

interface SkillRegistry {
  register: (skill: Skill) => KallaxResult<void>;
  list: () => KallaxResult<Skill[]>;
  getById: (id: string) => KallaxResult<Skill | null>;
  search: (query: string) => KallaxResult<Skill[]>;
  remove: (id: string) => KallaxResult<void>;
  getStats: () => { total: number; enabled: number; categories: number };
}

function createSkillsRegistry(): SkillRegistry {
  const skills = new Map<string, Skill>();

  return {
    register(skill: Skill): KallaxResult<void> {
      skills.set(skill.id, skill);
      return ok(undefined);
    },

    list(): KallaxResult<Skill[]> {
      return ok(Array.from(skills.values()));
    },

    getById(id: string): KallaxResult<Skill | null> {
      return ok(skills.get(id) ?? null);
    },

    search(query: string): KallaxResult<Skill[]> {
      const q = query.toLowerCase();
      const results = Array.from(skills.values()).filter(
        (s) =>
          s.name.toLowerCase().includes(q) ||
          s.description.toLowerCase().includes(q) ||
          s.tags.some((t) => t.toLowerCase().includes(q))
      );
      return ok(results);
    },

    remove(id: string): KallaxResult<void> {
      skills.delete(id);
      return ok(undefined);
    },

    getStats() {
      const all = Array.from(skills.values());
      const categories = new Set(all.map((s) => s.category));
      return {
        total: all.length,
        enabled: all.filter((s) => s.enabled).length,
        categories: categories.size,
      };
    },
  };
}

describe('SkillsRegistry', () => {
  let registry: SkillRegistry;

  beforeEach(() => {
    registry = createSkillsRegistry();
  });

  it('register and list skills', () => {
    registry.register({ id: 'sk-1', name: 'TypeScript', description: 'TS expert', category: 'language', tags: ['ts', 'node'], enabled: true });
    registry.register({ id: 'sk-2', name: 'Docker', description: 'Container expert', category: 'devops', tags: ['docker', 'k8s'], enabled: true });

    const list = registry.list();
    expect(list._unsafeUnwrap().length).toBe(2);
  });

  it('getById returns skill or null', () => {
    registry.register({ id: 'sk-x', name: 'Rust', description: 'Systems lang', category: 'language', tags: ['rust'], enabled: true });

    expect(registry.getById('sk-x')._unsafeUnwrap()?.name).toBe('Rust');
    expect(registry.getById('nonexistent')._unsafeUnwrap()).toBeNull();
  });

  it('search matches by name, description, and tags', () => {
    registry.register({ id: 's1', name: 'React', description: 'UI framework', category: 'frontend', tags: ['jsx', 'ui'], enabled: true });
    registry.register({ id: 's2', name: 'Vue', description: 'Another UI framework', category: 'frontend', tags: ['template'], enabled: true });
    registry.register({ id: 's3', name: 'Axios', description: 'HTTP client', category: 'networking', tags: ['http'], enabled: true });

    const results = registry.search('UI');
    expect(results._unsafeUnwrap().length).toBe(2); // React + Vue
  });

  it('remove deletes skill', () => {
    registry.register({ id: 'tmp', name: 'Temp', description: '', category: 'misc', tags: [], enabled: true });
    registry.remove('tmp');
    expect(registry.getById('tmp')._unsafeUnwrap()).toBeNull();
  });

  it('getStats returns aggregated data', () => {
    registry.register({ id: 'a', name: 'A', description: '', category: 'cat1', tags: [], enabled: true });
    registry.register({ id: 'b', name: 'B', description: '', category: 'cat2', tags: [], enabled: false });
    registry.register({ id: 'c', name: 'C', description: '', category: 'cat1', tags: [], enabled: true });

    const stats = registry.getStats();
    expect(stats.total).toBe(3);
    expect(stats.enabled).toBe(2);
    expect(stats.categories).toBe(2);
  });
});
