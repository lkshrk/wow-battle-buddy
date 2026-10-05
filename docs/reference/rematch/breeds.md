# Breeds

## Evidence

`../screenshots/battle-enemy-pet-tooltip-breed.png` is the visual authority: a breed suffix in the pet name and a lower attached tooltip block containing current breed, owned copy/level, possible breeds, and rare level-25 health/power/speed projections. The current breed is marked in the projection list. Preserve the captured possible-breeds line even though current Akolus `process/battleBreedTooltip.lua` omits that separate line.

Local factual sources: `/tmp/ns/ref/BattlePetBreedID/{BattlePetBreedID,BreedTooltips,PetData,OptionsPanel}.lua` and `BattlePetBreedID.toc`; `/tmp/ns/ref/Akolus_12.1-Rematch/info/{breedCalculator,breedInfo}.lua`, `process/battleBreedTooltip.lua`, and `panels/nativeBreedOptions.lua`. No clear reuse license is established here for BattlePetBreedID; treat its code and tables as reference-only until permission is verified.

## Behavior and states

- Breed describes a species' stat distribution, separate from rarity and level. Use the familiar letter pair consistently in pet rows/cards and battle hover. Keep live stats distinct from rare level-25 projections.
- Hovering an allied or enemy battle pet attaches the breed block below the ordinary pet tooltip. Show the inspected breed, owned copies, legal possibilities and comparable projections when known. Owned copies remain separate even if their breeds match; do not silently collapse a collection of three identical copies.
- Low-level or incomplete stats may admit multiple breeds. Preserve ambiguity or show unknown; never select an arbitrary candidate. Missing species/base data suppresses unsupported projections. Do not infer breed from secret battle stats.
- Akolus first uses its native breed provider, then older BPBID interfaces where available. This is evidence of behavior, not a requirement to vendor either implementation or its data. Build against independently licensed/publicly usable facts or an explicitly supported optional provider.
- Breed presentation is shared across journal, loadout, pet card and battle. Only expose Phase A breed controls whose views are implemented; no separate breed window or wholesale copied options page.

## Acceptance and gaps

Compare the supplied enemy tooltip's ordering, attachment, quality colors and current-breed marker. Exercise known/unknown/ambiguous breed, multiple owned copies, unowned species, missing provider, low-level pets and unreadable battle stats. Hover must not mutate journal filters or loadouts. Any temporary source-side journal filtering is an implementation hazard, not desired behavior.

The screenshot covers one enemy tooltip, not every breed format or provider failure. A redistributable breed dataset and validated 12.1 calculation path remain implementation prerequisites; these docs do not grant permission to copy BPBID/Akolus tables, code or assets.
