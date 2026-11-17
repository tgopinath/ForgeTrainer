# Forge: Apple HIG components audit

Audited 2026-11-17 against Apple's Human Interface Guidelines, Components
(https://developer.apple.com/design/human-interface-guidelines/components), on iOS 26.1 Simulator (iPhone 17 Pro).
Checked in light, dark and Accessibility Extra Large text with the UI tests `testPortfolioShots` (`-portfolioDemo` data) and `testEveryScreen`.

Status: **Fixed**, **Kept** (already follows the HIG, no change needed) or **Open** (not done yet).

## Already in line with the HIG (Kept)

| Area | What the app does |
|---|---|
| Tab bar | Stock `TabView` with four SF Symbol tabs. Goal is a sheet, not a fifth tab. |
| Menus | Switch workout, Sleep and Energy use stock `Menu`. |
| Confirmation dialogs | Rebuild plan and Discard workout use `confirmationDialog` with a destructive role. |
| Charts | Swift Charts with accessibility labels. |
| Full-screen workout | `fullScreenCover` for the focused logging task. |
| Haptics | `sensoryFeedback` for completed sets and the end of a rest. |
| Exercise animations | Already stop with Reduce Motion (`ExerciseFigure`). |

## Findings and fixes

| # | Screen | Finding | Fix | Status |
|---|---|---|---|---|
| 1 | All | Every number and headline used fixed point sizes (`Theme.display/mono(size)`), so most of the UI ignored Dynamic Type. | `Theme.display/mono` now map each size to the matching text style, so everything scales and default sizes are unchanged. Fixed icon sizes now use text styles. | Fixed |
| 2 | Today, Plan, Progress, Coach | There were no navigation bars: titles were plain text inside the scroll view. | Each tab is in a `NavigationStack` with a large title (Coach uses an inline title). The goal button moved to the toolbar, and Coach's Clear moved to the toolbar behind a confirmation. | Fixed |
| 3 | Goal sheet | It was a custom card of hand-built controls with no navigation bar or Cancel. | Rebuilt as a stock `Form` with sections, an inline goal `Picker` with checkmarks, menu pickers, a segmented unit picker, `LabeledContent` number fields, `DatePicker`, `Stepper`, `Toggle` and a Cancel button. Training days are 44pt toggle buttons, in two rows at accessibility sizes. | Fixed |
| 4 | Exercise detail | It was a large-only sheet with no explicit dismiss for VoiceOver users. | `.medium` and `.large` detents, a navigation title and a Done button. | Fixed |
| 5 | Workout | The custom header held Finish and the title, with no navigation bar. | Inline navigation title with Finish as the toolbar confirmation action. The header now shows set progress and the timer, with a labelled `ProgressView`. | Fixed |
| 6 | Workout | Set rows had unlabelled weight and reps fields, and the "+15s" and "Skip" rest buttons were small. | VoiceOver labels on every field ("Set 2 weight in kg"), large rest buttons, a "Rest over" announcement, and a rest bar that stacks at accessibility sizes. Field borders appear under Increase Contrast. | Fixed |
| 7 | Colour | The caption grey `ink3` (#8E93A0) was 2.9:1 on the page background, failing WCAG AA. | Changed to #666B7A (4.7:1); dark mode is unchanged at 5:1 or better. | Fixed |
| 8 | Colour | Theme colours ignored Increase Contrast. The page background and cards were custom hex values. | Theme colours move 25% toward black or white under Increase Contrast. The background and cards use the system grouped colours. | Fixed |
| 9 | Hero and day cards | White text on muscle-group gradients was about 3:1 (orange, teal, green). | `heroGradient()` starts 22% darker, and text opacity was raised, so white text passes AA (about 5:1). | Fixed |
| 10 | Today | The water chip used tap and long-press gestures, which have no button semantics. | Now a `Button`, with a context menu and a VoiceOver action to reset it. | Fixed |
| 11 | Today | At accessibility sizes the three rings and three habit chips were crushed into one row, and the week circles truncated. | Rings and chips stack vertically. The week strips cap their text at the largest non-accessibility size, and VoiceOver reads each day in full. | Fixed |
| 12 | Toasts | Toasts were visual only, and they slid even with Reduce Motion on. | Each toast is posted as a VoiceOver announcement, and it fades instead of sliding when Reduce Motion is on. | Fixed |
| 13 | Progress | Empty states were plain text. | `ContentUnavailableView` for no trend, no best lifts and no sessions. The summary card and the weight entry stack when they don't fit. | Fixed |
| 14 | Coach | Send and Stop were 34pt icons, "Thinking…" was a fake bubble, and VoiceOver couldn't tell who said what. | 44pt targets, a stock `ProgressView` while thinking, and bubbles read as "You:" or "Coach:". | Fixed |
| 15 | Buttons | `BigButtonStyle` scaled on press and had no disabled state. | It now dims for its disabled and pressed states and wraps long labels. It is kept only for calls to action on coloured cards, where a system style can't put coloured text on white. | Fixed |
| 16 | Small targets | The Set goal, switch-workout and exercise-row targets were under 44pt. | All are 44pt or larger now. | Fixed |
| 17 | UI tests | `testPortfolioShots` and `testEveryScreen` failed on rest days and when Plan was scrolled. | The tests switch in a workout on rest days, tap exercise tiles by identifier, and scroll Plan to the top before editing. | Fixed |
| 18 | Plan | Day cards are custom cards rather than an inset-grouped `List`, so rows have no swipe actions. | Kept as cards for the visual identity: muscle-group colour bands and exercise figures. Editing is one tap away. | Open |
| 19 | Today | The hero cards are custom; the HIG has no matching component. At the largest text sizes they get very tall. | They now wrap and scale. A compact accessibility layout could follow. | Open |

## Screenshots

The refreshed portfolio shots, light mode, are in `prototype/shots/`: today, detail, plan, progress, coach and workout (`.jpg`).
