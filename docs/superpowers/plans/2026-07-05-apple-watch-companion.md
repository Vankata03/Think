# Apple Watch Companion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a companion-first Apple Watch app with a Today glance and a watch-local Pomodoro timer that writes completed focus sessions into shared Think progress.

**Architecture:** Extract small cross-platform model/state files into `ThinkShared/`, add an App Group-backed defaults helper, then compile those files into the iOS app, widget extension, tests, and new Watch target. The Watch app is a two-page SwiftUI `TabView`; its timer is local and uses `PomodoroTimer(systemSideEffectsEnabled: false)`.

**Tech Stack:** SwiftUI, watchOS, Swift Testing, Observation, `UserDefaults` App Group suite `group.com.ivanterziev.Think`, existing Xcode project with file-system synchronized groups.

---

## File Structure

- Create `ThinkShared/Models/ContentLibrary.swift`: moved from `Think/Models/ContentLibrary.swift`.
- Create `ThinkShared/Models/ThinkingPath.swift`: moved from `Think/Models/ThinkingPath.swift`.
- Create `ThinkShared/State/ProgressStore.swift`: moved from `Think/State/ProgressStore.swift`.
- Create `ThinkShared/State/PomodoroTimer.swift`: moved from `Think/State/PomodoroTimer.swift` and made watch-compilable.
- Create `ThinkShared/State/SharedDefaults.swift`: App Group defaults factory.
- Delete old moved files from `Think/Models/` and `Think/State/`.
- Create `Think/Think.entitlements`: iOS App Group entitlement.
- Modify `Think/ThinkApp.swift`: use shared defaults outside UI tests.
- Create `ThinkWatch/ThinkWatchApp.swift`: Watch app entry point.
- Create `ThinkWatch/Views/WatchRootView.swift`: two-page Watch root.
- Create `ThinkWatch/Views/WatchTodayView.swift`: Today glance.
- Create `ThinkWatch/Views/WatchFocusView.swift`: Watch-local focus timer.
- Create `ThinkWatch/ThinkWatch.entitlements`: Watch App Group entitlement.
- Modify `Think.xcodeproj/project.pbxproj`: add `ThinkShared` group memberships, add Watch app target, add App Group entitlement build settings, embed Watch app in iOS app.
- Create `Think.xcodeproj/xcshareddata/xcschemes/ThinkWatchApp.xcscheme`: shared Watch scheme.
- Modify `ThinkTests/ProgressStoreTests.swift`: add shared defaults coverage.
- Modify `README.md`: mention Watch companion build surface.
- Modify `PLAN.md`: mark Watch v1 as implemented and phone-synced timer as later work.

## Task 1: Shared Defaults Test

**Files:**
- Create: `ThinkShared/State/SharedDefaults.swift`
- Modify: `ThinkTests/ProgressStoreTests.swift`
- Modify: `Think.xcodeproj/project.pbxproj`

- [x] **Step 1: Write the failing test**

Append these tests inside `ProgressStoreTests` before `makeDefaults()`:

```swift
    @Test func sharedDefaultsUsesConfiguredAppGroupName() {
        #expect(SharedDefaults.appGroupSuiteName == "group.com.ivanterziev.Think")
    }

    @Test func sharedDefaultsReturnsNamedSuiteWhenAvailable() {
        let suiteName = "ThinkTests.SharedDefaults.\(UUID().uuidString)"
        let fallback = makeDefaults()
        let defaults = SharedDefaults.make(suiteName: suiteName, fallback: fallback)

        defaults.set(42, forKey: "probe")

        #expect(defaults.integer(forKey: "probe") == 42)
        #expect(defaults !== fallback)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func sharedDefaultsFallsBackWhenSuiteCannotBeOpened() {
        let fallback = makeDefaults()
        let defaults = SharedDefaults.make(suiteName: "", fallback: fallback)

        #expect(defaults === fallback)
    }
```

- [x] **Step 2: Run test to verify it fails**

Run after accepting the Xcode license:

```bash
xcodebuild test -project Think.xcodeproj -scheme Think -testPlan Think -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -only-testing:ThinkTests/ProgressStoreTests/sharedDefaultsUsesConfiguredAppGroupName -only-testing:ThinkTests/ProgressStoreTests/sharedDefaultsReturnsNamedSuiteWhenAvailable -only-testing:ThinkTests/ProgressStoreTests/sharedDefaultsFallsBackWhenSuiteCannotBeOpened CODE_SIGNING_ALLOWED=NO
```

Expected: fails because `SharedDefaults` does not exist.

- [x] **Step 3: Add minimal implementation**

Create `ThinkShared/State/SharedDefaults.swift`:

```swift
//
//  SharedDefaults.swift
//  Think
//

import Foundation

enum SharedDefaults {
    static let appGroupSuiteName = "group.com.ivanterziev.Think"

    static func appGroup() -> UserDefaults {
        make(suiteName: appGroupSuiteName, fallback: .standard)
    }

    static func make(suiteName: String, fallback: UserDefaults = .standard) -> UserDefaults {
        guard !suiteName.isEmpty, let defaults = UserDefaults(suiteName: suiteName) else {
            return fallback
        }
        return defaults
    }
}
```

- [x] **Step 4: Add `ThinkShared` to the Think target**

Modify `Think.xcodeproj/project.pbxproj`:

Add a new root group:

```text
		AC0000000000000000000010 /* ThinkShared */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = ThinkShared;
			sourceTree = "<group>";
		};
```

Add `AC0000000000000000000010 /* ThinkShared */` to the main group children after `Think`.

Add `AC0000000000000000000010 /* ThinkShared */` to `fileSystemSynchronizedGroups` for the `Think` target:

```text
				02A861DB2FF9722200441A2B /* Think */,
				AC0000000000000000000010 /* ThinkShared */,
```

- [x] **Step 5: Run test to verify it passes**

Run:

```bash
xcodebuild test -project Think.xcodeproj -scheme Think -testPlan Think -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -only-testing:ThinkTests/ProgressStoreTests/sharedDefaultsUsesConfiguredAppGroupName -only-testing:ThinkTests/ProgressStoreTests/sharedDefaultsReturnsNamedSuiteWhenAvailable -only-testing:ThinkTests/ProgressStoreTests/sharedDefaultsFallsBackWhenSuiteCannotBeOpened CODE_SIGNING_ALLOWED=NO
```

Expected: passes after the project includes `ThinkShared` in the Think target, which `ThinkTests` imports with `@testable import Think`.

- [x] **Step 6: Commit**

Commit after Task 2 project wiring makes the new file visible to tests:

```bash
git add ThinkShared/State/SharedDefaults.swift ThinkTests/ProgressStoreTests.swift Think.xcodeproj/project.pbxproj
git commit -m "test: cover shared defaults"
```

## Task 2: Shared Code Extraction and iOS Defaults Wiring

**Files:**
- Create: `ThinkShared/Models/ContentLibrary.swift`
- Create: `ThinkShared/Models/ThinkingPath.swift`
- Create: `ThinkShared/State/ProgressStore.swift`
- Create: `ThinkShared/State/PomodoroTimer.swift`
- Delete: `Think/Models/ContentLibrary.swift`
- Delete: `Think/Models/ThinkingPath.swift`
- Delete: `Think/State/ProgressStore.swift`
- Delete: `Think/State/PomodoroTimer.swift`
- Modify: `Think/ThinkApp.swift`
- Modify: `Think.xcodeproj/project.pbxproj`

- [x] **Step 1: Move shared files**

Use `mkdir -p ThinkShared/Models ThinkShared/State`, then move:

```text
Think/Models/ContentLibrary.swift -> ThinkShared/Models/ContentLibrary.swift
Think/Models/ThinkingPath.swift -> ThinkShared/Models/ThinkingPath.swift
Think/State/ProgressStore.swift -> ThinkShared/State/ProgressStore.swift
Think/State/PomodoroTimer.swift -> ThinkShared/State/PomodoroTimer.swift
```

Do not change public type names. Existing iOS call sites should still compile once `ThinkShared` is added to the target.

- [x] **Step 2: Make `PomodoroTimer` cross-platform**

In `ThinkShared/State/PomodoroTimer.swift`, replace the import block with:

```swift
#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation
import Observation
#if canImport(UserNotifications)
import UserNotifications
#endif
```

Wrap ActivityKit-only methods and calls:

```swift
    private func syncLiveActivity() {
        #if os(iOS) && canImport(ActivityKit)
        guard let endDate else { return }
        let startDate = endDate.addingTimeInterval(-TimeInterval(max(phaseTotalSeconds, 1)))
        let state = PomodoroActivityAttributes.ContentState(
            phase: phase == .work ? .work : .rest,
            startDate: startDate,
            endDate: endDate
        )
        let content = ActivityContent(state: state, staleDate: endDate)
        if let id = liveActivityID {
            Task.detached {
                await Activity<PomodoroActivityAttributes>.activities
                    .first { $0.id == id }?
                    .update(content)
            }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            let activity = try? Activity.request(attributes: PomodoroActivityAttributes(), content: content)
            liveActivityID = activity?.id
        }
        #endif
    }

    private func endLiveActivity() {
        #if os(iOS) && canImport(ActivityKit)
        guard liveActivityID != nil else { return }
        liveActivityID = nil
        Task.detached {
            for activity in Activity<PomodoroActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }
```

Wrap notification methods:

```swift
    private func requestAuthorizationIfNeeded() {
        #if canImport(UserNotifications)
        guard !requestedAuthorization else { return }
        requestedAuthorization = true
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
        #endif
    }

    private func schedulePhaseEndNotification() {
        #if os(iOS) && canImport(ActivityKit) && canImport(UserNotifications)
        guard !ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let endDate else { return }
        let interval = endDate.timeIntervalSinceNow
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        switch phase {
        case .work:
            content.title = "Session complete"
            content.body = "Nice work. Time for a break."
        case .rest:
            content.title = "Break over"
            content.body = "Ready for the next session?"
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
        #endif
    }
```

In `stopRunning()`, wrap notification removal:

```swift
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        #endif
```

- [x] **Step 3: Wire iOS app to shared defaults**

In `Think/ThinkApp.swift`, replace `_progress = State(initialValue: ProgressStore())` in `init()` with:

```swift
        let progressDefaults: UserDefaults
        if isUITesting, let bundleIdentifier = Bundle.main.bundleIdentifier {
            let suiteName = "\(bundleIdentifier).ui-tests"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            progressDefaults = defaults
        } else {
            progressDefaults = SharedDefaults.appGroup()
        }
        _progress = State(initialValue: ProgressStore(defaults: progressDefaults))
```

Keep the existing UI-test removal of the app bundle persistent domain for SwiftData and app settings cleanup.

- [x] **Step 4: Update Xcode synchronized groups**

Modify `Think.xcodeproj/project.pbxproj`:

Add `AC0000000000000000000010 /* ThinkShared */` to `fileSystemSynchronizedGroups` for the widget extension target:

```text
AB000000000000000000000F /* ThinkWidgetsExtension */
```

Remove `AB0000000000000000000010 /* Exceptions for "Think" folder in "ThinkWidgetsExtension" target */` from the `Think` root group exceptions list because `ContentLibrary.swift` now lives in `ThinkShared`.

- [x] **Step 5: Run moved-code tests**

Run after Xcode license acceptance:

```bash
xcodebuild test -project Think.xcodeproj -scheme Think -testPlan Think -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -only-testing:ThinkTests/ContentLibraryTests -only-testing:ThinkTests/PathLibraryTests -only-testing:ThinkTests/ProgressStoreTests -only-testing:ThinkTests/PomodoroTimerTests -only-testing:ThinkWidgetsTests/DailyQuoteTimelineTests CODE_SIGNING_ALLOWED=NO
```

Expected: all selected tests pass.

- [x] **Step 6: Commit**

```bash
git add ThinkShared Think/ThinkApp.swift Think.xcodeproj/project.pbxproj Think/Models/ContentLibrary.swift Think/Models/ThinkingPath.swift Think/State/ProgressStore.swift Think/State/PomodoroTimer.swift
git commit -m "refactor: extract shared watch state"
```

## Task 3: App Group Entitlements and Watch Target

**Files:**
- Create: `Think/Think.entitlements`
- Create: `ThinkWatch/ThinkWatch.entitlements`
- Create: `ThinkWatch/ThinkWatchApp.swift`
- Create: `ThinkWatch/Views/WatchRootView.swift`
- Modify: `Think.xcodeproj/project.pbxproj`
- Create: `Think.xcodeproj/xcshareddata/xcschemes/ThinkWatchApp.xcscheme`

- [x] **Step 1: Create entitlements**

Create `Think/Think.entitlements` and `ThinkWatch/ThinkWatch.entitlements` with identical content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.ivanterziev.Think</string>
	</array>
</dict>
</plist>
```

- [x] **Step 2: Create minimal Watch app**

Create `ThinkWatch/ThinkWatchApp.swift`:

```swift
//
//  ThinkWatchApp.swift
//  ThinkWatchApp
//

import SwiftUI

@main
struct ThinkWatchApp: App {
    @State private var progress = ProgressStore(defaults: SharedDefaults.appGroup())

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(progress)
        }
    }
}
```

Create `ThinkWatch/Views/WatchRootView.swift`:

```swift
//
//  WatchRootView.swift
//  ThinkWatchApp
//

import SwiftUI

struct WatchRootView: View {
    var body: some View {
        TabView {
            Text("Today")
                .tag(0)
            Text("Focus")
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    WatchRootView()
        .environment(ProgressStore(defaults: .standard))
}
```

- [x] **Step 3: Add Watch target to project**

Modify `Think.xcodeproj/project.pbxproj` with these objects.

Add build file and product reference:

```text
		AC000000000000000000000B /* ThinkWatchApp.app in Embed Watch Content */ = {isa = PBXBuildFile; fileRef = AC0000000000000000000001 /* ThinkWatchApp.app */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };

		AC0000000000000000000001 /* ThinkWatchApp.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ThinkWatchApp.app; sourceTree = BUILT_PRODUCTS_DIR; };
```

Add root group:

```text
		AC0000000000000000000002 /* ThinkWatch */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = ThinkWatch;
			sourceTree = "<group>";
		};
```

Add framework, sources, resources, and embed phases:

```text
		AC0000000000000000000003 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AC0000000000000000000004 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AC0000000000000000000005 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AC000000000000000000000A /* Embed Watch Content */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";
			dstSubfolderSpec = 16;
			files = (
				AC000000000000000000000B /* ThinkWatchApp.app in Embed Watch Content */,
			);
			name = "Embed Watch Content";
			runOnlyForDeploymentPostprocessing = 0;
		};
```

Add target dependency objects:

```text
		AC000000000000000000000D /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 02A861D12FF9722200441A2B /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = AC0000000000000000000006;
			remoteInfo = ThinkWatchApp;
		};
		AC000000000000000000000C /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = AC0000000000000000000006 /* ThinkWatchApp */;
			targetProxy = AC000000000000000000000D /* PBXContainerItemProxy */;
		};
```

Add native target:

```text
		AC0000000000000000000006 /* ThinkWatchApp */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AC0000000000000000000007 /* Build configuration list for PBXNativeTarget "ThinkWatchApp" */;
			buildPhases = (
				AC0000000000000000000003 /* Sources */,
				AC0000000000000000000004 /* Frameworks */,
				AC0000000000000000000005 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				AC0000000000000000000002 /* ThinkWatch */,
				AC0000000000000000000010 /* ThinkShared */,
			);
			name = ThinkWatchApp;
			packageProductDependencies = (
			);
			productName = ThinkWatchApp;
			productReference = AC0000000000000000000001 /* ThinkWatchApp.app */;
			productType = "com.apple.product-type.application";
		};
```

Add target attributes:

```text
					AC0000000000000000000006 = {
						CreatedOnToolsVersion = 26.6;
					};
```

Add the Watch target to `targets`, add `AC0000000000000000000002 /* ThinkWatch */` to main group children, and add `AC0000000000000000000001 /* ThinkWatchApp.app */` to Products.

Add `AC000000000000000000000A /* Embed Watch Content */` to the `Think` target build phases after `Embed Foundation Extensions`, and add `AC000000000000000000000C /* PBXTargetDependency */` to the `Think` target dependencies.

Add build configurations:

```text
		AC0000000000000000000008 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = ThinkWatch/ThinkWatch.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = H2Z5VT54PS;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Think;
				INFOPLIST_KEY_WKApplication = YES;
				INFOPLIST_KEY_WKCompanionAppBundleIdentifier = com.ivanterziev.Think;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.ivanterziev.Think.watchkitapp;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = watchos;
				SKIP_INSTALL = YES;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SUPPORTED_PLATFORMS = "watchos watchsimulator";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = 4;
				WATCHOS_DEPLOYMENT_TARGET = 26.0;
			};
			name = Debug;
		};
		AC0000000000000000000009 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = ThinkWatch/ThinkWatch.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = H2Z5VT54PS;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Think;
				INFOPLIST_KEY_WKApplication = YES;
				INFOPLIST_KEY_WKCompanionAppBundleIdentifier = com.ivanterziev.Think;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.ivanterziev.Think.watchkitapp;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = watchos;
				SKIP_INSTALL = YES;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SUPPORTED_PLATFORMS = "watchos watchsimulator";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = 4;
				WATCHOS_DEPLOYMENT_TARGET = 26.0;
			};
			name = Release;
		};
```

Add configuration list:

```text
		AC0000000000000000000007 /* Build configuration list for PBXNativeTarget "ThinkWatchApp" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AC0000000000000000000008 /* Debug */,
				AC0000000000000000000009 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
```

Add `CODE_SIGN_ENTITLEMENTS = Think/Think.entitlements;` to both `Think` target build configurations.

- [x] **Step 4: Create shared Watch scheme**

Create `Think.xcodeproj/xcshareddata/xcschemes/ThinkWatchApp.xcscheme`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2660"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "AC0000000000000000000006"
               BuildableName = "ThinkWatchApp.app"
               BlueprintName = "ThinkWatchApp"
               ReferencedContainer = "container:Think.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "AC0000000000000000000006"
            BuildableName = "ThinkWatchApp.app"
            BlueprintName = "ThinkWatchApp"
            ReferencedContainer = "container:Think.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "AC0000000000000000000006"
            BuildableName = "ThinkWatchApp.app"
            BlueprintName = "ThinkWatchApp"
            ReferencedContainer = "container:Think.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
```

- [x] **Step 5: Verify target listing**

Run after Xcode license acceptance:

```bash
xcodebuild -list -project Think.xcodeproj
```

Expected: schemes include `Think`, `ThinkWidgetsExtension`, and `ThinkWatchApp`; targets include `ThinkWatchApp`.

- [x] **Step 6: Commit**

```bash
git add Think/Think.entitlements ThinkWatch Think.xcodeproj/project.pbxproj Think.xcodeproj/xcshareddata/xcschemes/ThinkWatchApp.xcscheme
git commit -m "feat: add watch app target"
```

## Task 4: Watch Today Glance

**Files:**
- Create: `ThinkWatch/Views/WatchTodayView.swift`
- Modify: `ThinkWatch/Views/WatchRootView.swift`

- [x] **Step 1: Write Watch Today view**

Create `ThinkWatch/Views/WatchTodayView.swift`:

```swift
//
//  WatchTodayView.swift
//  ThinkWatchApp
//

import SwiftUI

struct WatchTodayView: View {
    @Environment(ProgressStore.self) private var progress

    private var quote: Quote { ContentLibrary.dailyQuote() }
    private var nextStep: PathStep? {
        let index = min(progress.pathCompletedDays, PathLibrary.deepFocus.steps.count - 1)
        guard PathLibrary.deepFocus.steps.indices.contains(index) else { return nil }
        return PathLibrary.deepFocus.steps[index]
    }

    private var dailyProgressCount: Int {
        var completed = 0
        if progress.completedTaskToday { completed += 1 }
        if progress.focusSessionsToday > 0 { completed += 1 }
        if progress.completedPathStepToday { completed += 1 }
        return completed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                quoteBlock
                progressBlock
                pathBlock
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .navigationTitle("Today")
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("Today")
                .font(.headline.weight(.semibold))
            Spacer()
            Label("\(progress.displayedStreak)", systemImage: "flame.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)
                .accessibilityLabel("\(progress.displayedStreak) day streak")
        }
    }

    private var quoteBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(.yellow)
                .frame(width: 26, height: 3)
                .clipShape(Capsule())
            Text(quote.text)
                .font(.system(.callout, design: .serif).weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Text(quote.author)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Daily reps")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(dailyProgressCount)/3")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.yellow)
            }
            ProgressView(value: Double(dailyProgressCount), total: 3)
                .tint(.yellow)
                .accessibilityLabel("Daily progress")
                .accessibilityValue("\(dailyProgressCount) of 3")
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var pathBlock: some View {
        if let nextStep {
            VStack(alignment: .leading, spacing: 5) {
                Label("Deep Focus", systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                Text("Day \(nextStep.id): \(nextStep.title)")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(nextStep.task)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    NavigationStack {
        WatchTodayView()
            .environment(ProgressStore(defaults: .standard))
    }
}
```

- [x] **Step 2: Wire root to Today**

Replace `WatchRootView.body` with:

```swift
    var body: some View {
        TabView {
            NavigationStack {
                WatchTodayView()
            }
            .tag(0)

            Text("Focus")
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
```

- [x] **Step 3: Build Watch scheme**

Run after Xcode license acceptance:

```bash
xcodebuild build -project Think.xcodeproj -scheme ThinkWatchApp -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest' CODE_SIGNING_ALLOWED=NO
```

Expected: Watch app builds and Today view compiles.

- [x] **Step 4: Commit**

```bash
git add ThinkWatch/Views/WatchTodayView.swift ThinkWatch/Views/WatchRootView.swift
git commit -m "feat: add watch today glance"
```

## Task 5: Watch Focus Timer

**Files:**
- Create: `ThinkWatch/Views/WatchFocusView.swift`
- Modify: `ThinkWatch/Views/WatchRootView.swift`

- [x] **Step 1: Write Watch Focus view**

Create `ThinkWatch/Views/WatchFocusView.swift`:

```swift
//
//  WatchFocusView.swift
//  ThinkWatchApp
//

import SwiftUI

struct WatchFocusView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.scenePhase) private var scenePhase
    @State private var timer = PomodoroTimer(systemSideEffectsEnabled: false)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ring
                controls
                presets
                Text("\(progress.focusSessionsToday) today")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
        }
        .navigationTitle("Focus")
        .onAppear {
            timer.onWorkSessionComplete = {
                progress.recordFocusSession()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                timer.resync()
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.22), lineWidth: 9)
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(timer.phase == .work ? .yellow : .green, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.6), value: timer.progress)
            VStack(spacing: 3) {
                Text(timer.remainingLabel)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)
                Text(timer.phase.rawValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 132, height: 132)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(timer.phase == .work ? "Deep work timer" : "Break timer")
        .accessibilityValue(timer.remainingLabel)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Button {
                timer.toggle()
            } label: {
                Label(timer.isRunning ? "Pause" : "Start", systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)

            HStack(spacing: 8) {
                Button {
                    timer.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Reset timer")

                Button {
                    timer.skipPhase()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(timer.phase == .work ? "Skip to break" : "Skip to work")
            }
        }
    }

    private var presets: some View {
        Picker("Preset", selection: presetBinding) {
            ForEach(PomodoroTimer.Preset.all, id: \.workMinutes) { preset in
                Text(preset.label).tag(preset)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Focus preset")
    }

    private var presetBinding: Binding<PomodoroTimer.Preset> {
        Binding {
            timer.preset
        } set: { preset in
            timer.select(preset)
        }
    }
}

#Preview {
    NavigationStack {
        WatchFocusView()
            .environment(ProgressStore(defaults: .standard))
    }
}
```

- [x] **Step 2: Wire root to Focus**

Replace the `Text("Focus")` placeholder in `WatchRootView` with:

```swift
            NavigationStack {
                WatchFocusView()
            }
            .tag(1)
```

- [x] **Step 3: Build Watch scheme**

Run:

```bash
xcodebuild build -project Think.xcodeproj -scheme ThinkWatchApp -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest' CODE_SIGNING_ALLOWED=NO
```

Expected: Watch app builds with Today and Focus screens.

- [x] **Step 4: Run timer and progress tests**

Run:

```bash
xcodebuild test -project Think.xcodeproj -scheme Think -testPlan Think -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -only-testing:ThinkTests/PomodoroTimerTests -only-testing:ThinkTests/ProgressStoreTests CODE_SIGNING_ALLOWED=NO
```

Expected: timer and progress tests pass.

- [x] **Step 5: Commit**

```bash
git add ThinkWatch/Views/WatchFocusView.swift ThinkWatch/Views/WatchRootView.swift
git commit -m "feat: add watch focus timer"
```

## Task 6: Docs and Full Verification

**Files:**
- Modify: `README.md`
- Modify: `PLAN.md`
- Test: `Think.xctestplan`

- [x] **Step 1: Update README project structure**

In `README.md`, add:

```markdown
- `ThinkShared/` - model and state code shared by iOS, widgets, tests, and Watch.
- `ThinkWatch/` - watchOS companion app source.
```

Add Watch build command:

```text
Watch app build:

    xcodebuild build \
      -project Think.xcodeproj \
      -scheme ThinkWatchApp \
      -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'
```

- [x] **Step 2: Update PLAN progress**

In `PLAN.md`, replace the Later bullet:

```markdown
- **Later**: Apple Watch, additional paths, StoreKit paywall, and Pro content gating.
```

with:

```markdown
- **Later**: phone-synced Watch focus timer, additional paths, StoreKit paywall, and Pro content gating.
```

Add to build order:

```markdown
- [x] Apple Watch companion v1: Today glance and watch-local focus timer
```

- [x] **Step 3: Full iOS test plan**

Run after Xcode license acceptance:

```bash
xcodebuild test -project Think.xcodeproj -scheme Think -testPlan Think -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' CODE_SIGNING_ALLOWED=NO
```

Expected: app unit tests, UI tests, and widget tests pass.

- [x] **Step 4: Watch build**

Run:

```bash
xcodebuild build -project Think.xcodeproj -scheme ThinkWatchApp -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest' CODE_SIGNING_ALLOWED=NO
```

Expected: Watch app builds.

- [x] **Step 5: Commit**

```bash
git add README.md PLAN.md
git commit -m "docs: document watch companion"
```

## Execution Notes

- Local verification is blocked until the Xcode license is accepted in Terminal with `sudo xcodebuild -license`.
- If `Apple Watch Series 11 (46mm)` is unavailable, run `xcrun simctl list devices available | rg "Apple Watch"` and use the newest available watchOS simulator name.
- Apple Developer documentation says to add a watchOS target to an existing SwiftUI project for a watchOS app, and Apple documents modern single-target watchOS apps. Keep the new target single-target; do not add a legacy WatchKit extension.
