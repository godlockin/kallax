/**
 * KALLAX Brief Inference — Expert Assignment + Ticket I/O
 *
 * Bridges brief quality with TrustScore (combinedExpertAssignment) and persists
 * briefs to disk as `brief_inference` field on ticket.json.
 *
 * Wiring (kallax task:claim integration):
 *   - readTicket(ticketPath) — load + validate ticket.json shape
 *   - attachBriefToTicket(ticketPath, brief, claimerId) — write brief + claim metadata
 *   - combinedExpertAssignment(ticket, expert, brief?) — base TrustScore + optional brief boost
 *
 * Quality of brief can BOOST TrustScore via evaluateBriefQuality (EPIC-030-A ).
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { Result, ok, err } from 'neverthrow';
import { logger } from '../../utils/logger.js';
import {
  TrustScore,
  type ExpertProfile,
  type TicketProfile,
  type TrustScoreResult,
} from '../trust-score.js';
import type { BriefInference, BriefInferenceError } from './types.js';
import { validateBrief } from './types.js';
import { evaluateBriefQuality, briefBoostsTrustScore, type BriefQuality } from './quality.js';

// ============================================================================
// Constants (Rule 4: no magic numbers — name all of them)
// ============================================================================

export const BRIEF_INFERENCE_FIELD = 'brief_inference';

// ============================================================================
// Types
// ============================================================================

export interface TicketWithBrief {
  readonly id: string;
  readonly title: string;
  readonly description?: string;
  readonly brief_inference?: BriefInference;
  readonly claimed_by?: string;
  readonly claimed_at?: string;
}

// ============================================================================
// Expert assignment (TrustScore  — brief quality → score boost)
// ============================================================================

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
// Ticket I/O (file-system gate — kjson-shaped)
// ============================================================================

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

// ============================================================================
// Internal helpers
// ============================================================================

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
