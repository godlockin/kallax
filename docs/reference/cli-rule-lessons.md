# CLI Rule 教训 / Lessons Learned (kallax framework)

> **来源**:`anti-violent-layoff-evidence/lessons-learned.md` v1.2.8(30 条)中
> 与"日志/CLI 规则/工具对比/Hook 设计/Debug"相关的教训。
> **目的**:kallax 框架内其他项目复用,避免重复踩坑。

---

## 🛠️ 脚本/工程级

### 1. macOS bash 3.2 不支持 `declare -A`
- macOS 自带 bash 3.2.57,**不支持关联数组**
- 解法:临时文件模拟 / 变量名替代
```bash
# ❌ declare -A foo=([key1]=val1)  # bash 3.2 报错
# ✅ foo_file=$(mktemp); echo "key1=val1" > "$foo_file"
# ✅ foo_k1="val1"; foo_k2="val2"  # 变量名带 key
```

### 2. `bash -c "$CMD_STR"` 比 `( "$@" )` 可靠
- `for arg in "$@"; do ... done` 在子 shell 里 `"$@"` 被合并成单 token
- 解法:`bash -c "echo hello world"`
- 转义:含空格/特殊字符用单引号,内部 `'` 用 `'\''` 转义

### 3. git log `--pretty=format:'%ae\\n%ce'` 不换行
- `%ae` 后面的 `\n` 在 `format` 模式下被当字面字符串
- **改用 `tformat:'%ae%n%ce'`** 让 `\n` 生效
- `tformat` = "terminal format",自动应用换行

### 4. hash 自洽问题(self-consistency)
- "EXPECTED 值 = sha256(文件内容包含该 EXPECTED 行)" 是 fixed-point problem
- 解法 1:迭代收敛(慢,易死循环)
- **解法 2(推荐)**:用 magic marker 替代 hash self-consistency
```bash
# 用 grep 检查 marker,简单可靠
EXEC_TASK_INTEGRITY_v1="abc123..."
if ! grep -qF "EXEC_TASK_INTEGRITY_v1" "$0"; then
  echo "⚠️ 完整性标记缺失!"
fi
```

### 5. Heredoc 末尾 EOF 必须独立成行
- `cat > file <<'EOF'` 后,`EOF` 必须在行首(前面只能空格/tab)
- `COMPANY_DOMAIN=""` 后紧跟 `EOF` 没空行 → bash 报 "unexpected EOF"
- **习惯**:heredoc 结束后加一个空行 → `EOF\n`

### 6. bash 3.2 `set -u` + 数组未初始化会报错
- `set -uo pipefail` 加 `declare -A foo=()` 后,`${foo[key]:-}` 在 bash 3.2 仍可能 unbound
- 解法:`set +u` 在关联数组周围,或直接不用 `set -u`

---

## 🔧 工具对比 / Tool Comparison

### 7. 跨段大替换:Perl 表现不好,Python 是更好选择
- `perl -i -0pe 's|...|...|m'` 转义陷阱多,大段替换易破坏 heredoc
- **Python 是更好选择**:`str.replace` 无转义问题
```python
# ✅ Python
with open('README.md', 'r') as f:
    content = f.read()
content = content.replace('old text', 'new text')
with open('README.md', 'w') as f:
    f.write(content)

# ❌ Perl
perl -i -0pe 's|some|with pipe in $ENV{HOME}|g' file
```

**最佳工具栈**:
- 单行替换 → `sed -i`
- 跨段替换 → **Python**
- Edit 工具上下文 → Claude Code `Edit`
- 复杂正则 → `perl -i`(小心!)
- git 历史改写 → `git filter-repo`(唯一靠谱)

### 8. macOS sed vs GNU sed
- macOS `sed -i ''`(空字符串强制参数)
- GNU `sed -i`(直接编辑)
- **跨平台写法**:
```bash
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s/$pat/$repl/g" "$file"
else
  sed -i "s/$pat/$repl/g" "$file"
fi
```

### 9. zsh 解析 heredoc 的坑
- `(eval):38: parse error near \n`(zsh 不喜欢某些 here-doc)
- macOS 默认 `bash` 但 Claude Code 用 `zsh`?
- 解法:简化 heredoc 内容,避免特殊字符;或显式用 `bash script.sh`

---

## 🪝 Hook 设计 / Hook Design

### 10. 大模型也会被自己的 hook 拦截
- commit message 写了 `tail -f`(作为示例)→ **hook 拦截了 commit**
- 这是好事:证明 hook 真的在工作,大模型无法绕过
- **教训**:写 commit message / doc 时也要避免触发自己规则的字面字符串

### 11. Hook 检测的"精准 vs 宽松"
- 太严:误报,大模型频繁被拦截 → 工作流卡顿
- 太宽:漏判,违规命令通过
- **平衡**:
  - 高置信度违规(`tail -f` / `cat /var/log`)→ exit 2 拒绝
  - 中等违规(`tail -n N` / `find` 无 head)→ exit 0 但 stderr 警告
  - 不在 hook 检查命令本身的语法(`cat .conf` 合规)

### 12. Hook 必须独立测试
- 用 stdin 喂 JSON payload,验证 exit code
- `verify-rule.sh` 包含 12 个 case,自动测 hook 工作

---

## 🔒 隐私保护深度

### 13. 脱敏只是第一步,历史脱敏才彻底
- 文件脱敏:简单,新 commit 立刻生效
- 历史脱敏:必须 `git filter-repo` + force push
- 认知:GitHub 默认缓存旧 commit reflog,即使删除 branch 也可能查到
- **未来**:大项目考虑 `BFG Repo-Cleaner` 或新建仓库

### 14. 本机数据隔离要早做
- `.gitignore` 从 v1.0 就该配好
- 后期清理比一开始就保护难 100 倍
- 我后期发现 `tests/output/` 里真数据未 gitignore → 改 `.gitignore` + 跑 `git rm --cached`

---

## 📊 性能数据

### 15. Rust 工具加速实测
| 工具 | 替代 | 加速 |
|------|------|------|
| fd | find | **15.5x** (~/.4 层 *.png: 1.24s → 0.08s) |
| rg | grep | 5-20x |
| eza | ls | 视觉 |
| bat | cat | 语法高亮 |
| delta | diff | 更好看 |
| dust | du | 可视化 |
| procs | ps | 视觉 |
| sd | sed | DX |
| xh | curl | DX |

### 16. shell 命令性能 = O(file_count)
- 13K 个文件扫 ~/Documents ~3min(find) → 8s(fd + 排除 .git)
- 30K git commit 扫 ~/Library ~6min → 4s(fd)
- **优化策略**:深度限制、排除 .git/.Trash、并行

---

## 🧪 集成测试教训

### 17. 用户的实际环境 ≠ 开发环境
- 我开发时 bash 5.x,macOS bash 3.2 报错
- 我设 `set -u`,用户可能不用
- **必须**:在 README 标注最低 bash 版本,提供降级路径

### 18. 用户的文件 ≠ 你的假设
- 我假设 git config user.email = 个人邮箱
- 用户(IKEA 案例)的 git config 全局是个人邮箱,但**公司项目用公司邮箱**
- 必须扫 git log 历史 author/committer email,不只看 git config

### 19. 用户不知道他们需要什么
- 我以为 git 证据 = 维权核心 → 用户说"不是,我的代码不在 git 里"
- 自动检测到 git 占比 0.1% → 建议改用 general 证据
- **设计原则**:工具应该**智能诊断用户场景**并给建议

---

## 🐛 Debug 教训

### 20. `set -x` 是最简单的 debug
```bash
bash -x script.sh    # 打印每条命令
```
- 90% 的 bash 问题 5 分钟内定位

### 21. bash 报错"line N: syntax error" 先看 N 行附近
- 不是真的 N 行错,可能是 N 之前少了 `}` / `fi` / `EOF`
- **习惯**:报错后用 `awk 'NR>=N-5 && NR<=N+5'` 看上下文

### 22. `bash -n` 只检查语法,不检查逻辑
- 语法 OK 不代表运行 OK
- 必须 `bash -n && bash script.sh` 实际跑一下

---

## 🎬 团队协作

### 23. commit message 写"为什么"比"做了什么"重要
- ❌ "fix bug"
- ✅ "fix macOS bash 3.2 declare -A compatibility (issue from user feedback)"

### 24. 每完成一个 milestone 就 commit
- 不要攒一波 commit
- 出问题能精准 revert

---

## 📋 总览 / Summary

### 工具栈优先级(新项目首选)

```
1. bash (主) + set -uo pipefail + bash 3.2 兼容
2. Python (跨段替换 + JSON + heredoc 安全的操作)
3. rust 工具(可选加速,自动 fallback)
4. git-filter-repo (历史脱敏)
5. Claude Code Hook (系统级拦截)
```

### 设计原则(跨项目复用)

1. **用户的实际场景 ≠ 工具能力假设** — 从用户 case 出发,不要从工具出发
2. **大模型上下文窗口宝贵** — 不浪费在实时日志流
3. **失败用 exit code 表示** — 不需要监控
4. **修改不留死角** — 4 层防护叠加,任何单点失败都能被捕获
5. **文档 = 规则 + 教训** — 不仅说"做什么",更说"为什么"和"踩过什么坑"

---

**Maintained by**:kallax framework
**Source**:anti-violent-layoff-evidence v1.2.8 lessons-learned.md (24 条相关)
**Last updated**:2026-07-05
**License**:MIT