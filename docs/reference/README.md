# BattleBuddy reference addons — survey (2026-10-04)

Target: retail 12.1 (Interface 120100). BattleBuddy is GPL-3.0 (`~/Dev/wow-battle-buddy/LICENSE`).
Local source copies: `/tmp/ns/ref/<name>` (listed per addon).

## License summary (porting rules)

| Addon | License | Port code? |
|---|---|---|
| Rematch 5.3.x (Gello) | All Rights Reserved (CurseForge) | NO. Spec only |
| Akolus/12.1-Rematch | no LICENSE file; derivative of ARR Rematch | NO. Spec only |
| PBS (axc450/pbs) | MIT (LICENSE.md, (c) 2018 Dengzhun Lu) | YES, keep MIT notice |
| tdBattlePetScript (DengSir) | MIT | YES, keep MIT notice |
| tdBattlePetScript_Rematch (DengSir) | not checked (separate repo, superseded by PBS `Rematch/`) | n/a |
| UltraSquirt / Reloaded | GPL-3.0 (LICENSE in import) | YES (same license) |
| BPBUIT (Gello) | All Rights Reserved (CurseForge) | NO. Spec only |
| Battle Pet BreedID (Simca) | TOC `X-License: BSD`; no LICENSE file, GitHub shows none | UNCLEAR: variant (2/3-clause) and copyright holder are unstated. Treat as spec-only until clarified. Breed/stat data (PetData.lua) is the valuable part |
| PetTracker (Jaliborc) | TOC `X-License: All Rights Reserved` | NO. Spec only |

Embedded libs in UltraSquirt (Ace3, lib-st, LibDataBroker, LibStub) carry their own licenses (`Libs/LICENSE.txt`).

---

## 1. Rematch (Gello)
- Source: WoWInterface https://www.wowinterface.com/downloads/info22190-Rematch.html (zip: `https://cdn.wowinterface.com/downloads/getfile.php?id=22190`), CurseForge https://www.curseforge.com/wow/addons/rematch. No official git repository.
- Version: 5.3.1, updated 2026-01-24, TOC 120000. Upstream has had no 12.1 release (5.3.1 = Midnight secret-value fix).
- 12.1: upstream loads as out-of-date; target detection is broken by secret values. Use the Akolus fork (below).
- Local copy: `/tmp/ns/ref/rematch-wowi/Rematch` (docs: `docs/readme.txt`, `docs/extending.txt`, `docs/scriptFilters.txt`, `docs/changelog.txt`).
- SavedVariables: Rematch5Settings, Rematch5SavedTeams, Rematch5SavedGroups, Rematch5SavedTargets.
- Slash: `/rematch` (toggle window), `/rematch reset everything`, `/rematch delete all teams`, `/rematch targetdata`, `/rematch import options`.
- Keybindings (`bindings.xml`): REMATCH_WINDOW (toggle), REMATCH_NOTES. Addon compartment entry (`RematchToggleWindow`). Optional minimap button and LDB launcher.
- Surfaces (from `layout/`, `panels/`, `chrome/`, `menus/`, `dialogs/`, `cards/`, `process/`):
  - Hosting: integrated into the Pet Journal (a "Rematch" checkbox on the journal bottom switches it back to Blizzard's), or a standalone movable window you can minimize, with 1-, 2- or 3-panel layouts (`layout/definitions.lua`, `journal.lua`, `frame.lua`).
  - Chrome: titlebar (lock, layout left/right, minimize, close); toolbar (heal/revive, bandage, safari hat, treats, summon random pet, totals: pets/unique); bottombar; panel tabs Pets/Teams/Targets/Queue/Options; up to 15 team-group "bookmark" side tabs (`teamTabs`).
  - Loaded team panel: gold button showing the loaded team name (click reloads, right-click opens the team menu), notes button, blue dice (random or counter team for the target).
  - Loadout panel: 3 slots × (pet + 3 ability flyouts); "Put Leveling Pet Here". Mini loadout panel for the minimized window.
  - Loaded target panel: current target, its known enemy pets, load/save actions.
  - Pets panel: list with search (names, abilities, ability text, `level=`, `health>`, `speed=`, `power>`), Type Bar (Types / Strong Vs / Tough Vs tabs, level-25 button: right-click limits to rares), extensive filter menu (`petFilterMenu.lua`), pet markers (renamable), breed column.
  - Teams panel: groups and teams with drag-drop, sorting (name/wins/custom), win record, red target icon on teams that have targets, team tabs.
  - Targets panel: notable targets grouped by expansion/zone (`info/targetData.lua`, 82K).
  - Queue panel: leveling queue with sort (asc/desc/median level, by type, rares first, favorites first, in-teams first), Fill Queue / Fill Queue More, Empty, Import/Export, Pause Preferences, Start Leveling.
  - Options panel: about 137 options in 20 groups: Interaction, Standalone Window, Appearance, Badges, Behavior, Toolbar, Pet Filter, Breed, Pet Card, Notes, Ability Tooltip, Team, Random Pet, Team Win Record, Leveling Queue, Confirmation, Miscellaneous, Help, About (`panels/optionsList.lua`).
  - Menus: team (Edit Team, Edit Target, Load Target, Set Notes, Share → Send Team / Export Team / Plain Text, Move, Delete, Find Teams), group (Create/Edit/Move/Delete/Export Group, Backup All Teams, Import Teams), pet (Find Similar, Find Moveset, Pet Tags, queue moves), queue, loadout, target.
  - Dialogs (`dialogs/dialog.xml`, 150K): save team (name, group, targets, preferences: min/max HP and XP), import, export, send, summary, script filter (Lua filter expressions), confirmations.
  - Cards: pet card tooltip (lockable on click; Alt flips to lore and source), stats, notes card (team or pet notes, `#find` tags), ability tooltip.
  - Process: interact (auto-load or prompt on target interact), loadTeam (+ load healthiest pets, also after battles), leveling queue with preferences, petHerder (Team Herder), random pets, win record, team strings (import/export format), send (addon comm), toast, badges, Safari Hat reminder, battle.
- Extension API documented in `docs/extending.txt` (PBS uses it).

## 1a. Akolus/12.1-Rematch (12.1 compatibility fork)
- https://github.com/Akolus/12.1-Rematch; clone: `/tmp/ns/ref/Akolus_12.1-Rematch`. Version 5.3.14, last push 2026-09-05, TOC 120100. No license, "not affiliated with Gello".
- Changes on top of 5.3.1 (~147 files differ):
  - Target identification when GUID/ID are secret: uses gossip text, scenario criteria, nameplates, truncated names, name aliases, and pack-encounter redirects (Plagued Critters, Door Control Console).
  - Enemy Ability Bar: 3 enemy abilities with native tooltips, damage, hit chance, family effectiveness, and per-pet cooldown history across swaps. Options: icon size 30–60, spacing 0–16, cooldown font/size/X/Y, remaining-cooldown font size.
  - Optional compact battle panel replacing Blizzard's bottom bar: abilities, Battle Data, Pass, Autobattle (calls PBS), XP, PvP timer. Movable (drag the top edge), Ctrl+wheel scale, Autobattle hotkey (default A, "+" button binds through SetOverrideBindingClick, right-click clears, short labels such as MWD).
  - New process modules: `battleActionBar`, `battleControls`, `battleData`, `battleBreedTooltip`, `enemyAbilities`, `abilityEffectiveness`, `petCardExtras`, `nativeBreedOptions`.
- Useful as the 12.1 behaviour spec: it shows which Blizzard APIs are secret on 12.1 and the workarounds that hold.

## 2. Pet Battle Scripts (PBS), axc450 fork of tdBattlePetScript
- https://github.com/axc450/pbs; clone: `/tmp/ns/ref/axc450_pbs`. Latest release v1.13.1, 2026-06-20. CurseForge https://www.curseforge.com/wow/addons/pet-battle-scripts, Wago https://addons.wago.io/addons/pbs. MIT.
- 12.1: TOC is `120007, 50504`, so it loads as out-of-date on 120100 unless that is allowed. The Akolus fork relies on it working on 12.1. No 12.1 TOC bump yet.
- Original: https://github.com/DengSir/tdBattlePetScript (`/tmp/ns/ref/DengSir_tdBattlePetScript`), deprecated 2022-11-13, MIT.
- SavedVariables: TD_DB_BATTLEPETSCRIPT_GLOBAL, TD_DB_BATTLEPETSCRIPT_BATTLE_CACHE (per character). No slash command. Minimap button.
- Engine (`Core/`): script DSL (actions + conditions), Director (per-round evaluation), plugin manager (script selectors), battle cache, Share versions 0–2 (import/export string format). `Extension/`: Actions, Conditions, Snippets, Round, Played.
- Plugins (script selectors, priority-ordered): Base (per enemy team), FirstEnemy, AllInOne, Rematch (per Rematch team; `Rematch/Addon.lua` and `Rematch/UI.lua`).
- Battle UI (`UI/PetBattle.lua`):
  - Tool button on PetBattleFrame.
  - `tdBattlePetScriptAutoButton` "Autobattle" next to Skip, with primary and secondary hotkeys through override bindings, a hotkey label, and an optional glow/sound when it is active.
  - Art on the TurnTimer.
  - In-battle script selector panel (GridView) to choose a script, debug it, or create one.
- Script Manager / Editor (`UI/MainPanel.lua`): script list, name, textarea, Run, autoformat, toggle extra, Save, Delete (confirmation), error display, Import/Export dialogs (`UI/Import.lua`).
- Options (`UI/Options.lua`): auto-select script by order, autobutton hotkey and secondary hotkey, editor font face and size, hide minimap, hide selector with no script, lock script selector, no-wait delete, notify button active (+ sound), reset frames, script selector notes, test break.
- Rematch integration: scripts keyed to Rematch teams; a team-menu entry to create or edit a script; export the script into Rematch team notes; auto-import scripts found in notes (bad scripts are deleted since v1.13); the selector shows the Rematch team name and notes.

## 3. UltraSquirt / UltraSquirt Reloaded (BattleBuddy's direct predecessor)
- Original: UltraSquirt by aspin_kt, https://www.curseforge.com/wow/addons/ultrasquirt. Latest v0.9.9f, 2026-01-21, game 12.0.1, GPL-3.0.
- "Reloaded": imported into `~/Dev/wow-battle-buddy` at commit `5ac215e` ("Initial UltraSquirt Reloaded import"). Then `10035f6` (12.1 bindings) and `c67e646` (disable unsafe NPC table sort). Replaced at `bce5c6a` ("Replace UltraSquirt with BattleBuddy identity"). Extracted to `/tmp/ns/ref/ultrasquirt/UltraSquirtReloaded` (TOC 120100, v0.9.9f, Ace3).
- Dependencies (optional): Rematch, tdBattlePetScript, tdBattlePetScript_Rematch. SavedVariables: UltraSquirtReloadedSettingsDB (AceDB global).
- Slash: `/ultra`, `/ultrasquirt`, `/squirt` (toggle window); `config`; `reset`; `adv` (Advanced Teams window).
- Core loop: one key (default SPACE, set through a temporary override binding while the window is open) runs the next action on each hardware press:
  1. Heal by priority: Revive Battle Pets > Battle Pet Bandage > Stable Master NPC (Squirt only). Skipped unless some slotted pet is below the healing threshold.
  2. Apply buffs.
  3. Load the Rematch team (with delay).
  4. Target the NPC and interact (Interact With Target + Click-to-Move).
  5. In battle, press the PBS autobutton.
  6. Close the battle (with delay).
  If no heal is available it runs `/target player`. The window closes on regular combat.
- Main window `UltraSquirtReloadedFrame` (384×205, draggable title):
  - Macro button `UltraSquirtReloadedButton` that shows the hotkey.
  - Set Battle NPC (crosshair, current target; limited to Squirt and the repeatable Legion tamers).
  - Healing threshold slider (saved per NPC).
  - Toggle Advanced Teams button.
  - Buff/heal buttons (right-click toggles auto): Safari Hat (auto by default), Lesser Pet Treat, Pet Treat, Darkmoon Top Hat, Little Buddy Biscuits (treat buttons only glow as a reminder), Revive Battle Pets (auto by default), Bandage (off by default). The buttons are styled like the pet action bar (sparkles = enabled, corner markers = auto-cast).
- Advanced Teams window (743×400, lib-st table): per NPC, an ordered list of Rematch teams, each with its own heal threshold; "revive early" checkbox per NPC; reorder and remove.
- Settings (AceConfig): mute enable/disable messages; delays: Rematch load team (3s), pet battle close (2s), heal (2s); keybind.
- Rematch hooks: detects the "Load Healthiest Pets" + "After Pet Battles Too" options and pauses after each battle.
- Localized into 11 locales.
- Open to-dos in CHANGES: rethink Advanced Teams against Rematch 5 multi-target teams; replacement for Rematch reload timers; PLAYER_INTERACTION_MANAGER_FRAME_SHOW instead of GOSSIP_SHOW; custom accepted NPCs; a current-action indicator.
- Note: the AFK/keypresser use case is ToS-sensitive. Every action already requires a hardware press; keep it that way.

## 4. Battle Pet Battle UI Tweaks (BPBUIT, Gello)
- WoWInterface https://www.wowinterface.com/downloads/info25718-BattlePetBattleUITweaks.html, CurseForge https://www.curseforge.com/wow/addons/battle-pet-battle-ui-tweaks. Version 2.2.6, 2025-06-19, TOC 110107. All Rights Reserved.
- 12.1: broken or unmaintained. Players report it is blocked since 11.1.7 and that a TOC bump does not fix it.
- Local copy: `/tmp/ns/ref/bpbuit/BattlePetBattleUITweaks`. SavedVariables: BattlePetBattleUITweaksSettings. Options in Blizzard Settings; no slash command.
- Tweaks (one toggle each, all on by default, `options.lua`):
  - Round Counter: round number in the "Vs" circle.
  - Current Stats: health %, power, and speed under the frontline health bars.
  - Health Ticks: threshold ticks on mouseover of the frontline health bars.
  - Key Binds: Forfeit=6, Pass=7, swap pets 1–3 through SetOverrideBindingClick on proxy buttons. Auto-disabled if Battle Pet Binds is loaded.
  - Enemy Abilities: enemy abilities + cooldowns under the battle UI. Auto-disabled if Derangement PBC or PetTracker is loaded.

## 5. Battle Pet BreedID (Simca)
- https://github.com/MMOSimca/BattlePetBreedID; clone: `/tmp/ns/ref/BattlePetBreedID`. Release v1.42.0, 2026-08-13 ("Huge update to base pet stats and available breeds"). TOC `120100, 50504`, so it works on 12.1. Also on CurseForge.
- License: TOC says "BSD" only (see table, UNCLEAR).
- Slash: `/battlepetbreedid`, `/bpbid`, `/breedid` (open Settings). Addon compartment entry. Globals: `GetBreedID_Battle`, `GetBreedID_Journal`. SavedVariables: BPBID_Options.
- Features:
  - Breed display in battle names and tooltips, the Pet Journal list and tooltip, item tooltips (BattlePetTooltip), and chat-link tooltips (FloatingBattlePetTooltip).
  - Breed formats 1–6: number, two numbers, letters (default 3, e.g. "P/P"), and others.
  - Optional rarity colouring.
  - Breedtip contents (toggles): current breed, possible breeds, species base stats, current/all breed stats at level 1, current/all breed stats at level 25 (optionally assume rare), collected breeds.
  - Manual-change detection.
- Data: `PetData.lua` (base stats and breeds per species), the core asset for breed calculation.

## 6. PetTracker (Jaliborc)
- https://github.com/Jaliborc/PetTracker; clone: `/tmp/ns/ref/PetTracker` (libs are git submodules, not fetched). Version 12.1.6, 2026-10-04. TOC `120100, 50504`, so it works on 12.1. CurseForge https://www.curseforge.com/wow/addons/pettracker. All Rights Reserved.
- SavedVariables: PetTracker_Sets (global), PetTracker_State (per character). No slash command found. Options in Blizzard Settings (Sushi OptionsGroup) with FAQ, tutorials, and a patrons page.
- Features:
  - World map / minimap: pet, stable, and tamer locations; species filter box with search suggestions under the map magnifier.
  - Zone tracker in the objectives tracker: progress of missing pets and rares in the zone. Toggle "Zone Tracker" from the journal bottom-right; clicking the header opens its options.
  - Breeds shown everywhere, with names and icons (`api/breeds.lua`, `Predict.lua`).
  - Journal: "Rivals" tab with a PvE encounter browser, history of fights including the loadouts used (`journal/rivals.*`, `record.*`), and a track toggle.
  - Battle:
    - Enemy action bar (Shift+drag to move).
    - Improved pet switcher.
    - Upgrade alerts with a minimum alert quality.
    - Forfeit prompt.
- Options: ZoneTracker (+ TargetQuality display condition), SpecieIcons, RivalPortraits, Switcher, AlertUpgrades, Forfeit, MinAlertQuality.

---

## 12.1 compatibility snapshot

| Addon | Works on 12.1? |
|---|---|
| Rematch 5.3.1 upstream | Partial / out-of-date TOC; target detection is broken by secret values |
| Akolus 12.1-Rematch 5.3.14 | Yes (TOC 120100) |
| PBS 1.13.1 | TOC 120007: needs "load out of date"; functionally used on 12.1 by the Akolus fork |
| UltraSquirt 0.9.9f | Upstream 12.0.1; the local Reloaded import was bumped to 120100 |
| BPBUIT 2.2.6 | No (110107, reported blocked) |
| BattlePetBreedID 1.42.0 | Yes |
| PetTracker 12.1.6 | Yes |

## Flags
- BattlePetBreedID's "BSD" is ambiguous (no variant, no copyright line, no LICENSE file). Ask Simca or treat it as spec-only. Re-deriving breed data from Blizzard API stats is the clean path.
- Akolus fork: no license and a derivative of ARR code. Read it for 12.1 API workarounds only; never copy from it.
- PBS MIT: porting is allowed, but keep the MIT notice. GPL-3 BattleBuddy can absorb MIT code.
- Overlap to decide 1:1: there are three enemy-ability-bar implementations (BPBUIT, PetTracker, Akolus) and two battle keybind schemes (BPBUIT 6/7/1-3, PBS/Akolus autobutton hotkey). Pick one behaviour per ticket.

Sources: https://www.wowinterface.com/downloads/info22190-Rematch.html · https://www.curseforge.com/wow/addons/rematch · https://github.com/Akolus/12.1-Rematch · https://github.com/axc450/pbs · https://github.com/DengSir/tdBattlePetScript · https://www.curseforge.com/wow/addons/ultrasquirt · https://www.wowinterface.com/downloads/info25718-BattlePetBattleUITweaks.html · https://www.curseforge.com/wow/addons/battle-pet-battle-ui-tweaks · https://us.forums.blizzard.com/en/wow/t/is-pet-battle-addon-no-longer-supported/2301696 · https://github.com/MMOSimca/BattlePetBreedID · https://github.com/Jaliborc/PetTracker
