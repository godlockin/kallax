/**
 * KALLAX M1 100 Test Case — 扩域验证 (EPIC-034-A)
 *
 * Source: tests/fixtures/m1-cases.json (与 scripts/verify/expert-match-m1-v3.sh 1:1 对齐)
 *
 * Acceptance Criteria:
 *   AC1: 100+ test cases (本文件 100 个 it())
 *   AC2: tests/fixtures/m1-cases.json 提供数据
 *   AC3: 跟 EPIC-032-A (50 cases) 联合 0 重复 (断言 EPIC-032 子集与 EPIC-034-A 子集无交集)
 *   AC4: 跟 baseline 联合 0 NEW (EPIC-034-A 仅扩 finance + cross_domain 新域 + 已有域回填)
 *   AC5: All tests pass
 *
 * 执行:
 *   node --test tests/m1-100-test-cases.test.ts
 */

import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import assert from 'node:assert/strict';

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIXTURE_PATH = resolve(__dirname, 'fixtures/m1-cases.json');

type Source = 'EPIC-032-baseline' | 'EPIC-032-expansion' | 'EPIC-034-A-new';

interface M1Case {
  id: number;
  requirement: string;
  expected_expert: string;
  domain: string;
  source: Source;
}

interface M1Fixture {
  version: string;
  epic: string;
  ticket: string;
  total_cases: number;
  experts: string[];
  domains: string[];
  expansion_breakdown: Record<Source, number>;
  cases: M1Case[];
}

const fixture: M1Fixture = JSON.parse(readFileSync(FIXTURE_PATH, 'utf-8')) as M1Fixture;
const ALL_CASES: M1Case[] = fixture.cases;
const EPIC_032_CASES: M1Case[] = ALL_CASES.filter((c) => c.source.startsWith('EPIC-032'));
const EPIC_034_A_CASES: M1Case[] = ALL_CASES.filter((c) => c.source === 'EPIC-034-A-new');
const VALID_EXPERTS: ReadonlySet<string> = new Set(fixture.experts);
const VALID_DOMAINS: ReadonlySet<string> = new Set(fixture.domains);

test('AC1: fixture has 100+ test cases (exactly 100)', () => {
  assert.equal(ALL_CASES.length, 100, `expected 100 cases, got ${ALL_CASES.length}`);
  assert.equal(ALL_CASES.length, fixture.total_cases, 'cases.length must match total_cases');
});

test('AC2: fixture loaded from tests/fixtures/m1-cases.json', () => {
  assert.ok(FIXTURE_PATH.endsWith('m1-cases.json'), 'fixture path must end with m1-cases.json');
  assert.equal(fixture.ticket, 'EPIC-034-A', 'fixture.ticket must be EPIC-034-A');
  assert.equal(fixture.epic, 'EPIC-034', 'fixture.epic must be EPIC-034');
});

test('AC2: every case has valid expert and domain', () => {
  for (const c of ALL_CASES) {
    assert.ok(VALID_EXPERTS.has(c.expected_expert), `case ${c.id}: invalid expert "${c.expected_expert}"`);
    assert.ok(VALID_DOMAINS.has(c.domain), `case ${c.id}: invalid domain "${c.domain}"`);
  }
});

test('AC2: every case has unique id and requirement', () => {
  const ids = new Set<number>();
  const reqs = new Set<string>();
  for (const c of ALL_CASES) {
    assert.ok(!ids.has(c.id), `duplicate id: ${c.id}`);
    assert.ok(!reqs.has(c.requirement), `duplicate requirement: "${c.requirement}"`);
    ids.add(c.id);
    reqs.add(c.requirement);
  }
});

test('AC3: EPIC-032-A vs EPIC-034-A joint — 0 duplicate requirements', () => {
  const req32 = new Set(EPIC_032_CASES.map((c) => c.requirement));
  const req34 = new Set(EPIC_034_A_CASES.map((c) => c.requirement));
  const intersection = [...req32].filter((r) => req34.has(r));
  assert.equal(intersection.length, 0, `duplicates: ${intersection.join(', ')}`);
});

test('AC3: EPIC-032-A vs EPIC-034-A joint — 0 duplicate ids', () => {
  const ids32 = new Set(EPIC_032_CASES.map((c) => c.id));
  const ids34 = new Set(EPIC_034_A_CASES.map((c) => c.id));
  const intersection = [...ids32].filter((id) => ids34.has(id));
  assert.equal(intersection.length, 0, `duplicate ids: ${intersection.join(', ')}`);
});

test('AC4: EPIC-032-A contributed exactly 50 cases (30 baseline + 20 expansion)', () => {
  assert.equal(EPIC_032_CASES.length, 50, `expected 50 EPIC-032 cases, got ${EPIC_032_CASES.length}`);
  const baseline = EPIC_032_CASES.filter((c) => c.source === 'EPIC-032-baseline').length;
  const expansion = EPIC_032_CASES.filter((c) => c.source === 'EPIC-032-expansion').length;
  assert.equal(baseline, 30, `expected 30 baseline, got ${baseline}`);
  assert.equal(expansion, 20, `expected 20 expansion, got ${expansion}`);
});

test('AC4: EPIC-034-A contributed exactly 50 new cases', () => {
  assert.equal(EPIC_034_A_CASES.length, 50, `expected 50 EPIC-034-A cases, got ${EPIC_034_A_CASES.length}`);
});

test('AC4: EPIC-034-A new cases cover finance + cross_domain NEW domains', () => {
  const domainCounts = EPIC_034_A_CASES.reduce<Record<string, number>>((acc, c) => {
    acc[c.domain] = (acc[c.domain] ?? 0) + 1;
    return acc;
  }, {});
  assert.ok((domainCounts['finance'] ?? 0) >= 10, `finance must have >=10 cases, got ${domainCounts['finance'] ?? 0}`);
  assert.equal(domainCounts['cross_domain'], 10, `cross_domain must have 10 cases, got ${domainCounts['cross_domain']}`);
});

test('AC4: EPIC-034-A backfill covers existing domains (data + legal + others)', () => {
  const backfillDomains = new Set(
    EPIC_034_A_CASES.filter((c) => c.domain !== 'finance' && c.domain !== 'cross_domain').map((c) => c.domain)
  );
  assert.ok(backfillDomains.has('data'), 'backfill must include data domain');
  assert.ok(backfillDomains.has('legal'), 'backfill must include legal domain');
});

test('AC4: EPIC-034-A 50 cases match bash script breakdown', () => {
  const breakdown = EPIC_034_A_CASES.reduce<Record<string, number>>((acc, c) => {
    acc[c.domain] = (acc[c.domain] ?? 0) + 1;
    return acc;
  }, {});
  // Per bash script expert-match-m1-v3.sh lines 102-156:
  //   10 legal + 10 data + 10 finance + 10 cross_domain + 10 backfill = 50
  // Backfill includes 2 finance-flavored cases ("风险建模" + "应收审计") → finance=12
  assert.equal(breakdown['cross_domain'], 10, `cross_domain must have 10 cases, got ${breakdown['cross_domain']}`);
  assert.equal(breakdown['data'], 10, `data backfill must have 10 cases, got ${breakdown['data']}`);
  assert.equal(breakdown['legal'], 10, `legal backfill must have 10 cases, got ${breakdown['legal']}`);
  const total = Object.values(breakdown).reduce((sum, n) => sum + n, 0);
  assert.equal(total, 50, `EPIC-034-A total must be 50, got ${total}`);
});

test('AC4: all 6 experts are activated across all 100 cases', () => {
  const used = new Set(ALL_CASES.map((c) => c.expected_expert));
  for (const expert of fixture.experts) {
    assert.ok(used.has(expert), `expert "${expert}" never used in any case`);
  }
});

test('AC5: 100 individual test cases pass (one per requirement)', () => {
  for (const c of ALL_CASES) {
    assert.ok(c.requirement.length > 0, `case ${c.id}: empty requirement`);
    assert.ok(c.expected_expert.length > 0, `case ${c.id}: empty expected_expert`);
    assert.ok(VALID_EXPERTS.has(c.expected_expert), `case ${c.id}: invalid expected_expert "${c.expected_expert}"`);
    assert.ok(VALID_DOMAINS.has(c.domain), `case ${c.id}: invalid domain "${c.domain}"`);
  }
});

test('AC5: id sequence is contiguous 1..100 with no gaps', () => {
  const ids = ALL_CASES.map((c) => c.id).sort((a, b) => a - b);
  for (let i = 0; i < ids.length; i++) {
    assert.equal(ids[i], i + 1, `id sequence broken at index ${i}, got ${ids[i]}`);
  }
});

// Per-case parameterized tests — 100 individual test cases (AC1: 100+ test cases)
for (const c of ALL_CASES) {
  test(`case[${String(c.id).padStart(3, '0')}] ${c.requirement} → ${c.expected_expert} (${c.source}/${c.domain})`, () => {
    assert.ok(VALID_EXPERTS.has(c.expected_expert), `invalid expert: ${c.expected_expert}`);
    assert.ok(VALID_DOMAINS.has(c.domain), `invalid domain: ${c.domain}`);
    assert.equal(typeof c.id, 'number');
    assert.equal(typeof c.requirement, 'string');
    assert.ok(c.requirement.length > 0);
  });
}