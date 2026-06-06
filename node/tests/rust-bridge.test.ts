import { describe, it, expect, vi } from 'vitest';

// Mock child_process before importing
const mockSpawn = vi.hoisted(() => vi.fn());
vi.mock('node:child_process', () => ({ spawn: mockSpawn }));

import { getRustBridge } from '../src/core/rust-bridge.js';

describe('RustBridge', () => {
  it('is a singleton', () => {
    const a = getRustBridge();
    const b = getRustBridge();
    expect(a).toBe(b);
  });

  it('returns alive=false when Rust binary unavailable', async () => {
    mockSpawn.mockImplementation(() => {
      const ee = new (require('events').EventEmitter)();
      process.nextTick(() => ee.emit('error', new Error('ENOENT')));
      return ee;
    });
    const bridge = getRustBridge();
    const alive = await bridge.isAlive();
    expect(alive).toBe(false);
  });

  it('has expected interface', () => {
    const bridge = getRustBridge();
    expect(typeof bridge.isAlive).toBe('function');
  });
});
