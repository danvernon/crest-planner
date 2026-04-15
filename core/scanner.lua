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

local function TrackRankFromItemLevel(ilvl)
    if not ilvl or ilvl <= 0 then
        return nil, 0, 0
    end
    local lookup = Constants.ILVL_TO_TRACK_RANK
    if not lookup then
        return nil, 0, 0
    end
    -- Exact match first
    for _, entry in ipairs(lookup) do
        if ilvl >= entry[1] and ilvl <= entry[2] then
            return entry[3], entry[4], entry[5]
        end
    end
    -- Closest match for ilvls that fall between brackets (e.g. 648 between 645 and 649)
    local bestEntry
    local bestDiff = math.huge
    for _, entry in ipairs(lookup) do
        local mid = (entry[1] + entry[2]) / 2
        local diff = math.abs(ilvl - mid)
        if diff < bestDiff then
            bestDiff = diff
            bestEntry = entry
        end
    end
    if bestEntry and bestDiff <= 3 then
        return bestEntry[3], bestEntry[4], bestEntry[5]
    end
    return nil, 0, 0
end

local function ResolveTrackAndRanks(slotId, itemLink)
    local trackName
    local currentRank
    local maxRank
    local itemLevel

    if not trackName and C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotId)
        if tooltipData then
            -- SurfaceArgs populates leftText/rightText from the raw tooltip data.
            -- Without this call, leftText may be nil on modern clients.
            if TooltipUtil and TooltipUtil.SurfaceArgs then
                TooltipUtil.SurfaceArgs(tooltipData)
            end
        end
        if tooltipData and tooltipData.lines then
            for _, line in ipairs(tooltipData.lines) do
                local texts = {}
                if type(line.leftText) == "string" and line.leftText ~= "" then
                    texts[#texts + 1] = line.leftText
                end
                if type(line.rightText) == "string" and line.rightText ~= "" then
                    texts[#texts + 1] = line.rightText
                end
                if type(line.text) == "string" and line.text ~= "" and #texts == 0 then
                    texts[#texts + 1] = line.text
                end

                for _, raw in ipairs(texts) do
                    local text = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

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
                if trackName then break end
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

    -- Ensure we have an item level even if tooltip parsing missed it.
    if not itemLevel or itemLevel <= 0 then
        if GetDetailedItemLevelInfo then
            itemLevel = GetDetailedItemLevelInfo(itemLink) or 0
        end
        if (not itemLevel or itemLevel <= 0) and C_Item and C_Item.GetCurrentItemLevel then
            local itemLoc = ItemLocation:CreateFromEquipmentSlot(slotId)
            if itemLoc and itemLoc:IsValid() then
                itemLevel = C_Item.GetCurrentItemLevel(itemLoc) or 0
            end
        end
    end

    -- Fallback: if tooltip parsing failed but we have an item level, derive track/rank
    -- from the ilvl bracket table. Handles crafted items and non-standard tooltips.
    if not trackName and itemLevel and itemLevel > 0 then
        local inferredTrack, inferredRank, inferredMax = TrackRankFromItemLevel(itemLevel)
        if inferredTrack then
            trackName = inferredTrack
            currentRank = inferredRank
            maxRank = inferredMax
        end
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
        if tooltipData then
            if TooltipUtil and TooltipUtil.SurfaceArgs then
                TooltipUtil.SurfaceArgs(tooltipData)
            end
        end
        if tooltipData and tooltipData.lines then
            for _, line in ipairs(tooltipData.lines) do
                local texts = {}
                if type(line.leftText) == "string" and line.leftText ~= "" then
                    texts[#texts + 1] = line.leftText
                end
                if type(line.rightText) == "string" and line.rightText ~= "" then
                    texts[#texts + 1] = line.rightText
                end
                if type(line.text) == "string" and line.text ~= "" and #texts == 0 then
                    texts[#texts + 1] = line.text
                end

                for _, raw in ipairs(texts) do
                    local text = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
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
                if trackName then break end
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

    if not trackName and itemLevel and itemLevel > 0 then
        local inferredTrack, inferredRank, inferredMax = TrackRankFromItemLevel(itemLevel)
        if inferredTrack then
            trackName = inferredTrack
            currentRank = inferredRank
            maxRank = inferredMax
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
    local scanTime = time()
    CrestPlannerDB.characters[key].lastScan = scanTime

    CrestPlannerDB.meta.lastScannedCharacter = key
    CrestPlannerDB.meta.lastScanAt = scanTime
end

function Scanner:GetWarbandCharacters()
    EnsureDB()
    return CrestPlannerDB.characters
end
