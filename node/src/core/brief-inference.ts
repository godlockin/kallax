/**
 * KALLAX Brief Inference — 任务理解强制 (kallax task:claim gate)
 *
 * EPIC-030-I: Forces Performer to articulate task understanding BEFORE claim.
 * Performer §5.1 borrowed methodology (eket SLAVER-RULES.md §2.5).
 *
 * Why (反讽 + 诚实修正 战略):
 *   - "反讽": Performers who claim without understanding produce cargo-cult code
 *     (1 ticket 1 subagent 串行 treats this as a hard gate, not a soft hint).
 *   - "诚实修正": Surface hidden misunderstanding early — better to reject the
 *     claim (exit 1) than ship "should work" stubs.
 *
 * 4-section format (single line, separated by ` | `):
 *   📋 任务理解: [任务类型] | [核心目标] | [技术方案] | [风险点]
 *   e.g.       📋 任务理解: backend | 修复 N+1 query | 加 eager-load + 索引 | 索引迁移回滚
 *
 * Wiring (kallax task:claim integration):
 *   1. Performer calls `enforceClaimWithBrief(ticketPath, claimerId)` BEFORE claim.
 *   2. Reads ticket.json — must contain `brief_inference` field (4 sections).
 *   3. If missing → returns Err(BRIEF_INFERENCE_MISSING) — caller rejects claim (exit 1).
 *   4. If present → returns Ok(void), claim proceeds.
 *   5. Quality of brief can BOOST TrustScore via `evaluateBriefQuality` (EPIC-030-A 联合).
 *
 * Quality scoring (4 dimensions, 0.0-1.0):
 *   - specificity   — concrete (file paths / function names / metrics) vs vague
 *   - completeness  — 4 sections all non-empty
 *   - risk_aware    — explicitly names risks (not just "no risks")
 *   - measurable    — acceptance criteria implied (test/AC keywords)
 *
 * Source: Performer §5.1 + eket SLAVER-RULES.md §2.5 (方法论 borrow, 0 代码 copy)
 * TrustScore integration: node/src/core/trust-score.ts (EPIC-030-A)
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { Result, ok, err } from 'neverthrow';
import { z } from 'zod';
import { logger } from '../utils/logger.js';
import {
  TrustScore,
  type ExpertProfile,
  type TicketProfile,
  type TrustScoreResult,
} from './trust-score.js';

// ============================================================================
// Constants (Rule 4: no magic numbers — name all of them)
// ============================================================================

const BRIEF_SECTION_COUNT = 4;
const BRIEF_SECTION_SEPARATOR = ' | ';
const BRIEF_PREFIX = '📋 任务理解:';

const QUALITY_SPECIFICITY_WEIGHT = 0.35;
const QUALITY_COMPLETENESS_WEIGHT = 0.25;
const QUALITY_RISK_AWARE_WEIGHT = 0.20;
const QUALITY_MEASURABLE_WEIGHT = 0.20;

const MIN_FIELD_LENGTH = 2;
const SPECIFICITY_VAGUE_PHRASES = [
  '应该',
  '可能',
  '大概',
  '好像',
  'maybe',
  'probably',
  'might',
  'should work',
] as const;
const SPECIFICITY_CONCRETE_MARKERS = [
  'src/',
  'tests/',
  '.ts',
  '.sh',
  'function ',
  'class ',
  'interface ',
  'type ',
  'const ',
  'import ',
  'export ',
  '/',
  '.test.',
  'ERROR:',
  'FAIL:',
  'exit ',
  'AC',
] as const;
const RISK_AWARE_KEYWORDS = [
  '风险',
  '回滚',
  '失败',
  '超时',
  '阻塞',
  'race',
  'rollback',
  'risk',
  'failure',
  'timeout',
  'blocker',
] as const;
const MEASURABLE_KEYWORDS = [
  'PASS',
  'FAIL',
  'test',
  '测试',
  'AC',
  'exit',
  'coverage',
  '覆盖率',
  '断言',
  'expect',
] as const;

export const BRIEF_INFERENCE_FIELD = 'brief_inference';

// ============================================================================
// Types
// ============================================================================

export interface BriefInference {
  readonly taskType: string;
  readonly coreGoal: string;
  readonly technicalApproach: string;
  readonly risks: string;
}

export interface BriefQualityBreakdown {
  readonly specificity: number;
  readonly completeness: number;
  readonly riskAware: number;
  readonly measurable: number;
}

export interface BriefQuality {
  readonly score: number;
  readonly breakdown: BriefQualityBreakdown;
  readonly passes: boolean;
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
      message: `expected ${BRIEF_SECTION_COUNT} sections separated by "${BRIEF_SECTION_SEPARATOR}", got ${sections.length}`,
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
      message: `section "${emptySection}" is empty or below min length ${MIN_FIELD_LENGTH}`,
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
// Quality Scoring (EPIC-030-A TrustScore 联合 — brief quality → score boost)
// ============================================================================

export function evaluateBriefQuality(brief: BriefInference): BriefQuality {
  const combined = `${brief.taskType} ${brief.coreGoal} ${brief.technicalApproach} ${brief.risks}`;
  const combinedLower = combined.toLowerCase();

  const specificity = scoreSpecificity(combined, combinedLower);
  const completeness = scoreCompleteness(brief);
  const riskAware = scoreRiskAware(brief.risks, combinedLower);
  const measurable = scoreMeasurable(combinedLower);

  const score =
    specificity * QUALITY_SPECIFICITY_WEIGHT +
    completeness * QUALITY_COMPLETENESS_WEIGHT +
    riskAware * QUALITY_RISK_AWARE_WEIGHT +
    measurable * QUALITY_MEASURABLE_WEIGHT;

  const PASS_THRESHOLD = 0.5;
  return {
    score: clamp01(score),
    breakdown: { specificity, completeness, riskAware, measurable },
    passes: score >= PASS_THRESHOLD,
  };
}

export function briefBoostsTrustScore(
  brief: BriefInference,
  baseResult: TrustScoreResult,
): TrustScoreResult {
  const quality = evaluateBriefQuality(brief);
  const QUALITY_BOOST_FACTOR = 0.15;
  const boost = quality.score * QUALITY_BOOST_FACTOR;
  const boostedScore = clamp01(baseResult.score + boost);
  return {
    ...baseResult,
    score: boostedScore,
  };
}

export function combinedExpertAssignment(
  ticket: TicketProfile,
  expert: ExpertProfile,
  brief: BriefInference | null,
): { readonly trustResult: TrustScoreResult; readonly briefQuality: BriefQuality | null } {
  const scorer = new TrustScore();
  const baseResult = scorer.match(ticket, expert);
  if (brief === null) {
    return { trustResult: baseResult, briefQuality: null };
  }
  const briefQuality = evaluateBriefQuality(brief);
  return {
    trustResult: briefBoostsTrustScore(brief, baseResult),
    briefQuality,
  };
}

// ============================================================================
// Ticket Integration (file-system gate — kjson-shaped)
// ============================================================================

export interface TicketWithBrief {
  readonly id: string;
  readonly title: string;
  readonly description?: string;
  readonly brief_inference?: BriefInference;
  readonly claimed_by?: string;
  readonly claimed_at?: string;
}

export function readTicket(ticketPath: string): Result<TicketWithBrief, BriefInferenceError> {
  let raw: string;
  try {
    raw = readFileSync(ticketPath, 'utf-8');
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    return err({
      code: 'TICKET_FILE_READ_FAILED',
      message,
      path: ticketPath,
    });
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    return err({
      code: 'TICKET_JSON_INVALID',
      message,
      path: ticketPath,
    });
  }

  if (!isTicketWithBrief(parsed)) {
    return err({
      code: 'TICKET_JSON_INVALID',
      message: 'parsed JSON does not match TicketWithBrief shape',
      path: ticketPath,
    });
  }

  return ok(parsed);
}

export function attachBriefToTicket(
  ticketPath: string,
  brief: BriefInference,
  claimerId: string,
): Result<TicketWithBrief, BriefInferenceError> {
  const ticketResult = readTicket(ticketPath);
  if (ticketResult.isErr()) return ticketResult;

  const validation = validateBrief(brief);
  if (validation.isErr()) return err(validation.error);

  const updated: TicketWithBrief = {
    ...ticketResult.value,
    brief_inference: brief,
    claimed_by: claimerId,
    claimed_at: new Date().toISOString(),
  };

  try {
    writeFileSync(ticketPath, `${JSON.stringify(updated, null, 2)}\n`, 'utf-8');
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    return err({
      code: 'TICKET_FILE_WRITE_FAILED',
      message,
      path: ticketPath,
    });
  }

  logger.info(
    {
      event: 'brief_inference.attached',
      ticketId: updated.id,
      claimerId,
      quality: evaluateBriefQuality(brief),
    },
    'brief inference attached to ticket',
  );

  return ok(updated);
}

export function enforceClaimWithBrief(
  ticketPath: string,
  claimerId: string,
): Result<{ readonly ticket: TicketWithBrief; readonly quality: BriefQuality }, BriefInferenceError> {
  const ticketResult = readTicket(ticketPath);
  if (ticketResult.isErr()) {
    const e = ticketResult.error;
    if (e.code === 'TICKET_FILE_READ_FAILED' || e.code === 'TICKET_JSON_INVALID') {
      return err(e);
    }
    return err({
      code: 'TICKET_FILE_READ_FAILED',
      message: `unexpected ticket read error: ${e.code}`,
      path: ticketPath,
    });
  }

  const ticket = ticketResult.value;
  const brief = ticket.brief_inference;

  if (brief === undefined) {
    logger.warn(
      {
        event: 'brief_inference.rejected',
        ticketId: ticket.id,
        claimerId,
        reason: 'missing',
      },
      'claim rejected: no brief_inference on ticket',
    );
    return err({
      code: 'BRIEF_INFERENCE_MISSING',
      message: `ticket ${ticket.id} has no brief_inference field — Performer must write 任务理解 before claiming`,
    });
  }

  const validation = validateBrief(brief);
  if (validation.isErr()) return err(validation.error);

  const quality = evaluateBriefQuality(brief);
  const MIN_QUALITY_FOR_CLAIM = 0.5;
  if (quality.score < MIN_QUALITY_FOR_CLAIM) {
    logger.warn(
      {
        event: 'brief_inference.rejected',
        ticketId: ticket.id,
        claimerId,
        reason: 'low_quality',
        quality,
      },
      'claim rejected: brief quality too low',
    );
    return err({
      code: 'BRIEF_INFERENCE_MALFORMED',
      message: `brief quality score ${quality.score.toFixed(3)} below threshold ${MIN_QUALITY_FOR_CLAIM} — needs more specificity / risks / measurable AC`,
    });
  }

  logger.info(
    {
      event: 'brief_inference.claimed',
      ticketId: ticket.id,
      claimerId,
      quality,
    },
    'claim accepted with brief inference',
  );

  return ok({ ticket, quality });
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

function scoreSpecificity(text: string, textLower: string): number {
  const VAGUE_PENALTY = 0.15;
  const CONCRETE_REWARD = 0.12;
  const LENGTH_REWARD_CAP = 0.3;

  let score = 0.0;
  for (const phrase of SPECIFICITY_VAGUE_PHRASES) {
    if (textLower.includes(phrase)) score -= VAGUE_PENALTY;
  }
  for (const marker of SPECIFICITY_CONCRETE_MARKERS) {
    if (text.includes(marker)) score += CONCRETE_REWARD;
  }

  const lengthBonus = Math.min(text.length / 100, 1.0) * LENGTH_REWARD_CAP;
  return clamp01(0.5 + score + lengthBonus);
}

function scoreCompleteness(brief: BriefInference): number {
  let filled = 0;
  for (const value of [brief.taskType, brief.coreGoal, brief.technicalApproach, brief.risks]) {
    if (value.trim().length >= MIN_FIELD_LENGTH) filled += 1;
  }
  return filled / BRIEF_SECTION_COUNT;
}

function scoreRiskAware(risksField: string, combinedLower: string): number {
  const HAS_RISK_SECTION_BASE = 0.4;
  let hits = 0;
  for (const keyword of RISK_AWARE_KEYWORDS) {
    if (combinedLower.includes(keyword)) hits += 1;
  }
  const keywordBonus = Math.min(hits / 3, 1.0) * 0.6;
  const hasRisksSection = risksField.trim().length >= MIN_FIELD_LENGTH ? HAS_RISK_SECTION_BASE : 0;
  return clamp01(hasRisksSection + keywordBonus);
}

function scoreMeasurable(combinedLower: string): number {
  let hits = 0;
  for (const keyword of MEASURABLE_KEYWORDS) {
    if (combinedLower.includes(keyword.toLowerCase())) hits += 1;
  }
  return clamp01(Math.min(hits / 2, 1.0));
}

function clamp01(value: number): number {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

function isTicketWithBrief(value: unknown): value is TicketWithBrief {
  if (typeof value !== 'object' || value === null) return false;
  const obj = value as Record<string, unknown>;
  if (typeof obj['id'] !== 'string') return false;
  if (typeof obj['title'] !== 'string') return false;
  if (obj['description'] !== undefined && typeof obj['description'] !== 'string') return false;
  if (obj['claimed_by'] !== undefined && typeof obj['claimed_by'] !== 'string') return false;
  if (obj['claimed_at'] !== undefined && typeof obj['claimed_at'] !== 'string') return false;
  if (obj['brief_inference'] !== undefined) {
    const brief = obj['brief_inference'];
    if (typeof brief !== 'object' || brief === null) return false;
    const b = brief as Record<string, unknown>;
    if (typeof b['taskType'] !== 'string') return false;
    if (typeof b['coreGoal'] !== 'string') return false;
    if (typeof b['technicalApproach'] !== 'string') return false;
    if (typeof b['risks'] !== 'string') return false;
  }
  return true;
}
