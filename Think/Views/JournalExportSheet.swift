//
//  JournalExportSheet.swift
//  Think
//

import SwiftUI

struct JournalExportSheet: View {
    let fileURL: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var prominentButtonForeground: Color {
        .prominentButtonForeground(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "lock.doc")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("Your journal export is ready.")
                    .font(.title2.bold())

                Text("Think created a readable text file containing your journal entries and evening retrospectives. Share or save it somewhere private.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ShareLink(item: fileURL, preview: SharePreview("Think journal")) {
                    Label("Share export", systemImage: "square.and.arrow.up")
                        .foregroundStyle(prominentButtonForeground)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.accentColor)

                Text(fileURL.lastPathComponent)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer()
            }
            .padding(24)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
