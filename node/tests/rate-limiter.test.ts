import { describe, it, expect, vi, beforeEach } from 'vitest';

const mockLogger = { warn: vi.fn(), info: vi.fn(), debug: vi.fn(), error: vi.fn() };
vi.mock('../src/utils/logger.js', () => ({ logger: mockLogger }));

// Import after mock
import { createRateLimiter } from '../src/api/middleware/rate-limiter.js';

describe('RateLimiter', () => {
  let limiter: ReturnType<typeof createRateLimiter>;

  beforeEach(() => {
    vi.clearAllMocks();
    limiter = createRateLimiter();
  });

  it('returns a middleware function', () => {
    expect(typeof limiter).toBe('function');
  });

  it('allows requests within rate limit', () => {
    const req = { ip: '127.0.0.1', path: '/api/tasks', method: 'GET' } as any;
    const res = { status: vi.fn().mockReturnValue({ json: vi.fn() }) } as any;
    const next = vi.fn();

    limiter(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  it('blocks excessive requests from same IP', () => {
    const req = { ip: '10.0.0.1', path: '/api/tasks', method: 'POST' } as any;
    const res = { status: vi.fn().mockReturnValue({ json: vi.fn() }) } as any;
    const next = vi.fn();

    // Exhaust the token bucket
    for (let i = 0; i < 60; i++) {
      limiter(req, res, next);
    }
    // One more should be rate limited
    const blocked = { status: vi.fn().mockReturnValue({ json: vi.fn() }) } as any;
    const blockedNext = vi.fn();
    limiter(req, blocked, blockedNext);
    expect(blockedNext).not.toHaveBeenCalled();
    expect(blocked.status).toHaveBeenCalledWith(429);
  });

  it('uses different limits per route', () => {
    const ip = '192.168.1.1';
    const next = vi.fn();
    const res = { status: vi.fn().mockReturnValue({ json: vi.fn() }) } as any;

    // Heartbeat has higher limit (500)
    for (let i = 0; i < 100; i++) {
      limiter({ ip, path: '/api/heartbeat', method: 'POST' } as any, res, next);
      limiter({ ip, path: '/api/workflow', method: 'POST' } as any, res, next);
    }
    // Heartbeat should still pass, workflow should be blocked
    const hbNext = vi.fn();
    limiter({ ip, path: '/api/heartbeat', method: 'GET' } as any, res, hbNext);
    expect(hbNext).toHaveBeenCalled();
  });

  it('separates limits by IP', () => {
    const next = vi.fn();
    const res = { status: vi.fn().mockReturnValue({ json: vi.fn() }) } as any;

    // Exhaust IP-A
    for (let i = 0; i < 60; i++) {
      limiter({ ip: '1.1.1.1', path: '/api/tasks', method: 'GET' } as any, res, next);
    }
    // IP-B should still work
    const bNext = vi.fn();
    limiter({ ip: '2.2.2.2', path: '/api/tasks', method: 'GET' } as any, res, bNext);
    expect(bNext).toHaveBeenCalled();
  });
});
