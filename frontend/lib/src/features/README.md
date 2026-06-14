# features

`features` 是 Ling 前端的业务功能集合。每个一级子目录代表一个相对独立的业务域，并按 `application / data / models / presentation` 分层。

## 业务模块

- `auth`：登录、会话恢复、token 刷新、第三方/手机号/邮箱登录和账号身份模型。
- `calendar`：Ling 日程、意图、月视图、周视图、事件编辑，以及 Apple/外部日历同步。
- `chat`：助理对话、prompt 队列、SSE 流式回复、语音输入、图片附件和本地对话恢复。
- `membership`：会员状态、额度门禁、商品目录、Apple 购买与恢复订阅。
- `settings`：个人资料偏好、语言/主题/字号、账号绑定、通知、设备上下文、推送设备注册和登出清理。

## 分层约定

- `application/`：状态、控制器、用例编排和跨 repository 的业务流程。
- `data/`：后端 repository、native bridge、持久化或外部服务接入。
- `models/`：业务 DTO、枚举、序列化模型。
- `presentation/`：Widget、页面、sheet、视觉组件和交互状态承接。

## 依赖边界

feature 可以依赖 `core`、`shared` 和通过 `app/feature_providers.dart` 暴露的 provider。跨 feature 协调优先放在 `app` 壳层或更高层 orchestrator，避免两个业务模块互相深度耦合。

## 新增业务功能建议

新增功能时先判断它属于已有业务域还是独立业务域。若属于已有业务域，优先在该 feature 内补齐 `application / data / models / presentation`；若会被多个 feature 复用，再考虑抽到 `shared` 或 `core`。
