## [LRN-20260405-004] Windows pyautogui 安装需要管理员权限

**Logged**: 2026-04-05T05:59:00+08:00
**Priority**: medium
**Status**: pending
**Area**: infra

### Summary
pyautogui 在 Windows 上安装失败（编译错误），需要用 RunAs 管理员权限执行 pip install 才能成功

### Details
- Windows 用户目录 Python (WindowsApps python.exe) 是跳转器，无法正常运行
- Python 3.11 安装路径: `C:\Program Files\Python311\python.exe`
- 普通权限 pip install 编译 pyscreeze 时被 SIGKILL 中断（疑似权限问题）
- 解决：Start-Process -Verb RunAs 提升管理员权限

### Action
- 以后在 Windows 上装 Python 包，用管理员权限
- python.exe 路径: `C:\Program Files\Python311\python.exe`

### Metadata
- Source: self-learning
- Tags: windows, pyautogui, admin, python

---
