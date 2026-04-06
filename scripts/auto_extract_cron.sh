#!/bin/bash
# auto_extract_cron.sh - ExtractMemories 整合进心跳
# 每次心跳调用auto_extract.js扫描最近工具输出，提取记忆
# 路径：~/.openclaw/workspace/scripts/auto_extract_cron.sh

SCRIPT_DIR="$HOME/.openclaw/workspace/scripts"
LOG_DIR="$HOME/.openclaw/workspace/.tool_logs"
TODAY_LOG="$HOME/.openclaw/workspace/memory/$(date '+%Y-%m-%d').md"

mkdir -p "$LOG_DIR"

# 扫描最近工具日志（如果有）
if [ -d "$LOG_DIR" ] && [ "$(ls -A $LOG_DIR 2>/dev/null)" ]; then
    # 合并最近修改的日志
    find "$LOG_DIR" -name "*.log" -mmin -30 2>/dev/null | \
        xargs cat 2>/dev/null | \
        bun "$SCRIPT_DIR/auto_extract.js" 2>/dev/null
fi

# 从SESSION-STATE.md最近内容提取
if [ -f "$HOME/.openclaw/workspace/SESSION-STATE.md" ]; then
    cat "$HOME/.openclaw/workspace/SESSION-STATE.md" | \
        bun "$SCRIPT_DIR/auto_extract.js" 2>/dev/null
fi

# 从daily memory提取
if [ -f "$TODAY_LOG" ]; then
    tail -50 "$TODAY_LOG" | \
        bun "$SCRIPT_DIR/auto_extract.js" 2>/dev/null
fi

echo "✅ ExtractMemories heartbeat run done ($(date '+%H:%M:%S'))"
