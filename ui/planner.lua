local addonName, CrestPlanner = ...

local Planner = {}
CrestPlanner.Planner = Planner

local TRACK_ORDER = { "Veteran", "Champion", "Hero", "Myth" }
local Constants = CrestPlanner.Constants

local function EffectiveWeeklyCap(currency)
    local apiCap = currency and currency.weeklyMax or 0
    if currency and currency.canEarnPerWeek and apiCap > 0 then
        return apiCap
    end
    local fallback = Constants.DEFAULT_WEEKLY_CREST_CAP or 0
    if fallback > 0 then
        return fallback
    end
    return apiCap
end

local function FirstDiscountTrackOrderNotMet()
    for _, trackName in ipairs(TRACK_ORDER) do
        if not CrestPlanner.Optimiser:IsDiscountAlreadyActive(trackName) then
            local meta = Constants.TRACKS[trackName]
            return meta and meta.order or nil
        end
    end
    return nil
end

local function LineColorHex(trackOrder, focusDiscountOrder, discountActive, optimal)
    if optimal <= 0 then
        return "ff9bb0ae"
    end
    if focusDiscountOrder and trackOrder < focusDiscountOrder then
        return "ffffc857"
    end
    if not discountActive then
        return "ffffc857"
    end
    return "ffffffff"
end

local function BuildOutlookSubtitle(trackResult)
    if trackResult.discountAlreadyActive then
        return "Warband discount active"
    end

    local discountPct = math.floor((Constants.DISCOUNT_RATE or 0.50) * 100 + 0.5)

    if trackResult.altFirstIsBetter then
        return string.format("Upgrade another character first for %d%% discount", discountPct)
    end

    local mainRow
    for _, row in ipairs(trackResult.warbandRows or {}) do
        if row.isMain then
            mainRow = row
            break
        end
    end

    if mainRow then
        local remaining = mainRow.slotsNeeding or 0
        if remaining > 0 then
            return string.format("Discount unlocks in %d more slots", remaining)
        else
            return "Discount threshold reached"
        end
    end

    return ""
end

local function BuildPriorityActions(allTrackResults)
    local actions = {}
    local mainKey = CrestPlanner.GetCurrentCharacterKey()
    local characters = CrestPlanner.Scanner:GetWarbandCharacters()
    local main = characters[mainKey]
    local mainName = main and main.name or "Main"

    for _, trackName in ipairs(TRACK_ORDER) do
        local result = allTrackResults[trackName]
        if not result then
            -- skip
        elseif result.discountAlreadyActive then
            local shown = math.min(3, #(result.mainUpgradeActions or {}))
            if shown > 0 then
                local totalCost = 0
                local slotNames = {}
                for i = 1, shown do
                    totalCost = totalCost + (result.mainUpgradeActions[i].cost or 0)
                    slotNames[#slotNames + 1] = result.mainUpgradeActions[i].slotName
                end
                actions[#actions + 1] = {
                    text = string.format("Upgrade %s %s slots (discount active)", mainName, table.concat(slotNames, " + ")),
                    cost = string.format("%d crests", totalCost),
                    sortKey = 3,
                    trackName = trackName,
                }
            end
        elseif result.altFirstIsBetter then
            local altSlots = {}
            local altCost = 0
            local altCharName
            for _, action in ipairs(result.altActions or {}) do
                altCharName = altCharName or action.characterName
                altSlots[#altSlots + 1] = action.slotName
                altCost = altCost + (action.cost or 0)
            end

            if altCharName and #altSlots > 0 then
                local slotText = #altSlots <= 3 and table.concat(altSlots, " + ") or string.format("%d slots", #altSlots)
                actions[#actions + 1] = {
                    text = string.format(
                        "Upgrade %s %s %s - unlocks %s discount path",
                        altCharName, trackName, slotText, trackName
                    ),
                    cost = string.format("%d crests", altCost),
                    sortKey = 1,
                    trackName = trackName,
                }
            end
        else
            local mainRow
            for _, row in ipairs(result.warbandRows or {}) do
                if row.isMain then
                    mainRow = row
                    break
                end
            end
            local slotsToThreshold = (mainRow and mainRow.slotsNeeding) or 0

            if slotsToThreshold > 0 then
                actions[#actions + 1] = {
                    text = string.format(
                        "Finish %s's last %d %s slots - unlocks warband %s discount",
                        mainName, slotsToThreshold, trackName, trackName
                    ),
                    cost = string.format("%d crests", result.scenarioA or 0),
                    sortKey = 1,
                    trackName = trackName,
                }
            elseif result.remainingMainSlots and result.remainingMainSlots > 0 then
                local shown = math.min(3, #(result.mainUpgradeActions or {}))
                if shown > 0 then
                    local totalCost = 0
                    for i = 1, shown do
                        totalCost = totalCost + (result.mainUpgradeActions[i].cost or 0)
                    end
                    actions[#actions + 1] = {
                        text = string.format("Upgrade %s's remaining %d %s slots", mainName, result.remainingMainSlots, trackName),
                        cost = string.format("%d crests", totalCost),
                        sortKey = 2,
                        trackName = trackName,
                    }
                end
            end
        end
    end

    table.sort(actions, function(a, b)
        if a.sortKey ~= b.sortKey then
            return a.sortKey < b.sortKey
        end
        local aCost = tonumber((a.cost or ""):match("(%d+)")) or math.huge
        local bCost = tonumber((b.cost or ""):match("(%d+)")) or math.huge
        if aCost ~= bCost then
            return aCost < bCost
        end
        return (a.trackName or "") < (b.trackName or "")
    end)

    if #actions == 0 then
        actions[1] = { text = "All tracks complete - no actions needed", cost = "" }
    end

    local maxActions = 4
    if #actions > maxActions then
        local trimmed = {}
        for i = 1, maxActions do
            trimmed[i] = actions[i]
        end
        actions = trimmed
    end

    return actions
end

function Planner:GetWeeklyPreview(allTrackResults)
    local balances = CrestPlanner.Currency:GetCurrentCrestBalances()
    local perTrackBudgetLines = {}
    local perTrackWeeks = {}

    local totalOptimalCost = 0
    local totalMainFirstCost = 0
    local totalSavings = 0
    local priorities = {}

    local focusDiscountOrder = FirstDiscountTrackOrderNotMet()

    local worstWeeks = 0
    local worstTrackName
    local worstRemaining = 0
    local worstWeeklyCap = 0

    local outlookRows = {}
    local resolvedWeeklyCap = 0

    for _, trackName in ipairs(TRACK_ORDER) do
        local result = allTrackResults[trackName]
        if result then
            local optimal = result.scenarioA
            if result.scenarioB < optimal then
                optimal = result.scenarioB
            end
            if result.scenarioC and result.scenarioC < optimal then
                optimal = result.scenarioC
            end

            -- Character switching savings
            if result.shouldSwitchCharacter and result.cheapestCompletionCost
                and result.currentCompletionCost
                and result.cheapestCompletionCost < result.currentCompletionCost then
                local switchSavings = result.currentCompletionCost - result.cheapestCompletionCost
                if switchSavings > 0 then
                    totalSavings = totalSavings + switchSavings
                end
            end

            totalOptimalCost = totalOptimalCost + optimal
            totalMainFirstCost = totalMainFirstCost + result.scenarioA
            totalSavings = totalSavings + (result.scenarioA - optimal)

            local trackInfo = Constants.TRACKS[trackName] or {}
            local trackOrder = trackInfo.order or 0
            local currencyName = trackInfo.currencyName
            local currency = currencyName and balances[currencyName] or nil
            local currentAmount = currency and currency.amount or 0
            local weeklyCap = EffectiveWeeklyCap(currency)
            local discountActive = CrestPlanner.Optimiser:IsDiscountAlreadyActive(trackName)

            if weeklyCap > resolvedWeeklyCap then
                resolvedWeeklyCap = weeklyCap
            end

            local remaining = math.max(0, optimal - currentAmount)
            local weeksForTrack
            if remaining == 0 then
                weeksForTrack = 0
            elseif weeklyCap > 0 then
                weeksForTrack = math.ceil(remaining / weeklyCap)
            else
                weeksForTrack = math.huge
            end

            if optimal > 0 then
                perTrackWeeks[#perTrackWeeks + 1] = weeksForTrack

                if weeksForTrack ~= math.huge and remaining > 0 and weeklyCap > 0 then
                    if weeksForTrack > worstWeeks then
                        worstWeeks = weeksForTrack
                        worstTrackName = trackName
                        worstRemaining = remaining
                        worstWeeklyCap = weeklyCap
                    end
                end

                local weekHint = ""
                if weeksForTrack == math.huge then
                    weekHint = " | cap N/A"
                elseif weeksForTrack > 0 then
                    weekHint = string.format(" | ~%d wk at cap", weeksForTrack)
                end

                local linePlain = string.format(
                    "%s: %d held | %d to goal%s",
                    trackName,
                    currentAmount,
                    optimal,
                    weekHint
                )
                local color = LineColorHex(trackOrder, focusDiscountOrder, discountActive, optimal)
                perTrackBudgetLines[#perTrackBudgetLines + 1] = string.format("|c%s%s|r", color, linePlain)

                outlookRows[#outlookRows + 1] = {
                    trackName = trackName,
                    held = currentAmount,
                    needed = optimal,
                    weeks = weeksForTrack,
                    subtitle = BuildOutlookSubtitle(result),
                    discountActive = discountActive,
                    altFirstIsBetter = result.altFirstIsBetter,
                }
            end

            if result.altFirstIsBetter then
                priorities[#priorities + 1] = {
                    trackName = trackName,
                    savings = result.savings,
                    scenarioB = result.scenarioB,
                }
            end
        end
    end

    table.sort(priorities, function(a, b) return a.savings > b.savings end)

    local estimatedWeeks = 0
    local anyUnknownCap = false
    for _, weeks in ipairs(perTrackWeeks) do
        if weeks == math.huge then
            anyUnknownCap = true
            break
        end
        if weeks > estimatedWeeks then
            estimatedWeeks = weeks
        end
    end
    if anyUnknownCap then
        estimatedWeeks = "N/A"
    end

    local overallWeeksLine
    if estimatedWeeks == "N/A" then
        overallWeeksLine = "N/A (weekly cap unknown for at least one crest)"
    elseif worstTrackName and worstWeeks > 0 then
        overallWeeksLine = string.format(
            "~%d wk: %s is the slowest (%d crest left at %d/wk).",
            worstWeeks,
            worstTrackName,
            worstRemaining,
            worstWeeklyCap
        )
    else
        overallWeeksLine = "0 (no crest cost left)"
    end

    local priorityLines = {}
    for index, item in ipairs(priorities) do
        priorityLines[#priorityLines + 1] = string.format(
            "%d. %s alt-first (saves %d)",
            index,
            item.trackName,
            item.savings
        )
    end

    if #priorityLines == 0 then
        priorityLines[1] = "1. Upgrade current character directly; no alternate-character savings detected."
    end

    local priorityActions = BuildPriorityActions(allTrackResults)

    return {
        crestBudgetByTrack = perTrackBudgetLines,
        totalOptimalCost = totalOptimalCost,
        totalMainFirstCost = totalMainFirstCost,
        totalSavings = totalSavings,
        estimatedWeeks = estimatedWeeks,
        overallWeeksLine = overallWeeksLine,
        priorityLines = priorityLines,
        outlookRows = outlookRows,
        priorityActions = priorityActions,
        weeklyCap = resolvedWeeklyCap > 0 and resolvedWeeklyCap or (Constants.DEFAULT_WEEKLY_CREST_CAP or 100),
    }
end
