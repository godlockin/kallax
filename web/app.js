/* KALLAX Dashboard — zero-dependency vanilla JS */
(function () {
  'use strict';

  const API = 'http://127.0.0.1:9877';
  let activeTab = 'overview';
  let tasksCache = [];
  const TASK_STATUSES = ['pending', 'claimed', 'running', 'completed', 'failed'];

  // --- i18n ---
  const LANG = (document.documentElement.lang || 'zh-CN').startsWith('zh') ? 'zh' : 'en';
  const TXT = {
    zh: {
      connecting: '连接中...', connected: '已连接', disconnected: '已断开',
      nav: ['概览', '任务', 'Agent', '系统'],
      stats: ['总任务数', '活跃 Agent', '完成率', '系统状态'],
      overview: { recentActivity: '最近活动', noActivity: '暂无活动', taskDistribution: '任务分布', noTaskData: '暂无数据' },
      taskTypes: { development: '开发', review: '审查', testing: '测试', bugfix: '修复', refactor: '重构' },
      tasks: { title: '任务面板', noTasks: '暂无任务', allStatus: '全部状态', allType: '全部类型', search: '搜索任务...' },
      agents: { title: 'Agent 实例', noAgents: '暂无实例' },
      system: { health: '系统健康', circuitBreakers: '断路器', config: '配置信息', noHealth: '暂无数据', noCB: '暂无数据' },
      health: ['健康', '降级', '异常'], cb: { closed: '关闭', open: '开启', halfOpen: '半开' },
      taskStatus: ['待领取', '已认领', '运行中', '已完成', '失败'],
      errMsg: '无法连接服务器，请确认 KALLAX API 正在运行',
      perf: { label: '%s 个活跃 | %s 个忙碌', idle: '空闲' },
    },
    en: {
      connecting: 'Connecting...', connected: 'Connected', disconnected: 'Disconnected',
      nav: ['Overview', 'Tasks', 'Agents', 'System'],
      stats: ['Total Tasks', 'Active Agents', 'Completion Rate', 'System Health'],
      overview: { recentActivity: 'Recent Activity', noActivity: 'No recent activity', taskDistribution: 'Task Distribution', noTaskData: 'No task data' },
      taskTypes: { development: 'Development', review: 'Review', testing: 'Testing', bugfix: 'Bug Fix', refactor: 'Refactor' },
      tasks: { title: 'Task Board', noTasks: 'No tasks found', allStatus: 'All Statuses', allType: 'All Types', search: 'Search tasks...' },
      agents: { title: 'Agent Instances', noAgents: 'No agents registered' },
      system: { health: 'System Health', circuitBreakers: 'Circuit Breakers', config: 'Configuration', noHealth: 'No health data', noCB: 'No circuit breaker data' },
      health: ['Healthy', 'Degraded', 'Unhealthy'], cb: { closed: 'Closed', open: 'Open', halfOpen: 'Half-Open' },
      taskStatus: ['Pending', 'Claimed', 'Running', 'Completed', 'Failed'],
      errMsg: 'Cannot connect to server. Ensure KALLAX API is running.',
      perf: { label: '%s active | %s busy', idle: 'Idle' },
    },
  };
  const _ = TXT[LANG];

  function t(path, fallback) {
    return path.split('.').reduce((o, k) => (o && o[k] !== undefined ? o[k] : fallback), _);
  }

  function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach((el) => {
      el.textContent = t(el.dataset.i18n, el.textContent);
    });
    // Translate filter dropdown options
    const statusOpts = document.querySelectorAll('#task-status-filter option');
    ['', ...TASK_STATUSES].forEach((v, i) => {
      if (statusOpts[i]) statusOpts[i].textContent = v ? _.taskStatus[TASK_STATUSES.indexOf(v)] : _.tasks.allStatus;
    });
    const typeOpts = document.querySelectorAll('#task-type-filter option');
    const typeVals = ['', 'development', 'review', 'testing', 'bugfix', 'refactor'];
    typeVals.forEach((v, i) => {
      if (typeOpts[i]) typeOpts[i].textContent = v ? _.taskTypes[v] : _.tasks.allType;
    });
    // Translate search placeholder
    const searchEl = document.getElementById('task-search');
    if (searchEl) searchEl.placeholder = _.tasks.search;
  }

  // --- API fetch ---
  async function api(path) {
    const res = await fetch(API + path);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const body = await res.json();
    if (!body.success) throw new Error(body.error?.message || body.error?.code || 'API error');
    return body.data;
  }

  // --- Error banner ---
  function showError(msg) {
    let banner = document.getElementById('error-banner');
    if (!banner) {
      banner = document.createElement('div');
      banner.id = 'error-banner';
      banner.style.cssText =
        'position:fixed;top:0;left:0;right:0;background:var(--accent-red);color:#fff;padding:12px 24px;text-align:center;z-index:999;font-size:0.9rem;cursor:pointer';
      banner.addEventListener('click', () => banner.remove());
      document.body.prepend(banner);
    }
    banner.textContent = msg + ' (click to dismiss)';
  }

  // --- Tab switching ---
  function switchTab(tab) {
    activeTab = tab;
    document.querySelectorAll('.nav-btn').forEach((btn) => {
      btn.classList.toggle('active', btn.dataset.tab === tab);
    });
    document.querySelectorAll('.tab-content').forEach((el) => {
      el.classList.toggle('active', el.id === 'tab-' + tab);
    });
    if (tab === 'overview') loadOverview();
    if (tab === 'tasks') renderTasks();
    if (tab === 'agents') loadAgents();
    if (tab === 'system') loadSystem();
  }

  // --- SSE ---
  let sse = null;
  function connectSSE() {
    const el = document.getElementById('connection-status');
    const dot = el?.querySelector('.status-dot');
    const txt = el?.querySelector('.status-text');
    if (txt) txt.textContent = _.connecting;

    sse = new EventSource(API + '/events');
    sse.onopen = () => {
      if (dot) dot.className = 'status-dot connected';
      if (txt) txt.textContent = _.connected;
    };
    sse.addEventListener('connected', (e) => {
      if (dot) dot.className = 'status-dot connected';
      if (txt) txt.textContent = _.connected;
      const data = JSON.parse(e.data);
      document.querySelector('.version').textContent = 'v' + (data.version || '1.0.0');
    });
    sse.onerror = () => {
      if (dot) dot.className = 'status-dot disconnected';
      if (txt) txt.textContent = _.disconnected;
      setTimeout(() => { if (sse.readyState === 2) connectSSE(); }, 3000);
    };
    sse.onmessage = (e) => {
      try {
        const ev = JSON.parse(e.data);
        if (ev.type) addActivity(ev);
        // Refresh data on task/instance events
        if (activeTab === 'overview') loadOverview();
        if (activeTab === 'tasks' && ev.type?.startsWith('task')) renderTasks();
        if (activeTab === 'agents' && ev.type?.startsWith('instance')) loadAgents();
      } catch (_) { /* ignore */ }
    };
  }

  // --- Activity feed ---
  const MAX_ACTIVITY = 20;
  function addActivity(ev) {
    const feed = document.getElementById('activity-feed');
    if (!feed) return;
    const empty = feed.querySelector('.empty-state');
    if (empty) empty.remove();

    const item = document.createElement('div');
    item.className = 'activity-item';
    const time = new Date(ev.timestamp || Date.now()).toLocaleTimeString();
    item.innerHTML =
      '<span>' + (ev.message || ev.type + (ev.data?.taskId ? ' ' + ev.data.taskId : '')) + '</span>' +
      '<span class="activity-time">' + time + '</span>';
    feed.prepend(item);
    while (feed.children.length > MAX_ACTIVITY) feed.lastChild.remove();
  }

  // --- Overview ---
  async function loadOverview() {
    try {
      const stats = await api('/stats');
      const s = stats;
      document.getElementById('stat-tasks').textContent = s.tasks.total;
      document.getElementById('stat-agents').textContent = s.instances.active;
      const rate = s.tasks.total > 0 ? Math.round((s.tasks.completed / s.tasks.total) * 100) + '%' : '0%';
      document.getElementById('stat-completion').textContent = rate;

      // Progress bars for task distribution
      const distEl = document.getElementById('task-distribution');
      const counts = TASK_STATUSES.map((st) => s.tasks[st] || 0);
      const max = Math.max(...counts, 1);
      distEl.innerHTML = TASK_STATUSES.map((st, i) => {
        const pct = Math.round((counts[i] / (s.tasks.total || 1)) * 100);
        return '<div class="progress-item">' +
          '<span class="progress-label">' + _.taskStatus[i] + '</span>' +
          '<div class="progress-bar"><div class="progress-fill" style="width:' + pct + '%"></div></div>' +
          '<span class="progress-count">' + counts[i] + '</span></div>';
      }).join('');

      // Health
      try {
        const health = await api('/health');
        document.getElementById('stat-health').textContent = _.health[health.status === 'healthy' ? 0 : health.status === 'degraded' ? 1 : 2];
        document.getElementById('stat-health').style.color = health.status === 'healthy' ? 'var(--accent-green)' : health.status === 'degraded' ? 'var(--accent-yellow)' : 'var(--accent-red)';
      } catch (_) {
        document.getElementById('stat-health').textContent = '-';
      }
    } catch (err) {
      showError(_.errMsg);
    }
  }

  // --- Tasks ---
  async function renderTasks() {
    try {
      const data = await api('/api/tasks');
      tasksCache = data.items || [];
      applyTaskFilters();
    } catch (err) {
      showError(_.errMsg);
    }
  }

  function applyTaskFilters() {
    const statusFilter = document.getElementById('task-status-filter').value;
    const typeFilter = document.getElementById('task-type-filter').value;
    const searchFilter = document.getElementById('task-search').value.toLowerCase();
    let filtered = tasksCache;
    if (statusFilter) filtered = filtered.filter((t) => t.status === statusFilter);
    if (typeFilter) filtered = filtered.filter((t) => t.type === typeFilter);
    if (searchFilter) filtered = filtered.filter((t) => (t.ticketId || t.id).toLowerCase().includes(searchFilter));

    const list = document.getElementById('task-list');
    if (!filtered.length) {
      list.innerHTML = '<p class="empty-state" data-i18n="tasks.noTasks">' + _.tasks.noTasks + '</p>';
      return;
    }
    list.innerHTML = filtered.map((t) => {
      const statusIdx = TASK_STATUSES.indexOf(t.status);
      const label = statusIdx >= 0 ? _.taskStatus[statusIdx] : t.status;
      return '<div class="task-item ' + t.status + '">' +
        '<div><strong>' + (t.ticketId || t.id) + '</strong>' +
        '<span style="color:var(--text-muted);font-size:0.8rem;margin-left:8px">' + (t.type || '') + '</span></div>' +
        '<div style="display:flex;align-items:center;gap:8px">' +
        '<span class="status-badge ' + t.status + '">' + label + '</span>' +
        (t.performerId ? '<span style="font-size:0.8rem;color:var(--text-muted)">' + t.performerId + '</span>' : '') +
        '<span style="font-size:0.8rem;color:var(--text-muted)">' + t.progress + '%</span></div></div>';
    }).join('');
  }

  // --- Agents ---
  async function loadAgents() {
    try {
      const agents = await api('/api/agents');
      const list = document.getElementById('agent-list');
      if (!agents.length) {
        list.innerHTML = '<p class="empty-state" data-i18n="agents.noAgents">' + _.agents.noAgents + '</p>';
        return;
      }
      list.innerHTML = agents.map((a) => {
        const up = Math.floor((Date.now() - a.startedAt) / 1000);
        const uptimeStr = up > 3600 ? Math.floor(up / 3600) + 'h' : up > 60 ? Math.floor(up / 60) + 'm' : up + 's';
        return '<div class="agent-item ' + a.status + '">' +
          '<div><strong>' + a.id.slice(0, 12) + '</strong>' +
          '<span style="color:var(--accent-purple);font-size:0.8rem;margin-left:8px">' + a.role + '</span>' +
          '<span style="color:var(--text-muted);font-size:0.8rem;margin-left:8px">' + uptimeStr + '</span></div>' +
          '<div>' +
          '<span class="status-badge ' + a.status + '">' + a.status + '</span>' +
          (a.currentTaskId ? '<span style="font-size:0.8rem;color:var(--accent-blue);margin-left:8px">' + a.currentTaskId.slice(0, 8) + '</span>' : '') +
          '</div></div>';
      }).join('');
    } catch (err) {
      showError(_.errMsg);
    }
  }

  // --- System ---
  async function loadSystem() {
    try {
      const [doctor, config, cbStats] = await Promise.all([
        api('/api/system/doctor').catch(() => null),
        api('/api/system/config').catch(() => null),
        api('/api/system/circuit-breakers').catch(() => []),
      ]);

      // Health checks
      const hc = document.getElementById('health-checks');
      if (!doctor) {
        hc.innerHTML = '<p class="empty-state">' + _.system.noHealth + '</p>';
      } else {
        const checks = [];
        checks.push({ name: 'Database', status: doctor.database?.connected ? 'healthy' : 'unhealthy' });
        checks.push({ name: 'SSE Bus', status: 'healthy', detail: (doctor.sse?.clientCount || 0) + ' clients' });
        checks.push({ name: 'Node.js', status: 'healthy', detail: 'v' + doctor.node });
        checks.push({ name: 'Host', status: 'healthy', detail: doctor.hostname });
        const memMB = Math.round((doctor.memory?.heapUsed || 0) / 1024 / 1024);
        checks.push({ name: 'Memory', status: memMB > 500 ? 'degraded' : 'healthy', detail: memMB + ' MB' });
        if (doctor.instances) {
          checks.push({ name: 'Instances', status: 'healthy', detail: doctor.instances.active + ' active' });
        }
        hc.innerHTML = checks.map((c) => {
          const label = c.status === 'healthy' ? _.health[0] : c.status === 'degraded' ? _.health[1] : _.health[2];
          return '<div class="health-item ' + c.status + '">' +
            '<span>' + c.name + '</span>' +
            '<span>' + (c.detail ? c.detail + ' — ' : '') + '<span class="status-badge" style="background:' +
            (c.status === 'healthy' ? 'var(--accent-green)' : c.status === 'degraded' ? 'var(--accent-yellow)' : 'var(--accent-red)') +
            ';color:#fff">' + label + '</span></span></div>';
        }).join('');
      }

      // Circuit breakers
      const cbEl = document.getElementById('circuit-breakers');
      const cbData = Array.isArray(cbStats) ? cbStats : [];
      if (!cbData.length) {
        cbEl.innerHTML = '<p class="empty-state">' + _.system.noCB + '</p>';
      } else {
        cbEl.innerHTML = cbData.map((cb) => {
          const stateLabel = _.cb[cb.state] || cb.state;
          const stateColor = cb.state === 'closed' ? 'var(--accent-green)' : cb.state === 'halfOpen' ? 'var(--accent-yellow)' : 'var(--accent-red)';
          return '<div class="health-item ' + (cb.state === 'closed' ? 'healthy' : cb.state === 'halfOpen' ? 'degraded' : 'unhealthy') + '">' +
            '<span>' + (cb.name || cb.key || 'CB') + '</span>' +
            '<span>failures: ' + (cb.failures || 0) + ' | <span class="status-badge" style="background:' + stateColor + ';color:#fff">' + stateLabel + '</span></span></div>';
        }).join('');
      }

      // Config
      const configEl = document.getElementById('config-display');
      if (config) {
        const safe = { ...config, apiKeyConfigured: config.apiKeyConfigured ? true : false };
        configEl.textContent = JSON.stringify(safe, null, 2);
      } else {
        configEl.textContent = 'N/A';
      }
    } catch (err) {
      showError(_.errMsg);
    }
  }

  // --- Init ---
  function init() {
    applyI18n();

    // Tab clicks
    document.querySelectorAll('.nav-btn').forEach((btn) => {
      btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });

    // Language selector
    document.getElementById('lang-selector')?.addEventListener('change', (e) => {
      document.documentElement.lang = e.target.value;
      location.reload();
    });

    // Task filter events
    document.getElementById('task-status-filter')?.addEventListener('change', applyTaskFilters);
    document.getElementById('task-type-filter')?.addEventListener('change', applyTaskFilters);
    document.getElementById('task-search')?.addEventListener('input', applyTaskFilters);

    // Last update time
    setInterval(() => {
      const el = document.getElementById('last-update');
      if (el) el.textContent = new Date().toLocaleString();
    }, 1000);

    // Initial load
    switchTab('overview');
    connectSSE();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
