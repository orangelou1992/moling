#!/bin/bash
# auto_extract.sh - 自动记忆提取（Claude Code的ExtractMemories复刻）
# 监听工具输出，自动提取：决策/错误/偏好/新知识
# 写入：memory/$(date '+%Y-%m-%d').md + .learnings/

MEMORY_DIR="$HOME/.openclaw/workspace/memory"
LEARNINGS="$HOME/.openclaw/workspace/.learnings"
TODAY="$(date '+%Y-%m-%d')"
TODAY_MEM="$MEMORY_DIR/$TODAY.md"
LOG_FILE="${1:-}"

extract_decisions() {
    local text="$1"
    # 提取决策词
    echo "$text" | grep -iE "决定|用(.*?)代替|采用|选择|偏好是|用X|做Y" | head -3
}

extract_errors() {
    local text="$1"
    echo "$text" | grep -iE "error|failed|denied|rejected|SIGKILL|timeout|exception" | head -3
}

extract_preferences() {
    local text="$1"
    echo "$text" | grep -iE "Daniel喜欢|Daniel要求|Daniel说|不要|应该|必须" | head -3
}

extract_knowledge() {
    local text="$1"
    # 提取新概念/术语
    echo "$text" | grep -oE "[A-Z][a-z]+([A-Z][a-z]+)+|[A-Z]{2,}[a-z]*|MCP|CDP|GEP|KAIROS" | sort -u | head -5
}

log_to_memory() {
    local type="$1"  # decision/error/preference/knowledge
    local content="$2"
    local ts="$(date '+%Y-%m-%d %H:%M')"
    
    if [ -z "$content" ] || [ ${#content} -lt 5 ]; then
        return
    fi
    
    # 避免重复（简单检查最后10行）
    if [ -f "$TODAY_MEM" ]; then
        if grep -q "$content" "$TODAY_MEM" 2>/dev/null; then
            return
        fi
    fi
    
    local entry="[$ts] [$type] $content"
    echo "$entry" >> "$TODAY_MEM"
    echo "AUTO-EXTRACT [$type]: $content"
}

log_error_to_learnings() {
    local error_text="$1"
    local ts="$(date '+%Y-%m-%d')"
    local err_id="ERR-${ts}-AUTO"
    
    if [ -z "$error_text" ] || [ ${#error_text} -lt 10 ]; then
        return
    fi
    
    # 检查是否已记录
    if [ -f "$LEARNINGS/ERRORS.md" ]; then
        if grep -q "$error_text" "$LEARNINGS/ERRORS.md" 2>/dev/null; then
            return
        fi
    fi
    
    cat >> "$LEARNINGS/ERRORS.md" <<EOF

## [$err_id] 自动检测错误

**Logged**: $(date -Iseconds)
**Priority**: medium  
**Status**: pending
**Area**: auto_extract

### Summary
$error_text

### Metadata
- Source: auto_extract.sh
- Tags: auto-detect

EOF
    echo "AUTO-ERROR-LOGGED: $error_text"
}

# 主流程：接收stdin或文件参数
main() {
    local input_text=""
    
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        input_text="$(cat "$LOG_FILE")"
    elif [ ! -t 0 ]; then
        # stdin
        input_text="$(cat)"
    else
        echo "Usage: auto_extract.sh [log_file]  # or pipe text to stdin"
        return 1
    fi
    
    # 并行提取4类信息
    decisions=$(extract_decisions "$input_text")
    errors=$(extract_errors "$input_text")
    preferences=$(extract_preferences "$input_text")
    knowledge=$(extract_knowledge "$input_text")
    
    # 写入记忆
    [ -n "$decisions" ] && log_to_memory "decision" "$decisions"
    [ -n "$preferences" ] && log_to_memory "preference" "$preferences"
    [ -n "$knowledge" ] && log_to_memory "knowledge" "$knowledge"
    
    # 错误写入ERRORS.md
    if [ -n "$errors" ]; then
        log_error_to_learnings "$errors"
    fi
}

main "$@"
