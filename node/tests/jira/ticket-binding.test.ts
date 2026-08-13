/**
 * EPIC-251 — node/src/jira/ticket-binding.ts unit tests
 *
 * 修 EPIC-157 引入的 scan-dead-code Stage 3 sentinel debt.
 * Rule 34 复现: bash scripts/scan-dead-code.sh -> exit 1, "jira/ticket-binding 未被 tests 引用".
 *
 * 覆盖 4 exported 函数 (per AC1-AC5):
 *   findJiraTicketPath        - exact match / sub-ticket prefix / not found
 *   readJiraTicket            - NOT_FOUND / PARSE_FAILED / ok
 *   writeBinding              - VALIDATION_FAILED / ok (atomic tmp+rename)
 *   validateBindingForComplete - missing binding / actual 空 / divergent 无 reason / ok
 *
 * 隔离策略 (同 CLAUDE.md Rule 7): mkdtemp 临时目录 + afterEach 清理, 0 污染真实 jira/tickets/.
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  findJiraTicketPath,
  readJiraTicket,
  writeBinding,
  validateBindingForComplete,
} from '../../src/jira/ticket-binding.js';

let tmpRoot: string;

/** 在 tmpRoot 下建 jira/tickets/<id>/ticket.json */
function seedTicket(ticketId: string, body: Record<string, unknown>): string {
  const dir = path.join(tmpRoot, 'jira', 'tickets', ticketId);
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, 'ticket.json');
  fs.writeFileSync(file, JSON.stringify(body, null, 2), 'utf-8');
  return file;
}

/** 写非法 JSON (触发 PARSE_FAILED) */
function seedRawTicket(ticketId: string, raw: string): string {
  const dir = path.join(tmpRoot, 'jira', 'tickets', ticketId);
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, 'ticket.json');
  fs.writeFileSync(file, raw, 'utf-8');
  return file;
}

beforeEach(() => {
  tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'kallax-epic251-'));
});

afterEach(() => {
  fs.rmSync(tmpRoot, { recursive: true, force: true });
});

describe('EPIC-251 findJiraTicketPath', () => {
  it('finds exact match jira/tickets/<id>/ticket.json', () => {
    const expected = seedTicket('EPIC-900', { id: 'EPIC-900' });
    expect(findJiraTicketPath('EPIC-900', tmpRoot)).toBe(expected);
  });

  it('finds sub-ticket via prefix (EPIC-901-A when asked for EPIC-901)', () => {
    const expected = seedTicket('EPIC-901-A', { id: 'EPIC-901-A' });
    expect(findJiraTicketPath('EPIC-901', tmpRoot)).toBe(expected);
  });

  it('prefers exact match over sub-ticket prefix', () => {
    const exact = seedTicket('EPIC-902', { id: 'EPIC-902' });
    seedTicket('EPIC-902-B', { id: 'EPIC-902-B' });
    expect(findJiraTicketPath('EPIC-902', tmpRoot)).toBe(exact);
  });

  it('returns null when ticket missing', () => {
    expect(findJiraTicketPath('EPIC-999', tmpRoot)).toBeNull();
  });

  it('returns null when jira/tickets dir absent', () => {
    const emptyRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'kallax-epic251-empty-'));
    try {
      expect(findJiraTicketPath('EPIC-900', emptyRoot)).toBeNull();
    } finally {
      fs.rmSync(emptyRoot, { recursive: true, force: true });
    }
  });
});

describe('EPIC-251 readJiraTicket', () => {
  it('returns ok with parsed ticket + path', () => {
    const file = seedTicket('EPIC-910', { id: 'EPIC-910', title: 'read ok' });
    const result = readJiraTicket('EPIC-910', tmpRoot);
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.path).toBe(file);
      expect(result.value.ticket.id).toBe('EPIC-910');
    }
  });

  it('returns NOT_FOUND error when ticket missing', () => {
    const result = readJiraTicket('EPIC-911', tmpRoot);
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.kind).toBe('NOT_FOUND');
      expect(result.error.ticketId).toBe('EPIC-911');
    }
  });

  it('returns PARSE_FAILED error on malformed JSON', () => {
    seedRawTicket('EPIC-912', '{ not valid json');
    const result = readJiraTicket('EPIC-912', tmpRoot);
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.kind).toBe('PARSE_FAILED');
    }
  });

  it('returns PARSE_FAILED when id field absent', () => {
    seedRawTicket('EPIC-913', '{"title":"no id field"}');
    const result = readJiraTicket('EPIC-913', tmpRoot);
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.kind).toBe('PARSE_FAILED');
    }
  });
});

describe('EPIC-251 writeBinding', () => {
  it('writes consistent binding (suggested=actual, no reason needed)', () => {
    const file = seedTicket('EPIC-920', { id: 'EPIC-920', title: 'write ok' });
    const result = writeBinding(
      'EPIC-920',
      {
        suggested_expert: 'backend',
        actual_expert: 'backend',
        expert_binding_at: '2026-08-12T14:00:00Z',
      },
      tmpRoot
    );
    expect(result.isOk()).toBe(true);

    const persisted = JSON.parse(fs.readFileSync(file, 'utf-8')) as Record<string, unknown>;
    const binding = persisted.expert_binding as Record<string, unknown>;
    expect(binding.actual_expert).toBe('backend');
    // 原有字段保留 (merge 不覆盖)
    expect(persisted.title).toBe('write ok');
  });

  it('writes divergent binding when reason present', () => {
    seedTicket('EPIC-921', { id: 'EPIC-921' });
    const result = writeBinding(
      'EPIC-921',
      {
        suggested_expert: 'backend',
        actual_expert: 'frontend',
        expert_binding_at: '2026-08-12T14:00:00Z',
        binding_change_reason: 'scope spans both layers',
      },
      tmpRoot
    );
    expect(result.isOk()).toBe(true);
  });

  it('rejects divergent binding without reason (VALIDATION_FAILED)', () => {
    seedTicket('EPIC-922', { id: 'EPIC-922' });
    const result = writeBinding(
      'EPIC-922',
      {
        suggested_expert: 'backend',
        actual_expert: 'frontend',
        expert_binding_at: '2026-08-12T14:00:00Z',
      },
      tmpRoot
    );
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.kind).toBe('VALIDATION_FAILED');
    }
  });

  it('leaves no .tmp file behind after successful write', () => {
    const file = seedTicket('EPIC-923', { id: 'EPIC-923' });
    writeBinding(
      'EPIC-923',
      { actual_expert: 'backend', expert_binding_at: '2026-08-12T14:00:00Z' },
      tmpRoot
    );
    expect(fs.existsSync(`${file}.tmp`)).toBe(false);
  });

  it('returns NOT_FOUND when target ticket absent', () => {
    const result = writeBinding(
      'EPIC-924',
      { actual_expert: 'backend', expert_binding_at: '2026-08-12T14:00:00Z' },
      tmpRoot
    );
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.kind).toBe('NOT_FOUND');
    }
  });
});

describe('EPIC-251 validateBindingForComplete', () => {
  it('returns ok when binding consistent', () => {
    seedTicket('EPIC-930', {
      id: 'EPIC-930',
      expert_binding: {
        suggested_expert: 'backend',
        actual_expert: 'backend',
        expert_binding_at: '2026-08-12T14:00:00Z',
      },
    });
    const result = validateBindingForComplete('EPIC-930', tmpRoot);
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.binding.actual_expert).toBe('backend');
    }
  });

  it('returns ok when divergent binding carries reason', () => {
    seedTicket('EPIC-931', {
      id: 'EPIC-931',
      expert_binding: {
        suggested_expert: 'backend',
        actual_expert: 'frontend',
        expert_binding_at: '2026-08-12T14:00:00Z',
        binding_change_reason: 'documented divergence',
      },
    });
    expect(validateBindingForComplete('EPIC-931', tmpRoot).isOk()).toBe(true);
  });

  it('fails when expert_binding missing entirely', () => {
    seedTicket('EPIC-932', { id: 'EPIC-932' });
    const result = validateBindingForComplete('EPIC-932', tmpRoot);
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.kind).toBe('VALIDATION_FAILED');
      expect(result.error.errors.join(' ')).toContain('expert_binding is missing');
    }
  });

  it('fails when actual_expert blank', () => {
    seedTicket('EPIC-933', {
      id: 'EPIC-933',
      expert_binding: { suggested_expert: 'backend', actual_expert: '   ' },
    });
    const result = validateBindingForComplete('EPIC-933', tmpRoot);
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.errors.join(' ')).toContain('actual_expert is required');
    }
  });

  it('fails when divergent binding lacks reason', () => {
    seedTicket('EPIC-934', {
      id: 'EPIC-934',
      expert_binding: {
        suggested_expert: 'backend',
        actual_expert: 'frontend',
        expert_binding_at: '2026-08-12T14:00:00Z',
      },
    });
    const result = validateBindingForComplete('EPIC-934', tmpRoot);
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.errors.join(' ')).toContain('binding_change_reason is required');
    }
  });

  it('propagates NOT_FOUND when ticket absent', () => {
    const result = validateBindingForComplete('EPIC-935', tmpRoot);
    expect(result.isErr()).toBe(true);
    if (result.isErr()) {
      expect(result.error.kind).toBe('NOT_FOUND');
    }
  });
});
