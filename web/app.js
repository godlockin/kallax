/* KALLAX Dashboard — zero-dependency vanilla JS
 * 治根 FE-001 XSS: innerHTML 拼接 → textContent / KallaxEscape.el()
 * 治根 FE-004 dead code: 砍 web/src/dashboard/dispatch/ (重复 dashboard)
 * 治根 FE-005 CSS 重复: tokens 单一来源 (src/dashboard/tokens.css)
 * 治根 FE-002 硬编码 URL: 用 window.location.origin
 */
(function () {
  'use strict';

  const API = (window.location.origin && window.location.origin !== 'null' && window.location.origin !== 'file://')
    ? window.location.origin : 'http://127.0.0.1:9877';
  const { el } = window.KallaxEscape;

  let activeTab = 'overview';
  let tasksCache = [];
  const STATUSES = ['pending', 'claimed', 'running', 'completed', 'failed'];
  const ZH = document.documentElement.lang.startsWith('zh');

  const I = ZH ? {
    conn: '连接中...', ok: '已连接', off: '已断开', err: '无法连接服务器',
    taskStatus: ['待领取', '已认领', '运行中', '已完成', '失败'],
    health: ['健康', '降级', '异常'],
    noTasks: '暂无任务', noAgents: '暂无实例', noHealth: '暂无数据', noCB: '暂无数据',
  } : {
    conn: 'Connecting...', ok: 'Connected', off: 'Disconnected', err: 'Cannot connect to server',
    taskStatus: ['Pending', 'Claimed', 'Running', 'Completed', 'Failed'],
    health: ['Healthy', 'Degraded', 'Unhealthy'],
    noTasks: 'No tasks found', noAgents: 'No agents registered', noHealth: 'No health data', noCB: 'No circuit breaker data',
  };

  async function api(path) {
    const res = await fetch(API + path);
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const body = await res.json();
    if (!body.success) throw new Error(body.error?.message || body.error?.code || 'API error');
    return body.data;
  }

  function showError(msg) {
    let b = document.getElementById('error-banner');
    if (!b) {
      b = el('div', { id: 'error-banner', style: 'position:fixed;top:0;left:0;right:0;background:var(--accent-red);color:#fff;padding:12px 24px;text-align:center;z-index:999;font-size:0.9rem;cursor:pointer' });
      b.addEventListener('click', () => b.remove());
      document.body.prepend(b);
    }
    b.textContent = msg + ' (click to dismiss)';
  }

  function switchTab(tab) {
    activeTab = tab;
    document.querySelectorAll('.nav-btn').forEach((btn) => btn.classList.toggle('active', btn.dataset.tab === tab));
    document.querySelectorAll('.tab-content').forEach((sec) => sec.classList.toggle('active', sec.id === 'tab-' + tab));
    if (tab === 'overview') loadOverview();
    if (tab === 'tasks') renderTasks();
    if (tab === 'agents') loadAgents();
    if (tab === 'system') loadSystem();
  }

  let sse = null;
  function connectSSE() {
    const dot = document.querySelector('#connection-status .status-dot');
    const txt = document.querySelector('#connection-status .status-text');
    if (txt) txt.textContent = I.conn;
    sse = new EventSource(API + '/events');
    sse.onopen = () => { if (dot) dot.className = 'status-dot connected'; if (txt) txt.textContent = I.ok; };
    sse.addEventListener('connected', (e) => {
      if (dot) dot.className = 'status-dot connected';
      if (txt) txt.textContent = I.ok;
      try {
        const d = JSON.parse(e.data);
        document.querySelector('.version').textContent = 'v' + (d.version || '1.0.0');
      } catch (_) {}
    });
    sse.onerror = () => {
      if (dot) dot.className = 'status-dot disconnected';
      if (txt) txt.textContent = I.off;
      setTimeout(() => { if (sse.readyState === 2) connectSSE(); }, 3000);
    };
    sse.onmessage = (e) => {
      try {
        const ev = JSON.parse(e.data);
        if (ev.type) addActivity(ev);
        if (activeTab === 'overview') loadOverview();
        if (activeTab === 'tasks' && ev.type?.startsWith('task')) renderTasks();
        if (activeTab === 'agents' && ev.type?.startsWith('instance')) loadAgents();
      } catch (_) {}
    };
  }

  const MAX_ACTIVITY = 20;
  function addActivity(ev) {
    const feed = document.getElementById('activity-feed');
    if (!feed) return;
    const empty = feed.querySelector('.empty-state');
    if (empty) empty.remove();
    const msg = ev.message || (ev.type + (ev.data?.taskId ? ' ' + ev.data.taskId : ''));
    const item = el('div', { className: 'activity-item' });
    item.appendChild(el('span', null, msg));
    item.appendChild(el('span', { className: 'activity-time' }, new Date(ev.timestamp || Date.now()).toLocaleTimeString()));
    feed.prepend(item);
    while (feed.children.length > MAX_ACTIVITY) feed.lastChild.remove();
  }

  async function loadOverview() {
    try {
      const s = await api('/stats');
      document.getElementById('stat-tasks').textContent = s.tasks.total;
      document.getElementById('stat-agents').textContent = s.instances.active;
      document.getElementById('stat-completion').textContent = s.tasks.total > 0 ? Math.round((s.tasks.completed / s.tasks.total) * 100) + '%' : '0%';
      const distEl = document.getElementById('task-distribution');
      distEl.textContent = '';
      const total = s.tasks.total || 1;
      STATUSES.forEach((st, i) => {
        const pct = Math.round(((s.tasks[st] || 0) / total) * 100);
        const row = el('div', { className: 'progress-item' });
        row.appendChild(el('span', { className: 'progress-label' }, I.taskStatus[i]));
        const bar = el('div', { className: 'progress-bar' });
        const fill = el('div', { className: 'progress-fill' });
        fill.style.width = pct + '%';
        bar.appendChild(fill);
        row.appendChild(bar);
        row.appendChild(el('span', { className: 'progress-count' }, s.tasks[st] || 0));
        distEl.appendChild(row);
      });
      try {
        const h = await api('/health');
        const hEl = document.getElementById('stat-health');
        hEl.textContent = I.health[h.status === 'healthy' ? 0 : h.status === 'degraded' ? 1 : 2];
        hEl.style.color = h.status === 'healthy' ? 'var(--accent-green)' : h.status === 'degraded' ? 'var(--accent-yellow)' : 'var(--accent-red)';
      } catch (_) { document.getElementById('stat-health').textContent = '-'; }
    } catch (err) { showError(I.err); }
  }

  async function renderTasks() {
    try { tasksCache = (await api('/api/tasks')).items || []; applyTaskFilters(); }
    catch (err) { showError(I.err); }
  }

  function applyTaskFilters() {
    const sf = document.getElementById('task-status-filter').value;
    const tf = document.getElementById('task-type-filter').value;
    const q = document.getElementById('task-search').value.toLowerCase();
    let f = tasksCache;
    if (sf) f = f.filter((t) => t.status === sf);
    if (tf) f = f.filter((t) => t.type === tf);
    if (q) f = f.filter((t) => (t.ticketId || t.id).toLowerCase().includes(q));
    const list = document.getElementById('task-list');
    list.textContent = '';
    if (!f.length) { list.appendChild(el('p', { className: 'empty-state' }, I.noTasks)); return; }
    f.forEach((t) => {
      const si = STATUSES.indexOf(t.status);
      const row = el('div', { className: 'task-item ' + t.status });
      const left = el('div');
      left.appendChild(el('strong', null, t.ticketId || t.id));
      left.appendChild(el('span', { style: 'color:var(--text-muted);font-size:0.8rem;margin-left:8px' }, t.type || ''));
      row.appendChild(left);
      const right = el('div', { style: 'display:flex;align-items:center;gap:8px' });
      right.appendChild(el('span', { className: 'status-badge ' + t.status }, si >= 0 ? I.taskStatus[si] : t.status));
      if (t.performerId) right.appendChild(el('span', { style: 'font-size:0.8rem;color:var(--text-muted)' }, t.performerId));
      right.appendChild(el('span', { style: 'font-size:0.8rem;color:var(--text-muted)' }, t.progress + '%'));
      row.appendChild(right);
      list.appendChild(row);
    });
  }

  async function loadAgents() {
    try {
      const agents = await api('/api/agents');
      const list = document.getElementById('agent-list');
      list.textContent = '';
      if (!agents.length) { list.appendChild(el('p', { className: 'empty-state' }, I.noAgents)); return; }
      agents.forEach((a) => {
        const up = Math.floor((Date.now() - a.startedAt) / 1000);
        const upStr = up > 3600 ? Math.floor(up / 3600) + 'h' : up > 60 ? Math.floor(up / 60) + 'm' : up + 's';
        const row = el('div', { className: 'agent-item ' + a.status });
        const left = el('div');
        left.appendChild(el('strong', null, a.id.slice(0, 12)));
        left.appendChild(el('span', { style: 'color:var(--accent-purple);font-size:0.8rem;margin-left:8px' }, a.role));
        left.appendChild(el('span', { style: 'color:var(--text-muted);font-size:0.8rem;margin-left:8px' }, upStr));
        row.appendChild(left);
        const right = el('div');
        right.appendChild(el('span', { className: 'status-badge ' + a.status }, a.status));
        if (a.currentTaskId) right.appendChild(el('span', { style: 'font-size:0.8rem;color:var(--accent-blue);margin-left:8px' }, a.currentTaskId.slice(0, 8)));
        row.appendChild(right);
        list.appendChild(row);
      });
    } catch (err) { showError(I.err); }
  }

  async function loadSystem() {
    try {
      const [doctor, config, cbStats] = await Promise.all([
        api('/api/system/doctor').catch(() => null),
        api('/api/system/config').catch(() => null),
        api('/api/system/circuit-breakers').catch(() => []),
      ]);
      const hc = document.getElementById('health-checks');
      hc.textContent = '';
      if (!doctor) { hc.appendChild(el('p', { className: 'empty-state' }, I.noHealth)); }
      else {
        const memMB = Math.round((doctor.memory?.heapUsed || 0) / 1024 / 1024);
        const checks = [
          { name: 'Database', status: doctor.database?.connected ? 'healthy' : 'unhealthy' },
          { name: 'SSE Bus', status: 'healthy', detail: (doctor.sse?.clientCount || 0) + ' clients' },
          { name: 'Node.js', status: 'healthy', detail: 'v' + doctor.node },
          { name: 'Host', status: 'healthy', detail: doctor.hostname },
          { name: 'Memory', status: memMB > 500 ? 'degraded' : 'healthy', detail: memMB + ' MB' },
        ];
        if (doctor.instances) checks.push({ name: 'Instances', status: 'healthy', detail: doctor.instances.active + ' active' });
        checks.forEach((c) => {
          const color = c.status === 'healthy' ? 'var(--accent-green)' : c.status === 'degraded' ? 'var(--accent-yellow)' : 'var(--accent-red)';
          const row = el('div', { className: 'health-item ' + c.status });
          row.appendChild(el('span', null, c.name));
          const r = el('span');
          if (c.detail) r.appendChild(document.createTextNode(c.detail + ' — '));
          r.appendChild(el('span', { className: 'status-badge', style: 'background:' + color + ';color:#fff' }, I.health[c.status === 'healthy' ? 0 : c.status === 'degraded' ? 1 : 2]));
          row.appendChild(r);
          hc.appendChild(row);
        });
      }
      const cbEl = document.getElementById('circuit-breakers');
      cbEl.textContent = '';
      const cbData = Array.isArray(cbStats) ? cbStats : [];
      if (!cbData.length) { cbEl.appendChild(el('p', { className: 'empty-state' }, I.noCB)); }
      else {
        cbData.forEach((cb) => {
          const color = cb.state === 'closed' ? 'var(--accent-green)' : cb.state === 'halfOpen' ? 'var(--accent-yellow)' : 'var(--accent-red)';
          const cls = cb.state === 'closed' ? 'healthy' : cb.state === 'halfOpen' ? 'degraded' : 'unhealthy';
          const label = cb.state === 'closed' ? (ZH ? '关闭' : 'Closed') : cb.state === 'halfOpen' ? (ZH ? '半开' : 'Half-Open') : (ZH ? '开启' : 'Open');
          const row = el('div', { className: 'health-item ' + cls });
          row.appendChild(el('span', null, cb.name || cb.key || 'CB'));
          const r = el('span');
          r.appendChild(document.createTextNode('failures: ' + (cb.failures || 0) + ' | '));
          r.appendChild(el('span', { className: 'status-badge', style: 'background:' + color + ';color:#fff' }, label));
          row.appendChild(r);
          cbEl.appendChild(row);
        });
      }
      const configEl = document.getElementById('config-display');
      if (config) {
        const safe = Object.assign({}, config, { apiKeyConfigured: config.apiKeyConfigured ? true : false });
        configEl.textContent = JSON.stringify(safe, null, 2);
      } else { configEl.textContent = 'N/A'; }
    } catch (err) { showError(I.err); }
  }

  function init() {
    document.querySelectorAll('.nav-btn').forEach((btn) => btn.addEventListener('click', () => switchTab(btn.dataset.tab)));
    document.getElementById('lang-selector')?.addEventListener('change', (e) => { document.documentElement.lang = e.target.value; location.reload(); });
    document.getElementById('task-status-filter')?.addEventListener('change', applyTaskFilters);
    document.getElementById('task-type-filter')?.addEventListener('change', applyTaskFilters);
    document.getElementById('task-search')?.addEventListener('input', applyTaskFilters);
    setInterval(() => { const e = document.getElementById('last-update'); if (e) e.textContent = new Date().toLocaleString(); }, 1000);
    switchTab('overview');
    connectSSE();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();