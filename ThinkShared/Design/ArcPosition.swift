//
//  ArcPosition.swift
//  ThinkShared
//

import SwiftUI

/// Places a view on an upper half circle at `fraction`, where 0 is the left
/// end and 1 the right end. The fraction is the animatable value, never the
/// resulting point, so an animated change travels along the curve instead
/// of cutting across it. Shared by the day arc and the Focus session arc.
struct ArcPosition: ViewModifier, Animatable {
    var fraction: Double
    var center: CGPoint
    var radius: CGFloat

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func body(content: Content) -> some View {
        content.position(Self.point(fraction: fraction, center: center, radius: radius))
    }

    nonisolated static func point(fraction: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = Double.pi * (1 - fraction)
        return CGPoint(x: center.x + radius * cos(angle), y: center.y - radius * sin(angle))
    }
}

extension View {
    func arcPosition(_ fraction: Double, center: CGPoint, radius: CGFloat) -> some View {
        modifier(ArcPosition(fraction: fraction, center: center, radius: radius))
    }
}
