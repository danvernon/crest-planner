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
SlashCmdList.CRESTPLANNER = function()
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
