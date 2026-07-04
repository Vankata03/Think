//
//  PathsView.swift
//  Think
//

import SwiftUI

struct PathsView: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PathLibrary.all) { path in
                        if path.isAvailable {
                            NavigationLink(value: path.id) {
                                pathRow(path)
                            }
                        } else {
                            pathRow(path)
                        }
                    }
                } footer: {
                    Text("Pick one. Ten minutes a day.")
                }
            }
            .navigationTitle("Paths")
            .navigationDestination(for: String.self) { id in
                if let path = PathLibrary.all.first(where: { $0.id == id }) {
                    PathDetailView(path: path)
                }
            }
        }
    }

    private func pathRow(_ path: ThinkingPath) -> some View {
        HStack(spacing: 14) {
            Image(systemName: path.icon)
                .font(.title3)
                .foregroundStyle(path.isAvailable ? Color.accentColor : .secondary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(path.name)
                    .font(.headline)
                Text(subtitle(for: path))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !path.isAvailable {
                Text("Soon")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .opacity(path.isAvailable ? 1 : 0.6)
    }

    private func subtitle(for path: ThinkingPath) -> String {
        guard path.isAvailable else { return path.tagline }
        let done = progress.pathCompletedDays
        if done == 0 { return path.tagline }
        if done >= path.steps.count { return "Completed" }
        return "Day \(done + 1) of \(path.steps.count)"
    }
}

#Preview {
    PathsView()
        .environment(ProgressStore())
}
