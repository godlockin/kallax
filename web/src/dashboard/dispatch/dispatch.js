/* EPIC-053-D Dispatch Dashboard — vanilla JS, zero deps
 * 跟 web/app.js 框架一致 (IIFE, no globals, no framework deps).
 *
 * 数据源: 通过 fetch 加载 dispatch-dashboard CLI 的 JSON 输出
 *   (生产环境: 配 reverse proxy 把 bash CLI 输出转为 JSON;
 *    当前演示: 走 fallback sample data, 避免 web 端必须跑 Node).
 *
 * Rule 9 KPI X/Y format precision — 跟 PROJECT-STATUS line 43 baseline 对比.
 */

(function () {
  'use strict';

  // Fallback sample data (跟 PROJECT-STATUS line 43 baseline 对齐 + 5 张 EPIC-053 mock)
  // 真实部署: 后端暴露 /api/dispatch/dashboard.json, 走 Node CLI 喂出
  const SAMPLE_DATA = {
    total: 5,
    passed: 3,
    failed: 0,
    fakePasses: 1,
    boundaryViolations: 1,
    formatXofY: '3/5 (60.0%)',
    ratePct: 75.0,
    baselineRatePct: 58.3,
    targetRatePct: 95.0,
    deltaVsBaseline: 16.7,
    byEpic: [
      { epicId: 'EPIC-053', total: 5, passed: 3, fakePasses: 1, boundaryViolations: 1, formatXofY: '3/5 (60.0%)' },
    ],
    records: [
      { ticketId: 'EPIC-053-A', outcome: 'pass', commitSha: '827dc1500000000000000000000000000000000', beEvents: [], epicId: 'EPIC-053' },
      { ticketId: 'EPIC-053-B', outcome: 'pass', commitSha: '0a4d9287000000000000000000000000000000', beEvents: [], epicId: 'EPIC-053' },
      { ticketId: 'EPIC-053-C', outcome: 'pass', commitSha: 'bf394fd0000000000000000000000000000000', beEvents: [], epicId: 'EPIC-053' },
      { ticketId: 'EPIC-053-D', outcome: 'fake_pass', commitSha: 'eefa1d3000000000000000000000000000000', beEvents: [], epicId: 'EPIC-053' },
      { ticketId: 'EPIC-053-E', outcome: 'boundary_violation', commitSha: 'aef938e1000000000000000000000000000000', beEvents: ['BE-1', 'BE-6'], epicId: 'EPIC-053' },
    ],
  };

  // --- DOM helpers ---
  function $(id) { return document.getElementById(id); }
  function setText(id, text) { const el = $(id); if (el) el.textContent = text; }
  function setClass(id, cls) { const el = $(id); if (el) el.className = cls; }

  // --- Tab navigation (跟 web/app.js 一致, no framework) ---
  function setupTabs() {
    const buttons = document.querySelectorAll('.nav-btn');
    const sections = document.querySelectorAll('.tab-content');
    function activate(hash) {
      const target = hash || '#overview';
      buttons.forEach((b) => b.classList.toggle('active', b.getAttribute('href') === target));
      sections.forEach((s) => s.classList.toggle('active', '#' + s.id === target));
    }
    buttons.forEach((b) => {
      b.addEventListener('click', (e) => {
        e.preventDefault();
        activate(b.getAttribute('href'));
        history.replaceState(null, '', b.getAttribute('href'));
      });
    });
    activate(window.location.hash || '#overview');
  }

  // --- Refresh button ---
  function setupRefresh(onRefresh) {
    const btn = $('refresh-btn');
    if (!btn) return;
    btn.addEventListener('click', () => {
      btn.disabled = true;
      btn.textContent = '↻ Loading...';
      Promise.resolve(onRefresh()).finally(() => {
        btn.disabled = false;
        btn.textContent = '↻ Refresh';
      });
    });
  }

  // --- Renderers ---
  function renderOverview(data) {
    setText('stat-overall', data.formatXofY);
    setText('stat-overall-meta', `H1-corrected strict rate: ${data.ratePct.toFixed(1)}%`);
    setText('stat-baseline', `${data.baselineRatePct.toFixed(1)}%`);
    setText('stat-target', `${data.targetRatePct.toFixed(1)}%`);

    const deltaText = `${data.deltaVsBaseline >= 0 ? '+' : ''}${data.deltaVsBaseline.toFixed(1)}%`;
    setText('stat-delta', deltaText);
    const deltaCard = $('stat-delta').parentElement;
    deltaCard.classList.remove('pass', 'fail', 'warning');
    if (data.deltaVsBaseline >= 30) deltaCard.classList.add('pass');
    else if (data.deltaVsBaseline >= 0) deltaCard.classList.add('warning');
    else deltaCard.classList.add('fail');
    setText('stat-delta-meta', data.ratePct >= data.targetRatePct ? '✅ Above target' : '⚠️ Below target');

    setText('breakdown-total', data.total);
    setText('breakdown-passed', data.passed);
    setText('breakdown-failed', data.failed);
    setText('breakdown-fake', data.fakePasses);
    setText('breakdown-boundary', data.boundaryViolations);
  }

  function renderFakePassList(records) {
    const container = $('fake-pass-list');
    if (!container) return;
    const fakes = records.filter((r) => r.outcome === 'fake_pass');
    if (fakes.length === 0) {
      container.innerHTML = '<p class="empty-state">No fake PASS detected ✅</p>';
      return;
    }
    container.innerHTML = fakes.map((r) => `
      <div class="event-item fake">
        <span class="event-ticket">${escapeHtml(r.ticketId)}</span>
        <span class="event-meta">commit: ${escapeHtml(r.commitSha.slice(0, 12))}… (BE-5 pattern: PASS report but evidence chain FAIL)</span>
      </div>
    `).join('');
  }

  function renderBoundaryList(records) {
    const container = $('boundary-list');
    if (!container) return;
    const bes = records.filter((r) => r.outcome === 'boundary_violation');
    if (bes.length === 0) {
      container.innerHTML = '<p class="empty-state">No boundary violations ✅</p>';
      return;
    }
    container.innerHTML = bes.map((r) => `
      <div class="event-item boundary">
        <span class="event-ticket">${escapeHtml(r.ticketId)}</span>
        <span class="event-meta">BE events: ${r.beEvents.map(escapeHtml).join(', ') || '—'} (BE-1/6/11 pattern)</span>
      </div>
    `).join('');
  }

  function renderTrend(byEpic) {
    const container = $('trend-chart');
    if (!container) return;
    if (!byEpic || byEpic.length === 0) {
      container.innerHTML = '<p class="empty-state">No trend data</p>';
      return;
    }
    const rows = byEpic.map((e) => {
      const pct = e.total > 0 ? (e.passed / e.total) * 100 : 0;
      let cls = 'low';
      if (pct >= 95) cls = 'high';
      else if (pct >= 70) cls = 'mid';
      return `
        <div class="bar-row">
          <span class="epic-label">${escapeHtml(e.epicId)}</span>
          <div class="bar-track"><div class="bar-fill ${cls}" style="width: ${pct.toFixed(1)}%"></div></div>
          <span class="bar-value">${escapeHtml(e.formatXofY)}</span>
        </div>
      `;
    }).join('');
    container.innerHTML = `<div class="bar-chart">${rows}</div>`;
  }

  function renderData(data) {
    renderOverview(data);
    renderFakePassList(data.records || []);
    renderBoundaryList(data.records || []);
    renderTrend(data.byEpic || []);
    setText('status-text', 'Connected');
    setClass('status-dot', 'status-dot connected');
    setText('last-update', new Date().toLocaleString());
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  // --- Data loader ---
  // 真实部署: fetch('/api/dispatch/dashboard.json')
  // 当前演示: 用 SAMPLE_DATA (跟 EPIC-053 mock 对齐)
  async function loadData() {
    try {
      const res = await fetch('../api/dispatch-dashboard.json', { cache: 'no-store' });
      if (res.ok) {
        const data = await res.json();
        return data;
      }
    } catch {
      // fall through to sample
    }
    return SAMPLE_DATA;
  }

  // --- Bootstrap ---
  async function init() {
    setupTabs();
    setupRefresh(async () => {
      const data = await loadData();
      renderData(data);
    });
    const data = await loadData();
    renderData(data);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
