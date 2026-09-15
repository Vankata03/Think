import SwiftUI

struct PracticeDiscoveryView: View {
    @Environment(PracticePreferencesStore.self) private var preferences

    var body: some View {
        List {
            Section {
                Picker("Theme", selection: Binding(
                    get: { preferences.preference.theme?.rawValue ?? "" },
                    set: { value in
                        var preference = preferences.preference
                        preference.theme = PracticeTheme(rawValue: value)
                        preferences.setPreference(preference)
                    }
                )) {
                    Text("Any theme").tag("")
                    Text("Focus").tag("focus")
                    Text("Clarity").tag("clarity")
                    Text("Consistency").tag("consistency")
                    Text("Learning").tag("learning")
                    Text("Recovery").tag("recovery")
                }
                Picker("Time available", selection: Binding(
                    get: { preferences.preference.maximumMinutes ?? 0 },
                    set: { value in
                        var preference = preferences.preference
                        preference.maximumMinutes = value == 0 ? nil : value
                        preferences.setPreference(preference)
                    }
                )) {
                    Text("Any length").tag(0)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("25 minutes").tag(25)
                }
            } footer: {
                Text("Optional preferences for these suggestions. Today's assigned practice stays the same.")
            }
            Section("Suggestions") {
                if preferences.suggestions.isEmpty {
                    Text("Try another theme or a little more time.").foregroundStyle(.secondary)
                }
                ForEach(preferences.suggestions.prefix(20)) { practice in
                    NavigationLink {
                        PracticeDetailView(practiceID: practice.id, version: practice.version)
                    } label: {
                        Text(practice.quote.text).font(.system(.body, design: .serif))
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Find a practice")
        .navigationBarTitleDisplayMode(.inline)
    }
}
