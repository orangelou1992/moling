#!/bin/bash
# tool_validator.sh - 基于Claude Code Bash验证器的简化版
# 检查危险模式：注入/管道/替换/危险命令
# 4级权限：L0自动/L1首次/L2每次/L3永不

COMMAND="$1"
PERM_LEVEL="${2:-1}"

if [ -z "$COMMAND" ]; then
    echo "Usage: tool_validator.sh <command> [perm_level]"
    echo "L0: auto (read-only)"
    echo "L1: first-confirm (write)"
    echo "L2: always-confirm (dangerous)"
    echo "L3: never-auto (blocked)"
    exit 1
fi

# L3 - 永远阻止
if echo "$COMMAND" | grep -qiE 'rm -rf|sudo|chmod 777'; then
    echo "BLOCKED: L3危险命令"
    exit 3
fi

# 危险管道检测
if echo "$COMMAND" | grep -qiE '; &&|; rm|; reboot|\|\|;|`|\$\('; then
    echo "WARN: 管道/命令替换检测"
fi

# L0 - 放行
if echo "$COMMAND" | grep -qiE '^(read|cat |grep|head|tail|wc|ls -|find|stat|file)'; then
    echo "L0:AUTO"
    exit 0
fi

# L2 - 危险操作
if echo "$COMMAND" | grep -qiE '^(rm |del |drop |kill |curl |wget |pip install|npm install)'; then
    echo "L2:ALWAYS_CONFIRM"
    exit 2
fi

# L1 - 写操作
if echo "$COMMAND" | grep -qiE '^(write|edit|mkdir|cp |mv |touch|echo |tee )'; then
    echo "L1:FIRST_CONFIRM"
    exit 1
fi

echo "DEFAULT:ALLOW"
exit 0
