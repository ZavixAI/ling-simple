# ling

这是仓库里的跨平台前端应用，使用 Flutter 编写，当前已经补齐：

- iOS / Web 标准 Flutter 平台壳
- `lib/src` 分层业务结构与 Riverpod 状态管理
- 基于 `http` 的网络层
- Agent 会话、日历、登录、设置等核心前端模块
- HarmonyOS 接入预留目录与说明

架构入口可以先从下面这条链路理解：

`main.dart` -> `bootstrap/` -> `ProviderScope` -> `app/` -> `features/*`

更完整的开发与架构说明请查看 [`docs/跨平台开发说明.md`](../docs/跨平台开发说明.md) 中的“前端架构说明”章节。

## 目录结构约定

`lib/src` 目录按“应用装配 + 基础设施 + feature”组织：

- `app/`
  - 应用层装配入口
  - 放应用级 provider 组合、App widget、全局启动编排
- `bootstrap/`
  - Flutter 启动初始化
- `core/`
  - 与具体业务无关的基础设施
  - 例如网络、数据库、平台能力、存储、主题、日志
- `shared/`
  - 可被多个 feature 复用的通用 UI、i18n、共享展示组件
- `features/<feature>/`
  - 业务模块主目录
  - 默认按 `application/`、`data/`、`models/`、`presentation/` 分层

推荐目录示例：

```text
lib/src/features/
  auth/
    application/
    data/
    models/
    presentation/
  calendar/
    application/
    data/
    models/
    presentation/
```

## 文件命名规则

### 目录命名

- feature 目录使用业务语义命名，如 `auth`、`calendar`、`chat`
- 分层目录固定使用：
  - `application`
  - `data`
  - `models`
  - `presentation`
- `data` 下推荐子目录：
  - `bridges`
  - `repositories`
  - `storage`
- `presentation` 下按需要细分：
  - `mappers`
  - `view_models`

默认不要继续细分 `presentation/views`、`presentation/widgets`、`presentation/sheets` 这类子目录。
除 `mappers/` 外，优先直接放在 `presentation/` 根层，避免过度拆分。

### 文件命名

- 页面级入口统一使用 `*_page.dart`
- 页面中的主片段统一使用 `*_section.dart`
- 底部弹层统一使用 `*_sheet.dart`
- 页面骨架容器可使用 `*_surface.dart`
- 布局壳层可使用 `*_shell.dart`
- 特定业务面板可使用 `*_panel.dart`
- 小型可复用组件优先使用明确语义名，或 `*_widget.dart`
- 状态文件统一使用 `*_state.dart`
- 控制器统一使用 `*_controller.dart`
- 编排类统一使用 `*_orchestrator.dart`
- 策略类或规则函数统一使用 `*_policy.dart`
- 数据访问统一使用 `*_repository.dart`
- 平台桥接统一使用 `*_bridge.dart`
- 映射/转换统一使用 `*_mapper.dart`
- 文案格式化统一使用 `*_formatter.dart`
- 本地化错误转换统一使用 `*_localizer.dart`
- 交互回调集合统一使用 `*_callbacks.dart`
- 展示层数据模型统一使用 `*_view_models.dart`
- 业务模型文件放在 `models/` 目录，文件名需要表达领域语义，例如：
  - `user_models.dart`
  - `calendar_models.dart`
  - `membership_models.dart`

### 禁止项

- 不再新增 `features/models`、`features/repositories`、`features/services` 这类横向公共目录
- 不再新增 `features/providers.dart` 这类伪 feature 公共装配文件
- 不再使用模糊命名文件：
  - `helpers.dart`
  - `logic.dart`
  - `types.dart`
  - `widgets.dart`
- 非代码生成场景禁止使用 `part` 拆业务文件
- 一个文件只承载一个主要职责，避免“巨型桶文件”

## 分层职责约定

- `application/`
  - 放 controller、state、orchestrator、feature 内业务编排
- `data/`
  - 放 repository、bridge、store、远端/本地数据读写
- `models/`
  - 放当前 feature 自有的业务模型
- `presentation/`
  - 放 page、section、sheet、widget、展示 mapper、view model

依赖方向必须保持单向：

`presentation -> application -> data/models -> core`

补充规则：

- `presentation` 不直接拼装底层基础设施
- `core` 不依赖任何具体 feature
- `shared` 不承载 feature 业务状态
- 应用级 provider 组合统一放 `lib/src/app/`

## 开发规约

### 新增代码

- 新功能优先放入已有 feature，只有明确的新业务边界才新增 feature
- 新文件必须先判断所属层级，再决定目录
- import 必须使用新路径，禁止引用已废弃横向目录
- 公共能力先判断是否属于 `core`，其次才考虑 `shared`

### 修改代码

- 修改功能时优先维持现有 feature 边界，不把代码再次抽回横向公共目录
- 避免在 `presentation` 中堆积网络、存储、平台调用细节
- 如果文件超过约 500 行，应主动拆分
- 如果文件名无法准确描述职责，应同步重命名

### 前端视觉与组件准则

- 新增或调整前端 UI 时，优先使用 `liquid_glass_widgets` 提供的 `Glass*` 组件实现 iOS 26 Liquid Glass 风格。
- 只有在 `liquid_glass_widgets` 没有等价能力、且确实需要底层 shader/渲染能力时，才使用 `flutter_liquid_glass_plus` 作为补充。
- 不要重新引入自写 glass fallback、Material/Cupertino 双分支样式，或绕过 `LingGlass*` / `Glass*` 的自定义磨砂面板。
- 浅色和深色模式保持黑白主色调；不要主动新增副标题、字段描述或解释性 UI 文案，除非需求明确要求。

### Provider 约定

- 应用级组合 provider 放在 `lib/src/app/feature_providers.dart`
- feature 内部 provider 优先放在本 feature 的 `application/` 或独立 provider 文件中
- 不要把多个 feature 的 provider 再汇总到 `features/` 根目录

### 测试与守卫

- 提交前至少运行 `flutter analyze`
- 涉及结构调整时，优先补充对应 feature 的单测或 smoke test
- 不允许重新引入以下 import：
  - `package:ling/src/features/models/...`
  - `package:ling/src/features/repositories/...`
  - `package:ling/src/features/services/...`
  - `package:ling/src/features/providers.dart`

### 迁移目标

- feature 目录结构保持一致
- 非生成代码文件尽量控制在 300 到 400 行
- 超过 500 行的文件应视为待拆分对象
- 业务文件不使用 `part`

## 相关开发 Skill

https://github.com/flutter/skills
https://github.com/MiniMax-AI/skills

### 鸿蒙开发
https://github.com/openharmonyinsight/openharmony-skills


### ios开发
npx skills add https://github.com/twostraws/swift-concurrency-agent-skill --skill swift-concurrency-pro
npx skills add https://github.com/twostraws/swiftui-agent-skill --skill swiftui-pro