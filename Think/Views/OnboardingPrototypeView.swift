//
//  OnboardingPrototypeView.swift
//  Think
//
//  PROTOTYPE — throwaway. Answers "Onboarding aligned to the new IA" (#80),
//  variant E of prototype-onboarding/index.html: A's paged flow, Reminders as
//  a Form with switches, appearance tiles plus optional extras on one step,
//  the on-device AI slot after it. Lives on branch prototype/onboarding only;
//  never merged. Health and Lock journal switches only flip local state.
//  Launch with SIMCTL_CHILD_ONB_STEP=0...3 to open on a step and
//  SIMCTL_CHILD_ONB_AI=1 to show the AI slot.
//

import SwiftUI
import UserNotifications

private func accentFill(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 1.0, green: 0.831, blue: 0.2) : Color(red: 0.949, green: 0.769, blue: 0.11)
}

private func accentInk(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 1.0, green: 0.831, blue: 0.2) : Color(red: 0.431, green: 0.361, blue: 0.02)
}

struct OnboardingPrototypeView: View {
    private enum Step: Int { case promise, reminders, makeItYours, ai }

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(Onboarding.completedKey) private var completed = false
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.dark

    @State private var step: Step
    @State private var dailyLine = true
    @State private var retro = true
    @State private var sessionEnd = true
    @State private var health = false
    @State private var lock = false
    private let showsAI: Bool

    init() {
        let env = ProcessInfo.processInfo.environment
        showsAI = env["ONB_AI"] == "1"
        _step = State(initialValue: Step(rawValue: Int(env["ONB_STEP"] ?? "") ?? 0) ?? .promise)
    }

    private var steps: [Step] { showsAI ? [.promise, .reminders, .makeItYours, .ai] : [.promise, .reminders, .makeItYours] }
    private var isLast: Bool { step == steps.last }

    var body: some View {
        NavigationStack {
            page
                .id(step)
                .toolbar {
                    if !isLast {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Skip") { skip() }
                                .tint(.primary)
                        }
                    }
                }
                .safeAreaBar(edge: .bottom) { bottomBar }
        }
        .tint(accentInk(scheme))
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .promise: promise
        case .reminders: reminders
        case .makeItYours: makeItYours
        case .ai: aiSlot
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if !typeSize.isAccessibilitySize { HStack(spacing: 8) {
                ForEach(steps, id: \.self) { s in
                    Circle()
                        .fill(s == step ? Color.primary : Color(.tertiaryLabel))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \((steps.firstIndex(of: step) ?? 0) + 1) of \(steps.count)") }

            Button {
                Task { await advance() }
            } label: {
                Text(isLast ? "Begin practice" : "Continue")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(accentFill(scheme))
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: Steps

    private var promise: some View {
        GeometryReader { geo in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !typeSize.isAccessibilitySize {
                    PromiseArc(fill: accentFill(scheme), ink: accentInk(scheme))
                        .accessibilityLabel("Your day: a question in the morning, a move by afternoon, a retro in the evening.")
                }
                Text("One line, one question, one move a day.")
                    .font(.title)
                    .fontDesign(.serif)
                Text("A few honest minutes. What you write stays on your device and in your own iCloud.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: geo.size.height, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var reminders: some View {
        Form {
            Section {
                switchRow("Daily line", symbol: "text.quote", value: dailyLine ? "08:00" : nil, isOn: $dailyLine)
                switchRow("Evening retro", symbol: "moon.stars", value: retro ? "20:00" : nil, isOn: $retro)
                switchRow("Session end alerts", symbol: "timer", detail: "When a focus or break interval ends", isOn: $sessionEnd)
            } header: {
                Text("Notifications")
            } footer: {
                Text(anyReminder
                     ? "Change times and switches later in Settings, behind the gear on Progress."
                     : "Turn any of these on in Settings, behind the gear on Progress.")
            }
        }
        .navigationTitle("Reminders")
    }

    /// A switch row: monochrome symbol, title, optional detail or value.
    /// At accessibility sizes the switch drops under the label so the text
    /// wraps at word boundaries instead of squeezing beside the control.
    @ViewBuilder
    private func switchRow(_ title: LocalizedStringKey, symbol: String, detail: LocalizedStringKey? = nil,
                           value: String? = nil, isOn: Binding<Bool>) -> some View {
        let label = Label {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                    if let value, !typeSize.isAccessibilitySize {
                        Spacer()
                        Text(value).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                if let value, typeSize.isAccessibilitySize { Text(value).foregroundStyle(.secondary) }
                if let detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(.primary)
        }
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                label
                Toggle(isOn: isOn) { Text(title) }.labelsHidden().tint(.green)
            }
            .accessibilityElement(children: .combine)
        } else {
            Toggle(isOn: isOn) { label }.tint(.green)
        }
    }

    private var makeItYours: some View {
        Form {
            Section("Appearance") {
                AppearanceTiles(selection: $appearance, fill: accentFill(scheme))
                    .listRowInsets(EdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12))
            }
            Section {
                switchRow("Log focus to Health", symbol: "heart", detail: "Completed sessions become Mindful Minutes", isOn: $health)
                switchRow("Lock journal", symbol: "lock", detail: "Face ID before your writing opens", isOn: $lock)
            } header: {
                Text("Optional")
            } footer: {
                Text("Both stay in Settings. Each asks its own permission when turned on.")
            }
        }
        .navigationTitle("Make it yours")
    }

    private var aiSlot: some View {
        ContentUnavailableView {
            Label("On-device AI step", systemImage: "sparkle")
        } description: {
            Text("Reserved. Eligible devices only. Copy and default come from the on-device AI map (#67).")
        }
    }

    // MARK: Actions

    private var anyReminder: Bool { dailyLine || retro || sessionEnd }

    private func advance() async {
        if step == .reminders, anyReminder {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if !granted { dailyLine = false; retro = false; sessionEnd = false }
        }
        guard let i = steps.firstIndex(of: step), i + 1 < steps.count else {
            completed = true
            return
        }
        withAnimation { step = steps[i + 1] }
    }

    private func skip() {
        dailyLine = false; retro = false; sessionEnd = false
        completed = true
    }
}

// MARK: - Appearance tiles

private struct AppearanceTiles: View {
    @Binding var selection: Appearance
    var fill: Color
    @Environment(\.dynamicTypeSize) private var typeSize

    private let order: [Appearance] = [.dark, .system, .light]

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            ForEach(order) { option in
                tile(option)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tile(_ option: Appearance) -> some View {
        let selected = option == selection
        let parts = Group {
            Thumbnail(option: option)
                .frame(width: typeSize.isAccessibilitySize ? 44 : 62, height: typeSize.isAccessibilitySize ? 80 : 112)
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(selected ? fill : .clear, lineWidth: 2.5)
                        .padding(-4)
                }
            Text(option.label).font(.subheadline)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? AnyShapeStyle(fill) : AnyShapeStyle(.tertiary))
        }
        return Button {
            selection = option
        } label: {
            if typeSize.isAccessibilitySize {
                HStack(spacing: 16) { parts }
            } else {
                VStack(spacing: 8) { parts }.frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A miniature Today in one scheme (or split for Auto): arc, two text bars
/// and the next-act panel with its yellow button.
private struct Thumbnail: View {
    var option: Appearance

    var body: some View {
        HStack(spacing: 0) {
            switch option {
            case .dark: pane(dark: true)
            case .light: pane(dark: false)
            case .system:
                pane(dark: true).frame(minWidth: 0, maxWidth: .infinity).clipped()
                pane(dark: false).frame(minWidth: 0, maxWidth: .infinity).clipped()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.primary.opacity(0.18), lineWidth: 1))
    }

    private func pane(dark: Bool) -> some View {
        let bg = dark ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97)
        let track = dark ? Color(white: 0.33) : Color(white: 0.78)
        let bar = dark ? Color(white: 0.23) : Color(white: 0.78)
        let card = dark ? Color(white: 0.11) : .white
        let accent = dark ? Color(red: 1.0, green: 0.831, blue: 0.2) : Color(red: 0.949, green: 0.769, blue: 0.11)
        return VStack(spacing: 5) {
            ZStack(alignment: .topLeading) {
                Circle().trim(from: 0.5, to: 1).stroke(track, lineWidth: 2).frame(width: 34, height: 34).offset(y: 0)
                Circle().fill(accent).frame(width: 6, height: 6).offset(x: 3, y: 5)
            }
            .frame(width: 34, height: 17, alignment: .top)
            .clipped()
            Capsule().fill(bar).frame(width: 40, height: 4)
            Capsule().fill(bar).frame(width: 30, height: 4)
            RoundedRectangle(cornerRadius: 6).fill(card).frame(width: 50, height: 22)
                .overlay(alignment: .bottom) { Capsule().fill(accent).frame(width: 36, height: 6).padding(.bottom, 4) }
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .frame(width: 62)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(bg)
    }
}

// MARK: - Promise arc

/// The Today arc at 11:00 with nothing done: the ritual as three markers on
/// the day. Same geometry as the Today prototype's SunArc.
private struct PromiseArc: View {
    var fill: Color
    var ink: Color
    private let fraction = (11.0 - 6) / 16
    private let marks: [(t: Double, symbol: String, name: LocalizedStringKey)] = [
        (0.125, "pencil.line", "Question"), (0.5, "checkmark", "Move"), (0.875, "moon.stars", "Retro")
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let r = min(w / 2 - 30, 132)
            let c = CGPoint(x: w / 2, y: r + 42)
            ZStack {
                Circle().trim(from: 0.5, to: 1)
                    .stroke(Color(.separator), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: r * 2, height: r * 2).position(c)
                Circle().trim(from: 0.5, to: 0.5 + fraction / 2)
                    .stroke(fill, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: r * 2, height: r * 2).position(c)
                ZStack {
                    Circle().fill(fill.opacity(0.25)).frame(width: 30, height: 30)
                    Circle().fill(fill).frame(width: 18, height: 18)
                }
                .position(point(fraction, c: c, r: r))
                ForEach(Array(marks.enumerated()), id: \.offset) { i, m in
                    let p = point(m.t, c: c, r: r)
                    marker(i, symbol: m.symbol).position(p)
                    Text(m.name).font(.caption2.weight(.semibold))
                        .foregroundStyle(i == 0 ? ink : .secondary)
                        .position(x: p.x + (i == 0 ? -16 : i == 2 ? 16 : 0), y: p.y - 28)
                }
                Text("06:00").font(.caption2).foregroundStyle(.secondary).position(x: c.x - r, y: c.y + 22)
                Text("22:00").font(.caption2).foregroundStyle(.secondary).position(x: c.x + r, y: c.y + 22)
            }
        }
        .frame(height: 200)
    }

    private func point(_ t: Double, c: CGPoint, r: CGFloat) -> CGPoint {
        let a = Double.pi * (1 - t)
        return CGPoint(x: c.x + r * cos(a), y: c.y - r * sin(a))
    }

    @ViewBuilder
    private func marker(_ i: Int, symbol: String) -> some View {
        if i == 0 {
            ZStack {
                Circle().fill(fill).frame(width: 28, height: 28)
                Image(systemName: symbol).font(.caption.weight(.semibold)).foregroundStyle(.black)
            }
        } else {
            ZStack {
                Circle().fill(Color(.systemGroupedBackground)).frame(width: 26, height: 26)
                Circle().stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).frame(width: 26, height: 26)
                Image(systemName: symbol).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingPrototypeView()
}
