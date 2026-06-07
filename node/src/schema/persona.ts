/**
 * KALLAX Persona Schema (Layer 2 - Type Safety)
 * Validates 7 expert persona frontmatter via Zod runtime type checking
 * @ref EPIC-023-A | 6h | zod schema for 7 expert persona
 */

import { z } from 'zod';

// === Core Enums ===

export const TierEnum = z.enum(['default']);
export type Tier = z.infer<typeof TierEnum>;

export const WorktreeRoleEnum = z.enum(['master', 'conductor', 'performer']);
export type WorktreeRole = z.infer<typeof WorktreeRoleEnum>;

export const ReviewGroupEnum = z.enum(['A', 'B', 'AB']);
export type ReviewGroup = z.infer<typeof ReviewGroupEnum>;

// === Regex Patterns ===

const ID_PATTERN = /^kallax\.\w+\.\d{3}$/;
const SEMVER_PATTERN = /^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

// === Frontmatter Schema ===

export const PersonaFrontmatterSchema = z.object({
  id: z.string().regex(ID_PATTERN, 'id must match kallax.<role>.<NNN>'),
  name: z.string().min(1, 'name is required'),
  tier: TierEnum,
  worktree_role: WorktreeRoleEnum,
  review_group: ReviewGroupEnum,
  phase: z.number().int().min(1).max(5),
  rationalizations_count: z.number().int().min(0),
  version: z.string().regex(SEMVER_PATTERN, 'version must be semver'),
  last_reviewed: z.string().regex(DATE_PATTERN, 'last_reviewed must be YYYY-MM-DD'),
  tickets_served: z.array(z.string()),
});

export type PersonaFrontmatter = z.infer<typeof PersonaFrontmatterSchema>;

// === Output Format Section Schema ===

export const OutputFormatSectionSchema = z.object({
  has_highlights: z.boolean(),
  has_risks: z.boolean(),
  has_recommendations: z.boolean(),
  has_blocker: z.boolean(),
});

export type OutputFormatSection = z.infer<typeof OutputFormatSectionSchema>;

// === Full Persona Schema (with body sections) ===

export const PersonaBodySectionSchema = z.object({
  mantras: z.boolean(),
  personality: z.boolean(),
  background: z.boolean(),
  thinking_framework: z.boolean(),
  analysis_focus: z.boolean(),
  common_rationalizations: z.boolean(),
  when_to_use: z.boolean(),
  when_not_to_use: z.boolean(),
  process: z.boolean(),
  red_flags: z.boolean(),
  verification: z.boolean(),
  fact_forcing_compliance: z.boolean(),
  has_l1: z.boolean(),
  has_l2: z.boolean(),
  has_l3: z.boolean(),
  has_l4: z.boolean(),
});

export type PersonaBodySection = z.infer<typeof PersonaBodySectionSchema>;

// === Validation Result ===

export interface PersonaValidationResult {
  valid: boolean;
  frontmatter: PersonaFrontmatter | null;
  output_format: OutputFormatSection | null;
  body_sections: PersonaBodySection | null;
  errors: string[];
}

// === Schema Validator ===

/**
 * Parse frontmatter from markdown content
 */
export function parseFrontmatter(content: string): Record<string, unknown> | null {
  const fmMatch = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!fmMatch) return null;

  const fmText = fmMatch[1];
  const result: Record<string, unknown> = {};

  for (const line of fmText.split('\n')) {
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) continue;

    const key = line.slice(0, colonIdx).trim();
    let value: unknown = line.slice(colonIdx + 1).trim();

    // Parse arrays
    if (value === '[]') {
      value = [];
    } else if (typeof value === 'string' && value.startsWith('[')) {
      // Simple string array parsing for YAML
      const arrayContent = value.slice(1, value.indexOf(']'));
      value = arrayContent ? arrayContent.split(',').map(s => s.trim()) : [];
    }

    // Parse numbers
    if (typeof value === 'string' && /^\d+$/.test(value)) {
      value = parseInt(value, 10);
    }

    result[key] = value;
  }

  return result;
}

/**
 * Check if body has required sections
 */
export function checkBodySections(content: string): PersonaBodySection {
  const sectionPattern = /^## (.+)$/m;
  const sections = new Set<string>();
  let match;

  const regex = new RegExp(sectionPattern.source, 'gm');
  while ((match = regex.exec(content)) !== null) {
    sections.add(match[1]);
  }

  return {
    mantras: sections.has('mantras'),
    personality: sections.has('personality'),
    background: sections.has('background'),
    thinking_framework: sections.has('thinking_framework'),
    analysis_focus: sections.has('analysis_focus'),
    common_rationalizations: sections.has('Common Rationalizations'),
    when_to_use: sections.has('When to Use'),
    when_not_to_use: sections.has('When NOT to Use'),
    process: sections.has('Process'),
    red_flags: sections.has('Red Flags'),
    verification: sections.has('Verification'),
    fact_forcing_compliance: sections.has('Fact-Forcing Compliance'),
    has_l1: sections.has('L1_存在性') || content.includes('L1_'),
    has_l2: sections.has('L2_实质性') || content.includes('L2_'),
    has_l3: sections.has('L3_接线正确') || content.includes('L3_'),
    has_l4: sections.has('L4_数据流动') || content.includes('L4_'),
  };
}

/**
 * Check output_format sections in frontmatter
 * Handles YAML multi-line strings with indented ## headers
 */
export function checkOutputFormat(fmText: string): OutputFormatSection {
  // Look for section headers (## optional whitespace, then keyword)
  // In YAML multi-line | format, headers are indented with spaces
  return {
    has_highlights: /##\s*(亮点|Highlights?)/.test(fmText),
    has_risks: /##\s*(风险|Risks?)/.test(fmText),
    has_recommendations: /##\s*(建议|Recommendations?)/.test(fmText),
    has_blocker: /##\s*(P0 阻塞条件|Blocker)/.test(fmText),
  };
}

/**
 * Validate a persona markdown file
 */
export function validatePersona(content: string): PersonaValidationResult {
  const errors: string[] = [];

  // Parse frontmatter
  const fm = parseFrontmatter(content);
  if (!fm) {
    return { valid: false, frontmatter: null, output_format: null, body_sections: null, errors: ['No frontmatter found'] };
  }

  // Validate frontmatter
  const fmResult = PersonaFrontmatterSchema.safeParse(fm);
  if (!fmResult.success) {
    for (const err of fmResult.error.errors) {
      errors.push(`frontmatter.${err.path.join('.')}: ${err.message}`);
    }
  }

  // Check body sections
  const bodySections = checkBodySections(content);
  const missingSections: string[] = [];
  if (!bodySections.mantras) missingSections.push('mantras');
  if (!bodySections.personality) missingSections.push('personality');
  if (!bodySections.background) missingSections.push('background');
  if (!bodySections.thinking_framework) missingSections.push('thinking_framework');
  if (!bodySections.analysis_focus) missingSections.push('analysis_focus');
  if (!bodySections.common_rationalizations) missingSections.push('Common Rationalizations');
  if (!bodySections.when_to_use) missingSections.push('When to Use');
  if (!bodySections.when_not_to_use) missingSections.push('When NOT to Use');
  if (!bodySections.process) missingSections.push('Process');
  if (!bodySections.red_flags) missingSections.push('Red Flags');
  if (!bodySections.verification) missingSections.push('Verification');
  if (!bodySections.fact_forcing_compliance) missingSections.push('Fact-Forcing Compliance');

  if (missingSections.length > 0) {
    errors.push(`Missing body sections: ${missingSections.join(', ')}`);
  }

  // Check L1-L4
  if (!bodySections.has_l1 || !bodySections.has_l2 || !bodySections.has_l3 || !bodySections.has_l4) {
    errors.push('Fact-Forcing Compliance missing L1/L2/L3/L4 levels');
  }

  // Check output_format in frontmatter
  const fmMatch = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  const fmText = fmMatch ? fmMatch[1] : '';
  const outputFormat = checkOutputFormat(fmText);
  if (!outputFormat.has_highlights || !outputFormat.has_risks || !outputFormat.has_recommendations || !outputFormat.has_blocker) {
    errors.push('output_format missing required sections (亮点/风险/建议/P0 阻塞条件)');
  }

  // Check rationalizations_count sync
  const declaredCount = fm.rationalizations_count as number | undefined;
  if (typeof declaredCount === 'number' && declaredCount > 0) {
    const rationalizationsSection = content.match(/^## Common Rationalizations$/m);
    if (rationalizationsSection) {
      // Count bullets (multiline mode needed for ^ to work across lines)
      const bulletPattern = /^- "/gm;
      const bullets = (content.slice(rationalizationsSection.index!).match(bulletPattern) || []).length;
      // Count table rows
      const tablePattern = /^\|.*`.*/gm;
      const tableRows = (content.slice(rationalizationsSection.index!).match(tablePattern) || []).length;
      const actualCount = bullets > 0 ? bullets : tableRows;
      if (declaredCount !== actualCount) {
        errors.push(`rationalizations_count mismatch: declared=${declaredCount} actual=${actualCount}`);
      }
    }
  }

  return {
    valid: errors.length === 0,
    frontmatter: fmResult.success ? fmResult.data : null,
    output_format: outputFormat,
    body_sections: bodySections,
    errors,
  };
}

// === Exports ===

export const PersonaSchema = PersonaFrontmatterSchema;
export default PersonaSchema;