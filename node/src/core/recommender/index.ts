/**
 * KALLAX Recommender Module
 */

export { computeTF, computeIDF, applyIDF, cosineSimilarity } from './scorer.js';
export { matchPerformer } from './matcher.js';
export type { PerformerProfile, MatchResult, MatchOptions } from './matcher.js';
