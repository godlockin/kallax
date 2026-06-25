import { z } from 'zod';

export const PersonaIdSchema = z
  .string()
  .regex(/^kallax\.\w+\.\d{3}$/, {
    message: 'id must match /^kallax\\.\\w+\\.\\d{3}$/ (e.g. kallax.architect.001)',
  });

export const PersonaTierSchema = z.enum(['default'], {
  errorMap: () => ({ message: "tier must be 'default' (KALLAX does not use optional/extended tiers)" }),
});

export const WorktreeRoleSchema = z.enum(['master', 'conductor', 'performer'], {
  errorMap: () => ({ message: "worktree_role must be one of 'master' | 'conductor' | 'performer'" }),
});

export const ReviewGroupSchema = z.enum(['A', 'B', 'AB'], {
  errorMap: () => ({ message: "review_group must be one of 'A' | 'B' | 'AB'" }),
});

export const PhaseSchema = z
  .number()
  .int('phase must be an integer')
  .min(1, 'phase must be >= 1')
  .max(3, 'phase must be <= 3 (KALLAX EPIC phases 1-3)');

export const RationalizationsCountSchema = z
  .number()
  .int('rationalizations_count must be an integer')
  .min(0, 'rationalizations_count must be >= 0');

export const PersonaVersionSchema = z
  .string()
  .regex(/^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$/, {
    message: 'version must be semver (X.Y.Z or X.Y.Z-pre or X.Y.Z+build)',
  });

export const LastReviewedSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'last_reviewed must be ISO date YYYY-MM-DD',
  });

export const TicketsServedSchema = z.array(z.string()).default([]);

export const PersonaSchema = z
  .object({
    id: PersonaIdSchema,
    tier: PersonaTierSchema,
    worktree_role: WorktreeRoleSchema,
    review_group: ReviewGroupSchema,
    phase: PhaseSchema,
    rationalizations_count: RationalizationsCountSchema,
    version: PersonaVersionSchema,
    last_reviewed: LastReviewedSchema,
    tickets_served: TicketsServedSchema,
  })
  .passthrough();

export type Persona = z.infer<typeof PersonaSchema>;
export type PersonaTier = z.infer<typeof PersonaTierSchema>;
export type WorktreeRole = z.infer<typeof WorktreeRoleSchema>;
export type ReviewGroup = z.infer<typeof ReviewGroupSchema>;
export type PersonaVersion = z.infer<typeof PersonaVersionSchema>;