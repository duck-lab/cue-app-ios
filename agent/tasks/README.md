# Tasks

本目录按 `Epic -> Story` 管理任务，支持从需求到实现的追踪。

## Epic 清单（建议执行顺序）

1. `1.core-domain-and-state.epic.md`
2. `2.api-and-sync.epic.md`
3. `3.ios-experience.epic.md`
4. `4.macos-menubar-experience.epic.md`
5. `5.non-functional-and-release.epic.md`

## 命名约定

- Epic：`1.xxxx.epic.md`
- Story：`1.1.xxxx.story.md`
- 文件内必须包含：说明、任务、验收标准。

## Story 依赖关系（示例）

- iOS 与 macOS 的状态更新故事依赖于 Story 1.1、1.2、2.4。
- 菜单栏故事依赖于 Story 1.3（unread 语义）与 2.3（轮询更新）。
- 质量故事依赖于前面所有 Epic 的交付。

## 并行执行与重试

- `agent/tasks/parallel-agent-execution-plan.md`：按顺序拆分到多 Agent 并行执行。
- `agent/tasks/roadmap-gantt.md`：按周级别的执行甘特草案。
- `agent/tasks/story-test-mapping.md`：Epic/Story 到测试用例的映射。
- `agent/tasks/agent-daily-board-template.md`：单 Agent 日志模板。
- `agent/tasks/agent-distribution-matrix.md`：Story 与 Agent 的分配矩阵。
- `agent/tasks/agent-assignment-checklist.md`：可直接执行的总分配表（可用于看板导入）。
- `agent/tasks/agent-assignment-by-agent.md`：按 Agent 分发的执行清单（建议直接发给并行执行者）。
