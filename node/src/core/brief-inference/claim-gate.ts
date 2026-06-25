/**
 * KALLAX Brief Inference — Claim Gate (kallax task:claim hard gate)
 *
 * EPIC-030-I: Performer calls `enforceClaimWithBrief(ticketPath, claimerId)`
 * BEFORE claim. Reads ticket.json — must contain `brief_inference` field.
 *
 * Outcomes:
 *   - missing field            → Err(BRIEF_INFERENCE_MISSING)  — caller rejects (exit 1)
 *   - present but low quality  → Err(BRIEF_INFERENCE_MALFORMED) — caller rejects
 *   - present + quality ≥ 0.5  → Ok({ ticket, quality })        — claim proceeds
 *
 * Quality threshold check is intentionally strict (>0.5) so vague briefs
 * (probably / maybe / should) fail the gate, surfacing hidden misunderstanding
 * before any code is written.
 */

import { Result, ok, err } from 'neverthrow';
import { logger } from '../../utils/logger.js';
import type { BriefInferenceError } from './types.js';
import { validateBrief } from './types.js';
import { evaluateBriefQuality, type BriefQuality } from './quality.js';
import { readTicket, type TicketWithBrief } from './assignment.js';

// ============================================================================
// Constants (Rule 4: no magic numbers — name all of them)
// ============================================================================

const MIN_QUALITY_FOR_CLAIM = 0.5;

// ============================================================================
// Public API
// ============================================================================

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
