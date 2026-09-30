import SwiftUI

/// The Locked state of design-system section 8, shown in place of any
/// journal screen while the lock is engaged (`design/journal.md` section
/// 7). Face ID is asked for when a screen appears; Unlock is the retry.
struct JournalGate: View {
    @Environment(JournalLock.self) private var lock
    @State private var authenticating = false

    var body: some View {
        ContentUnavailableView {
            Label("Your journal is locked.", systemImage: ThinkSymbol.lock)
        } description: {
            if !lock.canAuthenticate { Text(lock.availability.settingSubtitle) }
        } actions: {
            Button("Unlock") {
                Task { authenticating = true; _ = await lock.authenticate(); authenticating = false }
            }
            .thinkButton(.secondary)
            .disabled(authenticating || !lock.canAuthenticate)
            .accessibilityIdentifier("UnlockJournal")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThinkColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("JournalLocked")
    }
}

/// The temporary-storage warning: a row above the content, never instead
/// of it (design-system section 8, Unavailable).
struct JournalStorageWarning: View {
    @Environment(JournalRepository.self) private var repository
    var body: some View {
        if repository.storageWarning != nil {
            Label("This session is temporary. Saved entries will be lost when Think closes.", systemImage: ThinkSymbol.unavailable)
                .font(.think(.secondary))
                .accessibilityIdentifier("JournalStorageWarning")
        }
    }
}
