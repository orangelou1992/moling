#!/bin/bash
# permission_check.sh - Claude Code风格的4级权限系统
# 基于memory/CLAUDE-CODE-vs-OPENCLAW-COMPARISON-2026-04-06.md分析实现

TOOL="$1"
ACTION="${2:-exec}"
USER="${3:-default}"

# Permission Level Definitions
# L0: auto - Read-only, always allowed
# L1: first-confirm - Write operations, first time confirm then cache
# L2: always-confirm - Dangerous operations, every time confirm
# L3: never-auto - Extremely dangerous, never auto

PERM_CACHE="/tmp/perm_cache.json"
PERM_DB="/tmp/perm_db.json"

# L0 Tools (Read-only, always auto)
L0_TOOLS="read|grep|glob|search|look|view|show|get|list|cat |head |tail |wc |file |stat |ls -|find . -"

# L1 Tools (Write, first confirm)
L1_TOOLS="write|edit|create|mkdir|cp |mv |touch|echo |printf |append|log |record"

# L2 Tools (Dangerous, always confirm)
L2_TOOLS="delete|remove|rm |del |drop|destroy|shutdown|reboot|kill|pkill|killall|exec |run |bash |source |curl |wget |pip install|npm install|apt|yum"

# L3 Tools (Extremely dangerous, never auto)
L3_TOOLS="rm -rf|sudo|chmod 777|dd |mkfs|fdisk|wipe|nuke|drop database|shutdown now|init 0"

# Working directory whitelist
WORKSPACE_WHITELIST="/home/louyz/.openclaw/workspace/"
DANGEROUS_PATHS="/etc/|/sys/|/proc/|/dev/|C:\\\\Windows|C:\\\\Program Files"

check_l0() {
    for pat in $L0_TOOLS; do
        if echo "$TOOL" | grep -qiE "$pat"; then
            echo "L0:AUTO"
            return 0
        fi
    done
    return 1
}

check_l1() {
    for pat in $L1_TOOLS; do
        if echo "$TOOL" | grep -qiE "$pat"; then
            # 检查缓存
            if [ -f "$PERM_CACHE" ] && grep -q "\"$USER:$TOOL\"" "$PERM_CACHE" 2>/dev/null; then
                echo "L1:CACHED"
                return 0
            fi
            echo "L1:CONFIRM"
            return 1
        fi
    done
    return 1
}

check_l2() {
    for pat in $L2_TOOLS; do
        if echo "$TOOL" | grep -qiE "$pat"; then
            echo "L2:ALWAYS_CONFIRM"
            return 1
        fi
    done
    return 1
}

check_l3() {
    for pat in $L3_TOOLS; do
        if echo "$TOOL" | grep -qiE "$pat"; then
            echo "L3:BLOCKED"
            return 2
        fi
    done
    return 1
}

check_path() {
    for pat in $DANGEROUS_PATHS; do
        if echo "$TOOL" | grep -qiE "$pat"; then
            echo "WARN: 危险路径访问 - $pat"
            return 1
        fi
    done
    return 0
}

# 执行检查
if check_l0; then exit 0; fi
if check_l3; then exit 2; fi
if check_l2; then exit 2; fi
if check_l1; then exit 0; fi

# 默认L1
echo "DEFAULT:L1"
exit 0
