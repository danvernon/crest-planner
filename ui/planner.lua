local addonName, CrestPlanner = ...

local Planner = {}
CrestPlanner.Planner = Planner

local TRACK_ORDER = { "Veteran", "Champion", "Hero", "Myth" }
local Constants = CrestPlanner.Constants

function Planner:GetWeeklyPreview(allTrackResults)
    local balances = CrestPlanner.Currency:GetCurrentCrestBalances()
    local perTrackBudgetLines = {}
    local perTrackWeeks = {}

    local totalOptimalCost = 0
    local totalMainFirstCost = 0
    local totalSavings = 0
    local priorities = {}

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
            local currencyName = trackInfo.currencyName
            local currency = currencyName and balances[currencyName] or nil
            local currentAmount = currency and currency.amount or 0
            local weeklyCap = currency and currency.weeklyMax or 0

            local remaining = math.max(0, optimal - currentAmount)
            local weeksForTrack
            if remaining == 0 then
                weeksForTrack = 0
            elseif weeklyCap > 0 then
                weeksForTrack = math.ceil(remaining / weeklyCap)
            else
                weeksForTrack = math.huge
            end

            perTrackWeeks[#perTrackWeeks + 1] = weeksForTrack
            perTrackBudgetLines[#perTrackBudgetLines + 1] = string.format(
                "%s: %d/%d",
                trackName,
                currentAmount,
                optimal
            )

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
    for _, weeks in ipairs(perTrackWeeks) do
        if weeks == math.huge then
            estimatedWeeks = "N/A"
            break
        end
        if weeks > estimatedWeeks then
            estimatedWeeks = weeks
        end
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
        priorityLines = priorityLines,
        message = string.format("Per-track budget: %s", table.concat(perTrackBudgetLines, "  |  ")),
    }
end
