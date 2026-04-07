# Home Screen Codex Handoff

This file is the handoff package for rebuilding the AiQo home screen inside another iOS SwiftUI project.

## Source of truth in this project

- `AiQo/App/MainTabRouter.swift`
- `AiQo/App/MainTabScreen.swift`
- `AiQo/Features/Home/HomeView.swift`
- `AiQo/Features/Home/HomeViewModel.swift`
- `AiQo/Features/Home/MetricKind.swift`
- `AiQo/Features/Home/HomeStatCard.swift`
- `AiQo/Features/Home/WaterDetailSheetView.swift`
- `AiQo/Features/Home/DailyAuraView.swift`
- `AiQo/Features/Home/VibeControlSheet.swift`
- `AiQo/Services/Permissions/HealthKit/TodaySummary.swift`

## Required architecture

Create or adapt these files in the target project:

- `App/MainTabRouter.swift`
- `App/MainTabScreen.swift`
- `Features/Home/HomeView.swift`
- `Features/Home/HomeViewModel.swift`
- `Features/Home/MetricKind.swift`
- `Features/Home/HomeStatCard.swift`
- `Features/Home/WaterDetailSheetView.swift`
- `Features/Home/DailyAuraView.swift`
- `Features/Home/VibeControlSheet.swift`
- `Services/Permissions/HealthKit/TodaySummary.swift`

If the target project already has equivalents, merge into the existing structure instead of duplicating files.

## Required routing behavior

- `HomeView` is the default selected tab.
- Keep `MainTabRouter.Tab.kitchen` in the enum even if Kitchen is not rendered as a normal tab page.
- When `navigate(to: .kitchen)` is called:
  - force `selectedTab = .home`
  - post `Notification.Name.openKitchenFromHome`
  - `HomeView` must listen to that notification and present the Kitchen sheet
- `MainTabScreen` must embed `HomeView()` inside `NavigationStack`.

## Required home screen layout

The screen is vertically stacked in this order:

1. Header
2. `DailyAuraView`
3. 2-column metric grid
4. Bottom kitchen shortcut section

### Header

- Left button opens `VibeControlSheet`
- Right button opens `ProfileScreen`
- Left button uses the custom asset name `vibe_ icon`
- Fallback vibe asset name: `vibe_icon`

### Main metrics grid

Show 6 cards in 3 rows, 2 cards per row:

- steps
- calories
- stand
- water
- sleep
- distance

Card tint mapping:

- `steps`: `mint`
- `calories`: `mint`
- `stand`: `sand`
- `water`: `sand`
- `sleep`: `mint`
- `distance`: `mint`

### Card behavior

- Tapping `water` opens `WaterDetailSheetView`
- Tapping any other metric opens `MetricDetailSheet`
- `MetricDetailSheet` must support scopes:
  - day
  - week
  - month
  - year
  - allTime

### Bottom kitchen shortcut

- Use the custom asset `Kitchenـicon`
- Fallback kitchen asset name: `Kitchen icon`
- Tapping it opens Kitchen as a sheet from the home screen
- Show the localized title under the icon

## Required state and models

### TodaySummary

Use this exact shape:

```swift
struct TodaySummary: Sendable {
    let steps: Double
    let activeKcal: Double
    let standPercent: Double
    let waterML: Double
    let sleepHours: Double
    let distanceMeters: Double
}
```

### MetricKind

Use these cases:

```swift
enum MetricKind {
    case steps, calories, stand, water, sleep, distance
}
```

Provide for each metric:

- localized title
- display unit
- SF Symbol name

### HomeViewModel

The view model must handle:

- loading today's health summary
- mapping health data to display card values
- a 60-second live refresh timer
- refresh on app becoming active
- navigation state:
  - `activeDestination`
  - `activeDetailMetric`
- chart state:
  - `chartData`
  - `selectedScope`
- water logging through `addWater(liters:)`

## Core code signatures to preserve

### MainTabRouter

```swift
@MainActor
final class MainTabRouter: ObservableObject {
    static let shared = MainTabRouter()

    enum Tab: Int {
        case home = 0
        case gym = 1
        case tribe = 2
        case kitchen = 3
        case captain = 4
    }

    @Published var selectedTab: Tab = .home

    private init() {}

    func navigate(to tab: Tab) {
        if tab == .kitchen {
            selectedTab = .home
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openKitchenFromHome, object: nil)
            }
            return
        }

        selectedTab = tab
    }
}

extension Notification.Name {
    static let openKitchenFromHome = Notification.Name("aiqo.openKitchenFromHome")
}
```

### HomeDestination

```swift
enum HomeDestination: Identifiable, Equatable, Sendable {
    case profile
    case tribe
    case kitchen
    case waterDetail
    case metricDetail(MetricKind)

    var id: String {
        switch self {
        case .profile: return "profile"
        case .tribe: return "tribe"
        case .kitchen: return "kitchen"
        case .waterDetail: return "waterDetail"
        case .metricDetail(let kind): return "metricDetail_\(kind.id)"
        }
    }
}
```

### gridRows helper

```swift
var gridRows: [[MetricCardData]] {
    stride(from: 0, to: metricCards.count, by: 2).map { index in
        Array(metricCards[index..<min(index + 2, metricCards.count)])
    }
}
```

### Kitchen icon resolution

```swift
private let preferredKitchenIconName = "Kitchenـicon"
private let fallbackKitchenIconName = "Kitchen icon"

private var kitchenIconName: String {
    UIImage(named: preferredKitchenIconName) != nil ? preferredKitchenIconName : fallbackKitchenIconName
}
```

### My Vibe icon resolution

```swift
private let preferredVibeIconName = "vibe_ icon"
private let fallbackVibeIconName = "vibe_icon"
```

## Exact behavior to preserve

- `HomeView` owns:
  - `@StateObject private var viewModel = HomeViewModel()`
  - `@StateObject private var dailyAuraViewModel = DailyAuraViewModel()`
  - `@StateObject private var vibeControlViewModel = VibeControlViewModel()`
- `HomeView` syncs `TodaySummary` into `DailyAuraViewModel` when summary changes
- `HomeView` keeps a local `waterSheetLiters` binding for `WaterDetailSheetView`
- `HomeView` refreshes when `scenePhase` becomes `.active`
- `HomeViewModel` arranges cards in rows of 2 using `gridRows`

## Asset assumptions for the target project

These assets already exist in the new project with the same names:

- `Kitchenـicon`
- `vibe_ icon`

Do not replace them with SF Symbols unless the asset lookup fails.

## Dependency rules for the target project

If these types do not already exist in the target project, create lightweight placeholders with the same API so the screen builds first:

- `ProfileScreen`
- `KitchenScreen`
- `KitchenViewModel`
- `LocalMealsRepository`
- `KitchenPersistenceStore`
- `DailyAuraView`
- `DailyAuraViewModel`
- `VibeControlSheet`
- `VibeControlViewModel`
- `FloatingProfileButton`
- `WaterBottleView`
- `HealthKitService`

If HealthKit is not ready in the target project, create a temporary `HealthKitService` stub returning mock `TodaySummary` data, but keep the same method names:

- `requestAuthorization()`
- `fetchTodaySummary()`
- `fetchAllTimeSummary()`
- `logWater(ml:)`
- `refreshWidgetFromToday()`

## Ready-to-send prompt for Codex

Copy and send this prompt to Codex in the other project:

```text
Implement the AiQo home screen in this iOS SwiftUI project.

Requirements:

1. Build the screen architecture using these files or their equivalents:
   - App/MainTabRouter.swift
   - App/MainTabScreen.swift
   - Features/Home/HomeView.swift
   - Features/Home/HomeViewModel.swift
   - Features/Home/MetricKind.swift
   - Features/Home/HomeStatCard.swift
   - Features/Home/WaterDetailSheetView.swift
   - Features/Home/DailyAuraView.swift
   - Features/Home/VibeControlSheet.swift
   - Services/Permissions/HealthKit/TodaySummary.swift

2. Home must be the default tab.

3. Keep a `MainTabRouter.Tab.kitchen` case, but do not render Kitchen as a normal tab page. Instead:
   - when `navigate(to: .kitchen)` is called, set `selectedTab = .home`
   - post `Notification.Name("aiqo.openKitchenFromHome")`
   - make `HomeView` listen for that notification and open Kitchen as a sheet

4. Recreate the home layout in this order:
   - header
   - DailyAura section
   - 2-column metrics grid
   - bottom kitchen shortcut

5. Header behavior:
   - left button opens `VibeControlSheet`
   - right button opens `ProfileScreen`
   - left button must use the existing custom asset `vibe_ icon`
   - optional fallback asset name: `vibe_icon`

6. Metrics behavior:
   - show these metrics in this exact order:
     steps, calories, stand, water, sleep, distance
   - render 2 cards per row
   - card tint mapping:
     - steps: mint
     - calories: mint
     - stand: sand
     - water: sand
     - sleep: mint
     - distance: mint
   - tapping water opens `WaterDetailSheetView`
   - tapping the other metrics opens `MetricDetailSheet`

7. Metric detail requirements:
   - support time scopes: day, week, month, year, allTime
   - keep chart state in `HomeViewModel`

8. Kitchen shortcut requirements:
   - use the existing custom asset `Kitchenـicon`
   - optional fallback asset name: `Kitchen icon`
   - open Kitchen from the home screen as a sheet

9. Use this model shape:

   struct TodaySummary: Sendable {
       let steps: Double
       let activeKcal: Double
       let standPercent: Double
       let waterML: Double
       let sleepHours: Double
       let distanceMeters: Double
   }

10. Use this metric enum:

    enum MetricKind {
        case steps, calories, stand, water, sleep, distance
    }

11. `HomeViewModel` must handle:
    - loading `TodaySummary`
    - mapping summary to display values
    - 60-second refresh timer
    - refresh when app becomes active
    - `activeDestination`
    - `activeDetailMetric`
    - `chartData`
    - `selectedScope`
    - `addWater(liters:)`
    - `gridRows`

12. Keep these HomeView state objects:
    - `HomeViewModel`
    - `DailyAuraViewModel`
    - `VibeControlViewModel`

13. If the target project is missing dependencies such as `ProfileScreen`, `KitchenScreen`, `DailyAuraView`, `VibeControlSheet`, `WaterBottleView`, or `HealthKitService`, create temporary placeholder implementations with the same API so the screen builds cleanly first.

14. If HealthKit integration is missing, stub the service with mock data but preserve the same method names and architecture so the real service can be dropped in later.

15. Preserve the custom icons already present in this project. Do not replace them with generic symbols unless asset loading fails.

Deliverables:
   - implement the full home screen
   - wire routing and sheet presentation
   - make it compile in this project
   - keep the code organized by feature
   - avoid duplicate files if equivalent files already exist
```

## Source notes from the current project

- `MainTabRouter` special Kitchen routing is the key behavior to preserve.
- `HomeViewModel` is the state hub for data loading, card formatting, chart loading, water logging, and destination control.
- `HomeView` owns the sheet presentation logic.
- `VibeControlSheet` is opened from the left header button.
- The kitchen shortcut is not part of the tab bar UI in practice, even though the router has a `.kitchen` case.
