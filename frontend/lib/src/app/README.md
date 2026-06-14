# app

`app` 是前端应用壳层，负责把各个业务 feature 组装成一个可运行的 Flutter 应用。这里不承载单一业务域的数据模型，而是处理应用级导航、登录态切换、首页多面板状态、全局主题和 feature provider 装配。

## 业务含义

这个模块代表用户打开 Ling 后看到的主应用体验：登录恢复、聊天主界面、日历页面、设置页面、会员状态、调试入口和前后台生命周期联动。它是各业务模块的协调者。

## 主要职责

- 创建 `LingApp`，配置 `MaterialApp`、主题、语言、本地化和首页。
- 在应用启动后触发登录态恢复，并根据登录态展示登录流程或认证后的主壳层。
- 维护主界面的打开状态，例如日历页、设置页、未读日历提醒、前后台状态。
- 协调跨 feature 的流程，例如日历变更后刷新日程、日历通知重新排程、设置页加载日历连接、推送前台上下文同步。
- 统一处理认证会话 lifecycle，例如登出/注销前清理远端 push device、托管 Apple 日历事件、本地日历通知和用户域本地缓存。
- 作为 `chat` 与 `membership` 的协调层，在聊天前确认会员摘要 ready，并把聊天返回的额度摘要应用回会员状态。
- 统一声明 feature 仓储、平台桥和服务的 Riverpod provider。

## 目录结构

- `app.dart`：应用根 Widget，负责主题、语言和 `LingCalendarHomePage` 挂载。
- `feature_providers.dart`：业务层 provider 集中装配，包含仓储、平台 MethodChannel bridge、图片选择器、设备 ID store 等。
- `application/`：应用壳状态与控制器。`HomeSurfaceController` 聚合日历、设置、反馈、调试、Apple 日历同步等跨模块动作；`AppSessionLifecycleCoordinator` 聚合会话 cleanup、日历通知排程和 chat/membership 协调。
- `presentation/`：首页壳层 UI、登录恢复页、认证后壳层等应用级界面。

## 关键入口

- `LingApp`：Flutter 应用根节点。
- `LingCalendarHomePage`：认证前后主页面和三大页面切换的核心容器。
- `homeSurfaceControllerProvider`：跨业务页面的数据加载与动作协调入口。
- `appSessionLifecycleCoordinatorProvider`：跨模块 lifecycle、通知排程和会员聊天前置检查入口。
- `feature_providers.dart`：新增 repository 或 native bridge 时通常从这里暴露 provider。

## 依赖边界

`app` 可以依赖 `features`、`core`、`shared` 和 `config`。具体业务规则应优先放在对应 feature 的 `application` 或 `data` 层，`app` 负责串联跨 feature 流程，并承接不应放入单一 feature 的会话 lifecycle 与协调逻辑。
