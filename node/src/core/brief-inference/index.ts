/**
 * KALLAX Brief Inference — Public API barrel (preserves `brief-inference.js` import path)
 *
 * EPIC-030-I: Forces Performer to articulate task understanding BEFORE claim.
 *
 * Sub-files (single responsibility each, all < 500 lines):
 *   - types.ts       — Brief types + parseBrief + validateBrief + serializeBrief
 *   - quality.ts     — evaluateBriefQuality + briefBoostsTrustScore + scoring helpers
 *   - assignment.ts  — combinedExpertAssignment + readTicket + attachBriefToTicket
 *   - claim-gate.ts  — enforceClaimWithBrief (the hard gate)
 *   - index.ts       — this file (re-exports + module header)
 *
 * All public symbols are re-exported from here so consumers continue importing
 * from `../core/brief-inference.js` (back-compat for tests and any external
 * caller). Internal sub-files use `./types.js`, `./quality.js`, etc.
 *
 * Source: Performer §5.1 + eket SLAVER-RULES.md §2.5 (方法论 borrow, 0 代码 copy)
 * TrustScore integration: node/src/core/trust-score.ts (EPIC-030-A)
 */

// Re-exports from types.ts — Brief types + parse/validate/serialize
export {
  BRIEF_SECTION_COUNT,
  BRIEF_SECTION_SEPARATOR,
  BRIEF_PREFIX,
  MIN_FIELD_LENGTH,
  parseBrief,
  validateBrief,
  serializeBrief,
  type BriefInference,
  type BriefInferenceError,
} from './types.js';

// Re-exports from quality.ts — Quality scoring + TrustScore boost
export {
  evaluateBriefQuality,
  briefBoostsTrustScore,
  type BriefQuality,
  type BriefQualityBreakdown,
} from './quality.js';

// Re-exports from assignment.ts — Expert assignment + Ticket I/O
export {
  BRIEF_INFERENCE_FIELD,
  combinedExpertAssignment,
  readTicket,
  attachBriefToTicket,
  type TicketWithBrief,
} from './assignment.js';

// Re-exports from claim-gate.ts — Hard claim gate
export { enforceClaimWithBrief } from './claim-gate.js';
