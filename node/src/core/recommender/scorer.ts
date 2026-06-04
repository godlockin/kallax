/**
 * KALLAX Recommender — TF-IDF Style Scorer
 *
 * Pure functions for term-frequency / inverse-document-frequency scoring
 * and cosine similarity.  Zero I/O — no external dependencies beyond neverthrow.
 */

// ============================================================================
// Tokenizer (internal)
// ============================================================================

/**
 * Lowercase tokenizer: strips non-alphanumeric chars (except hyphens),
 * splits on whitespace, drops single-character tokens.
 */
function tokenize(text: string): readonly string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .split(/\s+/)
    .filter((w) => w.length > 1);
}

// ============================================================================
// Public API
// ============================================================================

/**
 * Compute term-frequency vector for a piece of raw text.
 * Values are normalized by total token count (L1 norm).
 */
export function computeTF(text: string): Map<string, number> {
  const tokens = tokenize(text);
  const freq = new Map<string, number>();

  for (const t of tokens) {
    freq.set(t, (freq.get(t) ?? 0) + 1);
  }

  const total = tokens.length || 1;
  for (const [word, count] of freq) {
    freq.set(word, count / total);
  }

  return freq;
}

/**
 * Compute inverse-document-frequency for a corpus of documents.
 *   idf(w, D) = log(N / df_w) + 1   (smooth, avoids zero)
 * Every element in `docs` is treated as one document.
 */
export function computeIDF(docs: readonly string[]): Map<string, number> {
  const df = new Map<string, number>();
  const N = docs.length;

  for (const doc of docs) {
    const terms = new Set(tokenize(doc));
    for (const term of terms) {
      df.set(term, (df.get(term) ?? 0) + 1);
    }
  }

  const idf = new Map<string, number>();
  for (const [term, docCount] of df) {
    idf.set(term, Math.log(N / docCount) + 1);
  }

  return idf;
}

/**
 * Multiply a TF vector by an IDF vector to produce a TF-IDF vector.
 * Words that appear in TF but have no IDF entry receive IDF = 0.
 */
export function applyIDF(
  tf: Map<string, number>,
  idf: Map<string, number>,
): Map<string, number> {
  const result = new Map<string, number>();
  for (const [word, tfVal] of tf) {
    result.set(word, tfVal * (idf.get(word) ?? 0));
  }
  return result;
}

/**
 * Cosine similarity between two sparse vectors.
 * Returns 0 when either vector is zero-length.
 */
export function cosineSimilarity(
  a: Map<string, number>,
  b: Map<string, number>,
): number {
  let dot = 0;
  let normA = 0;
  let normB = 0;

  for (const [word, va] of a) {
    const vb = b.get(word) ?? 0;
    dot += va * vb;
    normA += va * va;
  }

  for (const vb of b.values()) {
    normB += vb * vb;
  }

  const denom = Math.sqrt(normA) * Math.sqrt(normB);
  return denom === 0 ? 0 : dot / denom;
}
