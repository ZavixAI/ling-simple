# auth

`auth` 是身份认证和登录会话模块，负责把用户从未登录状态带入可访问 Ling 业务功能的认证状态。

## 业务含义

这个模块处理用户是谁、如何登录、如何恢复会话、如何刷新 token，以及登录成功后前端持有什么用户资料和账号身份绑定信息。

## 主要职责

- 恢复本地保存的认证会话，并在应用启动后决定认证态。
- 支持邮箱验证码、阿里云一键手机号、Apple 登录、微信登录。
- 通过 OAuth token exchange 获取 access token、refresh token、profile 和 identities。
- 在 401 或手动刷新场景中执行 refresh token 流程。
- 保存、清理认证会话，并把资料更新同步到当前 `AuthState`。
- 读取 `/me` 资料、更新偏好、绑定手机号/邮箱/Apple/微信、删除账号和清理用户本地数据。

## 目录结构

- `application/`：`AuthController`、登录 UI 状态控制、会话协调。
- `data/repositories/`：`AuthRepository` 负责登录 token exchange，`ProfileRepository` 负责 `/me`、账号绑定、偏好和 profile 缓存。
- `data/storage/`：认证会话安全存储。
- `data/bridges/`：阿里云一键登录、Apple 登录、微信登录的 native bridge。
- `models/`：用户资料、认证 bundle、账号身份、偏好等 DTO。
- `presentation/`：登录流程、登录面板和认证入口页面。

## 关键入口

- `authControllerProvider`：全局登录态入口。
- `AuthLoginController`：登录页方法选择、验证码发送、第三方登录调起。
- `AuthSessionCoordinator`：会话恢复、刷新、完成登录和登出。
- `ProfileRepository`：用户资料、账号绑定和本地用户缓存。

## 依赖关系

`auth` 依赖 `core/network`、`core/storage`、`core/database` 和登录 native bridge。其他 feature 通常只读取 `authControllerProvider` 的会话状态或通过 settings 更新账号资料。
