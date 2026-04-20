# CrestPlanner

## [v0.1.9](https://github.com/danvernon/crest-planner/tree/v0.1.9) (2026-04-20)
[Full Changelog](https://github.com/danvernon/crest-planner/compare/v0.1.8...v0.1.9) [Previous Releases](https://github.com/danvernon/crest-planner/releases)

- **Season selector dropdown** in the top bar (left of close button); Midnight S2 shown as "coming soon"
- Season data restructured into a per-season registry — adding future seasons requires only a new constants block
- Active season persisted in SavedVariables and restored on login
- `/cp season` slash command to list or switch seasons
- Action rows now say **"Equip bag item then upgrade"** when the optimiser has chosen a bag item over the currently equipped piece
- `/cp debug bags` — new command showing all scanned equippable bag items with track, rank, ilvl and slot for diagnostics

## [v0.1.8](https://github.com/danvernon/crest-planner/tree/v0.1.8) (2026-04-17)
[Full Changelog](https://github.com/danvernon/crest-planner/compare/v0.1.7...v0.1.8) [Previous Releases](https://github.com/danvernon/crest-planner/releases)

- **New: Bonus tab** — dedicated tab showing per-character completion of uncapped crest sources (Cracked Keystone, Nullaeus, Nullaeus Hard)
- Bonus sources tracked via quest completion and achievement APIs; scanned on login alongside normal gear scan
- Hover any bonus row for the full how-to tooltip
- Footer shows total unclaimed count across the warband
- **Summary tab** now scrolls vertically when content overflows

## [v0.1.6](https://github.com/danvernon/crest-planner/tree/v0.1.6) (2026-04-15)
[Full Changelog](https://github.com/danvernon/crest-planner/compare/v0.1.5...v0.1.6) [Previous Releases](https://github.com/danvernon/crest-planner/releases)

- Bug fixes and stability updates  
    Made-with: Cursor  
