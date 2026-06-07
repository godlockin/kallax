#!/usr/bin/env node
/**
 * scripts/check-skill-anatomy.ts
 * KALLAX 专属 persona anatomy 校验 (TS 版本)
 * 借 EKET check-skill-anatomy.sh 思路, KALLAX 多 7 项语义校验
 *
 * @ref EPIC-023-A | 替代 .sh 版, 用 tsx 运行
 */

import { readFileSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  validatePersona,
  type PersonaValidationResult,
} from '../node/src/schema/persona.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface CliArgs {
  quiet: boolean;
  files: string[];
}

function parseArgs(argv: string[]): CliArgs {
  const args: CliArgs = { quiet: false, files: [] };
  for (const arg of argv) {
    if (arg === '--quiet' || arg === '-q') {
      args.quiet = true;
    } else if (!arg.startsWith('-')) {
      args.files.push(arg);
    }
  }
  return args;
}

function validateFile(filePath: string, quiet: boolean): { pass: boolean; errors: string[] } {
  const errors: string[] = [];

  try {
    const content = readFileSync(filePath, 'utf-8');
    const result: PersonaValidationResult = validatePersona(content);

    if (!result.valid) {
      errors.push(...result.errors);
    }

    // Additional checks not in Zod schema
    const fmMatch = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
    const fmText = fmMatch?.[1] ?? '';

    // Check worktree_role
    const roleMatch = fmText.match(/^worktree_role:\s*(\w+)/m);
    const role = roleMatch?.[1] ?? '';
    if (!['master', 'conductor', 'performer'].includes(role)) {
      errors.push(`worktree_role invalid: ${role} (must be master|conductor|performer)`);
    }

    // Check review_group
    const groupMatch = fmText.match(/^review_group:\s*(\w+)/m);
    const group = groupMatch?.[1] ?? '';
    if (!['A', 'B', 'AB'].includes(group)) {
      errors.push(`review_group invalid: ${group} (must be A|B|AB)`);
    }

    // Check tickets_served is array
    if (!fmText.includes('tickets_served: []') && !fmText.match(/^tickets_served:\s*\[/m)) {
      errors.push('tickets_served must be a JSON array (empty [] or non-empty [items])');
    }

    // Check id format
    const idMatch = fmText.match(/^id:\s*([^\s]+)/m);
    const id = idMatch?.[1] ?? '';
    if (!/^kallax\.\w+\.\d{3}$/.test(id)) {
      errors.push(`id invalid: ${id} (must match kallax.<role>.<NNN>)`);
    }

  } catch (err) {
    errors.push(`Read error: ${err instanceof Error ? err.message : String(err)}`);
  }

  return { pass: errors.length === 0, errors };
}

function main(argv: string[]): number {
  const args = parseArgs(argv.slice(2));

  if (args.files.length === 0) {
    console.error(`Usage: $0 [--quiet] <file.md> | <dir>/*.md`);
    console.error(`  --quiet, -q    Suppress output, only return exit code`);
    return 2;
  }

  let failCount = 0;
  let total = 0;

  for (const file of args.files) {
    total++;
    const { pass, errors } = validateFile(file, args.quiet);

    if (!pass) {
      failCount++;
      if (!args.quiet) {
        console.log(`❌ ${file}`);
        for (const err of errors) {
          console.log(`   - ${err}`);
        }
      }
    } else if (!args.quiet) {
      console.log(`✅ ${file}`);
    }
  }

  if (!args.quiet) {
    console.log('');
    console.log(`Summary: ${total - failCount}/${total} pass`);
  }

  return failCount;
}

export { parseArgs, validateFile };

// Run if executed directly
const exitCode = main(process.argv);
process.exit(exitCode);