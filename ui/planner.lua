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

    for _, trackName in ipairs(TRACK_ORDER) do
        local result = allTrackResults[trackName]
        if result then
            local optimal = result.scenarioA
            if result.scenarioB < optimal then
                optimal = result.scenarioB
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
            "~%d wk: %s is the slowest (%d crest left at %d/wk). Other rows show each track on its own.",
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
        priorityLines[1] = "1. Upgrade main directly; no alt-first savings currently detected."
    end

    return {
        crestBudgetByTrack = perTrackBudgetLines,
        totalOptimalCost = totalOptimalCost,
        totalMainFirstCost = totalMainFirstCost,
        totalSavings = totalSavings,
        estimatedWeeks = estimatedWeeks,
        overallWeeksLine = overallWeeksLine,
        priorityLines = priorityLines,
        message = #perTrackBudgetLines > 0 and table.concat({
            "|cff9bb0ae~N wk ≈ weeks to finish that row at weekly cap (API or "
                .. tostring(Constants.DEFAULT_WEEKLY_CREST_CAP)
                .. "/wk). Gold = work left on a tier before your next discount milestone.|r",
            "",
            table.concat(perTrackBudgetLines, "\n"),
        }, "\n") or "|cff9bb0aeNo crest goals left on Veteran–Myth (all rows at 0 to goal).|r",
    }
end
