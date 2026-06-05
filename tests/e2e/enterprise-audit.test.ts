import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import { createEnterpriseAudit, type EnterpriseAudit } from '../../src/core/enterprise-audit.js';

const AF = '.kallax/data/audit-log.jsonl';

describe('EnterpriseAudit', () => {
  let a: EnterpriseAudit;
  beforeEach(() => { try{fs.unlinkSync(AF);}catch{} a = createEnterpriseAudit(); });
  afterEach(() => { try{fs.unlinkSync(AF);}catch{} });
  const L = (actor='x',role:'conductor'|'performer'|'master'='conductor',action='merge:testing',res:'success' as const='success') =>
    a.log({actor,role,action,target:'t',result:res,details:'',metadata:{}});

  it('log and query', () => { L(); expect(a.query({actor:'x'}).length).toBe(1); });
  it('query by role', () => { L('p','performer','task:claim'); L('c','conductor','merge:testing');
    expect(a.query({role:'conductor'}).length).toBe(1); expect(a.query({role:'performer'}).length).toBe(1); });
  it('query by action', () => { L('a','conductor','merge:testing'); L('a','conductor','merge:miao'); L('a','conductor','task:claim');
    expect(a.query({action:'merge'}).length).toBe(2); });
  it('stats', () => { L();L();L('b','performer','task:claim','failure'); expect(a.stats().totalEntries).toBe(3); });
  it('permissions', () => {
    expect(a.isAllowed('conductor','merge:testing')).toBe(true);
    expect(a.isAllowed('performer','task:claim')).toBe(true);
    expect(a.isAllowed('performer','merge:testing')).toBe(false);
    expect(a.isAllowed('master','merge:miao')).toBe(true);
  });
  it('exports', () => { L(); expect(()=>JSON.parse(a.export('json'))).not.toThrow();
    expect(a.export('csv').startsWith('id,timestamp')).toBe(true); });
});
