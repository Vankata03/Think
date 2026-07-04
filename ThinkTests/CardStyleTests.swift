//
//  CardStyleTests.swift
//  ThinkTests
//

import Testing
@testable import Think

@MainActor
struct CardStyleTests {

    @Test func cardStylesHaveUniqueIdentifiersAndFreeOptions() {
        let styles = CardStyle.all
        let ids = Set(styles.map(\.id))

        #expect(ids.count == styles.count)
        #expect(styles.filter { !$0.isPro }.count == 2)
        #expect(styles.filter { $0.isPro }.count == 2)
    }
}
