//
//  ThinkAppShortcuts.swift
//  Think
//

import AppIntents

struct ThinkAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusSessionIntent(),
            phrases: [
                "Start focus in \(.applicationName)",
                "Start a focus session with \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("Start focus", table: "AppIntents"),
            systemImageName: "timer"
        )

        AppShortcut(
            intent: ShowDailyLineIntent(),
            phrases: [
                "Show today's line in \(.applicationName)",
                "Show the daily line in \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("Show daily line", table: "AppIntents"),
            systemImageName: "quote.opening"
        )

        AppShortcut(
            intent: CheckStreakIntent(),
            phrases: [
                "Check my streak in \(.applicationName)",
                "What's my streak in \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("Check streak", table: "AppIntents"),
            systemImageName: "flame.fill"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .yellow
}
