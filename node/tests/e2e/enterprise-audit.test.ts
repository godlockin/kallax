import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import { createEnterpriseAudit, type EnterpriseAudit } from '../../src/core/enterprise-audit.js';

const AUDIT_FILE = '.kallax/data/audit-log.jsonl';

describe('EnterpriseAudit', () => {
  let audit: EnterpriseAudit;

  beforeEach(() => {
    try { fs.unlinkSync(AUDIT_FILE); } catch { /* ok */ }
    audit = createEnterpriseAudit();
  });

  afterEach(() => {
    try { fs.unlinkSync(AUDIT_FILE); } catch { /* ok */ }
  });

  it('logs and queries by actor', () => {
    audit.log({ actor: 'test', role: 'conductor', action: 'merge:testing', target: 't', result: 'success', details: '', metadata: {} });
    expect(audit.query({ actor: 'test' }).length).toBe(1);
  });

  it('queries by role', () => {
    audit.log({ actor: 'p', role: 'performer', action: 'task:claim', target: 't', result: 'success', details: '', metadata: {} });
    audit.log({ actor: 'c', role: 'conductor', action: 'merge:testing', target: 't', result: 'success', details: '', metadata: {} });
    expect(audit.query({ role: 'conductor' }).length).toBe(1);
    expect(audit.query({ role: 'performer' }).length).toBe(1);
  });

  it('queries by action substring', () => {
    audit.log({ actor: 'a', role: 'conductor', action: 'merge:testing', target: 't', result: 'success', details: '', metadata: {} });
    audit.log({ actor: 'a', role: 'conductor', action: 'merge:miao', target: 't', result: 'success', details: '', metadata: {} });
    audit.log({ actor: 'a', role: 'conductor', action: 'task:claim', target: 't', result: 'success', details: '', metadata: {} });
    expect(audit.query({ action: 'merge' }).length).toBe(2);
  });

  it('returns correct stats', () => {
    audit.log({ actor: 'a', role: 'conductor', action: 'merge:testing', target: 't', result: 'success', details: '', metadata: {} });
    audit.log({ actor: 'a', role: 'conductor', action: 'task:claim', target: 't', result: 'success', details: '', metadata: {} });
    audit.log({ actor: 'a', role: 'conductor', action: 'task:claim', target: 't', result: 'failure', details: '', metadata: {} });
    expect(audit.stats().totalEntries).toBe(3);
  });

  it('enforces role permissions', () => {
    expect(audit.isAllowed('conductor', 'merge:testing')).toBe(true);
    expect(audit.isAllowed('performer', 'task:claim')).toBe(true);
    expect(audit.isAllowed('performer', 'merge:testing')).toBe(false);
    expect(audit.isAllowed('master', 'merge:miao')).toBe(true);
  });

  it('exports JSON and CSV', () => {
    audit.log({ actor: 'a', role: 'conductor', action: 'merge:testing', target: 't', result: 'success', details: '', metadata: {} });
    expect(() => JSON.parse(audit.export('json'))).not.toThrow();
    expect(audit.export('csv').startsWith('id,timestamp')).toBe(true);
  });
});
