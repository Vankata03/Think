//
//  JournalExportSheet.swift
//  Think
//

import SwiftUI

struct JournalExportSheet: View {
    let fileURL: URL

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ThinkSpacing.l) {
                Image(systemName: ThinkSymbol.exportReady)
                    .font(.think(.title))
                    .foregroundStyle(ThinkColor.secondaryLabel)
                    .accessibilityHidden(true)

                Text("Your journal export is ready.")
                    .font(.think(.heading))

                Text("Think created a readable text file containing your journal entries and evening retrospectives. Share or save it somewhere private.")
                    .font(.think(.body))
                    .foregroundStyle(ThinkColor.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                Text(fileURL.lastPathComponent)
                    .font(.think(.caption).monospaced())
                    .foregroundStyle(ThinkColor.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer()
            }
            .padding(ThinkSpacing.xl)
            .background(ThinkColor.background.ignoresSafeArea())
            .navigationTitle("Export journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Design-system 13.5: "Close" on a read-only sheet, Share as
                // the one primary in the trailing slot.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("DismissJournalExport")
                }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: fileURL, preview: SharePreview("Think journal")) {
                        Label("Share", systemImage: ThinkSymbol.share)
                    }
                    .thinkButton(.primary)
                    .accessibilityIdentifier("ShareJournalExport")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    JournalExportSheet(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("Think-Journal.txt"))
}
