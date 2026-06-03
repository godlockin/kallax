/**
 * KALLAX Skills System — barrel export.
 */

export type {
  SkillDefinition, SkillLoader, SkillInterceptor, SkillsRegistry, SkillStats,
} from './registry.js';

export {
  createSkillLoader, createSkillsRegistry, getSkillsRegistry,
  createLoggingInterceptor, createValidationInterceptor, createCachingInterceptor,
} from './registry.js';
