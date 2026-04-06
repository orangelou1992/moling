#!/bin/bash
# autocompact.sh - 自动上下文压缩
# Claude Code的Autocompact机制复刻
# 当context使用量>阈值时，自动压缩并保留关键信息
# 阈值: 60% (可配置)

THRESHOLD="${1:-60}"
SESSION_FILE="${2:-}"
MEMORY_FILE="${3:-}"
FORCE="${4:-}"

# 默认文件
[ -z "$SESSION_FILE" ] && SESSION_FILE="$HOME/.openclaw/workspace/SESSION-STATE.md"
[ -z "$MEMORY_FILE" ] && MEMORY_FILE="$HOME/.openclaw/workspace/memory/$(date '+%Y-%m-%d').md"

check_context_pct() {
    # 读取context_monitor输出的百分比
    local pct
    pct=$(bash "$HOME/.openclaw/workspace/scripts/context_monitor.sh" raw 2>/dev/null | grep "USAGE_PCT" | grep -o '[0-9]*' | head -1)
    [ -z "$pct" ] && pct=0
    echo "$pct"
}

compact_session_state() {
    echo "🔧 AUTOCOMPACT: 压缩 SESSION-STATE.md..."
    
    local tmp="/tmp/autocompact_session_$$.md"
    local original_lines=$(wc -l < "$SESSION_FILE")
    
    # 保留：当前任务 + 今天的重要事件 + 上下文状态
    {
        echo "# SESSION-STATE.md - 活跃工作内存（WAL目标）"
        echo "_自动压缩: $(date '+%Y-%m-%d %H:%M') 原行数: $original_lines_"
        echo ""
        grep -E "当前任务|今日重要|已实现|待处理|上下文状态|KAIROS|Evolver" "$SESSION_FILE" | head -30
        echo ""
        echo "## 原始行数: $original_lines"
    } > "$tmp"
    
    mv "$tmp" "$SESSION_FILE"
    local new_lines=$(wc -l < "$SESSION_FILE")
    echo "   $original_lines → $new_lines 行"
}

compact_daily_memory() {
    echo "🔧 AUTOCOMPACT: 压缩每日记忆..."
    
    local tmp="/tmp/autocompact_daily_$$.md"
    local original_lines=$(wc -l < "$MEMORY_FILE")
    
    # 保留：早晨概况 + 关键决策 + 错误记录 + 最近对话
    {
        echo "# $(basename $MEMORY_FILE .md)"
        echo "_自动压缩: $(date '+%Y-%m-%d %H:%M') 原行数: $original_lines_"
        echo ""
        echo "## 早晨概况"
        grep -A5 "早晨概况" "$MEMORY_FILE" | head -10
        echo ""
        echo "## 重要决策 (自动提取)"
        grep -E "\[Decision\]|决定:|采用|选择" "$MEMORY_FILE" | tail -20
        echo ""
        echo "## 错误记录"
        grep -E "ERROR|错误|失败|Err-" "$MEMORY_FILE" | tail -10
        echo ""
        echo "## 最近待处理"
        grep -E "TODO|待|进行中" "$MEMORY_FILE" | tail -10
        echo ""
        echo "## 原始行数: $original_lines"
    } > "$tmp"
    
    mv "$tmp" "$MEMORY_FILE"
    local new_lines=$(wc -l < "$MEMORY_FILE")
    echo "   $original_lines → $new_lines 行"
}

run_autocompact() {
    local pct=$(check_context_pct)
    echo "📊 Context使用量: ${pct}% (阈值: ${THRESHOLD}%)"
    
    if [ "$pct" -lt "$THRESHOLD" ] && [ "$FORCE" != "--force" ]; then
        echo "   未达阈值，无需压缩"
        return 0
    fi
    
    if [ "$pct" -lt "$THRESHOLD" ] && [ "$FORCE" != "--force" ]; then
        return 0
    fi
    
    echo "🚀 开始自动压缩..."
    
    # 记录压缩事件
    echo "[$(date '+%Y-%m-%d %H:%M')] AUTOCOMPACT triggered (${pct}%)" >> "$HOME/.openclaw/workspace/.compaction_log"
    
    compact_session_state
    compact_daily_memory
    
    echo "✅ 自动压缩完成"
    return 0
}

# 主入口
run_autocompact
