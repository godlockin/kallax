# 架构经验教训

> 从历史项目中提炼的教训，指导 KALLAX 的设计改进

---

## 1. 并行隔离问题

### 问题描述
历史项目中多个 Performer 并行工作时，经常发生文件冲突和隐式依赖问题：
- 两个 Performer 同时修改同一文件导致 git 冲突
- 隐式依赖未清理导致任务聚焦漂移
- 阻塞时间 2-3 小时

### 根因
- 缺乏文件范围隔离机制
- Master 协调不足
- Worktree 使用不强制

### KALLAX 改进
```yaml
# KALLAX: 强制 Worktree 隔离
isolation:
  enforce_worktree: true
  file_scope_check: true
  scope_overlap_action: reject

# 每个 Ticket 必须声明文件范围
file_scope:
  includes: [src/components/Login/**]
  excludes: [src/components/shared/**]
```

```bash
# 派发前检查
kallax isolation:check TASK-001 TASK-002
```

---

## 2. Agent 幻觉问题

### 问题描述
历史项目中 background agents 经常报告"完成"但实际零产出：
- 在 isolated context 中无文件写权限
- 汇报内容与实际不符

### 根因
- 未理解 background vs foreground 执行模式差异
- 未验证 Agent 产出真实性

### KALLAX 改进
```yaml
# KALLAX: 强制验证
verification:
  conductor_verify_output: true
  verification_steps:
    - command: "ls -la"
    - command: "git show --stat"
    - command: "npm test"
```

**规则**:
- 代码实现任务必须用 foreground 模式
- 分析任务可用 background（仅读取）ic
- 大文件解析导致 OOM

### 根因
- 开发时便利优先于运行时安全
- 缺乏 CI 检测

### KALLAX 改进
```rust
// ❌ 旧模式 (禁止)
let language = get_language("rust").expect("rust language not found");

// ✅ KALLAX 模式 (强制)
let language = get_language("rust")
    .ok_or(KallaxError::LanguageNotSupported { lang: "rust" })?;
```

```yaml
# KALLAX: CI 自动检测
error_handling:
  scan_on_commit: true
  forbidden_patterns:
    rust: [".expect(", ".unwrap()", "panic!"]
    typescript: [": any", "@ts-ignore"]
```

---

## 4. 类型安全问题

### 问题描述
历史项目中 46 处 `any` 类型，清理后发现 3 个潜在运行时错误。

### 根因
- 快速开发绕过类型检查
- 缺乏 CI 强制

### KALLAX 改进
```typescript
// ❌ 旧模式 (禁止)
function process(data: any): any { }
// @ts-ignore

// ✅ KALLAX 模式 (强制)
function process(data: unknown): Result<ProcessedData, ProcessError> {
  if (!isValidData(data)) {
    return err(ProcessError.invalidInput(data));
  }
  // 类型收窄后处理
}
```

---

## 5. 资源管理问题

### 问题描述
历史项目中缓存无 TTL 导致内存泄漏。

### 根因
- 使用原生 Map 作为缓存
- 未配置过期策略

### KALLAX 改进
```typescript
// ❌ 旧模式 (禁止)
const cache = new Map<string, Data>();

// ✅ KALLAX 模式 (强制)
const cache = new LRUCache<string, Data>({
  max: 1000,
  ttl: 5 * 60 * 1000,  // 必须配置 TTL
});
```

```yaml
# KALLAX: 资源配置
resources:
  cache:
    default_ttl: 300000  # 5 分钟
    max_entries: 1000
```

---

## 6. 静默降级问题

### 问题描述
远程配置失败时静默使用默认配置，无人知晓。

### 根因
- 降级逻辑隐藏在 catch 块
- 无日志/指标

### KALLAX 改进
```yaml
# KALLAX: 显式降级
degradation:
  log_on_degradation: true
  emit_metrics: true
```

```typescript
// ✅ KALLAX 降级模式
try {
  config = await fetchRemoteConfig();
} catch (e) {
  logger.warn({ error: e }, 'remote config failed, using fallback');
  metrics.increment('kallax.config.fallback');
  config = DEFAULT_CONFIG;
}
```

---

## 7. 测试质量问题

### 问题描述
历史项目中 82 个低质量测试内嵌实现源码逻辑，源码修改后测试仍通过。

### KALLAX 改进
- CI 检查测试是否导入源码
- Mutation testing 验证测试真实性
- 质量优于数量

---

## 总结: KALLAX P0 红线

1. **并行隔离必须强制** - Worktree + File Scope
2. **生产代码禁用 panic/expect** - 改用 Result
3. **Conductor 必须验证产出** - ls/git show/npm test
4. **所有缓存必须 TTL** - LRU + 过期
5. **禁用 any/@ts-ignore** - CI 检测
