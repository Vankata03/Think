//
//  ProfileView.swift
//  Think
//

import SwiftData
import SwiftUI

private enum ProfileSheetDestination: String, Identifiable {
    case achievements

    var id: String { rawValue }
}

struct ProfileView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.haptics) private var haptics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var sheetDestination: ProfileSheetDestination?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    progressPanel
                    journalPanel
                    favoritesPanel
                    NavigationLink(destination: PracticeDiscoveryView()) {
                        Label("Find a practice", systemImage: "sparkle.magnifyingglass")
                            .font(.headline).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(18)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    }
                    NavigationLink(destination: WeeklyReviewView()) {
                        Label("Weekly review", systemImage: "calendar")
                            .font(.headline).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(18)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    }
                    .accessibilityIdentifier("OpenWeeklyReview")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: ThinkSymbol.settings)
                    }
                    .accessibilityIdentifier("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        haptics.play(.selection)
                        sheetDestination = .achievements
                    } label: {
                        Image(systemName: "medal.fill")
                    }
                    .accessibilityLabel("Achievements")
                    .accessibilityIdentifier("Achievements")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 76)
            }
        }
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case .achievements:
                StreakAchievementsSheet()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your practice")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
            Text("Progress, settings, and your private notes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Progress")
            VStack(spacing: 16) {
                let metricLayout =
                    dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 12))
                    : AnyLayout(HStackLayout(spacing: 12))
                metricLayout {
                    profileMetric(
                        value: "\(progress.displayedStreak)",
                        label: "Current streak",
                        systemImage: "flame.fill"
                    )
                    profileMetric(
                        value: "\(progress.totalFocusSessions)",
                        label: "Focus sessions",
                        systemImage: "timer"
                    )
                }

                HStack {
                    Label("Path days completed", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(progress.pathCompletedDays)")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
                .font(.subheadline)

                ProgressView(value: Double(progress.pathCompletedDays) / Double(PathLibrary.deepFocus.steps.count))
                    .tint(Color("AccentColor"))
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.separator.opacity(0.6), lineWidth: 1)
            }
        }
        .accessibilityIdentifier("ProfileProgress")
    }

    private var journalPanel: some View {
        NavigationLink {
            JournalView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "book.closed")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Journal")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Private notes and daily answers")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.separator.opacity(0.6), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Journal")
    }

    private var favoritesPanel: some View {
        NavigationLink {
            FavoritesView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "heart")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Saved lines")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("The lines you kept")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.separator.opacity(0.6), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Favorites")
    }

    private func profileMetric(value: String, label: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    ProfileView()
        .environment(ProgressStore())
        .environment(MindfulMinutesStore(client: UnavailableMindfulHealthClient()))
        .environment(CloudBackupState(storage: .inMemory))
        .environment(JournalLock(authenticator: UnavailableJournalAuthenticator()))
        .environment(FavoritesStore(defaults: .standard))
        .environment(PomodoroTimer())
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
