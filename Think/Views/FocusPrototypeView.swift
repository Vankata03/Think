//
//  FocusPrototypeView.swift
//  Think
//
//  PROTOTYPE — throwaway. Answers "P3 Stage + W2 arc and wheel" for the
//  Focus redesign ticket (#76). Lives on branch prototype/focus-stage only;
//  never merged. Drives the real PomodoroTimer so the running, paused and
//  break states can be judged on device. A "Prototype" toolbar menu fakes a
//  finished work phase so the break state can be seen without waiting.
//

import SwiftUI

/// `accent` from design/design-system.md: fills only, black ink on top.
private func accentFill(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 1.0, green: 0.831, blue: 0.2) : Color(red: 0.949, green: 0.769, blue: 0.11)
}
/// `accentInk`: text and tinted symbols.
private func accentInk(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 1.0, green: 0.831, blue: 0.2) : Color(red: 0.431, green: 0.361, blue: 0.02)
}

struct FocusPrototypeView: View {
    @Environment(PomodoroTimer.self) private var timer
    @Environment(JournalLock.self) private var journalLock
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.haptics) private var haptics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var intentionDraft = ""
    @State private var workMinutes = 25
    @State private var breakMinutes = 5
    @State private var confirmingEnd = false
    /// Prototype lever: pretend a work phase just finished.
    @State private var fakeBreak = false
    @FocusState private var intentionFocused: Bool

    private static let workSteps = Array(stride(from: 5, through: 120, by: 5))
    private static let breakSteps = Array(1...30)

    /// A session exists once Start was pressed and until it ends: running or paused mid-phase.
    private var inSession: Bool {
        timer.isRunning || timer.remainingSeconds != timer.phaseTotalSeconds || timer.phase == .rest || fakeBreak
    }
    private var inBreak: Bool { timer.phase == .rest || fakeBreak }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headline
                        .padding(.top, 12)
                    hero
                        .padding(.top, 20)
                    if !inSession {
                        wheel
                            .padding(.top, 4)
                    }
                    lastSessionLink
                        .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: inSession)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { prototypeMenu } }
            .safeAreaBar(edge: .bottom) { controls.padding(.bottom, 8) }
            .confirmationDialog("End this session?", isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button("End session", role: .destructive) {
                    haptics.play(.reset)
                    fakeBreak = false
                    timer.reset()
                }
            } message: {
                Text("The time you've done so far is kept as partial effort.")
            }
            .onAppear {
                timer.resync()
                intentionDraft = journalLock.isLocked ? "" : (timer.intention ?? "")
                workMinutes = timer.preset.workMinutes
                breakMinutes = timer.preset.restMinutes
            }
            .onChange(of: timer.automaticTransitionCount) { haptics.play(.success) }
        }
    }

    // MARK: - Headline (the intention, in serif)

    @ViewBuilder
    private var headline: some View {
        if inSession {
            Text(timer.intention ?? String(localized: "Deep work"))
                .font(.system(.title2, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(timer.intention == nil ? .secondary : .primary)
        } else if journalLock.isLocked {
            Button { Task { if await journalLock.authenticate() { intentionDraft = timer.intention ?? "" } } } label: {
                Label("Unlock private intention", systemImage: "lock")
            }
        } else {
            VStack(spacing: 6) {
                TextField("What are you working on?", text: $intentionDraft, axis: .vertical)
                    .font(.system(.title2, design: .serif))
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .focused($intentionFocused)
                    .onSubmit { commitIntention() }
                    .onChange(of: intentionFocused) { _, focused in if !focused { commitIntention() } }
                if intentionDraft.isEmpty, let suggestion = timer.suggestedIntention() {
                    Button {
                        haptics.play(.selection)
                        intentionDraft = suggestion
                        commitIntention()
                    } label: {
                        Label(suggestion, systemImage: "arrow.uturn.backward")
                            .font(.subheadline)
                            .foregroundStyle(accentInk(colorScheme))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reuse intention: \(suggestion)")
                }
            }
        }
    }

    private func commitIntention() {
        guard !journalLock.isLocked else { return }
        let capped = String(intentionDraft.prefix(PomodoroTimer.intentionMaxLength))
        guard timer.intention != PomodoroTimer.normalizedIntention(capped) else { return }
        timer.setIntention(capped)
    }

    // MARK: - Hero: the arc, or a bar at accessibility sizes

    private var workFraction: Double {
        let w = Double(inSession ? timer.preset.workMinutes : workMinutes)
        let b = Double(inSession ? timer.preset.restMinutes : breakMinutes)
        return w / (w + b)
    }
    /// Where the sun sits along the whole arc (work plus break).
    private var sunFraction: Double {
        guard inSession else { return 0 }
        if inBreak { return workFraction + (fakeBreak ? 0.3 : timer.progress) * (1 - workFraction) }
        return timer.progress * workFraction
    }
    private func clock(_ minutesFromNow: Double) -> String {
        Date.now.addingTimeInterval(minutesFromNow * 60).formatted(date: .omitted, time: .shortened)
    }
    /// End of the work phase and of the break, as clock times.
    private var workEnd: String {
        if !inSession { return clock(Double(workMinutes)) }
        if inBreak { return String(localized: "done") }
        return clock(Double(timer.remainingSeconds) / 60)
    }
    private var breakEnd: String {
        if !inSession { return clock(Double(workMinutes + breakMinutes)) }
        if inBreak { return clock(Double(timer.remainingSeconds) / 60) }
        return clock(Double(timer.remainingSeconds) / 60 + Double(timer.preset.restMinutes))
    }

    @ViewBuilder
    private var hero: some View {
        VStack(spacing: 14) {
            if inBreak {
                let minutes = timer.lastSessionRecord?.durationMinutes ?? timer.preset.workMinutes
                Label("Session done · \(minutes) min", systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.monochrome)
                    .labelStyle(DoneLabelStyle())
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    countdown
                    caption
                    ProgressView(value: sunFraction)
                        .tint(inBreak ? .green : accentFill(colorScheme))
                    HStack { Text(inSession ? "" : "now"); Spacer(); Text(breakEnd) }
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                FocusArc(workFraction: workFraction, sunFraction: sunFraction, inSession: inSession, inBreak: inBreak,
                         accent: accentFill(colorScheme), ink: accentInk(colorScheme),
                         workEnd: workEnd, breakEnd: breakEnd, reduceMotion: reduceMotion) {
                    VStack(spacing: 4) { countdown; caption }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var countdown: some View {
        Text(inSession ? timer.remainingLabel : String(format: "%d:00", workMinutes))
            .font(.system(.largeTitle, design: .rounded, weight: .medium))
            .scaleEffect(dynamicTypeSize.isAccessibilitySize ? 1 : 1.55)
            .monospacedDigit()
            .contentTransition(.numericText())
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 0 : 10)
    }

    @ViewBuilder
    private var caption: some View {
        Group {
            if !inSession {
                Text("then \(Text("\(breakMinutes) min break").foregroundStyle(.green).fontWeight(.semibold))")
            } else if inBreak {
                Text("Break").foregroundStyle(.green)
            } else {
                Text(timer.isRunning ? "until \(workEnd)" : "Paused")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    // MARK: - Wheel: work and break minutes

    private var wheel: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 0))
        return layout {
            wheelColumn("Work", selection: $workMinutes, values: Self.workSteps, tint: accentInk(colorScheme))
            wheelColumn("Break", selection: $breakMinutes, values: Self.breakSteps, tint: .green)
        }
        .onChange(of: workMinutes) { applyDuration() }
        .onChange(of: breakMinutes) { applyDuration() }
    }

    private func wheelColumn(_ title: LocalizedStringKey, selection: Binding<Int>, values: [Int], tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { v in
                    Text("\(v) \(Text("min").foregroundStyle(tint).fontWeight(.semibold))").tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 160 : 120)
            .clipped()
        }
        .frame(maxWidth: .infinity)
    }

    private func applyDuration() {
        if workMinutes == 25, breakMinutes == 5 { timer.select(.classic) }
        else if workMinutes == 50, breakMinutes == 10 { timer.select(.long) }
        else { _ = timer.selectCustom(workMinutes: workMinutes, restMinutes: breakMinutes) }
    }

    // MARK: - Last session

    /// Plain text, not a link: history lives on Progress and there is no detail behind it.
    @ViewBuilder
    private var lastSessionLink: some View {
        if let session = timer.lastSessionRecord {
            Text("Last session · \(session.durationMinutes) min · \(session.completedAt.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Controls, pinned above the tab bar

    private var controls: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            if inSession && !inBreak {
                Button("End") { confirmingEnd = true }
                    .buttonStyle(.glass).controlSize(.large)
            }
            Button {
                commitIntention()
                haptics.play(timer.isRunning ? .pause : .start)
                if fakeBreak { fakeBreak = false }
                timer.toggle()
            } label: {
                Label(timer.isRunning ? "Pause" : (inSession ? "Resume" : "Start"),
                      systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                    .frame(minWidth: 120)
                    .foregroundStyle(.black)
            }
            .buttonStyle(.glassProminent)
            .tint(accentFill(colorScheme))
            .controlSize(.large)
            if inSession {
                Button(inBreak ? "Skip to work" : "Skip") {
                    haptics.play(.selection)
                    fakeBreak = false
                    timer.skipPhase()
                }
                .buttonStyle(.glass).controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Prototype levers

    private var prototypeMenu: some View {
        Menu {
            Button("Fake: work phase just finished") { fakeBreak = true }
            Button("Clear fake break") { fakeBreak = false }
        } label: {
            Label("Prototype", systemImage: "slider.horizontal.3")
        }
    }
}

/// The checkmark in `success` green, the text in secondary.
private struct DoneLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) { configuration.icon.foregroundStyle(.green); configuration.title }
    }
}

// MARK: - Arc

/// The session as a half circle: the work part (track, then `accent` as it
/// elapses) and a green break tail. The sun rides at now; the end of work and
/// the end of the break are captioned as clock times.
private struct FocusArc<Center: View>: View {
    var workFraction: Double
    var sunFraction: Double
    var inSession: Bool
    var inBreak: Bool
    var accent: Color
    var ink: Color
    var workEnd: String
    var breakEnd: String
    var reduceMotion: Bool
    @ViewBuilder var center: () -> Center

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let r = min(w / 2 - 24, 136)
            let c = CGPoint(x: w / 2, y: r + 30)
            let gap = 0.012
            ZStack {
                arc(0, workFraction - gap)
                    .stroke(Color(.separator), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: r * 2, height: r * 2).position(c)
                arc(workFraction + gap, 1)
                    .stroke(Color.green.opacity(inSession ? 0.45 : 0.55),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: inSession ? [] : [4, 5]))
                    .frame(width: r * 2, height: r * 2).position(c)
                arc(0, min(sunFraction, workFraction - gap))
                    .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: r * 2, height: r * 2).position(c)
                if sunFraction > workFraction {
                    arc(workFraction + gap, sunFraction)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: r * 2, height: r * 2).position(c)
                }
                Circle().fill(Color(.systemBackground)).overlay(Circle().stroke(Color.green, lineWidth: 1.5))
                    .frame(width: 8, height: 8)
                    .modifier(OnArc(fraction: workFraction, center: c, radius: r))
                sun
                    .modifier(OnArc(fraction: sunFraction, center: c, radius: r))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: sunFraction)
                Text(workEnd)
                    .font(.caption2.weight(.semibold)).foregroundStyle(ink)
                    .modifier(OnArc(fraction: workFraction, center: c, radius: r + 22))
                center().position(x: c.x, y: c.y - 44)
                Text(inSession ? "" : String(localized: "now"))
                    .font(.caption2).foregroundStyle(.secondary).position(x: c.x - r, y: c.y + 26)
                Text(breakEnd)
                    .font(.caption2.weight(.semibold)).foregroundStyle(.green).position(x: c.x + r, y: c.y + 26)
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: workFraction)
        }
        .frame(height: 200)
    }

    private var sun: some View {
        Circle().fill(inBreak ? Color.green : accent)
            .frame(width: 24, height: 24)
            .background(Circle().fill((inBreak ? Color.green : accent).opacity(0.18)).frame(width: 44, height: 44))
    }

    private func arc(_ from: Double, _ to: Double) -> some Shape {
        Circle().trim(from: 0.5 + max(0, from) / 2, to: 0.5 + max(max(0, from), to) / 2)
    }
}

/// Positions a view on the arc at `fraction` (0 = left end, 1 = right end)
/// and animates along the curve, because the fraction is the animatable value.
private struct OnArc: ViewModifier, Animatable {
    var fraction: Double
    var center: CGPoint
    var radius: CGFloat

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func body(content: Content) -> some View {
        let a = Double.pi * (1 - fraction)
        content.position(x: center.x + radius * cos(a), y: center.y - radius * sin(a))
    }
}

// MARK: - Bottom accessory

/// Shown above the tab bar while a session runs or is paused and another tab
/// is selected. Countdown, intention, pause/resume; tapping opens Focus.
struct FocusAccessoryPrototype: View {
    @Environment(PomodoroTimer.self) private var timer
    @Environment(AppIntentRouter.self) private var router
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .foregroundStyle(timer.phase == .rest ? .green : accentInk(colorScheme))
            Text(timer.remainingLabel)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text(timer.intention ?? (timer.phase == .rest ? String(localized: "Break") : String(localized: "Deep work")))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button {
                timer.toggle()
            } label: {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
            }
            .accessibilityLabel(timer.isRunning ? "Pause" : "Resume")
        }
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { router.selectedTab = .focus }
    }
}
