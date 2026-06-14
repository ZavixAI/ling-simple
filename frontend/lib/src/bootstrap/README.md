# bootstrap

`bootstrap` 是应用启动入口的初始化编排层。它在 `runApp` 之前准备运行环境、偏好设置、日志、平台配置和初始全局状态。

## 业务含义

这个模块决定 Ling 第一次进入 Flutter 世界前必须具备哪些前置条件，例如语言、字体大小、环境配置、调试日志、iOS 竖屏锁定和后端地址注入。

## 主要职责

- 初始化 Flutter binding、偏好存储和调试日志运行时。
- 校验运行环境配置，避免非本地或非调试构建使用不安全的 HTTP API 地址。
- 解析并写回初始语言、字体大小偏好。
- 配置 native 设备上下文 bridge 使用的后端地址。
- 注册 Flutter、平台和 zone 级错误捕获，并在 fatal 场景触发调试日志 flush。
- 创建 `ProviderScope`，注入初始语言和字号，再挂载 `LingApp`。

## 关键文件

- `bootstrap.dart`：唯一启动编排入口，主函数通常只需要调用 `bootstrap()`。

## 依赖边界

`bootstrap` 可以依赖应用根、配置、核心基础设施和少量设置初始 provider。这里应避免放业务交互逻辑；启动后运行的业务流程应交给 `app` 或对应 feature。
