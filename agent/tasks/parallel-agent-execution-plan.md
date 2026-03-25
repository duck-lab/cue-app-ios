# 多 Agent 并行执行计划

目标：在保持依赖顺序的前提下，提高实现速度。

## 执行原则

1. 先完成存在依赖关系的前置 Story。
2. 对无依赖或同层依赖的 Story 按 Agent 并行处理。
3. 每个 Story 允许最多重试 3 次：
   - 第 1 次：常规执行
   - 第 2 次：复用日志与上下文快速修复
   - 第 3 次：最小改动回归重试
4. 第 3 次仍失败则停用该 Story 并汇报阻塞项，由主控代理接管。

## 任务批次与并行分组（建议）

### Batch 0（顺序启动）

- `1.1.notification-domain-model`
- `1.2.status-state-machine`
- `1.3.unread-and-feedback-meta`

### Batch 1（核心依赖层）

- 并行前提：Batch 0 全部通过。
- `2.1.notification-repository-interface`（必须先完成）
- `2.2.mock-data-source-and-fetch`（可并行于 2.1 完成后）

### Batch 2（同步与反馈）

- 前提：2.1 已完成；2.2/2.3 可并行推进，2.4 依赖 2.1。
- Agent-Sync-A：`2.3.polling-and-background-refresh`
- Agent-Sync-B：`2.2.mock-data-source-and-fetch`（若未完成，先并行补齐）
- Agent-Sync-C：`2.4.status-feedback-submission`
- Agent-Sync-D：`2.5.offline-queue-and-retry`（依赖 2.4）

### Batch 3（iOS 体验）

- 前提：`1.x` 与 `2.x` 核心已可用。
- Agent-iOS-List：`3.1.ios-list-and-filter`
- Agent-iOS-Action：`3.2.ios-status-actions`
- Agent-iOS-QuickReply：`3.3.ios-system-push-quick-reply`

### Batch 4（macOS 体验）

- 前提：`1.x` 与 `2.x` 核心已可用。
- Agent-mac-Host：`4.1.macos-menubar-host`
- Agent-mac-Hover：`4.2.macos-hover-preview-reply`
- Agent-mac-Badge：`4.3.macos-badge-and-expand`

### Batch 5（质量与收敛）

- 并行启动：`5.1.local-alert-and-sound`、`5.2.error-handling-and-retry-observability`。
- 最后：`5.3.tests-and-dx`。

## 失败重试策略（3 次）

- 每个 Agent 在提交前提供以下交付物：
  - 代码变更
  - 自测结果（命令输出或执行截图）
  - 失败原因与根因分析（若失败）
- 失败重试流程：
  1. 重试 1：按失败日志仅修复直接原因
  2. 重试 2：审查阻塞项、更新依赖并重跑
  3. 重试 3：收缩改动范围，保留最小可用实现后提交
- 三次失败仍失败：
  - 标记为 BLOCKED，转给主控代理处理依赖/设计问题。
  - 对外更新 `阻塞项` 并记录在对应 Story。

## 里程碑映射（并行版）

- M1（Batch 0 + Batch 1）：核心模型与数据层
- M2（Batch 2）：同步与反馈闭环
- M3（Batch 3 + Batch 4）：iOS/macOS 可用功能并行完成
- M4（Batch 5）：体验增强与验收测试
