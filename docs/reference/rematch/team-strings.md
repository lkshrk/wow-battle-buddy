# Team strings and script exchange

## Evidence and boundary

Local references: `rematch-wowi/Rematch/process/teamStrings.lua`, `process/petTags.lua`, `dialogs/importDialog.lua`; equivalent Akolus files; `axc450_pbs/Core/Share.lua`, `Core/Director.lua`, `Share/Version*.lua`, `Rematch/Addon.lua`, relative to `/tmp/ns/ref/`. These are factual interoperability observations, not copied implementation. No supplied screenshot shows the import/export dialog; its geometry remains unverified. Screenshots take precedence when available.

## Team exchange

- A machine-readable team occupies one line: its name, target identifiers, and three pet descriptors, with optional leveling preferences and notes. Empty slots remain distinguishable from omitted optional sections. Target identifiers use base 32; preference values retain numeric meaning. Notes preserve line breaks through escaping.
- Pet descriptors carry the species/selection information and ability choices needed to match an owned pet; an unavailable owned GUID must not be treated as a portable identity. See [data model](data-model.md) for the semantic fields.
- Group exports retain group metadata and ordered teams. Whole-collection exports retain group order. A group header before any team enables grouped import; if a team appears first, subsequent headers do not turn the input into a grouped import.
- Pasting updates a preview: recognized teams/groups, name collisions, invalid input, and a three-pet preview for one team. A team-only import offers a destination group. Breed prioritization appears when breed support is available.
- Save persists the reviewed import. Load is offered only for a single-team preview and applies that team without saving it. Cancel must preserve stored teams. Name collisions offer replacement or separate copies; never silently overwrite.
- Export controls choose whether preferences and notes are included. Human-readable export is a separate presentation and is not a reimportable backup. Keep that distinction visible.

## PBS integration and pin

`third_party/pbs/` matches local `/tmp/ns/ref/axc450_pbs/` byte-for-byte, excluding source `.git`, at **v1.13.1**, commit **`fe78bd60049c559d9bf7d8d27a4039a2036b0241`**. `third_party/pbs/LICENSE.md` contains the MIT copyright and permission notice; retain it with redistributed portions. The source TOC has an unreplaced `@project-version@` token, so the git tag and revision are the version authority. This pin identifies the reference snapshot, not proof of runtime integration or retail compatibility.

- PBS has versioned exchange readers and validates decoded script content before accepting it. Its Rematch integration can accompany a script with team information and attach the script after that team is imported.
- BattleBuddy exposes script editing/import/export in the **Save Team Script tab**, script presence/edit access on the **team row**, and execution through battle **Autobattle**. Do not create a standalone PBS editor/library window or reproduce its addon-management UI.
- Keep team text and script text distinguishable. Bind imported scripts to the final selected/saved team identity after collision resolution; canceling must not attach a script to an unrelated team. Invalid script input reports an error in the existing surface and preserves the previous script.
- The supplied Save Team screenshot has Team, Targets, Preferences and Wins tabs; **Script is the requested integration addition**, not a claim about the screenshot. Preserve its surrounding layout.

## Acceptance and gaps

Verify single and grouped imports, empty slots, multiline notes, preferences, missing owned pets, breed choice, duplicate names, malformed text, cancel, and load-without-save. Verify team/script round trips and collision/cancel behavior without executing imported text during parsing or preview.

The exact BattleBuddy export envelope for combined team/script data is not selected here; compatibility needs independently authored fixtures and tests before shipping. No reference text, implementation, XML, or assets from ARR/unlicensed addons may be redistributed. PBS's MIT grant does not cover the other addons or automatically settle bundled-library notices.
