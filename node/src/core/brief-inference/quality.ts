/**
 * KALLAX Brief Inference — Quality Scoring (EPIC-030-A TrustScore )
 *
 * 4 quality dimensions, each scored 0.0-1.0:
 *   - specificity   — concrete (file paths / function names / metrics) vs vague
 *   - completeness  — 4 sections all non-empty
 *   - risk_aware    — explicitly names risks (not just "no risks")
 *   - measurable    — acceptance criteria implied (test/AC keywords)
 *
 * Combined score is a weighted average (summing to 1.0). Used by:
 *   - claim-gate.ts (enforceClaimWithBrief) — gate threshold check
 *   - assignment.ts (combinedExpertAssignment) — TrustScore boost via
 *     briefBoostsTrustScore(brief, base) = clamp01(base + quality * 0.15)
 *
 * Source: Performer §5.1 + eket SLAVER-RULES.md §2.5 (方法论 borrow, 0 代码 copy)
 * TrustScore integration: node/src/core/trust-score.ts (EPIC-030-A)
 */

import type { TrustScoreResult } from '../trust-score.js';
import {
  BRIEF_SECTION_COUNT,
  MIN_FIELD_LENGTH,
  type BriefInference,
} from './types.js';

// ============================================================================
// Constants (Rule 4: no magic numbers — name all of them)
// ============================================================================

const QUALITY_SPECIFICITY_WEIGHT = 0.35;
const QUALITY_COMPLETENESS_WEIGHT = 0.25;
const QUALITY_RISK_AWARE_WEIGHT = 0.20;
const QUALITY_MEASURABLE_WEIGHT = 0.20;

const PASS_THRESHOLD = 0.5;
const QUALITY_BOOST_FACTOR = 0.15;

const VAGUE_PENALTY = 0.15;
const CONCRETE_REWARD = 0.12;
const LENGTH_REWARD_CAP = 0.3;
const SPECIFICITY_BASE = 0.5;
const SPECIFICITY_LENGTH_DIVISOR = 100;

const HAS_RISK_SECTION_BASE = 0.4;
const RISK_KEYWORD_BONUS_CAP = 0.6;
const RISK_KEYWORD_HITS_DIVISOR = 3;

const MEASURABLE_HITS_CAP = 1.0;
const MEASURABLE_HITS_DIVISOR = 2;

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

// ============================================================================
// Types
// ============================================================================

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

// ============================================================================
// Public API
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
  const boost = quality.score * QUALITY_BOOST_FACTOR;
  const boostedScore = clamp01(baseResult.score + boost);
  return {
    ...baseResult,
    score: boostedScore,
  };
}

// ============================================================================
// Internal helpers
// ============================================================================

function scoreSpecificity(text: string, textLower: string): number {
  let score = 0.0;
  for (const phrase of SPECIFICITY_VAGUE_PHRASES) {
    if (textLower.includes(phrase)) score -= VAGUE_PENALTY;
  }
  for (const marker of SPECIFICITY_CONCRETE_MARKERS) {
    if (text.includes(marker)) score += CONCRETE_REWARD;
  }

  const lengthBonus = Math.min(text.length / SPECIFICITY_LENGTH_DIVISOR, 1.0) * LENGTH_REWARD_CAP;
  return clamp01(SPECIFICITY_BASE + score + lengthBonus);
}

function scoreCompleteness(brief: BriefInference): number {
  let filled = 0;
  for (const value of [brief.taskType, brief.coreGoal, brief.technicalApproach, brief.risks]) {
    if (value.trim().length >= MIN_FIELD_LENGTH) filled += 1;
  }
  return filled / BRIEF_SECTION_COUNT;
}

function scoreRiskAware(risksField: string, combinedLower: string): number {
  let hits = 0;
  for (const keyword of RISK_AWARE_KEYWORDS) {
    if (combinedLower.includes(keyword)) hits += 1;
  }
  const keywordBonus = Math.min(hits / RISK_KEYWORD_HITS_DIVISOR, 1.0) * RISK_KEYWORD_BONUS_CAP;
  const hasRisksSection = risksField.trim().length >= MIN_FIELD_LENGTH ? HAS_RISK_SECTION_BASE : 0;
  return clamp01(hasRisksSection + keywordBonus);
}

function scoreMeasurable(combinedLower: string): number {
  let hits = 0;
  for (const keyword of MEASURABLE_KEYWORDS) {
    if (combinedLower.includes(keyword.toLowerCase())) hits += 1;
  }
  return clamp01(Math.min(hits / MEASURABLE_HITS_DIVISOR, MEASURABLE_HITS_CAP));
}

function clamp01(value: number): number {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}
