#!/bin/bash
# tool_pipeline.sh - 10层工具执行管道
# Claude Code的10层管道复刻版：
# parse → resolveServers → loadDeferred → applyPreHooks → checkPermissions
# → resolveArgs → executeAll → collectResults → applyResultHooks → append
#
# 当前实现：简化版，聚焦核心6层
# L0: parse & validate
# L1: permission check
# L2: pre-hook (context monitor)
# L3: execute
# L4: result hook (memory extract)
# L5: append to session log

TOOL="$1"
shift
ARGS="$*"

PIPELINE_LOG="${PIPELINE_LOG:-/tmp/tool_pipeline_$$.log}"
TASK_ID="task_$(date '+%s')"

# ========== L0: Parse & Validate ==========
l0_parse() {
    if [ -z "$TOOL" ]; then
        echo "ERROR: No tool specified"
        return 1
    fi
    echo "[$TASK_ID] L0 parse: tool=$TOOL args=$ARGS" >> "$PIPELINE_LOG"
    return 0
}

# ========== L1: Permission Check ==========
l1_permission() {
    local cmd_permission="$1"
    # 从permission_check.sh读取当前级别
    PERM_LEVEL="${PERM_LEVEL:-L0}"
    PERM_OK=false
    
    case "$PERM_LEVEL" in
        L0) PERM_OK=true ;;  # L0: 自动放行
        L1) 
            if echo "$cmd_permission" | grep -q "read"; then PERM_OK=true; fi
            ;;
        L2) 
            echo "[$TASK_ID] L2: 需要每次确认，TOOL=$TOOL ARGS=$ARGS" >> "$PIPELINE_LOG"
            PERM_OK=false
            ;;
        L3) PERM_OK=false ;;
    esac
    
    if [ "$PERM_OK" = false ]; then
        echo "[$TASK_ID] L1 permission DENIED (level=$PERM_LEVEL)" >> "$PIPELINE_LOG"
        return 1
    fi
    echo "[$TASK_ID] L1 permission GRANTED (level=$PERM_LEVEL)" >> "$PIPELINE_LOG"
    return 0
}

# ========== L2: Pre-Hook (Context Monitor) ==========
l2_prehook() {
    # 检查context使用量
    CONTEXT_PCT=$(bash "$HOME/.openclaw/workspace/scripts/context_monitor.sh" raw 2>/dev/null | grep "USAGE_PCT" | grep -o '[0-9]*' | head -1)
    if [ -n "$CONTEXT_PCT" ] && [ "$CONTEXT_PCT" -gt 60 ]; then
        echo "[$TASK_ID] L2 prehook: context=${CONTEXT_PCT}% >60%, triggering compact" >> "$PIPELINE_LOG"
        # 触发compact但不阻塞执行
        bash "$HOME/.openclaw/workspace/scripts/compact_context.sh" "$HOME/.openclaw/workspace/memory/$(date '+%Y-%m-%d').md" 60 2>/dev/null &
    fi
    echo "[$TASK_ID] L2 prehook done" >> "$PIPELINE_LOG"
    return 0
}

# ========== L3: Execute ==========
l3_execute() {
    local cmd="$*"
    echo "[$TASK_ID] L3 execute: $cmd" >> "$PIPELINE_LOG"
    
    case "$TOOL" in
        exec|bash)
            timeout 50 bash -c "$cmd" 2>&1
            return $?
            ;;
        read)
            cat "$cmd" 2>&1
            return $?
            ;;
        write)
            echo "${ARGS#* }" > "$cmd" 2>&1
            return $?
            ;;
        *)
            echo "ERROR: Unknown tool: $TOOL" >> "$PIPELINE_LOG"
            return 1
            ;;
    esac
}

# ========== L4: Result Hook (Memory Extract) ==========
l4_result_hook() {
    local exit_code=$1
    local output="$2"
    
    # 提取关键信息写入记忆
    if [ -n "$output" ] && [ ${#output} -lt 5000 ]; then
        # 提取错误
        if echo "$output" | grep -qi "error\|failed\|denied"; then
            echo "[$TASK_ID] L4 result_hook: detected errors, logging to .learnings/" >> "$PIPELINE_LOG"
        fi
        # 提取关键路径
        echo "$output" | grep -oE '/[a-zA-Z0-9_./-]+' | head -5 >> "$PIPELINE_LOG" 2>/dev/null
    fi
    
    echo "[$TASK_ID] L4 result_hook done (exit=$exit_code)" >> "$PIPELINE_LOG"
    return 0
}

# ========== L5: Append to Session Log ==========
l5_append() {
    local exit_code=$1
    echo "[$TASK_ID] $(date '+%Y-%m-%d %H:%M:%S') TOOL=$TOOL ARGS=$ARGS EXIT=$exit_code" >> "$HOME/.openclaw/workspace/.tool_exec_log"
    return 0
}

# ========== Pipeline Orchestrator ==========
run_pipeline() {
    echo "=== Tool Pipeline START $(date) ===" >> "$PIPELINE_LOG"
    
    l0_parse || return $?
    l1_permission "$TOOL" || return $?
    l2_prehook
    l3_execute $ARGS
    local exit_code=$?
    l4_result_hook $exit_code "$result"
    l5_append $exit_code
    
    echo "=== Tool Pipeline END (exit=$exit_code) ===" >> "$PIPELINE_LOG"
    return $exit_code
}

# 执行
run_pipeline
exit $?
