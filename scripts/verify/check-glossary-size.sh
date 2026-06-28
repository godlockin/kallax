#!/usr/bin/env bash
# KALLAX Glossary Size Check (v2.7.5, 跟"反讽" 闭环, 跟 Karpathy "Readability Over Cleverness" 联合)
# 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合
# 跟 14 BE 累计 联合, 跟"翻篇&精进" 战略 一致

set -euo pipefail

GLOSSARY="${1:-docs/kallax-glossary.md}"
MAX_TERMS="${2:-35}"

if [[ ! -f "$GLOSSARY" ]]; then
  echo "ERROR: glossary not found: $GLOSSARY" >&2
  exit 2
fi

term_count=$(grep -cE "^### [0-9]+\." "$GLOSSARY")

if [[ $term_count -le $MAX_TERMS ]]; then
  echo "GLOSSARY OK: $term_count terms (<= $MAX_TERMS, 跟 Karpathy Readability 联合, 跟反讽 联合)"
  exit 0
else
  echo "GLOSSARY TOO BIG: $term_count terms (> $MAX_TERMS, 跟反讽 联合, 跟诚实修正 联合, 跟独立 拍 explicit 约束 联合)"
  echo "  跟翻篇精进 战略 一致 — 需继续压缩"
  exit 1
fi
