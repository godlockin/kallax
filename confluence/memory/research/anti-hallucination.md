# Agent 防幻觉机制

> KALLAX 核心模式 | 解决 Agent 虚假报告问题

---

## 问题背景

历史项目中 background agents 经常出现"幻觉"现象：
- 报告任务"完成"但实际无任何产出
- 描述详细的修改内容但文件未变化
- 声称测试通过但从未运行

**原因分析**:
1. Background 模式在 isolated context 中无文件写权限
2. Agent 基于预测而非实际执行结果回复
3. 缺乏产出验证机制

---

## KALLAX 解决方案

### 1. 强制 Foreground 模式

代码实现任务必须使用 foreground 模式：

```bash
# ✅ 正确: 代码任务用 foreground
kallax task:claim TASK-001 --mode foreground

# ❌ 错误: 代码任务用 background
kallax task:claim TASK-001 --mode background
# Error: Code tasks require foreground mode
```

**模式选择规则**:
| 任务类型 | 模式 | 原因 |
|---------|------|------|
| 代码实现 | foreground | 需要文件写权限 |
| 代码审查 | foreground | 需要验证修改 |
| 需求分析 | background | 仅读取 |
| 文档阅读 | background | 仅读取 |

### 2. 5-Level Fact-Forcing 验证

Conductor 必须执行 4 级验证后才能 Approve：

```
Level 1: 存在性验证
  ✓ 文件存在于 git diff
  ✓ 无幽灵引用（引用不存在的文件/函数）

Level 2: 实质性验证
  ✓ 真实逻辑，非 stub
  ✓ 无 TODO 占位符在关键路径

Level 3: 接线验证
  ✓ import/export 正确
  ✓ 类型兼容

Level 4: 数据流验证
  ✓ 集成测试通过
  ✓ E2E 覆盖关键路径
```

### 3. 产出验证命令

```bash
kallax verify:output TASK-001

# 内部执行:
# Step 1: ls -la - 检查文件存在
# Step 2: git show --stat - 检查实际修改
# Step 3: npm test - 运行真实测试
# Step 4: npm run build - 构建验证
```

---

## 配置

```yaml
# .kallax/config.yml
verification:
  # Conductor 必须验证
  conductor_verify_output: true
  
  # 验证步骤
  verification_steps:
    - command: "ls -la"
      description: "检查文件存在"
    - command: "git show --stat"
      description: "检查实际修改"
    - command: "npm test"
      description: "运行真实测试"
    - command: "npm run build"
      description: "构建验证"
  
  # 5-Level Fact-Forcing
  fact_forcing:
    level_1_existence: true
    level_2_substance: true
    level_3_wiring: true
    level_4_dataflow: true
```

---

## 证据要求

### 接受的证据

```markdown
## PR Review 证据示例

### Level 1: 存在性
✓ 文件 src/components/Login.tsx 存在于 diff
✓ 行号 42-86 包含新增的 LoginForm 组件

### Level 2: 实质性
✓ 完整的表单验证逻辑（非 TODO）
✓ 错误处理覆盖网络异常和认证失败

### Level 3: 接线
✓ 正确导入 useAuth hook (line 3)
✓ 导出 LoginForm 组件 (line 86)

### Level 4: 数据流
✓ 测试输出:
  ```
  PASS src/components/Login.test.tsx
    ✓ renders email input (12ms)
    ✓ validates email format (8ms)
    ✓ handles login success (45ms)
    ✓ handles login failure (23ms)
  Tests: 4 passed, 4 total
  ```
```

### 拒绝的证据

```markdown
❌ "应该没问题"
❌ "测试通过了"（无 stdout）
❌ "我已经验证过"（无具体说明）
❌ "这是标准实现"（无代码引用）
```

---

## 代码实现

### output-verifier.ts

```typescript
import { execFileSync } from 'child_process';
import { Result, ok, err } from 'neverthrow';

interface VerificationStep {
  command: string;
  args: string[];
  description: string;
}

interface VerificationResult {
  step: string;
  success: boolean;
  output: string;
}

export class OutputVerifier {
  private readonly steps: VerificationStep[] = [
    { command: 'ls', args: ['-la'], description: '检查文件存在' },
    { command: 'git', args: ['show', '--stat'], description: '检查实际修改' },
    { command: 'npm', args: ['test'], description: '运行真实测试' },
    { command: 'npm', args: ['run', 'build'], description: '构建验证' },
  ];

  /**
   * 执行完整验证
   */
  verify(workdir: string): Result<VerificationResult[], Error> {
    const results: VerificationResult[] = [];

    for (const step of this.steps) {
      try {
        const output = execFileSync(step.command, step.args, {
          cwd: workdir,
          encoding: 'utf-8',
        });

        results.push({
          step: step.description,
          success: true,
          output,
        });
      } catch (e: unknown) {
        const error = e as { stderr?: string; message: string };
        results.push({
          step: step.description,
          success: false,
          output: error.stderr ?? error.message,
        });
      }
    }

    const failed = results.filter(r => !r.success);
    if (failed.length > 0) {
      return err(new Error(`Verification failed: ${failed.map(f => f.step).join(', ')}`));
    }

    return ok(results);
  }

  /**
   * 生成验证报告
   */
  generateReport(results: VerificationResult[]): string {
    return results.map(r => {
      const status = r.success ? '✓' : '✗';
      return `${status} ${r.step}\n${r.output}`;
    }).join('\n\n');
  }
}
```

---

## 最佳实践

### Conductor

1. **不要相信自述**: Agent 说完成不代表真的完成
2. **运行验证命令**: 每次 Review 前执行 `kallax verify:output`
3. **要求证据**: PR 描述必须包含真实的命令输出
4. **检查 diff**: 实际查看代码变更，不只看描述

### Performer

1. **使用正确模式**: 代码任务必须 foreground
2. **提供证据**: PR 描述包含测试输出截图
3. **不要猜测**: 不确定就重新运行验证
4. **保持诚实**: 遇到问题如实报告，不要编造结果

---

## 检测信号

以下信号可能表明 Agent 幻觉：

| 信号 | 说明 |
|------|------|
| 完美的任务描述但无 diff | 可能未实际执行 |
| 测试"通过"但无输出 | 可能未运行 |
| 引用不存在的文件 | 幻觉生成的路径 |
| 代码风格与项目不符 | 可能是通用模板 |
| 缺少项目特定细节 | 可能未读取实际代码 |

---

## 参考

- [架构经验教训](./architecture-lessons-learned.md)
- `../../template/docs/GATE-REVIEW-PROTOCOL.md`
