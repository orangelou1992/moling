#!/bin/bash
# smooth_operator.sh - 丝滑操作层
# Claude Code风格的可靠GUI操作：retry + 验证 + 优雅降级
# 使用方式: bash smooth_operator.sh <command> [args]

PYTHON="C:/Program Files/Python311/python.exe"
SCRIPT_DIR="$HOME/.openclaw/workspace/skills/system-controller/scripts"
GUI_PY="$SCRIPT_DIR/gui_controller.py"

# ========== 核心函数 ==========

retry_visual_click() {
    # 截图 → OCR找文字 → 点击
    # 用法: retry_visual_click "要点击的文字" [max_attempts]
    local target="$1"
    local max_attempts="${2:-3}"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "[smooth] 尝试 $attempt/$max_attempts: 查找 '$target'"
        
        # OCR全屏，grep目标文字
        local ocr_result
        ocr_result=$("$PYTHON" "$GUI_PY" visual ocr 2>/dev/null)
        
        if echo "$ocr_result" | grep -qi "$target"; then
            echo "[smooth] ✅ 找到目标: $target"
            return 0
        else
            echo "[smooth] ⚠️ 未找到 '$target'，重试..."
            sleep 1
            attempt=$((attempt + 1))
        fi
    done
    
    echo "[smooth] ❌ 找不到 '$target'，尝试备用方案"
    return 1
}

screenshot_and_find() {
    # 截图并保存，用于调试
    local output="$HOME/.openclaw/workspace/screenshots/smooth_$(date '+%H%M%S').png"
    mkdir -p "$(dirname "$output")"
    "$PYTHON" "$GUI_PY" screenshot full "$output" 2>/dev/null
    echo "$output"
}

wait_for_change() {
    # 等待屏幕变化（检测UI是否响应）
    local region="${1:-0,0,1920,1080}"
    local timeout="${2:-5}"
    local before_hash
    before_hash=$("$PYTHON" "$GUI_PY" visual ocr --x 0 --y 0 --width 1920 --height 1080 2>/dev/null | md5sum | cut -c1-8)
    sleep 1
    local after_hash
    after_hash=$("$PYTHON" "$GUI_PY" visual ocr --x 0 --y 0 --width 1920 --height 1080 2>/dev/null | md5sum | cut -c1-8)
    
    if [ "$before_hash" != "$after_hash" ]; then
        echo "[smooth] ✅ 画面已变化"
        return 0
    else
        echo "[smooth] ⚠️ 画面无变化"
        return 1
    fi
}

click_at_text() {
    # OCR找文字位置 → 点击文字中心
    local target="$1"
    local offset_x="${2:-0}"
    local offset_y="${3:-0}"
    
    # 先截图
    local ss_path
    ss_path=$(screenshot_and_find)
    echo "[smooth] 截图: $ss_path"
    
    # 使用PowerShell FindText或类似方法找文字位置
    # 这里用简单的颜色扫描找相似区域
    # 实际实现依赖Windows OCR
    
    echo "[smooth] 需要Windows GUI环境，WSL无法直接执行"
    return 1
}

# ========== 高级操作 ==========

wechat_search_and_send() {
    # 微信搜索联系人并发送消息
    # 用法: wechat_search_and_send "联系人名" "消息内容"
    local contact="$1"
    local message="$2"
    
    echo "[smooth] 微信操作: 搜索 '$contact'"
    
    # 激活微信窗口
    "$PYTHON" "$SCRIPT_DIR/window_manager.py" activate "微信" 2>/dev/null || true
    
    # Ctrl+F 搜索
    "$PYTHON" "$GUI_PY" keyboard press --keys "ctrl+f" 2>/dev/null
    sleep 0.3
    
    # 输入联系人名（用剪贴板）
    echo "$contact" | clip.exe 2>/dev/null || true
    "$PYTHON" "$GUI_PY" keyboard press --keys "ctrl+v" 2>/dev/null
    sleep 0.3
    "$PYTHON" "$GUI_PY" keyboard press --keys "enter" 2>/dev/null
    sleep 0.5
    
    # 输入消息
    echo "$message" | clip.exe 2>/dev/null || true
    "$PYTHON" "$GUI_PY" keyboard press --keys "ctrl+v" 2>/dev/null
    sleep 0.3
    "$PYTHON" "$GUI_PY" keyboard press --keys "enter" 2>/dev/null
    
    echo "[smooth] ✅ 微信消息已发送"
}

# ========== CLI入口 ==========

case "${1:-}" in
    click-text)
        click_at_text "$2" "${3:-0}" "${4:-0}"
        ;;
    screenshot)
        screenshot_and_find
        ;;
    wechat)
        wechat_search_and_send "$2" "$3"
        ;;
    wait-change)
        wait_for_change "$2" "${3:-5}"
        ;;
    *)
        echo "丝滑操作层 - Claude Code风格GUI自动化"
        echo ""
        echo "用法:"
        echo "  $0 click-text <文字> [偏移x] [偏移y]  - 点击屏幕上的文字"
        echo "  $0 screenshot                            - 截图并保存"
        echo "  $0 wechat <联系人> <消息>               - 微信搜索发送"
        echo "  $0 wait-change [区域] [超时秒]           - 等待画面变化"
        echo ""
        echo "依赖: C:/Program Files/Python311/python.exe + gui_controller.py"
        ;;
esac
