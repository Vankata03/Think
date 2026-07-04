//
//  PathsView.swift
//  Think
//

import SwiftUI

struct PathsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.haptics) private var haptics

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    VStack(spacing: 0) {
                        sectionHeader(
                            "Training atlas",
                            detail: "\(progress.pathCompletedDays)/\(PathLibrary.deepFocus.steps.count)"
                        )
                            .padding(.bottom, 16)

                        ProgressView(value: Double(progress.pathCompletedDays) / Double(PathLibrary.deepFocus.steps.count))
                            .tint(.accentColor)
                            .padding(.bottom, 18)

                        VStack(spacing: 0) {
                            ForEach(PathLibrary.all) { path in
                                pathLink(path)
                                if path.id != PathLibrary.all.last?.id {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.separator.opacity(0.6), lineWidth: 1)
                    }
                    .padding(.horizontal, 20)

                    Text("The path is intentionally small. Read, act, mark the day.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 34)
                }
                .padding(.bottom, 110)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Paths")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { id in
                if let path = PathLibrary.all.first(where: { $0.id == id }) {
                    PathDetailView(path: path)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Paths")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
            Text("Pick one discipline. Ten minutes a day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    @ViewBuilder
    private func pathLink(_ path: ThinkingPath) -> some View {
        if path.isAvailable {
            NavigationLink(value: path.id) {
                pathRow(path)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                haptics.play(.selection)
            })
        } else {
            pathRow(path)
        }
    }

    private func pathRow(_ path: ThinkingPath) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(path.isAvailable ? Color.accentColor.opacity(0.16) : Color(.tertiarySystemFill))
                    .frame(width: 40, height: 40)
                Image(systemName: path.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(path.isAvailable ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(path.name)
                        .font(.headline)
                        .foregroundStyle(path.isAvailable ? Color.primary : Color.secondary)
                    if path.isAvailable, progress.pathCompletedDays > 0 {
                        Text("Day \(min(progress.pathCompletedDays + 1, path.steps.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(subtitle(for: path))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if !path.isAvailable {
                Text("Soon")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .opacity(path.isAvailable ? 1 : 0.68)
        .accessibilityElement(children: .combine)
    }

    private func subtitle(for path: ThinkingPath) -> String {
        guard path.isAvailable else { return path.tagline }
        let done = progress.pathCompletedDays
        if done == 0 { return path.tagline }
        if done >= path.steps.count { return "Completed" }
        return "Day \(done + 1) of \(path.steps.count)"
    }

    private func sectionHeader(_ title: String, detail: String? = nil) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PathsView()
        .environment(ProgressStore())
}
