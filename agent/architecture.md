# 项目架构文档

## 项目概述

本项目将演进为一个 iOS/macOS 跨平台应用：集中管理外部通知（todo），并允许用户对每条通知执行状态更新。
系统在未来支持真实 API 与推送通道，当前以 Mock 为主完成业务骨架。

## 技术栈

- UI：SwiftUI + 平台特性分支（`#if os(iOS)` / `#if os(macOS)`）
- 持久化：SwiftData
- 本地通知：UserNotifications（UNUserNotificationCenter）
- 架构：分层 + 依赖倒置（Repository + Service）
- 测试：Swift Testing（单元测试）、XCTest（UI 测试）
- 目标：iOS、macOS

## 目标状态机

### 通知状态定义

- `Pending`：待处理
- `InProgress`：进行中
- `Completed`：完成
- `Ignored`：忽略

### 状态转换规则（v1）

- 允许从 `Pending` 转到 `InProgress` / `Completed` / `Ignored`
- 允许从 `InProgress` 转到 `Completed` / `Ignored`
- `Completed` / `Ignored` 作为终态（建议 UI 也提供显式回退，但服务端接受则可放开）

## 目录结构（建议）

```
cude-app/
├── cude-app.xcodeproj/
├── App/
│   ├── cude_appApp.swift
│   ├── SceneState.swift
│   ├── AppLifecycleHandler.swift
│   ├── Resources/
│   │   └── Assets.xcassets
│   └── AppConfig/
│       ├── FeatureFlag.swift
│       └── Constants.swift
├── Domain/
│   ├── Models/
│   │   ├── NotificationItem.swift
│   │   └── Feedback.swift
│   ├── Repositories/
│   │   └── NotificationRepository.swift
│   └── UseCases/
│       ├── PollNotificationsUseCase.swift
│       ├── UpdateStatusUseCase.swift
│       └── ReplyUseCase.swift
├── Infrastructure/
│   ├── Persistence/
│   │   ├── ModelContainer.swift
│   │   └── SwiftDataNotificationStore.swift
│   ├── Network/
│   │   ├── NotificationRepositoryMock.swift
│   │   └── NotificationRepositoryAPI.swift
│   ├── Notification/
│   │   ├── PushNotificationService.swift
│   │   └── LocalAlertService.swift
│   └── Scheduler/
│       └── PollingScheduler.swift
├── Presentation/
│   ├── Shared/
│   │   ├── Components/
│   │   ├── NotificationCard.swift
│   │   ├── StatusBadge.swift
│   │   └── FilterPills.swift
│   ├── iOS/
│   │   ├── Views/
│   │   │   ├── NotificationListView.swift
│   │   │   ├── NotificationFilterView.swift
│   │   │   └── SystemQuickReplyActionProvider.swift
│   │   └── ViewModels/
│   │       └── NotificationListViewModel.swift
│   └── macOS/
│       ├── Views/
│       │   ├── NotificationListView.swift
│       │   ├── MenuBarHostView.swift
│       │   └── MenuBarPopoverView.swift
│       ├── ViewModels/
│       │   └── MenuBarViewModel.swift
│       └── AppKitAdapter/
│           └── MenuBarCoordinator.swift
├── Services/
│   ├── AuthProxy/
│   │   └── AuthContextStore.swift   # 预留
│   ├── Logging/
│   │   └── SyncLogger.swift
│   └── Error/
│       └── AppError.swift
├── Tests/
│   ├── cude_appTests/
│   └── cude_appUITests/
```

## 模块划分与职责

### Domain（领域层）

- 存放业务核心类型（模型、状态机、用例）
- 不依赖 SwiftUI，便于测试与跨端复用

### Infrastructure（基础层）

- 处理存储、网络（含 Mock）、本地通知、轮询调度
- 为 Domain 层服务：`NotificationRepository` 与 `NotificationUseCase` 交互

### Presentation（展示层）

- SwiftUI 页面、组件、状态驱动的 ViewModel（或 ObservableObject）
- iOS 与 macOS 分离实现，处理平台特有交互

### Services（服务层）

- 日志、认证预留、错误定义、调度辅助能力

## 同步与数据流

```text
App 启动
  ├─ 注入 ModelContainer 与 Repository 实例
  ├─ 创建共享状态（Store / ViewModel）
  ├─ 启动 PollingScheduler（30s）
  └─ 向 Repository 拉取通知

Presentation 操作（列表状态变更）
  ├─ 触发 UseCase
  ├─ 本地先更新 SwiftData（乐观更新）
  ├─ 调用 Repository 提交反馈（含可选备注）
  ├─ 成功：记录同步成功状态
  └─ 失败：记录待同步队列，后续重试

推送/系统通知
  ├─ 接收本地提醒或未来 APNs
  ├─ 触发 Pull 或增量更新
  └─ 可直接打开应用、或在通知中支持快速动作入口
```

## API 接口层（v1 设计）

- `GET /notifications`：拉取通知列表（分页可选）
- `POST /notifications/{id}/feedback`：提交状态更新与备注
  - Body: `status`, `comment`, `clientMeta`
- 预留：`POST /notifications/{id}/ack`（可选，记录已见到）

接口未实现时，使用 `MockNotificationRepository` 作为替代。

## 菜单栏架构（macOS）

- 使用 `NSStatusItem` + `Popover`（或 Menu extras 组件）展示入口
- Hover 行为：展示最近一条通知预览卡片与操作按钮
- 点击行为：打开主窗口（完整列表）或展开弹窗
- Badge 按本地 `unread` 字段计数显示未读

## iOS 系统通知架构

- 注册通知分类（Category）与快速动作（Action）
- 支持「完成」「忽略」「进行中」及可选文本输入
- 当用户在系统通知中动作时，路由到统一 `ReplyUseCase`

## 功能确认（v1）

- 系统通知与 macOS hover 快捷回复按钮固定提供三种动作：
  - 进行中
  - 完成
  - 忽略
- hover 卡片支持动作按钮同时附带可选文本输入。
- Menubar badge 按 `unread` 计数。

## 测试策略

- 单元测试（Swift Testing）
  - 状态机转移
  - Repository 行为（Mock）
  - 30 秒轮询触发逻辑
  - 同步失败重试与队列持久化
- UI 测试（XCTest）
  - iOS 列表操作关键路径
  - 菜单栏打开与快捷操作（macOS）
  - 系统通知快速动作触发分发

## 关键实现记录（待补充）

- 将菜单栏 hover 与系统通知的快速操作抽象成统一 `ReplyUseCase`，减少重复逻辑。
- 将 badge 与未读语义定义为持久化字段 `unread`，避免与状态规则耦合。

## 任务落地映射

- 任务化管理入口：`agent/tasks/`
- 建议从 `1.core-domain-and-state.epic.md` 开始实现，逐步完成 `2`、`3`、`4`、`5`。
- `AGENTS.md`、`agent/requirements.md`、`agent/architecture.md` 三份文档应始终保持一致的术语。

## 构建与测试命令

```bash
xcodebuild -project cude-app/cude-app.xcodeproj -scheme cude-app \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

xcodebuild -project cude-app/cude-app.xcodeproj -scheme cude-app \
  -destination 'platform=macOS' build

xcodebuild test -project cude-app/cude-app.xcodeproj -scheme cude-app \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:cude-appTests

xcodebuild test -project cude-app/cude-app.xcodeproj -scheme cude-app \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:cude-appUITests
```
