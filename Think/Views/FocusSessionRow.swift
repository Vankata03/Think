//
//  FocusSessionRow.swift
//  Think
//

import SwiftUI

/// One Focus history row (`design/progress-settings.md` section 1): date
/// and time, completed or partial, the actual active time when known, and
/// the intention only when the caller passes one, which it does only while
/// the journal is unlocked. The row opens nothing.
struct FocusSessionRow: View {
    let record: FocusSessionRecord
    let intention: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
            Text(record.completedAt, format: .dateTime.weekday(.abbreviated).month().day().hour().minute())
                .font(.think(.body))
            // Status and duration stack at accessibility sizes so neither wraps mid-word.
            let layout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: ThinkSpacing.xs))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: ThinkSpacing.s))
            layout {
                Label {
                    Text(status)
                } icon: {
                    Image(systemName: record.isCompleted ? ThinkSymbol.done : ThinkSymbol.focus)
                        .foregroundStyle(record.isCompleted ? ThinkColor.success : ThinkColor.secondaryLabel)
                }
                Text(duration)
                    .monospacedDigit()
            }
            .font(.think(.secondary))
            .foregroundStyle(ThinkColor.secondaryLabel)
            if let intention {
                Text(intention)
                    .font(.think(.secondary))
                    .foregroundStyle(ThinkColor.label)
                    .accessibilityIdentifier("FocusSessionIntention")
            }
        }
        .padding(.vertical, ThinkSpacing.xs)
        .fullWidthRowSeparator()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("FocusSession.\(record.id)")
    }

    private var status: String {
        record.isCompleted ? String(localized: "Completed") : String(localized: "Partial effort")
    }

    private var duration: String {
        guard let seconds = record.actualActiveSeconds else { return String(localized: "Actual duration unknown") }
        return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
    }
}

#Preview {
    List {
        FocusSessionRow(
            record: FocusSessionRecord(id: "a", completedAt: .now, durationMinutes: 25, actualActiveSeconds: 1_500),
            intention: "Write chapter 3")
        FocusSessionRow(
            record: FocusSessionRecord(id: "b", completedAt: .now, durationMinutes: 25, isCompleted: false),
            intention: nil)
    }
}
