# Evolver 深度解析 — 2026-04-05

## 核心机制

### 信号提取 (signals.js)
从 session 日志提取信号类型：
- 错误信号: `log_error`, `errsig:`, `errsig_norm:`
- 机会信号: `user_feature_request`, `capability_gap`, `perf_bottleneck`, `high_tool_usage:*`, `repeated_tool_usage:*`

### 基因选择 (selector.js)
- `scoreGene`: 对每个基因计分，匹配信号越多分数越高
- 支持三种匹配模式：正则、子串、多语言别名
- **遗传漂变强度** = 1/√(基因池大小) — 基因少时探索多，基因多时精准选择

### 突变 (mutation.js)
- 三种意图: repair（修复）/ optimize（优化）/ innovate（创新）
- 触发依据: hasErrorishSignal() → repair, hasOpportunitySignal() → innovate, 稳定无错 → optimize
- 风险分层: low/medium/high

### 实际 Cycle 0001
- 检测到的信号: `high_tool_usage:exec`, `repeated_tool_usage:exec`
- 推荐意图: optimize（系统稳定，无错误）
- Hub 结果: 401（节点未注册，hub 无法访问）
- 意义: evolver 发现了 exec 调用过多的模式，推荐了优化方向

## 对墨瞳的意义
自我修复 = 信号检测 → 基因匹配 → 风险评估 → 验证 → 固化
