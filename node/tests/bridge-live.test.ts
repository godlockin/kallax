import { describe, it, expect } from 'vitest';
import { getRustBridge } from '../src/core/rust-bridge.js';

describe('bridge live', () => {
  it('isAlive true', async () => {
    const bridge = getRustBridge();
    const alive = await bridge.isAlive();
    expect(alive).toBe(true);
  });

  it('createTicket returns ticket_id', async () => {
    const bridge = getRustBridge();
    const result = await bridge.createTicket({ title: 'live2', description: 'test' });
    console.log('result:', JSON.stringify(result));
    expect(result.isOk()).toBe(true);
  });
});
