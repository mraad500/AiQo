# Firebase Crashlytics Setup

## Status
- CrashReportingService.swift: READY (canImport guards in place)
- AppDelegate wiring: READY
- Firebase package: NOT YET ADDED — follow steps below
- GoogleService-Info.plist: NOT YET ADDED — follow steps below

## 1. Add Firebase via Swift Package Manager

In Xcode: **File → Add Package Dependencies**

- URL: `https://github.com/firebase/firebase-ios-sdk`
- Dependency Rule: **Up To Next Major Version** from `11.0.0`
- Products to add to the **AiQo** target:
  - `FirebaseCrashlytics`

> Do NOT add FirebaseAnalytics — this project intentionally omits it.

## 2. Add GoogleService-Info.plist

1. Go to [console.firebase.google.com](https://console.firebase.google.com) and create (or open) your project.
2. Add an iOS app with bundle ID matching `AiQo` (check Xcode → General → Bundle Identifier).
3. Download `GoogleService-Info.plist`.
4. Drag it into the Xcode project root (next to `Info.plist`) and tick **Copy items if needed** + your app target.

> `GoogleService-Info.plist` must **not** be committed to source control — add it to `.gitignore` if needed.

## 3. Add the dSYM Upload Build Phase

In Xcode: select the **AiQo** target → **Build Phases** → **+** → **New Run Script Phase**

Paste:
```sh
"${BUILD_DIR%Build/*}SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

Input files:
```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}
$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
```

Place this phase **after** the Compile Sources phase.

## 4. Enable Crashlytics Collection (optional, debug override)

By default Crashlytics collects crash reports in production. During development you may want to suppress uploads by adding to `Info.plist`:

```xml
<key>FirebaseCrashlyticsCollectionEnabled</key>
<false/>
```

Remove (or set to `<true/>`) before shipping.

## 5. Integration Points (already done)

| Location | What happens |
|---|---|
| `AppDelegate.application(_:didFinishLaunchingWithOptions:)` | `FirebaseApp.configure()` + user ID binding for returning users |
| `SceneDelegate.didLoginSuccessfully()` | User ID binding after fresh login |
| `CrashReportingService.shared.record(_:context:)` | Non-fatal error reporting |
| `CrashReportingService.shared.log(_:)` | Breadcrumb logging |

## 6. Verify in Xcode

1. Build and run on device (not Simulator — Crashlytics requires a real device for first upload).
2. Trigger a test crash:
   ```swift
   fatalError("Crashlytics test crash")
   ```
3. Reopen the app — crash report uploads on next launch.
4. Check Firebase Console → Crashlytics within a few minutes.
