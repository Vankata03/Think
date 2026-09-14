import SwiftUI

struct PathsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.haptics) private var haptics

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(PathLibrary.all.filter(\.isAvailable)) { path in
                        if progress.isPathUnlocked(path.id) {
                            NavigationLink(value: path.id) { pathCard(path) }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded { haptics.play(.selection) })
                        } else {
                            pathCard(path)
                        }
                    }
                    DisclosureGroup("In development") {
                        ForEach(PathLibrary.all.filter { !$0.isAvailable }) { path in
                            Label(path.name, systemImage: path.icon)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 12)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Paths")
            .navigationDestination(for: String.self) { id in
                if let path = PathLibrary.all.first(where: { $0.id == id }) {
                    PathDetailView(path: path)
                }
            }
        }
    }

    private func pathCard(_ path: ThinkingPath) -> some View {
        let unlocked = progress.isPathUnlocked(path.id)
        let done = progress.activeRun(for: path.id)?.completedSteps ?? 0
        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: path.icon)
                    .font(.title2)
                    .foregroundStyle(unlocked ? Color.accentColor : .secondary)
                Spacer()
                Image(systemName: unlocked ? "arrow.up.right" : "lock.fill")
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(path.name).font(.title2.bold()).foregroundStyle(.primary)
                if unlocked {
                    Text(path.tagline).font(.subheadline).foregroundStyle(.secondary)
                } else if let previous = progress.prerequisite(for: path.id) {
                    Text("Complete \(previous.name) to unlock")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if unlocked {
                ProgressView(value: Double(done), total: Double(max(1, path.steps.count)))
                    .tint(Color("AccentColor"))
                    .accessibilityLabel(path.name)
                    .accessibilityValue("\(done) of \(path.steps.count) days")
                Text(done >= path.steps.count ? String(localized: "Completed") : String(localized: "Day \(done + 1) of \(path.steps.count)"))
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Path.\(path.id)")
    }
}
