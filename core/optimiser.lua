local addonName, CrestPlanner = ...

local Optimiser = {}
CrestPlanner.Optimiser = Optimiser

local Constants = CrestPlanner.Constants
local MainCharacterKey
local function IsKnownTrack(trackName)
    return type(trackName) == "string" and Constants.TRACKS[trackName] ~= nil
end
local function TrackOrder(trackName)
    return IsKnownTrack(trackName) and Constants.TRACKS[trackName].order or nil
end

local function RoundNearest(value)
    return math.floor(value + 0.5)
end

local function CostFromRank(trackName, currentRank, maxRank, discountActive)
    local costs = Constants.UPGRADE_COSTS_PER_RANK[trackName] or {}
    local total = 0
    local startRank = math.max(1, currentRank or 1)
    local endRank = math.max(0, (maxRank or 0) - 1)

    for rank = startRank, endRank do
        local stepCost = costs[rank] or 0
        total = total + stepCost
    end

    if discountActive then
        total = RoundNearest(total * (1 - Constants.DISCOUNT_RATE))
    end

    return total
end

local function TargetTrackMaxRank(trackName)
    local costs = Constants.UPGRADE_COSTS_PER_RANK[trackName] or {}
    return #costs + 1
end

local function TransitionEquivalentRank(fromTrack, toTrack)
    local transitions = Constants.TRACK_TRANSITION_EQUIVALENT_RANK or {}
    local fromMap = transitions[fromTrack] or {}
    return fromMap[toTrack]
end

local function EvaluateItemForTargetTrack(item, targetTrackName, discountActive)
    if not item then
        return "unknown", 0, false
    end

    -- If the scanner couldn't parse the track, try to infer from item level.
    -- This handles crafted gear, PvP items, or items with non-standard tooltips.
    if not IsKnownTrack(item.trackName) then
        local inferred = CrestPlanner.Optimiser:InferTrackByItemLevel(item.itemLevel)
        if inferred and IsKnownTrack(inferred.trackName) then
            local inferredOrder = TrackOrder(inferred.trackName)
            local targetOrder = TrackOrder(targetTrackName)
            if inferredOrder and targetOrder and inferredOrder >= targetOrder then
                -- Item level suggests this item is at or above the target track,
                -- treat it as complete (we can't know its exact rank, so assume capped).
                return "complete", 0, false
            end
        end
        return "unknown", 0, false
    end

    local itemOrder = TrackOrder(item.trackName)
    local targetOrder = TrackOrder(targetTrackName)
    if not itemOrder or not targetOrder then
        return "unknown", 0, false
    end

    -- Item is already on a higher track than target, so it counts as complete.
    if itemOrder > targetOrder then
        return "complete", 0, false
    end

    if itemOrder == targetOrder then
        if (item.currentRank or 0) >= (item.maxRank or 0) then
            return "complete", 0, false
        end
        return "needs", CostFromRank(targetTrackName, item.currentRank or 0, item.maxRank or 0, discountActive), false
    end

    -- Item is below target track (e.g. Champion while evaluating Hero).
    -- If we have an adjacent-track equivalence, start from that rank (e.g. Hero 2/6).
    local targetMax = TargetTrackMaxRank(targetTrackName)
    local startRank = 1
    local itemIsTrackMaxed = (item.maxRank or 0) > 0 and (item.currentRank or 0) >= (item.maxRank or 0)

    if targetOrder - itemOrder == 1 then
        startRank = TransitionEquivalentRank(item.trackName, targetTrackName) or 1
    elseif itemIsTrackMaxed then
        -- Simplification for multi-gap transitions (e.g. Veteran 6/6 → Hero):
        -- We use a flat rank-2 baseline rather than chaining through each intermediate
        -- track (Vet 6/6 → Champ 2/6 → Champ 6/6 → Hero 2/6). This slightly undersells
        -- the real cost but avoids recursive chain calculation. Acceptable because
        -- multi-gap items are rare in practice (players upgrade sequentially).
        startRank = 2
    end
    return "needs", CostFromRank(targetTrackName, startRank, targetMax, discountActive), true
end

local function BagItemCanFitSlot(bagItem, slotName)
    for _, option in ipairs(bagItem.slotOptions or {}) do
        if option == slotName then
            return true
        end
    end
    return false
end

local function StatusPriority(status)
    if status == "complete" then
        return 3
    elseif status == "needs" then
        return 2
    end
    return 1
end

local function IsTwoHandMainHand(item)
    if not item then
        return false
    end

    local equipLoc = item.equipLoc
    if not equipLoc and item.itemLink and GetItemInfoInstant then
        local _, _, _, resolvedEquipLoc = GetItemInfoInstant(item.itemLink)
        equipLoc = resolvedEquipLoc
    end

    return equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"
end

local function BuildSlotPlans(character, targetTrackName, discountActive)
    local equippedBySlot = {}
    local plans = {}
    local usedBagIndices = {}

    for _, item in pairs(character.equipped or {}) do
        equippedBySlot[item.slotName] = item
    end

    local mainHandItem = equippedBySlot["MainHand"]
    local hasEquippedOffHand = equippedBySlot["OffHand"] ~= nil
    local useSingleWeaponSlot = IsTwoHandMainHand(mainHandItem)

    for _, slot in ipairs(Constants.SLOTS) do
        if not (slot.name == "OffHand" and (useSingleWeaponSlot or not hasEquippedOffHand)) then
            local best = nil

            local equippedItem = equippedBySlot[slot.name]
            if equippedItem then
                local status, cost, isBelow = EvaluateItemForTargetTrack(equippedItem, targetTrackName, discountActive)
                best = {
                    source = "equipped",
                    status = status,
                    cost = cost,
                    isBelowTrack = isBelow,
                    item = equippedItem,
                }
            end

            for bagIndex, bagItem in ipairs(character.bagItems or {}) do
                if not usedBagIndices[bagIndex] and BagItemCanFitSlot(bagItem, slot.name) then
                    local status, cost, isBelow = EvaluateItemForTargetTrack(bagItem, targetTrackName, discountActive)
                    local candidate = {
                        source = "bag",
                        bagIndex = bagIndex,
                        status = status,
                        cost = cost,
                        isBelowTrack = isBelow,
                        item = bagItem,
                    }

                    if not best then
                        best = candidate
                    else
                        local bestPriority = StatusPriority(best.status)
                        local candidatePriority = StatusPriority(candidate.status)
                        if candidatePriority > bestPriority then
                            best = candidate
                        elseif candidatePriority == bestPriority and candidate.status == "needs" and candidate.cost < best.cost then
                            best = candidate
                        end
                    end
                end
            end

            if best then
                if best.source == "bag" and best.bagIndex then
                    usedBagIndices[best.bagIndex] = true
                end
                best.slotName = slot.name
                plans[#plans + 1] = best
            end
        end
    end

    return plans
end

local function BuildTrackData(trackName)
    local characters = CrestPlanner.Scanner:GetWarbandCharacters()
    local mainKey = MainCharacterKey()
    local rows = {}

    -- If the warband discount is already active for this track, price all
    -- characters' upgrade costs at the discounted rate (it's warband-wide).
    local discountActive = CrestPlanner.Optimiser:IsDiscountAlreadyActive(trackName)

    for key, character in pairs(characters) do
        local slotsAtMax = 0
        local slotsNeeding = 0
        local crestNeeded = 0
        local totalSlots = 0
        local knownSlots = 0
        local unknownSlots = 0
        local belowTrackSlots = 0

        local plans = BuildSlotPlans(character, trackName, discountActive)
        for _, plan in ipairs(plans) do
            local item = plan.item
            totalSlots = totalSlots + 1
            if IsKnownTrack(item.trackName) then
                knownSlots = knownSlots + 1
            else
                unknownSlots = unknownSlots + 1
            end

            local status, itemCost, isBelowTrack = plan.status, plan.cost, plan.isBelowTrack
            if status == "complete" then
                slotsAtMax = slotsAtMax + 1
            elseif status == "needs" then
                slotsNeeding = slotsNeeding + 1
                crestNeeded = crestNeeded + itemCost
                if isBelowTrack then
                    belowTrackSlots = belowTrackSlots + 1
                end
            end
        end

        rows[#rows + 1] = {
            characterKey = key,
            name = character.name or key,
            realm = character.realm or "UnknownRealm",
            classFileName = character.classFileName or "UNKNOWN",
            level = character.level or 0,
            isMain = key == mainKey,
            slotsAtMax = slotsAtMax,
            slotsNeeding = slotsNeeding,
            crestNeeded = crestNeeded,
            knownSlots = knownSlots,
            totalSlots = totalSlots,
            unknownSlots = unknownSlots,
            belowTrackSlots = belowTrackSlots,
        }
    end

    table.sort(rows, function(a, b) return a.name < b.name end)
    return rows
end

local function CharacterThresholdUnlockCost(character, trackName)
    local plans = BuildSlotPlans(character, trackName, false)
    -- Threshold = all equipped slots (dynamic per character based on weapon type)
    local threshold = Constants.DISCOUNT_THRESHOLDS[trackName]
    if not threshold or threshold <= 0 then
        threshold = #plans
    end

    local completeCount = 0
    local candidateCosts = {}
    for _, plan in ipairs(plans) do
        if plan.status == "complete" then
            completeCount = completeCount + 1
        elseif plan.status == "needs" then
            candidateCosts[#candidateCosts + 1] = plan.cost or 0
        end
    end

    local needed = threshold - completeCount
    if needed <= 0 then
        return 0
    end
    if #candidateCosts < needed then
        return math.huge
    end

    table.sort(candidateCosts, function(a, b) return a < b end)
    local total = 0
    for i = 1, needed do
        total = total + candidateCosts[i]
    end
    return total
end

local function CheapestCharacterForThreshold(trackName)
    local bestName
    local bestCost = math.huge
    local currentCost = math.huge
    local mainKey = MainCharacterKey()
    for key, character in pairs(CrestPlanner.Scanner:GetWarbandCharacters() or {}) do
        local cost = CharacterThresholdUnlockCost(character, trackName)
        if key == mainKey then
            currentCost = cost
        end
        if cost < bestCost then
            bestCost = cost
            bestName = character.name or key
        end
    end
    return bestName, bestCost, currentCost
end

MainCharacterKey = function()
    return CrestPlanner.GetCurrentCharacterKey()
end

local function CalculateMainCost(trackName, discountActive)
    local main = CrestPlanner.Scanner:GetWarbandCharacters()[MainCharacterKey()]
    if not main then
        return 0, 0, 0, 0, {}
    end

    local totalCost = 0
    local remainingSlots = 0
    local unknownIgnored = 0
    local belowTrackSlots = 0
    local actions = {}

    local plans = BuildSlotPlans(main, trackName, discountActive)
    for _, plan in ipairs(plans) do
        local item = plan.item
        local status, itemCost, isBelowTrack = plan.status, plan.cost, plan.isBelowTrack
        if status == "needs" then
            totalCost = totalCost + itemCost
            remainingSlots = remainingSlots + 1
            actions[#actions + 1] = {
                slotName = plan.slotName or item.slotName or "UnknownSlot",
                cost = itemCost,
                trackName = item.trackName,
                currentRank = item.currentRank or 0,
                maxRank = item.maxRank or 0,
                isBelowTrack = isBelowTrack,
                source = plan.source,
            }
            if isBelowTrack then
                belowTrackSlots = belowTrackSlots + 1
            end
        elseif status == "unknown" then
            unknownIgnored = unknownIgnored + 1
        end
    end

    table.sort(actions, function(a, b) return a.cost > b.cost end)
    return totalCost, remainingSlots, unknownIgnored, belowTrackSlots, actions
end

local function ThresholdUnlockPlanForCharacter(character, characterName, trackName)
    local plans = BuildSlotPlans(character, trackName, false)
    local threshold = Constants.DISCOUNT_THRESHOLDS[trackName]
    if not threshold or threshold <= 0 then
        threshold = #plans
    end

    local candidates = {}
    local unknownIgnored = 0
    local belowTrackCandidates = 0
    local completeCount = 0
    for _, plan in ipairs(plans) do
        local item = plan.item
        local status, itemCost, isBelowTrack = plan.status, plan.cost, plan.isBelowTrack
        if status == "complete" then
            completeCount = completeCount + 1
        elseif status == "needs" then
            candidates[#candidates + 1] = {
                characterName = characterName or "Unknown",
                slotName = plan.slotName or item.slotName,
                cost = itemCost,
                source = plan.source,
            }
            if isBelowTrack then
                belowTrackCandidates = belowTrackCandidates + 1
            end
        elseif status == "unknown" then
            unknownIgnored = unknownIgnored + 1
        end
    end

    local needed = threshold - completeCount
    if needed <= 0 then
        return 0, {}, unknownIgnored, belowTrackCandidates
    end

    table.sort(candidates, function(a, b) return a.cost < b.cost end)

    local chosen = {}
    local spend = 0
    for i = 1, math.min(needed, #candidates) do
        spend = spend + candidates[i].cost
        chosen[#chosen + 1] = candidates[i]
    end

    if #chosen < needed then
        return math.huge, {}, unknownIgnored, belowTrackCandidates
    end

    return spend, chosen, unknownIgnored, belowTrackCandidates
end

local function CheapestAltUnlock(trackName)
    -- Threshold is resolved per-character inside ThresholdUnlockPlanForCharacter
    local mainKey = MainCharacterKey()
    local bestSpend = math.huge
    local bestChosen = {}
    local bestUnknownIgnored = 0
    local bestBelowTrackCandidates = 0

    for key, character in pairs(CrestPlanner.Scanner:GetWarbandCharacters()) do
        if key ~= mainKey then
            local characterName = character.name or key
            local spend, chosen, unknownIgnored, belowTrackCandidates = ThresholdUnlockPlanForCharacter(character, characterName, trackName)
            if spend < bestSpend then
                bestSpend = spend
                bestChosen = chosen
                bestUnknownIgnored = unknownIgnored
                bestBelowTrackCandidates = belowTrackCandidates
            end
        end
    end

    if bestSpend == math.huge then
        return math.huge, {}, bestUnknownIgnored, bestBelowTrackCandidates
    end

    return bestSpend, bestChosen, bestUnknownIgnored, bestBelowTrackCandidates
end

function Optimiser:IsDiscountAlreadyActive(trackName)
    local achievementID = Constants.DISCOUNT_ACHIEVEMENT_IDS[trackName]
    if not achievementID then
        return false
    end

    if not GetAchievementInfo then
        return false
    end

    local _, _, _, completed = GetAchievementInfo(achievementID)
    return completed == true
end

function Optimiser:EvaluateTrack(trackName)
    local discountAlreadyActive = self:IsDiscountAlreadyActive(trackName)
    local mainKey = MainCharacterKey()
    local main = CrestPlanner.Scanner:GetWarbandCharacters()[mainKey]
    local mainName = main and main.name or "Main"

    local mainCostNoDiscount, remainingMainSlotsNoDiscount, unknownMainIgnoredNoDiscount, mainBelowTrackSlotsNoDiscount, mainUpgradeActionsNoDiscount = CalculateMainCost(trackName, false)
    local mainCostDiscounted, remainingMainSlotsDiscounted, unknownMainIgnoredDiscounted, mainBelowTrackSlotsDiscounted, mainUpgradeActionsDiscounted = CalculateMainCost(trackName, true)

    -- Use discounted actions when the warband discount is active so costs shown
    -- to the user reflect the actual price they'll pay.
    local remainingMainSlots = discountAlreadyActive and remainingMainSlotsDiscounted or remainingMainSlotsNoDiscount
    local unknownMainIgnored = discountAlreadyActive and unknownMainIgnoredDiscounted or unknownMainIgnoredNoDiscount
    local mainBelowTrackSlots = discountAlreadyActive and mainBelowTrackSlotsDiscounted or mainBelowTrackSlotsNoDiscount
    local mainUpgradeActions = discountAlreadyActive and mainUpgradeActionsDiscounted or mainUpgradeActionsNoDiscount

    local altSpend, altActions, unknownAltIgnored, belowTrackCandidates = CheapestAltUnlock(trackName)

    -- Scenario A: upgrade main at current rate (discount if active, full price if not).
    local scenarioA = discountAlreadyActive and mainCostDiscounted or mainCostNoDiscount

    -- Scenario B: unlock discount via cheapest alt, then upgrade main at discount.
    local scenarioB
    if discountAlreadyActive then
        scenarioB = mainCostDiscounted
    elseif altSpend == math.huge then
        scenarioB = math.huge
    else
        scenarioB = altSpend + mainCostDiscounted
    end

    -- Scenario C: main self-unlocks discount by upgrading cheapest slots to threshold,
    -- then finishes the rest at discount rate. This handles the case where main is
    -- close to the threshold and self-unlocking is cheaper than diverting to an alt.
    local scenarioC = math.huge
    if not discountAlreadyActive and main then
        local mainUnlockCost = CharacterThresholdUnlockCost(main, trackName)
        if mainUnlockCost < math.huge then
            -- After self-unlocking, remaining slots get the discount.
            -- mainCostDiscounted already prices ALL slots at discount, but the unlock
            -- slots were paid at full price. Recalculate: unlock slots at full price,
            -- remaining slots at discount price.
            local plans = BuildSlotPlans(main, trackName, false)
            local threshold = Constants.DISCOUNT_THRESHOLDS[trackName]
            if not threshold or threshold <= 0 then
                threshold = #plans
            end
            local completeCount = 0
            local needsCosts = {}
            for _, plan in ipairs(plans) do
                if plan.status == "complete" then
                    completeCount = completeCount + 1
                elseif plan.status == "needs" then
                    needsCosts[#needsCosts + 1] = plan.cost or 0
                end
            end
            table.sort(needsCosts)
            local slotsToUnlock = math.max(0, threshold - completeCount)
            if slotsToUnlock <= #needsCosts then
                local unlockSpend = 0
                for i = 1, slotsToUnlock do
                    unlockSpend = unlockSpend + needsCosts[i]
                end
                -- Remaining slots after unlock get discount
                local remainingSpend = 0
                for i = slotsToUnlock + 1, #needsCosts do
                    remainingSpend = remainingSpend + RoundNearest(needsCosts[i] * (1 - Constants.DISCOUNT_RATE))
                end
                scenarioC = unlockSpend + remainingSpend
            end
        end
    end

    -- Pick the best scenario
    local bestScenario = scenarioA
    if scenarioB < bestScenario then bestScenario = scenarioB end
    if scenarioC < bestScenario then bestScenario = scenarioC end

    local savings = (scenarioA < math.huge and scenarioB < math.huge) and (scenarioA - scenarioB) or 0
    local altFirstIsBetter = scenarioB < scenarioA and scenarioB <= scenarioC
    if altFirstIsBetter then
        savings = scenarioA - scenarioB
    elseif scenarioC < scenarioA then
        -- Main self-unlock is best, treat like main-first but with partial discount
        savings = 0
        altFirstIsBetter = false
    end

    local warbandRows = BuildTrackData(trackName)
    local cheapestUnlockCharacter, cheapestUnlockCost, currentUnlockCost = CheapestCharacterForThreshold(trackName)
    local shouldSwitchCharacter = cheapestUnlockCharacter and mainName
        and cheapestUnlockCharacter ~= mainName
        and (cheapestUnlockCost or math.huge) < (currentUnlockCost or math.huge)

    return {
        trackName = trackName,
        discountAlreadyActive = discountAlreadyActive,
        scenarioA = scenarioA,
        scenarioB = scenarioB,
        scenarioC = scenarioC,
        savings = savings,
        altFirstIsBetter = altFirstIsBetter,
        mainName = mainName,
        remainingMainSlots = remainingMainSlots,
        altActions = altActions,
        mainUpgradeActions = mainUpgradeActions,
        unknownMainSlotsIgnored = unknownMainIgnored,
        unknownAltSlotsIgnored = unknownAltIgnored,
        mainBelowTrackSlots = mainBelowTrackSlots,
        altBelowTrackCandidates = belowTrackCandidates,
        warbandRows = warbandRows,
        altUnlockCost = altSpend,
        cheapestCompletionCharacter = cheapestUnlockCharacter,
        cheapestCompletionCost = (cheapestUnlockCost and cheapestUnlockCost < math.huge) and cheapestUnlockCost or nil,
        currentCompletionCost = (currentUnlockCost and currentUnlockCost < math.huge) and currentUnlockCost or nil,
        currentUnlockCost = currentUnlockCost,
        shouldSwitchCharacter = shouldSwitchCharacter,
    }
end

function Optimiser:EvaluateAllTracks()
    local result = {}

    for trackName in pairs(Constants.TRACKS) do
        result[trackName] = self:EvaluateTrack(trackName)
    end

    return result
end

function Optimiser:InferTrackByItemLevel(itemLevel)
    if not itemLevel or itemLevel <= 0 then
        return nil
    end

    -- Build averaged ilvl samples by track/rank to reduce noisy single-item matches.
    local samples = {}
    for _, character in pairs(CrestPlanner.Scanner:GetWarbandCharacters()) do
        for _, item in pairs(character.equipped or {}) do
            if IsKnownTrack(item.trackName) and (item.itemLevel or 0) > 0 and (item.maxRank or 0) > 0 then
                local key = string.format("%s:%d/%d", item.trackName, item.currentRank or 0, item.maxRank or 0)
                if not samples[key] then
                    samples[key] = {
                        trackName = item.trackName,
                        currentRank = item.currentRank or 0,
                        maxRank = item.maxRank or 0,
                        totalIlvl = 0,
                        count = 0,
                    }
                end
                samples[key].totalIlvl = samples[key].totalIlvl + (item.itemLevel or 0)
                samples[key].count = samples[key].count + 1
            end
        end
    end

    local bestMatch
    local bestDiff = math.huge
    for _, sample in pairs(samples) do
        local avgIlvl = sample.totalIlvl / math.max(1, sample.count)
        local diff = math.abs(avgIlvl - itemLevel)
        if diff < bestDiff then
            bestDiff = diff
            bestMatch = {
                trackName = sample.trackName,
                currentRank = sample.currentRank,
                maxRank = sample.maxRank,
                itemLevel = math.floor(avgIlvl + 0.5),
                ilvlDiff = diff,
                confidence = sample.count >= 2 and "medium" or "low",
            }
        end
    end

    return bestMatch
end
