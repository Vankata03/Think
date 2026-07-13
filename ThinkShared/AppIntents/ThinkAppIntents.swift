//
//  ThinkAppIntents.swift
//  Think
//

#if os(iOS)
import AppIntents
import Foundation
import Observation
import SwiftUI

enum FocusSessionPreset: String, AppEnum {
    case classic
    case long

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Focus preset", table: "AppIntents")
    )

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .classic: DisplayRepresentation(
            title: LocalizedStringResource("Classic 25 / 5", table: "AppIntents")
        ),
        .long: DisplayRepresentation(
            title: LocalizedStringResource("Long 50 / 10", table: "AppIntents")
        ),
    ]

    @MainActor
    init(_ preset: PomodoroTimer.Preset) {
        self = preset == .long ? .long : .classic
    }

    @MainActor
    var timerPreset: PomodoroTimer.Preset {
        switch self {
        case .classic: .classic
        case .long: .long
        }
    }

    @MainActor
    var workMinutes: Int {
        timerPreset.workMinutes
    }
}

final class FocusSessionIntentHandler: @unchecked Sendable {
    enum Outcome: Equatable {
        case started
        case alreadyRunning
    }

    private let timer: PomodoroTimer

    nonisolated init(timer: PomodoroTimer) {
        self.timer = timer
    }

    @MainActor
    func start(preset: FocusSessionPreset) -> Outcome {
        guard !timer.isRunning else { return .alreadyRunning }

        let timerPreset = preset.timerPreset
        if timer.preset != timerPreset || timer.phase != .work {
            timer.select(timerPreset)
        }
        timer.start()
        return .started
    }
}

struct StartFocusSessionIntent: LiveActivityIntent {
    static let title = LocalizedStringResource("Start focus session", table: "AppIntents")
    static let description = IntentDescription(
        LocalizedStringResource(
            "Start a focus timer using a classic or long preset.",
            table: "AppIntents"
        )
    )
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: LocalizedStringResource("Preset", table: "AppIntents"),
        default: .classic
    )
    var preset: FocusSessionPreset

    @Dependency
    private var handler: FocusSessionIntentHandler

    init() { }

    init(preset: FocusSessionPreset) {
        self.preset = preset
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch await handler.start(preset: preset) {
        case .started:
            let minutes = await preset.workMinutes
            return .result(
                dialog: IntentDialog(
                    LocalizedStringResource(
                        "Started a \(minutes)-minute focus session.",
                        table: "AppIntents"
                    )
                )
            )

        case .alreadyRunning:
            return .result(
                dialog: IntentDialog(
                    LocalizedStringResource("A focus session is already running.", table: "AppIntents")
                )
            )
        }
    }
}

enum ThinkAppTab: Hashable {
    case today
    case paths
    case focus
    case profile
}

@MainActor
@Observable
final class AppIntentRouter {
    static let shared = AppIntentRouter()

    var selectedTab: ThinkAppTab = .today

    init() { }

    func showDailyLine() {
        selectedTab = .today
    }
}

struct ShowDailyLineIntent: AppIntent {
    static let title = LocalizedStringResource("Show daily line", table: "AppIntents")
    static let description = IntentDescription(
        LocalizedStringResource("Open Think on today's daily line.", table: "AppIntents")
    )
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Dependency
    private var router: AppIntentRouter

    init() { }

    func perform() async throws -> some IntentResult {
        await router.showDailyLine()
        return .result()
    }
}

struct CheckStreakIntent: AppIntent {
    static let title = LocalizedStringResource("Check streak", table: "AppIntents")
    static let description = IntentDescription(
        LocalizedStringResource("Show your current Think streak.", table: "AppIntents")
    )
    static let supportedModes: IntentModes = .background

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let streak = Self.currentStreak(in: SharedDefaults.appGroup())
        let dialog = IntentDialog(Self.dialogResource(for: streak))

        return .result(dialog: dialog, view: StreakIntentSnippetView(streak: streak))
    }

    nonisolated static func dialogResource(for streak: Int) -> LocalizedStringResource {
        switch streak {
        case 0:
            LocalizedStringResource("Your streak is ready to begin.", table: "AppIntents")
        case 1:
            LocalizedStringResource("Your current streak is 1 day.", table: "AppIntents")
        default:
            LocalizedStringResource(
                "Your current streak is \(streak) days.",
                table: "AppIntents"
            )
        }
    }

    nonisolated static func currentStreak(
        in defaults: UserDefaults,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Int {
        ProgressStore.storedDisplayedStreak(in: defaults, calendar: calendar, now: now)
    }
}

private struct StreakIntentSnippetView: View {
    let streak: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(Color(red: 1, green: 0.83, blue: 0.20))
            Text(streak, format: .number)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text("Current streak", tableName: "AppIntents")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
#endif
