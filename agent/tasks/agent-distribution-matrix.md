# Story 分配与执行矩阵

建议配合 `parallel-agent-execution-plan.md` 使用。

## 分配总则

- Batch 0/1：顺序优先，默认由 1 名核心 Agent 处理。
- Batch 2/3/4：按 Agent 专长并行。
- Batch 5：建议最后统一收口，但 5.1 / 5.2 可与并行子任务重叠执行。

## 轮次级分配（建议）

### 轮次 A（Day 1）

- Core-Model-Agent：
  - `1.1.notification-domain-model`
  - `1.2.status-state-machine`
  - `1.3.unread-and-feedback-meta`
- Infra-Agent:
  - `2.1.notification-repository-interface`
- Support-Agent:
  - `2.2.mock-data-source-and-fetch`

### 轮次 B（Day 2）

- Sync-Agent:
  - `2.3.polling-and-background-refresh`
  - `2.5.offline-queue-and-retry`
- Core-Flow-Agent:
  - `2.4.status-feedback-submission`

### 轮次 C（Day 3）

- iOS-List-Agent：
  - `3.1.ios-list-and-filter`
- iOS-Action-Agent：
  - `3.2.ios-status-actions`
- mac-Host-Agent：
  - `4.1.macos-menubar-host`
- mac-Ui-Agent：
  - `4.3.macos-badge-and-expand`

### 轮次 D（Day 4）

- iOS-Notify-Agent：
  - `3.3.ios-system-push-quick-reply`
- mac-Hover-Agent：
  - `4.2.macos-hover-preview-reply`
- QA-Agent（并行启动）：
  - `5.1.local-alert-and-sound`
  - `5.2.error-handling-and-retry-observability`

### 轮次 E（Day 5）

- QA-Lead（合并验收）：
  - `5.3.tests-and-dx`
- 主控：做全量回归与里程碑验收

## 重试与阻塞处理（3 次）

- 每个 Agent 负责该 Story 的 3 次重试记录：`Retry-1 / Retry-2 / Retry-3`。
- 重试 3 失败后，标记 `BLOCKED` 并上报给主控：
  - 失败日志
  - 阻塞依赖（如 Story 未就绪）
  - 建议的替代方案（若有）

## 示例时间线（用于看板）

- 09:00 开始分配并确认依赖
- 10:30 每次同步：状态变更（进行中/阻塞）
- 12:00 小时内未关闭阻塞项上报
- 17:00 产出阶段报告与重试摘要
