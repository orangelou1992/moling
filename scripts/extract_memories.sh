#!/bin/bash
# extract_memories.sh - Claude Code风格的自动记忆提取
# 基于6子系统设计，每次交互后自动萃取关键信息

SESSION_LOG="${HOME}/.openclaw/workspace/memory/current_session.log"
EXTRACT_DIR="${HOME}/.openclaw/workspace/memory/extracted/"
MEMORY_FILE="${HOME}/.openclaw/workspace/MEMORY.md"
DB="${HOME}/.agent-memory/memory.db"
REMEMBER="${HOME}/.openclaw/workspace/scripts/remember.sh"

# 确保目录存在
mkdir -p "$EXTRACT_DIR"

# 从最后N行提取关键信息
extract_from_recent() {
    local lines=${1:-20}
    local recent=$(tail -n "$lines" "$SESSION_LOG" 2>/dev/null)
    
    # 提取模式
    patterns=(
        "Decision:|决定:|决策:"
        "Preference:|偏好:|喜欢:"
        "Error:|错误:|失败:"
        "Learning:|学习:|发现:"
        "TODO:|待办:|计划:"
        "Rule:|规则:|原则:"
    )
    
    for pat in "${patterns[@]}"; do
        local matches=$(echo "$recent" | grep -iE "${pat}" | tail -5)
        if [ -n "$matches" ]; then
            echo "$matches"
        fi
    done
}

# 提取决策
extract_decisions() {
    tail -50 "$SESSION_LOG" 2>/dev/null | grep -iE "(decision|决定|决策|preference|偏好|rule|规则)" | tail -10
}

# 提取错误
extract_errors() {
    tail -100 "$SESSION_LOG" 2>/dev/null | grep -iE "(error|错误|failed|失败|exception|异常)" | tail -5
}

# 提取偏好
extract_preferences() {
    tail -50 "$SESSION_LOG" 2>/dev/null | grep -iE "(preference|偏好|daniel|喜欢|want|need|希望)" | tail -5
}

# 写入记忆数据库
write_to_memory() {
    local type=$1
    local content=$2
    local tags=$3
    
    if [ -z "$content" ]; then return; fi
    
    # 写入agent-memory数据库
    python3 << EOF
import sqlite3, sys, os, time
db = os.path.expanduser('$DB')
conn = sqlite3.connect(db)
c = conn.cursor()
ts = int(time.time())
try:
    c.execute("INSERT INTO facts (content, tags, confidence, created_at, last_accessed, access_count) VALUES (?, ?, ?, ?, ?, ?)",
        ('$content', '$type|$tags', 0.8, ts, ts, 0))
    conn.commit()
    print(f"Extracted: $type: $content[:50]")
except Exception as e:
    print(f"DB error: {e}")
conn.close()
EOF
}

# 执行自动提取
run_extraction() {
    echo "=== ExtractMemories ==="
    
    # 提取各类信息
    local decisions=$(extract_decisions)
    local errors=$(extract_errors)
    local prefs=$(extract_preferences)
    
    # 写入记忆
    if [ -n "$decisions" ]; then
        echo "$decisions" | while read -r line; do
            [ -n "$line" ] && write_to_memory "decision" "$line" "auto-extract"
        done
    fi
    
    if [ -n "$errors" ]; then
        echo "$errors" | while read -r line; do
            [ -n "$line" ] && write_to_memory "error" "$line" "auto-extract"
        done
    fi
    
    if [ -n "$prefs" ]; then
        echo "$prefs" | while read -r line; do
            [ -n "$line" ] && write_to_memory "preference" "$line" "auto-extract"
        done
    fi
    
    # 统计
    local total=$(python3 -c "
import sqlite3, os
db = os.path.expanduser('$DB')
conn = sqlite3.connect(db)
c = conn.cursor()
c.execute('SELECT COUNT(*) FROM facts')
print(c.fetchone()[0])
conn.close()
" 2>/dev/null)
    
    echo "记忆总数: $total"
}

# 追加到session log
append() {
    local text="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $text" >> "$SESSION_LOG"
}

case "$1" in
    run) run_extraction ;;
    append) append "$2" ;;
    check) 
        tail -20 "$SESSION_LOG" 2>/dev/null
        ;;
    *)
        echo "Usage: extract_memories.sh {run|append <text>|check}"
        ;;
esac
