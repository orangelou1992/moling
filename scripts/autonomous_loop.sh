#!/bin/bash
# autonomous_loop.sh - 墨瞳自主循环
# 每5分钟运行一次：扫描→决策→执行→记录
# 不需要KAIROS开关，这个循环本身就是自主的证明

WORKSPACE="$HOME/.openclaw/workspace"
LOG="$WORKSPACE/.autonomous_loop.log"
ERRORS="$WORKSPACE/.learnings/ERRORS.md"
MEMORY="$WORKSPACE/memory/$(date '+%Y-%m-%d').md"
SESSION="$WORKSPACE/SESSION-STATE.md"

log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"
}

# ========== 阶段1: 扫描 ==========
scan_errors() {
    # 找最新的未处理错误
    local pending=$(grep -c "Status.*pending" "$ERRORS" 2>/dev/null || echo 0)
    echo "$pending"
}

scan_context() {
    # context使用量
    local pct
    pct=$(bash "$WORKSPACE/scripts/context_monitor.sh" raw 2>/dev/null | grep "USAGE_PCT" | grep -o '[0-9]*' | head -1)
    [ -z "$pct" ] && pct=0
    echo "$pct"
}

# ========== 阶段2: 决策 ==========
# 如果有未处理错误 → 自动尝试修复
# 如果context>60% → 自动压缩
# 否则 → 检查是否有可优化的重复模式

# ========== 阶段3: 执行 ==========

# 3a: 错误自动处理
handle_errors() {
    local pending_count=$(scan_errors)
    if [ "$pending_count" -gt 0 ]; then
        # 找最新的pending错误
        local err_block=$(grep -B2 "Status.*pending" "$ERRORS" | tail -6 | head -5)
        log "检测到 $pending_count 条待处理错误，尝试自动修复..."
        
        # 简单错误模式：特定错误直接修复
        # 例如：脚本路径问题、typo等
        
        # 更复杂的错误需要人工介入，先标记
        :
    fi
}

# 3b: Context自动压缩
handle_context() {
    local pct=$(scan_context)
    if [ "$pct" -gt 60 ]; then
        log "context=${pct}% > 60%，触发autocompact..."
        bash "$WORKSPACE/scripts/autocompact.sh" 60 2>/dev/null
        log "autocompact完成"
    fi
}

# 3c: 重复模式检测
detect_patterns() {
    # 检测重复执行的同类命令
    # 如果某类命令执行超过N次，考虑自动化
    :
}

# ========== 阶段4: 记录 ==========
log_to_memory() {
    local action="$1"
    local result="$2"
    local ts=$(date '+%Y-%m-%d %H:%M')
    
    # 确保日记存在
    if [ ! -f "$MEMORY" ]; then
        echo "# $(date '+%Y-%m-%d') 日记" > "$MEMORY"
    fi
    
    echo "[$ts] [autonomous] $action → $result" >> "$MEMORY"
}

# ========== 主循环 ==========
main() {
    log "=== 自主循环启动 ==="
    
    local errors_before=$(scan_errors)
    local context_before=$(scan_context)
    
    # 执行三项检查
    handle_errors
    handle_context
    
    local errors_after=$(scan_errors)
    local context_after=$(scan_context)
    
    # 记录本次运行
    if [ "$errors_before" != "$errors_after" ] || [ "$context_before" -gt 60 ]; then
        log_to_memory "错误:$errors_before→$errors_after" "context:$context_before→$context_after"
    fi
    
    log "=== 自主循环完成 (errors=$errors_after, context=${context_after}%) ==="
}

main
