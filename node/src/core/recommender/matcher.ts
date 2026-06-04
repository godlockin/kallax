/**
 * KALLAX Recommender — Skill Matcher
 *
 * Given a task's required capabilities and a pool of registered performers,
 * rank the performers by TF-IDF cosine similarity of their capability sets.
 */

import { err, ok } from 'neverthrow';
import type { Result } from 'neverthrow';
import { computeTF, computeIDF, applyIDF, cosineSimilarity } from './scorer.js';

// ============================================================================
// Types
// ============================================================================

export interface PerformerProfile {
  readonly id: string;
  readonly capabilities: readonly string[];
}

export interface MatchResult {
  readonly performerId: string;
  readonly score: number;
  readonly matchedCapabilities: readonly string[];
  readonly missingCapabilities: readonly string[];
}

export interface MatchOptions {
  readonly topN: number;
}

// ============================================================================
// Public API
// ============================================================================

/**
 * Rank performers by capability similarity to the task's requirements.
 *
 * Algorithm:
 *   1. Build a "document" (space-joined capabilities) per performer.
 *   2. Compute IDF across all performer documents.
 *   3. Compute TF for the task's required capabilities.
 *   4. Build TF-IDF vectors for task and every performer.
 *   5. Cosine-similarity between task vector and each performer vector.
 *   6. Sort descending by score, return top-N results.
 */
export function matchPerformer(
  taskCapabilities: readonly string[],
  performers: readonly PerformerProfile[],
  options: MatchOptions = { topN: 10 },
): Result<MatchResult[], Error> {
  if (taskCapabilities.length === 0) {
    return err(new Error('task capabilities list is empty — nothing to match'));
  }
  if (performers.length === 0) {
    return err(new Error('performer pool is empty — no candidates to rank'));
  }

  const topN = Math.max(1, options.topN);

  // Corpus of performer documents for IDF computation
  const docs = performers.map((p) => p.capabilities.join(' '));
  const idf = computeIDF(docs);

  // TF-IDF vector for the task
  const taskTF = computeTF(taskCapabilities.join(' '));
  const taskVec = applyIDF(taskTF, idf);

  // Score each performer
  const scored: MatchResult[] = [];

  for (const performer of performers) {
    const perfTF = computeTF(performer.capabilities.join(' '));
    const perfVec = applyIDF(perfTF, idf);

    const sim = cosineSimilarity(taskVec, perfVec);
    const capSet = new Set(performer.capabilities);

    const matched: string[] = [];
    const missing: string[] = [];
    for (const cap of taskCapabilities) {
      if (capSet.has(cap)) {
        matched.push(cap);
      } else {
        missing.push(cap);
      }
    }

    const result: MatchResult = {
      performerId: performer.id,
      score: sim,
      matchedCapabilities: matched,
      missingCapabilities: missing,
    };
    scored.push(result);
  }

  // Sort descending by similarity score
  scored.sort((a, b) => b.score - a.score);

  return ok(scored.slice(0, topN));
}
