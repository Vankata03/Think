//
//  ThinkingPath.swift
//  Think
//

import Foundation

// Codable for future remote content delivery (see PLAN.md).
struct PathStep: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let lesson: String
    let task: String
    /// Active task minutes; tasks explicitly name additional breaks or all-day experiments.
    let estimatedMinutes: Int
    let smallerTask: String?
    let suggestedFocusMinutes: Int?
    let suggestedIntention: String?

    init(id: Int, title: String, lesson: String, task: String, estimatedMinutes: Int = 10,
         smallerTask: String? = nil, suggestedFocusMinutes: Int? = nil, suggestedIntention: String? = nil) {
        self.id = id; self.title = title; self.lesson = lesson; self.task = task
        self.estimatedMinutes = estimatedMinutes; self.smallerTask = smallerTask
        self.suggestedFocusMinutes = suggestedFocusMinutes; self.suggestedIntention = suggestedIntention
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, lesson, task, estimatedMinutes, smallerTask, suggestedFocusMinutes, suggestedIntention
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        lesson = try c.decode(String.self, forKey: .lesson)
        task = try c.decode(String.self, forKey: .task)
        estimatedMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 10
        smallerTask = try c.decodeIfPresent(String.self, forKey: .smallerTask)
        suggestedFocusMinutes = try c.decodeIfPresent(Int.self, forKey: .suggestedFocusMinutes)
        suggestedIntention = try c.decodeIfPresent(String.self, forKey: .suggestedIntention)
    }
}

struct ThinkingPath: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let icon: String
    let isAvailable: Bool
    let steps: [PathStep]
    var continuation: String? = nil

    /// The step to work on given how many days are complete, or nil
    /// once the path is finished. Shared so iOS and watchOS resolve
    /// the current step identically.
    func currentStep(afterCompleted completed: Int) -> PathStep? {
        guard completed >= 0, completed < steps.count else { return nil }
        return steps[completed]
    }
}

enum PathLibrary {

    static let deepFocus = localized(sourceDeepFocus)
    static let clearThinking = localized(sourceClearThinking)
    static let discipline = localized(sourceDiscipline)
    static let learningMachine = localized(sourceLearningMachine)

    static let all: [ThinkingPath] = [deepFocus, clearThinking, discipline, learningMachine]

    private static let sourceDeepFocus = ThinkingPath(
        id: "deep-focus",
        name: "Deep focus",
        tagline: "21 lessons to practice attention at your pace",
        icon: "scope",
        isAvailable: true,
        steps: [
            PathStep(id: 1, title: "Notice the pull",
                     lesson: "Attention drifts by default. Before you can hold it, you have to see where it goes.",
                     task: "Work for 10 minutes on one thing. Keep a tally of every urge to switch. Just count — don't judge.",
                     estimatedMinutes: 10, smallerTask: "Spend two minutes on one thing and notice one urge to switch.",
                     suggestedFocusMinutes: 10, suggestedIntention: "Notice the pull"),
            PathStep(id: 2, title: "One thing",
                     lesson: "Focus starts before the work: with a single, clearly defined target.",
                     task: "Spend 10 minutes defining one important task and what 'done' looks like, then begin its first step.",
                     estimatedMinutes: 10, smallerTask: "Write one sentence describing the first step and what done means.",
                     suggestedFocusMinutes: 10, suggestedIntention: "One thing"),
            PathStep(id: 3, title: "Distance beats willpower",
                     lesson: "You don't resist your phone with discipline — you resist it with distance.",
                     task: "Do one 25-minute session with your phone in another room.",
                     estimatedMinutes: 25, smallerTask: "Put your phone out of reach and focus for five minutes.",
                     suggestedFocusMinutes: 25, suggestedIntention: "Distance beats willpower"),
            PathStep(id: 4, title: "The two-minute start",
                     lesson: "Starting is the hardest part, so make the start laughably small.",
                     task: "Take the task you've been dreading and work on it for just two minutes. Continue only if you want to.",
                     estimatedMinutes: 2, smallerTask: "Open the task and name its first action. Starting can wait.",
                     suggestedFocusMinutes: nil, suggestedIntention: "The two-minute start"),
            PathStep(id: 5, title: "Single-tab work",
                     lesson: "Every open tab is a promise to interrupt yourself.",
                     task: "Do one 25-minute session with a single window and a single tab open.",
                     estimatedMinutes: 25, smallerTask: "Close one unused tab and work for five minutes.",
                     suggestedFocusMinutes: 25, suggestedIntention: "Single-tab work"),
            PathStep(id: 6, title: "Boredom training",
                     lesson: "If you can't be bored, you can't be focused. Boredom tolerance is the muscle underneath.",
                     task: "Sit for 10 minutes with no input — no phone, no music, no book. Just sit.",
                     estimatedMinutes: 10, smallerTask: "Try one quiet minute without input; stop if it feels unhelpful.",
                     suggestedFocusMinutes: nil, suggestedIntention: "Boredom training"),
            PathStep(id: 7, title: "Environment design",
                     lesson: "Your workspace makes decisions for you before you make any yourself.",
                     task: "Spend five minutes clearing your workspace to the essentials for the work in front of you.",
                     estimatedMinutes: 5, smallerTask: "Move one distracting object away from your workspace.",
                     suggestedFocusMinutes: nil, suggestedIntention: "Environment design"),
            PathStep(id: 8, title: "Two sessions",
                     lesson: "Focus builds like fitness: add volume gradually.",
                     task: "Complete two 25-minute sessions today, plus a real break between them. The estimate covers 50 active minutes.",
                     estimatedMinutes: 50, smallerTask: "Complete one five-minute session, then take a break.",
                     suggestedFocusMinutes: 25, suggestedIntention: "Two sessions"),
            PathStep(id: 9, title: "Notification audit",
                     lesson: "Every notification is someone else scheduling your attention.",
                     task: "Spend five minutes reviewing notifications. Keep the alerts you need and silence one unnecessary source.",
                     estimatedMinutes: 5, smallerTask: "Silence one notification you do not need.",
                     suggestedFocusMinutes: nil, suggestedIntention: "Notification audit"),
            PathStep(id: 10, title: "The longer block",
                     lesson: "Depth arrives around the point where you would usually stop.",
                     task: "Do one 50-minute session on a single task.",
                     estimatedMinutes: 50, smallerTask: "Try one five-minute block on the same task.",
                     suggestedFocusMinutes: 50, suggestedIntention: "The longer block"),
            PathStep(id: 11, title: "The shutdown note",
                     lesson: "An open loop follows you around all evening. Close it on paper.",
                     task: "Spend five minutes writing tomorrow's first task. One line is enough.",
                     estimatedMinutes: 5, smallerTask: "Write tomorrow's first action in one sentence.",
                     suggestedFocusMinutes: nil, suggestedIntention: "The shutdown note"),
            PathStep(id: 12, title: "Attention diet",
                     lesson: "Feeds are engineered against everything you've practiced so far.",
                     task: "Take five minutes to choose a feed to skip and a helpful replacement. Try the experiment during the day.",
                     estimatedMinutes: 5, smallerTask: "Pause one feed for five minutes and choose what to do instead.",
                     suggestedFocusMinutes: nil, suggestedIntention: "Attention diet"),
            PathStep(id: 13, title: "Returning is the skill",
                     lesson: "Focus isn't never drifting — it's noticing the drift and coming back without drama.",
                     task: "In one 25-minute session, count how many times you return after drifting. Each return is a rep.",
                     estimatedMinutes: 25, smallerTask: "Notice and gently return once during five minutes of work.",
                     suggestedFocusMinutes: 25, suggestedIntention: "Returning is the skill"),
            PathStep(id: 14, title: "Hardest thing first",
                     lesson: "Give demanding work a time when you usually have energy. That time is different for different people.",
                     task: "Reserve 25 minutes for a demanding task at a time when you usually have energy.",
                     estimatedMinutes: 25, smallerTask: "Choose an energy-friendly time for one five-minute task.",
                     suggestedFocusMinutes: 25, suggestedIntention: "Hardest thing first"),
            PathStep(id: 15, title: "Batch the shallow",
                     lesson: "Messages expand to fill every gap you leave them.",
                     task: "Plan two 10-minute message windows today. Keep exceptions for people or work that need a timely reply.",
                     estimatedMinutes: 20, smallerTask: "Choose one five-minute window for messages, allowing urgent exceptions.",
                     suggestedFocusMinutes: nil, suggestedIntention: "Batch the shallow"),
            PathStep(id: 16, title: "Rest is part of work",
                     lesson: "Recovery isn't the opposite of focus; it's what pays for the next block.",
                     task: "Take a 10-minute break: a walk if that suits you, or another form of rest, with your phone out of reach.",
                     estimatedMinutes: 10, smallerTask: "Take two minutes of rest in a way that suits your body.",
                     suggestedFocusMinutes: nil, suggestedIntention: "Rest is part of work"),
            PathStep(id: 17, title: "Two deep blocks",
                     lesson: "You're ready for more volume at depth.",
                     task: "Complete two 50-minute sessions today, plus a real break between them. The estimate covers 100 active minutes.",
                     estimatedMinutes: 100, smallerTask: "Try one five-minute block; more volume is optional.",
                     suggestedFocusMinutes: 50, suggestedIntention: "Two deep blocks"),
            PathStep(id: 18, title: "Say no once",
                     lesson: "Every yes is a claim on future attention. Guard it.",
                     task: "Spend five minutes drafting a respectful no to one request that does not fit your capacity.",
                     estimatedMinutes: 5, smallerTask: "Draft one sentence declining or reducing a request.",
                     suggestedFocusMinutes: nil, suggestedIntention: "Say no once"),
            PathStep(id: 19, title: "The review",
                     lesson: "What pulled your attention this week will pull it next week — unless you name it.",
                     task: "Spend 10 minutes writing down your three biggest attention leaks from this path so far.",
                     estimatedMinutes: 10, smallerTask: "Write down one attention leak and one possible change.",
                     suggestedFocusMinutes: nil, suggestedIntention: "The review"),
            PathStep(id: 20, title: "Design tomorrow",
                     lesson: "A planned morning doesn't negotiate with distractions.",
                     task: "Spend five minutes writing tomorrow's single priority and when you will do it.",
                     estimatedMinutes: 5, smallerTask: "Write tomorrow's first step and a possible starting time.",
                     suggestedFocusMinutes: nil, suggestedIntention: "Design tomorrow"),
            PathStep(id: 21, title: "Own your attention",
                     lesson: "Three weeks of reps. This is the graduation set.",
                     task: "Do 90 active minutes of focused work, split into sessions that suit you, with extra time for breaks.",
                     estimatedMinutes: 90, smallerTask: "Try five minutes using one thing you learned; choose what to repeat.",
                     suggestedFocusMinutes: 25, suggestedIntention: "Own your attention"),
        ]
    )

    private static let sourceClearThinking = ThinkingPath(
        id: "clear-thinking", name: "Clear thinking",
        tagline: "A seven-lesson introduction to clearer decisions",
        icon: "lightbulb", isAvailable: true, steps: [
            PathStep(id: 1, title: "Fact and story",
                     lesson: "A fact describes something you could observe. A story adds an interpretation. Both can matter, but separating them makes a next step easier to choose.",
                     task: "Save a note with two headings: What happened and What I made it mean. Put one sentence under each.", estimatedMinutes: 10,
                     smallerTask: "Save one observable fact without a prediction.", suggestedFocusMinutes: 10,
                     suggestedIntention: "Fact and story"),
            PathStep(id: 2, title: "Your next step",
                     lesson: "Control is rarely all or nothing. You may influence a small part of a difficult situation without being responsible for the whole outcome.",
                     task: "Save two lists: What I can act on and What is outside my control. Circle one small next step.", estimatedMinutes: 10,
                     smallerTask: "Save one action within your control.", suggestedFocusMinutes: 10,
                     suggestedIntention: "Your next step"),
            PathStep(id: 3, title: "The hidden assumption",
                     lesson: "Plans often depend on something we have not checked. An assumption is a useful question to investigate, not proof that your plan is wrong.",
                     task: "Save one plan, the assumption it depends on, and a small way to check that assumption.", estimatedMinutes: 10,
                     smallerTask: "Save one sentence beginning: I am assuming that…", suggestedFocusMinutes: 10,
                     suggestedIntention: "The hidden assumption"),
            PathStep(id: 4, title: "Evidence that could change your mind",
                     lesson: "A belief is easier to update when you decide in advance what evidence would matter. Seek a source that could challenge you, and allow uncertainty.",
                     task: "Save one belief, one piece of evidence for it, and one finding that would make you reconsider it.", estimatedMinutes: 10,
                     smallerTask: "Save one thing you would need to learn before becoming more certain.", suggestedFocusMinutes: 10,
                     suggestedIntention: "Evidence that could change your mind"),
            PathStep(id: 5, title: "A reversible choice",
                     lesson: "Some decisions can be tested cheaply; others deserve more care. Name the cost and a way back before calling a choice reversible.",
                     task: "Save one small decision, its possible cost, a way to undo it, and a date to review what happened.", estimatedMinutes: 10,
                     smallerTask: "Save one low-cost step and a way to stop it.", suggestedFocusMinutes: 10,
                     suggestedIntention: "A reversible choice"),
            PathStep(id: 6, title: "A fair disagreement",
                     lesson: "Understanding a view does not require agreement. A fair summary gives the other person a position they could recognize, without inventing their motives.",
                     task: "Save a fair three-sentence summary of a disagreement, then add one question you could ask with curiosity.", estimatedMinutes: 10,
                     smallerTask: "Save one sentence the other person might recognize as their view.", suggestedFocusMinutes: 10,
                     suggestedIntention: "A fair disagreement"),
            PathStep(id: 7, title: "Review one decision",
                     lesson: "A result alone cannot tell you whether a decision was sensible. Review what you knew then, what happened, and what you want to try next.",
                     task: "Save a decision review: What I knew, What happened, What I learned, and My next experiment. Choose a lesson to repeat.", estimatedMinutes: 10,
                     smallerTask: "Save one lesson from a decision and one next step.", suggestedFocusMinutes: 10,
                     suggestedIntention: "Review one decision"),
        ],
        continuation: "You finished the seven-lesson introduction. Repeat a lesson with a new decision, or start a fresh seven-lesson run. A longer track is still in development."
    )

    private static let sourceDiscipline = ThinkingPath(
        id: "discipline", name: "Discipline",
        tagline: "Habits, consistency, showing up",
        icon: "figure.strengthtraining.traditional", isAvailable: false, steps: []
    )

    private static let sourceLearningMachine = ThinkingPath(
        id: "learning-machine", name: "Learning machine",
        tagline: "Reading, retention, curiosity",
        icon: "book", isAvailable: false, steps: []
    )

    private static func localized(_ source: ThinkingPath) -> ThinkingPath {
        let base = "path.\(source.id)"
        return ThinkingPath(
            id: source.id,
            name: localizedContent("\(base).name", fallback: source.name),
            tagline: localizedContent("\(base).tagline", fallback: source.tagline),
            icon: source.icon,
            isAvailable: source.isAvailable,
            steps: source.steps.map { step in
                let stepBase = "\(base).step.\(step.id)"
                return PathStep(
                    id: step.id,
                    title: localizedContent("\(stepBase).title", fallback: step.title),
                    lesson: localizedContent("\(stepBase).lesson", fallback: step.lesson),
                    task: localizedContent("\(stepBase).task", fallback: step.task),
                    estimatedMinutes: step.estimatedMinutes,
                    smallerTask: step.smallerTask.map { localizedContent("\(stepBase).smallerTask", fallback: $0) },
                    suggestedFocusMinutes: step.suggestedFocusMinutes,
                    suggestedIntention: step.suggestedIntention.map {
                        localizedContent("\(stepBase).title", fallback: $0)
                    }
                )
            },
            continuation: source.continuation.map { localizedContent("\(base).continuation", fallback: $0) }
        )
    }

    private static func localizedContent(_ key: String, fallback: String) -> String {
        Bundle.main.localizedString(forKey: key, value: fallback, table: "Content")
    }
}
