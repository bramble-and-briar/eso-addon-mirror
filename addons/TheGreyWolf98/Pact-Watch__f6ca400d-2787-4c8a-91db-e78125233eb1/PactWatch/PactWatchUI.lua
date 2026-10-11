local PW = PactWatch
local EP, AD, DC = ALLIANCE_EBONHEART_PACT, ALLIANCE_ALDMERI_DOMINION, ALLIANCE_DAGGERFALL_COVENANT
local function label(parent, name, x, y, width, height, font)
    local c = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(width, height)
    c:SetFont(font or "ZoFontGamepad22")
    c:SetColor(0.92, 0.92, 0.92, 1)
    return c
end
local function background(parent, name)
    local c = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    c:SetAnchorFill(parent)
    c:SetCenterColor(0.035, 0.035, 0.045, 0.96)
    c:SetEdgeColor(0.62, 0.16, 0.16, 1)
    c:SetEdgeTexture(nil, 1, 1, 2)
    return c
end
local function button(parent, name, text, x, y, width, callback)
    local c = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(width, 36)
    c:SetFont("ZoFontGamepad22")
    c:SetNormalFontColor(1, 0.70, 0.65, 1)
    c:SetMouseOverFontColor(1, 1, 1, 1)
    c:SetText(text)
    c:SetHandler("OnClicked", callback)
    return c
end
function PW:PositionWindow()
    self.window:ClearAnchors()
    self.window:SetAnchor(CENTER, GuiRoot, CENTER, self.sv.x or 0, self.sv.y or 0)
end
function PW:CreateUI()
    local w = WINDOW_MANAGER:CreateTopLevelWindow("PactWatchWindow")
    self.window = w
    w:SetDimensions(1000, 740)
    w:SetClampedToScreen(true)
    w:SetMouseEnabled(true)
    w:SetMovable(true)
    w:SetHidden(true)
    self:PositionWindow()
    w:SetHandler("OnMoveStop", function()
        self.sv.x = w:GetLeft() + w:GetWidth() / 2 - GuiRoot:GetWidth() / 2
        self.sv.y = w:GetTop() + w:GetHeight() / 2 - GuiRoot:GetHeight() / 2
    end)
    background(w, "PactWatchBackground")
    label(w, "PactWatchTitle", 24, 12, 800, 40, "ZoFontGamepad34"):SetText("PACT WATCH | 0.1.4 CONSOLE TEST")
    self.statusLabel = label(w, "PactWatchStatus", 24, 57, 585, 30)
    self.holdingsLabel = label(w, "PactWatchHoldings", 24, 91, 585, 30)
    self.campaignLabels = {}
    for i = 1, 3 do self.campaignLabels[i] = label(w, "PactWatchCampaign" .. i, 625, 53 + (i - 1) * 27, 351, 27, "ZoFontGamepad22") end
    self.hammerLabel = label(w, "PactWatchHammer", 24, 130, 952, 28)
    self.emperorLabel = label(w, "PactWatchEmperor", 24, 162, 952, 28)
    label(w, "PactWatchActivityTitle", 24, 196, 952, 34, "ZoFontGamepad27"):SetText("ACTION BOARD | most relevant first")
    self.activityLabels = {}
    for i = 1, 6 do
        local y = 234 + (i - 1) * 68
        local divider = WINDOW_MANAGER:CreateControl("PactWatchRule" .. i, w, CT_TEXTURE)
        divider:SetAnchor(TOPLEFT, w, TOPLEFT, 24, y)
        divider:SetDimensions(952, 1); divider:SetColor(0.4, 0.16, 0.16, 0.7)
        self.activityLabels[i] = {
            title = label(w, "PactWatchActivityTitle" .. i, 24, y + 2, 952, 32, "ZoFontGamepad27"),
            detail = label(w, "PactWatchActivityDetail" .. i, 24, y + 34, 952, 32, "ZoFontGamepad27"),
        }
    end
    self.pageLabel = label(w, "PactWatchPage", 380, 649, 250, 30)
    button(w, "PactWatchPrev", "Previous", 24, 646, 120, function() self:Command("prev") end)
    button(w, "PactWatchNext", "Next", 150, 646, 100, function() self:Command("next") end)
    button(w, "PactWatchRefresh", "Refresh", 685, 646, 130, function() self:Command("refresh") end)
    button(w, "PactWatchClose", "Close", 850, 646, 100, function() self:CloseWindow() end)
    label(w, "PactWatchFooter", 24, 690, 952, 21, "ZoFontGamepad18"):SetText("B / Back closes | /pw close | /pw next/prev | /pw hud | /pw diag | by @TheGreyWolf98")
    label(w, "PactWatchFooterNotes", 24, 712, 952, 21, "ZoFontGamepad18"):SetText("Deaths = received reports; siege = weapons. First wall damage and exact player totals unavailable.")
    local h = WINDOW_MANAGER:CreateTopLevelWindow("PactWatchHUD")
    self.hud = h
    h:SetDimensions(510, 245)
    h:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -35, 180)
    h:SetClampedToScreen(true); h:SetMouseEnabled(false); h:SetHidden(true)
    background(h, "PactWatchHUDBackground")
    label(h, "PactWatchHUDTitle", 12, 8, 486, 30, "ZoFontGamepad27"):SetText("PACT WATCH | RECENT ACTION")
    self.hudLabels = {}
    for i = 1, 3 do
        local y = 43 + (i - 1) * 56
        self.hudLabels[i] = {
            title = label(h, "PactWatchHUDTitle" .. i, 12, y, 486, 26),
            detail = label(h, "PactWatchHUDDetail" .. i, 12, y + 27, 486, 26, "ZoFontGamepad18"),
        }
    end
    label(h, "PactWatchHUDFooter", 12, 216, 486, 23, "ZoFontGamepad18"):SetText("/pw full briefing | /pw hud to hide")
    -- Scale down on lower-resolution UI roots; preserve large type at 1080p.
    local scale = math.min(1, (GuiRoot:GetWidth() - 40) / 1000, (GuiRoot:GetHeight() - 40) / 740)
    w:SetScale(math.max(0.5, scale))
    self:CreateWindowScene()
end
function PW:CreateWindowScene()
    if not (ZO_Scene and ZO_SimpleSceneFragment and SCENE_MANAGER and KEYBIND_STRIP and UI_SHORTCUTS_ACTION_LAYER_FRAGMENT) then return end
    self.windowScene = ZO_Scene:New("pactWatch", SCENE_MANAGER)
    self.windowScene:AddFragment(ZO_SimpleSceneFragment:New(self.window))
    self.windowScene:AddFragment(UI_SHORTCUTS_ACTION_LAYER_FRAGMENT)
    if GAMEPAD_UI_MODE_FRAGMENT then self.windowScene:AddFragment(GAMEPAD_UI_MODE_FRAGMENT) end
    if FRAGMENT_GROUP and FRAGMENT_GROUP.GAMEPAD_KEYBIND_STRIP_GROUP then
        self.windowScene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_KEYBIND_STRIP_GROUP)
    end
    self.windowKeys = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        { name = "Close", keybind = "UI_SHORTCUT_NEGATIVE", callback = function() self:CloseWindow() end },
        { name = "Next page", keybind = "UI_SHORTCUT_PRIMARY", callback = function() self:Command("next") end },
        { name = "Refresh", keybind = "UI_SHORTCUT_SECONDARY", callback = function() self:Command("refresh") end },
        { name = "Previous page", keybind = "UI_SHORTCUT_TERTIARY", callback = function() self:Command("prev") end },
    }
    self.windowScene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(self.windowKeys)
            self.windowKeysAdded = true
            self:Render()
        elseif state == SCENE_HIDDEN and self.windowKeysAdded then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.windowKeys)
            self.windowKeysAdded = false
        end
    end)
end
function PW:OpenWindow()
    if not self.window then return end
    self:RequestBriefing()
    if self.windowScene then SCENE_MANAGER:Show("pactWatch") else self.window:SetHidden(false) end
    self:Render()
end
function PW:CloseWindow()
    if not self.window then return end
    if self.windowScene and SCENE_MANAGER:IsShowing("pactWatch") then SCENE_MANAGER:HideCurrentScene() end
    self.window:SetHidden(true)
end
function PW:ToggleWindow()
    if not self.window then return end
    if self.window:IsHidden() then self:OpenWindow() else self:CloseWindow() end
end
function PW:ToggleHUD()
    if not self.sv then return end
    self.sv.hud = not self.sv.hud
    self:Chat("HUD " .. (self.sv.hud and "on (Cyrodiil only)" or "off"))
    self:Render()
end
function PW:Render()
    if not self.window then return end
    local list = self:GetActivities()
    self.hud:SetHidden(not (self:Running() and self.sv.hud))
    for i = 1, 3 do
        local a = list[i]
        self.hudLabels[i].title:SetText(a and (self:ColourAlliance(a.owner, a.name) .. " | observed " .. self:Age(a.last) .. " ago") or
            (i == 1 and "No received activity yet." or ""))
        self.hudLabels[i].detail:SetText(a and a.detail or (i == 1 and "Waiting for campaign reports / siege data." or ""))
    end
    if self.window:IsHidden() then return end
    local state = not self:IsPact() and "PACT CHARACTERS ONLY" or (not self.sv.enabled and "MONITORING DISABLED" or
        (self:Inside() and "LIVE CYRODIIL | scan " .. self:Age(self.lastScan) .. " ago" or "PRE-ENTRY BRIEFING | home holdings if available"))
    self.statusLabel:SetText(state .. " | chat " .. (self.sv.chat and "ON" or "OFF") .. " | sound " .. (self.sv.sound and "ON" or "OFF"))
    self.holdingsLabel:SetText(self:IsPact() and self:Holdings():gsub(" %(client data%)", ""):gsub(" %(home campaign client data%)", " (home)") or "This build serves the Ebonheart Pact.")
    local lines = {}
    local wanted = self:Inside() and self:Read("GetCurrentCampaignId") or self:Read("GetAssignedCampaignId")
    local rows = {}
    for _, r in ipairs(self.campaignRows) do table.insert(rows, r) end
    table.sort(rows, function(a, b) if (a.id == wanted) ~= (b.id == wanted) then return a.id == wanted end; return a.name < b.name end)
    for i = 1, math.min(3, #rows) do
        local r = rows[i]
        local function pop(side)
            local v = r.pop[side] == "MEDIUM" and "MED" or r.pop[side]
            return self:ColourAlliance(side, v)
        end
        table.insert(lines, r.name .. "  " .. pop(EP) .. "  " .. pop(AD) .. "  " .. pop(DC))
    end
    if #lines == 0 then lines[1] = "Population pending: refresh" end
    for i = 1, 3 do self.campaignLabels[i]:SetText(lines[i] or "") end
    local hammer, emperor = self:SpecialLines()
    self.hammerLabel:SetText(self:Inside() and hammer or "HAMMER | Enter Cyrodiil for live reports")
    self.emperorLabel:SetText(self:Inside() and emperor or "EMP | Enter Cyrodiil for live reports")
    local pages = math.max(1, math.ceil(#list / 6))
    self.page = math.max(1, math.min(self.page, pages))
    for i = 1, 6 do
        local a = list[(self.page - 1) * 6 + i]
        self.activityLabels[i].title:SetText(a and (self:ColourAlliance(a.owner, a.name) .. " | observed " .. self:Age(a.last) .. " ago") or
            (i == 1 and #list == 0 and "No activity received yet." or ""))
        self.activityLabels[i].detail:SetText(a and a.detail or (i == 1 and #list == 0 and
            (self:Inside() and "Monitoring starts when this build is active in Cyrodiil." or "Enter Cyrodiil to collect live battle reports.") or ""))
    end
    self.pageLabel:SetText("Page " .. self.page .. "/" .. pages .. " | " .. #list .. " locations")
end
