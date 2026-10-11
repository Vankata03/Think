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
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "lock.doc")
                    .font(.largeTitle)
                    .foregroundStyle(ThinkColor.secondaryLabel)
                    .accessibilityHidden(true)

                Text("Your journal export is ready.")
                    .font(.think(.heading))

                Text("Think created a readable text file containing your journal entries and evening retrospectives. Share or save it somewhere private.")
                    .font(.think(.body))
                    .foregroundStyle(ThinkColor.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                ShareLink(item: fileURL, preview: SharePreview("Think journal")) {
                    Label("Share export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .thinkButton(.primary)
                .controlSize(.large)

                Text(fileURL.lastPathComponent)
                    .font(.think(.caption).monospaced())
                    .foregroundStyle(ThinkColor.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer()
            }
            .padding(24)
            .background(ThinkColor.background.ignoresSafeArea())
            .navigationTitle("Export journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    JournalExportSheet(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("Think-Journal.txt"))
}
