# UltraSquirt Reloaded contributor guide

## Scope and layout

- `UltraSquirtReloaded/` is the addon directory installed in `_retail_/Interface/AddOns/`.
- `UltraSquirtReloaded.toc` is the load manifest. Its file order is runtime order; preserve it unless a dependency requires a change.
- `UltraSquirtReloaded.lua` is the addon entry point and primary UI/command logic.
- `UltraFactory.lua` and `UltraActions.lua` implement battle-script generation and actions.
- `Locales/` contains AceLocale translations. Add new user-facing English keys in `Locales/enUS.lua`; add matching translations when possible.
- `Libs/` is vendored third-party code. Do not edit or reformat it unless intentionally upgrading that dependency and preserving its license notices.

## Addon identity

Keep these identifiers aligned when changing the addon identity:

- Addon folder and TOC: `UltraSquirtReloaded`
- Main script: `UltraSquirtReloaded/UltraSquirtReloaded.lua`
- SavedVariables: `UltraSquirtReloadedSettingsDB`
- Author: `lkshrk`
- Retail interface version: `120100`

The addon has optional integrations with `Rematch`, `tdBattlePetScript`, and `tdBattlePetScript_Rematch`. Treat their globals as optional: test availability before using them and retain graceful behavior when they are absent.

## World of Warcraft API rules

This project targets retail WoW 12.1 (Midnight). Do not rely on older API examples.

- Before changing a WoW API call, look it up with `wow-api <name>` in the WoW workspace.
- Prefer namespaced APIs, e.g. `C_Spell.*`, `C_AddOns.*`, and `C_ActionBar.*`; legacy globals removed in modern retail must not be introduced.
- Combat-related values can be secret. Do not compare, do arithmetic on, index with, or use secret values as table keys. Check `issecretvalue`/`canaccessvalue` and use supported widget, curve, or duration-object APIs instead.
- `COMBAT_LOG_EVENT_UNFILTERED` is unavailable in current retail and must not be registered.
- Do not manipulate protected or secure frames in combat. Defer protected changes until `PLAYER_REGEN_ENABLED`.

## Validation and in-game testing

Work in the `dev/wow-addons` Coder workspace. Before editing, inspect current game errors:

```sh
wow-errors --match UltraSquirtReloaded
```

Validate touched code before committing:

```sh
cd ~/wow-ultrasquirt-reloaded
wow-check UltraSquirtReloaded
```

`wow-check` must have no errors. Existing warnings around optional Rematch globals may be present; do not add new warnings in changed code. If using or changing a WoW API, validate its current signature first with `wow-api`.

To test in game, always preview then sync the explicit addon path:

```sh
wow-sync --dry-run ~/wow-ultrasquirt-reloaded/UltraSquirtReloaded
wow-sync ~/wow-ultrasquirt-reloaded/UltraSquirtReloaded
```

This sends a separate `UltraSquirtReloaded-Dev` copy and does not overwrite the released addon. Ask the user to `/reload`, exercise the change, then run `wow-errors --match UltraSquirtReloaded` again. Never sync without an explicit path. Before syncing name-related changes, check TOC dependency fields and repository source for references to `UltraSquirtReloaded`.

## Repository hygiene

- The project is GPL-3.0. Keep `LICENSE`, upstream attribution, and licenses in `UltraSquirtReloaded/Libs/` intact.
- Do not commit `_retail_` data, `WTF/`, `Cache/`, logs, packaged ZIPs, IDE files, or generated release output; `.gitignore` covers the usual cases.
- Keep changes focused. Do not make drive-by reformatting changes to vendored libraries or unrelated localizations.
- Commit after `wow-check` passes with no errors. Push only when requested.
