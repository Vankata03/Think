# 011 — Let the evening retrospective reminder through Focus modes

- **Status**: TODO
- **Severity**: LOW
- **Category**: Missed opportunity
- **Estimated scope**: 2–3 files, about 40 lines including tests
- **Depends on**: —

## Problem

The evening retrospective reminder is a plain notification (`Think/State/RetroReminder.swift:36`):

```swift
let content = UNMutableNotificationContent()
content.title = String(localized: "Evening retrospective")
content.body = String(localized: "Close the day. Two honest minutes.")
content.sound = .default
```

Its default `interruptionLevel` (`.active`) means an evening Wind Down, Sleep, or Do Not Disturb Focus silences exactly the reminder whose whole purpose is to fire at the end of the day. The users most likely to run an evening Focus are the ones this app is for.

## Target

- Set `content.interruptionLevel = .timeSensitive` on the retro reminder.
- Add `com.apple.developer.usernotifications.time-sensitive` to `Think/Think.entitlements` and enable the Time Sensitive Notifications capability on the iOS target.
- Leave the daily-line notification (`Think/State/DailyQuoteNotifier.swift`) at its current level — a motivational line is not time sensitive, and marking it so would be the abuse pattern Apple's review guidance calls out.

Time Sensitive delivery is still user-controllable per app in Settings, so this raises the ceiling without taking away the user's control.

## Verification

- Unit test over the content builder (extract it if the current shape does not allow direct assertion): the retro content has `.timeSensitive`, the daily-line content does not.
- Manual: enable a Do Not Disturb Focus that permits time-sensitive notifications, set the retro reminder a minute ahead, confirm delivery; confirm the daily line stays suppressed under the same Focus.

## Out of scope

- Critical alerts (needs a separate Apple entitlement and is not justified here).
- Any change to the retro reminder's scheduling or copy.
