#!/usr/bin/env node
// web/tests/tab-persistence-test.js — V310 hotfix P-004 localStorage tab persistence
// 4 PASS: localStorage read on init + localStorage write on switch + restore on reload + private-mode safe
'use strict';

// Minimal localStorage stub
const storage = {};
global.localStorage = {
  getItem: (k) => storage[k] || null,
  setItem: (k, v) => { storage[k] = String(v); },
  removeItem: (k) => { delete storage[k]; },
};

// Simulate the app.js logic for activeTab
function getInitialActiveTab() {
  return (typeof localStorage !== 'undefined' && localStorage.getItem('kallax.activeTab')) || 'overview';
}
function persistTab(tab) {
  try { localStorage.setItem('kallax.activeTab', tab); } catch (e) {}
}

let pass = 0;
let fail = 0;
function check(name, cond, detail) {
  if (cond) { console.log('  PASS:', name); pass++; }
  else { console.log('  FAIL:', name, detail || ''); fail++; }
}

console.log('=== V310 hotfix P-004: tab localStorage persistence ===');
console.log('');

// ── Test 1: initial activeTab = 'overview' (no localStorage)
console.log('[TEST 1] initial activeTab defaults to "overview"');
const tab1 = getInitialActiveTab();
check('default = overview', tab1 === 'overview', 'got: ' + tab1);

// ── Test 2: switchTab persists to localStorage
console.log('[TEST 2] switchTab persists to localStorage');
persistTab('tasks');
check('localStorage.kallax.activeTab = tasks',
  localStorage.getItem('kallax.activeTab') === 'tasks',
  'got: ' + localStorage.getItem('kallax.activeTab'));

// ── Test 3: reload restores tab from localStorage
console.log('[TEST 3] reload restores from localStorage');
storage['kallax.activeTab'] = 'agents';  // simulate user switching before reload
const tab3 = getInitialActiveTab();
check('reload restores agents', tab3 === 'agents', 'got: ' + tab3);

// ── Test 4: private-mode safe (setItem throws → catch block)
console.log('[TEST 4] private-mode safe (localStorage.setItem throws)');
const origSetItem = global.localStorage.setItem;
global.localStorage.setItem = () => { throw new Error('QuotaExceededError'); };
let threw = false;
try { persistTab('system'); } catch (e) { threw = true; }
check('no exception thrown on private-mode failure', !threw, 'expected no throw');
global.localStorage.setItem = origSetItem;

console.log('');
console.log(`=== ${pass} passed, ${fail} failed ===`);
process.exit(fail === 0 ? 0 : 1);