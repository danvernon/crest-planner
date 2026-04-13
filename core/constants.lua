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

-- Slots required to unlock the warband discount for a track.
-- If your region/season differs, adjust here.
Constants.DISCOUNT_THRESHOLDS = {
    Adventurer = 8,
    Veteran = 8,
    Champion = 8,
    Hero = 8,
    Myth = 8,
}

Constants.DISCOUNT_ACHIEVEMENT_IDS = {
    Adventurer = 61809,
    Veteran = 42767,
    Champion = 42768,
    Hero = 42769,
    Myth = 42770,
}

-- When GetCurrencyInfo omits weekly data, assume this earn cap for crest planning (Midnight-era tuning).
Constants.DEFAULT_WEEKLY_CREST_CAP = 100
