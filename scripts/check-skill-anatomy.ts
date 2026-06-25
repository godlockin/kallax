#!/usr/bin/env node
/**
 * scripts/check-skill-anatomy.ts
 *
 * TypeScript port of scripts/check-skill-anatomy.sh.
 *
 * Validates KALLAX expert persona files (.kallax/experts/default/*.md) against:
 *   - PersonaSchema (Zod, runtime strong types for 9 frontmatter fields)
 *   - Structural checks (6 + 5 body sections, output_format subsections,
 *     Fact-Forcing 4 levels, rationalizations_count sync)
 *
 * Borrowed from EKET check-skill-anatomy.sh (Layer 2 + Layer 3 schema + structure).
 *
 * Usage:
 *   tsx scripts/check-skill-anatomy.ts [--quiet] <file.md> ...
 *
 * Exit code: 0 = all pass, N = number of failing files.
 */

import { readFileSync } from 'node:fs';
import { PersonaSchema } from '../node/src/schema/persona.js';
import { extractFrontmatter, parseFrontmatter, sliceSection } from '../node/src/schema/frontmatter.js';

const REQUIRED_BODY_SECTIONS = [
  'mantras',
  'personality',
  'background',
  'thinking_framework',
  'analysis_focus',
  'Common Rationalizations',
] as const;

const REQUIRED_EXTRA_SECTIONS = [
  'When to Use',
  'When NOT to Use',
  'Process',
  'Red Flags',
  'Verification',
] as const;

const OUTPUT_FORMAT_HEADERS = ['亮点', '风险', '建议', 'P0 阻塞条件'] as const;

const FACT_FORCING_LEVELS = ['L1_', 'L2_', 'L3_', 'L4_'] as const;

const SEMVER_REGEX = /^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$/;
const ID_REGEX = /^kallax\.[a-z]+\.[0-9]{3}$/;

const escapeRegex = (s: string): string => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

interface CheckResult {
  readonly file: string;
  readonly errors: readonly string[];
}

const checkFile = (filePath: string): CheckResult => {
  const errors: string[] = [];
  const content = readFileSync(filePath, 'utf-8');
  const { fmBlock, body } = extractFrontmatter(content);

  const fm = parseFrontmatter(fmBlock);
  const parsed = PersonaSchema.safeParse(fm);
  if (!parsed.success) {
    for (const issue of parsed.error.issues) {
      const path = issue.path.length > 0 ? issue.path.join('.') : '<root>';
      errors.push(`schema[${path}]: ${issue.message}`);
    }
  }

  for (const section of REQUIRED_BODY_SECTIONS) {
    const header = new RegExp(`^## ${escapeRegex(section)}$`, 'm');
    if (!header.test(body)) errors.push(`Missing section: ## ${section}`);
  }

  for (const section of REQUIRED_EXTRA_SECTIONS) {
    const header = new RegExp(`^## ${escapeRegex(section)}$`, 'm');
    if (!header.test(body)) errors.push(`Missing section: ## ${section}`);
  }

  if (parsed.success) {
    const declared = parsed.data.rationalizations_count;
    const rationaleSection = sliceSection(body, /^## Common Rationalizations$/);
    if (rationaleSection !== null) {
      const actualBullets = rationaleSection.split('\n').filter((l) => /^- "/.test(l)).length;
      const actualTable = rationaleSection.split('\n').filter((l) => /^\|.*`.*`/.test(l)).length;
      const actual = actualBullets > 0 ? actualBullets : actualTable;
      if (actual !== declared) {
        errors.push(`rationalizations_count mismatch: declared=${declared} actual=${actual}`);
      }
    }
  }

  const hasAllOutputSections = OUTPUT_FORMAT_HEADERS.every((h) => new RegExp(`## ${h}`).test(fmBlock));
  if (!hasAllOutputSections) {
    errors.push('output_format missing 4 sections (亮点/风险/建议/P0 阻塞条件)');
  }

  const factBlock = sliceSection(body, /^## Fact-Forcing Compliance/);
  if (factBlock === null) {
    errors.push('Fact-Forcing Compliance section missing');
  } else {
    const hasAllLevels = FACT_FORCING_LEVELS.every((level) => factBlock.includes(level));
    if (!hasAllLevels) {
      errors.push('Fact-Forcing Compliance missing 4 distinct levels (L1_/L2_/L3_/L4_)');
    }
  }

  const id = typeof fm.id === 'string' ? fm.id : '';
  if (!ID_REGEX.test(id)) {
    errors.push(`id invalid: ${id} (must match kallax.<role>.NNN)`);
  }

  const version = typeof fm.version === 'string' ? fm.version : '';
  if (!SEMVER_REGEX.test(version)) {
    errors.push(`version not semver: ${version} (expected X.Y.Z or X.Y.Z-pre or X.Y.Z+build)`);
  }

  return { file: filePath, errors };
};

const main = (): void => {
  const args = process.argv.slice(2);
  let quiet = false;
  const files: string[] = [];
  for (const arg of args) {
    if (arg === '--quiet') quiet = true;
    else files.push(arg);
  }

  if (files.length === 0) {
    process.stderr.write('Usage: tsx scripts/check-skill-anatomy.ts [--quiet] <file.md> ...\n');
    process.exit(2);
  }

  let failCount = 0;
  const results: CheckResult[] = files.map(checkFile);
  for (const result of results) {
    if (result.errors.length > 0) {
      failCount += 1;
      if (!quiet) {
        process.stdout.write(`❌ ${result.file}\n`);
        for (const err of result.errors) process.stdout.write(`   - ${err}\n`);
      }
    } else if (!quiet) {
      process.stdout.write(`✅ ${result.file}\n`);
    }
  }

  if (!quiet) {
    process.stdout.write(`\nSummary: ${results.length - failCount}/${results.length} pass\n`);
  }
  process.exit(failCount);
};

main();