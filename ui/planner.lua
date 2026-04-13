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
            local earnedThisWeek = currency and currency.weeklyEarned or 0
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

            perTrackWeeks[#perTrackWeeks + 1] = weeksForTrack

            local linePlain = string.format(
                "%s: %d held | %d to goal | week %d/%d",
                trackName,
                currentAmount,
                optimal,
                earnedThisWeek,
                weeklyCap
            )
            local color = LineColorHex(trackOrder, focusDiscountOrder, discountActive, optimal)
            perTrackBudgetLines[#perTrackBudgetLines + 1] = string.format("|c%s%s|r", color, linePlain)

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
        message = table.concat({
            "|cff9bb0aeWeek X/Y = earned this week / weekly cap (from API, else "
                .. tostring(Constants.DEFAULT_WEEKLY_CREST_CAP)
                .. "). Gold = below your next discount tier or discount not verified. Gray = no crests needed on that track.|r",
            "",
            table.concat(perTrackBudgetLines, "\n"),
        }, "\n"),
    }
end
