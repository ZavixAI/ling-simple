# settings

`settings` 是用户设置、账号资料、设备同步和通知偏好模块。

## 业务含义

这个模块管理“当前用户如何使用 Ling”：语言、主题、字号、时区、主动陪伴、安静时段、账号绑定、日历通知偏好、推送设备注册和设备上下文。

## 主要职责

- 拉取并应用 `/me` profile，将 profile preferences 同步到本地设置状态。
- 更新语言、主题、字号、时区、主动陪伴、安静时段和日历通知偏好。
- 处理手机号、邮箱、Apple、微信账号绑定，并同步到认证状态。
- 获取设备上下文，识别时区变化，并在登录后同步到后端 profile。
- 注册远端 push device，上传 push token、locale、timezone、定位上下文等设备信息。
- 管理日历通知权限、通知偏好保存和系统设置入口。
- 登出或注销时只清理 settings/auth 侧状态；远端 push device 删除、托管 Apple 日历事件清理和本地通知取消由 `app` lifecycle 协调。
- 提供设置页、账号绑定、日历连接、反馈、调试页面等 UI。

## 目录结构

- `application/`：`SettingsController`、状态、账号绑定协调、日历通知偏好，以及偏好/设备同步服务。
- `data/repositories/`：反馈上传与提交。
- `data/bridges/`：日历通知、系统评价请求等 native bridge。
- `models/`：账号绑定、反馈、设置导航模型。
- `presentation/`：设置主页面、子页面内容、账号绑定 sheet、通知/通用/关于/主动陪伴内容、调试通知页、反馈 sheet。

## 关键入口

- `settingsControllerProvider`：设置状态和主要设置动作。
- `SettingsDeviceSyncService`：设备上下文、时区同步、push device 注册和后端设备上下文同步。
- `SettingsIdentityBindingCoordinator`：Apple/微信账号绑定的 native 登录调起和错误文案转换。

## 依赖关系

`settings` 依赖 `auth` 的 profile 与账号状态，依赖 `core/platform` 和 native bridge 处理设备能力。它不直接依赖 `calendar` 或 `membership` 的 application/data 层；日历通知排程、Apple 日历清理和跨 feature lifecycle 由 `app` 壳层协调。
