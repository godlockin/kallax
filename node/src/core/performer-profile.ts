/**
 * KALLAX Performer Profile (EPIC-121-B)
 * Tiered memory for performer history.
 *
 * LangChain Memory tiers mapped to KALLAX:
 *   BufferWindow → SQLite task history (current, working)
 *   Summary → abandonment_summary field (weekly rollup)
 *   VectorStore → skill_embedding (future)
 */

export interface PerformerProfile {
  readonly performerId: string;
  readonly masteryLevel: MasteryLevel;
  readonly abandonmentRate: number;
  readonly taskHistory: TaskSummary[];
  readonly skillEmbedding: number[] | null;
  readonly updatedAt: number;
}

export interface TaskSummary {
  readonly ticketId: string;
  readonly status: string;
  readonly abandonedAt: number | null;
  readonly completedAt: number | null;
}

export type MasteryLevel = 'L1' | 'L2' | 'L3';

export interface PerformerProfileStore {
  save(profile: PerformerProfile): Promise<void>;
  load(performerId: string): Promise<PerformerProfile | null>;
  searchSimilar(embedding: number[], topK: number): Promise<string[]>;
}

export class InMemoryPerformerProfileStore implements PerformerProfileStore {
  private profiles = new Map<string, PerformerProfile>();

  save(profile: PerformerProfile): Promise<void> {
    this.profiles.set(profile.performerId, profile);
    return Promise.resolve();
  }

  load(performerId: string): Promise<PerformerProfile | null> {
    return Promise.resolve(this.profiles.get(performerId) ?? null);
  }

  searchSimilar(_embedding: number[], _topK: number): Promise<string[]> {
    return Promise.resolve([]);
  }
}
