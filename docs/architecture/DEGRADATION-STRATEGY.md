# KALLAX 降级策略

> 优雅降级是系统韧性的核心

---

## 1. 概述

### 1.1 设计原则

1. **可用性优先**: 功能降级 > 服务不可用
2. **透明可观测**: 每次降级必须记录日志和指标
3. **自动恢复**: 定期探测上级服务，条件满足自动恢复
4. **无感知切换**: 对使用者 API 保持一致

### 1.2 架构改进

| 问题 | 旧框架 | KALLAX |
|-----|------|--------|
| 降级日志 | 静默降级 | 强制 WARN 日志 |
| 降级指标 | 无 | 必须发射 metric |
| 恢复机制 | 无 | 自动探测 + 恢复 |
| 状态展示 | 无 | Dashboard 实时显示 |

---

## 2. 降级层级定义

```
┌─────────────────────────────────────────────────────────────┐
│                   Level 3: Full Production                   │
│                                                              │
│  组件:                                                       │
│  • Rust Core (8ms 启动)                                     │
│  • Redis Cluster (消息队列)                                  │
│  • PostgreSQL (持久化)                                       │
│  • Full Observability Stack                                  │
│                                                              │
│  能力: 100%                                                  │
│  延迟: P99 < 10ms                                           │
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         │        降级触发条件               │
         │  • rust binary not found          │
         │  • rust startup timeout > 5s      │
         │  • rust crash 3 times in 5min     │
         └─────────────────┬─────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Level 2: Node.js + Redis                   │
│                                                              │
│  组件:                                                       │
│  • Node.js Runtime (400ms 启动)                             │
│  • Redis (消息队列)                                          │
│  • SQLite (本地持久化)                                       │
│  • Basic Metrics                                             │
│                                                              │
│  能力: 80%                                                   │
│  延迟: P99 < 100ms                                          │
│  损失: DAG 调度精度降低, 无关键路径分析                     │
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         │        降级触发条件               │
         │  • redis connection timeout > 5s  │
         │  • redis error rate > 50%         │
         │  • redis cluster unavailable      │
         └─────────────────┬─────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Level 1: Node.js + File                    │
│                                                              │
│  组件:                                                       │
│  • Node.js Runtime                                           │
│  • File-based Queue (.kallax/queue/)                        │
│  • SQLite                                                    │
│                                                              │
│  能力: 50%                                                   │
│  延迟: P99 < 500ms                                          │
│  损失: 无实时消息推送, 轮询模式                             │
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         │        降级触发条件               │
         │  • node not found                 │
         │  • npm modules missing            │
         │  • node crash 5 times in 5min     │
         └─────────────────┬─────────────────┘
            Level 0: Shell Emergency                   │
│                                                              │
│  组件:                                                       │
│  • Pure Bash                                                 │
│  • Git                                                       │
│  • File-based Everything                                     │
│                                                              │
│  能力: 20%                                                   │
│  延迟: 无 SLA                                               │
│  损失: 仅保留基本任务流转                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 各层级能力矩阵

| 功能 | Level 3 | Level 2 | Level 1 | Level 0 |
|-----|---------|---------|---------|---------|
| 任务创建 | ✓ | ✓ | ✓ | ✓ |
| 任务领取 | ✓ | ✓ | ✓ | ✓ |
| 任务完成 | ✓ | ✓ | ✓ | ✓ |
| DAG 调度 | ✓ | △ (简化) | ✗ | ✗ |
| 关键路径分析 | ✓ | ✗ | ✗ | ✗ |
| 实时消息推送 | ✓ | ✓ | ✗ | ✗ |
| Web Dashboard | ✓ | ✓ | △ (只读) | ✗ |
| FTS 搜索 | ✓ | ✓ | △ (grep) | grep |
| TF-IDF 推荐 | ✓ | ✗ | ✗ | ✗ |
| 并行调度 | ✓ 5+ | ✓ 3 | ✓ 1 | ✓ 1 |
| Metrics | Full | Basic | File | None |

---

## 4. 自动降级触发条件

### 4.1 Rust → Node.js

```yaml
degradation:
  rust_to_node:
    triggers:
      # 二进制不存在
      - type: binary_missing
        check: "which kallax-core"
        
      # 启动超时
      - type: startup_timeout
        threshold: 5000  # ms
        
      # 连续崩溃
      - type: crash_count
        count: 3
        window: 300  # seconds
        
      # 健康检查失败
      - type: health_check
        endpoint: "http://localhost:9877/health"
        timeout: 1000
        failures: 3
```

### 4.2 Redis → File Queue

```yaml
degradation:
  redis_to_file:
    triggers:
      # 连接超时
      - type: connection_timeout
        threshold: 5000  # ms
        
      # 错误率
      - type: error_rate
        threshold: 0.5  # 50%
        window: 60      # seconds
        
      # Cluster 不可用
      - type: cluster_unavailable
        min_nodes: 2
```

### 4.3 Node.js → Shell

```yaml
degradation:
  node_to_shell:
    triggers:
      # Node.js 不存在
      - type: runtime_missing
        check: "which node"
        
      # 依赖缺失
      - type: deps_missing
        check: "test -d node_modules"
        
      # 启动超时
      - type: startup_timeout
        threshold: 10000  # ms
        
      # 连续崩溃
      - type: crash_count
        count: 5
        window: 300
```

---

## 5. KALLAX 改进: 显式日志/指标要求

### 5.1 降级日志规范

```typescript
// ❌ 旧: 静默降级
function degradeToFileQueue() {
  this.queue = new FileQueue();  // 无日志
}

// ✅ KALLAX: 显式降级
function degradeToFileQueue(reason: DegradationReason) {
  // 1. 必须记录 WARN 级别日志
  logger.warn({
    event: 'degradation_triggered',
    from: 'redis',
    to: 'file_queue',
    reason: reason,
    timestamp: Date.now(),
    context: {
      redis_last_error: this.lastRedisError?.message,
      redis_error_count: this.errorCount,
      uptime: process.uptime()
    }
  }, `Queue degraded from Redis to FileQueue: ${reason}`);
  
  // 2. 必须发射 metric
  metrics.increment('kallax.degradation.triggered', {
    from: 'redis',
    to: 'file_queue',
    reason: reason
  });
  
  // 3. 必须更新状态
  this.degradationState = {
    level: 'file_queue',
    since: Date.now(),
    reason: reason
  };
  
  // 4. 执行降级
  this.queue = new FileQueue();
}
```

### 5.2 降级指标规范

```typescript
// 必须发射的指标
const degradationMetrics = {
  // 降级触发
  'kallax.degradation.triggered': {
    type: 'counter',
    labels: ['from', 'to', 'reason']
  },
  
  // 降级持续时间
  'kallax.degradation.duration': {
    type: 'histogram',
    labels: ['level']
  },
  
  // 当前降级状态
  'kallax.degradation.current_level': {
    type: 'gauge',
    labels: []  // 0=full, 1=node_file, 2=shell
  },
  
  // 恢复成功
  'kallax.degradation.recovered': {
    type: 'counter',
    labels: ['from', 'to']
  }
};
```

### 5.3 Dashboard 展示

```
┌─────────────────────────────────────────────────────────────┐
│  KALLAX System Status                                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Current Level: Level 2 (Node.js + Redis)    ⚠️ DEGRADED    │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Timeline                                               │  │
│  │ 10:00 ████████████████████ Level 3 (Full)            │  │
│  │ 10:15 ████████▓▓▓▓▓▓▓▓▓▓▓▓ Level 2 (Degraded)        │  │
│  │ 10:30 ████████████████████ Level 3 (Recovered)       │  │
│  │ 11:00 ████████▓▓▓▓▓▓▓▓▓▓▓▓ Level 2 (Degraded) ← NOW  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  Degradation Events (Last 24h):                             │
│  • 11:00 - Redis timeout → Degraded to Level 2              │
│  • 10:30 - Redis recovered → Upgraded to Level 3            │
│  • 10:15 - Redis connection lost → Degraded to Level 2      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. 恢复策略

### 6.1 自动恢复流程

```typescript
class RecoveryManager {
  private checkInterval = 60000;  // 1 分钟
  private successThreshold = 3;    // 连续 3 次成功
  private successCount = 0;
  
  async checkAndRecover() {
    // 1. 检查上级服务是否恢复
    const isHealthy = await this.probeUpperLevel();
    
    if (isHealthy) {
      this.successCount++;
      
      logger.info({
        event: 'recovery_probe_success',
        successCount: this.successCount,
        threshold: this.successThreshold
      }, 'Upper level probe successful');
      
      // 2. 连续成功达到阈值才恢复
      if (this.successCount >= this.successThreshold) {
        await this.recover();
      }
    } else {
      this.successCount = 0;  // 重置计数
    }
  }
  
  async recover() {
    const fromLevel = this.currentLevel;
    const toLevel = this.getUpperLevel();
    
    // 1. 记录恢复日志
    logger.info({
      event: 'degradation_recovered',
      from: fromLevel,
      to: toLevel,
      degradation_duration: Date.now() - this.degradationState.since
    }, `System recovered from ${fromLevel} to ${toLevel}`);
    
    // 2. 发射恢复指标
    metrics.increment('kallax.degradation.recovered', {
      from: fromLevel,
      to: toLevel
    });
    
    metrics.histogram('kallax.degradation.duration', 
      Date.now() - this.degradationState.since,
      { level: fromLevel }
    );
    
    // 3. 执行恢复
    await this.switchToLevel(toLevel);
    
    // 4. 重置状态
    this.degradationState = null;
    this.successCount = 0;
  }
}
```

### 6.2 手动恢复

```bash
# 查看当前降级状态
kallax system:status

# 强制恢复到指定级别 (需人工确认)
kallax system:recover --level full --force

# 禁用自动恢复 (维护期间)
kallax system:auto-recovery --disable

# 重新启用
kallax system:auto-recovery --enable
```

---

## 7. 降级测试

### 7.1 混沌测试

```bash
# 模拟 Rust 崩溃
kallax chaos:inject --target rust --type crash

# 模拟 Redis 不可用
kallax chaos:inject --target redis --type unavailable --duration 60s

# 模拟网络延迟
kallax chaos:inject --target redis --type latency --delay 5000ms

# 验证降级行为
kallax chaos:verify
```

### 7.2 降级演练清单

```markdown
## 月度降级演练

### 准备
- [ ] 通知团队演练时间
- [ ] 确认监控告警静默
- [ ] 准备回滚方案

### Level 3 → Level 2 演练
- [ ] 停止 Rust 核心
- [ ] 验证系统自动降级
- [ ] 验证日志正确记录
- [ ] 验证指标正确发射
- [ ] 验证 Dashboard 状态更新
- [ ] 验证基本功能可用
- [ ] 恢复 Rust 核心
- [ ] 验证自动恢复

### Level 2 → Level 1 演练
- [ ] 停止 Redis
- [ ] 验证系统自动降级
- [ ] 验证文件队列工作
- [ ] 恢复 Redis
- [ ] 验证自动恢复

### 复盘
- [ ] 记录发现的问题
- [ ] 更新 Runbook
- [ ] 优化恢复流程
```

---

## 8. 配置参考

```yaml
# .kallax/config.yml
degradation:
  # 降级模式
  mode: auto  # auto | manual | disabled
  
  # Rust 层降级配置
  rust:
    startup_timeout: 5000      # ms
    crash_threshold: 3
    crash_window: 300          # seconds
    health_check_interval: 10000
    health_check_timeout: 1000
    
  # Redis 层降级配置
  redis:
    connection_timeout: 5000
    error_rate_threshold: 0.5
    error_rate_window: 60
    
  # Node.js 层降级配置
  node:
    startup_timeout: 10000
    crash_threshold: 5
    crash_window: 300
    
  # 恢复配置
  recovery:
    enabled: true
    check_interval: 60000      # 1 分钟
    success_threshold: 3       # 连续 3 次成功
    
  # 日志配置
  logging:
    level: warn                # 降级日志级别
    include_context: true      # 包含上下文信息
    
  # 指标配置
  metrics:
    enabled: true
    prefix: kallax.degradation
```

---

## 9. 故障排查

### 9.1 常见问题

**Q: 系统频繁在 Level 2 和 Level 3 之间切换?**

A: 检查 Redis 稳定性，可能需要:
- 增加 `connection_timeout`
- 降低 `error_rate_threshold`
- 增加 `success_threshold`

**Q: 降级后无法自动恢复?**

A: 检查:
- 恢复探测是否执行 (`kallax system:status`)
- 上级服务健康检查是否通过
- `success_threshold` 是否过高

**Q: 降级日志未记录?**

A: 检查:
- 日志级别配置 (`logging.level`)
- 降级代码是否遵循规范
- Logger 是否正确初始化

### 9.2 诊断命令

```bash
# 完整系统诊断
kallax system:doctor

# 查看降级历史
kallax system:degradation-history --last 24h

# 查看当前状态详情
kallax system:status --verbose

# 手动触发健康检查
kallax system:health-check --all
```
