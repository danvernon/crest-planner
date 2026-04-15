local addonName, CrestPlanner = ...

CrestPlanner.Constants = CrestPlanner.Constants or {}
local Constants = CrestPlanner.Constants
Constants.DB_VERSION = 1

-- Model discount as 50% (20 -> 10 per rank) based on observed upgrade spend.
Constants.DISCOUNT_RATE = 0.50

Constants.SLOTS = {
    { id = 1, name = "Head" },
    { id = 2, name = "Neck" },
    { id = 3, name = "Shoulder" },
    { id = 5, name = "Chest" },
    { id = 6, name = "Waist" },
    { id = 7, name = "Legs" },
    { id = 8, name = "Feet" },
    { id = 9, name = "Wrist" },
    { id = 10, name = "Hands" },
    { id = 11, name = "Finger1" },
    { id = 12, name = "Finger2" },
    { id = 13, name = "Trinket1" },
    { id = 14, name = "Trinket2" },
    { id = 15, name = "Back" },
    { id = 16, name = "MainHand" },
    { id = 17, name = "OffHand" },
}

-- Currency IDs read from installed retail addon data on this machine.
Constants.CREST_CURRENCY_IDS = {
    Weathered = 3383,
    Carved = 3341,
    Runed = 3343,
    Gilded = 3345,
    Myth = 3347,
}

Constants.TRACKS = {
    Adventurer = { order = 0, currencyName = "Weathered" },
    Veteran = { order = 1, currencyName = "Carved" },
    Champion = { order = 2, currencyName = "Runed" },
    Hero = { order = 3, currencyName = "Gilded" },
    Myth = { order = 4, currencyName = "Myth" },
}

Constants.TRACK_NAME_ALIASES = {
    Adventurer = { "Adventurer" },
    Veteran = { "Veteran" },
    Champion = { "Champion" },
    Hero = { "Hero" },
    Myth = { "Myth" },
}

-- Per-rank crest spend table used by optimiser math.
-- Update these if Blizzard changes costs during a season.
Constants.UPGRADE_COSTS_PER_RANK = {
    Adventurer = { 20, 20, 20, 20, 20 },
    Veteran = { 20, 20, 20, 20, 20 },
    Champion = { 20, 20, 20, 20, 20 },
    Hero = { 20, 20, 20, 20, 20 },
    Myth = { 20, 20, 20, 20, 20 },
}

-- Transition equivalence between adjacent tracks.
-- Example: Champion 6/6 behaves like Hero 2/6 baseline.
Constants.TRACK_TRANSITION_EQUIVALENT_RANK = {
    Adventurer = { Veteran = 2 },
    Veteran = { Champion = 2 },
    Champion = { Hero = 2 },
    Hero = { Myth = 2 },
}

-- Discount unlocks when ALL equipped slots are at max rank for the track.
-- Empty table — the optimiser derives the threshold dynamically from each
-- character's actual equipped slot count (15 for 2H, 16 for 1H+OH).
Constants.DISCOUNT_THRESHOLDS = {}

Constants.DISCOUNT_ACHIEVEMENT_IDS = {
    Adventurer = 61809,
    Veteran = 42767,
    Champion = 42768,
    Hero = 42769,
    Myth = 42770,
}

-- When GetCurrencyInfo omits weekly data, assume this earn cap for crest planning (Midnight-era tuning).
Constants.DEFAULT_WEEKLY_CREST_CAP = 100

-- Minimum character level to engage with crest progression.
-- Characters below this see a "Reach level X to activate" overlay and are
-- excluded from the warband view on other characters.
Constants.MIN_CHARACTER_LEVEL = 90

-- Item level to track/rank mapping (Midnight expansion).
-- Track ranges from Wowhead guide (overlap is intentional — transition points):
--   Adventurer: 220-237, Veteran: 233-250, Champion: 246-263,
--   Hero: 259-276, Myth: 272-289
-- Where ranges overlap, we prefer the HIGHER track (more valuable for warband progress).
-- Each track has 6 ranks evenly spaced across its range (~3.4 ilvls per rank).
-- Used as fallback when tooltip parsing fails (e.g. crafted items).
Constants.ILVL_TO_TRACK_RANK = {
    -- Adventurer 1/6 through 6/6 (220-237)
    { 220, 222, "Adventurer", 1, 6 },
    { 223, 226, "Adventurer", 2, 6 },
    { 227, 229, "Adventurer", 3, 6 },
    { 230, 232, "Adventurer", 4, 6 },
    -- Veteran 1/6 through 6/6 (233-250) — overlaps with Adventurer 5-6/6
    { 233, 235, "Veteran", 1, 6 },
    { 236, 239, "Veteran", 2, 6 },
    { 240, 242, "Veteran", 3, 6 },
    { 243, 245, "Veteran", 4, 6 },
    -- Champion 1/6 through 6/6 (246-263) — overlaps with Veteran 5-6/6
    { 246, 249, "Champion", 1, 6 },
    { 250, 252, "Champion", 2, 6 },
    { 253, 255, "Champion", 3, 6 },
    { 256, 258, "Champion", 4, 6 },
    -- Hero 1/6 through 6/6 (259-276) — overlaps with Champion 5-6/6
    { 259, 262, "Hero", 1, 6 },
    { 263, 265, "Hero", 2, 6 },
    { 266, 268, "Hero", 3, 6 },
    { 269, 271, "Hero", 4, 6 },
    -- Myth 1/6 through 6/6 (272-289) — overlaps with Hero 5-6/6
    { 272, 275, "Myth", 1, 6 },
    { 276, 278, "Myth", 2, 6 },
    { 279, 281, "Myth", 3, 6 },
    { 282, 285, "Myth", 4, 6 },
    { 286, 288, "Myth", 5, 6 },
    { 289, 289, "Myth", 6, 6 },
}
