# shared

`shared` 保存跨业务模块复用的 UI、文案、本地化和轻量业务值对象。它比 `core` 更接近产品表达，但不应该拥有完整业务流程。

## 业务含义

这个模块承载 Ling 多个页面都会使用的共同语言和交互素材，例如中英文文案、语言解析、通知格式化、附件模型、字号偏好、国家区号、通用控件和滑动返回。

## 主要职责

- `i18n/`：语言代码解析、支持语言列表、`LingStrings` 文案集合，以及日历通知文本格式化。
- `models/`：多个 feature 共享的轻量模型，例如附件、日历通知设置、字号偏好、手机号国家区号。
- `presentation/`：通用 UI 控件、提示、合法文档、触感反馈、适配式控件、边缘滑动返回和 surface group。

## 关键入口

- `LingStrings`：按当前 locale 取业务文案。
- `CalendarNotificationSettings`：日历通知设置模型，在 settings、calendar、app 中复用。
- `LingFontSizeLevel`：字号偏好模型。
- `showLingNotice`、`showLingAdaptiveConfirmationDialog` 等通用交互工具。

## 依赖边界

`shared` 可以表达可复用的展示和轻量模型，但不应直接访问后端、不应维护用户会话状态，也不应包含只服务单一 feature 的复杂业务规则。
