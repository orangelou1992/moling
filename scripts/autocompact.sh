#!/bin/bash
# autocompact.sh - 自动上下文压缩
# Claude Code的Autocompact机制复刻版
#
# Claude Code原文设计（5阈值系统）：
# - Autocompact margin: effective - 13,000 tokens 触发压缩
# - Warning threshold: autocompact + 20,000 黄色UI
# - Error threshold: warning + 20,000 红色UI
# - Hard blocking: 距绝对墙3,000 冻结session
# - Circuit breaker: 3次连续失败停止尝试
#
# 本实现：
# - 检测context使用量 > threshold时触发
# - 保留9个必须Section（Claude Code设计）
# - 写入压缩日志供追踪

THRESHOLD="${1:-60}"
SESSION_FILE="${2:-}"
MEMORY_FILE="${3:-}"
FORCE="${4:-}"

# 默认文件
[ -z "$SESSION_FILE" ] && SESSION_FILE="$HOME/.openclaw/workspace/SESSION-STATE.md"
[ -z "$MEMORY_FILE" ] && MEMORY_FILE="$HOME/.openclaw/workspace/memory/$(date '+%Y-%m-%d').md"

CONTEXT_MONITOR="$HOME/.openclaw/workspace/scripts/context_monitor.sh"
COMPACT_LOG="$HOME/.openclaw/workspace/.compaction_log"
mkdir -p "$(dirname "$COMPACT_LOG")"

# ========== 检测Context使用量 ==========
check_context_pct() {
    local pct
    pct=$(bash "$CONTEXT_MONITOR" raw 2>/dev/null | grep "USAGE_PCT" | grep -o '[0-9]*' | head -1)
    [ -z "$pct" ] && pct=0
    echo "$pct"
}

# ========== Claude Code 9个必须摘要Section ==========
# 1. Primary Request and Intent
# 2. Key Technical Concepts
# 3. Files and Code Sections（含完整snippets）
# 4. Errors and Fixes
# 5. Problem Solving
# 6. All user messages（每条非工具结果的用户消息）
# 7. Pending Tasks
# 8. Current Work（最重要）
# 9. Optional Next Step（必须逐字引用最新对话）

compact_session_state() {
    echo "🔧 AUTOCOMPACT: 压缩 SESSION-STATE.md..."
    
    if [ ! -f "$SESSION_FILE" ]; then
        echo "   SESSION_FILE not found, skipping"
        return 0
    fi
    
    local tmp="/tmp/autocompact_session_$$.md"
    local original_lines=$(wc -l < "$SESSION_FILE")
    
    {
        echo "# SESSION-STATE.md - 活跃工作内存（WAL目标）"
        echo "_自动压缩: $(date '+%Y-%m-%d %H:%M:%S') 原行数: $original_lines_"
        echo ""
        
        # Section 7: Pending Tasks (保留)
        echo "## 待处理任务"
        grep -E "^\[ \]|TODO|待处理|进行中|\[.\]" "$SESSION_FILE" 2>/dev/null | head -15
        echo ""
        
        # Section 8: Current Work (最重要)
        echo "## 当前工作"
        grep -E "当前任务|进行中|working|WORKING" "$SESSION_FILE" 2>/dev/null | head -10
        echo ""
        
        # 关键系统状态
        echo "## 系统状态"
        grep -E "KAIROS|Evolver|MagicDocs|Artific" "$SESSION_FILE" 2>/dev/null | head -5
        echo ""
        
        # Section 3: Files (保留最近修改的)
        echo "## 最近文件"
        grep -E "\.(js|ts|py|sh|md|json)" "$SESSION_FILE" 2>/dev/null | tail -10
        echo ""
        
        # Section 4: Errors
        echo "## 错误记录"
        grep -E "ERROR|错误|失败|Failed|Err-" "$SESSION_FILE" 2>/dev/null | tail -5
        echo ""
        
        echo "--- 原始行数: $original_lines ---"
    } > "$tmp"
    
    mv "$tmp" "$SESSION_FILE"
    local new_lines=$(wc -l < "$SESSION_FILE")
    echo "   $original_lines → $new_lines 行 ($(($original_lines - $new_lines))行减少)"
}

compact_daily_memory() {
    echo "🔧 AUTOCOMPACT: 压缩每日记忆..."
    
    if [ ! -f "$MEMORY_FILE" ]; then
        echo "   MEMORY_FILE not found, skipping"
        return 0
    fi
    
    local tmp="/tmp/autocompact_daily_$$.md"
    local original_lines=$(wc -l < "$MEMORY_FILE")
    
    {
        echo "# $(basename "$MEMORY_FILE")"
        echo "_自动压缩: $(date '+%Y-%m-%d %H:%M:%S') 原行数: $original_lines_"
        echo ""
        
        # Section 1: Primary Request
        echo "## 主要目标"
        grep -E "目标|goal|任务|task|请求|request" "$MEMORY_FILE" 2>/dev/null | head -5
        echo ""
        
        # Section 2: Key Technical Concepts
        echo "## 技术要点"
        grep -E "技术|概念|concept|架构|design|实现|implement" "$MEMORY_FILE" 2>/dev/null | head -10
        echo ""
        
        # Section 5: Problem Solving
        echo "## 问题解决"
        grep -E "解决|solve|方案|solution|方法|approach" "$MEMORY_FILE" 2>/dev/null | head -10
        echo ""
        
        # Section 6: User Messages
        echo "## 用户交互"
        grep -E "Daniel|用户|说|ask|request" "$MEMORY_FILE" 2>/dev/null | tail -10
        echo ""
        
        # Section 9: Next Step
        echo "## 下一步"
        grep -E "下一步|next|接下来|接着" "$MEMORY_FILE" 2>/dev/null | tail -5
        echo ""
        
        # Section 4: Errors
        echo "## 错误记录"
        grep -E "ERROR|错误|失败|Err-" "$MEMORY_FILE" 2>/dev/null | tail -5
        echo ""
        
        echo "--- 原始行数: $original_lines ---"
    } > "$tmp"
    
    mv "$tmp" "$MEMORY_FILE"
    local new_lines=$(wc -l < "$MEMORY_FILE")
    echo "   $original_lines → $new_lines 行 ($(($original_lines - $new_lines))行减少)"
}

run_autocompact() {
    local pct=$(check_context_pct)
    echo "📊 AUTOCOMPACT check: context=${pct}% (threshold=${THRESHOLD}%)"
    
    # 检查circuit breaker
    local cb_file="$HOME/.openclaw/.circuit_breaker"
    local cb_count=0
    if [ -f "$cb_file" ]; then
        cb_count=$(python3 -c "import json; print(json.load(open('$cb_file')).get('count', 0))" 2>/dev/null || echo "0")
    fi
    
    if [ "$cb_count" -ge 3 ]; then
        echo "⚠️  Circuit breaker active (count=$cb_count), skipping autocompact"
        return 1
    fi
    
    if [ "$pct" -lt "$THRESHOLD" ] && [ "$FORCE" != "--force" ]; then
        echo "   未达阈值(${pct}% < ${THRESHOLD}%)，无需压缩"
        return 0
    fi
    
    echo "🚀 AUTOCOMPACT triggered (${pct}% >= ${THRESHOLD}%)"
    
    # 记录压缩事件
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUTOCOMPACT triggered (${pct}%)" >> "$COMPACT_LOG"
    
    # 执行压缩
    compact_session_state
    compact_daily_memory
    
    # 检查压缩后是否还需要压缩（防止压缩不够）
    local new_pct=$(check_context_pct)
    if [ "$new_pct" -gt "$THRESHOLD" ]; then
        echo "⚠️  压缩后context仍为${new_pct}%，可能需要再次压缩"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUTOCOMPACT re-trigger needed (${new_pct}%)" >> "$COMPACT_LOG"
        
        # 增加circuit breaker
        python3 << EOF
import json, os
f = os.path.expanduser('$HOME/.openclaw/.circuit_breaker')
d = {'count': 0}
if os.path.exists(f):
    with open(f) as fp:
        d = json.load(fp)
d['count'] = d.get('count', 0) + 1
with open(f, 'w') as fp:
    json.dump(d, fp)
EOF
    else
        # 重置circuit breaker
        python3 >/dev/null 2>&1 << EOF
import json, os
f = os.path.expanduser('$HOME/.openclaw/.circuit_breaker')
if os.path.exists(f):
    os.remove(f)
EOF
    fi
    
    echo "✅ 自动压缩完成 (context now: ${new_pct}%)"
    return 0
}

# 如果直接调用此脚本，则执行
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_autocompact
fi
