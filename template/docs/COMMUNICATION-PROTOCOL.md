# 通信协议规范

> KALLAX Conductor-Performer 通信协议 v1.0

---

## 1. 概述

### 1.1 通信模型

```
┌─────────────────────────────────────────────────────────────────────┐
│                        通信架构                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐                           ┌─────────────┐          │
│  │  Conductor  │ ◀────── Request ─────────▶│  Performer  │          │
│  │             │                           │     #1      │          │
│  │             │ ◀────── Response ────────▶│             │          │
│  │             │                           └─────────────┘          │
│  │             │                                                    │
│  │             │                           ┌─────────────┐          │
│  │             │ ◀────── Request ─────────▶│  Performer  │          │
│  │             │                           │     #2      │          │
│  │             │ ◀────── Response ────────▶│             │          │
│  └─────────────┘                           └─────────────┘          │
│         │                                                           │
│         │                                                           │
│         ▼                                                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                     Message Queue                            │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │   │
│  │  │ List Queue  │  │ PubSub      │  │ File Queue  │         │   │
│  │  │ (单消费)     │  │ (广播)      │  │ (降级)      │         │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 队列模式

| 模式 | 使用场景 | 消费者 |
|-----|---------|-------|
| List Queue | 任务领取、PR Review | 单个消费者 |
| PubSub | 状态广播、进度更新 | 所有订阅者 |
| File Queue | 降级模式 | 轮询消费 |

---

## 2. 消息格式

### 2.1 基础消息结构

```typescript
interface Message {
  // 元数据
  id: string;              // 消息唯一 ID
  type: MessageType;       // 消息类型
  timestamp: Date;         // 发送时间
  
  // 路由
  from: AgentId;           // 发送方
  to: AgentId | 'broadcast'; // 接收方
  
  // 内容
  payload: unknown;        // 消息体
  
  // 追踪
  correlationId?: string;  // 关联 ID (用于请求-响应)
  traceId?: string;        // 追踪 ID (用于链路追踪)
}

type MessageType = 
  | 'task_assigned'
  | 'task_claimed'
  | 'progress_report'
  | 'pr_review_request'
  | 'review_result'
  | 'blocker_report'
  | 'question'
  | 'answer';
```

### 2.2 具体消息类型

#### 任务分配 (Conductor → Performer)

```typescript
interface TaskAssignedMessage {
  type: 'task_assigned';
  from: 'conductor';
  to: string;  // performer_id
  payload: {
    ticketId: string;
    title: string;
    priority: 'P0' | 'P1' | 'P2' | 'P3';
    estimate: number;  // 小时
    deadline?: Date;
    fileScope: {
      includes: string[];
      excludes: string[];
    };
    acceptanceCriteria: string[];
  };
}
```

#### 任务领取 (Performer → Conductor)

```typescript
interface TaskClaimedMessage {
  type: 'task_claimed';
  from: string;  // performer_id
  to: 'conductor';
  payload: {
    ticketId: string;
    performerId: string;
    claimedAt: Date;
    worktreePath: string;
  };
}
```

#### 进度报告 (Performer → Conductor)

```typescript
interface ProgressReportMessage {
  type: 'progress_report';
  from: string;  // performer_id
  to: 'conductor';
  payload: {
    ticketId: string;
    status: 'in_progress' | 'testing' | 'blocked';
    completion: number;  // 0-100
    currentStep: string;
    nextStep: string;
    blockers?: string[];
    estimatedRemaining?: number;  // 小时
  };
}
```

#### PR Review 请求 (Performer → Conductor)

```typescript
interface PRReviewRequestMessage {
  type: 'pr_review_request';
  from: string;  // performer_id
  to: 'conductor';
  payload: {
    ticketId: string;
    prNumber: number;
    prUrl: string;
    changedFiles: string[];
    testOutput: string;
    coverage: number;
    summary: string;
  };
}
```

#### Review 结果 (Conductor → Performer)

```typescript
interface ReviewResultMessage {
  type: 'review_result';
  from: 'conductor';
  to: string;  // performer_id
  correlationId: string;  // 对应 pr_review_request 的 id
  payload: {
    ticketId: string;
    prNumber: number;
    result: 'approved' | 'changes_requested' | 'needs_discussion';
    comments?: ReviewComment[];
    mergedAt?: Date;
  };
}

interface ReviewComment {
  file: string;
  line: number;
  comment: string;
  severity: 'error' | 'warning' | 'suggestion';
}
```

#### 阻塞报告 (Performer → Conductor)

```typescript
interface BlockerReportMessage {
  type: 'blocker_report';
  from: string;  // performer_id
  to: 'conductor';
  payload: {
    ticketId: string;
    blockerType: 'technical' | 'dependency' | 'clarification' | 'access';
    description: string;
    impact: 'blocked' | 'delayed';
    suggestedResolution?: string;
  };
}
```

#### 问题与回答

```typescript
// Performer → Conductor
interface QuestionMessage {
  type: 'question';
  from: string;  // performer_id
  to: 'conductor';
  payload: {
    ticketId: string;
    category: 'technical' | 'requirement' | 'process';
    question: string;
    context?: string;
    urgency: 'low' | 'medium' | 'high';
  };
}

// Conductor → Performer
interface AnswerMessage {
  type: 'answer';
  from: 'conductor';
  to: string;  // performer_id
  correlationId: string;  // 对应 question 的 id
  payload: {
    ticketId: string;
    answer: string;
    references?: string[];  // 相关文档链接
  };
}
```

---

## 3. 通信流程

### 3.1 任务派发流程

```
Conductor                    Queue                     Performer
    │                          │                          │
    │  1. task_assigned        │                          │
    │ ─────────────────────────▶                          │
    │                          │                          │
    │                          │  2. poll                 │
    │                          │ ◀────────────────────────│
    │                          │                          │
    │                          │  3. deliver              │
    │                          │ ─────────────────────────▶
    │                          │                          │
    │                          │  4. task_claimed         │
    │                          │ ◀────────────────────────│
    │                          │                          │
    │  5. notification         │                          │
    │ ◀────────────────────────│                          │
    │                          │                          │
```

### 3.2 PR Review 流程

```
Performer                   Queue                    Conductor
    │                          │                          │
    │  1. pr_review_request    │                          │
    │ ─────────────────────────▶                          │
    │                          │                          │
    │                          │  2. deliver              │
    │                          │ ─────────────────────────▶
    │                          │                          │
    │                          │  (Conductor 执行验证)     │
    │                          │                          │
    │                          │  3. review_result        │
    │                          │ ◀────────────────────────│
    │                          │                          │
    │  4. deliver              │                          │
    │ ◀────────────────────────│                          │
    │                          │                          │
    │  (如果 changes_requested)│                          │
    │  5. 修改代码             │                          │
    │                          │                          │
    │  6. 新的 pr_review_request                         │
    │ ─────────────────────────▶                          │
    │                          │                          │
```

### 3.3 心跳与状态同步

```
Conductor                    Queue                    All Performers
    │                          │                          │
    │                          │  1. poll heartbeat       │
    │ ◀────────────────────────│                          │
    │                          │                          │
    │  2. heartbeat_request    │                          │
    │ ─────────────────────────▶  (broadcast)             │
    │                          │ ─────────────────────────▶
    │                          │                          │
    │                          │  3. heartbeat_response   │
    │                          │ ◀────────────────────────│
    │                          │                          │
    │  4. aggregate            │                          │
    │ ◀────────────────────────│                          │
    │                          │                          │
    │  (检测超时 Performer)    │                          │
    │                          │                          │
```

---

## 4. 队列实现

### 4.1 Redis 实现 (Level 2/3)

```typescript
// List Queue (单消费)
class RedisListQueue implements MessageQueue {
  async send(message: Message): Promise<void> {
    const key = `kallax:queue:${message.to}`;
    await this.redis.lpush(key, JSON.stringify(message));
  }
  
  async receive(agentId: string, timeout: number): Promise<Message | null> {
    const key = `kallax:queue:${agentId}`;
    const result = await this.redis.brpop(key, timeout);
    if (!result) return null;
    return JSON.parse(result[1]);
  }
}

// PubSub (广播)
class RedisPubSub implements MessageBroadcast {
  async publish(channel: string, message: Message): Promise<void> {
    await this.redis.publish(channel, JSON.stringify(message));
  }
  
  subscribe(channel: string, handler: (msg: Message) => void): void {
    this.subscriber.subscribe(channel);
    this.subscriber.on('message', (ch, msg) => {
      if (ch === channel) {
        handler(JSON.parse(msg));
      }
    });
  }
}
```

### 4.2 File Queue 实现 (Level 1 降级)

```typescript
// 基于文件的消息队列
class FileQueue implements MessageQueue {
  private queueDir: string = '.kallax/queue';
  
  async send(message: Message): Promise<void> {
    const dir = path.join(this.queueDir, message.to);
    await fs.mkdir(dir, { recursive: true });
    
    const filename = `${message.timestamp.getTime()}_${message.id}.json`;
    await fs.writeFile(
      path.join(dir, filename),
      JSON.stringify(message, null, 2)
    );
  }
  
  async receive(agentId: string): Promise<Message | null> {
    const dir = path.join(this.queueDir, agentId);
    
    try {
      const files = await fs.readdir(dir);
      if (files.length === 0) return null;
      
      // 按时间排序,取最早的
      files.sort();
      const oldest = files[0];
      
      const content = await fs.readFile(path.join(dir, oldest), 'utf-8');
      await fs.unlink(path.join(dir, oldest));  // 删除已消费的消息
      
      return JSON.parse(content);
    } catch (e) {
      if (e.code === 'ENOENT') return null;
      throw e;
    }
  }
}
```

### 4.3 降级切换

```typescript
class MessageQueueFactory {
  private redisQueue: RedisListQueue;
  private fileQueue: FileQueue;
  private currentMode: 'redis' | 'file' = 'redis';
  
  async getQueue(): Promise<MessageQueue> {
    if (this.currentMode === 'redis') {
      try {
        await this.redisQueue.healthCheck();
        return this.redisQueue;
      } catch (e) {
        logger.warn({ error: e }, 'Redis unavailable, degrading to file queue');
        metrics.increment('kallax.queue.degradation', { to: 'file' });
        this.currentMode = 'file';
        return this.fileQueue;
      }
    }
    return this.fileQueue;
  }
  
  // 定期尝试恢复
  async tryRecover(): Promise<void> {
    if (this.currentMode === 'file') {
      try {
        await this.redisQueue.healthCheck();
        logger.info('Redis recovered, upgrading queue');
        this.currentMode = 'redis';
        metrics.increment('kallax.queue.recovery', { from: 'file' });
      } catch (e) {
        // 仍然不可用
      }
    }
  }
}
```

---

## 5. 错误处理

### 5.1 消息重试

```typescript
interface RetryPolicy {
  maxRetries: number;
  baseDelay: number;  // ms
  maxDelay: number;   // ms
  backoffMultiplier: number;
}

const defaultRetryPolicy: RetryPolicy = {
  maxRetries: 3,
  baseDelay: 1000,
  maxDelay: 30000,
  backoffMultiplier: 2
};

async function sendWithRetry(
  queue: MessageQueue,
  message: Message,
  policy: RetryPolicy = defaultRetryPolicy
): Promise<void> {
  let lastError: Error;
  
  for (let attempt = 0; attempt < policy.maxRetries; attempt++) {
    try {
      await queue.send(message);
      return;
    } catch (e) {
      lastError = e;
      
      const delay = Math.min(
        policy.baseDelay * Math.pow(policy.backoffMultiplier, attempt),
        policy.maxDelay
      );
      
      logger.warn({
        attempt,
        messageId: message.id,
        delay,
        error: e
      }, 'Message send failed, retrying');
      
      await sleep(delay);
    }
  }
  
  // 所有重试失败
  logger.error({
    messageId: message.id,
    error: lastError
  }, 'Message send failed after all retries');
  
  throw lastError;
}
```

### 5.2 死信队列

```typescript
// 处理失败的消息进入死信队列
class DeadLetterQueue {
  private dlqDir = '.kallax/dlq';
  
  async push(message: Message, error: Error): Promise<void> {
    const dlqMessage = {
      originalMessage: message,
      error: {
        message: error.message,
        stack: error.stack
      },
      failedAt: new Date()
    };
    
    const filename = `${Date.now()}_${message.id}.json`;
    await fs.writeFile(
      path.join(this.dlqDir, filename),
      JSON.stringify(dlqMessage, null, 2)
    );
    
    logger.error({
      messageId: message.id,
      error
    }, 'Message moved to DLQ');
  }
  
  // 手动重试 DLQ 消息
  async retry(messageId: string): Promise<void> {
    const files = await fs.readdir(this.dlqDir);
    const file = files.find(f => f.includes(messageId));
    
    if (!file) {
      throw new Error(`Message ${messageId} not found in DLQ`);
    }
    
    const content = await fs.readFile(path.join(this.dlqDir, file), 'utf-8');
    const { originalMessage } = JSON.parse(content);
    
    await this.queue.send(originalMessage);
    await fs.unlink(path.join(this.dlqDir, file));
  }
}
```

---

## 6. 安全性

### 6.1 消息签名

```typescript
import crypto from 'crypto';

interface SignedMessage extends Message {
  signature: string;
}

function signMessage(message: Message, secret: string): SignedMessage {
  const payload = JSON.stringify({
    id: message.id,
    type: message.type,
    from: message.from,
    to: message.to,
    timestamp: message.timestamp,
    payload: message.payload
  });
  
  const signature = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
  
  return { ...message, signature };
}

function verifyMessage(message: SignedMessage, secret: string): boolean {
  const { signature, ...rest } = message;
  const expected = signMessage(rest, secret).signature;
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expected)
  );
}
```

### 6.2 消息加密 (敏感内容)

```typescript
import crypto from 'crypto';

function encryptPayload(payload: unknown, key: Buffer): string {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  
  const encrypted = Buffer.concat([
    cipher.update(JSON.stringify(payload), 'utf8'),
    cipher.final()
  ]);
  
  const authTag = cipher.getAuthTag();
  
  return JSON.stringify({
    iv: iv.toString('hex'),
    data: encrypted.toString('hex'),
    authTag: authTag.toString('hex')
  });
}

function decryptPayload(encrypted: string, key: Buffer): unknown {
  const { iv, data, authTag } = JSON.parse(encrypted);
  
  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    key,
    Buffer.from(iv, 'hex')
  );
  decipher.setAuthTag(Buffer.from(authTag, 'hex'));
  
  const decrypted = Buffer.concat([
    decipher.update(Buffer.from(data, 'hex')),
    decipher.final()
  ]);
  
  return JSON.parse(decrypted.toString('utf8'));
}
```

---

## 7. 监控

### 7.1 指标

```typescript
const communicationMetrics = {
  // 消息计数
  'kallax.message.sent': Counter,
  'kallax.message.received': Counter,
  'kallax.message.failed': Counter,
  
  // 延迟
  'kallax.message.latency': Histogram,
  
  // 队列深度
  'kallax.queue.depth': Gauge,
  
  // DLQ
  'kallax.dlq.size': Gauge
};
```

### 7.2 日志格式

```typescript
// 消息发送日志
logger.info({
  event: 'message_sent',
  messageId: message.id,
  type: message.type,
  from: message.from,
  to: message.to,
  payloadSize: JSON.stringify(message.payload).length
}, 'Message sent');

// 消息接收日志
logger.info({
  event: 'message_received',
  messageId: message.id,
  type: message.type,
  from: message.from,
  latency: Date.now() - message.timestamp.getTime()
}, 'Message received');
```

---

## 参考

- [Conductor 规则](CONDUCTOR-RULES.md)
- [Performer 规则](PERFORMER-RULES.md)
- [降级策略](../../docs/architecture/DEGRADATION-STRATEGY.md)
