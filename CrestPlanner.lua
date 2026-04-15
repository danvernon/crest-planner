local addonName, CrestPlanner = ...

CrestPlanner.events = CreateFrame("Frame")
local rescanQueued = false

local function Initialize()
    CrestPlanner.Tooltip:Enable()
end

local function Rescan()
    CrestPlanner.Scanner:ScanCurrentCharacter()
    if CrestPlanner.MainFrame and CrestPlanner.MainFrame.frame and CrestPlanner.MainFrame.frame:IsShown() then
        CrestPlanner.MainFrame:Render(CrestPlanner.MainFrame.selectedTabName or "Veteran")
    end
end

local function QueueRescan(delaySeconds)
    if rescanQueued then
        return
    end

    rescanQueued = true
    C_Timer.After(delaySeconds or 0, function()
        rescanQueued = false
        Rescan()
    end)
end

SLASH_CRESTPLANNER1 = "/cp"
SlashCmdList.CRESTPLANNER = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S+)%s*(.-)%s*$")

    if cmd == "chars" then
        local minLevel = CrestPlanner.Constants.MIN_CHARACTER_LEVEL or 0
        local mainKey = CrestPlanner.GetCurrentCharacterKey()
        print("|cff00d1c1CrestPlanner:|r Warband characters (min level: " .. minLevel .. ")")
        for key, char in pairs((CrestPlannerDB and CrestPlannerDB.characters) or {}) do
            local level = char.level or 0
            local marker = (key == mainKey) and " |cff5cff7a[MAIN]|r" or ""
            local lastScan = char.lastScan and date("%Y-%m-%d %H:%M", char.lastScan) or "never"
            local status = (key == mainKey or level >= minLevel) and "|cff5cff7avisible|r" or "|cffff5555hidden|r"
            print(string.format("  %s (lvl %d) %s | scanned %s | %s", key, level, marker, lastScan, status))
        end
        print("Use |cff00d1c1/cp remove <name-realm>|r to delete a character record.")
        return
    end

    if cmd == "remove" and arg and arg ~= "" then
        if CrestPlannerDB and CrestPlannerDB.characters and CrestPlannerDB.characters[arg] then
            CrestPlannerDB.characters[arg] = nil
            print("|cff00d1c1CrestPlanner:|r Removed " .. arg)
        else
            print("|cff00d1c1CrestPlanner:|r No character with key " .. arg)
        end
        return
    end

    if cmd == "debug" then
        local key = CrestPlanner.GetCurrentCharacterKey()
        local db = CrestPlannerDB and CrestPlannerDB.characters and CrestPlannerDB.characters[key]
        if not db or not db.equipped then
            print("|cff00d1c1CrestPlanner:|r No scan data for " .. key)
            return
        end
        print("|cff00d1c1CrestPlanner Debug:|r Equipped items for " .. key)
        for _, slot in ipairs(CrestPlanner.Constants.SLOTS) do
            local item = db.equipped[slot.id]
            if item then
                local status = "?"
                if item.trackName == "Unknown" then
                    status = "|cffff5555Unknown|r"
                elseif (item.currentRank or 0) >= (item.maxRank or 0) and (item.maxRank or 0) > 0 then
                    status = "|cff5cff7aMaxed|r"
                else
                    status = "|cffffc857" .. (item.currentRank or 0) .. "/" .. (item.maxRank or 0) .. "|r"
                end
                print(string.format("  %s: %s %s (ilvl %d)", slot.name, item.trackName or "?", status, item.itemLevel or 0))
            end
        end
        print("|cff00d1c1CrestPlanner Debug:|r Warband discount achievement status:")
        for _, trackName in ipairs({ "Adventurer", "Veteran", "Champion", "Hero", "Myth" }) do
            local id = CrestPlanner.Constants.DISCOUNT_ACHIEVEMENT_IDS[trackName]
            if id and GetAchievementInfo then
                local _, name, _, completed = GetAchievementInfo(id)
                local st = completed and "|cff5cff7aEARNED|r" or "|cffff5555not earned|r"
                print(string.format("  %s (id %d \"%s\"): %s", trackName, id, name or "?", st))
            end
        end
        return
    end

    CrestPlanner.MainFrame:Toggle()
end

CrestPlanner.events:RegisterEvent("PLAYER_LOGIN")
CrestPlanner.events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
CrestPlanner.events:RegisterEvent("PLAYER_ENTERING_WORLD")
CrestPlanner.events:RegisterEvent("BAG_UPDATE_DELAYED")

CrestPlanner.events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Initialize()
        -- Run immediate scan, then a delayed follow-up after APIs/tooltips settle.
        QueueRescan(0)
        C_Timer.After(2, function()
            QueueRescan(0)
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        QueueRescan(1)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE_DELAYED" then
        QueueRescan(0.25)
    end
end)
