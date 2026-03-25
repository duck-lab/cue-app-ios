# Agent 分配执行清单

用于直接分发给并行 Agent 的总表，可按周或按日推进。

## 总则

- Retry 上限：3 次（Retry-1 / Retry-2 / Retry-3）
- 优先级：P1 必须在同一迭代优先处理
- 状态：`Pending / In Progress / Done / Blocked / Retrying`

## 分配表（可直接复制到看板）

| Story | Suggested Agent | Priority | Est. Hours | Dependencies | Retry Limit | Status | Owner | Start | Finish | Blockers |
|---|---|---|---:|---|---:|---|---|---|---|
| 1.1.notification-domain-model | Core-Model-Agent | P1 | 5.0 | 1.1 | 3 | Pending |  |  |  |
| 1.2.status-state-machine | Core-Model-Agent | P1 | 5.0 | 1.1 | 3 | Pending |  |  |  |
| 1.3.unread-and-feedback-meta | Core-Model-Agent | P1 | 3.5 | 1.1 | 3 | Pending |  |  |  |
| 2.1.notification-repository-interface | Infra-Agent | P1 | 4.5 | 1.1,1.2,1.3 | 3 | Pending |  |  |  |
| 2.2.mock-data-source-and-fetch | Support-Agent | P1 | 5.5 | 2.1 | 3 | Pending |  |  |  |
| 2.3.polling-and-background-refresh | Sync-Agent | P1 | 6.0 | 2.1,2.2 | 3 | Pending |  |  |  |
| 2.4.status-feedback-submission | Core-Flow-Agent | P1 | 6.5 | 1.1,1.2,1.3,2.1 | 3 | Pending |  |  |  |
| 2.5.offline-queue-and-retry | Sync-Agent | P2 | 8.0 | 2.4 | 3 | Pending |  |  |  |
| 3.1.ios-list-and-filter | iOS-List-Agent | P1 | 7.0 | 1.x,2.x | 3 | Pending |  |  |  |
| 3.2.ios-status-actions | iOS-Action-Agent | P1 | 7.5 | 1.x,2.1-2.4 | 3 | Pending |  |  |  |
| 3.3.ios-system-push-quick-reply | iOS-Notify-Agent | P2 | 7.0 | 1.1,1.2,2.4 | 3 | Pending |  |  |  |
| 4.1.macos-menubar-host | mac-Host-Agent | P1 | 6.0 | 1.x,2.x | 3 | Pending |  |  |  |
| 4.2.macos-hover-preview-reply | mac-Hover-Agent | P1 | 6.0 | 1.1,1.3,4.1,2.4 | 3 | Pending |  |  |  |
| 4.3.macos-badge-and-expand | mac-UI-Agent | P1 | 4.0 | 1.3,4.1 | 3 | Pending |  |  |  |
| 5.1.local-alert-and-sound | QA-Agent | P2 | 5.0 | 2.3 | 3 | Pending |  |  |  |
| 5.2.error-handling-and-retry-observability | QA-Agent | P2 | 7.0 | 2.3,2.4,2.5 | 3 | Pending |  |  |  |
| 5.3.tests-and-dx | QA-Lead | P3 | 8.5 | All P0 stories | 3 | Pending |  |  |  |

## 更新规则

- 每个 Story 完成后写入 `Owner`、`Start`、`Finish`。
- 出现阻塞时在 `Status=Blocked` 并将 `Blockers` 说明清楚。
- 重试时在对应任务下记录 Retry 状态到独立日报（`agent-daily-board-template.md`）。

## 快速上日报（示例）

- `1.1` 已分配 Core-Model-Agent，状态 In Progress，预计 2h 内返回初版。
- `2.4` 出现 API 反馈返回码未定义，转 `Blocked`，等待 Story 2.4 调用方错误码约定。
- `2.5` 经过 Retry-2 后通过。
