# chat

`chat` 是 Ling 助理对话模块，负责用户输入、队列、流式回复、附件、语音和本地会话恢复。

## 业务含义

这个模块表示用户与 Ling 助理的一次或多次对话。它把 prompt、附件、语音识别结果、SSE 流式事件和后端 agent session 组合成前端可持续展示和可恢复的会话。

## 主要职责

- 创建或复用 agent session，并判断跨天 session 是否应新建。
- 将用户输入和附件转成后端 messages，并通过 SSE 接收 assistant/tool_call 事件。
- 维护本地 prompt 执行状态；运行中输入与显式引导消息进入本地 pending guidance。
- 维护对话列表、streaming entry、可见条数、本地持久化快照和恢复逻辑。
- 支持图片选择、上传、附件保存和 native camera picker。
- 支持 iOS 实时语音识别，处理 listening、partial、processing、final、error 等事件。
- 通过 app 层回调在发起聊天前确认会员摘要 ready，并接收本地会员门禁判断结果。

## 目录结构

- `application/`：composer、conversation、voice、surface 状态控制，以及 session、queue、prompt execution、recovery、image upload 等 orchestrator/service。
- `data/`：`ChatRepository`、语音识别 bridge、native 相机 bridge、附件保存 bridge、本地持久化清理。
- `models/`：agent session、conversation entry、attachment、持久化状态等 DTO。
- `presentation/`：聊天主界面、输入 dock、空会话视图、消息气泡、工具调用展示、附件视图、队列 sheet、typing indicator。

## 关键入口

- `chatSessionControllerProvider`：把 conversation、composer、voice、surface 多个 controller 聚合成页面可用操作。
- `chatSessionOrchestratorProvider`：会话创建/恢复、prompt 执行、图片上传等业务编排。
- `chatQueueOrchestratorProvider`：prompt 入队、出队和执行。
- `chatRuntimeControllerProvider`：运行期序列号、活跃 SSE iterator、中止信号和语音草稿。
- `ChatRepository`：agent session、SSE stream、会话记录、图片上传和本地对话缓存。

## 依赖关系

`chat` 依赖 `core/network`、`core/database` 和多个 native bridge。`chat/application` 不直接读取 `membership` 或 `auth` provider；认证态、会员摘要 readiness、额度摘要回写和本地 gate 判断由 `app` 壳层通过 `LingCalendarChatSectionCallbacks` 注入。日历工具调用结果也由应用壳层协调刷新 `calendar`。
