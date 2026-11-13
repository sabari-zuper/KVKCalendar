# Collapsible all-day area ("+N more" / "Show less")

Status: implemented (week and day timelines).

## Goal

The all-day area above the timeline grows with the number of all-day events and can push the
timeline far down. We want it to show at most N rows (2 in our app) and a **"+N more"** button.
Tapping the button, or the chevron under the "all-day" title, expands the area to show every
event. When expanded, it shows a **"Show less"** button and an up chevron to collapse it again.

Target UI:

```
 all-day │      │      │ Rooftop Inspection Window │
    ⌄    │      │      │ Alex PTO                  │
         [ +3 more ]
─────────┴──────┴──────┴───────────────────────────┴── timeline
```

## Usage

The feature is opt-in. If `maxCollapsedRows` is `nil`, the old behaviour is unchanged.

```swift
var style = Style()
style.allDay.maxCollapsedRows = 2
```

New `AllDayStyle` options (`Sources/KVKCalendar/Style.swift`):

| Property | Default | Notes |
| --- | --- | --- |
| `maxCollapsedRows` | `nil` | Rows shown while collapsed. `nil` = feature off. |
| `maxExpandedHeight` | `nil` | Cap for the expanded area. `nil` = half the timeline height; the area scrolls if the events don't fit. |
| `moreTitleFormat` | `"+%d more"` | `%d` = number of hidden events. |
| `lessTitle` | `"Show less"` | `nil` hides the button when expanded (only the chevron collapses). |
| `moreFont`, `moreTextColor`, `moreBackgroundColor`, `moreBorderColor`, `moreHeight` | | Pill button look. Dark mode handled in `adaptiveStyle`. |
| `expandIcon`, `collapseIcon`, `expandIconColor` | `chevron.down` / `chevron.up` | Chevron under the "all-day" title. |

## How it works

1. **Count rows and hidden events**: `AllDayView.collapseInfo(prepareEvents:type:maxRows:)`
   returns `totalRows`, `visibleRows` and `hiddenCount`.
   - Week: rows = the largest number of events on any one day. Hidden events are counted
     by `Event.ID`. A multi-day event is repeated in every column, so it counts once, and
     only if it isn't visible in some other column.
   - If nothing is really hidden (everything past row N is visible on another day), show
     all rows and no button, so no day looks free when it isn't.
   - Day: events are laid out 2 per row, so rows = `ceil(count / 2)` and collapsed shows
     `maxRows * 2` events.
2. **Height**: `TimelineView.createAllDayEvents` (`Timeline+Extension.swift`).
   - Collapsed = `visibleRows * allDay.height` + the button strip
     (`AllDayView.moreButtonAreaHeight`).
   - Expanded = all rows + the button strip, capped at `maxExpandedHeight`.
3. **Drawing**: `AllDayView`.
   - While collapsed, only the first `visibleRows` events of each column are drawn and the
     inner scroll view is disabled.
   - The pill button sits under the first day column.
   - The chevron and a transparent button cover the left "all-day" column.
   - The inner scroll view uses `contentInsetAdjustmentBehavior = .never`. Without it, the
     safe-area inset pushes the events down.
4. **Toggling**: both buttons call `Parameters.didToggleExpand`, which calls
   `TimelineView.toggleAllDayExpanded()`, which calls `setAllDayExpanded(_:)`. That:
   - flips `paramaters.isAllDayExpanded`;
   - reloads the timeline without auto-scrolling to the current time;
   - keeps the timeline right under the all-day area. If it was at the top it stays at
     the top; if it was scrolled down, the position is kept.
5. **Keeping the state**: `TimelineView.Parameters.isAllDayExpanded` reports changes through
   `didChangeParameters`.
   - `WeekView` / `DayView` store the value and pass it to every new `TimelineView`.
   - They also call `TimelinePageView.reloadAllDayExpanded(_:excludeCurrentPage:)` for the
     cached neighbour pages.
6. **Timeline inset**: when the feature is on, `TimelineView.create` always resets the
   scroll view's top inset (`force: true`). The area can now shrink, and the week view used
   to only ever grow the inset.

## Files

- `Sources/KVKCalendar/Style.swift`: new `AllDayStyle` properties, `Equatable`, dark-mode colours.
- `Sources/KVKCalendar/AllDayView.swift`: `CollapseInfo`, row limiting, chevron, pill button.
- `Sources/KVKCalendar/Timeline+Extension.swift`: height calculation, `toggleAllDayExpanded`, `setAllDayExpanded`.
- `Sources/KVKCalendar/TimelineView.swift`: `Parameters.isAllDayExpanded`, forced inset.
- `Sources/KVKCalendar/TimelinePageView.swift`: `reloadAllDayExpanded`.
- `Sources/KVKCalendar/WeekView.swift`, `DayView.swift`: keep the state across pages.
- `Tests/KVKCalendarTests/AllDayCollapseTests.swift`: counting logic.
- `Example/KVKCalendar/KVKCalendarSettings.swift`: enables `maxCollapsedRows = 2`.

## Decisions

- The expanded state is shared across pages: paging to another week keeps it. Changing that
  to "collapse on page change" is a one-liner in `WeekView` / `DayView` `didChangeParameters`.
- Opt-in style property, so upstream behaviour and other users of the library are untouched.
- A single pill under the first column (as in the design) instead of one per column. Week
  columns on a phone are too narrow for per-column labels.

## Known limitations / follow-ups

- Multi-day all-day events are still drawn as one block per day, not one bar across days.
  That needs a different week layout.
- With a custom corner header (`dequeueAllDayCornerHeader`), no chevron is added, and the
  pill is the only toggle. If `lessTitle == nil` as well, there is no way to collapse.
- Not visually tested with `allDay.isPinned = false`.
- Already in the code before this change: `AllDayView.updateStyle` adds the event views and
  divider lines again without removing the old ones. Toggling isn't affected, because it
  rebuilds the view.

## Testing

- Unit tests: `AllDayCollapseTests`. At the repo root, `xcodebuild` picks up
  `_Pods.xcodeproj`, so run the SPM tests from a folder that only links the package:
  ```sh
  mkdir -p .context/spm && cd .context/spm
  for f in Package.swift Sources Tests Example; do ln -sf "../../$f" "$f"; done
  xcodebuild test -scheme KVKCalendar -destination "platform=iOS Simulator,name=iPhone 16 Pro"
  ```
- Visual check without driving the Example app (it shows a calendar permission prompt):
  write a temporary `@testable` test that puts a `TimelineView` in a `UIWindow` and calls
  `create(dates:events:recurringEvents:selectedDate:)` and `toggleAllDayExpanded()`. Render
  it with `view.layer.render(in:)` to a PNG (`drawHierarchy` gives a blank image in SPM tests).
- Manual check in the app:
  - Week view with 3+ all-day events on one day shows 2 rows and "+N more".
  - Tapping the pill or the chevron expands and collapses.
  - The state is kept when paging between weeks.
  - The timeline stays right under the bar.
