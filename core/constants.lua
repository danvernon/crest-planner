local addonName, CrestPlanner = ...

CrestPlanner.Constants = CrestPlanner.Constants or {}
local Constants = CrestPlanner.Constants
Constants.DB_VERSION = 1

-- Model discount as 50% (20 -> 10 per rank) based on observed upgrade spend.
Constants.DISCOUNT_RATE = 0.50

-- Gear slot IDs — season-agnostic.
Constants.SLOTS = {
    { id = 1,  name = "Head" },
    { id = 2,  name = "Neck" },
    { id = 3,  name = "Shoulder" },
    { id = 5,  name = "Chest" },
    { id = 6,  name = "Waist" },
    { id = 7,  name = "Legs" },
    { id = 8,  name = "Feet" },
    { id = 9,  name = "Wrist" },
    { id = 10, name = "Hands" },
    { id = 11, name = "Finger1" },
    { id = 12, name = "Finger2" },
    { id = 13, name = "Trinket1" },
    { id = 14, name = "Trinket2" },
    { id = 15, name = "Back" },
    { id = 16, name = "MainHand" },
    { id = 17, name = "OffHand" },
}

-- Transition equivalence between adjacent tracks — season-agnostic.
-- Example: Champion 6/6 behaves like Hero 2/6 baseline.
Constants.TRACK_TRANSITION_EQUIVALENT_RANK = {
    Adventurer = { Veteran   = 2 },
    Veteran    = { Champion  = 2 },
    Champion   = { Hero      = 2 },
    Hero       = { Myth      = 2 },
}

-- Discount unlocks when ALL equipped slots are at max rank for the track.
-- Empty — the optimiser derives the threshold dynamically from each
-- character's actual equipped slot count (15 for 2H, 16 for 1H+OH).
Constants.DISCOUNT_THRESHOLDS = {}

-- Minimum character level to engage with crest progression.
-- Characters below this see a "Reach level X to activate" overlay and are
-- excluded from the warband view on other characters.
Constants.MIN_CHARACTER_LEVEL = 90

---------------------------------------------------------------------------
-- Season registry
-- Everything that changes season-to-season lives here.
-- Call Constants.ApplySeason(key) to make a season active; it overlays
-- the relevant keys onto the flat Constants table so all existing code
-- continues to work without modification.
---------------------------------------------------------------------------
Constants.SEASONS = {
    Midnight_S1 = {
        label = "Midnight S1",

        -- Currency IDs (from retail addon data).
        CREST_CURRENCY_IDS = {
            Weathered = 3383,
            Carved    = 3341,
            Runed     = 3343,
            Gilded    = 3345,
            Myth      = 3347,
        },

        TRACKS = {
            Adventurer = { order = 0, currencyName = "Weathered" },
            Veteran    = { order = 1, currencyName = "Carved"    },
            Champion   = { order = 2, currencyName = "Runed"     },
            Hero       = { order = 3, currencyName = "Gilded"    },
            Myth       = { order = 4, currencyName = "Myth"      },
        },

        TRACK_NAME_ALIASES = {
            Adventurer = { "Adventurer" },
            Veteran    = { "Veteran"    },
            Champion   = { "Champion"   },
            Hero       = { "Hero"       },
            Myth       = { "Myth"       },
        },

        -- Per-rank crest spend table used by optimiser math.
        UPGRADE_COSTS_PER_RANK = {
            Adventurer = { 20, 20, 20, 20, 20 },
            Veteran    = { 20, 20, 20, 20, 20 },
            Champion   = { 20, 20, 20, 20, 20 },
            Hero       = { 20, 20, 20, 20, 20 },
            Myth       = { 20, 20, 20, 20, 20 },
        },

        DISCOUNT_ACHIEVEMENT_IDS = {
            Adventurer = 61809,
            Veteran    = 42767,
            Champion   = 42768,
            Hero       = 42769,
            Myth       = 42770,
        },

        -- When GetCurrencyInfo omits weekly data, assume this earn cap.
        DEFAULT_WEEKLY_CREST_CAP = 100,

        -- Item level to track/rank mapping.
        -- Ranges from Wowhead guide (overlap intentional — transition points).
        -- Where ranges overlap, we prefer the HIGHER track.
        ILVL_TO_TRACK_RANK = {
            -- Adventurer 1/6 – 6/6 (220-237)
            { 220, 222, "Adventurer", 1, 6 },
            { 223, 226, "Adventurer", 2, 6 },
            { 227, 229, "Adventurer", 3, 6 },
            { 230, 232, "Adventurer", 4, 6 },
            -- Veteran 1/6 – 6/6 (233-250) — overlaps Adventurer 5-6/6
            { 233, 235, "Veteran", 1, 6 },
            { 236, 239, "Veteran", 2, 6 },
            { 240, 242, "Veteran", 3, 6 },
            { 243, 245, "Veteran", 4, 6 },
            -- Champion 1/6 – 6/6 (246-263) — overlaps Veteran 5-6/6
            { 246, 249, "Champion", 1, 6 },
            { 250, 252, "Champion", 2, 6 },
            { 253, 255, "Champion", 3, 6 },
            { 256, 258, "Champion", 4, 6 },
            -- Hero 1/6 – 6/6 (259-276) — overlaps Champion 5-6/6
            { 259, 262, "Hero", 1, 6 },
            { 263, 265, "Hero", 2, 6 },
            { 266, 268, "Hero", 3, 6 },
            { 269, 271, "Hero", 4, 6 },
            -- Myth 1/6 – 6/6 (272-289) — overlaps Hero 5-6/6
            { 272, 275, "Myth", 1, 6 },
            { 276, 278, "Myth", 2, 6 },
            { 279, 281, "Myth", 3, 6 },
            { 282, 285, "Myth", 4, 6 },
            { 286, 288, "Myth", 5, 6 },
            { 289, 289, "Myth", 6, 6 },
        },

        -- Bonus crest sources that don't count toward the weekly cap.
        -- checkType: "quest"       → C_QuestLog.IsQuestFlaggedCompleted(checkID)
        --            "achievement" → GetAchievementInfo(checkID) completed flag
        -- frequency: "weekly" resets each week, "once" is one-time per character.
        BONUS_CREST_SOURCES = {
            {
                id        = "cracked_keystone",
                label     = "Cracked Keystone",
                hint      = "Complete a Tier 11 Delve for the keystone, then finish a Mythic+ 2 or higher.",
                checkType = "quest",
                checkID   = 92600,
                crests    = { Hero = 20, Myth = 20 },
                frequency = "once",
            },
            {
                id        = "nullaeus_normal",
                label     = "Nullaeus",
                hint      = "Defeat the Delve Nemesis boss on normal difficulty.",
                checkType = "achievement",
                checkID   = 61797,
                crests    = { Hero = 30 },
                frequency = "once",
            },
            {
                id        = "nullaeus_hard",
                label     = "Nullaeus (Hard)",
                hint      = "Defeat the Delve Nemesis boss on hard difficulty.",
                checkType = "achievement",
                checkID   = 61798,
                crests    = { Myth = 30 },
                frequency = "once",
            },
        },
    },

    Midnight_S2 = {
        label      = "Midnight S2",
        comingSoon = true,
    },
}

---------------------------------------------------------------------------
-- Season helpers
---------------------------------------------------------------------------

-- Returns an ordered list of season keys (insertion order via a separate array).
Constants.SEASON_ORDER = { "Midnight_S1", "Midnight_S2" }

-- Overlays the named season's data onto the flat Constants table.
-- All existing code continues to read Constants.TRACKS, Constants.BONUS_CREST_SOURCES,
-- etc. without any changes.
function Constants.ApplySeason(key)
    local season = Constants.SEASONS[key]
    if not season then
        return false
    end
    Constants.ACTIVE_SEASON = key
    for k, v in pairs(season) do
        if k ~= "label" then
            Constants[k] = v
        end
    end
    return true
end

-- Default to the first (and currently only) season.
Constants.ACTIVE_SEASON = Constants.SEASON_ORDER[1]
Constants.ApplySeason(Constants.ACTIVE_SEASON)
