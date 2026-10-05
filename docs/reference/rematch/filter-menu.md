# Filter menu

## Evidence

Visual authority: [open filter menu](../screenshots/rematch-pet-filter-menu.png). Behavior: `/tmp/ns/ref/rematch-wowi/Rematch/menus/petFilterMenu.lua`, `roster/filters.lua`, and Akolus equivalents. Labels identify controls; explanatory text and implementation must be independently written.

## Layout and behavior

- A narrow dark dropdown opens immediately beside the Filter button and overlays the loadout. It has a thin border, left checkmarks, indented favorites restriction, and right-facing arrows for submenus.
- Captured order: ownership and favorites; family/offensive/defensive matchups; source, expansion, rarity, level, breed, tags, miscellaneous restrictions, script filters, sorting, saved filter presets; export and herding actions; help, global reset, and close. Keep this order and the captured separator spacing.
- Collected and uncollected visibility are independently selectable. Favorites restrict the result set. Family and matchup submenus each contain the ten pet families; the toolbar mirrors their selection.
- Ordinary clicks toggle grouped choices. Shift-click selects all choices except the clicked one; Alt-click isolates it. A fully selected group is normalized to unrestricted. Per-group reset clears only that group; global reset respects the configured search-retention behavior.
- Level bands are 1–7, 8–14, 15–24, and 25, with further species/moveset restrictions. Other filters cover leveling membership, tradability, battle eligibility, duplicate count, team membership, moveset uniqueness, current zone, hidden pets, and notes. Mutually exclusive choices within these restrictions behave as radio groups.
- Breed availability follows the active breed-data capability; a missing provider must not produce fabricated breed choices. Sorting supports multiple criteria and reverse order. Saved presets capture reusable filter selections; destructive preset actions require the normal confirmation behavior.
- Script filtering here means collection predicates. It is separate from PBS battle scripts in the Save Team Script tab. Export and herding are explicit actions, not side effects of opening or changing a filter.
- Updates refresh the visible results while preserving usable menu state. Highlight active subgroups. Help is explanatory; Okay closes the menu. No filter operation applies a team or dispatches battle actions.

## Acceptance and gaps

Match the screenshot's anchor, width, alignment, ordering, checks, and arrows. Test ordinary/Shift/Alt selection, group reset, global reset with retained search, synchronized family icons, zero results, missing breed capability, and menu close. Submenus and presets lack supplied screenshots, so source establishes behavior but not verified visual parity. Only expose functional entries as their features ship; track omitted entries explicitly rather than presenting inert controls.
