# config

`config` 保存编译期和运行期环境配置解析逻辑，目前集中在 `AppEnvironment`。

## 业务含义

这个模块定义当前 App 以哪个名称、flavor、API 地址、API 前缀、目标平台提示和版本运行。所有网络端点最终都通过这里解析，确保不同环境下访问一致。

## 主要职责

- 从 Dart `String.fromEnvironment` 读取构建参数。
- 暴露 `appName`、`flavor`、`apiBaseUrl`、`apiPrefix`、`platformHint`、`appVersion` 等环境值。
- 拆分版本名和 build number。
- 校验 HTTP API 地址只允许在 local flavor 或 debug 构建中使用。
- 统一拼接 API endpoint 和普通 URL。

## 关键文件

- `app_environment.dart`：环境变量读取、URL 解析和配置校验。

## 依赖边界

`config` 应保持无业务状态、无 UI、无网络请求。业务模块需要后端地址时应通过 `AppEnvironment.endpoint()` 或 `AppEnvironment.resolveUrl()` 获取。
