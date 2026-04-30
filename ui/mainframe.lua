local addonName, CrestPlanner = ...

local MainFrame = {}
CrestPlanner.MainFrame = MainFrame

local TAB_ORDER = { "Veteran", "Champion", "Hero", "Myth", "Summary", "Bonus" }
local Constants = CrestPlanner.Constants

local COLORS = {
    accent    = "ff00d1c1",
    section   = "ff7be3dc",
    value     = "ffffffff",
    muted     = "ff9bb0ae",
    good      = "ff5cff7a",
    warn      = "ffffc857",
    greenBg   = { 0.13, 0.22, 0.13, 0.95 },
    amberBg   = { 0.22, 0.18, 0.08, 0.95 },
    greenAccent = { 0.36, 1.0, 0.48, 0.9 },
    amberAccent = { 1.0, 0.78, 0.34, 0.9 },
    cardBg    = { 0.06, 0.08, 0.11, 0.90 },
}

local function C(hex, text)
    return string.format("|c%s%s|r", hex, text)
end

local function FormatNumber(n)
    if n >= 10000 then
        local s = tostring(n)
        return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end
    return tostring(n)
end

local function DiscountPctLabel()
    local pct = math.floor((Constants.DISCOUNT_RATE or 0.50) * 100 + 0.5)
    return string.format("%d%%", pct)
end


---------------------------------------------------------------------------
-- Shared card background helper
---------------------------------------------------------------------------
local function ApplyCardBg(frame, bgColor)
    if not frame._cardBg then
        frame._cardBg = frame:CreateTexture(nil, "BACKGROUND")
        frame._cardBg:SetAllPoints()
    end
    local c = bgColor or COLORS.cardBg
    frame._cardBg:SetColorTexture(c[1], c[2], c[3], c[4])
end

---------------------------------------------------------------------------
-- Track view widgets
---------------------------------------------------------------------------
local function CreateActionRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(26)
    row:SetPoint("TOPLEFT", 12, -62 - ((index - 1) * 28))
    row:SetPoint("RIGHT", -12, 0)

    row.number = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.number:SetPoint("LEFT", 0, 0)
    row.number:SetWidth(20)
    row.number:SetJustifyH("CENTER")

    row.numberBg = row:CreateTexture(nil, "ARTWORK")
    row.numberBg:SetPoint("CENTER", row.number, "CENTER", 0, 0)
    row.numberBg:SetSize(22, 22)
    row.numberBg:SetColorTexture(0.1, 0.1, 0.1, 0.6)
    row.numberBg:SetDrawLayer("ARTWORK", -1)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", row.number, "RIGHT", 8, 0)
    row.text:SetPoint("RIGHT", -120, 0)
    row.text:SetJustifyH("LEFT")

    row.cost = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.cost:SetPoint("RIGHT", 0, 0)
    row.cost:SetWidth(120)
    row.cost:SetJustifyH("RIGHT")

    return row
end

local function CreateWarbandCharRow(parent, index)
    local ROW_HEIGHT = 36
    local ROW_STRIDE = 44
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 8, -28 - ((index - 1) * ROW_STRIDE))
    row:SetPoint("RIGHT", -8, 0)

    -- Faint divider above each row (hidden for first row)
    row.divider = row:CreateTexture(nil, "ARTWORK")
    row.divider:SetPoint("TOPLEFT", 0, 4)
    row.divider:SetPoint("RIGHT", 0, 0)
    row.divider:SetHeight(1)
    row.divider:SetColorTexture(0.2, 0.25, 0.28, 0.5)
    if index == 1 then
        row.divider:Hide()
    end

    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetPoint("TOPLEFT", 0, -2)
    row.classIcon:SetSize(32, 32)
    row.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    row.classIcon:SetTexCoord(0, 0.25, 0, 0.25) -- default, updated at render

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", row.classIcon, "TOPRIGHT", 8, -2)
    row.name:SetJustifyH("LEFT")

    row.youBadge = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.youBadge:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.youBadge:SetTextColor(0.36, 1, 0.48)

    row.realm = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.realm:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.realm:SetPoint("TOP", row.classIcon, "TOP", 0, -2)
    row.realm:SetJustifyH("RIGHT")

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("TOPLEFT", row.classIcon, "TOPRIGHT", 8, -18)
    row.bar:SetSize(120, 8)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)
    row.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    row.bar:GetStatusBarTexture():SetHorizTile(false)
    row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bar.bg:SetAllPoints()
    row.bar.bg:SetColorTexture(0.08, 0.1, 0.13, 0.9)

    row.ratio = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.ratio:SetPoint("LEFT", row.bar, "RIGHT", 6, 0)
    row.ratio:SetJustifyH("LEFT")

    row.costText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.costText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.costText:SetPoint("BOTTOM", row.classIcon, "BOTTOM", 0, 0)
    row.costText:SetJustifyH("RIGHT")

    row.completedText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.completedText:SetPoint("TOPLEFT", row.classIcon, "TOPRIGHT", 8, -18)
    row.completedText:SetTextColor(0.36, 1, 0.48)
    row.completedText:SetText("Complete")
    row.completedText:Hide()

    return row
end

local function CreateDiscountRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", 10, -28 - ((index - 1) * 30))
    row:SetPoint("RIGHT", -10, 0)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetWidth(70)
    row.label:SetJustifyH("LEFT")

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("LEFT", 74, 0)
    row.bar:SetSize(100, 10)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)
    row.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    row.bar:GetStatusBarTexture():SetHorizTile(false)
    row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bar.bg:SetAllPoints()
    row.bar.bg:SetColorTexture(0.08, 0.1, 0.13, 0.9)

    row.info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.info:SetPoint("LEFT", row.bar, "RIGHT", 8, 0)
    row.info:SetPoint("RIGHT", 0, 0)
    row.info:SetJustifyH("LEFT")

    return row
end

local function EnsureTrackWidgets(frame)
    if frame.trackView then
        return
    end

    frame.trackView = CreateFrame("Frame", nil, frame)
    frame.trackView:SetPoint("TOPLEFT", 8, -37)
    frame.trackView:SetPoint("BOTTOMRIGHT", -8, 37)

    -- Action card
    local ac = CreateFrame("Frame", nil, frame.trackView)
    ac:SetPoint("TOPLEFT", 0, 0)
    ac:SetPoint("RIGHT", 0, 0)
    ac:SetHeight(180)
    ApplyCardBg(ac, COLORS.greenBg)

    ac.leftAccent = ac:CreateTexture(nil, "ARTWORK")
    ac.leftAccent:SetPoint("TOPLEFT", 0, 0)
    ac.leftAccent:SetPoint("BOTTOMLEFT", 0, 0)
    ac.leftAccent:SetWidth(4)
    ac.leftAccent:SetColorTexture(0.36, 1.0, 0.48, 0.9)

    ac.subtitle = ac:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ac.subtitle:SetPoint("TOPLEFT", 14, -12)
    ac.subtitle:SetJustifyH("LEFT")

    ac.heading = ac:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ac.heading:SetPoint("TOPLEFT", 14, -30)
    ac.heading:SetPoint("RIGHT", -14, 0)
    ac.heading:SetJustifyH("LEFT")
    ac.heading:SetTextColor(1, 1, 1)

    ac.rows = {}
    for i = 1, 4 do
        ac.rows[i] = CreateActionRow(ac, i)
    end

    frame.trackView.actionCard = ac

    -- Warband card (bottom-left)
    local wc = CreateFrame("Frame", nil, frame.trackView)
    wc:SetPoint("TOPLEFT", 0, -190)
    wc:SetPoint("BOTTOMLEFT", 0, 0)
    wc:SetWidth(358)
    ApplyCardBg(wc)

    wc.title = wc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wc.title:SetPoint("TOPLEFT", 10, -8)
    wc.title:SetJustifyH("LEFT")
    wc.title:SetTextColor(0.48, 0.89, 0.86)

    wc.charRows = {}
    for i = 1, 6 do
        wc.charRows[i] = CreateWarbandCharRow(wc, i)
    end

    frame.trackView.warbandCard = wc

    -- Discount card (bottom-right)
    local dc = CreateFrame("Frame", nil, frame.trackView)
    dc:SetPoint("TOPLEFT", 366, -190)
    dc:SetPoint("BOTTOMRIGHT", 0, 0)
    ApplyCardBg(dc)

    dc.title = dc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dc.title:SetPoint("TOPLEFT", 10, -8)
    dc.title:SetJustifyH("LEFT")
    dc.title:SetText(C(COLORS.section, "DISCOUNT PROGRESS"))

    dc.discountRows = {}
    for i = 1, 4 do
        dc.discountRows[i] = CreateDiscountRow(dc, i)
    end

    dc.activeText = dc:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dc.activeText:SetPoint("TOPLEFT", 10, -28)
    dc.activeText:SetTextColor(0.36, 1, 0.48)
    dc.activeText:SetText("Warband discount active")
    dc.activeText:Hide()

    dc.tip = dc:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dc.tip:SetPoint("BOTTOMLEFT", 10, 10)
    dc.tip:SetPoint("RIGHT", -10, 0)
    dc.tip:SetJustifyH("LEFT")
    dc.tip:SetJustifyV("BOTTOM")

    frame.trackView.discountCard = dc
end

---------------------------------------------------------------------------
-- Summary view widgets
---------------------------------------------------------------------------
local function CreateStatCard(parent, xOffset, label)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(228, 72)
    card:SetPoint("TOPLEFT", xOffset, 0)
    ApplyCardBg(card)

    card.label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.label:SetPoint("TOPLEFT", 12, -10)
    card.label:SetText(C(COLORS.muted, label))
    card.label:SetJustifyH("LEFT")

    card.value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    card.value:SetPoint("TOPLEFT", 12, -30)
    card.value:SetJustifyH("LEFT")
    card.value:SetTextColor(1, 1, 1)

    return card
end

local function CreateOutlookRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(46)
    row:SetPoint("TOPLEFT", 10, -28 - ((index - 1) * 50))
    row:SetPoint("RIGHT", -10, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", 0, 0)
    row.icon:SetSize(28, 28)

    row.mainText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.mainText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1)
    row.mainText:SetPoint("RIGHT", -80, 0)
    row.mainText:SetJustifyH("LEFT")

    row.subtitle = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.subtitle:SetPoint("TOPLEFT", row.mainText, "BOTTOMLEFT", 0, -2)
    row.subtitle:SetPoint("RIGHT", -80, 0)
    row.subtitle:SetJustifyH("LEFT")

    row.weeks = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.weeks:SetPoint("RIGHT", 0, 0)
    row.weeks:SetWidth(80)
    row.weeks:SetJustifyH("RIGHT")

    return row
end

local function CreatePriorityRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(32)
    row:SetPoint("TOPLEFT", 10, -28 - ((index - 1) * 36))
    row:SetPoint("RIGHT", -10, 0)

    row.number = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.number:SetPoint("LEFT", 0, 0)
    row.number:SetWidth(20)
    row.number:SetJustifyH("CENTER")

    row.numberBg = row:CreateTexture(nil, "ARTWORK")
    row.numberBg:SetPoint("CENTER", row.number, "CENTER", 0, 0)
    row.numberBg:SetSize(22, 22)
    row.numberBg:SetColorTexture(0.1, 0.1, 0.1, 0.6)
    row.numberBg:SetDrawLayer("ARTWORK", -1)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", row.number, "RIGHT", 8, 0)
    row.text:SetPoint("RIGHT", -110, 0)
    row.text:SetJustifyH("LEFT")

    row.cost = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.cost:SetPoint("RIGHT", 0, 0)
    row.cost:SetWidth(110)
    row.cost:SetJustifyH("RIGHT")

    return row
end

local function EnsureSummaryWidgets(frame)
    if frame.summaryView then
        return
    end

    frame.summaryView = CreateFrame("Frame", nil, frame)
    frame.summaryView:SetPoint("TOPLEFT", 8, -37)
    frame.summaryView:SetPoint("BOTTOMRIGHT", -8, 37)
    frame.summaryView:Hide()

    -- Scroll frame for vertical overflow
    local scroll = CreateFrame("ScrollFrame", nil, frame.summaryView, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -22, 0)

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetWidth(700)  -- fixed; frame is 760 - 8 - 8 margins - 22 scrollbar = ~722
    scrollChild:SetHeight(1)
    scroll:SetScrollChild(scrollChild)
    scroll:EnableMouseWheel(true)
    frame.summaryView.scroll = scroll
    frame.summaryView.scrollChild = scrollChild

    -- All cards parent to scrollChild
    local sc = scrollChild
    local statCardW = 240
    local statGap = 8
    frame.summaryView.statCards = {}
    frame.summaryView.statCards[1] = CreateStatCard(sc, 0, "Total crests needed")
    frame.summaryView.statCards[2] = CreateStatCard(sc, statCardW + statGap, "Saved by optimal order")
    frame.summaryView.statCards[3] = CreateStatCard(sc, (statCardW + statGap) * 2, "Weeks at cap")
    for i = 1, 3 do
        frame.summaryView.statCards[i]:SetWidth(statCardW)
    end

    -- Weekly outlook card
    local oc = CreateFrame("Frame", nil, sc)
    oc:SetPoint("TOPLEFT", 0, -80)
    oc:SetPoint("RIGHT", 0, 0)
    oc:SetHeight(180)
    ApplyCardBg(oc)

    oc.title = oc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    oc.title:SetPoint("TOPLEFT", 10, -8)
    oc.title:SetText(C(COLORS.section, "WEEKLY OUTLOOK"))

    oc.rows = {}
    for i = 1, 4 do
        oc.rows[i] = CreateOutlookRow(oc, i)
    end

    frame.summaryView.outlookCard = oc

    -- Priority order card
    local pc = CreateFrame("Frame", nil, sc)
    pc:SetPoint("TOPLEFT", 0, -268)
    pc:SetPoint("RIGHT", 0, 0)
    pc:SetHeight(180)
    ApplyCardBg(pc)

    pc.title = pc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pc.title:SetPoint("TOPLEFT", 10, -8)
    pc.title:SetText(C(COLORS.section, "PRIORITY ORDER THIS WEEK"))

    pc.rows = {}
    for i = 1, 4 do
        pc.rows[i] = CreatePriorityRow(pc, i)
    end

    frame.summaryView.priorityCard = pc
end

---------------------------------------------------------------------------
-- Bonus view widgets
---------------------------------------------------------------------------
local function EnsureBonusWidgets(frame)
    if frame.bonusView then
        return
    end

    frame.bonusView = CreateFrame("Frame", nil, frame)
    frame.bonusView:SetPoint("TOPLEFT", 8, -37)
    frame.bonusView:SetPoint("BOTTOMRIGHT", -8, 37)
    frame.bonusView:Hide()

    local bc = frame.bonusView

    bc.title = bc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bc.title:SetPoint("TOPLEFT", 10, -8)
    bc.title:SetText(C(COLORS.section, "BONUS CRESTS"))

    bc.subtitle = bc:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bc.subtitle:SetPoint("TOPLEFT", 10, -24)
    bc.subtitle:SetText(C(COLORS.muted, "Uncapped crests from one-time quests and boss kills"))

    -- Character name headers (up to 6)
    bc.charHeaders = {}
    for i = 1, 6 do
        local header = bc:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        header:SetWidth(56)
        header:SetJustifyH("LEFT")
        header:SetWordWrap(false)
        header:Hide()
        bc.charHeaders[i] = header
    end

    -- Source rows (up to 8)
    bc.sourceRows = {}
    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, bc)
        row:SetHeight(30)
        row:SetPoint("TOPLEFT", 10, -56 - ((i - 1) * 34))
        row:SetPoint("RIGHT", -10, 0)
        row:EnableMouse(true)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.06, 0.08, 0.11, (i % 2 == 0) and 0.5 or 0)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", 0, 0)
        row.label:SetWidth(130)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)

        row.reward = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.reward:SetPoint("RIGHT", 0, 0)
        row.reward:SetWidth(100)
        row.reward:SetJustifyH("RIGHT")

        -- Per-character status marks (up to 6)
        row.marks = {}
        for j = 1, 6 do
            local mark = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            mark:SetWidth(56)
            mark:SetJustifyH("LEFT")
            mark:Hide()
            row.marks[j] = mark
        end

        -- Tooltip on hover shows the full hint text
        row:SetScript("OnEnter", function(self)
            if self._hint and self._hint ~= "" then
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                GameTooltip:SetText(self._labelText or "", 1, 1, 1)
                GameTooltip:AddLine(self._hint, 0.7, 0.82, 0.8, true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row:Hide()
        bc.sourceRows[i] = row
    end

    bc.footer = bc:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bc.footer:SetPoint("BOTTOMLEFT", 10, 10)
    bc.footer:SetPoint("RIGHT", -10, 0)
    bc.footer:SetJustifyH("LEFT")
end

---------------------------------------------------------------------------
-- Tab helpers
---------------------------------------------------------------------------
local function IsTrackTab(tabName)
    return tabName ~= "Summary" and tabName ~= "Bonus"
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

local function TrackHasWork(self, trackName)
    if trackName == "Summary" or trackName == "Bonus" then
        return true
    end
    local result = GetTrackResult(self, trackName)
    if not result then
        return false
    end
    local optimal = result.scenarioA or 0
    if result.scenarioB and result.scenarioB < optimal then
        optimal = result.scenarioB
    end
    if result.scenarioC and result.scenarioC < optimal then
        optimal = result.scenarioC
    end
    return optimal > 0
end

local function RefreshTabVisibility(self)
    if not self.frame or not self.frame.tabs then
        return
    end

    local visibleTabs = {}
    for index, tabName in ipairs(TAB_ORDER) do
        local tab = self.frame.tabs[index]
        if TrackHasWork(self, tabName) then
            tab:Show()
            visibleTabs[#visibleTabs + 1] = { index = index, name = tabName, tab = tab }
        else
            tab:Hide()
        end
    end

    if #visibleTabs == 0 then
        local summaryIdx = #TAB_ORDER
        local tab = self.frame.tabs[summaryIdx]
        tab:Show()
        visibleTabs[1] = { index = summaryIdx, name = "Summary", tab = tab }
    end

    for visibleIndex, info in ipairs(visibleTabs) do
        info.tab:ClearAllPoints()
        info.tab:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", (visibleIndex - 1) * 78, 0)
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

---------------------------------------------------------------------------
-- Track view rendering
---------------------------------------------------------------------------
local function ActionCardHeading(result)
    local charName = result.mainName or "this character"

    if result.discountAlreadyActive then
        return string.format("Upgrade %s \226\128\148 warband discount is active", charName)
    end

    if result.shouldSwitchCharacter and result.cheapestCompletionCharacter then
        local diff = (result.currentCompletionCost or 0) - (result.cheapestCompletionCost or 0)
        return string.format("Switch to %s \226\128\148 saves %d crests vs current character",
            result.cheapestCompletionCharacter, math.max(0, diff))
    end

    if result.altFirstIsBetter then
        return string.format("Upgrade another character first \226\128\148 unlocks the discount and saves %d crests",
            result.savings or 0)
    end

    local diff = 0
    if result.scenarioB and result.scenarioB < math.huge and result.scenarioA then
        diff = math.max(0, result.scenarioB - result.scenarioA)
    end
    return string.format("Upgrade %s first \226\128\148 switching would cost %d more crests", charName, diff)
end

local function RenderTrackView(self, trackName)
    local result = GetTrackResult(self, trackName)
    EnsureTrackWidgets(self.frame)

    if self.frame.summaryView then
        self.frame.summaryView:Hide()
    end
    self.frame.trackView:Show()

    local ac = self.frame.trackView.actionCard
    local isAmber = result.altFirstIsBetter and not result.discountAlreadyActive

    -- Color the action card
    local bgColor = isAmber and COLORS.amberBg or COLORS.greenBg
    ApplyCardBg(ac, bgColor)
    local accentColor = isAmber and COLORS.amberAccent or COLORS.greenAccent
    ac.leftAccent:SetColorTexture(accentColor[1], accentColor[2], accentColor[3], accentColor[4])

    -- Check if the main character already holds enough crests to finish this track now.
    local balances = CrestPlanner.Currency:GetCurrentCrestBalances()
    local trackInfo = Constants.TRACKS[trackName] or {}
    local currencyName = trackInfo.currencyName
    local currency = currencyName and balances[currencyName] or nil
    local heldCrests = currency and currency.amount or 0
    local optimal = result.scenarioA or 0
    if result.scenarioB and result.scenarioB < optimal then optimal = result.scenarioB end
    if result.scenarioC and result.scenarioC < optimal then optimal = result.scenarioC end
    local fundedNow = optimal > 0 and heldCrests >= optimal

    local subtitleLine = string.format("THIS WEEK \226\128\148 %s TRACK", trackName:upper())
    if fundedNow then
        subtitleLine = subtitleLine .. "  \xC2\xB7 " .. C(COLORS.good, "enough crests to finish now")
    end
    ac.subtitle:SetText(C(isAmber and COLORS.warn or COLORS.good, subtitleLine))

    ac.heading:SetText(ActionCardHeading(result))

    -- Action rows
    local actions = {}
    if isAmber then
        for i, action in ipairs(result.altActions or {}) do
            if i <= 3 then
                actions[#actions + 1] = {
                    text = string.format("Upgrade %s \226\128\148 %s slot",
                        action.characterName or "Alt", action.slotName or "?"),
                    cost = string.format("%d %s crests", action.cost or 0, trackName),
                }
            end
        end
        local discountedMainCost = (result.scenarioB and result.scenarioB < math.huge
            and result.altUnlockCost and result.altUnlockCost < math.huge)
            and math.max(0, result.scenarioB - result.altUnlockCost)
            or nil
        actions[#actions + 1] = {
            text = string.format("Then upgrade %s at %s discount",
                result.mainName or "this character", DiscountPctLabel()),
            cost = discountedMainCost
                and string.format("%d crests", discountedMainCost)
                or  string.format("saves %d crests", result.savings or 0),
        }
    else
        for i, action in ipairs(result.mainUpgradeActions or {}) do
            if i <= 4 then
                local prefix = action.source == "bag"
                    and string.format("Equip bag item then upgrade %s", result.mainName or "this character")
                    or  string.format("Upgrade %s", result.mainName or "this character")
                actions[#actions + 1] = {
                    text = string.format("%s \226\128\148 %s slot", prefix, action.slotName or "?"),
                    cost = string.format("%d %s crests", action.cost or 0, trackName),
                }
            end
        end
    end

    local maxActionRows = math.min(4, #actions)
    for i = 1, 4 do
        local row = ac.rows[i]
        if i <= maxActionRows then
            row.number:SetText(C(COLORS.muted, tostring(i)))
            row.text:SetText(actions[i].text)
            row.cost:SetText(C(COLORS.muted, actions[i].cost))
            row:Show()
        else
            row:Hide()
        end
    end

    -- Adjust action card height based on visible rows
    local actionCardHeight = 66 + (maxActionRows * 28)
    ac:SetHeight(actionCardHeight)

    -- Reposition bottom cards with consistent 8px gap
    local bottomTop = -(actionCardHeight + 8)
    local totalWidth = self.frame.trackView:GetWidth()
    local halfWidth = math.floor((totalWidth - 8) / 2)

    self.frame.trackView.warbandCard:ClearAllPoints()
    self.frame.trackView.warbandCard:SetPoint("TOPLEFT", 0, bottomTop)
    self.frame.trackView.warbandCard:SetPoint("BOTTOMLEFT", 0, 0)
    self.frame.trackView.warbandCard:SetWidth(halfWidth)

    self.frame.trackView.discountCard:ClearAllPoints()
    self.frame.trackView.discountCard:SetPoint("TOPRIGHT", 0, bottomTop)
    self.frame.trackView.discountCard:SetPoint("BOTTOMRIGHT", 0, 0)
    self.frame.trackView.discountCard:SetWidth(halfWidth)

    -- Warband card
    local wc = self.frame.trackView.warbandCard
    wc.title:SetText(C(COLORS.section, string.format("WARBAND \226\128\148 %s PROGRESS", trackName:upper())))

    -- Filter out characters that aren't actionable for this track:
    --  - Below max level (not eligible for endgame crest progression)
    --  - No known-track gear (never scanned with new-enough data)
    --  - Stale data (no upgrades needed but not fully complete — usually
    --    means their items can't be evaluated, not that they're actually done)
    -- Always keep the main character.
    local minLevel = Constants.MIN_CHARACTER_LEVEL or 0
    local allRows = result.warbandRows or {}
    local warbandRows = {}
    for _, row in ipairs(allRows) do
        local levelOk = (row.level or 0) >= minLevel
        local hasGear = (row.knownSlots or 0) > 0
        local totalSlots = row.totalSlots or 0
        local slotsAtMax = row.slotsAtMax or 0
        local slotsNeeding = row.slotsNeeding or 0
        local actionable = slotsNeeding > 0 or (totalSlots > 0 and slotsAtMax >= totalSlots)
        if row.isMain or (levelOk and hasGear and actionable) then
            warbandRows[#warbandRows + 1] = row
        end
    end
    table.sort(warbandRows, function(a, b)
        -- Main always first
        if a.isMain ~= b.isMain then return a.isMain end
        -- Completed characters (0 crests needed) go to the bottom
        local aDone = (a.crestNeeded or 0) == 0
        local bDone = (b.crestNeeded or 0) == 0
        if aDone ~= bDone then return bDone end
        -- Otherwise sort by least crests needed first
        if (a.crestNeeded or 0) ~= (b.crestNeeded or 0) then
            return (a.crestNeeded or 0) < (b.crestNeeded or 0)
        end
        return a.name < b.name
    end)

    local maxCharRows = math.min(6, #warbandRows)
    for i = 1, 6 do
        local charRow = wc.charRows[i]
        if i <= maxCharRows then
            local data = warbandRows[i]
            if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[data.classFileName] then
                local coords = CLASS_ICON_TCOORDS[data.classFileName]
                charRow.classIcon:SetTexCoord(unpack(coords))
            else
                charRow.classIcon:SetTexCoord(0, 0.25, 0, 0.25)
            end
            charRow.name:SetText(data.name or "Unknown")
            charRow.youBadge:SetText(data.isMain and "you" or "")
            charRow.realm:SetText(C(COLORS.muted, data.realm or ""))

            local total = math.max(1, data.totalSlots or 1)
            local atMax = data.slotsAtMax or 0
            local isDone = atMax >= total

            if isDone then
                charRow.bar:Hide()
                charRow.ratio:Hide()
                charRow.costText:Hide()
                charRow.realm:Hide()
                charRow.completedText:Show()
            else
                charRow.bar:SetMinMaxValues(0, total)
                charRow.bar:SetValue(atMax)
                local barColor = isAmber and COLORS.amberAccent or COLORS.greenAccent
                charRow.bar:SetStatusBarColor(barColor[1] * 0.7, barColor[2] * 0.7, barColor[3] * 0.7)
                charRow.ratio:SetText(C(COLORS.muted, string.format("%d / %d", atMax, total)))
                charRow.costText:SetText(string.format("%d crests", data.crestNeeded or 0))
                charRow.bar:Show()
                charRow.ratio:Show()
                charRow.costText:Show()
                charRow.realm:Show()
                charRow.completedText:Hide()
            end
            charRow:Show()
        else
            charRow:Hide()
        end
    end

    -- Discount card
    local dc = self.frame.trackView.discountCard
    local currentDiscountActive = CrestPlanner.Optimiser:IsDiscountAlreadyActive(trackName)

    if currentDiscountActive then
        dc.activeText:Show()
        for i = 1, 4 do dc.discountRows[i]:Hide() end
    else
        dc.activeText:Hide()
        local discountRowIndex = 0
        local pctLabel = DiscountPctLabel()
        for _, tn in ipairs({ "Veteran", "Champion", "Hero", "Myth" }) do
            local discountActive = CrestPlanner.Optimiser:IsDiscountAlreadyActive(tn)
            if not discountActive then
                discountRowIndex = discountRowIndex + 1
                if discountRowIndex <= 4 then
                    local drow = dc.discountRows[discountRowIndex]
                    drow.label:SetText(tn)

                    local trackResult = GetTrackResult(self, tn)
                    local tnOrder = (Constants.TRACKS[tn] or {}).order or 0

                    local mainSlotsNeeding = 0
                    local mainTotalSlots = 15
                    for _, wr in ipairs(trackResult.warbandRows or {}) do
                        if wr.isMain then
                            mainSlotsNeeding = wr.slotsNeeding or 0
                            mainTotalSlots = wr.totalSlots or 15
                            break
                        end
                    end
                    local threshold = mainTotalSlots
                    local remaining = mainSlotsNeeding

                    drow.bar:SetMinMaxValues(0, threshold)
                    drow.bar:SetValue(threshold - remaining)

                    local currentTrackMeta = Constants.TRACKS[trackName]
                    local currentOrder = currentTrackMeta and currentTrackMeta.order or 0

                    if tnOrder == currentOrder then
                        drow.bar:SetStatusBarColor(0.36, 1.0, 0.48)
                    else
                        drow.bar:SetStatusBarColor(0.3, 0.5, 0.7)
                    end

                    drow.info:SetText(C(COLORS.muted, string.format("%d slots until %s off", remaining, pctLabel)))
                    drow:Show()
                end
            end
        end

        for i = discountRowIndex + 1, 4 do
            dc.discountRows[i]:Hide()
        end
    end

    -- Tip text
    local tipText = ""
    if not result.discountAlreadyActive then
        local mainRow
        for _, row in ipairs(result.warbandRows or {}) do
            if row.isMain then mainRow = row; break end
        end
        local tipRemaining = (mainRow and mainRow.slotsNeeding) or 0
        local charForTip = (result.mainName) or "this character"
        tipText = string.format(
            "Finish %s's last %s %s slots to unlock the warband discount for all characters.",
            charForTip,
            C(COLORS.value, tostring(tipRemaining)),
            C(COLORS.value, trackName)
        )
    else
        tipText = C(COLORS.good, "Warband discount is active for " .. trackName .. ".")
    end
    dc.tip:SetText(tipText)
end

---------------------------------------------------------------------------
-- Summary view rendering
---------------------------------------------------------------------------
local function RenderSummaryView(self)
    local allTrackResults = CrestPlanner.Optimiser:EvaluateAllTracks()
    local weekly = CrestPlanner.Planner:GetWeeklyPreview(allTrackResults)

    if self.frame.trackView then
        self.frame.trackView:Hide()
    end
    EnsureSummaryWidgets(self.frame)
    self.frame.summaryView:Show()

    -- Stat cards
    local sc = self.frame.summaryView.statCards
    sc[1].value:SetText(FormatNumber(weekly.totalOptimalCost or 0))
    sc[2].value:SetText(C(COLORS.good, FormatNumber(weekly.totalSavings or 0)))

    local capLabel = weekly.weeklyCap and string.format("(%d/wk)", weekly.weeklyCap) or ""
    sc[3].label:SetText(C(COLORS.muted, "Weeks at cap " .. capLabel))
    if weekly.estimatedWeeks == "N/A" then
        sc[3].value:SetText(C(COLORS.warn, "N/A"))
    else
        sc[3].value:SetText(C(COLORS.warn, string.format("~%s", tostring(weekly.estimatedWeeks))))
    end

    -- Weekly outlook
    local oc = self.frame.summaryView.outlookCard
    local outlookRows = weekly.outlookRows or {}
    local maxOutlook = math.min(4, #outlookRows)
    for i = 1, 4 do
        local row = oc.rows[i]
        if i <= maxOutlook then
            local data = outlookRows[i]
            local currencyName = (Constants.TRACKS[data.trackName] or {}).currencyName
            local currencyID = currencyName and Constants.CREST_CURRENCY_IDS[currencyName]
            if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
                if info and info.iconFileID then
                    row.icon:SetTexture(info.iconFileID)
                end
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
            end

            local needed = data.needed or 0
            local total  = data.total  or 0
            local fullyDone   = total == 0
            local fundedNow   = total > 0 and needed == 0

            local neededText
            if fullyDone then
                neededText = C(COLORS.good, "complete")
            elseif fundedNow then
                neededText = C(COLORS.good, "enough crests held")
            else
                neededText = string.format("%d still needed", needed)
            end
            row.mainText:SetText(string.format(
                "%s \226\128\148 %d crests held, %s",
                C(COLORS.value, data.trackName),
                data.held or 0,
                neededText
            ))

            local subtitleColor = data.altFirstIsBetter and COLORS.warn or COLORS.muted
            row.subtitle:SetText(C(subtitleColor, data.subtitle or ""))

            if data.weeks == math.huge then
                row.weeks:SetText(C(COLORS.muted, "N/A"))
            elseif fullyDone then
                row.weeks:SetText(C(COLORS.good, "done"))
            elseif fundedNow then
                row.weeks:SetText(C(COLORS.good, "ready"))
            else
                row.weeks:SetText(C(COLORS.muted, string.format("~%d wks", data.weeks)))
            end
            row:Show()
        else
            row:Hide()
        end
    end

    local outlookHeight = 34 + (maxOutlook * 50)
    oc:SetHeight(outlookHeight)

    -- Reposition priority card
    local pc = self.frame.summaryView.priorityCard
    pc:ClearAllPoints()
    pc:SetPoint("TOPLEFT", 0, -(80 + outlookHeight + 8))
    pc:SetPoint("RIGHT", 0, 0)

    local priorityActions = weekly.priorityActions or {}
    local maxPriority = math.min(4, #priorityActions)
    for i = 1, 4 do
        local row = pc.rows[i]
        if i <= maxPriority then
            local data = priorityActions[i]
            row.number:SetText(C(COLORS.muted, tostring(i)))
            row.text:SetText(data.text or "")
            row.cost:SetText(C(COLORS.muted, data.cost or ""))
            row:Show()
        else
            row:Hide()
        end
    end

    local priorityHeight = 34 + (maxPriority * 36)
    pc:SetHeight(priorityHeight)

    -- Update scroll child height so scrollbar works
    local totalHeight = 80 + outlookHeight + 8 + priorityHeight + 16
    if self.frame.summaryView.scrollChild then
        self.frame.summaryView.scrollChild:SetHeight(totalHeight)
    end
end

---------------------------------------------------------------------------
-- Bonus view rendering
---------------------------------------------------------------------------
local function RenderBonusView(self)
    if self.frame.trackView then self.frame.trackView:Hide() end
    if self.frame.summaryView then self.frame.summaryView:Hide() end
    EnsureBonusWidgets(self.frame)
    self.frame.bonusView:Show()

    local bc = self.frame.bonusView
    local sources = Constants.BONUS_CREST_SOURCES or {}
    local characters = CrestPlanner.Scanner:GetWarbandCharacters()
    local minLevel = Constants.MIN_CHARACTER_LEVEL or 0

    -- Build filtered character list
    local bonusChars = {}
    for key, char in pairs(characters) do
        if (char.level or 0) >= minLevel then
            bonusChars[#bonusChars + 1] = {
                key = key,
                name = char.name or key,
                bonusStatus = char.bonusStatus or {},
            }
        end
    end
    table.sort(bonusChars, function(a, b) return a.name < b.name end)
    local maxChars = math.min(6, #bonusChars)

    -- Position character name headers.
    -- Rows have a 10px left margin, so marks live at row.left + colStart.
    -- Headers are anchored to bc directly, so offset by 10 to match.
    local colStart = 140
    local colWidth = 56
    local headerX = 10 + colStart  -- 10 = row left margin
    for i = 1, 6 do
        local header = bc.charHeaders[i]
        if i <= maxChars then
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", bc, "TOPLEFT", headerX + ((i - 1) * colWidth), -38)
            header:SetText(C(COLORS.muted, bonusChars[i].name))
            header:Show()
        else
            header:Hide()
        end
    end

    -- Render source rows
    local maxSources = math.min(8, #sources)
    local totalUnclaimed = 0
    for i = 1, 8 do
        local row = bc.sourceRows[i]
        if i <= maxSources then
            local source = sources[i]
            row._labelText = source.label or "Unknown"
            row._hint = source.hint or ""
            row.label:SetText(source.label or "Unknown")

            -- Build reward text
            local rewardParts = {}
            for crestType, amount in pairs(source.crests or {}) do
                rewardParts[#rewardParts + 1] = amount .. " " .. crestType
            end
            local freqTag = source.frequency == "weekly" and " (wk)" or ""
            row.reward:SetText(C(COLORS.muted, table.concat(rewardParts, " + ") .. freqTag))

            -- Per-character marks
            for j = 1, 6 do
                local mark = row.marks[j]
                if j <= maxChars then
                    mark:ClearAllPoints()
                    mark:SetPoint("LEFT", row, "LEFT", colStart + ((j - 1) * colWidth), 0)
                    local completed = bonusChars[j].bonusStatus[source.id] or false
                    if completed then
                        mark:SetText("|cff5cff7aDone|r")
                    else
                        mark:SetText("|cffff5555Miss|r")
                        totalUnclaimed = totalUnclaimed + 1
                    end
                    mark:Show()
                else
                    mark:Hide()
                end
            end

            row:Show()
        else
            row:Hide()
        end
    end

    if totalUnclaimed > 0 then
        bc.footer:SetText(C(COLORS.warn, string.format("%d unclaimed across your warband", totalUnclaimed)))
    else
        bc.footer:SetText(C(COLORS.good, "All bonus crests claimed!"))
    end
end

---------------------------------------------------------------------------
-- Frame creation
---------------------------------------------------------------------------
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

    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.03, 0.04, 0.06, 0.95)

    -- Top bar
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

    -- Footer bar (tab area)
    frame.footerBar = frame:CreateTexture(nil, "ARTWORK")
    frame.footerBar:SetPoint("BOTTOMLEFT", 0, 0)
    frame.footerBar:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.footerBar:SetHeight(28)
    frame.footerBar:SetColorTexture(0.05, 0.07, 0.1, 0.98)

    frame.footerTopEdge = frame:CreateTexture(nil, "BORDER")
    frame.footerTopEdge:SetPoint("BOTTOMLEFT", 0, 28)
    frame.footerTopEdge:SetPoint("BOTTOMRIGHT", 0, 28)
    frame.footerTopEdge:SetHeight(1)
    frame.footerTopEdge:SetColorTexture(0, 0.82, 0.76, 0.55)

    -- Logo + title
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

    -- Close button (created first so season dropdown can anchor to it)
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

    -- Season dropdown (top bar, left of close button)
    do
        local ROW_H    = 22
        local BTN_W    = 112
        local BTN_H    = 18

        -- Dropdown panel — parented to UIParent so it floats above the modal.
        local panel = CreateFrame("Frame", nil, UIParent)
        panel:SetFrameStrata("FULLSCREEN_DIALOG")
        panel:SetFrameLevel(200)
        panel:SetWidth(BTN_W)
        panel:Hide()

        panel.bg = panel:CreateTexture(nil, "BACKGROUND")
        panel.bg:SetAllPoints()
        panel.bg:SetColorTexture(0.05, 0.07, 0.1, 0.98)

        panel.border = panel:CreateTexture(nil, "BORDER")
        panel.border:SetPoint("TOPLEFT",     0,  0)
        panel.border:SetPoint("BOTTOMRIGHT", 0,  0)
        panel.border:SetColorTexture(0, 0.82, 0.76, 0.35)

        panel.rows = {}

        local function RebuildPanel(anchorBtn)
            local order = Constants.SEASON_ORDER or {}
            panel:SetHeight(#order * ROW_H + 2)
            panel:ClearAllPoints()
            panel:SetPoint("TOPRIGHT", anchorBtn, "BOTTOMRIGHT", 0, -2)

            for i, key in ipairs(order) do
                if not panel.rows[i] then
                    local row = CreateFrame("Button", nil, panel)
                    row:SetHeight(ROW_H)
                    row:SetPoint("TOPLEFT",  1, -1 - (i - 1) * ROW_H)
                    row:SetPoint("TOPRIGHT", -1, -1 - (i - 1) * ROW_H)

                    row.hl = row:CreateTexture(nil, "BACKGROUND")
                    row.hl:SetAllPoints()
                    row.hl:SetColorTexture(0.1, 0.2, 0.22, 0)

                    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.text:SetPoint("LEFT", 8, 0)
                    row.text:SetPoint("RIGHT", -8, 0)
                    row.text:SetJustifyH("LEFT")

                    row:SetScript("OnEnter", function() row.hl:SetColorTexture(0.1, 0.2, 0.22, 0.9) end)
                    row:SetScript("OnLeave", function() row.hl:SetColorTexture(0.1, 0.2, 0.22, 0) end)
                    panel.rows[i] = row
                end

                local row    = panel.rows[i]
                local season = Constants.SEASONS[key]
                local lbl    = (season and season.label) or key
                local active = key == Constants.ACTIVE_SEASON
                local season = Constants.SEASONS[key]
                local soon  = season and season.comingSoon
                if active then
                    row.text:SetText(C(COLORS.good, lbl))
                elseif soon then
                    row.text:SetText(C(COLORS.muted, lbl .. " (soon)"))
                else
                    row.text:SetText(C(COLORS.muted, lbl))
                end
                row:SetScript("OnClick", function()
                    Constants.ApplySeason(key)
                    if CrestPlannerDB then CrestPlannerDB.activeSeason = key end
                    if not soon then
                        CrestPlanner.Scanner:ScanCurrentCharacter()
                    end
                    panel:Hide()
                    MainFrame:Render(MainFrame.selectedTabName)
                end)
                row:Show()
            end

            -- Hide stale rows beyond current season count
            for i = #(Constants.SEASON_ORDER or {}) + 1, #panel.rows do
                if panel.rows[i] then panel.rows[i]:Hide() end
            end
        end

        -- Click-off blocker: a transparent frame behind the panel that eats
        -- mouse events outside the dropdown.
        local blocker = CreateFrame("Frame", nil, UIParent)
        blocker:SetAllPoints(UIParent)
        blocker:SetFrameStrata("FULLSCREEN_DIALOG")
        blocker:SetFrameLevel(199)
        blocker:EnableMouse(true)
        blocker:Hide()
        blocker:SetScript("OnMouseDown", function()
            panel:Hide()
            blocker:Hide()
        end)
        panel:HookScript("OnShow", function() blocker:Show() end)
        panel:HookScript("OnHide", function() blocker:Hide() end)

        -- The visible dropdown button in the top bar
        local btn = CreateFrame("Button", nil, frame)
        btn:SetSize(BTN_W, BTN_H)
        btn:SetPoint("RIGHT", frame.close, "LEFT", -8, 0)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.08, 0.11, 0.14, 0.8)

        btn.border = btn:CreateTexture(nil, "BORDER")
        btn.border:SetAllPoints()
        btn.border:SetColorTexture(0, 0.82, 0.76, 0.2)

        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.label:SetPoint("LEFT", 6, 0)
        btn.label:SetPoint("RIGHT", -6, 0)
        btn.label:SetJustifyH("LEFT")

        btn:SetScript("OnEnter", function()
            if #(Constants.SEASON_ORDER or {}) > 1 then
                btn.bg:SetColorTexture(0.12, 0.18, 0.22, 0.9)
            end
        end)
        btn:SetScript("OnLeave", function()
            btn.bg:SetColorTexture(0.08, 0.11, 0.14, 0.8)
        end)
        btn:SetScript("OnClick", function()
            if #(Constants.SEASON_ORDER or {}) <= 1 then return end
            if panel:IsShown() then
                panel:Hide()
            else
                RebuildPanel(btn)
                panel:Show()
            end
        end)

        frame.seasonDropdown     = btn
        frame.seasonDropdownPanel = panel
    end

    -- Tabs (at top, below top bar)
    frame.tabs = {}
    for index, tabName in ipairs(TAB_ORDER) do
        local tab = CreateFrame("Button", "$parentTab" .. index, frame)
        tab:SetSize(78, 28)

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

        tab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (index - 1) * 78, 0)
        tab:SetScript("OnClick", function()
            MainFrame.selectedTabName = tabName
            MainFrame:Render(tabName)
        end)
        frame.tabs[index] = tab
    end

    self.selectedTabName = TAB_ORDER[1]

    -- ESC close
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

    -- Level gate overlay: covers content when player is below max level
    frame.levelGate = CreateFrame("Frame", nil, frame)
    frame.levelGate:SetPoint("TOPLEFT", 0, -29)
    frame.levelGate:SetPoint("BOTTOMRIGHT", 0, 29)
    frame.levelGate:SetFrameLevel(frame:GetFrameLevel() + 50)
    frame.levelGate:Hide()

    frame.levelGate.bg = frame.levelGate:CreateTexture(nil, "BACKGROUND")
    frame.levelGate.bg:SetAllPoints()
    frame.levelGate.bg:SetColorTexture(0.02, 0.03, 0.05, 0.96)

    frame.levelGate.icon = frame.levelGate:CreateTexture(nil, "ARTWORK")
    frame.levelGate.icon:SetPoint("CENTER", 0, 40)
    frame.levelGate.icon:SetSize(64, 64)
    frame.levelGate.icon:SetTexture("Interface\\Icons\\Spell_ChargePositive")

    frame.levelGate.title = frame.levelGate:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.levelGate.title:SetPoint("CENTER", 0, -20)
    frame.levelGate.title:SetTextColor(1, 1, 1)

    frame.levelGate.subtitle = frame.levelGate:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.levelGate.subtitle:SetPoint("CENTER", 0, -50)
    frame.levelGate.subtitle:SetTextColor(0.6, 0.72, 0.72)

    self.frame = frame
    RefreshTabVisibility(self)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
local function RefreshSeasonSelector(frame)
    if not frame.seasonDropdown then return end
    local current = Constants.ACTIVE_SEASON
    local season  = current and Constants.SEASONS and Constants.SEASONS[current]
    local lbl     = (season and season.label) or current or "Season"
    frame.seasonDropdown.label:SetText(C(COLORS.value, lbl))
end

function MainFrame:Render(tabName)
    self._renderCache = {}
    RefreshSeasonSelector(self.frame)

    -- Ensure the level gate exists (self-healing if frame predates overlay code)
    if not self.frame.levelGate then
        local gate = CreateFrame("Frame", nil, self.frame)
        gate:SetPoint("TOPLEFT", 0, -29)
        gate:SetPoint("BOTTOMRIGHT", 0, 29)
        gate:SetFrameLevel(self.frame:GetFrameLevel() + 50)
        gate:EnableMouse(true)
        gate:Hide()

        gate.bg = gate:CreateTexture(nil, "BACKGROUND")
        gate.bg:SetAllPoints()
        gate.bg:SetColorTexture(0.02, 0.03, 0.05, 0.98)

        gate.icon = gate:CreateTexture(nil, "ARTWORK")
        gate.icon:SetPoint("CENTER", 0, 50)
        gate.icon:SetSize(64, 64)
        gate.icon:SetTexture("Interface\\Icons\\Spell_ChargePositive")

        gate.title = gate:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        gate.title:SetPoint("CENTER", 0, -10)
        gate.title:SetTextColor(1, 1, 1)

        gate.subtitle = gate:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        gate.subtitle:SetPoint("CENTER", 0, -40)
        gate.subtitle:SetTextColor(0.6, 0.72, 0.72)

        self.frame.levelGate = gate
    end

    -- Level gate: if the current character is below max, show overlay and stop.
    local minLevel = Constants.MIN_CHARACTER_LEVEL or 0
    local playerLevel = UnitLevel("player") or 0
    if minLevel > 0 and playerLevel > 0 and playerLevel < minLevel then
        if self.frame.trackView then self.frame.trackView:Hide() end
        if self.frame.summaryView then self.frame.summaryView:Hide() end
        if self.frame.bonusView then self.frame.bonusView:Hide() end
        for _, tab in ipairs(self.frame.tabs or {}) do tab:Hide() end
        self.frame.levelGate.icon:SetTexture("Interface\\Icons\\Spell_ChargePositive")
        self.frame.levelGate.title:SetText(string.format("Reach level %d to activate", minLevel))
        self.frame.levelGate.subtitle:SetText(string.format("Currently level %d", playerLevel))
        self.frame.levelGate:Show()
        return
    end

    self.frame.levelGate:Hide()

    -- Coming-soon overlay: active season not yet released.
    local activeSeason = Constants.SEASONS and Constants.SEASONS[Constants.ACTIVE_SEASON]
    if activeSeason and activeSeason.comingSoon then
        if self.frame.trackView   then self.frame.trackView:Hide()   end
        if self.frame.summaryView then self.frame.summaryView:Hide() end
        if self.frame.bonusView   then self.frame.bonusView:Hide()   end
        for _, tab in ipairs(self.frame.tabs or {}) do tab:Hide() end

        -- Use the top-tier crest icon from the current active season's currency.
        -- Falls back to the Myth currency from the previous season, then a generic coin.
        local crestIcon
        local prevSeason = Constants.SEASONS and Constants.SEASONS[Constants.SEASON_ORDER and Constants.SEASON_ORDER[1]]
        local mythCurrencyID = prevSeason and prevSeason.CREST_CURRENCY_IDS and prevSeason.CREST_CURRENCY_IDS.Myth
        if mythCurrencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local info = C_CurrencyInfo.GetCurrencyInfo(mythCurrencyID)
            crestIcon = info and info.iconFileID
        end
        self.frame.levelGate.icon:SetTexture(crestIcon or "Interface\\Icons\\inv_misc_coin_17")

        self.frame.levelGate.title:SetText(activeSeason.label .. " — Coming Soon")
        self.frame.levelGate.subtitle:SetText("Season data will be added when it releases.")
        self.frame.levelGate:Show()
        RefreshSeasonSelector(self.frame)
        return
    end

    RefreshTabVisibility(self)
    if tabName ~= self.selectedTabName then
        tabName = self.selectedTabName
    end

    if tabName == "Summary" then
        if self.frame.bonusView then self.frame.bonusView:Hide() end
        RenderSummaryView(self)
        return
    end

    if tabName == "Bonus" then
        if self.frame.trackView then self.frame.trackView:Hide() end
        if self.frame.summaryView then self.frame.summaryView:Hide() end
        RenderBonusView(self)
        return
    end

    if self.frame.bonusView then self.frame.bonusView:Hide() end
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
