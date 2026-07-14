/**
 * KALLAX Skills Registry — manages skill definitions and lifecycle.
 */

import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../../types/index.js';
import { KallaxError, KallaxErrorCode } from '../../types/index.js';
import { logger } from '../../utils/logger.js';

export interface SkillDefinition {
  readonly name: string;
  readonly version: string;
  readonly description: string;
  readonly author?: string;
  readonly tags: readonly string[];
  readonly category: string;
  readonly entryPoint: string; // relative path to SKILL.md or main file
  readonly dependencies?: readonly string[];
  readonly capabilities: readonly string[];
  readonly isLoaded: boolean;
  readonly loadedAt?: number;
}

export interface SkillLoader {
  load: (skill: SkillDefinition, basePath: string) => Promise<KallaxResult<void>>;
  unload: (skillName: string) => Promise<KallaxResult<void>>;
  reload: (skillName: string) => Promise<KallaxResult<void>>;
  isLoaded: (skillName: string) => boolean;
  listLoaded: () => string[];
}

export interface SkillInterceptor {
  readonly name: string;
  beforeLoad?: (skill: SkillDefinition) => Promise<KallaxResult<SkillDefinition>>;
  afterLoad?: (skill: SkillDefinition) => Promise<void>;
  beforeUnload?: (skillName: string) => Promise<KallaxResult<void>>;
  onError?: (skillName: string, error: Error) => Promise<void>;
}

export interface SkillsRegistry {
  register: (skill: SkillDefinition) => KallaxResult<void>;
  unregister: (name: string) => KallaxResult<void>;
  get: (name: string) => KallaxResult<SkillDefinition>;
  list: (filter?: { category?: string; tag?: string }) => SkillDefinition[];
  search: (query: string) => SkillDefinition[];
  getLoader: () => SkillLoader;
  addInterceptor: (interceptor: SkillInterceptor) => void;
  removeInterceptor: (name: string) => void;
  getStats: () => SkillStats;
}

export interface SkillStats {
  readonly totalSkills: number;
  readonly loadedSkills: number;
  readonly categories: Record<string, number>;
  readonly tags: Record<string, number>;
}

/**
 * Create a skill loader that reads SKILL.md files and tracks state.
 */
export function createSkillLoader(): SkillLoader {
  const loadedSkills = new Map<string, { definition: SkillDefinition; loadedAt: number }>();

  return {
    load(skill: SkillDefinition): Promise<KallaxResult<void>> {
      if (loadedSkills.has(skill.name)) {
        return ok(undefined); // Already loaded
      }

      loadedSkills.set(skill.name, {
        definition: { ...skill, isLoaded: true, loadedAt: Date.now() },
        loadedAt: Date.now(),
      });

      logger.info({ skillName: skill.name, version: skill.version }, 'skill loaded');
      return ok(undefined);
    },

    unload(skillName: string): Promise<KallaxResult<void>> {
      if (!loadedSkills.has(skillName)) {
        return Promise.resolve(err(new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, `Skill ${skillName} not loaded`)));
      }

      loadedSkills.delete(skillName);
      logger.info({ skillName }, 'skill unloaded');
      return Promise.resolve(ok(undefined));
    },

    reload(skillName: string): Promise<KallaxResult<void>> {
      const entry = loadedSkills.get(skillName);
      if (!entry) {
        return Promise.resolve(err(new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, `Skill ${skillName} not loaded`)));
      }

      const def = entry.definition;
      loadedSkills.set(skillName, {
        definition: { ...def, isLoaded: true, loadedAt: Date.now() },
        loadedAt: Date.now(),
      });

      logger.info({ skillName }, 'skill reloaded');
      return Promise.resolve(ok(undefined));
    },

    isLoaded(skillName: string): boolean {
      return loadedSkills.has(skillName);
    },

    listLoaded(): string[] {
      return Array.from(loadedSkills.keys());
    },
  };
}

// ── Built-in Interceptors ──────────────────────────────────────────────────

export function createLoggingInterceptor(): SkillInterceptor {
  return {
    name: 'logging',
    afterLoad(skill: SkillDefinition): Promise<void> {
      logger.info({ skillName: skill.name, version: skill.version, capabilities: skill.capabilities }, 'skill loaded');
      return Promise.resolve();
    },
    beforeUnload(skillName: string): Promise<KallaxResult<void>> {
      logger.info({ skillName }, 'skill unloading');
      return Promise.resolve(ok(undefined));
    },
  };
}

export function createValidationInterceptor(): SkillInterceptor {
  return {
    name: 'validation',
    beforeLoad(skill: SkillDefinition): Promise<KallaxResult<SkillDefinition>> {
      if (!skill.name || skill.name.trim().length === 0) {
        return Promise.resolve(err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Skill name is required')));
      }
      if (!skill.entryPoint) {
        return Promise.resolve(err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, `Skill ${skill.name} has no entryPoint`)));
      }
      if (skill.capabilities.length === 0) {
        return Promise.resolve(err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, `Skill ${skill.name} has no capabilities`)));
      }
      return Promise.resolve(ok(skill));
    },
  };
}

export function createCachingInterceptor(): SkillInterceptor {
  const cache = new Map<string, SkillDefinition>();
  return {
    name: 'caching',
    beforeLoad(skill: SkillDefinition): Promise<KallaxResult<SkillDefinition>> {
      const cached = cache.get(skill.name);
      if (cached?.version === skill.version) {
        // Return cached version to skip reload
        return Promise.resolve(ok(cached));
      }
      return Promise.resolve(ok(skill));
    },
    afterLoad(skill: SkillDefinition): Promise<void> {
      cache.set(skill.name, skill);
      return Promise.resolve();
    },
  };
}

// ── SkillsRegistry ─────────────────────────────────────────────────────────

export function createSkillsRegistry(loader?: SkillLoader): SkillsRegistry {
  const skills = new Map<string, SkillDefinition>();
  const interceptors: SkillInterceptor[] = [];
  const skillLoader = loader ?? createSkillLoader();

  return {
    register(skill: SkillDefinition): KallaxResult<void> {
      if (skills.has(skill.name)) {
        return err(new KallaxError(
          KallaxErrorCode.INSTANCE_ALREADY_EXISTS,
          `Skill ${skill.name} already registered`,
        ));
      }

      skills.set(skill.name, skill);
      logger.debug({ skillName: skill.name, version: skill.version }, 'skill registered');
      return ok(undefined);
    },

    unregister(name: string): KallaxResult<void> {
      if (!skills.has(name)) {
        return err(new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, `Skill ${name} not found`));
      }
      skills.delete(name);
      logger.debug({ skillName: name }, 'skill unregistered');
      return ok(undefined);
    },

    get(name: string): KallaxResult<SkillDefinition> {
      const skill = skills.get(name);
      if (!skill) {
        return err(new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, `Skill ${name} not found`));
      }
      return ok(skill);
    },

    list(filter?: { category?: string; tag?: string }): SkillDefinition[] {
      let result = Array.from(skills.values());

      if (filter?.category !== undefined && filter.category !== '') {
        result = result.filter((s) => s.category === filter.category);
      }
      if (filter?.tag !== undefined && filter.tag !== '') {
        const tag = filter.tag;
        result = result.filter((s) => s.tags.includes(tag));
      }

      return result.sort((a, b) => a.name.localeCompare(b.name));
    },

    search(query: string): SkillDefinition[] {
      const q = query.toLowerCase();
      return Array.from(skills.values()).filter(
        (s) =>
          s.name.toLowerCase().includes(q) ||
          s.description.toLowerCase().includes(q) ||
          s.tags.some((t) => t.toLowerCase().includes(q)) ||
          s.capabilities.some((c) => c.toLowerCase().includes(q)),
      );
    },

    getLoader(): SkillLoader {
      return skillLoader;
    },

    addInterceptor(interceptor: SkillInterceptor): void {
      const idx = interceptors.findIndex((i) => i.name === interceptor.name);
      if (idx >= 0) {
        interceptors[idx] = interceptor;
      } else {
        interceptors.push(interceptor);
      }
    },

    removeInterceptor(name: string): void {
      const idx = interceptors.findIndex((i) => i.name === name);
      if (idx >= 0) interceptors.splice(idx, 1);
    },

    getStats(): SkillStats {
      const categories: Record<string, number> = {};
      const tags: Record<string, number> = {};
      let loadedCount = 0;

      for (const skill of skills.values()) {
        if (skill.isLoaded) loadedCount++;
        categories[skill.category] = (categories[skill.category] ?? 0) + 1;
        for (const tag of skill.tags) {
          tags[tag] = (tags[tag] ?? 0) + 1;
        }
      }

      return {
        totalSkills: skills.size,
        loadedSkills: loadedCount,
        categories,
        tags,
      };
    },
  };
}

// Default singleton
let defaultRegistry: SkillsRegistry | null = null;

export function getSkillsRegistry(): SkillsRegistry {
  defaultRegistry ??= createSkillsRegistry();
  return defaultRegistry;
}
