--[[
    AetherPath - Minimalist Dark UI
    Single focused quest view (native-like description + objectives)
    Cycle with T | No custom .dds textures
    Original layout
]]

AetherPath = AetherPath or {}
local AP = AetherPath
AP.UI = AP.UI or {}

local UI = AP.UI

local PADDING    = 10
local WIDTH      = 300
local HEADER_H   = 26

function UI:Initialize()
    self:CreateTrackerFrame()
    self:CreateTravelFrame()
    self:RegisterHudFragments()
    self:ApplyPosition()
    self:ApplyScale()
    self:ApplyAlpha()
    self:ApplyLock()
    AP.ApplyContrast(AP.sv.contrast or 1)
    self:ApplyTheme()
    self:SetTrackerVisible(AP.sv.showTracker ~= false)
    self:RegisterCycleKey()
    if AP.Tomes and AP.Tomes.Initialize then AP.Tomes:Initialize() end
end

-- Only show on world HUD — never on inventory, map, skills, etc.
function UI:RegisterHudFragments()
    if not self.trackerFrame then return end

    -- Prefer fade fragment (matches native tracker behavior)
    local frag
    if ZO_HUDFadeSceneFragment then
        frag = ZO_HUDFadeSceneFragment:New(self.trackerFrame)
    elseif ZO_HUDSceneFragment then
        frag = ZO_HUDSceneFragment:New(self.trackerFrame)
    elseif ZO_SimpleSceneFragment then
        frag = ZO_SimpleSceneFragment:New(self.trackerFrame)
    end
    self.trackerFragment = frag

    if frag then
        if HUD_SCENE and HUD_SCENE.AddFragment then
            HUD_SCENE:AddFragment(frag)
        end
        if HUD_UI_SCENE and HUD_UI_SCENE.AddFragment then
            HUD_UI_SCENE:AddFragment(frag)
        end
    end

    -- Extra safety: hide whenever a non-HUD scene is shown
    if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
            if not self.trackerFrame or not AP.sv then return end
            if not AP.sv.showTracker then
                self.trackerFrame:SetHidden(true)
                return
            end
            local name = scene and scene.GetName and scene:GetName() or ""
            local isHud = (name == "hud" or name == "hudui")
            if newState == SCENE_SHOWN then
                if isHud then
                    self.trackerFrame:SetHidden(false)
                    -- keep native tracker suppressed
                    if AP.Tracker then AP.Tracker:HideNativeTracker(true) end
                else
                    self.trackerFrame:SetHidden(true)
                    if self.travelFrame then self.travelFrame:SetHidden(true) end
                end
            end
        end)
    end
end

-------------------------------------------------
-- Key T: cycle focused quest (like native)
-------------------------------------------------
function UI:RegisterCycleKey()
    -- Prefer keybind system so it shows in Controls menu
    -- Fallback: direct key handler on tracker when focused is not required
    local function onCycle()
        if AP.Tracker then AP.Tracker:CycleNext() end
    end

    -- Slash already exists; also bind action if possible
    if KEYBINDING_MANAGER and KEYBINDING_MANAGER.RegisterKeybind then
        -- ESO keybind registration is via Bindings.xml + localization
        -- We already have AETHERPATH bindings; cycle is wired in Bindings.xml
    end

    -- Also listen for the native "assist next" style events if they fire
    EVENT_MANAGER:RegisterForEvent("AetherPath_Assist", EVENT_QUEST_ADVANCED, function()
        if AP.Tracker then AP.Tracker:Refresh() end
    end)
end

-------------------------------------------------
-- TRACKER FRAME
-------------------------------------------------
function UI:CreateTrackerFrame()
    local f = WINDOW_MANAGER:CreateTopLevelWindow("AetherPathTracker")
    f:SetDimensions(WIDTH, 160)
    f:SetMovable(true)
    f:SetMouseEnabled(true)
    f:SetClampedToScreen(true)
    f:SetDrawLayer(DL_CONTROLS)
    f:SetHandler("OnMoveStop", function()
        -- Save absolute screen position (reliable across reloads)
        local left = f:GetLeft()
        local top  = f:GetTop()
        if type(left) == "number" and type(top) == "number" then
            AP.sv.position = {
                point    = TOPLEFT,
                relPoint = TOPLEFT,
                x        = left,
                y        = top,
            }
        end
    end)
    -- Also save while moving ends via mouse up as backup
    f:SetHandler("OnMouseUp", function()
        if f.IsMoving and f:IsMoving() then return end
        local left = f:GetLeft()
        local top  = f:GetTop()
        if type(left) == "number" and type(top) == "number" and AP.sv then
            AP.sv.position = {
                point    = TOPLEFT,
                relPoint = TOPLEFT,
                x        = left,
                y        = top,
            }
        end
    end)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)Bg", f, CT_BACKDROP)
    bg:SetAnchorFill(f)
    bg:SetCenterColor(unpack(AP.Colors.bg))
    bg:SetEdgeColor(unpack(AP.Colors.border))
    bg:SetEdgeTexture("", 1, 1, 1)
    bg:SetInsets(1, 1, 1, 1)
    self.trackerBg = bg

    local header = WINDOW_MANAGER:CreateControl("$(parent)Header", f, CT_CONTROL)
    header:SetDimensions(WIDTH, HEADER_H)
    header:SetAnchor(TOPLEFT, f, TOPLEFT, 0, 0)
    self.header = header

    local headerBg = WINDOW_MANAGER:CreateControl("$(parent)HBg", header, CT_BACKDROP)
    headerBg:SetAnchorFill(header)
    headerBg:SetCenterColor(unpack(AP.Colors.bgHeader))
    headerBg:SetEdgeColor(0, 0, 0, 0)
    self.headerBg = headerBg

    local counter = WINDOW_MANAGER:CreateControl("$(parent)Counter", header, CT_LABEL)
    counter:SetFont("ZoFontGameSmall")
    counter:SetColor(unpack(AP.Colors.textDim))
    counter:SetText("0/0")
    counter:SetAnchor(LEFT, header, LEFT, PADDING, 0)
    self.counterLabel = counter

    local hint = WINDOW_MANAGER:CreateControl("$(parent)Hint", header, CT_LABEL)
    hint:SetFont("ZoFontGameSmall")
    hint:SetColor(unpack(AP.Colors.textDim))
    hint:SetText("[T]")
    hint:SetAnchor(LEFT, counter, RIGHT, 8, 0)
    hint:SetMouseEnabled(true)
    hint:SetHandler("OnMouseUp", function() if AP.Tracker then AP.Tracker:CycleNext() end end)
    hint:SetHandler("OnMouseEnter", function() hint:SetColor(unpack(AP.Colors.accent)) end)
    hint:SetHandler("OnMouseExit", function() hint:SetColor(unpack(AP.Colors.textDim)) end)
    self.cycleHint = hint

    -- Close (right)
    local closeBtn = WINDOW_MANAGER:CreateControl("$(parent)Close", header, CT_LABEL)
    closeBtn:SetFont("ZoFontWinH5")
    closeBtn:SetColor(unpack(AP.Colors.textDim))
    closeBtn:SetText("×")
    closeBtn:SetMouseEnabled(true)
    closeBtn:SetAnchor(RIGHT, header, RIGHT, -PADDING, 0)
    closeBtn:SetHandler("OnMouseUp", function() self:SetTrackerVisible(false) end)
    closeBtn:SetHandler("OnMouseEnter", function() closeBtn:SetColor(unpack(AP.Colors.danger)) end)
    closeBtn:SetHandler("OnMouseExit", function() closeBtn:SetColor(unpack(AP.Colors.textDim)) end)
    self.closeBtn = closeBtn

    -- Abandon (where Travel was) — left of close
    local abandonBtn = WINDOW_MANAGER:CreateControl("$(parent)AbandonHdr", header, CT_LABEL)
    abandonBtn:SetFont("ZoFontGameSmall")
    abandonBtn:SetColor(unpack(AP.Colors.textDim))
    abandonBtn:SetText(AP.L("BTN_ABANDON") or "Abandon")
    abandonBtn:SetMouseEnabled(true)
    abandonBtn:SetAnchor(RIGHT, closeBtn, LEFT, -10, 0)
    abandonBtn:SetHandler("OnMouseUp", function()
        local d = AP.Tracker and AP.Tracker:GetFocusedQuestData()
        if d then AP.Tracker:AbandonQuest(d.index) end
    end)
    abandonBtn:SetHandler("OnMouseEnter", function() abandonBtn:SetColor(unpack(AP.Colors.danger)) end)
    abandonBtn:SetHandler("OnMouseExit", function() abandonBtn:SetColor(unpack(AP.Colors.textDim)) end)
    self.abandonBtn = abandonBtn

    -- Map — in front of Abandon
    local mapBtn = WINDOW_MANAGER:CreateControl("$(parent)MapHdr", header, CT_LABEL)
    mapBtn:SetFont("ZoFontGameSmall")
    mapBtn:SetColor(unpack(AP.Colors.textDim))
    mapBtn:SetText(AP.L("BTN_MAP") or "Map")
    mapBtn:SetMouseEnabled(true)
    mapBtn:SetAnchor(RIGHT, abandonBtn, LEFT, -10, 0)
    mapBtn:SetHandler("OnMouseUp", function()
        local d = AP.Tracker and AP.Tracker:GetFocusedQuestData()
        if d then AP.Tracker:ShowQuestOnMap(d.index) end
    end)
    mapBtn:SetHandler("OnMouseEnter", function() mapBtn:SetColor(unpack(AP.Colors.accent)) end)
    mapBtn:SetHandler("OnMouseExit", function() mapBtn:SetColor(unpack(AP.Colors.textDim)) end)
    self.mapBtn = mapBtn

    local content = WINDOW_MANAGER:CreateControl("$(parent)Content", f, CT_CONTROL)
    content:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 4)
    content:SetAnchor(BOTTOMRIGHT, f, BOTTOMRIGHT, -2, -4)
    self.trackerContent = content

    local nameLabel = WINDOW_MANAGER:CreateControl("$(parent)QName", content, CT_LABEL)
    nameLabel:SetFont("ZoFontWinH4")
    nameLabel:SetColor(unpack(AP.Colors.accent))
    nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    nameLabel:SetMaxLineCount(1)
    nameLabel:SetAnchor(TOPLEFT, content, TOPLEFT, PADDING, 2)
    nameLabel:SetDimensions(WIDTH - PADDING * 2, 20)
    self.questNameLabel = nameLabel

    local zoneLabel = WINDOW_MANAGER:CreateControl("$(parent)QZone", content, CT_LABEL)
    zoneLabel:SetFont("ZoFontGameSmall")
    zoneLabel:SetColor(unpack(AP.Colors.textDim))
    zoneLabel:SetAnchor(TOPLEFT, nameLabel, BOTTOMLEFT, 0, 2)
    zoneLabel:SetDimensions(WIDTH - PADDING * 2, 16)
    self.questZoneLabel = zoneLabel

    local descLabel = WINDOW_MANAGER:CreateControl("$(parent)QDesc", content, CT_LABEL)
    descLabel:SetHidden(true)
    descLabel:SetDimensions(1, 1)
    self.questDescLabel = descLabel

    local stepLabel = WINDOW_MANAGER:CreateControl("$(parent)QStep", content, CT_LABEL)
    stepLabel:SetFont("ZoFontGameSmall")
    stepLabel:SetColor(unpack(AP.Colors.incomplete))
    stepLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    stepLabel:SetMaxLineCount(8)
    stepLabel:SetAnchor(TOPLEFT, zoneLabel, BOTTOMLEFT, 0, 4)
    stepLabel:SetDimensions(WIDTH - PADDING * 2, 120)
    self.questStepLabel = stepLabel

    -- no bottom actions row (moved to header)
    self.actionsRow = nil

    self.trackerFrame = f
end

function UI:RebuildQuestList()
    if not self.questNameLabel then return end

    local data = AP.Tracker and AP.Tracker:GetFocusedQuestData()
    local contentW = WIDTH - PADDING * 2

    -- Apply fonts & colors from settings
    local titleFont = AP.SafeFont and AP.SafeFont(AP.sv.titleFont) or (AP.sv.titleFont or "ZoFontWinH4")
    local stepFont  = AP.SafeFont and AP.SafeFont(AP.sv.stepFont) or (AP.sv.stepFont or "ZoFontGameSmall")
    local titleCol  = AP.sv.titleColor or AP.Colors.accent
    local stepCol   = AP.sv.stepColor or AP.Colors.incomplete

    self.questNameLabel:SetFont(titleFont)
    self.questNameLabel:SetColor(titleCol[1], titleCol[2], titleCol[3], titleCol[4] or 1)
    self.questStepLabel:SetFont(stepFont)
    self.questStepLabel:SetColor(stepCol[1], stepCol[2], stepCol[3], stepCol[4] or 1)
    self.questZoneLabel:SetFont("ZoFontGameSmall")
    self.questZoneLabel:SetColor(unpack(AP.Colors.textDim))

    if not data then
        self.questNameLabel:SetText(AP.L("NO_QUEST") or "No quest")
        self.questZoneLabel:SetText("")
        self.questZoneLabel:SetHidden(true)
        self.questDescLabel:SetText("")
        self.questDescLabel:SetHidden(true)
        self.questStepLabel:SetText("")
        self.counterLabel:SetText("0/0")
        self.trackerFrame:SetHeight(HEADER_H + 50)
        if AP.Tomes then AP.Tomes:Refresh() end
        return
    end

    self.counterLabel:SetText(string.format("%d/%d", data.position or 1, data.count or 1))

    -- Title
    self.questNameLabel:SetDimensions(contentW, 0) -- height auto via wrap
    self.questNameLabel:SetMaxLineCount(2)
    self.questNameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.questNameLabel:SetText(data.name or "")
    local nameH = self.questNameLabel:GetTextHeight()
    if not nameH or nameH < 16 then nameH = 18 end
    if nameH > 40 then nameH = 40 end
    self.questNameLabel:SetHeight(nameH)

    -- Zone
    local zoneLine = data.zone or ""
    self.questZoneLabel:SetText(zoneLine)
    self.questZoneLabel:SetHidden(zoneLine == "")
    local zoneH = (zoneLine ~= "") and 16 or 0

    -- Native-style step text only (short)
    local lines = {}
    if data.stepText and data.stepText ~= "" then
        table.insert(lines, data.stepText)
    end
    if AP.sv.showObjectives ~= false and data.objectives then
        for _, obj in ipairs(data.objectives) do
            local prog = ""
            if obj.max and obj.max > 0 then
                prog = string.format(" (%d/%d)", obj.current, obj.max)
            end
            local mark = obj.complete and "✓ " or "• "
            table.insert(lines, mark .. (obj.text or "") .. prog)
        end
    end
    local stepText = table.concat(lines, "\n")

    self.questDescLabel:SetHidden(true)
    self.questStepLabel:SetHidden(false)
    self.questStepLabel:SetDimensions(contentW, 0)
    self.questStepLabel:SetMaxLineCount(12)
    self.questStepLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.questStepLabel:SetText(stepText)

    local stepH = self.questStepLabel:GetTextHeight()
    if not stepH or stepH < 14 then
        stepH = math.max(14, (#lines) * 15)
    end
    -- Cap so it never blows the screen, but grow with content
    if stepH > 180 then stepH = 180 end
    self.questStepLabel:SetHeight(stepH)

    -- Re-anchor content stack tightly
    self.questNameLabel:ClearAnchors()
    self.questNameLabel:SetAnchor(TOPLEFT, self.trackerContent, TOPLEFT, PADDING, 2)

    self.questZoneLabel:ClearAnchors()
    self.questZoneLabel:SetAnchor(TOPLEFT, self.questNameLabel, BOTTOMLEFT, 0, 2)

    self.questStepLabel:ClearAnchors()
    if zoneLine ~= "" then
        self.questStepLabel:SetAnchor(TOPLEFT, self.questZoneLabel, BOTTOMLEFT, 0, 4)
    else
        self.questStepLabel:SetAnchor(TOPLEFT, self.questNameLabel, BOTTOMLEFT, 0, 4)
    end

    local h = HEADER_H + 8 + nameH + (zoneH > 0 and (zoneH + 2) or 0) + 4 + stepH + 12
    if h < 70 then h = 70 end
    if h > 280 then h = 280 end
    self.trackerFrame:SetHeight(h)
    self.trackerFrame:SetWidth(WIDTH)
    if AP.Tomes then AP.Tomes:Refresh() end
end

function UI:CreateTravelFrame()
    local f = WINDOW_MANAGER:CreateTopLevelWindow("AetherPathTravel")
    f:SetDimensions(WIDTH + 20, 360)
    f:SetMovable(true)
    f:SetMouseEnabled(true)
    f:SetClampedToScreen(true)
    f:SetHidden(true)
    f:SetDrawLayer(DL_CONTROLS)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)Bg", f, CT_BACKDROP)
    bg:SetAnchorFill(f)
    bg:SetCenterColor(unpack(AP.Colors.bg))
    bg:SetEdgeColor(unpack(AP.Colors.border))
    bg:SetEdgeTexture("", 1, 1, 1)

    local header = WINDOW_MANAGER:CreateControl("$(parent)Header", f, CT_CONTROL)
    header:SetDimensions(WIDTH + 20, HEADER_H)
    header:SetAnchor(TOPLEFT, f, TOPLEFT, 0, 0)

    local headerBg = WINDOW_MANAGER:CreateControl("$(parent)HBg", header, CT_BACKDROP)
    headerBg:SetAnchorFill(header)
    headerBg:SetCenterColor(unpack(AP.Colors.bgHeader))
    headerBg:SetEdgeColor(0, 0, 0, 0)

    local title = WINDOW_MANAGER:CreateControl("$(parent)Title", header, CT_LABEL)
    title:SetFont("ZoFontWinH5")
    title:SetColor(unpack(AP.Colors.accent))
    title:SetText(AP.L("TRAVEL_TITLE"))
    title:SetAnchor(LEFT, header, LEFT, PADDING, 0)

    local closeBtn = WINDOW_MANAGER:CreateControl("$(parent)Close", header, CT_LABEL)
    closeBtn:SetFont("ZoFontWinH5")
    closeBtn:SetColor(unpack(AP.Colors.textDim))
    closeBtn:SetText("×")
    closeBtn:SetMouseEnabled(true)
    closeBtn:SetAnchor(RIGHT, header, RIGHT, -PADDING, 0)
    closeBtn:SetHandler("OnMouseUp", function() f:SetHidden(true) end)

    local scroll = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Scroll", f, "ZO_ScrollContainer")
    scroll:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 2)
    scroll:SetAnchor(BOTTOMRIGHT, f, BOTTOMRIGHT, -2, -2)
    self.travelScroll = scroll
    self.travelContent = scroll:GetNamedChild("ScrollChild") or scroll
    self.travelRows = {}

    self.travelFrame = f
end

function UI:RefreshTravelList()
    if not self.travelContent then return end
    for _, row in ipairs(self.travelRows or {}) do
        row:SetHidden(true)
    end
    self.travelRows = {}

    AP.Travel:RefreshNodes()
    local nodes = AP.Travel:GetNodes()
    local y = 4
    local ROW_HEIGHT = 22

    for _, node in ipairs(nodes) do
        local row = self:CreateTravelRow(node, y)
        y = y + ROW_HEIGHT + 2
        table.insert(self.travelRows, row)
    end
end

function UI:CreateTravelRow(node, y)
    local ROW_HEIGHT = 22
    local row = WINDOW_MANAGER:CreateControl(nil, self.travelContent, CT_CONTROL)
    row:SetDimensions(WIDTH, ROW_HEIGHT)
    row:SetAnchor(TOPLEFT, self.travelContent, TOPLEFT, 4, y)
    row:SetMouseEnabled(true)

    local star = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    star:SetFont("ZoFontGameSmall")
    star:SetColor(unpack(node.favorite and AP.Colors.favorite or AP.Colors.textDim))
    star:SetText(node.favorite and "★" or "☆")
    star:SetMouseEnabled(true)
    star:SetAnchor(LEFT, row, LEFT, 2, 0)
    star:SetHandler("OnMouseUp", function() AP.Travel:ToggleFavorite(node.index) end)

    local nameLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    nameLabel:SetFont("ZoFontGameSmall")
    nameLabel:SetColor(unpack(AP.Colors.text))
    nameLabel:SetText(node.name)
    nameLabel:SetAnchor(LEFT, star, RIGHT, 6, 0)
    nameLabel:SetDimensions(WIDTH - 100, ROW_HEIGHT)
    nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    nameLabel:SetMouseEnabled(true)
    nameLabel:SetHandler("OnMouseUp", function() AP.Travel:TravelTo(node.index) end)
    nameLabel:SetHandler("OnMouseEnter", function() nameLabel:SetColor(unpack(AP.Colors.accent)) end)
    nameLabel:SetHandler("OnMouseExit", function() nameLabel:SetColor(unpack(AP.Colors.text)) end)

    local costLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    costLabel:SetFont("ZoFontGameSmall")
    costLabel:SetColor(unpack(AP.Colors.textDim))
    costLabel:SetText(AP.FormatCost(node.cost))
    costLabel:SetAnchor(RIGHT, row, RIGHT, -4, 0)

    return row
end

-------------------------------------------------
-- Helpers
-------------------------------------------------

function UI:ApplyTheme()
    local c = AP.Colors
    if self.trackerBg then
        local a = (AP.sv and AP.sv.trackerAlpha) or 0.94
        self.trackerBg:SetCenterColor(c.bg[1], c.bg[2], c.bg[3], a)
        self.trackerBg:SetEdgeColor(unpack(c.border))
    end
    if self.headerBg then
        self.headerBg:SetCenterColor(unpack(c.bgHeader))
    end
    if self.counterLabel then self.counterLabel:SetColor(unpack(c.textDim)) end
    if self.cycleHint then self.cycleHint:SetColor(unpack(c.textDim)) end
    if self.closeBtn then self.closeBtn:SetColor(unpack(c.textDim)) end
    if self.mapBtn then self.mapBtn:SetColor(unpack(c.textDim)) end
    if self.abandonBtn then self.abandonBtn:SetColor(unpack(c.textDim)) end
    if self.questNameLabel then
        local tc = (AP.sv and AP.sv.titleColor) or c.accent
        self.questNameLabel:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
        if AP.sv and AP.sv.titleFont then self.questNameLabel:SetFont(AP.sv.titleFont) end
    end
    if self.questStepLabel then
        local sc = (AP.sv and AP.sv.stepColor) or c.incomplete
        self.questStepLabel:SetColor(sc[1], sc[2], sc[3], sc[4] or 1)
        if AP.sv and AP.sv.stepFont then self.questStepLabel:SetFont(AP.sv.stepFont) end
    end
    if self.questZoneLabel then self.questZoneLabel:SetColor(unpack(c.textDim)) end
    if AP.Tomes and AP.Tomes.ApplyTheme then AP.Tomes:ApplyTheme() end
end

function UI:ApplyPosition()
    local pos = AP.sv and AP.sv.position
    local x, y = 40, 120
    if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
        x, y = pos.x, pos.y
        -- sanity clamp to screen
        local sw = GuiRoot and GuiRoot:GetWidth() or 1920
        local sh = GuiRoot and GuiRoot:GetHeight() or 1080
        if x < -200 then x = 40 end
        if y < -200 then y = 120 end
        if x > sw - 50 then x = sw - 50 end
        if y > sh - 50 then y = sh - 50 end
    else
        if AP.sv then
            AP.sv.position = { point = TOPLEFT, relPoint = TOPLEFT, x = x, y = y }
        end
    end
    self.trackerFrame:ClearAnchors()
    self.trackerFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

function UI:SavePosition()
    if not self.trackerFrame or not AP.sv then return end
    local left = self.trackerFrame:GetLeft()
    local top  = self.trackerFrame:GetTop()
    if type(left) == "number" and type(top) == "number" then
        AP.sv.position = {
            point    = TOPLEFT,
            relPoint = TOPLEFT,
            x        = left,
            y        = top,
        }
    end
end

function UI:ApplyScale()
    local s = AP.sv.trackerScale or 1
    self.trackerFrame:SetScale(s)
end

function UI:ApplyAlpha()
    local a = AP.sv.trackerAlpha or 0.94
    if self.trackerBg then
        local c = AP.Colors.bg
        self.trackerBg:SetCenterColor(c[1], c[2], c[3], a)
    end
    -- Tomes panel uses the same trackerAlpha; keep in sync with the slider
    if AP.Tomes and AP.Tomes.ApplyTheme then
        AP.Tomes:ApplyTheme()
    end
end

function UI:ApplyLock()
    local locked = AP.sv.trackerLocked
    self.trackerFrame:SetMovable(not locked)
end

function UI:SetTrackerVisible(visible)
    if not visible and self.SavePosition then
        self:SavePosition()
    end
    AP.sv.showTracker = visible
    if self.trackerFragment and self.trackerFragment.SetHiddenForReason then
        self.trackerFragment:SetHiddenForReason("UserToggle", not visible)
    end
    -- Only unhide if HUD is showing
    local show = visible
    if show and SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene then
        local scene = SCENE_MANAGER:GetCurrentScene()
        local name = scene and scene.GetName and scene:GetName() or ""
        if name ~= "" and name ~= "hud" and name ~= "hudui" then
            show = false
        end
    end
    self.trackerFrame:SetHidden(not show)
    if AP.Tracker then
        AP.Tracker:HideNativeTracker(visible)
    end
end

function UI:ToggleTracker()
    self:SetTrackerVisible(self.trackerFrame:IsHidden())
end

function UI:ToggleTravel()
    local hidden = self.travelFrame:IsHidden()
    if hidden then
        self:RefreshTravelList()
        self.travelFrame:ClearAnchors()
        self.travelFrame:SetAnchor(TOPLEFT, self.trackerFrame, TOPRIGHT, 8, 0)
    end
    self.travelFrame:SetHidden(not hidden)
end

function UI:RefreshAll()
    if AP.Tracker then AP.Tracker:Refresh() end
    if self.travelFrame and not self.travelFrame:IsHidden() then
        self:RefreshTravelList()
    end
end
