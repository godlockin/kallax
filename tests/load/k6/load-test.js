// KALLAX K6 Load Test
// Performance testing for KALLAX API endpoints
// Usage: k6 run tests/load/k6/load-test.js

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// ============================================================
// Configuration
// ============================================================
const BASE_URL = __ENV.KALLAX_URL || 'http://localhost:9877';

export const options = {
  // Test scenarios
  scenarios: {
    // Smoke test - basic functionality
    smoke: {
      executor: 'constant-vus',
      vus: 1,
      duration: '30s',
      tags: { scenario: 'smoke' },
    },

    // Load test - normal load
    load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 10 },   // Ramp up
        { duration: '3m', target: 10 },   // Stay at 10
        { duration: '1m', target: 0 },    // Ramp down
      ],
      tags: { scenario: 'load' },
      startTime: '30s',
    },

    // Stress test - high load
    stress: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 20 },   // Ramp up
        { duration: '5m', target: 20 },   // Stay at 20
        { duration: '2m', target: 50 },   // Push higher
        { duration: '3m', target: 50 },   // Stay at 50
        { duration: '2m', target: 0 },    // Ramp down
      ],
      tags: { scenario: 'stress' },
      startTime: '5m',
    },

    // Spike test - sudden traffic spike
    spike: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '10s', target: 1 },   // Normal
        { duration: '10s', target: 50 },  // Spike!
        { duration: '30s', target: 50 },  // Stay
        { duration: '10s', target: 1 },   // Back to normal
      ],
      tags: { scenario: 'spike' },
      startTime: '20m',
    },
  },

  // Thresholds
  thresholds: {
    // Overall
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],

    // Per endpoint
    'http_req_duration{endpoint:health}': ['p(95)<100'],
    'http_req_duration{endpoint:tasks}': ['p(95)<300'],
    'http_req_duration{endpoint:performers}': ['p(95)<200'],

    // Custom metrics
    errors: ['rate<0.05'],
  },
};

// ============================================================
// Custom Metrics
// ============================================================
const errors = new Rate('errors');
const taskCreationTime = new Trend('task_creation_time');
const taskListTime = new Trend('task_list_time');
const apiCalls = new Counter('api_calls');

// ============================================================
// Helper Functions
// ============================================================
function getHeaders() {
  return {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}

function checkResponse(res, name) {
  const success = check(res, {
    [`${name} status is 200`]: (r) => r.status === 200,
    [`${name} has body`]: (r) => r.body.length > 0,
  });

  if (!success) {
    errors.add(1);
  }

  apiCalls.add(1);
  return success;
}

// ============================================================
// Test Scenarios
// ============================================================

export default function () {
  // Health Check
  group('Health Check', () => {
    const res = http.get(`${BASE_URL}/health`, {
      tags: { endpoint: 'health' },
    });

    check(res, {
      'health status 200': (r) => r.status === 200,
      'health returns healthy': (r) => {
        try {
          const body = JSON.parse(r.body);
          return body.status === 'healthy' || body.status === 'ok';
        } catch {
          return false;
        }
      },
    });
  });

  sleep(0.5);

  // List Tasks
  group('List Tasks', () => {
    const start = Date.now();
    const res = http.get(`${BASE_URL}/api/tasks`, {
      headers: getHeaders(),
      tags: { endpoint: 'tasks' },
    });
    taskListTime.add(Date.now() - start);

    checkResponse(res, 'List tasks');
  });

  sleep(0.5);

  // Create Task
  group('Create Task', () => {
    const taskData = {
      title: `Load Test Task ${Date.now()}`,
      type: 'feature',
      priority: 'medium',
      description: 'Created by K6 load test',
    };

    const start = Date.now();
    const res = http.post(`${BASE_URL}/api/tasks`, JSON.stringify(taskData), {
      headers: getHeaders(),
      tags: { endpoint: 'tasks' },
    });
    taskCreationTime.add(Date.now() - start);

    const success = check(res, {
      'Create task status 200 or 201': (r) => r.status === 200 || r.status === 201,
      'Create task returns id': (r) => {
        try {
          const body = JSON.parse(r.body);
          return body.id !== undefined;
        } catch {
          return false;
        }
      },
    });

    if (!success) {
      errors.add(1);
    }

    // If task created, get its details
    if (res.status === 200 || res.status === 201) {
      try {
        const task = JSON.parse(res.body);
        if (task.id) {
          sleep(0.2);

          const getRes = http.get(`${BASE_URL}/api/tasks/${task.id}`, {
            headers: getHeaders(),
            tags: { endpoint: 'tasks' },
          });

          checkResponse(getRes, 'Get task');
        }
      } catch (e) {
        console.error('Failed to parse task response');
      }
    }
  });

  sleep(0.5);

  // List Performers
  group('List Performers', () => {
    const res = http.get(`${BASE_URL}/api/performers`, {
      headers: getHeaders(),
      tags: { endpoint: 'performers' },
    });

    checkResponse(res, 'List performers');
  });

  sleep(0.5);

  // Get Metrics
  group('Get Metrics', () => {
    const res = http.get(`${BASE_URL}/api/metrics`, {
      headers: getHeaders(),
      tags: { endpoint: 'metrics' },
    });

    check(res, {
      'Metrics status 200': (r) => r.status === 200,
    });
  });

  sleep(1);
}

// ============================================================
// Setup and Teardown
// ============================================================

export function setup() {
  console.log(`Starting KALLAX load test against ${BASE_URL}`);

  // Verify server is up
  const res = http.get(`${BASE_URL}/health`);
  if (res.status !== 200) {
    throw new Error(`Server not available at ${BASE_URL}`);
  }

  return {
    startTime: Date.now(),
  };
}

export function teardown(data) {
  const duration = (Date.now() - data.startTime) / 1000;
  console.log(`Load test completed in ${duration.toFixed(2)} seconds`);
}

// ============================================================
// Thresholds Summary
// ============================================================
export function handleSummary(data) {
  const summary = {
    timestamp: new Date().toISOString(),
    duration_seconds: data.state.testRunDurationMs / 1000,
    vus_max: data.metrics.vus_max ? data.metrics.vus_max.values.max : 0,
    requests: {
      total: data.metrics.http_reqs ? data.metrics.http_reqs.values.count : 0,
      failed: data.metrics.http_req_failed ? data.metrics.http_req_failed.values.passes : 0,
      rate: data.metrics.http_reqs ? data.metrics.http_reqs.values.rate : 0,
    },
    latency: {
      p50: data.metrics.http_req_duration ? data.metrics.http_req_duration.values['p(50)'] : 0,
      p95: data.metrics.http_req_duration ? data.metrics.http_req_duration.values['p(95)'] : 0,
      p99: data.metrics.http_req_duration ? data.metrics.http_req_duration.values['p(99)'] : 0,
    },
    thresholds: {
      passed: Object.values(data.root_group.checks).every((c) => c.passes > 0),
    },
  };

  return {
    'k6/results/summary.json': JSON.stringify(summary, null, 2),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

function textSummary(data, options) {
  // Basic text summary
  const lines = [
    '',
    '='.repeat(60),
    '  KALLAX Load Test Results',
    '='.repeat(60),
    '',
    `  Duration: ${(data.state.testRunDurationMs / 1000).toFixed(2)}s`,
    `  VUs Max: ${data.metrics.vus_max ? data.metrics.vus_max.values.max : 'N/A'}`,
    '',
    '  Requests:',
    `    Total: ${data.metrics.http_reqs ? data.metrics.http_reqs.values.count : 0}`,
    `    Rate: ${data.metrics.http_reqs ? data.metrics.http_reqs.values.rate.toFixed(2) : 0}/s`,
    '',
    '  Response Time:',
    `    p50: ${data.metrics.http_req_duration ? data.metrics.http_req_duration.values['p(50)'].toFixed(2) : 0}ms`,
    `    p95: ${data.metrics.http_req_duration ? data.metrics.http_req_duration.values['p(95)'].toFixed(2) : 0}ms`,
    `    p99: ${data.metrics.http_req_duration ? data.metrics.http_req_duration.values['p(99)'].toFixed(2) : 0}ms`,
    '',
    '='.repeat(60),
    '',
  ];

  return lines.join('\n');
}
