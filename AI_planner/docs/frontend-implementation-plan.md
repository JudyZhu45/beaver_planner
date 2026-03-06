# Beaver Planner — 前端实现方案 (Frontend Implementation Plan)

> **愿景**: 从"你告诉它做什么"到"它了解你并建议你"
> **范围**: 仅前端，不涉及后端改动
> **基于**: 现有 AI_planner 代码库

---

## 一、记忆能力 — 记住用户行为模式，越用越懂你

### 1.1 本地行为数据采集层

- [x] **创建 `UserBehaviorStore.swift` 服务**
  - 使用 UserDefaults / JSON 文件持久化用户行为数据
  - 定义 `BehaviorRecord` 模型：行为类型、时间戳、上下文信息
  - 行为类型包括：任务创建、任务完成、任务删除、任务延期、任务编辑、应用打开时间

- [x] **在 `TodoViewModel` 中埋点**
  - `addTodo` / `addEvent` 时记录：创建时间、事件类型、优先级、时间段选择
  - `toggleTodoCompletion` 时记录：计划时间 vs 实际完成时间、事件类型
  - `deleteTodo` 时记录：任务存活时长、是否曾被推迟
  - `updateTodo` 时记录：修改了哪些字段（时间？优先级？标题？）

- [x] **记录应用使用时间模式**
  - 在 `AI_plannerApp.swift` 中记录每次打开 App 的时间
  - 在 `ContentView.swift` 中记录 Tab 切换行为（哪些 Tab 最常用）
  - 记录每日首次打开时间和最后活跃时间

### 1.2 行为分析引擎

- [x] **创建 `BehaviorAnalyzer.swift` 服务**
  - 统计用户高频行为时间段（几点创建任务最多、几点完成任务最多）
  - 分析任务完成率按事件类型分布（学习完成率 vs 健身完成率）
  - 分析任务完成率按时间段分布（上午 vs 下午 vs 晚上）
  - 分析拖延模式：哪些类型的任务最容易被推迟或删除
  - 分析时间估算偏差：计划时长 vs 实际完成时长

- [x] **增强现有 `EnergyAnalysisService.swift`**
  - 整合行为数据，不再仅依赖 `completedAt` 时间戳
  - 加入"高效时段"分析（完成率最高的时段）
  - 加入"拖延高发时段"分析

### 1.3 用户画像模型

- [x] **创建 `UserProfile.swift` 模型**
  - `preferredWorkHours: ClosedRange<Int>` — 偏好工作时间段
  - `peakProductivityHours: [Int]` — 高效时间段
  - `taskTypePreferences: [EventType: TypeStats]` — 各类型任务统计
  - `averageTasksPerDay: Double` — 日均任务量
  - `completionRate: Double` — 总体完成率
  - `procrastinationPatterns: [ProcrastinationPattern]` — 拖延模式
  - `streakData: StreakInfo` — 连续打卡数据

- [x] **创建 `UserProfileViewModel.swift`**
  - 定期（每日/每周）基于 `BehaviorAnalyzer` 重新计算用户画像
  - 发布用户画像变化通知供 UI 消费

---

## 二、智能推荐 — 基于历史数据推荐最佳执行时间

### 2.1 时间推荐引擎

- [x] **创建 `TimeRecommendationEngine.swift` 服务**
  - 输入：事件类型 + 预计时长 + 日期
  - 输出：推荐时间段列表（排序后），每个附带推荐理由
  - 推荐逻辑：
    1. 查询该日已有事件，排除冲突时段
    2. 根据 `UserProfile.peakProductivityHours` 优先推荐高效时段
    3. 根据事件类型历史完成率推荐该类型最佳时段
    4. 避开用户历史拖延高发时段
  - 定义 `TimeRecommendation` 模型：
    ```
    - timeSlot: DateInterval
    - confidence: Double (0-1)
    - reason: String (推荐理由，中文)
    - conflictWarning: String? (冲突提醒)
    ```

### 2.2 AddEventSheet 时间推荐 UI

- [x] **改造 `AddEventSheet.swift`**
  - 选择事件类型后，自动显示"推荐时间"区域
  - 展示 2-3 个推荐时间卡片，显示：
    - 推荐时间段（如 "09:00 - 10:30"）
    - 推荐理由（如 "这是你学习效率最高的时段"）
    - 置信度指示器（圆环或进度条）
  - 点击推荐卡片自动填充开始/结束时间
  - 如果用户选择非推荐时间，温和提示（不强制）

### 2.3 AI 聊天中的推荐集成

- [x] **增强 `ChatService.swift` 系统提示**
  - 将用户画像摘要注入 system prompt
  - 包含：高效时段、各类型完成率、拖延模式
  - 让 AI 在规划日程时参考这些数据
  - 示例 prompt 片段：
    ```
    用户画像：
    - 高效时段：9:00-11:00, 14:00-16:00
    - 学习任务最佳时段：上午（完成率 85%）
    - 健身任务最佳时段：17:00-19:00（完成率 72%）
    - 用户倾向于在晚上 22:00 后创建明日计划
    ```

---

## 三、渐进式学习 — 从被动记录到主动建议

### 3.1 洞察卡片系统

- [x] **创建 `InsightCard.swift` 模型**
  - `InsightType` 枚举：
    - `.completionMilestone` — 完成里程碑（"你已连续完成 7 天任务！"）
    - `.productivityTrend` — 效率趋势（"本周完成率比上周提高了 15%"）
    - `.timeRecommendation` — 时间建议（"你上午学习效率最高，建议把学习任务安排在 9-11 点"）
    - `.procrastinationAlert` — 拖延提醒（"你有 3 个健身任务已延期超过 2 天"）
    - `.patternDiscovery` — 模式发现（"你最近的晚餐安排都在 18:30，要固定这个时间吗？"）
    - `.weeklyReview` — 周报（"本周完成 23 个任务，比上周多 5 个"）

- [x] **创建 `InsightGenerator.swift` 服务**
  - 基于 `BehaviorAnalyzer` 和 `UserProfile` 生成洞察
  - 洞察触发条件：
    - 每日首次打开 App 时生成当日洞察
    - 连续 N 天完成率 > 80% 时触发里程碑
    - 某类型任务连续 3 次延期时触发拖延提醒
    - 每周日/一生成周报
  - 洞察去重：相同类型洞察 N 天内不重复
  - 洞察优先级排序：里程碑 > 拖延提醒 > 效率趋势 > 模式发现

### 3.2 TodayView 洞察展示

- [x] **在 `TodayView.swift` 添加洞察卡片区域**
  - 位于日期标题下方、任务列表上方
  - 横向滑动的洞察卡片列表（最多 3 张）
  - 卡片 UI：
    - 图标 + 标题 + 描述
    - 颜色编码（绿=正面、橙=提醒、蓝=信息）
    - 可点击展开详细信息
    - 左滑关闭（记录用户是否关注该类型洞察）
  - 无洞察时不显示该区域

### 3.3 主动建议通知

- [x] **增强 `NotificationManager.swift`**
  - 新增"智能建议"通知类别
  - 早间建议通知（基于用户首次打开时间 -5 分钟）：
    - "今天有 5 个任务，建议先完成上午的学习任务"
  - 拖延提醒通知：
    - "你的'跑步'任务已延期 2 天，今天要完成吗？"
  - 效率提醒：
    - "现在是你的高效时段，适合处理重要任务"
  - 通知频率控制：每日最多 3 条建议通知

---

## 四、温度感 — 有性格的管家，不是冷冰冰的数据库

### 4.1 河狸管家人设系统

- [x] **创建 `BeaverPersonality.swift`**
  - 定义河狸管家的语气和性格特征
  - 根据用户完成情况动态调整语气：
    - 完成率高时：鼓励型（"太棒了！今天效率爆棚 🦫"）
    - 完成率低时：温和关怀型（"今天辛苦了，明天从最简单的开始吧"）
    - 连续多天没打开时：轻松召回型（"好久不见！有什么我能帮你规划的吗？"）
  - 定义 `BeaverMood` 枚举：
    - `.cheerful` — 开心（用户表现好）
    - `.encouraging` — 鼓励（用户有进步）
    - `.caring` — 关怀（用户遇到困难）
    - `.playful` — 俏皮（日常互动）
    - `.proud` — 骄傲（达成里程碑）

### 4.2 增强 AI 聊天人设

- [x] **改造 `ChatService.swift` 系统提示**
  - 加入河狸管家人设描述
  - 动态注入当前 mood 和上下文
  - 示例 prompt 补充：
    ```
    你是"小河狸"，一个温暖、有条理的日程管家。
    你说话简洁友善，偶尔用 🦫 表情。
    当前心情：开心（用户今天完成了 5 个任务）。
    你了解用户习惯：喜欢上午学习、下午运动。
    ```

### 4.3 动态问候与状态展示

- [x] **改造 `TodayView.swift` 顶部问候区**
  - 根据时间段显示不同问候：
    - 早上 6-12："早上好！今天有 N 个任务等着你 🦫"
    - 下午 12-18："下午好！还剩 N 个任务"
    - 晚上 18-24："晚上好！今天完成了 N%"
  - 根据完成进度动态调整语气
  - 河狸表情/动画根据 mood 变化（开心、加油、睡觉）

- [x] **改造 `ProfileView.swift` 统计展示**
  - 统计数据配合河狸管家点评
  - 如："本周完成率 92%！小河狸为你骄傲 🦫"
  - 能量曲线图增加河狸人设解读

### 4.4 成就与激励系统

- [x] **创建 `AchievementSystem.swift`**
  - 定义成就列表：
    - 🌱 "初次播种" — 创建第一个任务
    - 🔥 "连续 7 天" — 连续 7 天完成所有任务
    - 📚 "学霸养成" — 完成 50 个学习任务
    - 🏃 "运动达人" — 完成 30 个健身任务
    - ⚡ "效率之王" — 单日完成 10 个任务
    - 🦫 "河狸之友" — 使用 App 30 天
  - 成就解锁时显示庆祝动画（复用 `CompletionParticleEffect`）
  - 使用 UserDefaults 持久化已解锁成就

- [x] **在 `ProfileView.swift` 添加成就展示区**
  - 成就徽章网格（已解锁高亮、未解锁灰色）
  - 点击查看成就详情和解锁条件
  - 显示下一个即将解锁的成就及进度

---

## 五、UI/UX 增强

### 5.1 每周回顾视图

- [x] **创建 `WeeklyReviewView.swift`**
  - 每周日/一弹出展示
  - 内容：
    - 本周完成任务数 vs 上周
    - 完成率趋势折线图
    - 各事件类型完成分布饼图
    - 高效时段分析
    - 河狸管家总结点评
  - 可从 ProfileView 手动查看历史周报

### 5.2 智能空状态

- [x] **增强 `EmptyStateView.swift`**
  - 根据时间和用户历史显示不同空状态内容：
    - 新用户："让小河狸帮你规划第一个任务吧！"
    - 老用户清空日程："今天没有安排，要不要让我帮你规划？"
    - 全部完成："太厉害了！今天的任务全部完成 🎉"
  - 空状态中的快速操作按钮

### 5.3 习惯追踪可视化

- [x] **创建 `HabitHeatmapView.swift` 组件**
  - GitHub 风格的日历热力图
  - 颜色深浅表示每日完成任务数量
  - 显示在 ProfileView 中
  - 支持按事件类型筛选

---

## 六、实现优先级与阶段规划

### Phase 1 — 数据基础（最先做）
1. `UserBehaviorStore.swift` — 行为数据采集
2. `TodoViewModel` 埋点 — 开始收集数据
3. `BehaviorAnalyzer.swift` — 基础分析能力

### Phase 2 — 智能推荐（核心功能）
4. `UserProfile.swift` — 用户画像模型
5. `TimeRecommendationEngine.swift` — 时间推荐
6. `AddEventSheet` 推荐 UI — 用户可见的推荐
7. `ChatService` prompt 增强 — AI 感知用户偏好

### Phase 3 — 主动建议（差异化功能）
8. `InsightCard` + `InsightGenerator` — 洞察系统
9. `TodayView` 洞察展示 — 前端展示
10. `NotificationManager` 增强 — 智能通知

### Phase 4 — 温度感（体验提升）
11. `BeaverPersonality.swift` — 人设系统
12. `ChatService` 人设注入 — AI 性格
13. `TodayView` 动态问候 — 界面温度感
14. `AchievementSystem.swift` — 成就系统
15. `ProfileView` 成就展示 — 激励可视化

### Phase 5 — 体验完善
16. `WeeklyReviewView.swift` — 每周回顾
17. `HabitHeatmapView.swift` — 习惯热力图
18. `EmptyStateView` 增强 — 智能空状态
19. `ProfileView` 统计增强 — 河狸管家点评

---

## 七、技术约束与注意事项

- **数据持久化**: 所有行为数据使用 UserDefaults + JSON 文件本地存储，不依赖后端
- **性能**: 行为分析在后台线程执行，避免阻塞 UI
- **隐私**: 所有数据仅存储在本地设备上
- **渐进体验**: 数据不足时优雅降级（不显示推荐，而非显示低质量推荐）
- **架构**: 遵循现有 MVVM 架构，新服务放在 `Services/`，新模型放在 `Models/`
- **设计**: 遵循现有 `AppTheme` 设计系统，新组件使用统一的颜色、间距、圆角
- **语言**: UI 文案使用中文，代码使用英文命名
