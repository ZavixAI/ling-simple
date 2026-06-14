# calendar

`calendar` 是 Ling 的日程业务模块，负责展示、编辑、同步用户的时间安排。

## 业务含义

这个模块把后端的 Ling event、月视图快照和本机 Apple 日历上下文组织成用户可浏览、可编辑、可同步的日程体验。

## 主要职责

- 管理当前选中日期、月份、时区、日事件列表和月视图快照。
- 编辑或删除 Ling 事件，支持单次 occurrence 和整个 series。
- 处理 Apple 日历权限、本机日历读取、Ling 事件镜像到 Apple 日历、Apple 导入事件回传后端。
- 管理外部日历连接，包括 OAuth start/complete、同步刷新和断开连接。
- 根据通知设置构建本地通知请求和 Apple Calendar alarm payload。

## 目录结构

- `application/`：`CalendarController`、`ScheduleSurfaceController`、事件动作、编辑表单支持、通知构建。
- `data/repositories/`：Ling 日历 API、外部日历连接 API、Apple 日历同步 API。
- `data/bridges/`：Apple Calendar、外部日历 OAuth、日历 App 打开器。
- `models/`：事件、日历集成、Apple 日历、编辑草稿、时间工具模型。
- `presentation/`：日程页、月/周视图、事件卡片、事件详情、编辑 sheet。

## 关键入口

- `calendarControllerProvider`：日期、月份和核心日历数据状态。
- `scheduleSurfaceControllerProvider`：日程面板窗口事件和编辑后刷新。
- `scheduleEventActionsProvider`：按来源区分 Ling 事件和 Apple 导入事件的更新/删除动作。
- `CalendarRepository`：`/calendar` 后端 API。
- `AppleCalendarSyncRepository`：Apple 日历链接和上下文上传。

## 依赖关系

`calendar` 依赖 `core/network`、`core/database`、`shared/i18n`、`shared/models/calendar_notification_models.dart` 和 Apple native bridge。设置页和应用壳层会调用本模块完成通知排程、连接管理和页面数据刷新。
