//
//  PathLibraryTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct PathLibraryTests {

    @Test func deepFocusPathIsCompleteAndSequential() {
        let path = PathLibrary.deepFocus

        #expect(path.isAvailable)
        #expect(path.steps.count == 21)
        #expect(path.steps.map(\.id) == Array(1...21))
        #expect(path.steps.allSatisfy { !$0.title.isEmpty && !$0.lesson.isEmpty && !$0.task.isEmpty })
    }

    @Test func futurePathsAreLockedUntilContentShips() {
        let lockedPaths = PathLibrary.all.filter { !$0.isAvailable }

        #expect(lockedPaths.count == 3)
        #expect(lockedPaths.allSatisfy { $0.steps.isEmpty })
    }

    @Test func pathModelsRoundTripThroughJSON() throws {
        let encoded = try JSONEncoder().encode(PathLibrary.deepFocus)
        let decoded = try JSONDecoder().decode(ThinkingPath.self, from: encoded)

        #expect(decoded == PathLibrary.deepFocus)
    }
}
