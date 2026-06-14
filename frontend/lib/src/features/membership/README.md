# membership

`membership` 是会员和额度模块，负责判断用户是否可继续使用受限能力，并处理 Apple 购买与订阅恢复。

## 业务含义

这个模块回答两个问题：当前用户拥有什么会员权益，以及当前操作是否应该被会员或每日额度限制拦截。

## 主要职责

- 拉取会员摘要，包括 tier、access state、每日聊天额度、已用量、剩余额度、权益和积分。
- 拉取会员商品目录，并解析不同 provider/channel 的商品信息。
- 在发起聊天前提供本地 gate 判断。
- 从后端错误中解析会员门禁原因，例如每日额度耗尽或需要会员权益。
- 准备 Apple checkout intent，调用 native Apple purchase，并向后端确认交易。
- 恢复 Apple 购买并同步最新会员摘要。
- 打开 Apple 订阅管理页面。
- 不直接判断认证态；调用方需要在 app 层根据认证状态决定刷新摘要或清空本地会员状态。

## 目录结构

- `application/`：`MembershipController`、会员状态、门禁判断。
- `data/repositories/`：会员摘要、商品目录、checkout prepare、Apple confirm、取消订阅 API。
- `data/bridges/`：Apple 内购和订阅管理 native bridge。
- `models/`：会员摘要、商品、channel、checkout intent、Apple purchase result。
- `presentation/`：会员状态卡、订阅面板、会员拦截 sheet。

## 关键入口

- `membershipControllerProvider`：会员摘要、商品目录、购买、恢复和本地 gate。
- `membershipGateResultFromSummary()`：根据本地摘要判断是否需要拦截。
- `membershipGateResultFromError()`：根据后端错误判断是否触发会员拦截。
- `MembershipRepository`：会员相关后端 API。

## 依赖关系

`membership` 依赖 `core/network` 请求后端，依赖 native payment bridge 完成 Apple 购买。它不直接依赖 `auth`；认证态前置判断由 `app` 壳层负责。`chat` 不直接读取会员 provider，而是通过 app 层回调触发摘要 readiness 和本地 gate 判断。
