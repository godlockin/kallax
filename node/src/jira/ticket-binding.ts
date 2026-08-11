/**
 * KALLAX Jira Ticket Binding Helper (EPIC-157)
 *
 * Read/write jira/tickets/{ticket_id}/ticket.json expert_binding field.
 * Source of truth: jira/tickets/{star}/ticket.json (per CLAUDE.md design).
 *
 * Functions:
 *   readJiraTicketPath(ticketId, worktreeRoot) - find ticket.json path
 *   readJiraTicket(ticketId, worktreeRoot)     - read + parse ticket.json
 *   writeBinding(ticketId, binding, root)      - write expert_binding (atomic)
 *   validateBindingForComplete(ticketId, root) - submit-pr validation (AC4)
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import { err, ok, Result } from 'neverthrow';
import { ExpertBindingSchema, ExpertBinding, Ticket } from '../core/schema-validator.js';
import { logger } from '../utils/logger.js';

export type JiraTicketError =
  | { kind: 'NOT_FOUND'; ticketId: string; searched: string[] }
  | { kind: 'PARSE_FAILED'; ticketId: string; cause: string }
  | { kind: 'WRITE_FAILED'; ticketId: string; cause: string }
  | { kind: 'VALIDATION_FAILED'; ticketId: string; errors: string[] };

const JIRA_TICKETS_DIR = 'jira/tickets';

/**
 * Find ticket.json for a given ticketId, supporting both:
 *   - jira/tickets/EPIC-XXX/ticket.json  (root ticket)
 *   - jira/tickets/EPIC-XXX-A/ticket.json (sub-ticket)
 *
 * Returns the first match (sub-ticket wins over root).
 */
export function findJiraTicketPath(ticketId: string, worktreeRoot: string): string | null {
  const exact = path.join(worktreeRoot, JIRA_TICKETS_DIR, ticketId, 'ticket.json');
  if (fs.existsSync(exact)) return exact;

  // sub-ticket pattern: jira/tickets/EPIC-XXX-*/
  const ticketsDir = path.join(worktreeRoot, JIRA_TICKETS_DIR);
  if (!fs.existsSync(ticketsDir)) return null;

  const prefix = `${ticketId}-`;
  let candidate: string | null = null;
  try {
    for (const entry of fs.readdirSync(ticketsDir)) {
      if (entry.startsWith(prefix) || entry === ticketId) {
        const p = path.join(ticketsDir, entry, 'ticket.json');
        if (fs.existsSync(p)) {
          if (entry === ticketId) {
            // exact match takes priority
            return p;
          }
          candidate ??= p;
        }
      }
    }
  } catch (error: unknown) {
    logger.warn({ ticketId, error: String(error) }, 'failed to scan jira tickets dir');
  }
  return candidate;
}

/**
 * Read ticket.json + return parsed Ticket.
 */
export function readJiraTicket(
  ticketId: string,
  worktreeRoot: string
): Result<{ ticket: Ticket; path: string }, JiraTicketError> {
  const p = findJiraTicketPath(ticketId, worktreeRoot);
  if (p === null) {
    return err({
      kind: 'NOT_FOUND',
      ticketId,
      searched: [
        path.join(worktreeRoot, JIRA_TICKETS_DIR, ticketId, 'ticket.json'),
        path.join(worktreeRoot, JIRA_TICKETS_DIR, `${ticketId}-*`),
      ],
    });
  }

  let raw: string;
  try {
    raw = fs.readFileSync(p, 'utf-8');
  } catch (error: unknown) {
    return err({ kind: 'WRITE_FAILED', ticketId, cause: `read: ${String(error)}` });
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (error: unknown) {
    return err({ kind: 'PARSE_FAILED', ticketId, cause: String(error) });
  }

  // Light validation: ensure it's a record with at least id
  if (typeof parsed !== 'object' || parsed === null || !('id' in parsed)) {
    return err({ kind: 'PARSE_FAILED', ticketId, cause: 'missing id field' });
  }

  return ok({ ticket: parsed as Ticket, path: p });
}

/**
 * Write expert_binding to ticket.json (atomic via tmp + rename).
 * Validates binding via ExpertBindingSchema before writing.
 */
export function writeBinding(
  ticketId: string,
  binding: ExpertBinding,
  worktreeRoot: string
): Result<{ path: string }, JiraTicketError> {
  // 1. Validate binding shape (incl. divergent-reason rule)
  const parseResult = ExpertBindingSchema.safeParse(binding);
  if (!parseResult.success) {
    return err({
      kind: 'VALIDATION_FAILED',
      ticketId,
      errors: parseResult.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`),
    });
  }

  // 2. Read existing ticket
  const readResult = readJiraTicket(ticketId, worktreeRoot);
  if (readResult.isErr()) return err(readResult.error);

  const { ticket, path: ticketPath } = readResult.value;

  // 3. Merge binding (preserve other fields)
  const updated: Ticket = { ...ticket, expert_binding: parseResult.data };

  // 4. Atomic write via tmp + rename
  const tmpPath = `${ticketPath}.tmp`;
  try {
    fs.writeFileSync(tmpPath, JSON.stringify(updated, null, 2) + '\n', 'utf-8');
    fs.renameSync(tmpPath, ticketPath);
  } catch (error: unknown) {
    // Cleanup tmp on failure
    try {
      if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);
    } catch {
      /* ignore */
    }
    return err({ kind: 'WRITE_FAILED', ticketId, cause: String(error) });
  }

  logger.info({ ticketId, binding }, 'expert_binding written');
  return ok({ path: ticketPath });
}

/**
 * Submit-pr (AC4) 校验: 读 jira ticket.json, 验证 binding 可提交.
 *
 * Rules:
 *   - expert_binding 必须存在
 *   - actual_expert 必填
 *   - 若 actual_expert 跟 suggested_expert 不同 → binding_change_reason 必填非空
 *
 * Returns ok({ binding }) on success, err with reasons on failure.
 */
export function validateBindingForComplete(
  ticketId: string,
  worktreeRoot: string
): Result<{ binding: ExpertBinding }, JiraTicketError> {
  const readResult = readJiraTicket(ticketId, worktreeRoot);
  if (readResult.isErr()) return err(readResult.error);

  const binding = readResult.value.ticket.expert_binding;
  if (binding === undefined) {
    return err({
      kind: 'VALIDATION_FAILED',
      ticketId,
      errors: ['expert_binding is missing (Performer must claim the ticket first)'],
    });
  }

  if (binding.actual_expert == null || binding.actual_expert.trim() === '') {
    return err({
      kind: 'VALIDATION_FAILED',
      ticketId,
      errors: ['expert_binding.actual_expert is required for submit-pr'],
    });
  }

  if (
    binding.suggested_expert != null &&
    binding.suggested_expert !== binding.actual_expert &&
    (binding.binding_change_reason == null || binding.binding_change_reason.trim() === '')
  ) {
    return err({
      kind: 'VALIDATION_FAILED',
      ticketId,
      errors: [
        'binding_change_reason is required when actual_expert differs from suggested_expert',
      ],
    });
  }

  return ok({ binding });
}
