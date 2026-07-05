# Token Economy / Token 精简策略

> **核心原则**:每次大模型回复消耗 token = 工具输出 + 系统消息 + 中间态 + 重复路径 + 装饰
> **目标**:用最小 token 完成工作,**功能完整 > 技术完备**(出问题时简单能跑 > 复杂不能用)

---

## 🎯 4 个核心原则 / 4 Core Principles

### 1. 单次输出最大化信息密度
- ✅ `head -n 5 file | grep pattern`
- ❌ `cat file; grep pattern file`

### 2. 工具输出预过滤
- ✅ `git diff --stat` (摘要) 而非 `git diff` (全 diff)
- ✅ `jq '.field'` 而非 `cat file.json`
- ✅ `ls -la | head -n 20` 而非 `ls -laR /`

### 3. 不重复路径
- ✅ 一次 grep/rg 扫所有相关文件
- ✅ 缓存结果到 `/tmp/cache-$(date +%s).txt` 后续引用
- ❌ 多次 grep 同一字符串

### 4. 上下文主动压缩
- 50+ 次工具调用后 / 主动 `/compact`
- 关键节点(策略转变前)主动压缩
- 不让上下文膨胀到 100k

---

## 🛠️ 5 类工具的精简模式 / 5 Tool Categories

### A. 文件读取 / File Reading

| 反例 | 正例 | 减多少 |
|------|------|--------|
| `cat <5MB.log>` | `tail -n 50 <log>` | **99%** |
| `cat README.md` | `head -n 50 README.md` | 80% |
| `cat .json` | `jq '.key'` | **90%** |
| `cat package.json` | `jq '.scripts'` | 85% |
| `cat .yaml` | `yq '.spec'` | 90% |
| `cat .csv` | `column -t -s, file.csv \| head` | 70% |

### B. 文件查找 / File Search

| 反例 | 正例 | 减多少 |
|------|------|--------|
| `find /` | `fd --type f --max-depth 4 . /path` | **80%** |
| `find ... \| wc -l` | `fd ... \| wc -l`(直接给数字) | 90% |
| `find -name '*.log'` | `fd '.*\.log$'` | 70% |
| `grep -r PATTERN dir/` | `rg --files-with-matches PATTERN` | **95%** |
| `cat file \| grep PATTERN` | `rg PATTERN file` | 85% |

### C. Git 操作 / Git Operations

| 反例 | 正例 | 减多少 |
|------|------|--------|
| `git log --all` | `git log --oneline -20` | **95%** |
| `git diff` | `git diff --stat` | **99%** |
| `git status` | (只跑一次,后续引用) | 80% |
| `git show COMMIT` | `git show --stat COMMIT` | 95% |
| `git log --pretty=full` | `git log --pretty=oneline` | 90% |

### D. 系统状态 / System State

| 反例 | 正例 | 减多少 |
|------|------|--------|
| `ps aux` | `pgrep -fa PROCESS_NAME` | 90% |
| `netstat -an` | `lsof -i :PORT` | 95% |
| `df -h` | `df -h /` | 80% |
| `du -sh dir/` | `dust -d 1 dir/` | 80% |

### E. 构建/测试 / Build/Test

| 反例 | 正例 | 减多少 |
|------|------|--------|
| `cargo build` | `cargo build --message-format=json` 然后 jq | 70% |
| `npm test` | `npm test 2>&1 \| tail -n 50` | **90%** |
| `make all` | `make 2>&1 \| grep -E "(error|warning)"` | 95% |

---

## 🧠 行为模式精简 / Behavioral Economy

### 不要做的 / Anti-patterns

| 反例 | 减多少 | 原因 |
|------|--------|------|
| "让我先读这个文件..." | 5% | 直接 Read,工具自己记录 |
| "完成后让我标记..." | 3% | 完成后直接进下一步 |
| "下面是详细解释..." | 10% | 命令本身就清楚 |
| "我已经成功执行了..." | 3% | 工具结果已经说明 |
| "现在让我开始..." | 5% | 不需要状态机播报 |
| "这一步的目的是..." | 5% | 用户已经知道 |

### 推荐模式

- **批量操作**:一次 bash 调用做多件事
  ```bash
  # ❌ 5 次单独调用
  cat f1; cat f2; cat f3
  
  # ✅ 1 次调用
  for f in f1 f2 f3; do echo "=== $f ==="; head -5 "$f"; done
  ```

- **摘要优先**:
  ```bash
  # ❌ 全文
  cat file.log
  
  # ✅ 摘要
  wc -l file.log && grep -c "ERROR" file.log && tail -10 file.log
  ```

- **管道 + 限行**:
  ```bash
  # ❌ 全输出
  rg PATTERN dir/
  
  # ✅ 限行
  rg PATTERN dir/ --max-count 20
  ```

- **结构化数据用 jq**:
  ```bash
  # ❌ 原始 JSON
  curl api | head -100
  
  # ✅ 提取字段
  curl -s api | jq -r '.data[] | "\(.name): \(.value)"'
  ```

---

## 📊 Token 消耗预算 / Token Budget

按任务类型给预算:

| 任务类型 | 预算 | 节省手段 |
|----------|------|---------|
| 文件读取 | 5k tokens | `head/tail/jq` |
| 单步命令 | 1k | `wc/cut/head -5` |
| 多步聚合 | 10k | 1 个 bash 多命令 |
| git 操作 | 2k | `--stat` / `--oneline` |
| 文件编辑 | 3k | Edit 工具(只 diff) |
| 信息查询 | 1k | WebFetch 摘要 |
| **典型 30 步任务** | **50-80k tokens** | **目标 < 100k** |

---

## 🔍 自我审计清单 / Self-Audit Checklist

每完成一个 milestone,问自己:

- [ ] 我读了几个 > 100 行的文件?
- [ ] 有没有 5MB+ 的输出塞进上下文?
- [ ] 同一个 grep 跑了几次?
- [ ] git log 显示了完整 commit message 而不是 --stat?
- [ ] 我用 "我先 X" / "完成后" 这类废话占了多少 token?
- [ ] 表格 / ASCII art 占空间吗?
- [ ] 是否可以 1 个 bash 调用做多件事?
- [ ] 主动 /compact 时机到了吗?

---

## 🛠️ 工具与脚本 / Tools and Scripts

### 推荐工具

| 工具 | 替代 | 减多少 |
|------|------|--------|
| `fd` | `find` | **15x** (速度 + 输出) |
| `rg` | `grep -r` | **5-20x** (速度 + 跳过 .git) |
| `jq` | 文本 grep | **90%** (JSON 路径) |
| `yq` | 文本 grep | **90%** (YAML) |
| `bat` | `cat` | 视觉 |
| `eza` | `ls -la` | 视觉 + 简洁 |

### alias 推荐(放 ~/.zshrc / ~/.bashrc)

```bash
# 限制大量输出
alias cat='bat --plain --paging never'  # 语法高亮但避免 pager
alias ls='eza -la --git'                  # 简洁列表
alias grep='rg'                          # 跳过 .git
alias find='fd'                          # 更快更少输出

# 减少"我看看"
alias ll='ls -la | head -n 30'           # 默认限行
alias du='dust -d 1'                     # 目录树视图
alias ps='procs'                         # 进程树
```

### 自定义 wrapper

```bash
# 智能 cat(自动判断文件大小)
scat() {
  local f="$1"
  local size=$(stat -f %z "$f" 2>/dev/null || stat -c %s "$f" 2>/dev/null)
  if [[ $size -gt 100000 ]]; then
    echo "📄 文件 $1 ($size bytes) 太大,自动摘要:"
    wc -l "$f"
    head -n 20 "$f"
    echo "... (省略 $(($(wc -l < "$f") - 20)) 行 ..."
    tail -n 10 "$f"
  else
    cat "$f"
  fi
}
```

---

## 📐 大输出场景专项 / High-volume Scenarios

### 场景 1:日志分析
```bash
# ❌ cat /var/log/app.log (10MB)
# ✅ 分层
wc -l /var/log/app.log
grep -c "ERROR" /var/log/app.log
grep "ERROR" /var/log/app.log | tail -20  # 最近 20 条错误
```

### 场景 2:代码搜索
```bash
# ❌ grep -r "TODO" src/ (10000 行输出)
# ✅ 摘要
rg "TODO" src/ -c                    # 每个文件 TODO 数
rg "TODO" src/ -l                    # 哪些文件含 TODO
rg "TODO" src/ --max-count 20 -A 3   # 20 个 TODO + 3 行上下文
```

### 场景 3:大型 JSON API
```bash
# ❌ curl api | head -100
# ✅ 精确字段
curl -s api | jq '.data[] | {id, name, status}'
```

### 场景 4:Git 历史
```bash
# ❌ git log --all (1000 commits × 80 字符)
# ✅ 摘要
git log --oneline -20          # 最近 20 commit hash + subject
git log --stat --oneline -10    # 10 commit + 改动文件
```

### 场景 5:大文件 diff
```bash
# ❌ git diff (10000 行)
# ✅ 摘要
git diff --stat                  # 文件级摘要
git diff --stat -p | head -50    # 文件 + 前 50 行
```

---

## 🎬 实战检查 / Practical Checklist

**每次工具调用前问**:
1. 这个命令会输出多少行?
2. 输出能压成数字吗?(`wc -l` / `--stat` / `-c`)
3. 是否可以限行 + 限文件?(`head/tail/max-depth`)
4. 输出格式能结构化吗?(JSON → jq,YAML → yq)
5. 一次性做多件事吗?(loop / `&&`)

**调用后问**:
1. 输出 > 50 行了吗?
2. 有重复吗?(同一目录 grep 多次)
3. 用户能从 5 行看到结论吗?

**每 30 次调用后**:
1. /compact 主动压缩
2. 重新读 README/CLAUDE.md(避免方向漂移)
3. 检查剩余 token 估算

---

## ⚖️ 一句话原则 / One-liner

> **1 个命令做多件事,1 行输出做多行工作,1 个工具调用前问"能压成数字吗"。**

---

**Maintained by**:kallax framework
**Last updated**:2026-07-05
**Source**:反思自 anti-violent-layoff-evidence v1.0 → v1.2.9 开发过程