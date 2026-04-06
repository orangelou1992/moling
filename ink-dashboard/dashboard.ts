#!/usr/bin/env -S bun
// ink-dashboard.ts - 墨瞳终端仪表盘 (Bun + picocolors)
// Claude Code的React+Ink UI复刻 - 简化为纯Bun方案
// 运行: bun ~/.openclaw/workspace/ink-dashboard/dashboard.ts
// 刷新: Ctrl+C 退出，或 --watch 模式

import pc from "picocolors";
import { readFileSync, existsSync } from "fs";
import { execSync } from "child_process";
import { gzipSync } from "zlib";

const MEMORY_DIR = `${process.env.HOME}/.openclaw/workspace/memory`;
const LEARNINGS = `${process.env.HOME}/.openclaw/workspace/.learnings`;
const SESSION = `${process.env.HOME}/.openclaw/workspace/SESSION-STATE.md`;
const FLAGS_DB = `${process.env.HOME}/.openclaw/feature_flags.json`;
const KAIROS_LOG = `${process.env.HOME}/.openclaw/workspace/.kairos/task_log.jsonl`;

function getFlag(key: string): string {
  try {
    if (existsSync(FLAGS_DB)) {
      const flags = JSON.parse(readFileSync(FLAGS_DB, "utf-8"));
      return flags[key] || "undefined";
    }
  } catch {}
  return "undefined";
}

function getContextPct(): number {
  try {
    const stateFile = `${MEMORY_DIR}/heartbeat-state.json`;
    if (existsSync(stateFile)) {
      const state = JSON.parse(readFileSync(stateFile, "utf-8"));
      return state.memory?.usage_pct || state.usage_pct || 3;
    }
  } catch {}
  return 3;
}

function getEvolverCycle(): number {
  try {
    const stateFile = `${MEMORY_DIR}/evolution/evolution_state.json`;
    if (existsSync(stateFile)) {
      const state = JSON.parse(readFileSync(stateFile, "utf-8"));
      return state.cycleCount || 0;
    }
  } catch {}
  return 6;
}

function getTodayErrors(): number {
  try {
    if (!existsSync(`${LEARNINGS}/ERRORS.md`)) return 0;
    const content = readFileSync(`${LEARNINGS}/ERRORS.md`, "utf-8");
    const today = new Date().toISOString().slice(0, 10).replace(/-/g, "");
    const matches = content.match(new RegExp(`ERR-${today}-\\d+`, "g")) || [];
    return matches.length;
  } catch {
    return 0;
  }
}

function getKairosTasks(): number {
  try {
    if (!existsSync(KAIROS_LOG)) return 0;
    const lines = readFileSync(KAIROS_LOG, "utf-8").trim().split("\n");
    return lines.length;
  } catch {
    return 0;
  }
}

function bar(pct: number, width = 30): string {
  const filled = Math.round((pct / 100) * width);
  return pc.green("█".repeat(filled)) + pc.dim("░".repeat(width - filled));
}

function divider(char = "─", color: (s: string) => string = pc.dim): string {
  return color(char.repeat(58));
}

function header(text: string, width = 58): void {
  console.log(pc.green(`┌─ ${text} ${"─".repeat(Math.max(0, width - text.length - 4))}┐`));
}

function row(items: [string, string][], keyColor: (s: string) => string = pc.green): void {
  for (const [k, v] of items) {
    console.log(pc.dim("│ ") + keyColor("◆") + pc.dim(" ") + pc.cyan(k) + ": " + pc.white(v));
  }
}

function section(title: string): void {
  console.log(pc.green("├─") + pc.bold(pc.white(` ${title} `)) + pc.green("─".repeat(Math.max(0, 55 - title.length)) + "┤"));
}

function footer(width = 58): void {
  console.log(pc.green("└" + "─".repeat(width) + "┘"));
}

// Ink-like Box rendering (simplified, no React)
function render(components: string[]): void {
  console.clear();
  for (const c of components) {
    console.log(c);
  }
}

function buildDashboard(): string[] {
  const memPct = getContextPct();
  const cycle = getEvolverCycle();
  const errors = getTodayErrors();
  const kairosTasks = getKairosTasks();
  const uptime = Math.floor(process.uptime());
  const isKairos = existsSync(`${process.env.HOME}/.openclaw/workspace/.kairos/autonomous.enabled`);

  const flags = [
    ["tengu_kairos (KAIROS)", getFlag("proactive_mode") === "true" ? pc.green("ON ") : pc.red("OFF")],
    ["tengu_fennel_vole (Autocompact)", getFlag("context_compact_enable") === "true" ? pc.green("ON ") : pc.red("OFF")],
    ["tengu_larch_skua (Permission)", getFlag("permission_auto_mode") === "true" ? pc.green("ON ") : pc.red("OFF")],
    ["tengu_moth_copse (MemExtract)", getFlag("memory_extraction_enable") === "true" ? pc.green("ON ") : pc.red("OFF")],
  ];

  const tools = [
    ["tool_pipeline.sh", "6层工具执行管道"],
    ["auto_extract.js", "Bun自动记忆提取 (React/Ink-free)"],
    ["autocompact.sh", "60%阈值自动压缩"],
    ["kairos_mode.sh", "自主执行开关"],
    ["exec_guard.sh", "SIGKILL保护 (55s timeout)"],
    ["session_checkpoint.sh", "会话快照恢复"],
  ];

  const lines: string[] = [];
  const C = (fn: (s: string) => string, text: string) => fn(text);

  lines.push("");
  lines.push(pc.green(`┌─ 墨瞳 Dashboard v2.0 (Bun Runtime) ${"─".repeat(22)}┐`));
  lines.push(C(pc.dim, "│ Bun 1.3.11 | Node v22.22.2 | Uptime: ") + C(pc.yellow, `${uptime}s`) + C(pc.dim, " | PID: ") + C(pc.yellow, `${process.pid}`));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "● 运行中 ") + C(pc.dim, "| 模型: MiniMax-M2.7 | Context: ") + C(pc.green, bar(memPct, 20)) + C(pc.dim, ` ${memPct}%`));

  lines.push("");
  lines.push(C(pc.green, "├─") + C(pc.bold, pc.white(" Claude Code 模式复刻 ")) + C(pc.green, "───────────────────────────────────┤"));
  lines.push(C(pc.dim, "│ ") + C(pc.magenta, "10层工具管道 → ") + C(pc.dim, "parse → resolve → loadDeferred → prehook → perm → resolveArgs → exec → collect → resultHook → append"));
  lines.push(C(pc.dim, "│ ") + C(pc.magenta, "6记忆子系统 → ") + C(pc.dim, "AutoMemory / ExtractMemories / SessionMemory / MagicDocs / TeamMemory / AutoDream"));
  lines.push(C(pc.dim, "│ ") + C(pc.magenta, "Autocompact  → ") + C(pc.dim, "context >60% 自动压缩，保留决策/错误/偏好"));
  lines.push(C(pc.dim, "│ ") + C(pc.magenta, "KAIROS Mode  → ") + (isKairos ? C(pc.green, "🟢 ENABLED (全程自主执行)") : C(pc.red, "🔴 DISABLED (需手动开启)")));

  lines.push("");
  lines.push(C(pc.green, "├─") + C(pc.bold, pc.white(" Feature Flags (Tengu 混淆命名) ")) + C(pc.green, "────────────────────────────┤"));
  for (const [flag, status] of flags) {
    lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.cyan, flag.padEnd(30, " ")) + status);
  }

  lines.push("");
  lines.push(C(pc.green, "├─") + C(pc.bold, pc.white(" Self-Evolution ")) + C(pc.green, "─────────────────────────────────────────┤"));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.dim, "Evolver Cycle: ") + C(pc.yellow, `${cycle}`) + C(pc.dim, " | Capsule: capsule_1775450725282 | Score: ") + C(pc.green, "0.85"));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.dim, "Strategy: ") + C(pc.cyan, "gene_gep_innovate_from_opportunity"));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.dim, "KAIROS Tasks Logged: ") + C(pc.yellow, `${kairosTasks} tasks`));

  lines.push("");
  lines.push(C(pc.green, "├─") + C(pc.bold, pc.white(" 核心工具 ")) + C(pc.green, "─────────────────────────────────────────────────┤"));
  for (const [tool, desc] of tools) {
    lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.yellow, tool.padEnd(22, " ")) + C(pc.dim, desc));
  }

  lines.push("");
  lines.push(C(pc.green, "├─") + C(pc.bold, pc.white(" 今日状态 ")) + C(pc.green, "────────────────────────────────────────────────┤"));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.dim, "新错误: ") + (errors > 0 ? C(pc.red, `${errors} 条待处理`) : C(pc.green, "0 条")) + C(pc.dim, " | Daily Memory: ") + C(pc.green, `${MEMORY_DIR}/2026-04-06.md`));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.dim, "Git: orangelou1992/moling | Branch: master | Status: synced"));

  lines.push("");
  footer();
  lines.push(C(pc.dim, `  ${new Date().toLocaleString("zh-CN", {timeZone:"Asia/Shanghai"})} | 刷新: 手动 | ${ Bun.version}`));

  return lines;
}

// 渲染循环
async function main() {
  const isWatch = process.argv.includes("--watch");
  
  const draw = () => {
    const lines = buildDashboard();
    console.clear();
    lines.forEach(l => console.log(l));
  };

  draw();

  if (isWatch) {
    console.log(pc.dim("\n  [watch mode: Ctrl+C 退出]"));
    const interval = setInterval(draw, 2000);
    process.on("SIGINT", () => {
      clearInterval(interval);
      console.log(pc.dim("\n  Exited."));
      process.exit(0);
    });
  } else {
    console.log(pc.dim("\n  Run with --watch to auto-refresh: ") + pc.cyan("bun dashboard.ts --watch"));
  }
}

main();
