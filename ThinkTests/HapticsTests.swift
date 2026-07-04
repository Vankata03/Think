//
//  HapticsTests.swift
//  ThinkTests
//

import Testing
@testable import Think

@MainActor
struct HapticsTests {

    @Test func semanticEventsMapToStablePatterns() {
        let recorder = RecordingHapticsBackend()
        let haptics = Haptics(backend: recorder)

        haptics.play(.selection)
        haptics.play(.start)
        haptics.play(.pause)
        haptics.play(.reset)
        haptics.play(.success)
        haptics.play(.warning)

        #expect(recorder.patterns == [
            .selection,
            .impact(.medium),
            .impact(.light),
            .impact(.medium),
            .notification(.success),
            .notification(.warning),
        ])
    }
}
