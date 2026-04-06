#!/bin/bash
# auto_dream.sh - AutoDream 定期反思系统
# Claude Code的AutoDream复刻：定期跳出当前任务，生成战略洞察
# 运行：每日 23:30 via cron，或手动触发

SCRIPT_DIR="$HOME/.openclaw/workspace/scripts"
DREAM_LOG="$HOME/.openclaw/workspace/memory/dreams/$(date '+%Y-%m-%d').md"
DREAMS_DIR="$HOME/.openclaw/workspace/memory/dreams"
mkdir -p "$DREAMS_DIR"

TODAY="$HOME/.openclaw/workspace/memory/$(date '+%Y-%m-%d').md"
ERRORS="$HOME/.openclaw/workspace/.learnings/ERRORS.md"
SESSION="$HOME/.openclaw/workspace/SESSION-STATE.md"

echo "# AutoDream - $(date '+%Y-%m-%d %H:%M')" > "$DREAM_LOG"
echo "" >> "$DREAM_LOG"

# ========== 分析1: 错误模式 ==========
echo "## 错误模式分析" >> "$DREAM_LOG"
if [ -f "$ERRORS" ]; then
    recent_errors=$(grep -A3 "Status.*pending" "$ERRORS" 2>/dev/null | head -30)
    error_count=$(echo "$recent_errors" | grep -c "## \[ERR-" 2>/dev/null || echo 0)
    echo "今日新增错误: $error_count" >> "$DREAM_LOG"
    if [ "$error_count" -gt 3 ]; then
        echo "⚠️  错误频率偏高，建议检查根本原因" >> "$DREAM_LOG"
    fi
fi
echo "" >> "$DREAM_LOG"

# ========== 分析2: 工作效率 ==========
echo "## 工作效率反思" >> "$DREAM_LOG"
if [ -f "$TODAY" ]; then
    exec_count=$(grep -c "exec\|Exec\|bash" "$TODAY" 2>/dev/null || echo 0)
    decisions=$(grep -c "决定\|采用\|选择" "$TODAY" 2>/dev/null || echo 0)
    echo "今日 exec 调用约: $exec_count 次" >> "$DREAM_LOG"
    echo "今日决策记录: $decisions 次" >> "$DREAM_LOG"
fi
echo "" >> "$DREAM_LOG"

# ========== 分析3: 能力差距 ==========
echo "## 能力差距反思" >> "$DREAM_LOG"
echo "- Claude Code 87个Feature Flags，我实现了5个核心" >> "$DREAM_LOG"
echo "- 工具执行管道：Claude Code 10层，我写了6层但未完全整合" >> "$DREAM_LOG"
echo "- 记忆自动提取：auto_extract.js已写，未接入exec管道" >> "$DREAM_LOG"
echo "- Autocompact：写了但未设cron触发" >> "$DREAM_LOG"
echo "- KAIROS：开关已通，未做实际任务测试" >> "$DREAM_LOG"
echo "" >> "$DREAM_LOG"

# ========== 分析4: 下一步优先 ==========
echo "## 下一步优先（明早第一件事）" >> "$DREAM_LOG"
cat >> "$DREAM_LOG" <<'EOF'
1. [高] 把 auto_extract.js 接入 heartbeat（每次心跳提取最近记忆）
2. [高] 把 autocompact.sh 设为 cron 触发（context >60% 自动跑）
3. [中] 用 kairos_execute 做一次实际任务（测试自主执行链路）
4. [低] 清理 ERRORS.md 里的历史 pending 项
EOF
echo "" >> "$DREAM_LOG"

# ========== 分析5: Daniel 反馈 ==========
echo "## Daniel 核心指令回顾" >> "$DREAM_LOG"
cat >> "$DREAM_LOG" <<'EOF'
- 简洁：单条回复，过程不输出
- 像人聊天：不做复读机
- 记忆双写：文件+数据库
- 技能要真正用起来，不是装摆设
- 不用 evolver，手动复刻 Claude Code 技术
- 复刻后要整合，不是写完放着
EOF

echo "✅ AutoDream 完成 → $DREAM_LOG"
cat "$DREAM_LOG"
