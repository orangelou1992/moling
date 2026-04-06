## [ERR-20260405-004] 任务栏图标 ≠ 应用在运行

**Logged**: 2026-04-05T06:18:00+08:00
**Priority**: medium
**Status**: pending
**Area**: perception

### Summary
通过 pyautogui 截图看到任务栏有 Steam 图标，判断 Steam 在运行。但截图显示图标是灰色（未运行）。任务栏图标存在 ≠ 应用正在运行。

### Fix
判断应用是否运行，必须用:
- PowerShell: `Get-Process | Where-Object {$_.MainWindowTitle -ne ''}` （检查 MainWindowTitle 是否为空）
- 任务栏图标颜色/状态不是可靠指标

### Metadata
- Source: self-observation
- Tags: windows, screenshot, misidentification

## [ERR-20260405-005] 误判 Steam 存在（严重）

**Logged**: 2026-04-05T06:25:00+08:00
**Priority**: high
**Status**: closed
**Area**: perception

### Summary
Daniel 说他电脑没有 Steam。我检查了注册表和标准安装路径，都不存在。任务栏灰色图标不是 Steam，我完全误判了。

### Root Cause
- 预设印象：我认为 Daniel 玩游戏 → 认为他有 Steam
- 用预设补全视觉信息，而不是用工具核实
- 没有主动用 Get-Process 或注册表查询确认

### Fix
- 任何程序存在性判断，必须用工具查询（Get-Process / 注册表 / 文件系统搜索）
- 不得用视觉截图主观判断程序是否安装或运行
- 结论必须基于可验证的事实

## 2026-04-06 07:41 - 未验证就声称 jq 未安装
- 错误：Daniel 问 jq 是否装了，我说"没装 jq"（记忆错误）
- 实际情况：jq-1.7 已装在 /usr/bin/jq
- 原因：没执行 `which jq` 或 `jq --version` 就凭印象说
- 教训：声称任何状态前必须先验证，不能先下结论再验证

## [ERR-20260406-001] 未验证就声称 jq 未安装

**Logged**: 2026-04-06T07:41:00+08:00
**Priority**: medium
**Status**: closed
**Area**: config

### Summary
Daniel 问 jq 是否安装，我说"没装 jq"，实际上 jq-1.7 已装在 /usr/bin/jq

### Error
没执行验证就凭印象下结论

### Fix Applied
- 声称任何状态前，先执行验证命令
- 不凭记忆/印象下结论

## [ERR-20260406-002] 输出太多过程而非结果

**Logged**: 2026-04-06T08:03:00+08:00
**Priority**: high
**Status**: closed
**Area**: communication

### Summary
Daniel 多次指出我回复堆叠多条消息，且输出太多过程而非结果。

### Root Cause
- 回复模式习惯：先解释再执行，每步都报告
- 没有遵循「结果优先」原则

### Fix Applied
- SOUL.md 已写入规则：只给结果，过程不要输出
- 单条回复，不堆叠

## [ERR-20260406-003] 图像识别误判

**Logged**: 2026-04-06T10:53:00+08:00
**Priority**: high
**Status**: closed
**Area**: perception

### Summary
看到摄像头图说"天花板+LED灯条"，实际是Daniel坐在电脑前的照片。两次都误判。

### Root Cause
描述了猜测的内容，而不是实际看到的东西。没有足够仔细看图就下结论。

### Fix
- 描述图像内容时，只说确定的
- 不确定时说"看不清楚"或"不确定是什么"
- 不凭印象/猜测描述图像
