#!/usr/bin/env -S node --experimental-strip-types
/**
 * KALLAX Process Metrics — EPIC-056-B
 * 3 KPI 度量: 派单成功率 / 平均周期 / 越界率
 *
 * Rule 9 KPI X/Y 格式: 6/6 = 100.0% (1 位小数, no estimate, no "~")
 * Rule 11 强验证: 跟 11 BE 累计 + 6 痛点 联合
 * Rule 15 file_scope: 严格不动 docs/PROCESS.md
 *
 * CLI Usage:
 *   process-metrics.ts dispatch-rate --tickets-dir <dir>
 *   process-metrics.ts cycle-time    --tickets-dir <dir>
 *   process-metrics.ts violation-rate --tickets-dir <dir>
 *   process-metrics.ts trend         --tickets-dir <dir>
 *   process-metrics.ts check-targets --tickets-dir <dir>
 *   process-metrics.ts dashboard     --tickets-dir <dir>
 *
 * Target values (跟 PHASE-009 跟 EPIC-053-D 联动):
 *   dispatch-rate >= 95.0%
 *   cycle-time    <= 8.0h
 *   violation-rate <= 0.0%
 */

import * as fs from 'node:fs';
import * as path from 'node:path';

interface TicketData {
  readonly id: string;
  readonly status: string;
  readonly created_at: string;
  readonly completed_at: string | null;
  readonly estimated_hours: number;
  readonly be_event: string | null;
  readonly file_scope: { includes: string[]; excludes: string[] };
}

interface KPIData {
  readonly label: string;
  readonly numerator: number;
  readonly denominator: number;
  readonly percentage: number;
  readonly raw_value: number;
  readonly target_value: number;
  readonly status: 'PASS' | 'WARN' | 'CRITICAL';
  readonly formatted: string;
}

interface TargetsConfig {
  readonly dispatchRatePercent: number;
  readonly cycleHoursMax: number;
  readonly violationRatePercent: number;
}

const TARGETS: TargetsConfig = {
  dispatchRatePercent: 95.0,
  cycleHoursMax: 8.0,
  violationRatePercent: 0.0,
};

const WARN_MARGIN = 0.10;

function parseArgs(argv: readonly string[]): { ticketsDir: string } {
  const args = argv.slice(2);
  let ticketsDir = '';
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--tickets-dir' && i + 1 < args.length) {
      ticketsDir = args[i + 1] ?? '';
      i++;
    }
  }
  if (!ticketsDir) {
    process.stderr.write('ERROR: --tickets-dir <path> required\n');
    process.exit(2);
  }
  if (!fs.existsSync(ticketsDir)) {
    process.stderr.write(`ERROR: tickets dir not found: ${ticketsDir}\n`);
    process.exit(2);
  }
  return { ticketsDir };
}

function readTickets(ticketsDir: string): TicketData[] {
  const tickets: TicketData[] = [];
  const entries = fs.readdirSync(ticketsDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const ticketPath = path.join(ticketsDir, entry.name, 'ticket.json');
    if (!fs.existsSync(ticketPath)) continue;
    const raw = fs.readFileSync(ticketPath, 'utf-8');
    const parsed: unknown = JSON.parse(raw);
    if (!isTicketData(parsed)) {
      process.stderr.write(`WARN: skipping malformed ticket ${ticketPath}\n`);
      continue;
    }
    tickets.push(parsed);
  }
  return tickets;
}

function isTicketData(value: unknown): value is TicketData {
  if (typeof value !== 'object' || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    typeof v['id'] === 'string' &&
    typeof v['status'] === 'string' &&
    typeof v['created_at'] === 'string' &&
    (typeof v['completed_at'] === 'string' || v['completed_at'] === null) &&
    typeof v['estimated_hours'] === 'number' &&
    (typeof v['be_event'] === 'string' || v['be_event'] === null) &&
    typeof v['file_scope'] === 'object' &&
    v['file_scope'] !== null
  );
}

function formatXY(numerator: number, denominator: number, percentage: number): string {
  return `${numerator}/${denominator} (${percentage.toFixed(1)}%)`;
}

function formatHours(hours: number): string {
  return `${hours.toFixed(1)}h`;
}

function computeDispatchRate(tickets: readonly TicketData[]): KPIData {
  const denominator = tickets.length;
  const numerator = tickets.filter(t => t.status === 'done').length;
  const percentage = denominator === 0 ? 0 : (numerator / denominator) * 100;
  const status = evaluateDispatchStatus(percentage);
  return {
    label: '派单成功率',
    numerator,
    denominator,
    percentage,
    raw_value: percentage,
    target_value: TARGETS.dispatchRatePercent,
    status,
    formatted: formatXY(numerator, denominator, percentage),
  };
}

function evaluateDispatchStatus(percentage: number): 'PASS' | 'WARN' | 'CRITICAL' {
  if (percentage >= TARGETS.dispatchRatePercent) return 'PASS';
  if (percentage >= TARGETS.dispatchRatePercent - 85.0) return 'WARN';
  return 'CRITICAL';
}

function computeCycleTime(tickets: readonly TicketData[]): KPIData {
  const completed = tickets.filter(
    (t): t is TicketData & { completed_at: string } => t.completed_at !== null
  );
  const denominator = completed.length;
  if (denominator === 0) {
    return {
      label: '平均周期',
      numerator: 0,
      denominator: 0,
      percentage: 0,
      raw_value: 0,
      target_value: TARGETS.cycleHoursMax,
      status: 'CRITICAL',
      formatted: formatHours(0),
    };
  }
  let totalHours = 0;
  for (const t of completed) {
    const start = new Date(t.created_at).getTime();
    const end = new Date(t.completed_at).getTime();
    const diffMs = end - start;
    const hours = diffMs / (1000 * 60 * 60);
    totalHours += hours;
  }
  const avgHours = totalHours / denominator;
  const status = evaluateCycleStatus(avgHours);
  return {
    label: '平均周期',
    numerator: denominator,
    denominator: denominator,
    percentage: 0,
    raw_value: avgHours,
    target_value: TARGETS.cycleHoursMax,
    status,
    formatted: formatHours(avgHours),
  };
}

function evaluateCycleStatus(hours: number): 'PASS' | 'WARN' | 'CRITICAL' {
  if (hours <= TARGETS.cycleHoursMax) return 'PASS';
  if (hours <= TARGETS.cycleHoursMax * (1 + WARN_MARGIN)) return 'WARN';
  return 'CRITICAL';
}

function computeViolationRate(tickets: readonly TicketData[]): KPIData {
  const denominator = tickets.length;
  const numerator = tickets.filter(t => t.be_event !== null).length;
  const percentage = denominator === 0 ? 0 : (numerator / denominator) * 100;
  const status = evaluateViolationStatus(percentage);
  return {
    label: '越界率',
    numerator,
    denominator,
    percentage,
    raw_value: percentage,
    target_value: TARGETS.violationRatePercent,
    status,
    formatted: formatXY(numerator, denominator, percentage),
  };
}

function evaluateViolationStatus(percentage: number): 'PASS' | 'WARN' | 'CRITICAL' {
  if (percentage <= TARGETS.violationRatePercent) return 'PASS';
  if (percentage <= TARGETS.violationRatePercent + 5.0) return 'WARN';
  return 'CRITICAL';
}

interface TrendBucket {
  readonly epic: string;
  readonly dispatch: KPIData;
  readonly cycle: KPIData;
  readonly violation: KPIData;
}

function computeTrend(tickets: readonly TicketData[]): readonly TrendBucket[] {
  const buckets = new Map<string, TicketData[]>();
  for (const t of tickets) {
    const epic = extractEpic(t.id);
    const list = buckets.get(epic) ?? [];
    list.push(t);
    buckets.set(epic, list);
  }
  const result: TrendBucket[] = [];
  for (const [epic, list] of buckets) {
    result.push({
      epic,
      dispatch: computeDispatchRate(list),
      cycle: computeCycleTime(list),
      violation: computeViolationRate(list),
    });
  }
  result.sort((a, b) => a.epic.localeCompare(b.epic));
  return result;
}

function extractEpic(ticketId: string): string {
  const match = ticketId.match(/^(EPIC-\d+)/);
  return match && match[1] ? match[1] : 'UNKNOWN';
}

interface TargetsCheckResult {
  readonly allPass: boolean;
  readonly details: readonly string[];
  readonly exitCode: number;
}

function checkTargets(
  dispatch: KPIData,
  cycle: KPIData,
  violation: KPIData
): TargetsCheckResult {
  const details: string[] = [];
  details.push(`dispatch-rate: ${dispatch.formatted} target=${dispatch.target_value}% status=${dispatch.status}`);
  details.push(`cycle-time: ${cycle.formatted} target=${cycle.target_value}h status=${cycle.status}`);
  details.push(`violation-rate: ${violation.formatted} target=${violation.target_value}% status=${violation.status}`);
  const allPass =
    dispatch.status === 'PASS' &&
    cycle.status === 'PASS' &&
    violation.status === 'PASS';
  return {
    allPass,
    details,
    exitCode: allPass ? 0 : 1,
  };
}

function dashboard(tickets: readonly TicketData[]): string {
  const dispatch = computeDispatchRate(tickets);
  const cycle = computeCycleTime(tickets);
  const violation = computeViolationRate(tickets);
  const trend = computeTrend(tickets);
  const targets = checkTargets(dispatch, cycle, violation);

  const lines: string[] = [];
  lines.push('==========================================');
  lines.push('KALLAX 3 KPI Dashboard — EPIC-056-B');
  lines.push('==========================================');
  lines.push(`Tickets analyzed: ${tickets.length}`);
  lines.push('');
  lines.push('--- KPI Summary (X/Y format, Rule 9) ---');
  lines.push(`[${dispatch.status}] 派单成功率: ${dispatch.formatted}  target=${dispatch.target_value}%`);
  lines.push(`[${cycle.status}] 平均周期: ${cycle.formatted}  target=${cycle.target_value}h`);
  lines.push(`[${violation.status}] 越界率: ${violation.formatted}  target=${violation.target_value}%`);
  lines.push('');

  const anomalyCount = [dispatch, cycle, violation].filter(k => k.status !== 'PASS').length;
  if (anomalyCount > 0) {
    lines.push(`--- ANOMALY ALERTS (${anomalyCount} KPI(s) outside target) ---`);
    if (dispatch.status === 'CRITICAL') lines.push(`CRITICAL: dispatch-rate ${dispatch.formatted} < 85%`);
    if (cycle.status === 'CRITICAL') lines.push(`CRITICAL: cycle-time ${cycle.formatted} > ${TARGETS.cycleHoursMax * (1 + WARN_MARGIN)}h`);
    if (violation.status === 'CRITICAL') lines.push(`CRITICAL: violation-rate ${violation.formatted} > 5%`);
    if (dispatch.status === 'WARN') lines.push(`WARN: dispatch-rate ${dispatch.formatted} below target ${dispatch.target_value}%`);
    if (cycle.status === 'WARN') lines.push(`WARN: cycle-time ${cycle.formatted} above target ${cycle.target_value}h`);
    if (violation.status === 'WARN') lines.push(`WARN: violation-rate ${violation.formatted} above target ${violation.target_value}%`);
    lines.push('');
  }

  lines.push('--- Historical Trend (by EPIC) ---');
  for (const bucket of trend) {
    lines.push(
      `${bucket.epic}: dispatch=${bucket.dispatch.formatted} cycle=${bucket.cycle.formatted} violation=${bucket.violation.formatted}`
    );
  }
  lines.push('');

  lines.push('--- Target Check ---');
  for (const detail of targets.details) {
    lines.push(detail);
  }
  lines.push('');
  lines.push(`Result: ${targets.allPass ? 'ALL TARGETS MET' : 'TARGETS NOT MET'}`);
  return lines.join('\n');
}

function cmdDispatchRate(tickets: readonly TicketData[]): void {
  const kpi = computeDispatchRate(tickets);
  process.stdout.write(`${kpi.formatted}\n`);
}

function cmdCycleTime(tickets: readonly TicketData[]): void {
  const kpi = computeCycleTime(tickets);
  process.stdout.write(`${kpi.formatted}\n`);
}

function cmdViolationRate(tickets: readonly TicketData[]): void {
  const kpi = computeViolationRate(tickets);
  process.stdout.write(`${kpi.formatted}\n`);
}

function cmdTrend(tickets: readonly TicketData[]): void {
  const trend = computeTrend(tickets);
  for (const bucket of trend) {
    process.stdout.write(
      `${bucket.epic}: ${bucket.dispatch.formatted} | ${bucket.cycle.formatted} | ${bucket.violation.formatted}\n`
    );
  }
}

function cmdCheckTargets(tickets: readonly TicketData[]): void {
  const dispatch = computeDispatchRate(tickets);
  const cycle = computeCycleTime(tickets);
  const violation = computeViolationRate(tickets);
  const result = checkTargets(dispatch, cycle, violation);
  for (const detail of result.details) {
    process.stdout.write(`${detail}\n`);
  }
  process.stdout.write(`\nALL_PASS=${result.allPass ? 'YES' : 'NO'}\n`);
  process.exit(result.exitCode);
}

function cmdDashboard(tickets: readonly TicketData[]): void {
  process.stdout.write(`${dashboard(tickets)}\n`);
}

function main(argv: readonly string[]): void {
  const args = argv.slice(2);
  const subcommand = args[0];
  if (!subcommand || subcommand === '-h' || subcommand === '--help') {
    process.stdout.write(
      'Usage: process-metrics.ts <subcommand> --tickets-dir <path>\n' +
        'Subcommands: dispatch-rate | cycle-time | violation-rate | trend | check-targets | dashboard\n'
    );
    process.exit(0);
  }
  const { ticketsDir } = parseArgs(argv);
  const tickets = readTickets(ticketsDir);

  switch (subcommand) {
    case 'dispatch-rate':
      cmdDispatchRate(tickets);
      break;
    case 'cycle-time':
      cmdCycleTime(tickets);
      break;
    case 'violation-rate':
      cmdViolationRate(tickets);
      break;
    case 'trend':
      cmdTrend(tickets);
      break;
    case 'check-targets':
      cmdCheckTargets(tickets);
      break;
    case 'dashboard':
      cmdDashboard(tickets);
      break;
    default:
      process.stderr.write(`ERROR: unknown subcommand: ${subcommand}\n`);
      process.exit(2);
  }
}

main(process.argv);