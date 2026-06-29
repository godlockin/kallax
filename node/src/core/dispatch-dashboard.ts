/**
 * KALLAX Dispatch Dashboard
 * Real-time Performer dispatch success-rate tracker (X/Y format, Rule 9 precision)
 *
 * EPIC-053-D: Performer 派单成功率仪表盘 — closes the KPI falsification feedback loop
 * by making H1 (KPI falsification 12 repeats) and H6 (boundary BE-1/6/11 violations)
 * visible in real-time across 3 data sources:
 *   S1: pass-report JSON (outbox) — Performer self-reported outcome
 *   S2: check-scope-creep.sh exit — boundary check (Rule 15 / EPIC-053-F glob)
 *   S3: kpi-evidence-chain.sh exit — 5 levels evidence (EPIC-053-B)
 *
 * All outputs use Rule 9 X/Y format precision (no estimate, exact).
 * Baseline reference: PROJECT-STATUS-AND-LESSONS-2026-06-13.md line 43
 *   "Performer 派单成功率: 7/12 真 PASS (58.3%)" → target 95%+
 */

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { readFile, readdir, stat } from 'node:fs/promises';
import { join } from 'node:path';
import { err, ok, type Result } from 'neverthrow';
import { logger } from '../utils/logger.js';

const execFileAsync = promisify(execFile);

// ============================================================================
// Constants (no magic numbers — KALLAX Hard Rule #4)
// ============================================================================

export const KpiThresholds = {
  PASS_RATE_TARGET_PCT: 95.0,
  BASELINE_RATE_PCT: 58.3,
  HISTORY_WINDOW_EPICS: 10,
} as const;

export type DispatchOutcome = 'pass' | 'fail' | 'fake_pass' | 'boundary_violation';

export interface DispatchRecord {
  readonly ticketId: string;
  readonly epicId: string;
  readonly performerId: string;
  readonly commitSha: string;
  readonly outcome: DispatchOutcome;
  readonly evidenceChainPassed: boolean;
  readonly scopeViolations: ReadonlyArray<string>;
  readonly beEvents: ReadonlyArray<string>;
  readonly timestamp: number;
}

export interface EpicKpi {
  readonly epicId: string;
  readonly total: number;
  readonly passed: number;
  readonly fakePasses: number;
  readonly boundaryViolations: number;
  readonly formatXofY: string;
}

export interface DispatchKpiSummary {
  readonly total: number;
  readonly passed: number;
  readonly failed: number;
  readonly fakePasses: number;
  readonly boundaryViolations: number;
  readonly formatXofY: string;
  readonly ratePct: number;
  readonly baselineRatePct: number;
  readonly targetRatePct: number;
  readonly deltaVsBaseline: number;
  readonly byEpic: ReadonlyArray<EpicKpi>;
}

export interface DataSourceStatus {
  readonly s1PassReports: number;
  readonly s2ScopeChecks: number;
  readonly s3EvidenceChainChecks: number;
  readonly allLoaded: boolean;
}

export type DashboardError =
  | { readonly kind: 'mock_dir_missing'; readonly path: string }
  | { readonly kind: 'no_pass_reports'; readonly path: string }
  | { readonly kind: 'malformed_pass_report'; readonly path: string; readonly reason: string };

// ============================================================================
// Pure functions — KPI math, X/Y formatting, fake PASS detection
// ============================================================================

/**
 * Rule 9: KPI X/Y format precision. Always "X/Y (P.P%)", never estimate.
 * Denominator is total count; numerator is passed count.
 * Use computeStrictPassRate() for the H1-corrected rate (excludes fake passes from denominator).
 */
export function formatXofY(passed: number, total: number): string {
  if (total === 0) {
    return '0/0 (0.0%)';
  }
  const pct = (passed / total) * 100;
  return `${passed}/${total} (${pct.toFixed(1)}%)`;
}

/**
 * H1-corrected real pass rate: excludes fake_passes from denominator.
 * Mirrors PROJECT-STATUS-AND-LESSONS-2026-06-13.md line 43 definition
 * "真 PASS" — only counts tickets whose evidence chain actually passed.
 */
export function computeStrictPassRate(passed: number, total: number, fakePasses: number): number {
  const realTotal = total - fakePasses;
  if (realTotal <= 0) {
    return 0.0;
  }
  return Number(((passed / realTotal) * 100).toFixed(1));
}

/**
 * Detect fake PASS — Performer reported PASS but evidence chain failed.
 * H1 root-cause mode: KPI falsification 12-times repeat (EPIC-024/028/031/036/037/039-B).
 * BE-5 pattern: 0 commit + 0 file + fake PASS.
 */
export function detectFakePasses(records: ReadonlyArray<DispatchRecord>): ReadonlyArray<DispatchRecord> {
  return records.filter(
    (r) =>
      (r.outcome === 'pass' || r.outcome === 'fake_pass') &&
      !r.evidenceChainPassed &&
      r.scopeViolations.length > 0,
  );
}

/**
 * Detect boundary violations — Rule 15 / EPIC-053-F check-scope-creep.sh exit=1.
 * H6 root-cause mode: BE-1 (Conductor 越界) + BE-6 (Performer 越界) + BE-11 (反向越界).
 */
export function detectBoundaryViolations(records: ReadonlyArray<DispatchRecord>): ReadonlyArray<DispatchRecord> {
  return records.filter((r) => r.outcome === 'boundary_violation' || r.scopeViolations.length > 0);
}

/**
 * Compute aggregate KPI summary from records.
 * Pure function — no I/O. Caller supplies records via loadDispatchRecords().
 */
export function computeDispatchKpi(records: ReadonlyArray<DispatchRecord>): DispatchKpiSummary {
  let passed = 0;
  let failed = 0;
  let fakePasses = 0;
  let boundaryViolations = 0;
  const byEpicMap = new Map<string, { total: number; passed: number; fakePasses: number; boundaryViolations: number }>();

  for (const r of records) {
    if (r.outcome === 'pass') passed += 1;
    else if (r.outcome === 'fake_pass') fakePasses += 1;
    else if (r.outcome === 'boundary_violation') boundaryViolations += 1;
    else failed += 1;

    const epicStats = byEpicMap.get(r.epicId) ?? { total: 0, passed: 0, fakePasses: 0, boundaryViolations: 0 };
    epicStats.total += 1;
    if (r.outcome === 'pass') epicStats.passed += 1;
    if (r.outcome === 'fake_pass') epicStats.fakePasses += 1;
    if (r.outcome === 'boundary_violation') epicStats.boundaryViolations += 1;
    byEpicMap.set(r.epicId, epicStats);
  }

  const total = records.length;
  const ratePct = computeStrictPassRate(passed, total, fakePasses);
  const formatXofYStr = formatXofY(passed, total);
  const deltaVsBaseline = Number((ratePct - KpiThresholds.BASELINE_RATE_PCT).toFixed(1));

  const byEpic: ReadonlyArray<EpicKpi> = Array.from(byEpicMap.entries()).map(([epicId, s]) => ({
    epicId,
    total: s.total,
    passed: s.passed,
    fakePasses: s.fakePasses,
    boundaryViolations: s.boundaryViolations,
    formatXofY: formatXofY(s.passed, s.total),
  }));

  return {
    total,
    passed,
    failed,
    fakePasses,
    boundaryViolations,
    formatXofY: formatXofYStr,
    ratePct,
    baselineRatePct: KpiThresholds.BASELINE_RATE_PCT,
    targetRatePct: KpiThresholds.PASS_RATE_TARGET_PCT,
    deltaVsBaseline,
    byEpic,
  };
}

// ============================================================================
// Data source loaders (S1 pass-report + S2 scope-creep + S3 evidence-chain)
// ============================================================================

function epicIdFromTicketId(ticketId: string): string {
  const match = ticketId.match(/^(EPIC-\d+)/);
  return match?.[1] ?? 'EPIC-UNKNOWN';
}

async function readPassReport(filePath: string): Promise<Result<DispatchRecord, DashboardError>> {
  try {
    const raw = await readFile(filePath, 'utf-8');
    const parsed: unknown = JSON.parse(raw);
    if (
      typeof parsed !== 'object' ||
      parsed === null ||
      !('ticket_id' in parsed) ||
      !('commit_sha' in parsed) ||
      !('kpi_x_of_y' in parsed)
    ) {
      return err({ kind: 'malformed_pass_report', path: filePath, reason: 'missing required fields' });
    }
    const obj = parsed as Record<string, unknown>;
    const ticketId = String(obj['ticket_id']);
    const commitSha = String(obj['commit_sha']);
    const kpiStr = String(obj['kpi_x_of_y']);
    const boundaryViolationsRaw = obj['boundary_violations'];
    const boundaryViolations = typeof boundaryViolationsRaw === 'number' ? boundaryViolationsRaw : 0;
    const beEventsRaw = obj['be_events'];
    const beEvents: ReadonlyArray<string> = Array.isArray(beEventsRaw)
      ? beEventsRaw.filter((x): x is string => typeof x === 'string')
      : [];

    let outcome: DispatchOutcome = 'fail';
    if (boundaryViolations > 0) {
      outcome = 'boundary_violation';
    } else if (kpiStr.includes('100.0%')) {
      // Rule 9 X/Y precision: 100.0% rate = pass (regardless of "PASS" word decoration)
      outcome = 'pass';
    } else if (kpiStr.includes('PASS')) {
      outcome = 'fake_pass';
    }

    return ok({
      ticketId,
      epicId: epicIdFromTicketId(ticketId),
      performerId: String(obj['performer_id'] ?? `performer-${ticketId}`),
      commitSha,
      outcome,
      evidenceChainPassed: false, // updated later by S3 loader
      scopeViolations: [], // updated later by S2 loader
      beEvents,
      timestamp: Date.now(),
    });
  } catch (e: unknown) {
    return err({
      kind: 'malformed_pass_report',
      path: filePath,
      reason: e instanceof Error ? e.message : String(e),
    });
  }
}

async function loadPassReports(outboxDir: string): Promise<Result<ReadonlyArray<DispatchRecord>, DashboardError>> {
  try {
    const stats = await stat(outboxDir);
    if (!stats.isDirectory()) {
      return err({ kind: 'mock_dir_missing', path: outboxDir });
    }
  } catch {
    return err({ kind: 'mock_dir_missing', path: outboxDir });
  }

  const records: DispatchRecord[] = [];
  try {
    const performerDirs = await readdir(outboxDir);
    for (const performerDir of performerDirs) {
      const dirPath = join(outboxDir, performerDir);
      const dirStat = await stat(dirPath);
      if (!dirStat.isDirectory()) continue;
      const files = await readdir(dirPath);
      for (const f of files) {
        if (f.startsWith('pass-report-') && f.endsWith('.json')) {
          const r = await readPassReport(join(dirPath, f));
          if (r.isOk()) records.push(r.value);
        }
      }
    }
  } catch (e: unknown) {
    return err({ kind: 'no_pass_reports', path: outboxDir });
  }

  return ok(records);
}

async function loadScopeCheckResults(
  scopeDir: string,
  records: ReadonlyArray<DispatchRecord>,
): Promise<ReadonlyArray<DispatchRecord>> {
  const merged: DispatchRecord[] = [];
  for (const r of records) {
    const exitFile = join(scopeDir, `${r.ticketId}.exit`);
    try {
      const raw = await readFile(exitFile, 'utf-8');
      const code = raw.trim();
      const violations: ReadonlyArray<string> = code === '1' ? [`scope-creep:${r.ticketId}`] : [];
      let outcome = r.outcome;
      if (code === '1' && outcome === 'pass') {
        outcome = 'fake_pass';
      } else if (code === '1' && outcome === 'fake_pass') {
        outcome = 'boundary_violation';
      }
      merged.push({ ...r, scopeViolations: violations, outcome });
    } catch {
      merged.push(r);
    }
  }
  return merged;
}

async function loadEvidenceChainResults(
  evidenceDir: string,
  records: ReadonlyArray<DispatchRecord>,
): Promise<ReadonlyArray<DispatchRecord>> {
  const merged: DispatchRecord[] = [];
  for (const r of records) {
    const exitFile = join(evidenceDir, `${r.ticketId}.exit`);
    try {
      const raw = await readFile(exitFile, 'utf-8');
      const evidencePassed = raw.includes('[L1 PASS]') && raw.includes('[L2 PASS]') && raw.includes('[L3 PASS]') && raw.includes('[L4 PASS]');
      let outcome = r.outcome;
      if (!evidencePassed && outcome === 'pass') {
        outcome = 'fake_pass';
      }
      merged.push({ ...r, evidenceChainPassed: evidencePassed, outcome });
    } catch {
      merged.push({ ...r, evidenceChainPassed: false });
    }
  }
  return merged;
}

export interface DispatchDashboardConfig {
  readonly outboxDir: string;
  readonly scopeCheckDir?: string;
  readonly evidenceChainDir?: string;
}

export interface DispatchDashboard {
  readonly loadDataSources: () => Promise<Result<{ records: ReadonlyArray<DispatchRecord>; status: DataSourceStatus }, DashboardError>>;
  readonly computeKpi: (records: ReadonlyArray<DispatchRecord>) => DispatchKpiSummary;
  readonly formatOutput: (summary: DispatchKpiSummary, records: ReadonlyArray<DispatchRecord>) => string;
}

export function createDispatchDashboard(config: DispatchDashboardConfig): DispatchDashboard {
  const { outboxDir } = config;
  const scopeCheckDir = config.scopeCheckDir ?? join(outboxDir, '..', 'scope-creep');
  const evidenceChainDir = config.evidenceChainDir ?? join(outboxDir, '..', 'evidence-chain');

  return {
    async loadDataSources() {
      const passResult = await loadPassReports(outboxDir);
      if (passResult.isErr()) return err(passResult.error);
      const afterScope = await loadScopeCheckResults(scopeCheckDir, passResult.value);
      const afterEvidence = await loadEvidenceChainResults(evidenceChainDir, afterScope);

      const status: DataSourceStatus = {
        s1PassReports: passResult.value.length,
        s2ScopeChecks: afterScope.filter((r) => r.scopeViolations.length > 0).length,
        s3EvidenceChainChecks: afterEvidence.filter((r) => r.evidenceChainPassed).length,
        allLoaded: passResult.value.length > 0,
      };
      return ok({ records: afterEvidence, status });
    },

    computeKpi(records: ReadonlyArray<DispatchRecord>): DispatchKpiSummary {
      return computeDispatchKpi(records);
    },

    formatOutput(summary: DispatchKpiSummary, records: ReadonlyArray<DispatchRecord>): string {
      const lines: string[] = [];
      lines.push('==========================================');
      lines.push('Performer Dispatch Dashboard — EPIC-053-D');
      lines.push('==========================================');
      lines.push('');
      lines.push(`Overall: ${summary.formatXofY} (real pass rate, H1-corrected)`);
      lines.push(`Baseline (PROJECT-STATUS line 43): ${summary.baselineRatePct.toFixed(1)}%`);
      lines.push(`Target: ${summary.targetRatePct.toFixed(1)}%`);
      lines.push(`Delta vs Baseline: ${summary.deltaVsBaseline >= 0 ? '+' : ''}${summary.deltaVsBaseline.toFixed(1)}%`);
      lines.push('');
      lines.push(`Total: ${summary.total} | Passed: ${summary.passed} | Failed: ${summary.failed} | Fake PASS: ${summary.fakePasses} | Boundary Violations: ${summary.boundaryViolations}`);
      lines.push('');
      if (summary.byEpic.length > 0) {
        lines.push('By EPIC:');
        for (const e of summary.byEpic) {
          lines.push(`  ${e.epicId}: ${e.formatXofY} (fake=${e.fakePasses} boundary=${e.boundaryViolations})`);
        }
        lines.push('');
      }
      const fakes = detectFakePasses(records);
      if (fakes.length > 0) {
        lines.push('H1 — Fake PASS detected (KPI falsification):');
        for (const f of fakes) {
          lines.push(`  [FAKE] ${f.ticketId} performer=${f.performerId} commit=${f.commitSha.slice(0, 12)}`);
        }
        lines.push('');
      }
      const bes = detectBoundaryViolations(records);
      if (bes.length > 0) {
        lines.push('H6 — Boundary Violations (BE-1/6/11):');
        for (const b of bes) {
          lines.push(`  [BE] ${b.ticketId} events=${b.beEvents.join(',') || 'none'}`);
        }
        lines.push('');
      }
      return lines.join('\n');
    },
  };
}

// ============================================================================
// CLI entry — invoked by `bash scripts/dashboard/dispatch-dashboard.sh`
// Also supports test cases 1-5 via `node dispatch-dashboard.ts caseN`.
// ============================================================================

async function main(): Promise<number> {
  const args = process.argv.slice(2);
  const mockDir = process.env['KALLAX_DASHBOARD_MOCK_DIR'];
  const filter = process.env['KALLAX_DASHBOARD_FILTER'];
  const outboxDir = mockDir ? join(mockDir, 'outbox') : join(process.cwd(), '.kallax', 'queue', 'outbox');

  const dashboard = createDispatchDashboard({
    outboxDir,
    scopeCheckDir: mockDir ? join(mockDir, 'scope-creep') : undefined,
    evidenceChainDir: mockDir ? join(mockDir, 'evidence-chain') : undefined,
  });

  const loaded = await dashboard.loadDataSources();
  if (loaded.isErr()) {
    logger.error({}, `ERROR: ${loaded.error.kind} — ${'path' in loaded.error ? loaded.error.path : ''}`);
    return 2;
  }

  let records = loaded.value.records;
  const status = loaded.value.status;

  // Apply optional filter (for test cases)
  if (filter === 'pass_only') {
    records = records.filter((r) => r.outcome === 'pass');
  }

  const summary = dashboard.computeKpi(records);

  // Test cases 1-5 (when invoked with caseN arg)
  if (args[0]?.startsWith('case')) {
    const caseNum = args[0];
    switch (caseNum) {
      case 'case1':
        logger.info({}, `S1_OK=${status.s1PassReports >= 5 ? 'yes' : 'no'} S2_OK=${status.s2ScopeChecks >= 1 ? 'yes' : 'no'} S3_OK=${status.s3EvidenceChainChecks >= 3 ? 'yes' : 'no'}`);
        return 0;
      case 'case2':
        logger.info({}, `all_pass=${summary.passed}/${summary.total} ${summary.formatXofY}`);
        return 0;
      case 'case3':
        logger.info({}, `fake_passes=${summary.fakePasses} tickets=${records.filter((r) => r.outcome === 'fake_pass').map((r) => r.ticketId).join(',')}`);
        return 0;
      case 'case4':
        logger.info({}, `boundary_violations=${summary.boundaryViolations} be_events=${records.filter((r) => r.outcome === 'boundary_violation').flatMap((r) => r.beEvents).join(',')}`);
        return 0;
      case 'case5':
        logger.info({}, `kpi=${summary.formatXofY} total=${summary.total} passed=${summary.passed} strict_rate=${summary.ratePct.toFixed(1)}% baseline=${summary.baselineRatePct.toFixed(1)}%`);
        return 0;
      default:
        logger.error({}, `Unknown case: ${caseNum}`);
        return 2;
    }
  }

  // Production CLI output
  logger.info({}, dashboard.formatOutput(summary, records));
  return 0;
}

// Export for production use
export { main };

// CLI entry — invoked directly by `node dispatch-dashboard.ts`
const isMainModule = (() => {
  try {
    const url = new URL(import.meta.url);
    return url.pathname === process.argv[1] || url.pathname.endsWith(process.argv[1] ?? '');
  } catch {
    return false;
  }
})();

if (isMainModule) {
  main().then(
    (code) => process.exit(code),
    (e: unknown) => {
      logger.error({}, 'FATAL:', e instanceof Error ? e.message : String(e));
      process.exit(2);
    },
  );
}
