local addonName, CrestPlanner = ...

local MainFrame = {}
CrestPlanner.MainFrame = MainFrame

local TAB_ORDER = { "Veteran", "Champion", "Hero", "Myth", "Summary" }
local COLORS = {
    accent = "ff00d1c1",
    section = "ff7be3dc",
    value = "ffffffff",
    muted = "ff9bb0ae",
    good = "ff5cff7a",
    warn = "ffffc857",
}

local function C(hex, text)
    return string.format("|c%s%s|r", hex, text)
end

local function Divider(char, len)
    return string.rep(char or "-", len or 56)
end

local function SectionHeader(text)
    return C(COLORS.section, text) .. "\n" .. C(COLORS.muted, Divider("-", 56))
end

local function EnsureTrackWidgets(frame)
    if frame.trackView then
        return
    end

    local function CreateCard(parent, x, y, w, h, title)
        local card = CreateFrame("Frame", nil, parent)
        card:SetPoint("TOPLEFT", x, y)
        card:SetSize(w, h)

        card.bg = card:CreateTexture(nil, "BACKGROUND")
        card.bg:SetAllPoints()
        card.bg:SetColorTexture(0.03, 0.05, 0.07, 0.78)

        card.accent = card:CreateTexture(nil, "ARTWORK")
        card.accent:SetPoint("TOPLEFT", 0, -1)
        card.accent:SetPoint("TOPRIGHT", 0, -1)
        card.accent:SetHeight(2)
        card.accent:SetColorTexture(0, 0.82, 0.76, 0.9)

        card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.title:SetPoint("TOPLEFT", 8, -8)
        card.title:SetJustifyH("LEFT")
        card.title:SetText(C(COLORS.section, title))

        card.text = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        card.text:SetPoint("TOPLEFT", 8, -26)
        card.text:SetPoint("BOTTOMRIGHT", -8, 8)
        card.text:SetJustifyH("LEFT")
        card.text:SetJustifyV("TOP")

        return card
    end

    frame.trackView = CreateFrame("Frame", nil, frame)
    frame.trackView:SetPoint("TOPLEFT", 14, -42)
    frame.trackView:SetPoint("BOTTOMRIGHT", -14, 42)

    frame.trackView.decisionCard = CreateCard(frame.trackView, 0, 0, 328, 118, "DECISION")
    frame.trackView.actionsCard = CreateCard(frame.trackView, 0, -126, 328, 178, "TOP ACTIONS")
    frame.trackView.progressCard = CreateCard(frame.trackView, 0, -312, 328, 128, "DISCOUNT PROGRESS")
    frame.trackView.warbandCard = CreateCard(frame.trackView, 336, 0, 390, 440, "WARBAND")
    local row = CreateFrame("Frame", nil, frame.trackView.progressCard)
    row:SetPoint("TOPLEFT", 8, -30)
    row:SetSize(310, 22)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetWidth(96)
    row.label:SetJustifyH("LEFT")

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("LEFT", 100, 0)
    row.bar:SetSize(160, 12)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)
    row.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    row.bar:GetStatusBarTexture():SetHorizTile(false)
    row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bar.bg:SetAllPoints()
    row.bar.bg:SetColorTexture(0.08, 0.1, 0.13, 0.9)

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetPoint("LEFT", row.bar, "RIGHT", 6, 0)
    row.value:SetJustifyH("LEFT")

    frame.trackView.progressRow = row

    frame.trackView.progressNote = frame.trackView.progressCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.trackView.progressNote:SetPoint("TOPLEFT", 8, -58)
    frame.trackView.progressNote:SetPoint("RIGHT", -8, 0)
    frame.trackView.progressNote:SetJustifyH("LEFT")
    frame.trackView.progressNote:SetJustifyV("TOP")
end

local function IsTrackTab(tabName)
    return tabName ~= "Summary"
end

local function GetTrackResult(self, trackName)
    self._renderCache = self._renderCache or {}
    if not self._renderCache[trackName] then
        self._renderCache[trackName] = CrestPlanner.Optimiser:EvaluateTrack(trackName)
    end
    return self._renderCache[trackName]
end

local function ApplyTabVisual(tab, isSelected)
    if not tab or not tab.bg then
        return
    end

    if isSelected then
        tab.bg:SetColorTexture(0.05, 0.18, 0.2, 0.95)
        tab.activeBar:Show()
        tab.text:SetTextColor(0.95, 1, 1)
    else
        tab.bg:SetColorTexture(0.05, 0.07, 0.1, 0.9)
        tab.activeBar:Hide()
        tab.text:SetTextColor(0.72, 0.82, 0.82)
    end
end

local function RefreshTabVisibility(self)
    if not self.frame or not self.frame.tabs then
        return
    end

    local visibleTabs = {}
    for index, tabName in ipairs(TAB_ORDER) do
        local shouldShow = true
        if IsTrackTab(tabName) then
            local result = GetTrackResult(self, tabName)
            shouldShow = (result.remainingMainSlots or 0) > 0
        end

        local tab = self.frame.tabs[index]
        if shouldShow then
            tab:Show()
            visibleTabs[#visibleTabs + 1] = { index = index, name = tabName, tab = tab }
        else
            tab:Hide()
        end
    end

    for visibleIndex, info in ipairs(visibleTabs) do
        info.tab:ClearAllPoints()
        info.tab:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", (visibleIndex - 1) * 78, 1)
    end

    local selectedIndex
    for _, info in ipairs(visibleTabs) do
        if info.name == self.selectedTabName then
            selectedIndex = info.index
            break
        end
    end

    if not selectedIndex then
        selectedIndex = visibleTabs[1] and visibleTabs[1].index or #TAB_ORDER
        self.selectedTabName = TAB_ORDER[selectedIndex]
    end

    for _, info in ipairs(visibleTabs) do
        ApplyTabVisual(info.tab, info.index == selectedIndex)
    end
end

local function BuildActionText(trackResult)
    local function LimitLines(lines, keepCount)
        if #lines <= keepCount then
            return lines
        end
        local limited = {}
        for i = 1, keepCount do
            limited[#limited + 1] = lines[i]
        end
        limited[#limited + 1] = string.format("... and %d more actions", #lines - keepCount)
        return limited
    end

    if trackResult.shouldSwitchCharacter and trackResult.cheapestCompletionCharacter and trackResult.currentCompletionCost then
        local lines = {}
        lines[#lines + 1] = string.format(
            "Decision: Switch to %s for this track.",
            trackResult.cheapestCompletionCharacter
        )
        lines[#lines + 1] = string.format(
            "Reason: %s cost %d vs current %d.",
            trackResult.cheapestCompletionCharacter,
            trackResult.cheapestCompletionCost or 0,
            trackResult.currentCompletionCost or 0
        )
        lines[#lines + 1] = "Use this character to push the next discount unlock fastest."
        return table.concat(lines, "\n")
    end

    if trackResult.discountAlreadyActive then
        local lines = {
            "Decision: Upgrade your current character now (discount already active).",
        }
        local shown = math.min(3, #(trackResult.mainUpgradeActions or {}))
        for index = 1, shown do
            local action = trackResult.mainUpgradeActions[index]
            lines[#lines + 1] = string.format(
                "%d) %s: %s%s (%d crest)",
                index,
                trackResult.mainName or "Current",
                action.slotName,
                action.source == "bag" and " [equip from bag]" or "",
                action.cost
            )
        end
        if (trackResult.remainingMainSlots or 0) > shown then
            lines[#lines + 1] = string.format("+ %d more slots pending", (trackResult.remainingMainSlots or 0) - shown)
        end
        return table.concat(LimitLines(lines, 6), "\n")
    end

    local lines = {}
    if not trackResult.altFirstIsBetter then
        lines[#lines + 1] = "Decision: Upgrade your current character first."
        lines[#lines + 1] = string.format(
            "Reason: Alt-first costs %d more crest.",
            math.max(0, (trackResult.scenarioB == math.huge and 0 or trackResult.scenarioB) - (trackResult.scenarioA == math.huge and 0 or trackResult.scenarioA))
        )
        local shown = math.min(3, #(trackResult.mainUpgradeActions or {}))
        for index = 1, shown do
            local action = trackResult.mainUpgradeActions[index]
            lines[#lines + 1] = string.format(
                "%d) %s: %s%s (%d crest)",
                index,
                trackResult.mainName or "Current",
                action.slotName,
                action.source == "bag" and " [equip from bag]" or "",
                action.cost
            )
        end
        if (trackResult.remainingMainSlots or 0) > shown then
            lines[#lines + 1] = string.format("+ %d more slots pending", (trackResult.remainingMainSlots or 0) - shown)
        end
        return table.concat(LimitLines(lines, 6), "\n")
    end

    lines[#lines + 1] = "Decision: Upgrade alts first to unlock discount."
    lines[#lines + 1] = string.format("Reason: Saves %d crest total.", trackResult.savings or 0)

    for index = 1, math.min(3, #(trackResult.altActions or {})) do
        local action = trackResult.altActions[index]
        lines[#lines + 1] = string.format(
            "%d) %s: %s%s (%d crest)",
            index,
            action.characterName,
            action.slotName,
            action.source == "bag" and " [equip from bag]" or "",
            action.cost
        )
    end

    local shownAltActions = math.min(3, #(trackResult.altActions or {}))
    lines[#lines + 1] = string.format("%d) %s: finish remaining slots with discount.", shownAltActions + 1, trackResult.mainName or "Current")
    return table.concat(LimitLines(lines, 6), "\n")
end

local function BuildWarbandVisualData(allTrackResults)
    local preferredTracks = { "Champion", "Hero", "Myth" }
    local visibleTracks = {}
    local characterMap = {}

    for _, trackName in ipairs(preferredTracks) do
        local result = allTrackResults[trackName]
        if result and (result.remainingMainSlots or 0) > 0 then
            visibleTracks[#visibleTracks + 1] = trackName
        end
    end
    if #visibleTracks == 0 then
        for _, trackName in ipairs(preferredTracks) do
            if allTrackResults[trackName] then
                visibleTracks[#visibleTracks + 1] = trackName
            end
        end
    end

    for _, trackName in ipairs(visibleTracks) do
        local result = allTrackResults[trackName]
        for _, row in ipairs((result and result.warbandRows) or {}) do
            local key = string.format("%s-%s", row.name or "Unknown", row.realm or "UnknownRealm")
            if not characterMap[key] then
                characterMap[key] = {
                    key = key,
                    name = row.name or "Unknown",
                    realm = row.realm or "UnknownRealm",
                    isMain = row.isMain == true,
                    perTrack = {},
                }
            end
            characterMap[key].isMain = characterMap[key].isMain or row.isMain == true
            characterMap[key].perTrack[trackName] = row
        end
    end

    local chars = {}
    for _, entry in pairs(characterMap) do
        chars[#chars + 1] = entry
    end
    table.sort(chars, function(a, b)
        if a.isMain ~= b.isMain then
            return a.isMain
        end
        return a.name < b.name
    end)

    return visibleTracks, chars
end

local function EnsureSummaryWidgets(frame)
    if frame.summaryView then
        return
    end

    frame.summaryView = CreateFrame("Frame", nil, frame)
    frame.summaryView:SetPoint("TOPLEFT", 16, -122)
    frame.summaryView:SetSize(720, 130)
    frame.summaryView:Hide()

    frame.summaryView.title = frame.summaryView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.summaryView.title:SetPoint("TOPLEFT", 0, 0)
    frame.summaryView.title:SetText(C(COLORS.section, "WARBAND VISUAL"))

    frame.summaryView.legend = frame.summaryView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summaryView.legend:SetPoint("TOPLEFT", 0, -18)
    frame.summaryView.legend:SetText(C(COLORS.muted, "Legend: flat bar = capped/known for each track; cost is full finish crest."))

    frame.summaryView.rows = {}
end

local function EnsureSummaryRow(parent, rowIndex)
    if parent.rows[rowIndex] then
        return parent.rows[rowIndex]
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(712, 22)
    row:SetPoint("TOPLEFT", 0, -36 - ((rowIndex - 1) * 24))

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", 0, 0)
    row.name:SetWidth(205)
    row.name:SetJustifyH("LEFT")

    row.cells = {}
    parent.rows[rowIndex] = row
    return row
end

local function EnsureSummaryCell(row, cellIndex)
    if row.cells[cellIndex] then
        return row.cells[cellIndex]
    end

    local cell = CreateFrame("Frame", nil, row)
    cell:SetSize(166, 20)
    cell:SetPoint("LEFT", 214 + ((cellIndex - 1) * 166), 0)

    cell.track = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.track:SetPoint("LEFT", 0, 0)
    cell.track:SetWidth(18)
    cell.track:SetJustifyH("LEFT")

    cell.bar = CreateFrame("StatusBar", nil, cell)
    cell.bar:SetPoint("LEFT", 20, 0)
    cell.bar:SetSize(84, 10)
    cell.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    cell.bar:SetStatusBarColor(0.0, 0.82, 0.76)
    cell.bar.bg = cell.bar:CreateTexture(nil, "BACKGROUND")
    cell.bar.bg:SetAllPoints()
    cell.bar.bg:SetColorTexture(0.08, 0.1, 0.13, 0.9)

    cell.value = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.value:SetPoint("LEFT", cell.bar, "RIGHT", 4, 0)
    cell.value:SetWidth(30)
    cell.value:SetJustifyH("LEFT")

    cell.cost = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.cost:SetPoint("LEFT", cell.value, "RIGHT", 4, 0)
    cell.cost:SetWidth(28)
    cell.cost:SetJustifyH("LEFT")

    row.cells[cellIndex] = cell
    return cell
end

local function RenderWarbandVisualBars(self, allTrackResults)
    EnsureSummaryWidgets(self.frame)
    local summaryView = self.frame.summaryView
    summaryView:Show()

    local visibleTracks, chars = BuildWarbandVisualData(allTrackResults)
    if #visibleTracks == 0 or #chars == 0 then
        summaryView.legend:SetText(C(COLORS.muted, "No warband track data available yet."))
        for _, row in ipairs(summaryView.rows) do
            row:Hide()
        end
        return
    end

    summaryView.legend:SetText(C(COLORS.muted, "Legend: flat bar = capped/known for each track; cost is full finish crest."))

    local shortTrack = { Champion = "Ch", Hero = "H", Myth = "M" }
    for rowIndex, char in ipairs(chars) do
        local row = EnsureSummaryRow(summaryView, rowIndex)
        local marker = char.isMain and C(COLORS.good, " [CURRENT]") or ""
        row.name:SetText(string.format("%s (%s)%s", char.name, char.realm, marker))
        row:Show()

        for cellIndex, trackName in ipairs(visibleTracks) do
            local cell = EnsureSummaryCell(row, cellIndex)
            local data = char.perTrack[trackName]
            local known = math.max(1, (data and data.knownSlots) or (data and data.totalSlots) or 1)
            local atMax = math.min(known, (data and data.slotsAtMax) or 0)
            local cost = (data and data.crestNeeded) or 0
            cell.track:SetText(C(COLORS.muted, shortTrack[trackName] or trackName:sub(1, 1)))
            cell.bar:SetMinMaxValues(0, known)
            cell.bar:SetValue(atMax)
            cell.value:SetText(C(COLORS.value, string.format("%d/%d", atMax, known)))
            cell.cost:SetText(C(COLORS.warn, tostring(cost)))
            cell:Show()
        end

        for cellIndex = #visibleTracks + 1, #row.cells do
            row.cells[cellIndex]:Hide()
        end
    end

    for rowIndex = #chars + 1, #summaryView.rows do
        summaryView.rows[rowIndex]:Hide()
    end
end

function MainFrame:Create()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "CrestPlannerMainFrame", UIParent)
    frame:SetSize(760, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(20)
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.03, 0.04, 0.06, 0.95)

    frame.topBar = frame:CreateTexture(nil, "ARTWORK")
    frame.topBar:SetPoint("TOPLEFT", 0, 0)
    frame.topBar:SetPoint("TOPRIGHT", 0, 0)
    frame.topBar:SetHeight(28)
    frame.topBar:SetColorTexture(0.06, 0.08, 0.11, 0.98)

    frame.topBarTopEdge = frame:CreateTexture(nil, "BORDER")
    frame.topBarTopEdge:SetPoint("TOPLEFT", 0, 0)
    frame.topBarTopEdge:SetPoint("TOPRIGHT", 0, 0)
    frame.topBarTopEdge:SetHeight(1)
    frame.topBarTopEdge:SetColorTexture(0, 0.82, 0.76, 0.55)

    frame.topBarBottomEdge = frame:CreateTexture(nil, "BORDER")
    frame.topBarBottomEdge:SetPoint("TOPLEFT", 0, -28)
    frame.topBarBottomEdge:SetPoint("TOPRIGHT", 0, -28)
    frame.topBarBottomEdge:SetHeight(1)
    frame.topBarBottomEdge:SetColorTexture(0, 0.82, 0.76, 0.55)

    frame.footerBar = frame:CreateTexture(nil, "ARTWORK")
    frame.footerBar:SetPoint("BOTTOMLEFT", 0, 0)
    frame.footerBar:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.footerBar:SetHeight(32)
    frame.footerBar:SetColorTexture(0.05, 0.07, 0.1, 0.98)

    frame.footerTopEdge = frame:CreateTexture(nil, "BORDER")
    frame.footerTopEdge:SetPoint("BOTTOMLEFT", 0, 32)
    frame.footerTopEdge:SetPoint("BOTTOMRIGHT", 0, 32)
    frame.footerTopEdge:SetHeight(1)
    frame.footerTopEdge:SetColorTexture(0, 0.82, 0.76, 0.55)

    local addonLogo = "Interface\\AddOns\\CrestPlanner\\Textures\\CrestPlannerLogo.tga"

    frame.titleIconFallback = frame:CreateTexture(nil, "ARTWORK")
    frame.titleIconFallback:SetPoint("TOPLEFT", 8, -3)
    frame.titleIconFallback:SetSize(22, 22)
    frame.titleIconFallback:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")

    frame.titleIcon = frame:CreateTexture(nil, "OVERLAY")
    frame.titleIcon:SetPoint("TOPLEFT", 8, -3)
    frame.titleIcon:SetSize(22, 22)
    frame.titleIcon:SetTexture(addonLogo)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.titleIcon, "RIGHT", 6, 0)
    frame.title:SetText("Crest Planner")

    frame.close = CreateFrame("Button", nil, frame)
    frame.close:SetPoint("TOPRIGHT", -6, -5)
    frame.close:SetSize(18, 18)
    frame.close.bg = frame.close:CreateTexture(nil, "BACKGROUND")
    frame.close.bg:SetAllPoints()
    frame.close.bg:SetColorTexture(0.0, 0.0, 0.0, 0)
    frame.close.label = frame.close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.close.label:SetPoint("CENTER", 0, 0)
    frame.close.label:SetText("X")
    frame.close.label:SetTextColor(1, 1, 1)
    frame.close:SetScript("OnClick", function()
        frame:Hide()
    end)
    frame.close:SetScript("OnEnter", function()
        frame.close.bg:SetColorTexture(0.16, 0.28, 0.32, 0.8)
        frame.close.label:SetTextColor(0.85, 1, 0.97)
    end)
    frame.close:SetScript("OnLeave", function()
        frame.close.bg:SetColorTexture(0.0, 0.0, 0.0, 0)
        frame.close.label:SetTextColor(1, 1, 1)
    end)

    frame.body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.body:SetPoint("TOPLEFT", 16, -44)
    frame.body:SetWidth(720)
    frame.body:SetJustifyH("LEFT")
    frame.body:SetJustifyV("TOP")

    frame.accent = frame:CreateTexture(nil, "ARTWORK")
    frame.accent:SetColorTexture(0, 0.82, 0.76, 0.9)
    frame.accent:SetPoint("TOPLEFT", 12, -37)
    frame.accent:SetPoint("TOPRIGHT", -12, -37)
    frame.accent:SetHeight(2)
    frame.accent:Hide()

    frame.tabs = {}
    for index, tabName in ipairs(TAB_ORDER) do
        local tab = CreateFrame("Button", "$parentTab" .. index, frame)
        tab:SetSize(78, 30)

        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetColorTexture(0.05, 0.07, 0.1, 0.9)

        tab.edge = tab:CreateTexture(nil, "BORDER")
        tab.edge:SetAllPoints()
        tab.edge:SetColorTexture(0, 0.82, 0.76, 0.25)

        tab.activeBar = tab:CreateTexture(nil, "ARTWORK")
        tab.activeBar:SetPoint("BOTTOMLEFT", 0, 0)
        tab.activeBar:SetPoint("BOTTOMRIGHT", 0, 0)
        tab.activeBar:SetHeight(2)
        tab.activeBar:SetColorTexture(0.2, 1, 0.92, 0.9)
        tab.activeBar:Hide()

        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab.text:SetPoint("CENTER", 0, 0)
        tab.text:SetText(tabName)
        tab.text:SetTextColor(0.72, 0.82, 0.82)

        tab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (index - 1) * 78, 1)
        tab:SetScript("OnClick", function()
            MainFrame.selectedTabName = tabName
            MainFrame:Render(tabName)
        end)
        frame.tabs[index] = tab
    end

    self.selectedTabName = TAB_ORDER[1]

    if UISpecialFrames then
        local alreadyRegistered = false
        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == "CrestPlannerMainFrame" then
                alreadyRegistered = true
                break
            end
        end
        if not alreadyRegistered then
            table.insert(UISpecialFrames, "CrestPlannerMainFrame")
        end
    end

    self.frame = frame
    RefreshTabVisibility(self)
end

local function RenderTrackView(self, trackName)
    local result = GetTrackResult(self, trackName)
    EnsureTrackWidgets(self.frame)

    self.frame.body:Hide()
    if self.frame.summaryView then
        self.frame.summaryView:Hide()
    end
    self.frame.trackView:Show()

    local rows = {}
    for _, row in ipairs(result.warbandRows) do
        local marker = row.isMain and (" " .. C(COLORS.good, "[CURRENT]")) or ""
        rows[#rows + 1] = string.format(
            "• %s (%s)%s  |  %s %s  |  %s %s",
            C(COLORS.value, row.name),
            C(COLORS.muted, row.realm),
            marker,
            C(COLORS.muted, "Need:"),
            C(COLORS.value, row.slotsNeeding),
            C(COLORS.muted, "Full Cost:"),
            C(COLORS.value, row.crestNeeded)
        )
    end

    local recommendationLine = result.altFirstIsBetter
            and C(COLORS.good, string.format("[BEST] Alt-first saves %d.", result.savings))
            or C(COLORS.warn, "[OK] Current-character-first is optimal.")
    if result.shouldSwitchCharacter and result.cheapestCompletionCharacter then
        recommendationLine = C(
            COLORS.warn,
            string.format("[SWITCH] Progress on %s first.", result.cheapestCompletionCharacter)
        )
    end

    local reasonLine = C(COLORS.muted, "No additional context.")
    if result.shouldSwitchCharacter and result.cheapestCompletionCharacter and result.currentCompletionCost then
        reasonLine = C(
            COLORS.value,
            string.format("%s %d vs current %d cost.", result.cheapestCompletionCharacter, result.cheapestCompletionCost or 0, result.currentCompletionCost or 0)
        )
    elseif result.altFirstIsBetter then
        reasonLine = C(COLORS.value, string.format("Alt-first saves %d crest total.", result.savings or 0))
    end

    self.frame.trackView.decisionCard.text:SetText(table.concat({
        string.format("%s %s", C(COLORS.muted, "Track:"), C(COLORS.accent, trackName)),
        recommendationLine,
        string.format("%s %s", C(COLORS.muted, "Reason:"), reasonLine),
    }, "\n"))
    self.frame.trackView.actionsCard.text:SetText(BuildActionText(result))
    self.frame.trackView.warbandCard.text:SetText(table.concat(rows, "\n"))

    local achievementId = (CrestPlanner.Constants.DISCOUNT_ACHIEVEMENT_IDS or {})[trackName]
    local currentSlotsAtMax = 0
    local currentSlotsNeeding = 0
    local currentFullCost = 0
    local currentTotalSlots = 0
    local currentKnownSlots = 0
    for _, row in ipairs(result.warbandRows or {}) do
        local slotsAtMax = row.slotsAtMax or 0
        if row.isMain then
            currentSlotsAtMax = slotsAtMax
            currentSlotsNeeding = row.slotsNeeding or 0
            currentFullCost = row.crestNeeded or 0
            currentTotalSlots = row.totalSlots or 0
            currentKnownSlots = row.knownSlots or 0
            break
        end
    end

    local slotTarget = math.max(1, currentKnownSlots > 0 and currentKnownSlots or currentTotalSlots)
    local shownValue = math.min(currentSlotsAtMax, slotTarget)
    local row = self.frame.trackView.progressRow
    row.label:SetText(C(COLORS.muted, trackName))
    row.bar:SetMinMaxValues(0, slotTarget)
    row.bar:SetValue(shownValue)
    row.value:SetText(C(COLORS.value, string.format("%d/%d", shownValue, slotTarget)))
    local explanation = string.format("Current character %s slot completion.", trackName)
    local cappedLine = string.format(
        "Capped slots now: %d/%d known slots.",
        currentSlotsAtMax,
        slotTarget
    )
    if result.discountAlreadyActive then
        row.bar:SetStatusBarColor(0.36, 1, 0.48)
        self.frame.trackView.progressNote:SetText(table.concat({
            C(COLORS.good, "Warband discount active (achievement)."),
            C(COLORS.muted, explanation),
            C(COLORS.muted, cappedLine),
            C(COLORS.value, string.format("Full completion left: %d slots (%d cost).", currentSlotsNeeding, currentFullCost)),
        }, "\n"))
    else
        row.bar:SetStatusBarColor(0.0, 0.82, 0.76)
        local lines = {
            C(COLORS.muted, explanation),
            C(COLORS.muted, cappedLine),
            C(COLORS.value, string.format("Full completion left: %d slots (%d cost).", currentSlotsNeeding, currentFullCost)),
        }
        if not achievementId then
            table.insert(lines, 1, C(COLORS.muted, "Achievement ID not set in constants; addon cannot check discount from API."))
        end
        self.frame.trackView.progressNote:SetText(table.concat(lines, "\n"))
    end
end

local function RenderSummaryView(self)
    local allTrackResults = CrestPlanner.Optimiser:EvaluateAllTracks()
    local weekly = CrestPlanner.Planner:GetWeeklyPreview(allTrackResults)

    if self.frame.trackView then
        self.frame.trackView:Hide()
    end
    RenderWarbandVisualBars(self, allTrackResults)
    self.frame.body:Show()

    self.frame.body:SetText(table.concat({
        SectionHeader("SUMMARY ACROSS ALL TRACKS"),
        string.format("%s %s", C(COLORS.muted, "Current-first total:"), C(COLORS.value, weekly.totalMainFirstCost)),
        string.format("%s %s", C(COLORS.muted, "Optimal ordering total:"), C(COLORS.value, weekly.totalOptimalCost)),
        string.format("%s %s", C(COLORS.muted, "Total saved by optimiser:"), C(COLORS.good, weekly.totalSavings)),
        "",
        "",
        "",
        "",
        "",
        "",
        SectionHeader("WEEKLY PLANNER"),
        weekly.message,
        string.format("%s %s", C(COLORS.muted, "Overall timeline:"), C(COLORS.value, weekly.overallWeeksLine or weekly.estimatedWeeks)),
        "",
        SectionHeader("THIS WEEK PRIORITY"),
        table.concat(weekly.priorityLines, "\n"),
    }, "\n"))
end

function MainFrame:Render(tabName)
    self._renderCache = {}
    RefreshTabVisibility(self)
    if tabName ~= self.selectedTabName then
        tabName = self.selectedTabName
    end

    if tabName == "Summary" then
        RenderSummaryView(self)
        return
    end

    RenderTrackView(self, tabName)
end

function MainFrame:Toggle()
    self:Create()

    if self.frame:IsShown() then
        self.frame:Hide()
        return
    end

    self.frame:Show()
    self:Render(self.selectedTabName or TAB_ORDER[1])
end
