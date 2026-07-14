/**
 * Persona Schema Unit Tests (EPIC-023-A)
 *
 * Validates the 9-field PersonaSchema against canonical and adversarial inputs.
 * Run: npx vitest run tests/persona-schema.test.ts
 */

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { PersonaSchema } from '../src/schema/persona.js';
import { extractFrontmatter, parseFrontmatter } from '../src/schema/frontmatter.js';

const EXPERTS_DIR = resolve(process.cwd(), '..', '.kallax/experts/default');

const loadCanonicalPersona = (): Readonly<Record<string, unknown>> => {
  const content = readFileSync(join(EXPERTS_DIR, 'architect.md'), 'utf-8');
  const { fmBlock } = extractFrontmatter(content);
  return parseFrontmatter(fmBlock);
};

const VALID_BASE = {
  id: 'kallax.architect.001',
  tier: 'default' as const,
  worktree_role: 'conductor' as const,
  review_group: 'A' as const,
  phase: 1,
  rationalizations_count: 8,
  version: '1.0.0',
  last_reviewed: '2026-06-11',
  tickets_served: ['EPIC-030'],
};

describe('PersonaSchema', () => {
  describe('9 required fields', () => {
    it('accepts canonical valid input', () => {
      const result = PersonaSchema.safeParse(VALID_BASE);
      expect(result.success).toBe(true);
    });

    it('rejects missing id', () => {
      const { id: _id, ...rest } = VALID_BASE;
      void _id;
      const result = PersonaSchema.safeParse(rest);
      expect(result.success).toBe(false);
    });

    it('rejects missing tier', () => {
      const { tier: _tier, ...rest } = VALID_BASE;
      void _tier;
      const result = PersonaSchema.safeParse(rest);
      expect(result.success).toBe(false);
    });
  });

  describe('id regex', () => {
    it('accepts kallax.<role>.NNN', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, id: 'kallax.backend.042' });
      expect(result.success).toBe(true);
    });

    it('rejects id without numeric suffix', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, id: 'kallax.backend' });
      expect(result.success).toBe(false);
    });

    it('accepts id with mixed-case role (\\w+ allows A-Z per AC spec)', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, id: 'kallax.Backend.001' });
      expect(result.success).toBe(true);
    });

    it('rejects id with non-3-digit suffix', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, id: 'kallax.backend.1' });
      expect(result.success).toBe(false);
    });
  });

  describe('tier enum', () => {
    it('accepts "default"', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, tier: 'default' });
      expect(result.success).toBe(true);
    });

    it('rejects "optional"', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, tier: 'optional' });
      expect(result.success).toBe(false);
    });
  });

  describe('worktree_role enum', () => {
    it.each(['master', 'conductor', 'performer'] as const)('accepts "%s"', (role) => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, worktree_role: role });
      expect(result.success).toBe(true);
    });

    it('rejects "auditor" (not in canonical enum)', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, worktree_role: 'auditor' });
      expect(result.success).toBe(false);
    });
  });

  describe('review_group enum', () => {
    it.each(['A', 'B', 'AB'] as const)('accepts "%s"', (group) => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, review_group: group });
      expect(result.success).toBe(true);
    });

    it('rejects "C"', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, review_group: 'C' });
      expect(result.success).toBe(false);
    });
  });

  describe('version semver', () => {
    it('accepts X.Y.Z', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, version: '1.2.3' });
      expect(result.success).toBe(true);
    });

    it('accepts X.Y.Z-pre-release', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, version: '1.2.3-rc.1' });
      expect(result.success).toBe(true);
    });

    it('accepts X.Y.Z+build', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, version: '1.2.3+build.42' });
      expect(result.success).toBe(true);
    });

    it('rejects non-semver', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, version: 'v1.2.3' });
      expect(result.success).toBe(false);
    });
  });

  describe('phase and rationalizations_count', () => {
    it('accepts phase 1-3', () => {
      for (const phase of [1, 2, 3]) {
        const result = PersonaSchema.safeParse({ ...VALID_BASE, phase });
        expect(result.success).toBe(true);
      }
    });

    it('rejects phase 0', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, phase: 0 });
      expect(result.success).toBe(false);
    });

    it('rejects phase 4', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, phase: 4 });
      expect(result.success).toBe(false);
    });

    it('rejects negative rationalizations_count', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, rationalizations_count: -1 });
      expect(result.success).toBe(false);
    });
  });

  describe('last_reviewed ISO date', () => {
    it('accepts YYYY-MM-DD', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, last_reviewed: '2026-06-11' });
      expect(result.success).toBe(true);
    });

    it('rejects non-date strings', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, last_reviewed: '06/11/2026' });
      expect(result.success).toBe(false);
    });
  });

  describe('tickets_served array', () => {
    it('accepts empty array', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, tickets_served: [] });
      expect(result.success).toBe(true);
    });

    it('accepts non-empty array', () => {
      const result = PersonaSchema.safeParse({ ...VALID_BASE, tickets_served: ['EPIC-030', 'EPIC-031'] });
      expect(result.success).toBe(true);
    });
  });

  describe('passthrough for non-9 fields', () => {
    it('allows name, trigger, output_format', () => {
      const result = PersonaSchema.safeParse({
        ...VALID_BASE,
        name: 'Architect',
        trigger: '架构,边界',
        output_format: '## 亮点\nfoo',
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Architect');
      }
    });
  });

  describe('integration: canonical architect.md parses', () => {
    it('loads and validates .kallax/experts/default/architect.md', () => {
      const fm = loadCanonicalPersona();
      const result = PersonaSchema.safeParse(fm);
      expect(result.success).toBe(true);
    });
  });

  describe('integration: 7 default persona files', () => {
    const files = readdirSync(EXPERTS_DIR).filter((f) => f.endsWith('.md')).sort();

    it.each(files)('%s parses', (file) => {
      const content = readFileSync(join(EXPERTS_DIR, file), 'utf-8');
      const { fmBlock } = extractFrontmatter(content);
      const parsed = parseFrontmatter(fmBlock);
      const result = PersonaSchema.safeParse(parsed);
      expect(result.success).toBe(true);
    });
  });
});