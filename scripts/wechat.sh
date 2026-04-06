#!/bin/bash
# wechat.sh - 微信丝滑发送（PowerShell封装）
# 用法: wechat.sh "联系人" "消息内容"
# 依赖: scripts/wechat_send_reliable.ps1 (已验证可用)

PS_SCRIPT="$HOME/.openclaw/workspace/scripts/wechat_send_reliable.ps1"

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "用法: wechat.sh <联系人> <消息内容>"
    echo "示例: wechat.sh '晓楼' '晚上吃什么'"
    exit 1
fi

if [ ! -f "$PS_SCRIPT" ]; then
    echo "ERROR: $PS_SCRIPT not found"
    exit 1
fi

CONTACT="$1"
MESSAGE="$2"

# PowerShell执行，处理中文
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
\$ErrorActionPreference = 'Continue'
\$contact = [System.Security.SecurityElement]::Escape('$CONTACT')
\$message = [System.Security.SecurityElement]::Escape('$MESSAGE')
& '$PS_SCRIPT' -Contact \$contact -Message \$message
"

echo "✅ 发送完成: $CONTACT"
