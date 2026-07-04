//
//  ProfileView.swift
//  Think
//

import SwiftUI
import SwiftData
import StoreKit

private enum Feedback {
    static let address = "ivanterziev93@gmail.com"

    static func mailURL(subject: String) -> URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let body = "\n\n—\nThink \(version), iOS \(UIDevice.current.systemVersion)"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

struct ProfileView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    @AppStorage(DailyQuoteNotifier.enabledKey) private var dailyLineEnabled = false
    @AppStorage(DailyQuoteNotifier.minutesKey) private var dailyLineMinutes = DailyQuoteNotifier.defaultMinutes

    private var dailyLineTime: Binding<Date> {
        Binding {
            Calendar.current.date(
                bySettingHour: dailyLineMinutes / 60,
                minute: dailyLineMinutes % 60,
                second: 0, of: .now
            ) ?? .now
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            dailyLineMinutes = (components.hour ?? 8) * 60 + (components.minute ?? 0)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Progress") {
                    LabeledContent("Current streak") {
                        Label("\(progress.displayedStreak) days", systemImage: "flame.fill")
                            .foregroundStyle(progress.displayedStreak > 0 ? .orange : .secondary)
                    }
                    LabeledContent("Focus sessions", value: "\(progress.totalFocusSessions)")
                    LabeledContent("Path days completed", value: "\(progress.pathCompletedDays)")
                }

                Section {
                    NavigationLink {
                        JournalView()
                    } label: {
                        Label("Journal", systemImage: "book.closed")
                    }
                }

                Section("Settings") {
                    Picker(selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }
                    Toggle(isOn: $dailyLineEnabled) {
                        Label("Daily line notification", systemImage: "bell")
                    }
                    if dailyLineEnabled {
                        DatePicker(selection: dailyLineTime, displayedComponents: .hourAndMinute) {
                            Label("Time", systemImage: "clock")
                        }
                    }
                }
                .onChange(of: dailyLineEnabled) {
                    DailyQuoteNotifier.refreshSchedule()
                }
                .onChange(of: dailyLineMinutes) {
                    DailyQuoteNotifier.refreshSchedule()
                }

                Section("Feedback") {
                    Button {
                        sendMail(subject: "Think — idea")
                    } label: {
                        Label("Share an idea", systemImage: "lightbulb")
                    }
                    Button {
                        sendMail(subject: "Think — problem")
                    } label: {
                        Label("Report a problem", systemImage: "exclamationmark.bubble")
                    }
                    Button {
                        requestReview()
                    } label: {
                        Label("Rate Think", systemImage: "star")
                    }
                }

            }
            .navigationTitle("Profile")
        }
    }

    private func sendMail(subject: String) {
        if let url = Feedback.mailURL(subject: subject) {
            openURL(url)
        }
    }
}

#Preview {
    ProfileView()
        .environment(ProgressStore())
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
