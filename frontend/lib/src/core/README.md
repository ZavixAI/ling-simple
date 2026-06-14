# core

`core` 是跨业务模块共享的基础设施层。它提供网络、数据库、日志、缓存、存储、平台判断、主题和通用异步工具，不表达具体业务场景。

## 业务含义

这个模块承载 Ling 前端运行所需的底座能力：如何请求后端、如何保存本地私有缓存、如何上传调试日志、如何识别平台、如何管理全局 provider。

## 主要职责

- `network/`：封装 HTTP、multipart、SSE、统一响应和异常。`ApiClient` 支持 access token、401 后 token refresh、请求日志和流式 JSON event。
- `database/`：基于 Drift 的本地数据库，保存 profile 快照、日历缓存、对话快照和调试日志队列。
- `logging/`：应用日志、结构化日志事件、调试执行状态模型、调试日志本地落库和批量上传运行时。
- `storage/`：偏好存储、安全存储、私有资源缓存、push device id 和本地持久化策略。
- `cache/`：内存 JSON 缓存，用于短 TTL 的业务数据缓存。
- `platform/`：平台识别和设备上下文、通知相关模型。
- `theme/`：Light/Dark 主题定义。
- `async/`：`SingleFlight` 等并发控制工具，避免重复加载或重复同步。
- `providers.dart`：核心基础设施 provider。

## 关键入口

- `apiClientProvider`：业务 repository 的默认网络客户端。
- `appDatabaseProvider`：本地 Drift 数据库。
- `DebugExecutionLog`：跨页面展示调试动作执行状态的轻量模型。
- `LocalPersistencePolicy`：决定不同敏感级别数据的存储目标。
- `AppTheme.light()` / `AppTheme.dark()`：应用主题。

## 依赖边界

`core` 不应依赖 `features` 或 `app`。如果某段代码包含业务名词或业务规则，通常不应该放进 `core`，而应放进对应 feature。
