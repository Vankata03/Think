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
}

struct ThinkingPath: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let icon: String
    let isAvailable: Bool
    let steps: [PathStep]
}

enum PathLibrary {

    static let all: [ThinkingPath] = [deepFocus, clearThinking, discipline, learningMachine]

    static let deepFocus = ThinkingPath(
        id: "deep-focus",
        name: "Deep focus",
        tagline: "21 days to a longer attention span",
        icon: "scope",
        isAvailable: true,
        steps: [
            PathStep(id: 1, title: "Notice the pull",
                     lesson: "Attention drifts by default. Before you can hold it, you have to see where it goes.",
                     task: "Work for 10 minutes on one thing. Keep a tally of every urge to switch. Just count — don't judge."),
            PathStep(id: 2, title: "One thing",
                     lesson: "Focus starts before the work: with a single, clearly defined target.",
                     task: "Pick your one most important task for today and write down what 'done' looks like. Then do it first."),
            PathStep(id: 3, title: "Distance beats willpower",
                     lesson: "You don't resist your phone with discipline — you resist it with distance.",
                     task: "Do one 25-minute session with your phone in another room."),
            PathStep(id: 4, title: "The two-minute start",
                     lesson: "Starting is the hardest part, so make the start laughably small.",
                     task: "Take the task you've been dreading and work on it for just two minutes. Continue only if you want to."),
            PathStep(id: 5, title: "Single-tab work",
                     lesson: "Every open tab is a promise to interrupt yourself.",
                     task: "Do one 25-minute session with a single window and a single tab open."),
            PathStep(id: 6, title: "Boredom training",
                     lesson: "If you can't be bored, you can't be focused. Boredom tolerance is the muscle underneath.",
                     task: "Sit for 10 minutes with no input — no phone, no music, no book. Just sit."),
            PathStep(id: 7, title: "Environment design",
                     lesson: "Your workspace makes decisions for you before you make any yourself.",
                     task: "Clear your workspace down to the essentials for the work in front of you."),
            PathStep(id: 8, title: "Two sessions",
                     lesson: "Focus builds like fitness: add volume gradually.",
                     task: "Complete two 25-minute sessions today with a real break between them."),
            PathStep(id: 9, title: "Notification audit",
                     lesson: "Every notification is someone else scheduling your attention.",
                     task: "Turn off every notification that doesn't come from a human who needs you."),
            PathStep(id: 10, title: "The longer block",
                     lesson: "Depth arrives around the point where you would usually stop.",
                     task: "Do one 50-minute session on a single task."),
            PathStep(id: 11, title: "The shutdown note",
                     lesson: "An open loop follows you around all evening. Close it on paper.",
                     task: "End your workday by writing down tomorrow's first task. One line is enough."),
            PathStep(id: 12, title: "Attention diet",
                     lesson: "Feeds are engineered against everything you've practiced so far.",
                     task: "Pick one feed or app and skip it entirely for the whole day."),
            PathStep(id: 13, title: "Returning is the skill",
                     lesson: "Focus isn't never drifting — it's noticing the drift and coming back without drama.",
                     task: "In one 25-minute session, count how many times you return after drifting. Each return is a rep."),
            PathStep(id: 14, title: "Hardest thing first",
                     lesson: "Willpower is highest early. Spend it on what matters, not on email.",
                     task: "Do your most demanding task before anything easy today."),
            PathStep(id: 15, title: "Batch the shallow",
                     lesson: "Messages expand to fill every gap you leave them.",
                     task: "Handle all messages and email in one or two fixed windows today — nothing in between."),
            PathStep(id: 16, title: "Rest is part of work",
                     lesson: "Recovery isn't the opposite of focus; it's what pays for the next block.",
                     task: "Take one real break today: a walk, outside if you can, phone left behind."),
            PathStep(id: 17, title: "Two deep blocks",
                     lesson: "You're ready for more volume at depth.",
                     task: "Complete two 50-minute sessions today."),
            PathStep(id: 18, title: "Say no once",
                     lesson: "Every yes is a claim on future attention. Guard it.",
                     task: "Decline one request, invitation, or task today that doesn't deserve your focus."),
            PathStep(id: 19, title: "The review",
                     lesson: "What pulled your attention this week will pull it next week — unless you name it.",
                     task: "Spend 10 minutes writing down your three biggest attention leaks from this path so far."),
            PathStep(id: 20, title: "Design tomorrow",
                     lesson: "A planned morning doesn't negotiate with distractions.",
                     task: "Tonight, write down tomorrow's single priority and when you'll do it."),
            PathStep(id: 21, title: "Own your attention",
                     lesson: "Three weeks of reps. This is the graduation set.",
                     task: "Do 90 minutes of deep work today, split into sessions however you choose."),
        ]
    )

    static let clearThinking = ThinkingPath(
        id: "clear-thinking", name: "Clear thinking",
        tagline: "Mental models, biases, judgment",
        icon: "lightbulb", isAvailable: false, steps: []
    )

    static let discipline = ThinkingPath(
        id: "discipline", name: "Discipline",
        tagline: "Habits, consistency, showing up",
        icon: "figure.strengthtraining.traditional", isAvailable: false, steps: []
    )

    static let learningMachine = ThinkingPath(
        id: "learning-machine", name: "Learning machine",
        tagline: "Reading, retention, curiosity",
        icon: "book", isAvailable: false, steps: []
    )
}
