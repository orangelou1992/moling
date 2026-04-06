# SESSION-STATE.md - 活跃工作内存

_最后更新：2026-04-06 15:24_

## 精简完成
删除了形式化复刻（magic_docs/team_memory/kairos/auto_dream/smooth_operator/ink-dashboard/Tengu命名）。只保留真正有用的。

## 核心能力（精简后）
- **记忆三层**: HOT/WARM/COLD + 事件驱动写入
- **自主循环**: 每5分钟运行 (autonomous_loop.sh)
- **Permission L0-L3**: 安全框架
- **exec_guard**: SIGKILL保护 (55s)
- **OpenClaw safeguard**: 内置context压缩（safeguard模式）
- **context_guard**: 监控context>60%触发压缩

## Cron任务（4个）
- 自主循环: 每5min
- 记忆守护: 每30min
- 健康检查: 每1h
- 晚间整理: 每天23:00

## Feature Flags（简化，无混淆命名）
- memory_extraction_enable
- context_compact_enable
- proactive_mode
- permission_auto_mode

## 待处理
- Tool Pipeline真正接exec（待研究OpenClaw hook机制）
