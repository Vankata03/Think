import Testing

@testable import Think

/// Reduce Motion through `ThinkMotion` (design-system sections 9 and 11):
/// graphics that glide or change proportion cut instead.
struct ThinkMotionTests {
    @Test func graphicsGlideUnlessReduceMotionIsOn() {
        #expect(ThinkMotion.glide(reduceMotion: false) != nil)
        #expect(ThinkMotion.glide(reduceMotion: true) == nil)
    }

    @Test func proportionsChangeAnimatedUnlessReduceMotionIsOn() {
        #expect(ThinkMotion.proportion(reduceMotion: false) != nil)
        #expect(ThinkMotion.proportion(reduceMotion: true) == nil)
    }
}
