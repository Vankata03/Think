import SwiftUI

struct JournalGate: View {
    @Environment(JournalLock.self) private var lock
    @State private var authenticating = false
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.tint)
            Text("Your journal is locked").font(.headline)
            Text("Unlock to read your notes, answers, and retrospectives.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Unlock") {
                Task { authenticating = true; _ = await lock.authenticate(); authenticating = false }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("AccentColor"))
            .foregroundStyle(.black)
            .disabled(authenticating || !lock.canAuthenticate)
            .accessibilityIdentifier("UnlockJournal")
            if !lock.canAuthenticate { Text(lock.availability.settingSubtitle).font(.footnote).foregroundStyle(.secondary) }
        }
        .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("JournalLocked")
    }
}

struct JournalStorageWarning: View {
    @Environment(JournalRepository.self) private var repository
    var body: some View {
        if repository.storageWarning != nil {
            Label("This session is temporary. Saved entries will be lost when Think closes.", systemImage: "exclamationmark.triangle")
                .font(.callout).foregroundStyle(.orange).accessibilityIdentifier("JournalStorageWarning")
        }
    }
}
