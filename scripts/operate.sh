#!/bin/bash
# operate.sh - 丝滑操作层 CLI
# 一个入口，所有 GUI 操作统一接口
# 
# 功能:
#   screenshot [name]    - 截图保存
#   ocr [x y w h]       - OCR 识别屏幕文字
#   click-text <文字>    - 找文字位置并点击
#   find-color <hex>     - 找指定颜色的像素
#   wechat <联系人> <消息> - 微信发送
#
# 依赖:
#   Windows Python: C:/Program Files/Python311/python.exe
#   GUI Controller: skills/system-controller/scripts/gui_controller.py

PYTHON="C:/Program Files/Python311/python.exe"
GUI="$HOME/.openclaw/workspace/skills/system-controller/scripts/gui_controller.py"
SCREENSHOT_DIR="$HOME/.openclaw/workspace/screenshots"

ensure_dir() {
    mkdir -p "$SCREENSHOT_DIR"
}

run_gui() {
    "$PYTHON" "$GUI" "$@" 2>/dev/null
}

case "$1" in
    screenshot)
        ensure_dir
        name="${2:-$(date '+%H%M%S')}"
        path="$SCREENSHOT_DIR/${name}.png"
        run_gui screenshot full "$path"
        echo "→ $path"
        ;;
    ocr)
        if [ -z "$2" ]; then
            run_gui visual ocr --x 0 --y 0 --width 1920 --height 1080
        else
            run_gui visual ocr --x "$2" --y "$3" --width "$4" --height "$5"
        fi
        ;;
    find-text)
        # 截图 + OCR 找文字
        ensure_dir
        ss="$SCREENSHOT_DIR/ocr_$(date '+%H%M%S').png"
        run_gui screenshot full "$ss"
        "$PYTHON" - "$ss" "${2:-}" <<'PYEOF'
import sys, pytesseract, json
from PIL import Image
if len(sys.argv) < 3:
    print("Usage: find-text <screenshot> <search_term>")
    sys.exit(1)
img = Image.open(sys.argv[1])
text = pytesseract.image_to_string(img, lang='chi_sim+eng')
search = sys.argv[2].lower()
lines = text.split('\n')
for i, line in enumerate(lines):
    if search in line.lower():
        print(f"FOUND line {i}: {line.strip()}")
print("NOT_FOUND")
PYEOF
        ;;
    wechat)
        # 调用 wechat_send_reliable.ps1
        ps_script="$HOME/.openclaw/workspace/scripts/wechat_send_reliable.ps1"
        if [ ! -f "$ps_script" ]; then
            echo "ERROR: $ps_script not found"
            exit 1
        fi
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
            & '$ps_script' -Contact '$2' -Message '$3'
        " 2>/dev/null
        echo "✅ 微信: '$2' ← '$3'"
        ;;
    list-screenshots)
        ensure_dir
        ls -lt "$SCREENSHOT_DIR"/*.png 2>/dev/null | head -10
        ;;
    screen-size)
        run_gui screenshot size
        ;;
    "")
        echo "丝滑操作层 CLI"
        echo "用法:"
        echo "  operate.sh screenshot [名字]     截图"
        echo "  operate.sh ocr [x y w h]        OCR识别"
        echo "  operate.sh find-text <文字>     找文字"
        echo "  operate.sh wechat <联系人> <消息> 微信发送"
        echo "  operate.sh screen-size          屏幕分辨率"
        echo "  operate.sh list-screenshots     最近截图"
        ;;
    *)
        echo "未知命令: $1"
        ;;
esac
