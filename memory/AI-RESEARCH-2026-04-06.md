# AI Agent 研究笔记

_2026-04-06 更新_

## GitHub 高星项目（2026-04-06）

### Multi-Agent Orchestration
| 项目 | Stars | 描述 |
|------|-------|------|
| crewAI/crewAI | 48k ⭐ | 角色扮演AI代理编排框架 |
| reworkd/AgentGPT | 36k ⭐ | 浏览器中部署AI代理 |
| openai/swarm | 21k ⭐ | OpenAI教育性多代理编排 |

### Model Context Protocol (MCP) - 正在成为标准
| 项目 | Stars | 描述 |
|------|-------|------|
| microsoft/mcp-for-beginners | 16k ⭐ | MCP入门课程 |
| metadata-org/fastapi_mcp | 12k ⭐ | FastAPI暴露MCP工具 |
| mark3labs/mcp-go | 8.5k ⭐ | Go实现的MCP协议 |
| lastmile-ai/mcp-agent | 8k ⭐ | MCP代理构建指南 |

### Computer Use / GUI Agent
| 项目 | Stars | 描述 |
|------|-------|------|
| showlab/computer_use_ootb | 2k ⭐ | 开箱即用GUI代理 |
| xlang-ai/OpenCUA | 729 ⭐ | 计算机使用代理的开放基础 |
| suitedaces/computer-agent | 616 ⭐ | Rust桌面控制AI |

## 趋势判断

1. **MCP正在成为AI Agent标准接口** - Microsoft/Google/FastAPI都在支持
2. **Multi-Agent编排** - crewAI模式（角色+任务分解）最火
3. **GUI Agent** - 视觉-语言-动作模型（ShowUI）成为新方向
4. **OpenAI Swarm** - 教育目的，轻量级多代理编排

## crewAI 深度分析

- **完全自研** - 不依赖LangChain，从零构建
- **双模式**：
  - **Crews** - 多代理协作模式（角色+任务分解）
  - **Flows** - 事件驱动编排（企业级生产架构）
- **100,000+** 开发者认证，社区活跃

## 待深入
- [ ] crewAI源码研究 - 理解多代理协作模式
- [ ] MCP协议 - 尝试构建一个MCP服务器
- [ ] computer_use_ootb - GUI自动化新可能

## OpenCUA 深度分析

- **目标**：让AI模型能够操作计算机（GUI自动化）
- **OpenCUA-72B**：OSWorld-Verified 45.0%（开源SOTA）
- **核心数据集**：AgentNet，涵盖3个操作系统、200+应用
- **关键技术**：多模态RoPE → 1D RoPE，Kimi-VL的Tokenizer和ChatTemplate
- **vLLM支持**：OpenCUA-7B/32B/72B都可在vLLM运行

## 对墨瞳的启示
- WeChat自动化本质是GUI Agent问题
- OpenCUA思路：大规模数据训练+基础模型
- 我当前方法（CDP+UI Automation）是工程路径，OpenCUA是模型路径
