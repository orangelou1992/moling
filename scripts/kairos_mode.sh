#!/bin/bash
# kairos_mode.sh - KAIROS自主模式
# Claude Code的KAIROS autonomous mode复刻
# 当开启时：Plan → Execute → Report，全程无需确认
# Feature Flag: tengu_kairos_autonomous

KAIROS_STATE_DIR="$HOME/.openclaw/workspace/.kairos"
mkdir -p "$KAIROS_STATE_DIR"

KAIROS_FLAG_FILE="$KAIROS_STATE_DIR/autonomous.enabled"
TASK_LOG="$KAIROS_STATE_DIR/task_log.jsonl"
CURRENT_TASK="$KAIROS_STATE_DIR/current_task.json"

# ========== KAIROS 核心 ==========

# 检查是否在自主模式
is_autonomous() {
    [ -f "$KAIROS_FLAG_FILE" ]
}

# 启用自主模式
enable() {
    mkdir -p "$KAIROS_STATE_DIR"
    echo "$(date -Iseconds)" > "$KAIROS_FLAG_FILE"
    echo "✅ KAIROS 自主模式已启用"
}

# 禁用自主模式
disable() {
    rm -f "$KAIROS_FLAG_FILE"
    echo "❌ KAIROS 自主模式已关闭"
}

# 状态
status() {
    if is_autonomous; then
        echo "🟢 KAIROS: ENABLED (since $(cat $KAIROS_FLAG_FILE))"
    else
        echo "🔴 KAIROS: DISABLED"
    fi
}

# ========== 自主任务执行 ==========
# 用法: kairos_execute "任务描述" "执行命令"
kairos_execute() {
    local task_desc="$1"
    local task_cmd="$2"
    local task_id="kairos_$(date '%s')"
    
    if ! is_autonomous; then
        echo "ERROR: KAIROS not enabled. Run: kairos_mode.sh enable"
        return 1
    fi
    
    echo "[$task_id] 📋 PLAN: $task_desc"
    echo "[$task_id] ⚡ EXECUTE: $task_cmd"
    
    # 执行
    local start_ts=$(date +%s)
    local output
    output=$(bash -c "$task_cmd" 2>&1)
    local exit_code=$?
    local end_ts=$(date +%s)
    local duration=$((end_ts - start_ts))
    
    # 记录到task log
    cat >> "$TASK_LOG" <<EOF
{"task_id":"$task_id","desc":"$task_desc","exit":$exit_code,"duration":$duration,"ts":"$(date -Iseconds)"}
EOF
    
    echo "[$task_id] 📊 REPORT: exit=$exit_code duration=${duration}s"
    
    if [ $exit_code -eq 0 ]; then
        echo "[$task_id] ✅ 完成"
    else
        echo "[$task_id] ❌ 失败: $output"
    fi
    
    return $exit_code
}

# ========== CLI ==========
case "${1:-status}" in
    enable) enable ;;
    disable) disable ;;
    status|'') status ;;
    execute) kairos_execute "$2" "$3" ;;
    *) echo "Usage: kairos_mode.sh [enable|disable|status|execute <desc> <cmd>]" ;;
esac
