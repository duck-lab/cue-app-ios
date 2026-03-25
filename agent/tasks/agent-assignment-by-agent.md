# 分配清单（按 Agent 分组）

按 Agent 直接发送的执行清单。每位 Agent 负责自己的 Story 集合及重试记录。

## Core-Model-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 1.1.notification-domain-model | P1 | 5.0 | 无（基础） | 3 |  |
| 1.2.status-state-machine | P1 | 5.0 | 1.1 | 3 |  |
| 1.3.unread-and-feedback-meta | P1 | 3.5 | 1.1 | 3 |  |

### 交付摘要模板

- 完成标准：模型定义可编译；状态语义与 `unread` 与 `status` 分离；字段与需求一致。
- 结果文件：模型文件与对应单元测试。

## Infra-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 2.1.notification-repository-interface | P1 | 4.5 | 1.1,1.2,1.3 | 3 |  |

### 交付摘要模板

- 完成标准：业务层可不依赖具体仓库实现。
- 输出：Repository 接口、错误码定义、注入点。

## Support-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 2.2.mock-data-source-and-fetch | P1 | 5.5 | 2.1 | 3 |  |

### 交付摘要模板

- 完成标准：无真实 API 时可稳定预览列表。
- 输出：Mock Repository 与可切换配置。

## Sync-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 2.3.polling-and-background-refresh | P1 | 6.0 | 2.1,2.2 | 3 |  |
| 2.5.offline-queue-and-retry | P2 | 8.0 | 2.4 | 3 |  |

### 交付摘要模板

- 完成标准：轮询与离线重试机制可在无 API 条件下稳定运行。
- 输出：定时调度器、重试队列、恢复策略。

## Core-Flow-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 2.4.status-feedback-submission | P1 | 6.5 | 1.1,1.2,1.3,2.1 | 3 |  |

### 交付摘要模板

- 完成标准：状态变更能提交到反馈层，失败可入重试队列。
- 输出：状态反馈服务与提交链路。

## iOS-List-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 3.1.ios-list-and-filter | P1 | 7.0 | 1.x,2.x | 3 |  |

### 交付摘要模板

- 完成标准：列表可展示、筛选与排序通过。
- 输出：iOS 列表页面与交互。

## iOS-Action-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 3.2.ios-status-actions | P1 | 7.5 | 1.x,2.1-2.4 | 3 |  |

### 交付摘要模板

- 完成标准：列表内三状态操作可用，可选备注提交成功。
- 输出：状态操作入口与反馈联动。

## iOS-Notify-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 3.3.ios-system-push-quick-reply | P2 | 7.0 | 1.1,1.2,2.4 | 3 |  |

### 交付摘要模板

- 完成标准：系统通知可快速回复并携带可选文本。
- 输出：UNNotificationCategory/Action 集成。

## mac-Host-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 4.1.macos-menubar-host | P1 | 6.0 | 1.x,2.x | 3 |  |

### 交付摘要模板

- 完成标准：Menubar 图标与完整窗口联动可用。
- 输出：菜单栏入口与窗口切换。

## mac-Hover-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 4.2.macos-hover-preview-reply | P1 | 6.0 | 1.1,1.3,4.1,2.4 | 3 |  |

### 交付摘要模板

- 完成标准：hover 展示最新通知并可快速操作。
- 输出：hover 预览卡片与快捷动作。

## mac-UI-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 4.3.macos-badge-and-expand | P1 | 4.0 | 1.3,4.1 | 3 |  |

### 交付摘要模板

- 完成标准：badge 按 unread 显示且一致，点击可展开完整列表。
- 输出：badge 展示与点击跳转。

## QA-Agent

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 5.1.local-alert-and-sound | P2 | 5.0 | 2.3 | 3 |  |
| 5.2.error-handling-and-retry-observability | P2 | 7.0 | 2.3,2.4,2.5 | 3 |  |

### 交付摘要模板

- 完成标准：提示/告警与错误可观测能力对齐需求。
- 输出：通知提示配置、错误提示策略、日志指标。

## QA-Lead

### 任务清单

| Story | Priority | Est. Hours | Dependencies | Retry Limit | Blockers |
|---|---|---:|---|---:|---|
| 5.3.tests-and-dx | P3 | 8.5 | All P0 stories | 3 |  |

### 交付摘要模板

- 完成标准：核心路径测试完成并能复现执行。
- 输出：测试覆盖报告、验收闭环文档。

## 更新约定

- 每个 Agent 结束后在 `agent-assignment-checklist.md` 与其日报中同步状态。
- 若 Story 阻塞：
  - 标记 `Blocked`
  - 说明阻塞项与所需资源
  - 指定升级给主控处理
