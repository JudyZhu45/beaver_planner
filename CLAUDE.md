# Beaver Planner - Project Memory

## Project Overview
iOS task management app with AI chat assistant. "Beaver Planner" theme — warm, natural design language.

**Tech Stack:** Swift, SwiftUI (iOS 17+), AWS Amplify (Cognito auth), Kimi/Moonshot LLM API (SSE streaming), UserDefaults persistence (no backend DB).

## Architecture

### App Launch Flow
```
AI_plannerApp.swift
  → authManager.isLoading → Splash screen
  → !authManager.isSignedIn → LoginView
  → isSignedIn && !hasCompletedOnboarding → OnboardingView
  → isSignedIn && hasCompletedOnboarding → ContentView (4 tabs)
```

### Tab Structure (ContentView.swift)
- Tab 0: **TodayView** — Today's schedule + todo list with inline add buttons
- Tab 1: **CalendarView** → MindfulCalendarView — Monthly calendar with day detail
- Tab 2: **AIChatView** — Streaming chat with LLM, supports task CRUD via [ACTION] blocks
- Tab 3: **ProfileView** — Stats, achievements, energy curve, settings (wrapped in NavigationStack)

### Data Model (TodoModel.swift)
```swift
TodoTask {
    id, title, description, isCompleted, dueDate,
    startTime: Date?,    // nil = unscheduled todo
    endTime: Date?,      // nil = unscheduled todo
    priority: TaskPriority (.low/.medium/.high),
    eventType: EventType (.gym/.class_/.study/.meeting/.dinner/.other),
    calendarEventId: String?,
    completedAt: Date?
}
```
- **Scheduled event**: has both startTime + endTime → displayed as ScheduleCard
- **Unscheduled todo**: startTime == nil → displayed as TodoChecklistItem

### Key Services
| File | Purpose |
|------|---------|
| `AuthManager.swift` | @Observable, AWS Cognito auth (sign in/up/out, email verify) |
| `ChatService.swift` | AI chat orchestration: system prompt build, SSE streaming, [ACTION] parsing, undo support |
| `AIAPIService.swift` | Low-level AI API calls (GPT-4o / Kimi) with SSE |
| `ChatMemoryStore.swift` | Persistent user preference storage (structured + chat-extracted), injected into AI system prompt |
| `BehaviorAnalyzer.swift` | Analyzes task completion patterns, productive hours, trends |
| `UserBehaviorStore.swift` | Raw behavior event logging (app opens, tab switches, task actions) |
| `BeaverPersonality.swift` | Dynamic beaver commentary based on stats |
| `AchievementSystem.swift` | Gamification achievements tracking |
| `EnergyAnalysisService.swift` | Hourly productivity analysis from task data |
| `InsightGenerator.swift` | Generates insight cards for TodayView |
| `TimeRecommendationEngine.swift` | Smart time slot suggestions |
| `CalendarSyncService.swift` | iOS Calendar (EventKit) sync |
| `NotificationManager.swift` | Local push notifications |

### AI Chat System
- **System prompt** rebuilt every API call with: current tasks (segmented overdue/this-week/future), user behavior profile, structured preferences, chat memory
- **[ACTION] blocks**: AI embeds JSON actions in response (`create_task`, `update_task`, `delete_task`, `complete_task`, `propose_plan`)
- **Two-phase confirm**: AI proposes → user confirms → actions execute
- **Undo**: Each action stores previous state snapshot for one-tap reversal
- **Memory pipeline**: `OnboardingView / UserPreferencesView → ChatMemoryStore.structuredPreferences` + `Chat conversations → ChatMemoryStore.extractPreferences()` → both merged in `generateMemorySummary()` → injected into system prompt

### User Preferences System
Three sources feed into AI context:
1. **Onboarding** (first launch) — wake time, work hours, lunch break, task types, duration preference, weekend style, constraints
2. **Manual editing** — UserPreferencesView accessible from Profile → Settings → "My Preferences"
3. **Chat extraction** — ChatMemoryStore auto-extracts preferences from conversation patterns

All stored via `ChatMemoryStore` (UserDefaults), merged into `generateMemorySummary()` for system prompt.

## Design System (AppTheme.swift)
- **Primary**: Beaver Brown `#7D512D` (primaryDeepIndigo)
- **Secondary**: Moss Green `#619D7A` (secondaryTeal)
- **Accent**: Autumn Orange `#DD6F57` (accentCoral)
- **Backgrounds**: Cream `#F7F4EE` (bgPrimary), Warm White `#FEFDFB` (bgSecondary)
- **Typography**: `.rounded` design, 12 scale levels (displayLarge 32pt → labelSmall 10pt)
- **Spacing**: xs=4, sm=8, md=12, lg=16, xl=20, xxl=24, xxxl=32, huge=48
- **Radius**: xs=4, sm=8, md=12, lg=16, xl=20, full=infinity
- **Event colors**: 6 types with light/primary/dark variants (Gym=terracotta, Class=lake blue, Study=forest green, Meeting=honey, Dinner=coral, Other=warm gray)

## Component Library
| Component | Purpose |
|-----------|---------|
| `ScheduleCard` | Timed event card with duration, type color |
| `TodoChecklistItem` | Unscheduled todo with checkbox, supports onToggle/onDelete/onEdit |
| `CheckboxButton` | Animated checkbox with haptic + beaver celebration |
| `SectionHeader` | Section title with icon |
| `MessageBubble` | Chat message bubble (user/AI) |
| `TypingIndicator` | AI typing animation |
| `EmptyStateView` | Empty state with type enum (.tasks/.calendar/.analytics/.notifications) |
| `FilterButton` | Pill-shaped filter toggle |
| `CustomTabBar` | 4-tab bottom bar |
| `AuthFormField/AuthPrimaryButton` | Auth screen components |
| `EnergyCurveView` | Hourly productivity chart |
| `HabitHeatmapView` | GitHub-style 12-week activity heatmap |
| `ToastView` | Toast notification overlay |
| `LoadingScreen` | Animated launch screen |
| `CelebrationView` | Task completion celebration |

## Key Patterns & Conventions
- **State**: `@Observable` for AuthManager, `@StateObject`/`@ObservedObject` for ViewModels, `@State` for local view state
- **Persistence**: All UserDefaults + JSON encoding (no CoreData/backend)
- **No Combine**: Prefer async/await over Combine publishers
- **SwiftUI List**: Used in TodayView for swipeActions support; `.listStyle(.plain)`, `.scrollContentBackground(.hidden)`
- **Sheets**: `.sheet(isPresented:)` for new items, `.sheet(item:)` for editing existing items
- **Delete pattern**: Confirmation dialog → delete → Toast with undo callback

## Recent Decisions
- **No floating action button (FAB)**: Removed in favor of inline "+ Add Event" and "+ Add To Do" buttons at the bottom of their respective sections in TodayView
- **Onboarding gate**: First-launch onboarding collects user preferences before showing main app
- **Preference reset**: UserPreferencesView has "Reset All Preferences" that clears ChatMemoryStore and re-triggers onboarding
