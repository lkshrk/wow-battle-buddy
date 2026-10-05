# Pet list

## Evidence

Visual authority: [journal](../screenshots/rematch-journal-teams.png), [filter](../screenshots/rematch-pet-filter-menu.png). Local source: both Rematch trees' `panels/petsPanel.lua`, `templates/petListButton.lua`, `roster/filters.lua`; Akolus adds the separate stat-search fields. This describes observed behavior in original words.

## Layout and interactions

- Left column: expansion arrow, pet/ability search, Filter button; a second row of health, power, and speed comparison inputs; then a max-level shortcut, three category tabs, and ten family icons. The category tabs select family, offensive matchup, or defensive matchup filtering.
- Each normal row has a framed portrait at left, a level badge at its lower edge, a quality-colored name, a large subdued family symbol at right, optional status markers, and breed text near the lower right. Favorites use a star. Breed text is factual data, not inferred when unavailable.
- The list has a narrow right scrollbar. The header can collapse the family bar; search remains available. Filters produce a result-summary bar; an unrestricted list omits it. Source also offers compact rows (26 units versus 44 normally); no supplied capture establishes their appearance.
- Typing updates results, including ability-name search. The Akolus health/power/speed fields feed the same filter evaluation as the text input and show invalid input distinctly. Clearing text must clear its actual filter, not just its visible value.
- Family buttons share state with the Filter menu. Selected categories remain distinguishable; other icons dim when that group restricts results. Left-clicking the max-level shortcut toggles level 25; right-clicking selects level 25 plus rare quality, with repeat-click removal behavior.
- A row opens/locks its pet card; right-click opens the pet menu. Double-click summons an owned pet unless disabled by the corresponding setting. Owned individual pets can be dragged into supported destinations. Species-only/unowned entries cannot be picked up as owned pets. The currently summoned pet and the card selection have separate highlight states.
- Wrapped/newly acquired pets and pet-herding mode alter row click handling; do not accidentally summon or open the normal menu while those modes own the click. Details belong to [pet-card](pet-card.md) and [processes](processes.md).

## Acceptance and gaps

Match screenshot row spacing, icon/badge anchors, text clipping, scrollbar, stat inputs, and family bar. Exercise empty search, no results, combined text/stat/family filters, invalid stat expressions, owned versus unowned rows, card selection, summon, and drag. Refresh/filtering itself must not summon or change the loadout. Compact rows, empty-state copy, and precise invalid-input styling require additional visual confirmation; do not invent exact pixel values from source units.
