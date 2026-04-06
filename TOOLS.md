# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

## Windows 控制

- windows-control: `C:\Users\lou\.openclaw\workspace\skills\windows-control\scripts\`
- Python: `C:\Program Files\Python311\python.exe`
- pyautogui 已安装（需 admin 权限安装）
- 截图备选（无需依赖）: `C:\Users\lou\screenshot.ps1`
- 截图输出目录: `C:\Users\lou\.openclaw\media\`

## SkillHub

- CLI: `/home/louyz/.local/bin/skillhub`
- 审核工具: skill-vetter（安装前必审）

## Ubuntu (WSL)

- sudo 密码: `Lyz904800.`（`louyz` 用户，sudo 组）
- 已安装: jq 1.7.1

## Windows TTS

- 技能: windows-tts-wsl2
- 中文语音: Microsoft Huihui Desktop ✅
- 英文语音: Microsoft Zira Desktop ✅
- 调用: `powershell.exe ... \$s.Speak('文本')`
- 脚本: `skills/windows-tts-wsl2/scripts/say.sh`（需修复 powershell.exe 路径）
