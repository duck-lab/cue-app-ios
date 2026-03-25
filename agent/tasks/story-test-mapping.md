# Story - 测试映射表

用于把开发 Story 与测试项绑定，执行时可直接生成验收清单。

## 映射

| Story | 主要测试点 | 测试类型 | 对应验收项 |
|---|---|---|---|
| 1.1.notification-domain-model | 模型可实例化、默认值、枚举兼容 | 单元测试 | 数据模型完整性 | 
| 1.2.status-state-machine | 合法/非法状态转换、终态约束 | 单元测试 | 状态语义一致性 |
| 1.3.unread-and-feedback-meta | unread 与 status 解耦、clientMeta 序列化 | 单元测试 | badge 口径、反馈结构完整 |
| 2.1.notification-repository-interface | 接口注入、Mock/API 替换不改业务层 | 单元测试 | 可替换 API 层 |
| 2.2.mock-data-source-and-fetch | mock 场景加载、空列表与多状态场景 | 单元测试 | 无真实后端也可运行 |
| 2.3.polling-and-background-refresh | 30s 周期触发、重复请求去重 | 单元测试 + 集成测试 | 轮询更新通知 |
| 2.4.status-feedback-submission | 反馈请求包含状态与可选备注、成功失败分支 | 单元测试 + 集成测试 | 标记完成/忽略可提交反馈 |
| 2.5.offline-queue-and-retry | 失败入队、重试、恢复一致性 | 单元测试 + 集成测试 | 网络失败不丢操作 |
| 3.1.ios-list-and-filter | 列表渲染、筛选排序准确性 | 单元测试 + SwiftUI UI tests | 通知列表可读/可筛选 |
| 3.2.ios-status-actions | 操作更新即时反馈、备注提交 | 单元测试 + UI 测试 | iOS 列表可执行状态更新 |
| 3.3.ios-system-push-quick-reply | 通知动作按钮与文本回传 | 集成测试（系统通知） + 手动测试 | 系统通知快速回复 |
| 4.1.macos-menubar-host | 图标显示、点击打开主窗口 | 手动 UI 测试 + 逻辑测试 | 菜单栏入口可用 |
| 4.2.macos-hover-preview-reply | hover 卡片与动作执行 | 手动 UI 测试 + 自动 UI（可选） | hover 快速回复 |
| 4.3.macos-badge-and-expand | badge 计算、0 隐藏、点击展开 | 单元测试 + UI 测试 | 菜单栏徽标正确 |
| 5.1.local-alert-and-sound | 新通知提示触发、去抖动 | 单元测试 + 手动验收 | 到达提示与音效 |
| 5.2.error-handling-and-retry-observability | 失败状态显示与日志记录 | 单元测试 + 集成测试 | 失败可观测、可重试 |
| 5.3.tests-and-dx | 测试覆盖率、命令可复现、文档映射 | 测试验证 + 文档审核 | 核心路径覆盖 |

## 推荐测试优先级

- P0（上线前必须）：1.2, 2.1, 2.3, 2.4, 3.2, 4.1, 4.3, 5.3
- P1（核心验收）：1.1, 1.3, 2.2, 3.1, 4.2, 5.2
- P2（体验）：3.3, 5.1
