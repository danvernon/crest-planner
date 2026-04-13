local addonName, CrestPlanner = ...

local Scanner = {}
CrestPlanner.Scanner = Scanner

local Constants = CrestPlanner.Constants
local ScanTooltip = CreateFrame("GameTooltip", "CrestPlannerScanTooltip", UIParent, "GameTooltipTemplate")
ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
local EQUIP_LOC_TO_SLOTS = {
    INVTYPE_HEAD = { "Head" },
    INVTYPE_NECK = { "Neck" },
    INVTYPE_SHOULDER = { "Shoulder" },
    INVTYPE_CHEST = { "Chest" },
    INVTYPE_ROBE = { "Chest" },
    INVTYPE_WAIST = { "Waist" },
    INVTYPE_LEGS = { "Legs" },
    INVTYPE_FEET = { "Feet" },
    INVTYPE_WRIST = { "Wrist" },
    INVTYPE_HAND = { "Hands" },
    INVTYPE_CLOAK = { "Back" },
    INVTYPE_FINGER = { "Finger1", "Finger2" },
    INVTYPE_TRINKET = { "Trinket1", "Trinket2" },
    INVTYPE_WEAPON = { "MainHand", "OffHand" },
    INVTYPE_WEAPONMAINHAND = { "MainHand" },
    INVTYPE_WEAPONOFFHAND = { "OffHand" },
    INVTYPE_2HWEAPON = { "MainHand" },
    INVTYPE_RANGED = { "MainHand" },
    INVTYPE_RANGEDRIGHT = { "MainHand" },
    INVTYPE_SHIELD = { "OffHand" },
    INVTYPE_HOLDABLE = { "OffHand" },
}

local function EnsureDB()
    CrestPlannerDB = CrestPlannerDB or {}
    local expectedVersion = Constants.DB_VERSION or 1
    if CrestPlannerDB.version ~= expectedVersion then
        CrestPlannerDB.characters = {}
        CrestPlannerDB.config = CrestPlannerDB.config or {}
        CrestPlannerDB.meta = CrestPlannerDB.meta or {}
        CrestPlannerDB.meta.schemaMigratedAt = time()
        CrestPlannerDB.version = expectedVersion
    else
        CrestPlannerDB.characters = CrestPlannerDB.characters or {}
        CrestPlannerDB.config = CrestPlannerDB.config or {}
        CrestPlannerDB.meta = CrestPlannerDB.meta or {}
    end
end

local function HasEntries(t)
    return type(t) == "table" and next(t) ~= nil
end

local function CharacterKey()
    return CrestPlanner.GetCurrentCharacterKey()
end

local function EscapeLuaPattern(text)
    return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function ParseItemLevelFromText(text)
    local levelPattern = ITEM_LEVEL or "Item Level %d"
    local escaped = EscapeLuaPattern(levelPattern)
    local capturePattern = escaped:gsub("%%d", "(%%d+)")
    local value = text:match(capturePattern)
    if value then
        return tonumber(value)
    end
    return nil
end

local function BuildTrackLabelLookup()
    local lookup = {}
    for canonicalTrack, aliases in pairs(Constants.TRACK_NAME_ALIASES or {}) do
        for _, alias in ipairs(aliases) do
            local normalized = tostring(alias):lower():gsub("%s+", "")
            lookup[normalized] = canonicalTrack
        end
    end
    for canonicalTrack in pairs(Constants.TRACKS or {}) do
        local normalized = tostring(canonicalTrack):lower():gsub("%s+", "")
        lookup[normalized] = canonicalTrack
    end
    return lookup
end

local TRACK_LABEL_LOOKUP = BuildTrackLabelLookup()

local function ParseTrackFromText(text)
    local rawTrack, extractedCurrent, extractedMax = text:match("([%a]+)%s+(%d+)%s*/%s*(%d+)")
    if rawTrack then
        local normalizedTrack = rawTrack:lower():gsub("%s+", "")
        local canonicalTrack = TRACK_LABEL_LOOKUP[normalizedTrack]
        if canonicalTrack then
            return canonicalTrack, tonumber(extractedCurrent) or 0, tonumber(extractedMax) or 0
        end
    end

    rawTrack, extractedCurrent, extractedMax = text:match("(.+)%s+(%d+)%s*/%s*(%d+)")
    if not rawTrack then
        return nil
    end

    local normalizedText = rawTrack:lower()
    for normalizedAlias, canonicalTrack in pairs(TRACK_LABEL_LOOKUP) do
        if normalizedText:find(normalizedAlias, 1, true) then
            return canonicalTrack, tonumber(extractedCurrent) or 0, tonumber(extractedMax) or 0
        end
    end
    return nil
end

local function ResolveTrackAndRanks(slotId, itemLink)
    local trackName
    local currentRank
    local maxRank
    local itemLevel

    if not trackName and C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotId)
        if tooltipData and tooltipData.lines then
            for _, line in ipairs(tooltipData.lines) do
                local text = line.leftText or line.text or ""
                if type(text) == "string" and text ~= "" then
                    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

                    if not itemLevel then
                        itemLevel = ParseItemLevelFromText(text)
                    end

                    local parsedTrack, extractedCurrent, extractedMax = ParseTrackFromText(text)
                    if parsedTrack and Constants.TRACKS[parsedTrack] then
                        trackName = parsedTrack
                        currentRank = extractedCurrent
                        maxRank = extractedMax
                        break
                    end
                end
            end
        end
    end

    if not trackName and ScanTooltip and ScanTooltip.SetInventoryItem then
        ScanTooltip:ClearLines()
        ScanTooltip:SetInventoryItem("player", slotId)

        local lineCount = ScanTooltip:NumLines() or 0
        for i = 1, lineCount do
            local leftRegion = _G["CrestPlannerScanTooltipTextLeft" .. i]
            local text = leftRegion and leftRegion:GetText()
            if type(text) == "string" and text ~= "" then
                text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

                if not itemLevel then
                    itemLevel = ParseItemLevelFromText(text)
                end

                local parsedTrack, extractedCurrent, extractedMax = ParseTrackFromText(text)
                if parsedTrack and Constants.TRACKS[parsedTrack] then
                    trackName = parsedTrack
                    currentRank = extractedCurrent
                    maxRank = extractedMax
                    break
                end
            end
        end

        ScanTooltip:Hide()
    end

    trackName = trackName or "Unknown"
    currentRank = currentRank or 0
    maxRank = maxRank or 0

    return trackName, currentRank, maxRank, itemLevel
end

local function ScanEquippedItems()
    local entries = {}

    for _, slot in ipairs(Constants.SLOTS) do
        local itemLink = GetInventoryItemLink("player", slot.id)

        if itemLink then
            local trackName, currentRank, maxRank, itemLevel = ResolveTrackAndRanks(slot.id, itemLink)
            local _, _, _, equipLoc = GetItemInfoInstant(itemLink)

            entries[slot.id] = {
                slotId = slot.id,
                slotName = slot.name,
                itemLink = itemLink,
                equipLoc = equipLoc,
                itemLevel = itemLevel or 0,
                trackName = trackName or "Unknown",
                currentRank = currentRank,
                maxRank = maxRank,
                needsUpgrade = (maxRank or 0) > (currentRank or 0),
                scannedAt = time(),
            }
        end
    end

    return entries
end

local function ParseBagItemTooltip(bagID, slotID, itemLink)
    local trackName
    local currentRank
    local maxRank
    local itemLevel

    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local tooltipData = C_TooltipInfo.GetBagItem(bagID, slotID)
        if tooltipData and tooltipData.lines then
            for _, line in ipairs(tooltipData.lines) do
                local text = line.leftText or line.text or ""
                if type(text) == "string" and text ~= "" then
                    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    if not itemLevel then
                        itemLevel = ParseItemLevelFromText(text)
                    end
                    local parsedTrack, extractedCurrent, extractedMax = ParseTrackFromText(text)
                    if parsedTrack and Constants.TRACKS[parsedTrack] then
                        trackName = parsedTrack
                        currentRank = extractedCurrent
                        maxRank = extractedMax
                        break
                    end
                end
            end
        end
    end

    if not trackName then
        ScanTooltip:ClearLines()
        if ScanTooltip.SetBagItem then
            ScanTooltip:SetBagItem(bagID, slotID)
            local lineCount = ScanTooltip:NumLines() or 0
            for i = 1, lineCount do
                local leftRegion = _G["CrestPlannerScanTooltipTextLeft" .. i]
                local text = leftRegion and leftRegion:GetText()
                if type(text) == "string" and text ~= "" then
                    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    if not itemLevel then
                        itemLevel = ParseItemLevelFromText(text)
                    end
                    local parsedTrack, extractedCurrent, extractedMax = ParseTrackFromText(text)
                    if parsedTrack and Constants.TRACKS[parsedTrack] then
                        trackName = parsedTrack
                        currentRank = extractedCurrent
                        maxRank = extractedMax
                        break
                    end
                end
            end
            ScanTooltip:Hide()
        end
    end

    trackName = trackName or "Unknown"
    currentRank = currentRank or 0
    maxRank = maxRank or 0
    return trackName, currentRank, maxRank, itemLevel or 0
end

local function ScanBagItems()
    local entries = {}

    for bagID = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        local numSlots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bagID) or 0
        for bagSlot = 1, numSlots do
            local itemLink = C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bagID, bagSlot)
            if itemLink then
                local _, _, _, equipLoc = GetItemInfoInstant(itemLink)
                local slotOptions = EQUIP_LOC_TO_SLOTS[equipLoc]
                if slotOptions then
                    local trackName, currentRank, maxRank, itemLevel = ParseBagItemTooltip(bagID, bagSlot, itemLink)
                    entries[#entries + 1] = {
                        bagID = bagID,
                        bagSlot = bagSlot,
                        itemLink = itemLink,
                        itemLevel = itemLevel,
                        trackName = trackName,
                        currentRank = currentRank,
                        maxRank = maxRank,
                        slotOptions = slotOptions,
                        scannedAt = time(),
                    }
                end
            end
        end
    end

    return entries
end

function Scanner:ScanCurrentCharacter()
    EnsureDB()

    local key = CharacterKey()
    CrestPlannerDB.characters[key] = CrestPlannerDB.characters[key] or {}

    CrestPlannerDB.characters[key].name = UnitName("player")
    CrestPlannerDB.characters[key].realm = GetRealmName()
    CrestPlannerDB.characters[key].classFileName = select(2, UnitClass("player"))
    CrestPlannerDB.characters[key].level = UnitLevel("player")
    local scannedEquipped = ScanEquippedItems()
    local scannedBagItems = ScanBagItems()

    -- Guard against transient empty scans (common during logout/loading phases).
    -- Keep previous good snapshot instead of overwriting with empty data.
    if HasEntries(scannedEquipped) then
        CrestPlannerDB.characters[key].equipped = scannedEquipped
    else
        CrestPlannerDB.characters[key].equipped = CrestPlannerDB.characters[key].equipped or {}
    end

    if HasEntries(scannedBagItems) then
        CrestPlannerDB.characters[key].bagItems = scannedBagItems
    else
        CrestPlannerDB.characters[key].bagItems = CrestPlannerDB.characters[key].bagItems or {}
    end
    CrestPlannerDB.characters[key].lastScan = time()

    CrestPlannerDB.meta.lastScannedCharacter = key
    CrestPlannerDB.meta.lastScanAt = time()
end

function Scanner:GetWarbandCharacters()
    EnsureDB()
    return CrestPlannerDB.characters
end
