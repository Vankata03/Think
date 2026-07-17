//
//  StartFocusControl.swift
//  ThinkWidgets
//

import AppIntents
import SwiftUI
import WidgetKit

struct StartFocusControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.ivanterziev.Think.StartFocusControl") {
            ControlWidgetButton(action: StartFocusSessionIntent(preset: .classic)) {
                Label {
                    Text("Start focus", tableName: "AppIntents")
                } icon: {
                    Image(systemName: "timer")
                }
            }
        }
        .displayName(LocalizedStringResource("Start focus", table: "AppIntents"))
        .description(
            LocalizedStringResource(
                "Start a 25-minute Think focus session.",
                table: "AppIntents"
            )
        )
    }
}
