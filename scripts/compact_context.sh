#!/bin/bash
# compact_context.sh - Context压缩机制
# 当context使用量>60%时触发，生成摘要替换原始内容

CONTEXT_FILE="${1:-}"
THRESHOLD="${2:-60}"

if [ -z "$CONTEXT_FILE" ] || [ ! -f "$CONTEXT_FILE" ]; then
    echo "Usage: compact_context.sh <context_file> [threshold]"
    exit 1
fi

# 获取行数
LINES=$(wc -l < "$CONTEXT_FILE")
echo "当前行数: $LINES"

# 保留策略：最后50行 + 关键section
TAIL_LINES=50

# 创建临时文件
TMP="/tmp/compact_$$.txt"

# 提取关键section（最近对话）
{
    echo "# Context压缩摘要"
    echo "_压缩时间: $(date '+%Y-%m-%d %H:%M')_"
    echo ""
    echo "## 原始行数: $LINES"
    echo ""
    echo "## 重要决策"
    grep -E "^\[Decision\]|^\*\*Decision|\*\*决定" "$CONTEXT_FILE" | tail -20
    echo ""
    echo "## 错误记录"
    grep -E "ERROR|错误|失败|failed|error" "$CONTEXT_FILE" | tail -10
    echo ""
    echo "## 偏好/设定"
    grep -E "Daniel偏好|Daniel要求|偏好:|规则:" "$CONTEXT_FILE" | tail -10
    echo ""
    echo "## 待处理任务"
    grep -E "TODO|\[ \]|\[x\]|待处理|进行中" "$CONTEXT_FILE" | tail -10
    echo ""
    echo "## 最近对话"
    tail -n $TAIL_LINES "$CONTEXT_FILE"
} > "$TMP"

# 替换原文件
mv "$TMP" "$CONTEXT_FILE"
NEW_LINES=$(wc -l < "$CONTEXT_FILE")
echo "压缩完成: $LINES → $NEW_LINES 行"
echo "保留: 决策 + 错误 + 偏好 + 待办 + 最近$TAIL_LINES行"
