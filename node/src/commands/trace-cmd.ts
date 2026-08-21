/**
 * KALLAX `trace` Command — EPIC-277-D AC6
 *
 * Query persisted trace events from `trace_logs` table via `TraceLog`.
 * Supports filtering by performer / task / chain / action / time window.
 *
 * Output: tabular (default) or JSON (`--json`) for downstream tooling.
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';

const SINCE_MS_PATTERN = /^(\d+)(s|m|h|d)$/i;

function parseSince(value: string): number | null {
  const match = SINCE_MS_PATTERN.exec(value.trim());
  if (match === null) return null;
  const amount = Number(match[1]);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  const rawUnit = match[2];
  if (rawUnit === undefined) return null;
  const unit = rawUnit.toLowerCase();
  const multipliers: Record<string, number> = { s: 1_000, m: 60_000, h: 3_600_000, d: 86_400_000 };
  const mult = multipliers[unit];
  if (mult === undefined) return null;
  return amount * mult;
}

function resolveCurrentInstanceId(): string | null {
  return process.env['KALLAX_PERFORMER_ID'] ?? process.env['KALLAX_INSTANCE_ID'] ?? null;
}

function cellToString(value: unknown): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  return JSON.stringify(value);
}

function asTable(rows: ReadonlyArray<Record<string, unknown>>): string {
  if (rows.length === 0) return '(no trace entries match filter)';
  const keys = Array.from(rows.reduce<Set<string>>((acc, r) => {
    for (const k of Object.keys(r)) acc.add(k);
    return acc;
  }, new Set<string>()));
  const widths: number[] = keys.map((k) => {
    const max = rows.reduce((m, r) => Math.max(m, cellToString(r[k]).length), k.length);
    return max;
  });
  const header = keys.map((k, i) => k.padEnd(widths[i] ?? k.length)).join(' | ');
  const sep = widths.map((w) => '-'.repeat(w)).join('-+-');
  const body = rows.map((r) => keys.map((k, i) => cellToString(r[k]).padEnd(widths[i] ?? k.length)).join(' | ')).join('\n');
  return `${header}\n${sep}\n${body}`;
}

function durationMs(start: number, end: number): number {
  return end - start;
}

function badgeFor(result: string): string {
  if (result === 'success') return '[OK]';
  if (result === 'failure') return '[FAIL]';
  return '[----]';
}

export function registerTraceCommands(program: Command, ctx: AppContext): void {
  const trace = program
    .command('trace')
    .description('Query persisted trace events (EPIC-277-D AC6)');

  trace
    .option('--performer <id>', 'Filter by performer (actor) id')
    .option('--self', 'Filter by current performer (KALLAX_PERFORMER_ID / KALLAX_INSTANCE_ID)')
    .option('--task <id>', 'Filter by target task id')
    .option('--chain <traceId>', 'Follow trace parent chain from traceId')
    .option('--since <window>', 'Time window like 1h / 30m / 2d (default: all)')
    .option('--action <name>', 'Filter by action name (exact match)')
    .option('--json', 'Emit JSON array instead of human-readable table')
    .action((opts: {
      performer?: string;
      self?: boolean;
      task?: string;
      chain?: string;
      since?: string;
      action?: string;
      json?: boolean;
    }) => {
      try {
        if (ctx.traceLog === undefined) {
          process.stderr.write('FAIL: traceLog not available in current context (CLI not bootstrapped)\n');
          process.exit(1);
        }

        let sinceMs: number | null = null;
        if (opts.since !== undefined) {
          sinceMs = parseSince(opts.since);
          if (sinceMs === null) {
            process.stderr.write(`FAIL: invalid --since value: ${opts.since} (expected 30s / 15m / 1h / 2d)\n`);
            process.exit(1);
          }
        }

        const selfId = opts.self === true ? resolveCurrentInstanceId() : null;
        if (opts.self === true && selfId === null) {
          process.stderr.write('FAIL: --self requires KALLAX_PERFORMER_ID or KALLAX_INSTANCE_ID env var\n');
          process.exit(1);
        }
        const performerFilter = opts.performer ?? selfId;

        // Fetch each candidate source, then merge + filter.
        const candidates: Array<{ source: string; rows: ReadonlyArray<ReturnType<typeof ctx.traceLog.getPerformerTrace>>[0] }> = [];
        if (opts.chain !== undefined) {
          candidates.push({ source: 'chain', rows: ctx.traceLog.getChain(opts.chain) });
        }
        if (performerFilter !== null) {
          candidates.push({ source: 'performer', rows: ctx.traceLog.getPerformerTrace(performerFilter) });
        }
        if (opts.task !== undefined) {
          candidates.push({ source: 'task', rows: ctx.traceLog.getTaskTrace(opts.task) });
        }
        if (candidates.length === 0) {
          process.stderr.write('FAIL: at least one filter required (--performer / --self / --task / --chain)\n');
          process.exit(1);
        }

        const cutoff = sinceMs === null ? 0 : Date.now() - sinceMs;
        const seen = new Set<string>();
        const merged: unknown[] = [];
        for (const { rows } of candidates) {
          for (const row of rows) {
            if (seen.has(row.traceId)) continue;
            if (cutoff > 0 && row.timestamp < cutoff) continue;
            if (opts.action !== undefined && row.action !== opts.action) continue;
            seen.add(row.traceId);
            merged.push(row);
          }
        }
        merged.sort((a, b) => (a as { timestamp: number }).timestamp - (b as { timestamp: number }).timestamp);

        if (opts.json === true) {
          process.stdout.write(JSON.stringify(merged, null, 2) + '\n');
          return;
        }

        const table = merged.map((row) => {
          const r = row as { traceId: string; timestamp: number; actor: string; action: string; target: string; result: string; detail: Record<string, unknown> };
          const profilePath = (r.detail as { profilePath?: string | undefined }).profilePath;
          const detailRows: Record<string, unknown> = {
              traceId: r.traceId,
              timestamp: new Date(r.timestamp).toISOString(),
              duration: `${String(durationMs(r.timestamp, Date.now()))}ms`,
              actor: r.actor,
              action: r.action,
              target: r.target,
              result: badgeFor(r.result),
              profilePath: profilePath ?? '-',
              detail: JSON.stringify(r.detail),
            };
          return detailRows;
        });
        process.stdout.write(asTable(table) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}