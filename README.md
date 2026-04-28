# Crest Planner

**Warband crest optimisation planner for World of Warcraft retail.**

Plan how to spend crests across your warband so you finish Veteran → Champion → Hero → Myth upgrades with the least total crest cost. The addon tracks every character you log in on, compares upgrade paths, and tells you exactly what to do this week.

**CurseForge:** [crest-planner](https://legacy.curseforge.com/wow/addons/crest-planner)  
**Slash command:** `/cp`

---

## What it does

### Optimal upgrade path
For each track (Veteran, Champion, Hero, Myth) the optimiser runs three scenarios:

- **Scenario A** — upgrade your current character at full price
- **Scenario B** — upgrade an alt first to unlock the warband discount, then finish your main at 50% off
- **Scenario C** — your main self-unlocks the discount, then finishes at 50% off

It picks the cheapest path and tells you what to do, in order.

### Warband discount awareness
The 50% warband discount unlocks when one character maxes all slots on a track. If an alt is closer to the threshold than your main, the addon will recommend upgrading the alt first and show you exactly how much you save.

### Per-track tabs (Veteran / Champion / Hero / Myth)
- Recommended action list with crest costs
- Warband roster showing each character's slot progress and crests needed
- Discount progress panel — how many slots until the 50% discount unlocks per track
- "Enough crests to finish now" callout when your balance already covers the cost

### Summary tab
- Total crest cost across all tracks (optimal path)
- Total savings vs upgrading naively
- Weeks-to-completion estimate based on weekly cap
- Per-track outlook: crests held, crests still needed, weeks at cap
- Priority action list — the highest-value steps across all tracks this week

### Bonus tab
Tracks uncapped crest sources (one-time quests and boss kills) across your warband so you never miss free crests. Shows a per-character checklist with claimed/unclaimed status and a warband total.

### Season selector
Switch between seasons from the top bar. Midnight S2 is listed as coming soon — the addon will update when it releases.

### Bag item scanning
Scans equippable items in your bags. If a bag item is a better upgrade base than your equipped piece, the addon factors it into the plan and flags it with "Equip bag item then upgrade".

### Item tooltips
Hover any upgradeable item to see its track, current rank, estimated crests to max, and any warband discount context.

---

## Setup

1. Install from CurseForge or copy the `CrestPlanner` folder into:  
   `World of Warcraft\_retail_\Interface\AddOns\`
2. Log in on each warband character once so their gear is scanned.
3. Open the planner with **`/cp`**.

Data updates automatically on login, equipment changes, and bag updates.

---

## Slash commands

| Command | Description |
|---------|-------------|
| `/cp` | Open / close the planner |
| `/cp chars` | List all scanned warband characters |
| `/cp remove <name-realm>` | Remove a character record |
| `/cp season` | List available seasons |
| `/cp season <name>` | Switch to a season |
| `/cp debug` | Show equipped item scan data for current character |
| `/cp debug bags` | Show all scanned equippable bag items |

---

## Repository layout

| Path | Role |
|------|------|
| `CrestPlanner.lua` | Entry point: events, slash commands, rescan scheduling |
| `core/constants.lua` | Season registry, tracks, costs, achievement IDs, currency IDs |
| `core/scanner.lua` | Gear scan, tooltip parsing, bonus source tracking |
| `core/optimiser.lua` | Scenario cost and ordering logic |
| `core/currency.lua` | Crest balance queries |
| `core/utils.lua` | Character key helpers |
| `ui/mainframe.lua` | Main window, all tabs |
| `ui/tooltip.lua` | Item tooltip hooks |
| `ui/planner.lua` | Summary and weekly preview logic |
| `Textures/` | UI textures |

## Automated releases

Tags matching `v*` trigger the BigWigsMods packager workflow, which builds the zip and uploads to CurseForge automatically.
