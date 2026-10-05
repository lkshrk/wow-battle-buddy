# Window

## Reference and scope

Visual authority: [journal/teams](../screenshots/rematch-journal-teams.png) and [queue](../screenshots/rematch-queue.png). Local behavioral references: `/tmp/ns/ref/rematch-wowi/Rematch/{layout/definitions.lua,layout/journal.lua,layout/frame.lua,chrome/panelTabs.lua,chrome/bottombar.lua}` and the matching Akolus files. This is an independently implemented 1:1 layout/interaction target, not permission to reuse source or artwork.

## Layout and behavior

- The captured journal has a dark framed title strip and close button, then a full-width collection/achievement/utility strip. Three nearly equal columns sit below: pet collection, current team/loadout, and the selected management panel.
- Keep the left search/filter area and center team header, target strip, and three vertically stacked pets visible when switching the right column between Teams, Targets, and Queue. Options occupies its own reference panel layout; do not invent another primary window.
- Bottom actions align with their columns: Summon under pets; Save, Save As, and Find Battle along the lower edge. Panel tabs sit below the right edge with a clear selected state. The screenshot also shows the surrounding Blizzard Collections tabs and the enabled journal-integration checkbox.
- Teams and Queue have independent scroll positions and retain the same outer column boundaries. Long lists scroll inside their panel, not the whole window. Tooltips, cards, menus, and modal dialogs layer over the frame without shifting those boundaries.
- Source additionally defines minimized, one-, two-, and three-column standalone arrangements. Nominal source dimensions are 280 units per standard panel and 520 units tall, with 340 units for a single-panel layout. These are layout facts, not screenshot pixel measurements; the captured UI scale determines final visual comparison.
- Source supports standalone positioning/scaling and journal embedding. Preserve the captured journal arrangement first; additional arrangements need their own visual evidence before claiming parity. Opening, resizing, refreshing, or changing tabs must never load a team or dispatch a battle action.

## Acceptance and gaps

Compare at matching UI scale: outer frame, column seams, header heights, action alignment, scrolling, and active tab. Switch Teams → Queue → Teams and verify left/center continuity and retained panel state. Check close/reopen and unavailable/disabled actions. No screenshots establish standalone/minimized layouts, Options content, alternate scales, or keyboard focus order; these remain visual-validation gaps. Use Blizzard-provided or independently created visuals, never extracted ARR assets.
