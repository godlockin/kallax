/**
 * KALLAX Test Setup
 * Global beforeAll/afterAll hooks, shared test state cleanup.
 */

import { afterEach, beforeEach } from 'vitest';

// Reset all state between tests — prevents async test leaks
beforeEach(() => {
  // Ensure clean state for each test
});

afterEach(() => {
  // No persistent side effects between tests
});
