/**
 * Schema validation evidence for EPIC-023-A.
 * Runs PersonaSchema against all 7 default persona files.
 *
 * Run: npx tsx node/src/schema/validate-personas.ts
 */

import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { PersonaSchema } from './persona.js';
import { extractFrontmatter, parseFrontmatter } from './frontmatter.js';

const EXPERTS_DIR = '.kallax/experts/default';

const main = (): void => {
  const files = readdirSync(EXPERTS_DIR).filter((f) => f.endsWith('.md')).sort();
  process.stdout.write(`EPIC-023-A persona validation: ${String(files.length)} files\n\n`);

  let pass = 0;
  let fail = 0;
  for (const file of files) {
    const path = join(EXPERTS_DIR, file);
    const content = readFileSync(path, 'utf-8');
    const { fmBlock } = extractFrontmatter(content);
    const parsed = parseFrontmatter(fmBlock);
    const result = PersonaSchema.safeParse(parsed);
    if (result.success) {
      process.stdout.write(`PASS ${file}\n`);
      pass += 1;
    } else {
      process.stdout.write(`FAIL ${file}\n`);
      for (const issue of result.error.issues) {
        const where = issue.path.length > 0 ? issue.path.join('.') : '<root>';
        process.stdout.write(`     ${where}: ${issue.message}\n`);
      }
      fail += 1;
    }
  }

  process.stdout.write(`\nSummary: ${String(pass)}/${String(files.length)} pass\n`);
  process.exit(fail);
};

main();