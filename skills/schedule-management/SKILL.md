---
name: schedule-management
description: Ling 的日程管理能力，覆盖查询、创建、更新、完成、取消、重复日程、时间点提醒。
---
# 日程管理技能

所有 MCP 工具调用必须传 `user_id`。

## 范围

本 skill 只处理日程。随手想法、感悟、摘录、备忘、困惑、灵感和未成形计划不落库为想法；如果没有明确日期或时间边界，继续在聊天里保留为待确认计划。

出行相关任务里，本 skill 只负责日程落库和日历维护。复杂行程规划、路线顺序、交通取舍、天气备选和多点安排先交 `trip-planning`；等用户确认明确日期或时间边界后，再由本 skill 创建或更新日程。

如果 `trip-planning` 已经产出计划，本 skill 只接收已确定的标题、时间边界、地点、摘要和材料文件。简短行程摘要写入 metadata；详细攻略、报告或可分享文件通过 `preparation` 关联，不塞进 metadata。

## 协作 skill

- 内容还只是想法、备忘、待办线索或未定档计划，不满足日程条件时，不创建日程；简短说明需要具体日期或时间边界才能落日历。
- 用户要求 Ling 在未来持续复看、周期汇总、等待变化或条件命中提醒时，不要创建重复日程或隐藏安排；只能落成具体日程，或告知当前不支持持续跟踪。
- 用户要求路线顺序、交通取舍、天气备选、多点安排或完整出行方案时，用 `trip-planning` 先形成计划，本 skill 只负责确定后的日程落库。
- 创建或更新日程前需要确认地点、坐标、路线耗时或天气事实时，用 `location-services` 补齐事实。
- 日程内容需要生成报告、攻略、复盘或可分享文件时，用 `ling-report` 生成文件，再通过 preparation 关联到日程。

默认原则：
- 能从上下文安全推断的信息直接使用。
- 只在缺关键字段、候选不唯一、冲突或高风险歧义时确认。
- 不编造时间、地点、参与人或执行结果。

## 日程还是想法

创建日程需同时满足：
- 能解析到具体日历日。
- 能表达时间边界：明确钟点可做时间点提醒；明确时段或连续占用可做普通日程。
- 用户表达的是已定档安排，不是“先记着”。

不创建日程的情况：
- 只有「下周」「月底」「周末」等窗口，无法定到具体哪一天。
- 有截止期，但没有要在哪个时段去做。
- 用户说“先记着”“之后再定”，或只是愿望、备忘、感悟、摘录、困惑。
- 当前信息不够具体，继续追问会打断用户记录念头。
- 用户表达的是有后续价值但还不满足日程条件的待办线索、灵感或未成形计划；此时不要为了建日程追问到具体时间。

不适合建日程的持续跟踪情况：
- 用户要 Ling 在未来反复检查某件事，而不是把用户自己的时间占用放进日历。
- 用户要周期性复看下周事项、汇总外部信息，或等待票务、价格、页面、结果等变化。
- 这类需求当前不能用隐藏日程替代；可先保存为想法，或向用户说明持续跟踪能力已不可用。

截图、聊天记录、邀请卡片与文字同等处理：先提取时间、地点、人物和主题。能成日程就建日程；只是摘录、感悟、备忘或未成形计划就不创建日程。

如果输入里有 Ling 附件引用，尤其是 `【Ling 附件引用】` 中给出的 Markdown 图片或文件链接，创建或更新日程备注时保留对用户有用的引用；图片用 `![标题](file:///app/agents/.../upload_files/...)`，文件用 `[标题](file:///app/agents/.../upload_files/...)`。不要改成相对路径。

## 时间规则

`calendar_create_event` / `calendar_update_event` 使用 RFC 5545 `VEVENT`：
- 必须包含 `SUMMARY`、`DTSTART`。
- 普通日程包含 `DTEND`，且结束晚于开始。
- 时间点提醒只写 `DTSTART`，不要补假的 `DTEND`。
- 重复日程在同一个 `VEVENT` 里加 `RRULE`；普通单次日程不要写 `RRULE`。
- `DTSTART` / `DTEND` 使用 `TZID` 或 UTC `Z`，并必须带 `X-LING-WEEKDAY=MO|TU|WE|TH|FR|SA|SU`，如 `DTSTART;TZID=Asia/Shanghai;X-LING-WEEKDAY=TU:20260512T090000`。
- `X-LING-WEEKDAY` 必须和日期真实星期一致；如果后端返回星期不一致或缺失错误，先重新核对日期再重试。
- 可见备注、地点、链接、分类分别写 `DESCRIPTION`、`LOCATION`、`URL`、`CATEGORIES`。
- 创建或改期到已经过去的 `DTSTART` 默认会被拒绝；只有用户明确要补记、回填或记录已经发生的事时，才可用 `force=true`。

VEVENT 写法速记：
- 单点提醒：`SUMMARY + DTSTART`
- 普通日程：`SUMMARY + DTSTART + DTEND`
- 重复日程：普通日程基础上加 `RRULE`
- 修改单次重复 occurrence：`scope="occurrence"`，VEVENT 不写 `RRULE`
- 修改整个重复 series 的规则：`scope="series"`，需要变更规则时才写新的 `RRULE`

用户只给时段时，可用默认时段：

| 时段 | 默认时间 |
| --- | --- |
| 上午/早上 | 09:00-12:00 |
| 下午 | 13:00-18:00 |
| 晚上 | 18:00-21:00 |

单个明确钟点是时间点提醒，不用默认时段补结束时间。默认时段与已有日程冲突时，展示冲突并请用户指定具体时间。

当用户说“规划今天”“安排今天”时，今天只安排当前时间之后的可执行时间；不要把已经过去的上午、下午或晚上默认时段落成日程。如果默认时段起点已经过去，改用当前时间之后的合理时间段；不确定剩余时长时先询问。

遇到“周五”“下周三”“明晚”“周末”等相对日期时，先用命令行按用户时区确认日期与星期对应关系，再写 VEVENT。不要只凭心算换算日期。可用系统命令查询，例如：

```bash
TZ=Asia/Shanghai date '+%Y-%m-%d %A %z'
```

确认目标日期后，在 `DTSTART` 和普通日程的 `DTEND` 上写入对应 `X-LING-WEEKDAY`。时间点提醒没有 `DTEND`，只需要给 `DTSTART` 写 weekday。

## 多日与出行

同一趟出行、出差、旅行，默认用一条跨天日程表达整块占用：
- 起点：出发日 + 已知钟点；只知时段时取该时段起点。
- 终点：返程日 + 已知钟点；只知“某天回来”时取返程日下午段结束。
- 只有用户明确要求分段，或中间是无关事项，才拆多条。

若只是“某段时期想去某地、玩几天”，但没有明确出发日和返程日，不创建日程；请用户确认日期或继续由 `trip-planning` 做待确认草案。

若用户要求“怎么安排、怎么走、先去哪、天气不好怎么办、顺路做哪些事”，先转 `trip-planning`。本 skill 只在行程已经形成明确日历占用时接手落库。

## 工具

| 工具 | 用途 |
| --- | --- |
| `calendar_list_events` | 查询日程 |
| `calendar_create_event` | 创建普通日程、时间点提醒或重复日程 |
| `calendar_update_event` | 更新可见字段、时间形态、重复规则、备注或日程材料列表 |
| `calendar_complete_event` | 标记完成 |
| `calendar_delete_event` | 删除、取消、作废 |

## 创建

收集最小必要字段：标题 + 时间。


冲突时展示摘要并询问是否强制创建。过去时间只在用户明确要补记/回填时用 `force=true`，不要为了完成规划自动强制创建过去日程。

时间点提醒示例：

```text
BEGIN:VEVENT
SUMMARY:Call parents
DTSTART;TZID=Asia/Shanghai;X-LING-WEEKDAY=TU:20260512T200000
END:VEVENT
```

普通日程示例：

```text
BEGIN:VEVENT
SUMMARY:Morning sync
DTSTART;TZID=Asia/Shanghai;X-LING-WEEKDAY=TU:20260512T090000
DTEND;TZID=Asia/Shanghai;X-LING-WEEKDAY=TU:20260512T093000
END:VEVENT
```

重复日程示例：

```text
BEGIN:VEVENT
SUMMARY:Weekly standup
DTSTART;TZID=Asia/Shanghai;X-LING-WEEKDAY=TU:20260512T090000
DTEND;TZID=Asia/Shanghai;X-LING-WEEKDAY=TU:20260512T093000
RRULE:FREQ=WEEKLY;BYDAY=TU;COUNT=8
END:VEVENT
```

## 修改、完成、删除

必须先搜后改：
1. `calendar_list_events(query=...)` 搜索目标。
2. 命中 1 条且用户已明确授权，直接执行。
3. 命中 0 条，请用户补充关键词。
4. 命中多条，用日期+时间列出候选，请用户选择。
5. 禁止跳过搜索猜 `event_id`。

语义：
- “完成了 / 已经做了 / 结果是...” → `calendar_complete_event`
- “不去了 / 取消了 / 不用了 / 作废了 / 删掉” → `calendar_delete_event`
- 只是补备注、结论、参与人、标签 → `calendar_update_event` 只传 `metadata`
- 维护日程时需要记录材料文件 → `calendar_update_event` 只传 `preparation`

`metadata` 必须是完整 Markdown 字符串，不要传 JSON。metadata 更新只能整段覆盖 `metadata.markdown`，不会覆盖日程准备材料；如果要保留旧备注，先把旧内容纳入新的 Markdown。按需使用小标题，不要为了模板填空：

- `## 背景/原文`
- `## 关键信息`
- `## 判断与结论`
- `## 后续动作`
- `## 记录来源`

不适用的小节直接省略，不要写“无”。

`preparation` 只用于日程材料列表，传列表，不要塞进 Markdown；它不是每次修改日程都必须更新的字段。只有当你确实整理、生成或发现了对这个日程有用的材料时才写入；如果旧材料已不适合当前日程，传空列表清空：

```json
[
  {
    "title": "会议准备文档",
    "path": "/absolute/or/agent/file/path.md"
  }
]
```

重复日程：
- “整个系列 / 以后都这样” → `scope="series"`
- “只改这一次 / 这周这次” → `scope="occurrence"`，并传 `occurrence_start_time`
- `scope="occurrence"` 不能包含 `RRULE`

## 回复要点

- 成功：简短确认动作 + 标题 + 时间。
- 消歧：候选用日期+时间区分，一次问清。
