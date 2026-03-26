# CmdTab Manual QA Checklist

## Switching reliability

- Quick press and release `Cmd+Tab` twice between two apps. Expected: it alternates on every invocation, not only the first one.
- Hold `Cmd` and press `Tab` repeatedly. Expected: each key press advances exactly one item and release activates the highlighted item.
- Hold `Cmd+Shift` and press `Tab`. Expected: the initial highlight starts on the previous item in reverse order, and additional presses continue backward.
- Open the switcher, use arrow keys to change selection, then press `Return`. Expected: the highlighted item activates and the overlay closes.

## Ordering and grouping

- Arrange recent usage as Finder, Arc, Finder. Expected: the switcher shows Finder, Arc, Finder in strict MRU order without collapsing the two Finder entries together.
- Open four or more windows from the same app alongside other apps. Expected: visible entries still stay interleaved in recency order, while any app-specific cap only trims the oldest entries from that app.
- Toggle "Include background and minimized windows" on and off. Expected: minimized/background windows appear only when enabled, while visible-window ordering remains stable.

## Visual polish

- Compare selected and unselected cards in single-row and multi-row layouts. Expected: the selected card has a noticeably thicker blue border and a stronger blue glow.
- Open apps with wide, tall, and small previews. Expected: previews sit inside a clean framed stage with consistent padding and do not look cropped or cluttered.
- Force a fallback preview scenario by denying screen recording or selecting an uncapturable window. Expected: the fallback still renders inside the same framed stage and looks intentional.
