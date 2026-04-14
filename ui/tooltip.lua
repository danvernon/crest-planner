local addonName, CrestPlanner = ...

local Tooltip = {}
CrestPlanner.Tooltip = Tooltip
Tooltip.enabled = false
local OrderedTracks
Tooltip._trackEvalCache = Tooltip._trackEvalCache or {}

local function TrackOrder(trackName)
    local tracks = CrestPlanner.Constants and CrestPlanner.Constants.TRACKS
    if not tracks or not tracks[trackName] then
        return nil
    end
    return tracks[trackName].order
end

OrderedTracks = function()
    local ordered = {}
    local tracks = CrestPlanner.Constants and CrestPlanner.Constants.TRACKS or {}
    for trackName, info in pairs(tracks) do
        ordered[#ordered + 1] = { name = trackName, order = info.order or 0 }
    end
    table.sort(ordered, function(a, b) return a.order < b.order end)
    return ordered
end

local function CurrentGoalTrack(character)
    local ordered = OrderedTracks()

    -- Intuitive progression rule:
    -- if multiple tracks are in progress, finish the lower track first.
    -- Example: Hero and Myth both unfinished -> target Hero.
    for _, track in ipairs(ordered) do
        for _, item in pairs((character and character.equipped) or {}) do
            if item.trackName == track.name and (item.currentRank or 0) < (item.maxRank or 0) then
                return track.name
            end
        end
    end

    -- Fallback to highest track if no incomplete known-track items are found.
    return ordered[#ordered] and ordered[#ordered].name or nil
end

local function GetCachedTrackResult(trackName)
    if not trackName or not CrestPlanner.Optimiser or not CrestPlanner.Optimiser.EvaluateTrack then
        return nil
    end

    local scanStamp = CrestPlannerDB and CrestPlannerDB.meta and CrestPlannerDB.meta.lastScanAt or 0
    local now = GetTime and GetTime() or 0
    local cacheKey = tostring(trackName)
    local cached = Tooltip._trackEvalCache[cacheKey]
    if cached and cached.scanStamp == scanStamp and (now - cached.at) <= 0.5 then
        return cached.result
    end

    local result = CrestPlanner.Optimiser:EvaluateTrack(trackName)
    Tooltip._trackEvalCache[cacheKey] = {
        at = now,
        scanStamp = scanStamp,
        result = result,
    }
    return result
end

local function IsTrackCompleteForItem(itemTrack, currentRank, maxRank)
    if not itemTrack or itemTrack == "Unknown" then
        return false
    end
    return (maxRank or 0) > 0 and (currentRank or 0) >= (maxRank or 0)
end

local function ResolveItemLink(tooltip, data)
    local itemLink

    if tooltip and tooltip.GetItem then
        local _, linkFromTooltip = tooltip:GetItem()
        itemLink = linkFromTooltip
    end

    if not itemLink and type(data) == "table" then
        itemLink = data.hyperlink or data.itemLink
    end

    return itemLink
end

local function EstimateItemMaxCost(trackName, currentRank, maxRank)
    local costs = CrestPlanner.Constants.UPGRADE_COSTS_PER_RANK[trackName] or {}
    local total = 0
    local startRank = math.max(1, currentRank or 1)
    local endRank = math.max(0, (maxRank or 0) - 1)
    for rank = startRank, endRank do
        total = total + (costs[rank] or 0)
    end
    return total
end

local function IsItemAtLeastAsProgressed(lhs, rhs)
    if not lhs or not rhs then
        return false
    end

    local lhsOrder = TrackOrder(lhs.trackName)
    local rhsOrder = TrackOrder(rhs.trackName)
    if not lhsOrder or not rhsOrder then
        return false
    end

    if lhsOrder ~= rhsOrder then
        return lhsOrder > rhsOrder
    end

    local lhsMax = lhs.maxRank or 0
    local rhsMax = rhs.maxRank or 0
    local lhsRank = lhs.currentRank or 0
    local rhsRank = rhs.currentRank or 0

    if lhsMax > 0 and rhsMax > 0 and lhsRank >= lhsMax and rhsRank < rhsMax then
        return true
    end
    if lhsMax > 0 and rhsMax > 0 and lhsRank < lhsMax and rhsRank >= rhsMax then
        return false
    end

    return lhsRank >= rhsRank
end

local function BagItemAlreadyCoveredByEquipped(character, bagItem)
    if not character or not bagItem then
        return false
    end

    for _, slotName in ipairs(bagItem.slotOptions or {}) do
        for _, equippedItem in pairs(character.equipped or {}) do
            if equippedItem.slotName == slotName and IsItemAtLeastAsProgressed(equippedItem, bagItem) then
                return true
            end
        end
    end

    return false
end

function Tooltip:AppendUpgradeInfo(tooltip, data)
    local itemLink = ResolveItemLink(tooltip, data)
    if not itemLink then
        return
    end

    local characters = CrestPlanner.Scanner:GetWarbandCharacters()
    local key = CrestPlanner.GetCurrentCharacterKey()
    local current = characters[key]
    if not current then
        return
    end

    local trackName, currentRank, maxRank, itemLevel
    local function MatchItem(collection, source)
        for _, item in pairs(collection or {}) do
            if item.itemLink == itemLink then
                return item, source
            end
        end
        return nil, nil
    end

    local matched, matchedSource = MatchItem(current.equipped, "equipped")
    if not matched then
        matched, matchedSource = MatchItem(current.bagItems, "bag")
    end
    if matched then
        trackName = matched.trackName
        currentRank = matched.currentRank
        maxRank = matched.maxRank
        itemLevel = matched.itemLevel
    end

    if not trackName or not currentRank or not maxRank then
        return
    end

    if not tooltip or not tooltip.AddLine then
        return
    end

    if trackName == "Unknown" or (maxRank or 0) == 0 then
        local inferred = CrestPlanner.Optimiser and CrestPlanner.Optimiser.InferTrackByItemLevel
            and CrestPlanner.Optimiser:InferTrackByItemLevel(itemLevel or 0)

        tooltip:AddLine(" ")
        if inferred then
            tooltip:AddLine(
                string.format("CrestPlanner: inferred %s %d/%d (est)", inferred.trackName, inferred.currentRank or 0, inferred.maxRank or 0),
                0.35,
                0.8,
                1
            )
            tooltip:AddLine(
                string.format("From item level %d (closest known ilvl %d)", itemLevel or 0, inferred.itemLevel or 0),
                0.8,
                0.8,
                0.8
            )
            tooltip:AddLine(string.format("Inference confidence: %s", inferred.confidence or "low"), 0.8, 0.8, 0.8)
            tooltip:AddLine("Likely contributes as this inferred track/rank", 0.2, 1, 0.2)
        else
            tooltip:AddLine("CrestPlanner: Non-track item", 0.7, 0.7, 0.7)
            tooltip:AddLine("Does not count toward crest-track achievement progress", 0.7, 0.7, 0.7)
        end
        if tooltip.Show then
            tooltip:Show()
        end
        return
    end

    local goalTrack = CurrentGoalTrack(current)
    local baseCost = EstimateItemMaxCost(trackName, currentRank, maxRank)
    local discounted = math.floor(baseCost * (1 - CrestPlanner.Constants.DISCOUNT_RATE) + 0.5)
    local isComplete = (maxRank or 0) > 0 and (currentRank or 0) >= (maxRank or 0)
    local bagCoveredByEquipped = matchedSource == "bag" and BagItemAlreadyCoveredByEquipped(current, matched)

    tooltip:AddLine(" ")
    tooltip:AddLine(string.format("CrestPlanner: %s %d/%d", trackName, currentRank, maxRank), 0.35, 0.8, 1)

    local targetTrack = goalTrack
    local targetOrder = TrackOrder(targetTrack)
    local itemOrder = TrackOrder(trackName)
    local itemTrackComplete = IsTrackCompleteForItem(trackName, currentRank, maxRank)

    local shortStatus
    local shortCost
    local statusColor = { 0.2, 1, 0.2 } -- default green

    if bagCoveredByEquipped then
        shortStatus = "Already covered by equipped item for this slot"
        shortCost = nil
        statusColor = { 0.2, 1, 0.2 }
    elseif targetTrack and targetOrder and itemOrder then
        if itemOrder < targetOrder then
            if itemTrackComplete then
                shortStatus = string.format("Complete for %s, below %s", trackName, targetTrack)
            else
                shortStatus = string.format("Progressing %s, below %s", trackName, targetTrack)
            end
            statusColor = { 1, 0.82, 0 } -- orange when below current target
        elseif itemOrder == targetOrder then
            if itemTrackComplete then
                shortStatus = string.format("Complete for current target: %s", targetTrack)
            else
                shortStatus = string.format("Progress toward current target: %s", targetTrack)
                statusColor = { 1, 0.82, 0 } -- orange for in-progress current target
            end
        else
            shortStatus = string.format("Exceeds current target: %s", targetTrack)
        end

        if baseCost > 0 then
            if CrestPlanner.Optimiser:IsDiscountAlreadyActive(trackName) then
                shortCost = string.format("Cost to max: %d (%d discounted)", baseCost, discounted)
            else
                shortCost = string.format("Cost to max: %d", baseCost)
            end
        end
    elseif isComplete then
        shortStatus = string.format("Complete for %s", trackName)
    elseif CrestPlanner.Optimiser:IsDiscountAlreadyActive(trackName) then
        shortStatus = "Contributes to unlock"
        statusColor = { 1, 0.82, 0 }
        if baseCost > 0 then
            shortCost = string.format("Cost to max: %d (%d discounted)", baseCost, discounted)
        end
    else
        shortStatus = "Contributes to unlock"
        statusColor = { 1, 0.82, 0 }
        if baseCost > 0 then
            shortCost = string.format("Cost to max: %d", baseCost)
        end
    end

    if shortStatus then
        tooltip:AddLine(shortStatus, statusColor[1], statusColor[2], statusColor[3])
    end
    if shortCost then
        tooltip:AddLine(shortCost, 1, 0.82, 0)
    end

    -- Decision hint: if another character is currently the cheaper path for this track,
    -- warn before spending on the viewed character.
    if trackName and trackName ~= "Unknown"
        and baseCost > 0
        and not bagCoveredByEquipped
        and CrestPlanner.Optimiser
        and CrestPlanner.Optimiser.EvaluateTrack then
        local trackResult = GetCachedTrackResult(trackName)
        local currentName = UnitName("player") or "Current"
        if trackResult
            and trackResult.shouldSwitchCharacter
            and trackResult.cheapestCompletionCharacter
            and trackResult.cheapestCompletionCharacter ~= currentName
            and not trackResult.discountAlreadyActive then
            tooltip:AddLine(
                string.format("Better first: %s for %s discount progress", trackResult.cheapestCompletionCharacter, trackName),
                1,
                0.35,
                0.35
            )
        end
    end

    if tooltip.Show then
        tooltip:Show()
    end
end

function Tooltip:Enable()
    if self.enabled then
        return
    end

    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            Tooltip:AppendUpgradeInfo(tooltip, data)
        end)
    elseif GameTooltip and GameTooltip.GetItem then
        if GameTooltip:HasScript("OnTooltipSetItem") then
            GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
                Tooltip:AppendUpgradeInfo(tooltip)
            end)
        else
            hooksecurefunc(GameTooltip, "SetHyperlink", function()
                Tooltip:AppendUpgradeInfo(GameTooltip)
            end)
        end
    end

    self.enabled = true
end
