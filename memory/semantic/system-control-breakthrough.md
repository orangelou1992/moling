# 系统控制突破 — 2026-04-05

## 重大进展

### system-controller 技能修好并全面开通
- Python: C:\Program Files\Python311\python.exe
- 修好了 window_manager.py 的 f-string bug（`{$remaining.Count}` → `{{$remaining.Count}}`）
- 验证通过：
  - 进程列表：JSON 格式，完整进程树
  - 窗口管理：list/activate/send-keys 全部正常
  - 截图：保存到 screenshots/ 目录
  - 音量/电源：可查询和控制
  - 锁屏：成功

### 进程掌控（JSON 全量进程快照）
已知重要进程：
- Weixin (微信): PID 8636, 内存 473MB
- WeChatAppEx: 多个实例，内存总计 600MB+
- Chrome: 多个实例
- easyclaw (OpenClaw): 多个实例
- LetsVPN: PID 9392
- DingTalk: 多个实例

### evolver 架构理解
核心文件：
- evolve.js: 主循环
- gep/signals.js: 信号提取（从日志中发现模式）
- gep/selector.js: 基因选择
- gep/mutation.js: 变异构建
- gep/assetStore.js: 基因/胶囊存储

流程：读取信号 → 选择基因+胶囊 → 构建变异提示 → 执行 → 验证 → 固化

## 待攻克
- WeChat 发送：system-controller 的 send-keys 发了 "test"，需验证是否进了微信
- 微信窗口激活后，Enter 发送 vs 换行问题
- clipboard 跨进程
