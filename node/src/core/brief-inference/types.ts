/**
 * KALLAX Brief Inference — Types + Parse + Validate + Serialize
 *
 * EPIC-030-I: Forces Performer to articulate task understanding BEFORE claim.
 * Performer §5.1 borrowed methodology (eket SLAVER-RULES.md §2.5).
 *
 * 4-section format (single line, separated by ` | `):
 *   📋 任务理解: [任务类型] | [核心目标] | [技术方案] | [风险点]
 *   e.g.       📋 任务理解: backend | 修复 N+1 query | 加 eager-load + 索引 | 索引迁移回滚
 *
 * Why ( + 诚实修正 plan):
 *   - "": Performers who claim without understanding produce cargo-cult code
 *     (1 ticket 1 subagent 串行 treats this as a hard gate, not a soft hint).
 *   - "诚实修正": Surface hidden misunderstanding early — better to reject the
 *     claim (exit 1) than ship "should work" stubs.
 *
 * Constants exported here are shared with quality.ts (MIN_FIELD_LENGTH,
 * BRIEF_SECTION_COUNT used in scoring). Keep this file dependency-free within
 * brief-inference/ — other sub-files import from here, never the reverse.
 */

import { Result, ok, err } from 'neverthrow';
import { z } from 'zod';

// ============================================================================
// Constants (Rule 4: no magic numbers — name all of them)
// ============================================================================

export const BRIEF_SECTION_COUNT = 4;
export const BRIEF_SECTION_SEPARATOR = ' | ';
export const BRIEF_PREFIX = '📋 任务理解:';
export const MIN_FIELD_LENGTH = 2;

// ============================================================================
// Types
// ============================================================================

export interface BriefInference {
  readonly taskType: string;
  readonly coreGoal: string;
  readonly technicalApproach: string;
  readonly risks: string;
}

export type BriefInferenceError =
  | { readonly code: 'BRIEF_INFERENCE_MISSING'; readonly message: string }
  | { readonly code: 'BRIEF_INFERENCE_MALFORMED'; readonly message: string }
  | { readonly code: 'BRIEF_INFERENCE_EMPTY_SECTION'; readonly message: string; readonly section: string }
  | { readonly code: 'TICKET_FILE_READ_FAILED'; readonly message: string; readonly path: string }
  | { readonly code: 'TICKET_FILE_WRITE_FAILED'; readonly message: string; readonly path: string }
  | { readonly code: 'TICKET_JSON_INVALID'; readonly message: string; readonly path: string };

const BriefInferenceSchema = z.object({
  taskType: z.string().min(MIN_FIELD_LENGTH),
  coreGoal: z.string().min(MIN_FIELD_LENGTH),
  technicalApproach: z.string().min(MIN_FIELD_LENGTH),
  risks: z.string().min(MIN_FIELD_LENGTH),
});

// ============================================================================
// Pure Functions
// ============================================================================

export function parseBrief(input: string): Result<BriefInference, BriefInferenceError> {
  if (!input || input.trim().length === 0) {
    return err({
      code: 'BRIEF_INFERENCE_MALFORMED',
      message: 'brief input is empty',
    });
  }

  const stripped = input.startsWith(BRIEF_PREFIX)
    ? input.slice(BRIEF_PREFIX.length).trim()
    : input.trim();

  const sections = stripped.split(BRIEF_SECTION_SEPARATOR);
  if (sections.length !== BRIEF_SECTION_COUNT) {
    return err({
      code: 'BRIEF_INFERENCE_MALFORMED',
      message: `expected ${String(BRIEF_SECTION_COUNT)} sections separated by "${BRIEF_SECTION_SEPARATOR}", got ${String(sections.length)}`,
    });
  }

  const [taskType, coreGoal, technicalApproach, risks] = sections.map((s) => s.trim());

  if (
    taskType === undefined ||
    coreGoal === undefined ||
    technicalApproach === undefined ||
    risks === undefined
  ) {
    return err({
      code: 'BRIEF_INFERENCE_MALFORMED',
      message: 'section array has undefined entries',
    });
  }

  const emptySection = findEmptySection({ taskType, coreGoal, technicalApproach, risks });
  if (emptySection !== null) {
    return err({
      code: 'BRIEF_INFERENCE_EMPTY_SECTION',
      message: `section "${emptySection}" is empty or below min length ${String(MIN_FIELD_LENGTH)}`,
      section: emptySection,
    });
  }

  const brief: BriefInference = { taskType, coreGoal, technicalApproach, risks };
  const validation = BriefInferenceSchema.safeParse(brief);
  if (!validation.success) {
    return err({
      code: 'BRIEF_INFERENCE_MALFORMED',
      message: `zod validation failed: ${validation.error.message}`,
    });
  }

  return ok(brief);
}

export function validateBrief(brief: BriefInference): Result<void, BriefInferenceError> {
  const validation = BriefInferenceSchema.safeParse(brief);
  if (!validation.success) {
    return err({
      code: 'BRIEF_INFERENCE_MALFORMED',
      message: `zod validation failed: ${validation.error.message}`,
    });
  }

  const emptySection = findEmptySection(brief);
  if (emptySection !== null) {
    return err({
      code: 'BRIEF_INFERENCE_EMPTY_SECTION',
      message: `section "${emptySection}" is empty`,
      section: emptySection,
    });
  }

  return ok(undefined);
}

export function serializeBrief(brief: BriefInference): string {
  return `${BRIEF_PREFIX} ${brief.taskType}${BRIEF_SECTION_SEPARATOR}${brief.coreGoal}${BRIEF_SECTION_SEPARATOR}${brief.technicalApproach}${BRIEF_SECTION_SEPARATOR}${brief.risks}`;
}

// ============================================================================
// Internal helpers
// ============================================================================

function findEmptySection(brief: BriefInference): string | null {
  if (brief.taskType.trim().length < MIN_FIELD_LENGTH) return 'taskType';
  if (brief.coreGoal.trim().length < MIN_FIELD_LENGTH) return 'coreGoal';
  if (brief.technicalApproach.trim().length < MIN_FIELD_LENGTH) return 'technicalApproach';
  if (brief.risks.trim().length < MIN_FIELD_LENGTH) return 'risks';
  return null;
}
