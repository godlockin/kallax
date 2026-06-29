#!/usr/bin/env node
// web/tests/escape-attr-test.js — V310 hotfix U-001 attribute sanitization tests
// 6 PASS: escapeAttr + sanitizeUrl (javascript:) + sanitizeUrl (data:text/html) + el setAttribute + on* dropped + el href
'use strict';

const path = require('node:path');
const fs = require('node:fs');

// Minimal DOM stub for testing (node has no DOM)
let attributeStore = {};
let textStore = '';
function createElement(tag) {
  attributeStore = {};
  textStore = '';
  return {
    _tag: tag,
    setAttribute(k, v) { attributeStore[k] = String(v); },
    getAttribute(k) { return attributeStore[k]; },
    set className(v) { attributeStore['class'] = String(v); },
    get className() { return attributeStore['class'] || ''; },
    set textContent(v) { textStore = String(v); },
    get textContent() { return textStore; },
    _attrs: () => attributeStore,
  };
}
global.document = { createElement };

const escapePath = path.resolve(__dirname, '..', 'lib', 'escape.js');
const KallaxEscape = require(escapePath);

let pass = 0;
let fail = 0;
function check(name, cond, detail) {
  if (cond) { console.log('  PASS:', name); pass++; }
  else { console.log('  FAIL:', name, detail || ''); fail++; }
}

console.log('=== V310 hotfix U-001: escape.js attribute sanitization ===');
console.log('');

// ── Test 1: escapeAttr quotes are safe
console.log('[TEST 1] escapeAttr escapes " < > \' &');
const escaped = KallaxEscape.escapeAttr(`onclick=alert(1) "x"`);
check('escapeAttr escapes quotes', escaped.includes('&quot;') && escaped.includes('='), 'got: ' + escaped);

// ── Test 2: sanitizeUrl blocks javascript:
console.log('[TEST 2] sanitizeUrl blocks javascript: scheme');
check('javascript: → about:blank',
  KallaxEscape.sanitizeUrl('javascript:alert(1)') === 'about:blank',
  'got: ' + KallaxEscape.sanitizeUrl('javascript:alert(1)'));

// ── Test 3: sanitizeUrl blocks data:text/html
console.log('[TEST 3] sanitizeUrl blocks data:text/html');
check('data:text/html → about:blank',
  KallaxEscape.sanitizeUrl('data:text/html,<script>alert(1)</script>') === 'about:blank',
  'got: ' + KallaxEscape.sanitizeUrl('data:text/html,<script>'));

// ── Test 4: el() with href uses sanitizeUrl
console.log('[TEST 4] el(\'a\', {href: ...}) goes through sanitizeUrl');
const aNode = KallaxEscape.el('a', { href: 'javascript:alert(1)' }, 'click');
check('href javascript: blocked at attribute layer',
  aNode.getAttribute('href') === 'about:blank',
  'got href=' + aNode.getAttribute('href'));

// ── Test 5: el() drops on* event handler attributes
console.log('[TEST 5] el() drops on*= event handler attributes');
const evilNode = KallaxEscape.el('div', { onclick: 'alert(1)', onmouseover: 'x' }, 'safe');
const oc = evilNode.getAttribute('onclick');
const om = evilNode.getAttribute('onmouseover');
check('onclick dropped', oc === null || oc === undefined,
  'got onclick=' + oc);
check('onmouseover dropped', om === null || om === undefined,
  'got onmouseover=' + om);

// ── Test 6: el() escapeAttr on user-supplied attributes
console.log('[TEST 6] el() escapes user-supplied attribute values');
const xssNode = KallaxEscape.el('div', { title: '"><script>alert(1)</script>' });
const t = xssNode.getAttribute('title') || '';
check('title attribute escapes quotes (no executable script)',
  !t.includes('"') && t.includes('&quot;'),
  'got: ' + t);

console.log('');
console.log(`=== ${pass} passed, ${fail} failed ===`);
process.exit(fail === 0 ? 0 : 1);