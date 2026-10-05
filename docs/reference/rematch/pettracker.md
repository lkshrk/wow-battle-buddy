# PetTracker reference boundary

## Evidence and purpose

Local factual sources: `/tmp/ns/ref/PetTracker/README.md`, `addons/battle/{enemyBar,listener,switcher,alerts,units}.lua`, `addons/main/features/{mapFilters,mapCanvas,objectives,tooltips}.lua`, `addons/main/classes/combat/{abilityButton,petSlot}.lua`, and `addons/journal/rivals.lua`. PetTracker is ARR: no source, XML, comments, assets, breed tables or long text may be imported.

The supplied battle screenshots show desired information, but do not establish which addon produced every element. Use `battle-enemy-ability-tooltip.png` and `battle-enemy-pet-tooltip-breed.png` for visible results; do not attribute them to PetTracker without evidence.

## Observable reference behavior

- Collection support includes map pet/stable/tamer markers and filtering, current-zone collection progress, journal tracking controls, and rarity/breed information. These are reference capabilities, not authorization for a new BattleBuddy tracking window.
- Its battle enemy bar allocates six ability positions in two rows of three, updates for enemy changes and round playback, hides during pet selection, and supports Shift-drag with saved offsets. BattleBuddy uses the selected Akolus three-ability surface instead; do not duplicate bars or replace screenshot-backed layout with PetTracker's arrangement.
- Pet switching provides status information; collection alerts identify useful captures. Rival records associate encounters with prior outcomes and loadouts. Any later adoption must fit existing BattleBuddy pet, target and battle surfaces and be specified separately.
- PetTracker's `addons/battle/listener.lua` derives ability casts and rounds from chat combat messages and records encounter history. This mechanism is incompatible with BattleBuddy's no-combat-log-parsing boundary. Do not reproduce it; unavailable public cooldown/history data remains unknown.

## Integration and acceptance

PetTracker is an optional coexistence case, not a runtime dependency. Verify that BattleBuddy's chosen enemy bar, hover details and swap controls remain readable when PetTracker is present; avoid duplicate information without mutating another addon's protected frames in combat. No standalone PetTracker clone, PBS window or future UltraSquirt window is part of Phase A. Later integrations attach to existing surfaces and expose controls only for shipped behavior.

Check absence/presence of PetTracker, battle start/end, pet selection, enemy replacement, tooltip overlap and missing/secret facts. No dedicated map, tracker, rival-history or collection-alert screenshots were supplied, so visual parity for those features is unproven and outside this battle reference slice. Local source inspection is not live 12.1 compatibility validation.
