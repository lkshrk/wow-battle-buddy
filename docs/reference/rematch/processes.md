# Processes and integration boundaries

## Evidence

Local sources beneath `/tmp/ns/ref/`: Rematch and Akolus `process/{loadTeam,loadouts,queue,preferences,interact,send,rebuild,battle}.lua`; Akolus `process/{battleData,battleControls}.lua`; PBS `Core/{Director,Action,Script}.lua` and `Rematch/Addon.lua`. Descriptions below are independently worded behavior, not source reuse. Visual placement belongs to the screenshot-led surface specs.

## User intent to result

| Trigger | Required result |
| --- | --- |
| Load a saved team | Resolve three slots against owned pets, ability choices, special slots and effective leveling preferences. Exclude duplicate pet selections where necessary; observe journal updates and bound retries. Report missing/unusable pets instead of silently declaring a complete load. |
| Leveling-slot resolution | Recompute eligible queue picks for the incoming team and its group/default preferences. Persist slot intent separately from the concrete pet currently occupying it. |
| Refresh/rebuild | Rebuild derived lists, target associations and visible summaries. Rendering and cache rebuilds alone must never apply a loadout or dispatch a battle action. |
| Target interaction | Support the selected off/prompt/window/autoload policy. Prompt requires a Load choice; multiple candidate teams remain selectable. Suppress unsafe loadout changes during combat. Akolus rechecks the current target after teams change, so importing beside an already-targeted trainer is recognized. Keep this an explicit interaction event, not a rendering side effect. |
| Finish loading | Update the active-team display, optional notes and per-slot warnings. Partial resolution remains visible and must not rewrite the saved team's intended pets. |
| Share/receive | Keep sending, receiving, preview and acceptance separate. Incoming text is data; it cannot trigger team loading or battle execution merely by arriving. See [team strings](team-strings.md). |
| Battle start/close | Establish and clear battle-local state, selected script and temporary bindings. Refresh teams/queue after the relevant journal/battle events; do not retain stale enemy or script state into the next encounter. |

## PBS and later integrations

Use the pinned MIT PBS engine described in [team strings](team-strings.md). Save Team's Script tab owns script content and validation; the team row identifies and opens that team's script; battle Autobattle invokes the selected script through the permitted user action. PBS evaluates ordered conditions/actions until an actionable branch succeeds. Parsing, previewing, showing a panel and ordinary event refresh do not execute a script.

Keep battle actions gated by battle phase, available data and a valid script. Empty/invalid scripts or an unavailable action leave the user in control with readable feedback. Do not introduce a standalone PBS UI. Later UltraSquirt support integrates into existing team, queue, options and battle surfaces; there is no authorized UltraSquirt source in this reference set, so its precise automation contract is deferred rather than invented.

## Akolus 12.1 compatibility observations

- `battleData.lua` checks whether an API exists, protects fallible calls, and substitutes display fallbacks for missing/secret results. Adopt the behavior, not its implementation: detect secret values before comparisons, table indexing, formatting or arithmetic; unknown is not zero or a false combat fact.
- `battleControls.lua` accommodates optional PBS module/method availability and defers protected binding changes in combat. Protected calls remain prohibited during lockdown even if wrapped in error handling. Apply pending binding changes only after a safe transition.
- Some reference battle modules inspect combat-log messages. **Do not reproduce that path:** the repository's no-combat-log-parsing rule remains in force. If permitted current APIs cannot supply a fact, display it as unavailable and disable dependent decisions instead of reconstructing it from restricted data.
- API guards do not establish API correctness. Before implementation, query each changed WoW API through `wow-api` and use permitted live FrameXML verification where needed. This documentation task changes no API calls and does not certify a live-client run.

## Acceptance and gaps

Exercise delayed journal updates, bounded load failure, missing pets, multiple leveling slots, import while already targeting, combat entry mid-request, and battle close/reopen. Rendering must remain action-free; a canceled import or invalid script leaves prior data intact. Missing APIs and secret values must not cause comparisons, fabricated stats or protected operations. Autobattle requires the intended user activation and clears stale script selection between encounters.

Phase A exposes only changed options and controls for shipped features. Background reference capabilities do not authorize implementing every process or adding dormant settings. Live timing, secure execution and unavailable-data behavior require in-client validation; screenshots cannot prove them.
