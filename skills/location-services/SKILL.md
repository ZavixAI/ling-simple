---
name: location-services
description: Ling 的地图与位置服务能力，覆盖地址解析、逆地理编码、POI 文本/周边搜索、路线规划和天气查询的工具选择、参数准备、结果解读与降级策略。
---
# 地图与位置服务技能

所有 MCP 工具调用必须传 `user_id`。本 skill 是支撑 skill，负责选择和组合地图与位置相关工具，不负责制定完整旅行计划。

本 skill 主责是地点、坐标、POI、路线、天气等事实查询，不负责完整行程编排或日程落库。

## 协作 skill

当位置事实只是更大任务的一部分时，先把地点、坐标、路线或天气查清楚，再把结果交给对应任务继续完成：多日/多点/取舍规划交给 `trip-planning`，明确要放日历交给 `schedule-management`，需要形成正式攻略或路线报告交给 `ling-report`。

## 适用范围

当用户需要地点、地址、路线、天气、附近搜索、目的地对比或位置相关事实时，使用本 skill。

典型任务：
- 把地址转坐标，或把坐标转可读地址。
- 搜索某个地点、附近地点或区域内 POI。
- 规划两点之间驾车、步行、骑行、电动车或公交路线。
- 查询某个行政区的实时天气或天气预报。

## 工具选择

| 工具 | 用途 |
| --- | --- |
| `location_geocode_address` | 地址、店名、景点名转经纬度候选 |
| `location_reverse_geocode` | 经纬度转地址、区县、附近 POI |
| `location_search_poi` | 文本或周边维度搜索 POI |
| `location_route_plan` | 两点之间路线规划 |
| `location_weather_query` | 按 adcode 查询实时天气或预报 |

## 使用顺序

地址和路线：
1. 用户给的是地址或地点名，先用 `location_geocode_address` 或 `location_search_poi(search_type="text")` 找候选。
2. 候选唯一且可信时，取坐标进入下一步。
3. 候选不唯一时，用名称、区域、距离或用户上下文消歧；仍不确定就问用户。
4. 路线规划必须给 `location_route_plan` 传 `longitude,latitude` 坐标，不要直接传自然语言地址。
5. 公共交通路线还需要提供起终点城市编码：`origin_city` 和 `destination_city`；优先从地址解析或 POI 候选里的 citycode 取值，不要传城市名称。
6. 路线规划只用于判断距离、耗时、费用和方案取舍；不要为普通路线问题请求逐步导航、路线几何或路口级细节字段。

附近搜索：
- 已有坐标时，用 `location_search_poi(search_type="around", location="lng,lat")`。
- 用户只说“附近”但没有当前位置，先看上下文是否有设备位置或明确地点；没有就询问位置。
- 半径缺省可用 1000 米；餐饮、咖啡、便利店等步行场景优先 500-1500 米。

区域搜索：
- 城市或行政区文本检索用 `search_type="text"` + `region`。
- 需要严格限制区域时设置 `city_limit=true`。
- 需要更多字段时设置 `show_fields`，只请求当前任务需要的字段。

天气：
- `location_weather_query(extensions="base")` 查实时天气。
- `extensions="all"` 查预报。
- 只有地址没有 adcode 时，先通过地址解析、POI 或逆地理拿行政区信息；拿不到时询问或说明无法精确查询。

## 结果处理

- 位置服务返回多个候选时，不要把第一条当成确定答案；优先结合城市、距离、类型和用户原话判断。
- 对用户展示地点名称、地址、距离、耗时、天气等有用摘要，不展示原始 JSON。
- 路线结果里如果有多方案，优先概括最短时间、较少换乘或更符合用户偏好的方案。
- 工具失败、无结果或结果冲突时，说明限制并给出下一步需要的信息。

## 边界

- 不编造经纬度、adcode、POI ID、营业状态、路线耗时或天气。
- 不把坐标传给 `location_geocode_address`；坐标反查用 `location_reverse_geocode`。
- 不把自然语言地址直接传给 `location_route_plan`；先转坐标。
