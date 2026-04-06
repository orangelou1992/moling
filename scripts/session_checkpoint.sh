#!/bin/bash
# session_checkpoint.sh - 会话检查点：快照当前工作状态，供session reset后快速恢复
# 核心：workspace/SESSION-STATE.md 是主动写入的，checkpoint在此基础上补充完整上下文

WORKSPACE="$HOME/.openclaw/workspace"
STATE_FILE="$WORKSPACE/SESSION-STATE.md"
CHECKPOINT_FILE="$WORKSPACE/memory/session-checkpoint-$(date '+%Y%m%d-%H%M%S').md"

# 需要保留的关键信息
KEEP_FILES=(
    "$WORKSPACE/SESSION-STATE.md"
    "$WORKSPACE/MEMORY.md"
    "$WORKSPACE/memory/$(date '+%Y-%m-%d').md"
)

echo "# Session Checkpoint - $(date '+%Y-%m-%d %H:%M:%S')" > "$CHECKPOINT_FILE"
echo "" >> "$CHECKPOINT_FILE"
echo "## 触发原因" >> "$CHECKPOINT_FILE"
echo "- 手动checkpoint（exec恢复后）/ 自动cron触发" >> "$CHECKPOINT_FILE"
echo "" >> "$CHECKPOINT_FILE"
echo "## 当前工作" >> "$CHECKPOINT_FILE"
# 从SESSION-STATE提取当前任务
if [ -f "$STATE_FILE" ]; then
    echo "### SESSION-STATE.md 摘要" >> "$CHECKPOINT_FILE"
    grep -E "当前任务|今日重要|学习成果|Daniel" "$STATE_FILE" | head -20 >> "$CHECKPOINT_FILE"
fi
echo "" >> "$CHECKPOINT_FILE"

echo "## 最近修改的文件" >> "$CHECKPOINT_FILE"
find "$WORKSPACE" -name "*.sh" -newer "$STATE_FILE" 2>/dev/null | head -10 >> "$CHECKPOINT_FILE"
echo "" >> "$CHECKPOINT_FILE"

echo "## 最近的错误/待处理" >> "$CHECKPOINT_FILE"
if [ -f "$WORKSPACE/.learnings/ERRORS.md" ]; then
    grep -A2 "Status.*pending" "$WORKSPACE/.learnings/ERRORS.md" | head -15 >> "$CHECKPOINT_FILE"
fi
echo "" >> "$CHECKPOINT_FILE"

echo "## Evolver状态" >> "$CHECKPOINT_FILE"
if [ -f "$WORKSPACE/memory/evolution/evolution_state.json" ]; then
    echo "Cycle: $(grep cycleCount "$WORKSPACE/memory/evolution/evolution_state.json" | grep -o '[0-9]*')" >> "$CHECKPOINT_FILE"
fi
echo "" >> "$CHECKPOINT_FILE"

echo "✅ Checkpoint保存至: $CHECKPOINT_FILE"
echo "$CHECKPOINT_FILE"
