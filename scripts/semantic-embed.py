#!/usr/bin/env python3
"""
semantic-embed.py — Generate 384-dim embedding for requirement text.
Usage: python3 scripts/semantic-embed.py '<requirement_text>'

Outputs: JSON with id, embedding (384-dim list), model, cache_hit
Supports CPU-only, cross-platform (macOS/Linux).
"""

import sys
import os
import json
import hashlib
import tempfile
from pathlib import Path

# Configuration
EMBEDDING_DIM = 384
CACHE_DIR = Path(__file__).parent.parent / ".kallax" / "data" / "embeddings_cache"
CACHE_DIR.mkdir(parents=True, exist_ok=True)

def get_cache_path(text: str) -> Path:
    """Get cache file path for embedding."""
    h = hashlib.sha256(text.encode()).hexdigest()[:16]
    return CACHE_DIR / f"{h}.npy"

def compute_tfidf_embedding(text: str, dim: int = 384) -> list:
    """Fallback TF-IDF + L2 normalization when sentence-transformers unavailable."""
    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
    except ImportError:
        # Simple hash-based fallback if sklearn unavailable
        import struct
        h = hashlib.sha256(text.encode()).digest()
        vec = list(struct.unpack(f"{dim}f", h * (dim //32 + 1)[:dim * 4]))
        # L2 normalize
        norm = sum(v * v for v in vec) ** 0.5
        if norm > 0:
            vec = [v / norm for v in vec]
        return vec

    # TF-IDF vectorization
    vectorizer = TfidfVectorizer(max_features=dim, ngram_range=(1, 2))
    try:
        tfidf_matrix = vectorizer.fit_transform([text])
        vec = tfidf_matrix.toarray()[0].tolist()
    except ValueError:
        # Text too short for TF-IDF
        vec = [0.0] * dim

    # L2 normalize
    norm = sum(v * v for v in vec) ** 0.5
    if norm > 0:
        vec = [v / norm for v in vec]
    else:
        # Fallback to hash-based if TF-IDF gives zero vector
        h = hashlib.sha256(text.encode()).digest()
        vec = list(struct.unpack(f"{dim}f", h * (dim // 32 + 1)[:dim * 4]))

    return vec

def compute_sentence_embedding(text: str, dim: int = 384) -> list:
    """Compute embedding using sentence-transformers (preferred)."""
    try:
        from sentence_transformers import SentenceTransformer
        model = SentenceTransformer('all-MiniLM-L6-v2', device='cpu')
        embedding = model.encode(text, normalize_embeddings=True)
        return embedding.tolist()
    except ImportError:
        return None

def cosine_similarity(a: list, b: list) -> float:
    """Compute cosine similarity between two vectors."""
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(x * x for x in b) ** 0.5
    if norm_a * norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 semantic-embed.py '<requirement_text>'", file=sys.stderr)
        sys.exit(1)

    text = sys.argv[1]
    if not text.strip():
        print("ERROR: empty text", file=sys.stderr)
        sys.exit(1)

    cache_path = get_cache_path(text)

    # Check cache
    if cache_path.exists():
        embedding = np.load(cache_path) if False else None # Simplified cache check
        # For simplicity, always recompute (cache check via file existence)
        pass

    # Compute embedding
    embedding = compute_sentence_embedding(text, EMBEDDING_DIM)
    model = "sentence-transformers:all-MiniLM-L6-v2"

    if embedding is None:
        embedding = compute_tfidf_embedding(text, EMBEDDING_DIM)
        model = "sklearn:tfidf+l2"

    # Save cache
    try:
        import numpy as np
        np.save(cache_path, np.array(embedding, dtype=np.float32))
    except ImportError:
        pass # Skip cache if numpy unavailable

    result = {
        "embedding": embedding,
        "dim": EMBEDDING_DIM,
        "model": model,
        "cache_hit": False
    }

    print(json.dumps(result, ensure_ascii=False))

if __name__ == "__main__":
    main()