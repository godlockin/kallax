#!/usr/bin/env bash
# next-epic-id.test.sh — EPIC-259 编号注册器守卫 test
#
# 设计原则 (吸取第 1 版教训): **行为断言, 不 grep 源码**.
#
# 第 1 版有 2 个 case 是 grep 被测脚本自己的源码 (查有没有 --show-toplevel 字样、
# 有没有 0-result 防御), 独立核实者做了 5 个变异体 — 删掉功能只留一行注释 —
# 全部存活, 每次都 18 passed. 那种 case 防御价值为 0.
#
# 本版改成: 在临时 git repo 里构造场景, 断言脚本的实际行为 (输出 + 退出码).
# 每个 case 都能杀掉对应的功能删除.
#
# 不加 set -e — 本 test 大量检查非 0 退出码 (本会话同类坑第 6 次)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
TARGET="$REPO_ROOT/scripts/next-epic-id.sh"

PASS=0
FAIL=0
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/e259-test.XXXXXX")"
trap 'rm -rf "$TMPROOT"' EXIT

ok()  { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
bad() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

assert_exit() {
  local desc="$1" expected="$2"; shift 2
  local actual
  "$@" >/dev/null 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    ok "$desc (exit $actual)"
  else
    bad "$desc — 期望 exit $expected, 实际 $actual"
  fi
}

assert_stdout_has() {
  local desc="$1" pattern="$2"; shift 2
  local out
  out="$("$@" 2>/dev/null)"
  if printf '%s' "$out" | grep -qE "$pattern"; then
    ok "$desc"
  else
    bad "$desc — stdout 不含 '$pattern', 实际: $(printf '%s' "$out" | head -1)"
  fi
}

assert_stdout_lacks() {
  local desc="$1" pattern="$2"; shift 2
  local out
  out="$("$@" 2>/dev/null)"
  if printf '%s' "$out" | grep -qE "$pattern"; then
    bad "$desc — stdout 不该含 '$pattern', 实际: $(printf '%s' "$out" | head -1)"
  else
    ok "$desc"
  fi
}

# 造一个自带 origin 的临时 repo, 内容由参数控制
# $1 = repo 名
# 之后调用者往 $TMPROOT/$1/ 里放 ticket 目录 / decisions 文件 / 建 branch
make_repo() {
  local name="$1"
  local up="$TMPROOT/${name}-upstream"
  local wt="$TMPROOT/$name"
  mkdir -p "$up"
  git init -q --bare "$up"
  git init -q "$wt"
  git -C "$wt" config user.email t@t.local
  git -C "$wt" config user.name t
  git -C "$wt" config commit.gpgsign false
  mkdir -p "$wt/scripts" "$wt/jira/tickets" "$wt/confluence/decisions"
  cp "$TARGET" "$wt/scripts/next-epic-id.sh"
  chmod +x "$wt/scripts/next-epic-id.sh"
  echo "$wt"
}

commit_and_push() {
  local wt="$1" branch="${2:-miao}"
  git -C "$wt" add -A >/dev/null 2>&1
  git -C "$wt" commit -q -m "setup" >/dev/null 2>&1
  git -C "$wt" branch -M "$branch" >/dev/null 2>&1
  git -C "$wt" remote add origin "$TMPROOT/$(basename "$wt")-upstream" >/dev/null 2>&1
  git -C "$wt" push -q -u origin "$branch" >/dev/null 2>&1
}

run_in() {
  local wt="$1"; shift
  ( cd "$wt" && KALLAX_NUMBERING_REF="origin/miao" bash scripts/next-epic-id.sh "$@" )
}

echo "=== EPIC-259 next-epic-id.sh Tests (行为断言版) ==="

# ---------------------------------------------------------------
echo "--- 组 A: 基本可用性 ---"
if [ -x "$TARGET" ]; then ok "脚本可执行"; else bad "不可执行: $TARGET"; fi
assert_exit "bash -n 语法" 0 bash -n "$TARGET"
assert_exit "--help exit 0" 0 bash "$TARGET" --help
assert_stdout_has "无参输出 EPIC-NNN" '^EPIC-[0-9]{3}$' bash "$TARGET"

# ---------------------------------------------------------------
echo "--- 组 B: 4 个编号来源, 每个单独隔离验 ---"
# 关键: 每个 case 只在**一个**来源里放编号, 其余来源为空.
# 若脚本漏查该来源, 这个 case 必红. 这能杀掉"删掉某个来源"的变异体.

# B1: 只有远端 ticket 目录有编号
WT_B1="$(make_repo b1)"
mkdir -p "$WT_B1/jira/tickets/EPIC-500"
echo '{}' > "$WT_B1/jira/tickets/EPIC-500/ticket.json"
# decisions 也放一个不同编号, 保证远端来源非空判断能过
echo "x" > "$WT_B1/confluence/decisions/EPIC-501-foo.md"
commit_and_push "$WT_B1"
# 删掉本地目录 + 不建 branch, 让编号只能来自远端
rm -rf "$WT_B1/jira/tickets/EPIC-500"
assert_exit "B1 远端 ticket 来源: --check 500 报占用" 1 run_in "$WT_B1" --check 500
assert_stdout_has "B1 指出来源是远端 ticket" '远端 ticket' run_in "$WT_B1" --check 500

# B2: 只有远端 decisions 有编号 (这是第 1 版漏掉的来源)
assert_exit "B2 远端 decisions 来源: --check 501 报占用" 1 run_in "$WT_B1" --check 501
assert_stdout_has "B2 指出来源是远端 decision" '远端 decision' run_in "$WT_B1" --check 501

# B3: 只有本地未提交目录有编号
WT_B3="$(make_repo b3)"
mkdir -p "$WT_B3/jira/tickets/EPIC-600"
echo '{}' > "$WT_B3/jira/tickets/EPIC-600/ticket.json"
echo "x" > "$WT_B3/confluence/decisions/EPIC-601-foo.md"
commit_and_push "$WT_B3"
# 新建一个只在本地的目录 (未提交)
mkdir -p "$WT_B3/jira/tickets/EPIC-650"
echo '{}' > "$WT_B3/jira/tickets/EPIC-650/ticket.json"
assert_exit "B3 本地未提交目录: --check 650 报占用" 1 run_in "$WT_B3" --check 650
assert_stdout_has "B3 指出来源是本地 ticket" '本地 ticket' run_in "$WT_B3" --check 650

# B4: 只有 branch 名有编号
git -C "$WT_B3" branch feature/EPIC-700-something >/dev/null 2>&1
assert_exit "B4 branch 名来源: --check 700 报占用" 1 run_in "$WT_B3" --check 700
assert_stdout_has "B4 指出来源是 branch" 'branch:' run_in "$WT_B3" --check 700

# ---------------------------------------------------------------
echo "--- 组 C: 编号归一化 (前导 0 / 低编号 / 八进制) ---"
# 第 1 版这里全错: --check 15 报 FREE (远端有 EPIC-015), --check 015 打印 EPIC-013
WT_C="$(make_repo c1)"
mkdir -p "$WT_C/jira/tickets/EPIC-015-D"
echo '{}' > "$WT_C/jira/tickets/EPIC-015-D/ticket.json"
echo "x" > "$WT_C/confluence/decisions/EPIC-021-foo.md"
commit_and_push "$WT_C"
assert_exit "C1 --check 15 (裸数字对零填充编号)" 1 run_in "$WT_C" --check 15
assert_exit "C2 --check 015 (前导 0)" 1 run_in "$WT_C" --check 015
assert_stdout_has "C3 --check 015 打印 EPIC-015 而非八进制 EPIC-013" 'EPIC-015' run_in "$WT_C" --check 015
assert_stdout_lacks "C4 --check 015 不打印 EPIC-013" 'EPIC-013' run_in "$WT_C" --check 015
assert_exit "C5 --check 21 (2 位输入)" 1 run_in "$WT_C" --check 21

# ---------------------------------------------------------------
echo "--- 组 D: 日期串不能被当成编号 ---"
# 放宽 regex 到 {3,} 时, retrospective-batch-8-EPIC-2026-08-12.md 被解析成 EPIC-2026
WT_D="$(make_repo d1)"
mkdir -p "$WT_D/jira/tickets/EPIC-300"
echo '{}' > "$WT_D/jira/tickets/EPIC-300/ticket.json"
echo "x" > "$WT_D/confluence/decisions/retrospective-EPIC-2026-08-12.md"
echo "x" > "$WT_D/confluence/decisions/EPIC-301-foo.md"
commit_and_push "$WT_D"
assert_stdout_has "D1 next 给 EPIC-302 而非 EPIC-2027" '^EPIC-302$' run_in "$WT_D"
assert_stdout_lacks "D2 next 不受日期串影响" '2027' run_in "$WT_D"

# ---------------------------------------------------------------
echo "--- 组 E: 小写 epic- 文件名也要认 ---"
# 实仓有 epic-188-retrospective-2026-08-07.md (小写)
WT_E="$(make_repo e1)"
mkdir -p "$WT_E/jira/tickets/EPIC-400"
echo '{}' > "$WT_E/jira/tickets/EPIC-400/ticket.json"
echo "x" > "$WT_E/confluence/decisions/epic-450-lowercase.md"
commit_and_push "$WT_E"
assert_exit "E1 小写 epic-450 被认出占用" 1 run_in "$WT_E" --check 450
assert_stdout_has "E2 小写归属输出 (归属 grep 大小写敏感 bug 防护)" '远端 decision' run_in "$WT_E" --check 450

# ---------------------------------------------------------------
# E3: ghost 占位测试 — 4 位编号不能被截成 3 位
# 二轮核实者发现: regex 无右边界, EPIC-1234 目录会被截成 EPIC-123
# 真仓被掩盖是因为 EPIC-202 恰好真存在 (retrospective-EPIC-2026-08-12.md)
WT_E3="$(make_repo e3)"
mkdir -p "$WT_E3/jira/tickets/EPIC-300"
echo '{}' > "$WT_E3/jira/tickets/EPIC-300/ticket.json"
echo "x" > "$WT_E3/confluence/decisions/EPIC-1234-fake.md"
commit_and_push "$WT_E3"
assert_exit "E3 4 位编号不占 3 位 (期望 123 free, 不被 1234 截断)" 0 run_in "$WT_E3" --check 123
# E4: 4 位编号根本不在 3 位约定范围, --check 1234 应当 exit 2 (用法错)
# 跟 --check abc / --check 'bigger than 6 digits' / --check -5 同一档
assert_exit "E4 4 位编号 --check 1234 报用法错 (exit 2)" 2 run_in "$WT_E3" --check 1234

# ---------------------------------------------------------------
echo "--- 组 F: 远端来源为 0 必须 exit 3, 不许退化 ---"
# 第 1 版只在三处全空时才 exit 3; ref 存在但无 jira/tickets 时静默用本地+branch
WT_F="$(make_repo f1)"
# 远端只有一个空 README, 0 个 EPIC 编号
echo "readme" > "$WT_F/README.md"
commit_and_push "$WT_F"
# 本地放编号 + 建 branch — 若脚本退化, 会用这些给出建议
mkdir -p "$WT_F/jira/tickets/EPIC-800"
echo '{}' > "$WT_F/jira/tickets/EPIC-800/ticket.json"
git -C "$WT_F" branch feature/EPIC-810-x >/dev/null 2>&1
assert_exit "F1 远端 0 来源 → exit 3 (不退化用本地)" 3 run_in "$WT_F"
assert_stdout_lacks "F2 不输出任何编号建议" 'EPIC-[0-9]{3}' run_in "$WT_F"
assert_exit "F3 --check 也 exit 3" 3 run_in "$WT_F" --check 810

# ---------------------------------------------------------------
echo "--- 组 G: ref 不存在 → exit 3 ---"
assert_exit "G1 坏 ref exit 3" 3 \
  env KALLAX_NUMBERING_REF=origin/nonexistent-xyz bash "$TARGET"

# ---------------------------------------------------------------
echo "--- 组 H: 用法错误一律 exit 2 (区分于'已占用'的 1) ---"
assert_exit "H1 --check abc" 2 bash "$TARGET" --check abc
assert_exit "H2 --check 无值" 2 bash "$TARGET" --check
assert_exit "H3 未知参数" 2 bash "$TARGET" --bogus
assert_exit "H4 --check 多余参数" 2 bash "$TARGET" --check 259 extra
assert_exit "H5 --check 超长编号" 2 bash "$TARGET" --check 99999999999999999999
assert_exit "H6 --list-tail 带参数" 2 bash "$TARGET" --list-tail bogus

# ---------------------------------------------------------------
echo "--- 组 I: 陈旧 ref 可见性 ---"
# 不 fetch 时必须在 stderr 提示读的是缓存 + ref 时间, 否则"本地落后"这件事不可见
# I1/I2 仅做"提示存在"的不退化断言 (用真仓, 真仓不上锁不破坏东西)
# I3 在 sandbox 里造 stale ref, 断言 --fetch 后编号真变 — 这才是避免 N5 变异体
# (--fetch 静默 no-op 而 test 仍绿) 的关键防护
STDERR_OUT="$(bash "$TARGET" 2>&1 >/dev/null)"
if printf '%s' "$STDERR_OUT" | grep -q '未 fetch'; then
  ok "I1 不 fetch 时 stderr 提示读缓存"
else
  bad "I1 缺'未 fetch'提示 — 本地落后不可见"
fi
if printf '%s' "$STDERR_OUT" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
  ok "I2 提示里带 ref 提交日期"
else
  bad "I2 提示缺 ref 日期 — 无法判断多旧"
fi

# I3-I5: 在 sandbox 里造 stale ref, 验证 --fetch 真的推进 ref
# (这是 N5 变异体的反制: 若 --fetch 变成 no-op, 验证码不变 → 红)
# I3-I4: 在 sandbox 里造 stale ref, 验证 --fetch 真的推进 ref
# (这是 N5 变异体的反制: 若 --fetch 变成 no-op, 验证码不变 → 红)
#
# 关键: bare upstream 必须显式设 HEAD 指向 miao, 否则 clone 后 checkout 失败.
# 用 make_repo 风格的 wt-write + wt-read, 两个 worktree 共享一个 upstream.
WT_I_UP="$TMPROOT/i4-upstream"
WT_I_WRITE="${WT_I_UP}-write"
WT_I_READ="${WT_I_UP}-read"
rm -rf "$WT_I_UP" "$WT_I_WRITE" "$WT_I_READ"
mkdir -p "$WT_I_UP"
git init -q --bare "$WT_I_UP"
git -C "$WT_I_UP" symbolic-ref HEAD refs/heads/miao

# write 端: 造基础 + 名额 250 + 拷脚本
git clone -q "$WT_I_UP" "$WT_I_WRITE"
git -C "$WT_I_WRITE" config user.email w@t.local
git -C "$WT_I_WRITE" config user.name w
git -C "$WT_I_WRITE" config commit.gpgsign false
mkdir -p "$WT_I_WRITE/jira/tickets/EPIC-250" "$WT_I_WRITE/scripts" "$WT_I_WRITE/confluence/decisions"
echo '{}' > "$WT_I_WRITE/jira/tickets/EPIC-250/ticket.json"
echo "x" > "$WT_I_WRITE/confluence/decisions/EPIC-251-foo.md"
cp "$TARGET" "$WT_I_WRITE/scripts/next-epic-id.sh"
chmod +x "$WT_I_WRITE/scripts/next-epic-id.sh"
git -C "$WT_I_WRITE" add -A
git -C "$WT_I_WRITE" commit -q -m "seed"
git -C "$WT_I_WRITE" push -u origin miao 2>&1 | tail -3
# 上面 push 失败常见原因是 HEAD 没 push 上 (push default refspec),
# 显式再 push HEAD 兜底
git -C "$WT_I_WRITE" push origin HEAD:refs/heads/miao 2>&1 | tail -3

# read 端: 拉下来, 拷脚本
git clone -q "$WT_I_UP" "$WT_I_READ"
git -C "$WT_I_READ" config user.email r@t.local
git -C "$WT_I_READ" config user.name r
git -C "$WT_I_READ" config commit.gpgsign false
mkdir -p "$WT_I_READ/scripts"
cp "$TARGET" "$WT_I_READ/scripts/next-epic-id.sh"
chmod +x "$WT_I_READ/scripts/next-epic-id.sh"

# read 端拿数字: 应该 EPIC-252 (250/251 + 1)
NEXT_BEFORE="$(cd "$WT_I_READ" && KALLAX_NUMBERING_REF=origin/miao bash scripts/next-epic-id.sh 2>&1)"
assert_exit "I3 --fetch 模式可用" 0 bash "$TARGET" --fetch

# write 端加新 ticket 300, push
mkdir -p "$WT_I_WRITE/jira/tickets/EPIC-300"
echo '{}' > "$WT_I_WRITE/jira/tickets/EPIC-300/ticket.json"
git -C "$WT_I_WRITE" add -A
git -C "$WT_I_WRITE" commit -q -m "add 300"
git -C "$WT_I_WRITE" push origin HEAD:refs/heads/miao 2>&1 | tail -3

# read 端 fetch 跑: 应该 EPIC-301 (基于 300 + 1)
NEXT_AFTER_FETCH="$(cd "$WT_I_READ" && KALLAX_NUMBERING_REF=origin/miao bash scripts/next-epic-id.sh --fetch 2>&1)"

if [ "$NEXT_BEFORE" != "$NEXT_AFTER_FETCH" ]; then
  ok "I4 --fetch 真推进 ref (前后编号不同: $NEXT_BEFORE → $NEXT_AFTER_FETCH)"
else
  bad "I4 --fetch 没推进 ref (前后相同: $NEXT_BEFORE) — 是 N5 变异体 (--fetch 静默 no-op)"
fi

# ---------------------------------------------------------------
echo "--- 组 J: repo root 解析 ---"
# 第 1 版这里是 grep 源码查有没有 --show-toplevel 字样, 核实者用"改代码留注释"
# 的变异体轻易骗过. 改成行为断言.
#
# 注意一个实测结论: 在 <repo>/scripts/ 这个布局下, $SCRIPT_DIR/.. 跟
# rev-parse --show-toplevel 结果**相同**, 所以单纯把实现换成 $SCRIPT_DIR/..
# 不产生行为差异 (等价变异体, 杀不掉是正常的).
# 真正的差异出现在脚本从别处被调用时 — 下面 J2 造这个场景.

WT_LOCAL_MARKER="EPIC-259"
if [ -d "$REPO_ROOT/jira/tickets/$WT_LOCAL_MARKER" ]; then
  OUT_J="$(bash "$TARGET" --check 259 2>/dev/null)"
  if printf '%s' "$OUT_J" | grep -q '本地 ticket'; then
    ok "J1 worktree 内查到本 worktree 的本地目录"
  else
    bad "J1 没查到本 worktree 的 jira/tickets/EPIC-259 — repo root 可能指向主仓"
  fi
else
  bad "J1 前置不满足: $REPO_ROOT/jira/tickets/$WT_LOCAL_MARKER 不存在"
fi

# J2: 把脚本 copy 到一个**深层子目录**再跑. 若用 $SCRIPT_DIR/.. 推导,
# repo root 会算成子目录的父目录 (不是仓库根), 于是查不到 jira/tickets.
# 用 --show-toplevel 则不受脚本位置影响.
DEEP_DIR="$REPO_ROOT/scripts/dashboard"
if [ -d "$DEEP_DIR" ]; then
  cp "$TARGET" "$DEEP_DIR/.e259-probe.sh"
  OUT_J2="$(bash "$DEEP_DIR/.e259-probe.sh" --check 259 2>/dev/null)"
  RC_J2=$?
  rm -f "$DEEP_DIR/.e259-probe.sh"
  # 从 scripts/dashboard/ 跑, $SCRIPT_DIR/.. = scripts/ (不是仓库根) → 查不到本地 ticket
  # 用 --show-toplevel → 仍能查到
  if printf '%s' "$OUT_J2" | grep -q '本地 ticket'; then
    ok "J2 脚本置于深层子目录仍能定位仓库根 (--show-toplevel 生效)"
  else
    bad "J2 从 scripts/dashboard/ 跑时定位不到仓库根 — 说明用了 SCRIPT_DIR 推导"
  fi
else
  bad "J2 前置不满足: $DEEP_DIR 不存在"
fi

# ---------------------------------------------------------------
echo "--- 组 K: 4 位编号告警 ---"
WT_K="$(make_repo k1)"
mkdir -p "$WT_K/jira/tickets/EPIC-900"
echo '{}' > "$WT_K/jira/tickets/EPIC-900/ticket.json"
echo "x" > "$WT_K/confluence/decisions/EPIC-901-foo.md"
commit_and_push "$WT_K"
mkdir -p "$WT_K/jira/tickets/EPIC-1234"
echo '{}' > "$WT_K/jira/tickets/EPIC-1234/ticket.json"
ERR_K="$( (cd "$WT_K" && KALLAX_NUMBERING_REF=origin/miao bash scripts/next-epic-id.sh 2>&1 >/dev/null) )"
if printf '%s' "$ERR_K" | grep -q '超过 3 位'; then
  ok "K1 出现 4 位编号时告警 (3 位假设失效可见)"
else
  bad "K1 4 位编号无告警 — 会被静默截断成 3 位"
fi

# ---------------------------------------------------------------
echo "--- 组 L: 数值排序 (N6 变异体防护) ---"
# 无 sort -un: 字典序把 "99" 排在 "250" 后面, max 误判为 99, next 给 100 (撞号)
# 有 sort -un: max 真的是 250, next 给 251
WT_L1="$(make_repo l1)"
mkdir -p "$WT_L1/jira/tickets/EPIC-099"
echo '{}' > "$WT_L1/jira/tickets/EPIC-099/ticket.json"
mkdir -p "$WT_L1/jira/tickets/EPIC-250"
echo '{}' > "$WT_L1/jira/tickets/EPIC-250/ticket.json"
commit_and_push "$WT_L1"
N_L1="$(run_in "$WT_L1" 2>/dev/null)"
if [ "$N_L1" = "EPIC-251" ]; then
  ok "L1 数值排序: EPIC-099 + EPIC-250 → next=EPIC-251 (不是字典序 EPIC-100)"
else
  bad "L1 排序错: 期望 EPIC-251, 实得 $N_L1 — N6 变异体 (字典序 99 排最后)"
fi
# L2: EPIC-099 是 3 位零填充 (effective 99), 跟上 EPIC-0099 (4 位) 区分
# 0 开头的 3 位数 99 跟 250 比, 真正的 max 是 250
WT_L2="$(make_repo l2)"
mkdir -p "$WT_L2/jira/tickets/EPIC-005"
echo '{}' > "$WT_L2/jira/tickets/EPIC-005/ticket.json"
mkdir -p "$WT_L2/jira/tickets/EPIC-120"
echo '{}' > "$WT_L2/jira/tickets/EPIC-120/ticket.json"
commit_and_push "$WT_L2"
N_L2="$(run_in "$WT_L2" 2>/dev/null)"
if [ "$N_L2" = "EPIC-121" ]; then
  ok "L2 数值排序: EPIC-005 + EPIC-120 → next=EPIC-121"
else
  bad "L2 排序错: 期望 EPIC-121, 实得 $N_L2"
fi

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then exit 0; else exit 1; fi
