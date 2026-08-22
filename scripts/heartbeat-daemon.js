#!/usr/bin/env node
// scripts/heartbeat-daemon.js — EPIC-277-F (北极星数据源 AC1 + AC2)
//
// 为什么存在 (跟 scripts/heartbeat-daemon.sh 的分工):
//   heartbeat-daemon.sh 是 EPIC-015 的 per-instance tick loop, 要求实例目录
//   已存在 (state.json 缺失直接 exit 1), 且只能前台无限循环 — 没有实例注册,
//   没有单次 tick, 没有崩溃恢复. 结果: `.kallax/instances/` 长期为空,
//   expert_invocations 数据源常年 0 行, Rule 36 指标 #1 恒 NO_DATA.
//
//   本脚本补的是"注册 + 生命周期"这一层: 自己建实例目录, 写 daemon 实例 JSON,
//   支持 --once 单次 tick (CI / 门控可验证), 支持 pause / resume / 崩溃恢复.
//   每次 tick 通过 scripts/lib/expert-invocation-queue.sh 的 emit() 真写队列.
//
// Usage:
//   node scripts/heartbeat-daemon.js --daemon --once
//   node scripts/heartbeat-daemon.js --daemon --interval 60
//   node scripts/heartbeat-daemon.js --pause | --resume | --status | --stop
//
// Options:
//   --daemon                 启动 daemon (注册实例 + tick)
//   --once                   只跑 1 次 tick 就退出 (exit 0), 不进循环
//   --instance-id <id>       实例 ID (默认 heartbeat_daemon)
//   --instances-dir <dir>    实例根目录 (默认 .kallax/instances)
//   --interval <seconds>     tick 间隔 (默认 60, 仅 --daemon 无 --once 时用)
//   --expert-id <id>         emit 用的 expert_id (默认 kallax.heartbeat.001)
//   --ticket-id <id>         emit 用的 ticket_id (默认从 KALLAX_TICKET_ID 或 EPIC-277-F)
//   --no-emit                跳过 emit (只写实例状态, 给不想污染队列的测试用)
//   --pause / --resume       置 / 清 paused 标志 (tick 跳过但实例保留)
//   --status                 打印实例 JSON 到 stdout, exit 0
//   --stop                   给运行中的 daemon 发 SIGTERM
//
// Exit codes:
//   0 = OK
//   1 = 参数错误 / 实例状态无法写入 (fail-fast, 不静默降级)
//   2 = 依赖缺失 (bash / 队列 lib 不存在)

import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(SCRIPT_DIR, '..');
const QUEUE_LIB = join(SCRIPT_DIR, 'lib', 'expert-invocation-queue.sh');

const DEFAULTS = Object.freeze({
  instanceId: 'heartbeat_daemon',
  instancesDir: '.kallax/instances',
  intervalSeconds: 60,
  expertId: 'kallax.heartbeat.001',
});

// ── 结构化日志 (Observable by Design: 事件 > 自由文本) ─────────────────────
function logEvent(level, event, ctx) {
  const line = JSON.stringify({ level, event, ts: new Date().toISOString(), ...ctx });
  process.stderr.write(`${line}\n`);
}

// ── 参数解析 (fail-fast, 未知参数直接 exit 1) ──────────────────────────────
function parseArgs(argv) {
  const opts = {
    daemon: false,
    once: false,
    pause: false,
    resume: false,
    status: false,
    stop: false,
    noEmit: false,
    instanceId: DEFAULTS.instanceId,
    instancesDir: DEFAULTS.instancesDir,
    intervalSeconds: DEFAULTS.intervalSeconds,
    expertId: DEFAULTS.expertId,
    ticketId: process.env.KALLAX_TICKET_ID || 'EPIC-277-F',
  };

  const needValue = (i, name) => {
    const v = argv[i + 1];
    if (v === undefined || v.startsWith('--')) {
      throw new Error(`${name} requires a value`);
    }
    return v;
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case '--daemon': opts.daemon = true; break;
      case '--once': opts.once = true; break;
      case '--pause': opts.pause = true; break;
      case '--resume': opts.resume = true; break;
      case '--status': opts.status = true; break;
      case '--stop': opts.stop = true; break;
      case '--no-emit': opts.noEmit = true; break;
      case '--instance-id': opts.instanceId = needValue(i, arg); i += 1; break;
      case '--instances-dir': opts.instancesDir = needValue(i, arg); i += 1; break;
      case '--expert-id': opts.expertId = needValue(i, arg); i += 1; break;
      case '--ticket-id': opts.ticketId = needValue(i, arg); i += 1; break;
      case '--interval': {
        const raw = needValue(i, arg);
        i += 1;
        const n = Number.parseInt(raw, 10);
        if (!Number.isFinite(n) || n <= 0) {
          throw new Error(`--interval must be a positive integer (got: ${raw})`);
        }
        opts.intervalSeconds = n;
        break;
      }
      case '-h':
      case '--help':
        opts.help = true;
        break;
      default:
        throw new Error(`unknown arg: ${arg}`);
    }
  }

  if (!/^[A-Za-z0-9._-]{1,64}$/.test(opts.instanceId)) {
    throw new Error(`--instance-id must match [A-Za-z0-9._-]{1,64} (got: ${opts.instanceId})`);
  }
  if (!/^[A-Za-z0-9._-]{1,128}$/.test(opts.expertId)) {
    throw new Error(`--expert-id must match [A-Za-z0-9._-]{1,128} (got: ${opts.expertId})`);
  }
  if (!/^[A-Za-z0-9._-]{1,64}$/.test(opts.ticketId)) {
    throw new Error(`--ticket-id must match [A-Za-z0-9._-]{1,64} (got: ${opts.ticketId})`);
  }

  return opts;
}

function printHelp() {
  process.stdout.write(`heartbeat-daemon.js — KALLAX 实例心跳 daemon (EPIC-277-F)

USAGE:
  node scripts/heartbeat-daemon.js --daemon --once
  node scripts/heartbeat-daemon.js --daemon --interval 60
  node scripts/heartbeat-daemon.js --pause | --resume | --status | --stop

OPTIONS:
  --daemon                 启动 daemon (注册实例 + tick)
  --once                   单次 tick 后 exit 0
  --instance-id <id>       实例 ID (默认 ${DEFAULTS.instanceId})
  --instances-dir <dir>    实例根目录 (默认 ${DEFAULTS.instancesDir})
  --interval <seconds>     tick 间隔秒 (默认 ${DEFAULTS.intervalSeconds})
  --expert-id <id>         emit 的 expert_id (默认 ${DEFAULTS.expertId})
  --ticket-id <id>         emit 的 ticket_id
  --no-emit                跳过 emit
  --pause / --resume       暂停 / 恢复 tick
  --status                 打印实例 JSON
  --stop                   SIGTERM 运行中的 daemon

EXIT CODES:
  0  OK
  1  参数错误 / 实例状态写入失败
  2  依赖缺失 (bash / 队列 lib)
`);
}

// ── 路径 ──────────────────────────────────────────────────────────────────
function instancePaths(opts) {
  const root = resolve(opts.instancesDir);
  const dir = join(root, opts.instanceId);
  return { root, dir, daemonFile: join(dir, 'daemon.json'), stateFile: join(dir, 'state.json') };
}

// ── 原子写 (temp + rename, 跟 heartbeat-daemon.sh atomic_write_with_fsync 同口径) ──
function atomicWriteJson(path, obj) {
  const tmp = `${path}.tmp.${process.pid}`;
  writeFileSync(tmp, `${JSON.stringify(obj, null, 2)}\n`, { mode: 0o600 });
  renameSync(tmp, path);
}

function readJson(path) {
  if (!existsSync(path)) return null;
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (e) {
    const reason = e instanceof Error ? e.message : String(e);
    logEvent('warn', 'instance_json_unreadable', { path, reason });
    return null;
  }
}

function isPidAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (e) {
    // EPERM = 进程存在但不属于本用户; ESRCH = 不存在
    return e instanceof Error && 'code' in e && e.code === 'EPERM';
  }
}

// ── 实例注册 + 崩溃恢复 ────────────────────────────────────────────────────
// 上一次的 daemon.json 若 pid 已死 → 认定崩溃, restart_count +1, 记 recovered_from.
function registerInstance(opts, paths) {
  mkdirSync(paths.dir, { recursive: true, mode: 0o700 });

  const prev = readJson(paths.daemonFile);
  let restartCount = 0;
  let recoveredFrom = null;
  let crashRecovered = false;

  if (prev && typeof prev === 'object') {
    restartCount = Number.isInteger(prev.restart_count) ? prev.restart_count : 0;
    const prevPid = Number.isInteger(prev.pid) ? prev.pid : 0;
    const prevStatus = typeof prev.status === 'string' ? prev.status : '';
    const cleanExit = prevStatus === 'STOPPED' || prevStatus === 'COMPLETED';
    if (!cleanExit && prevPid > 0 && prevPid !== process.pid && !isPidAlive(prevPid)) {
      crashRecovered = true;
      restartCount += 1;
      recoveredFrom = { pid: prevPid, status: prevStatus, last_beat: prev.last_beat ?? null };
      logEvent('warn', 'crash_recovered', {
        instance_id: opts.instanceId, dead_pid: prevPid, restart_count: restartCount,
      });
    }
  }

  const paused = prev !== null && prev.paused === true;

  const record = {
    instance_id: opts.instanceId,
    role: 'heartbeat_daemon',
    pid: process.pid,
    // paused 优先于 RECOVERED/ACTIVE: 暂停是显式人为状态, 启动不该悄悄清掉它
    status: paused ? 'PAUSED' : (crashRecovered ? 'RECOVERED' : 'ACTIVE'),
    paused,
    interval_seconds: opts.intervalSeconds,
    expert_id: opts.expertId,
    ticket_id: opts.ticketId,
    started_at: new Date().toISOString(),
    last_beat: (prev && prev.last_beat) || null,
    beat_count: (prev && Number.isInteger(prev.beat_count)) ? prev.beat_count : 0,
    missed_count: 0,
    restart_count: restartCount,
    crash_recovered: crashRecovered,
    recovered_from: recoveredFrom,
    emit_enabled: !opts.noEmit,
    repo_root: REPO_ROOT,
    schema_version: 1,
  };

  atomicWriteJson(paths.daemonFile, record);

  // state.json: 兼容 heartbeat-daemon.sh 读的字段 (heartbeat.last_beat 等),
  // 让两个 daemon 实现共用同一个实例目录, 不各自造一套 schema.
  const prevState = readJson(paths.stateFile) || {};
  atomicWriteJson(paths.stateFile, {
    ...prevState,
    instance_id: opts.instanceId,
    status: record.status,
    expert_id: opts.expertId,
    ticket_id: opts.ticketId,
    heartbeat: {
      last_beat: record.last_beat,
      missed_count: 0,
      heartbeat_daemon_pid: process.pid,
    },
    expert_invocations: Array.isArray(prevState.expert_invocations) ? prevState.expert_invocations : [],
  });

  logEvent('info', 'instance_registered', {
    instance_id: opts.instanceId,
    daemon_file: paths.daemonFile,
    status: record.status,
    restart_count: restartCount,
  });

  return record;
}

// ── emit: 真写 expert_invocations 队列 (AC2) ────────────────────────────────
// 复用 scripts/lib/expert-invocation-queue.sh 的降级链 (Redis→SQLite→JSONL),
// 不在 JS 侧另写一份 SQLite 逻辑 (DRY: 单一真相来源在 bash lib).
function emitInvocation(opts) {
  if (opts.noEmit) {
    logEvent('info', 'emit_skipped', { reason: 'no_emit_flag' });
    return { ok: true, skipped: true };
  }
  if (!existsSync(QUEUE_LIB)) {
    logEvent('error', 'emit_lib_missing', { queue_lib: QUEUE_LIB });
    return { ok: false, skipped: false, reason: 'queue_lib_missing' };
  }

  const script = `set -euo pipefail; source "$1"; emit "$2" "$3"`;
  const res = spawnSync('bash', ['-c', script, 'heartbeat-emit', QUEUE_LIB, opts.expertId, opts.ticketId], {
    encoding: 'utf8',
    timeout: 30_000,
  });

  if (res.error) {
    logEvent('error', 'emit_spawn_failed', { reason: res.error.message });
    return { ok: false, skipped: false, reason: res.error.message };
  }
  if (res.status !== 0) {
    logEvent('error', 'emit_failed', {
      exit_code: res.status,
      stderr: (res.stderr || '').trim().slice(0, 500),
    });
    return { ok: false, skipped: false, reason: `exit=${res.status}` };
  }

  logEvent('info', 'emit_ok', { expert_id: opts.expertId, ticket_id: opts.ticketId });
  return { ok: true, skipped: false };
}

// ── 单次 tick ─────────────────────────────────────────────────────────────
function tick(opts, paths) {
  const record = readJson(paths.daemonFile);
  if (!record) {
    logEvent('error', 'tick_no_instance', { daemon_file: paths.daemonFile });
    return { ok: false, paused: false };
  }

  if (record.paused === true) {
    record.status = 'PAUSED';
    record.missed_count = (Number.isInteger(record.missed_count) ? record.missed_count : 0) + 1;
    atomicWriteJson(paths.daemonFile, record);
    logEvent('info', 'tick_paused', { instance_id: opts.instanceId, missed_count: record.missed_count });
    return { ok: true, paused: true };
  }

  const emitted = emitInvocation(opts);

  record.status = 'ACTIVE';
  record.last_beat = new Date().toISOString();
  record.beat_count = (Number.isInteger(record.beat_count) ? record.beat_count : 0) + 1;
  record.missed_count = 0;
  record.last_emit_ok = emitted.ok;
  atomicWriteJson(paths.daemonFile, record);

  const state = readJson(paths.stateFile) || {};
  state.status = 'ACTIVE';
  state.heartbeat = {
    last_beat: record.last_beat,
    missed_count: 0,
    heartbeat_daemon_pid: process.pid,
  };
  atomicWriteJson(paths.stateFile, state);

  logEvent('info', 'tick_ok', {
    instance_id: opts.instanceId,
    beat_count: record.beat_count,
    emit_ok: emitted.ok,
  });
  return { ok: emitted.ok, paused: false };
}

function setPaused(opts, paths, paused) {
  const record = readJson(paths.daemonFile);
  if (!record) {
    logEvent('error', 'pause_no_instance', { daemon_file: paths.daemonFile });
    return 1;
  }
  record.paused = paused;
  record.status = paused ? 'PAUSED' : 'ACTIVE';
  atomicWriteJson(paths.daemonFile, record);
  logEvent('info', paused ? 'paused' : 'resumed', { instance_id: opts.instanceId });
  return 0;
}

function showStatus(paths) {
  const record = readJson(paths.daemonFile);
  if (!record) {
    logEvent('error', 'status_no_instance', { daemon_file: paths.daemonFile });
    return 1;
  }
  process.stdout.write(`${JSON.stringify(record, null, 2)}\n`);
  return 0;
}

function stopDaemon(paths) {
  const record = readJson(paths.daemonFile);
  if (!record || !Number.isInteger(record.pid)) {
    logEvent('error', 'stop_no_instance', { daemon_file: paths.daemonFile });
    return 1;
  }
  if (!isPidAlive(record.pid)) {
    record.status = 'STOPPED';
    atomicWriteJson(paths.daemonFile, record);
    logEvent('info', 'stop_already_dead', { pid: record.pid });
    return 0;
  }
  try {
    process.kill(record.pid, 'SIGTERM');
  } catch (e) {
    const reason = e instanceof Error ? e.message : String(e);
    logEvent('error', 'stop_failed', { pid: record.pid, reason });
    return 1;
  }
  logEvent('info', 'stop_signalled', { pid: record.pid });
  return 0;
}

function markStopped(paths) {
  const record = readJson(paths.daemonFile);
  if (!record) return;
  record.status = 'STOPPED';
  record.pid = 0;
  atomicWriteJson(paths.daemonFile, record);
}

const sleep = (ms) => new Promise((r) => { setTimeout(r, ms); });

async function runLoop(opts, paths) {
  let stopping = false;
  const onSignal = (sig) => {
    stopping = true;
    logEvent('info', 'signal_received', { signal: sig });
  };
  process.on('SIGTERM', () => onSignal('SIGTERM'));
  process.on('SIGINT', () => onSignal('SIGINT'));

  while (!stopping) {
    tick(opts, paths);
    // 拆成 100ms 片, 让 SIGTERM 不用等满一个 interval
    const slices = Math.max(1, Math.round((opts.intervalSeconds * 1000) / 100));
    for (let i = 0; i < slices && !stopping; i += 1) {
      await sleep(100);
    }
  }

  markStopped(paths);
  logEvent('info', 'daemon_stopped', { instance_id: opts.instanceId });
  return 0;
}

async function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (e) {
    const reason = e instanceof Error ? e.message : String(e);
    logEvent('error', 'bad_args', { reason });
    printHelp();
    return 1;
  }

  if (opts.help) {
    printHelp();
    return 0;
  }

  const paths = instancePaths(opts);

  if (opts.status) return showStatus(paths);
  if (opts.stop) return stopDaemon(paths);
  if (opts.pause || opts.resume) {
    if (opts.pause && opts.resume) {
      logEvent('error', 'bad_args', { reason: '--pause and --resume are mutually exclusive' });
      return 1;
    }
    // pause/resume 允许在实例尚未注册时先建目录 (幂等)
    mkdirSync(paths.dir, { recursive: true, mode: 0o700 });
    return setPaused(opts, paths, opts.pause);
  }

  if (!opts.daemon) {
    logEvent('error', 'bad_args', { reason: 'one of --daemon / --pause / --resume / --status / --stop required' });
    printHelp();
    return 1;
  }

  if (spawnSync('bash', ['-c', 'exit 0']).status !== 0) {
    logEvent('error', 'missing_dependency', { dependency: 'bash' });
    return 2;
  }

  try {
    registerInstance(opts, paths);
  } catch (e) {
    const reason = e instanceof Error ? e.message : String(e);
    logEvent('error', 'register_failed', { reason, daemon_file: paths.daemonFile });
    return 1;
  }

  if (opts.once) {
    const r = tick(opts, paths);
    const record = readJson(paths.daemonFile);
    if (record) {
      // paused 实例不该被 --once 收尾改成 COMPLETED — 那会把"暂停中"
      // 覆盖成"跑完了", 下次启动就看不出它本来是暂停的.
      if (record.paused !== true) {
        record.status = 'COMPLETED';
      }
      record.pid = 0;
      atomicWriteJson(paths.daemonFile, record);
    }
    // paused 状态下 tick 不 emit, 仍算成功 (暂停是预期状态, 不是失败)
    return (r.ok || r.paused) ? 0 : 1;
  }

  return runLoop(opts, paths);
}

main()
  .then((code) => { process.exitCode = code; })
  .catch((e) => {
    const reason = e instanceof Error ? e.message : String(e);
    logEvent('error', 'unhandled', { reason });
    process.exitCode = 1;
  });
