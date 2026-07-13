//
//  ThinkWidgetsBundle.swift
//  ThinkWidgets
//

import SwiftUI
import WidgetKit

@main
struct ThinkWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DailyQuoteWidget()
        PomodoroLiveActivity()
        StartFocusControl()
    }
}
