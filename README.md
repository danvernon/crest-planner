# Crest Planner

World of Warcraft **Retail** addon that plans how to spend crests across your **warband** so your **current character** finishes Veteran → Champion → Hero → Myth upgrades with less total crest cost. It compares **current-character-first** versus **alt-first** paths when a warband discount can unlock on a track.

**CurseForge:** [crest-planner](https://legacy.curseforge.com/wow/addons/crest-planner)

## Features

- Scans **equipped** and **bag** gear per character you log in on; stores snapshots in **SavedVariables** (`CrestPlannerDB`).
- Per-track optimiser (Veteran, Champion, Hero, Myth): scenarios, savings, and a short **recommended action** list.
- Main window **`/cp`**: track tabs, warband roster, discount progress, summary and weekly-style planning hints.
- **Tooltips** on upgradeable items: track/rank, estimated crest-to-max, discount context, and notes when another character is cheaper for threshold progress.
- Header branding uses `Textures/CrestPlannerLogo.tga` (WoW expects **TGA/BLP**, not PNG, for `SetTexture`).

## Requirements

- Retail WoW with an interface version supported by the manifest (see `CrestPlanner.toc` `## Interface` lines).

## Install

1. Copy the `CrestPlanner` folder into:
   `World of Warcraft\_retail_\Interface\AddOns\`
2. Enable **Crest Planner** in the AddOns list.
3. Or install from CurseForge (link above) once the release is available to your client.

## Usage

- **`/cp`** — open or toggle the planner window.

Data updates when you log in, change equipment, or bags update (with a short debounce). Log each character once so the warband table is populated.

## Repository layout

| Path | Role |
|------|------|
| `CrestPlanner.lua` | Entry: events, slash command, rescan scheduling |
| `core/constants.lua` | Tracks, costs, thresholds, achievement IDs, currency IDs |
| `core/scanner.lua` | Gear scan + tooltip parsing |
| `core/optimiser.lua` | Cost and ordering logic |
| `core/currency.lua` | Crest balances |
| `core/utils.lua` | Character key helpers |
| `ui/mainframe.lua` | Main UI |
| `ui/tooltip.lua` | Tooltip hooks |
| `ui/planner.lua` | Summary / weekly preview |
| `Textures/` | Logo and other UI textures |

## Version

See `## Version` in `CrestPlanner.toc`.

## Automated releases (GitHub Actions + CurseForge)

This repo uses [BigWigsMods/packager](https://github.com/BigWigsMods/packager) to build a correct `CrestPlanner/` zip and upload to CurseForge when you push a **version tag**.

### One-time setup

1. **CurseForge project ID**  
   On your addon’s CurseForge page, open **About** (or project settings) and copy the numeric **Project ID**. Add a line to `CrestPlanner.toc` (anywhere with the other `##` headers):

   `## X-Curse-Project-ID: YOUR_ID_HERE`

2. **CurseForge API key**  
   CurseForge → your profile → **API Tokens** → create a token with upload scope. In the GitHub repo: **Settings → Secrets and variables → Actions → New repository secret**  
   - Name: `CF_API_KEY`  
   - Value: the token  

3. **Workflow permissions**  
   **Settings → Actions → General → Workflow permissions** → choose **Read and write** (so the packager can create GitHub Releases). This matches what the [packager wiki](https://github.com/BigWigsMods/packager/wiki/GitHub-Actions-workflow) describes for `GITHUB_TOKEN`.

### Ship a release

1. Bump `## Version` in `CrestPlanner.toc` (e.g. `0.1.1`).
2. Commit and push to `master` (or your default branch).
3. Create and push an annotated tag whose name starts with `v`, for example:

   `git tag -a v0.1.1 -m "0.1.1"`  
   `git push origin v0.1.1`

The **Package and release** workflow runs, uploads to CurseForge, and can attach a GitHub Release.

**Manual run:** **Actions → Package and release → Run workflow** (`workflow_dispatch`) is available for testing once secrets and `## X-Curse-Project-ID` are set.

## License

See your CurseForge project license (e.g. All Rights Reserved) unless you add a `LICENSE` file here for open source.
