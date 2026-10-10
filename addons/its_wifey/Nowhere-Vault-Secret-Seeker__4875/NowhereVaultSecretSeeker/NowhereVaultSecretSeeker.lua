local NVC = NowhereVaultSecretSeeker
NVC.name = "NowhereVaultSecretSeeker"
NVC.version = "1.0.2"
NVC.pinType = "NowhereVaultSecretSeekerPins"

local MAIN_WIDTH = 410
local STRIP_WIDTH = 60
local PANEL_WIDTH = MAIN_WIDTH + STRIP_WIDTH
local PAD = 9
local INNER_WIDTH = MAIN_WIDTH - PAD * 2

local PIN_TEXTURES = {
    blue   = "NowhereVaultSecretSeeker/art/pin_blue.dds",
    bluearea = "NowhereVaultSecretSeeker/art/pin_blue_area.dds",
    red    = "NowhereVaultSecretSeeker/art/pin_red.dds",
    green  = "NowhereVaultSecretSeeker/art/pin_green.dds",
    blue1  = "NowhereVaultSecretSeeker/art/pin_blue_1.dds",
    blue2  = "NowhereVaultSecretSeeker/art/pin_blue_2.dds",
    green1 = "NowhereVaultSecretSeeker/art/pin_green_1.dds",
    green3 = "NowhereVaultSecretSeeker/art/pin_green_3.dds",
    skyshard = "EsoUI/Art/MapPins/skyshard_seen.dds",
    crystal_gold = "NowhereVaultSecretSeeker/art/crystal_gold.dds",
    crystal_blue = "NowhereVaultSecretSeeker/art/crystal_blue.dds",
    crystal_red = "NowhereVaultSecretSeeker/art/crystal_red.dds",
}

local function Msg(text)
    d("|cE5C07B[Secret Seeker]|r " .. tostring(text))
end

local function CurrentRoom()
    local mapId = GetCurrentMapId()
    return mapId, mapId and NVC.rooms[mapId] or nil
end

-- Keep each step on its own line, with explicit word wrapping to prevent
-- CT_LABEL text from overflowing the checklist area on different UI scales.
local function WrapGuideLine(text, limit)
    local result = {}
    local line = ""
    for word in tostring(text or ""):gmatch("%S+") do
        if line == "" then
            line = word
        elseif #line + 1 + #word <= limit then
            line = line .. " " .. word
        else
            result[#result + 1] = line
            line = word
        end
    end
    if line ~= "" then result[#result + 1] = line end
    return table.concat(result, "\n")
end

local function NumberedInstructions(lines)
    local out = {}
    for i, line in ipairs(lines or {}) do
        out[#out + 1] = WrapGuideLine(tostring(i) .. ". " .. tostring(line), 37)
    end
    return table.concat(out, "\n")
end

local function CountWrappedLines(text, charsPerLine)
    text = tostring(text or "")
    charsPerLine = charsPerLine or 52

    local total = 0
    if text == "" then return 1 end

    for line in string.gmatch(text .. "\n", "(.-)\n") do
        local len = string.len(line)
        total = total + math.max(1, math.ceil(len / charsPerLine))
    end

    return math.max(1, total)
end

local function MeasureLabelHeight(label, text, charsPerLine, lineHeight, minimum)
    -- Allow enough temporary height for ESO to measure wrapped text correctly.
    label:SetHeight(2000)

    local measured = 0
    if label.GetTextHeight then
        measured = label:GetTextHeight() or 0
    end

    if label.GetTextDimensions then
        local _, h = label:GetTextDimensions()
        if h and h > measured then measured = h end
    end

    local estimated = CountWrappedLines(text, charsPerLine) * (lineHeight or 20)
    return math.max(minimum or 20, measured, estimated)
end

function NVC:SavePanelPosition()
    if not self.window or not self.sv then return end
    self.sv.left = self.window:GetLeft()
    self.sv.top = self.window:GetTop()
end

function NVC:CreateUI()
    local wm = WINDOW_MANAGER
    local w = wm:CreateTopLevelWindow("NowhereVaultSecretSeekerWindow")
    w:SetDimensions(PANEL_WIDTH, 330)
    w:SetClampedToScreen(true)
    w:SetScale((self.sv.hudSize or 100) / 100)
    w:SetMovable(true)
    w:SetDrawTier(DT_LOW)
    w:SetMouseEnabled(true)
    w:SetHidden(true)

    if self.sv.left and self.sv.top then
        w:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.sv.left, self.sv.top)
    else
        w:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -40, 180)
    end

    w:SetHandler("OnMouseUp", function()
        NVC:SavePanelPosition()
    end)

    local bg = wm:CreateControl(nil, w, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(.015, .015, .015, .97)
    bg:SetEdgeColor(.75, .55, .15, .95)
    bg:SetEdgeTexture("", 1, 1, 1)

    local title = wm:CreateControl(nil, w, CT_LABEL)
    title:SetFont("ZoFontGameBold")
    title:SetText("NOWHERE VAULT: SECRET SEEKER")
    title:SetDimensions(340, 24)

    local hide = wm:CreateControl(nil, w, CT_BUTTON)
    hide:SetDimensions(48, 24)
    hide:SetFont("ZoFontGameSmall")
    hide:SetText("HIDE")
    hide:SetNormalFontColor(.72, .72, .72, 1)
    hide:SetMouseOverFontColor(1, 1, 1, 1)
    hide:SetHandler("OnClicked", function()
        NVC.sv.hidden = true
        NVC:UpdateVisibility()
        Msg("Panel hidden. Type /nvc to show it again.")
    end)

    local room = wm:CreateControl(nil, w, CT_LABEL)
    room:SetFont("ZoFontGameBold")
    room:SetWidth(INNER_WIDTH)

    local secret = wm:CreateControl(nil, w, CT_LABEL)
    secret:SetFont("ZoFontGameBold")
    secret:SetWidth(INNER_WIDTH)

    local prereq = wm:CreateControl(nil, w, CT_LABEL)
    prereq:SetFont("ZoFontGame")
    prereq:SetWidth(INNER_WIDTH - 8)
    prereq:SetColor(1, .72, .24, 1)

    local warning = wm:CreateControl(nil, w, CT_LABEL)
    warning:SetFont("ZoFontGameBold")
    warning:SetWidth(INNER_WIDTH - 8)
    warning:SetColor(1, .35, .25, 1)

    local body = wm:CreateControl(nil, w, CT_LABEL)
    body:SetFont("ZoFontGame")
    body:SetWidth(INNER_WIDTH - 8)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local foot = wm:CreateControl(nil, w, CT_LABEL)
    foot:SetFont("ZoFontGameSmall")
    foot:SetText("Drag to move • /nvc hide/show • Map for pins")
    foot:SetColor(.62, .62, .62, 1)
    foot:SetDimensions(INNER_WIDTH, 20)

    local author = wm:CreateControl(nil, w, CT_LABEL)
    author:SetFont("ZoFontGameSmall")
    author:SetText("WifeyRytic  •  v" .. self.version)
    author:SetColor(.48, .48, .48, 1)
    author:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    author:SetDimensions(145, 20)

    self.window = w
    self.titleLabel = title
    self.hideButton = hide
    self.roomLabel = room
    self.secretLabel = secret
    self.prereqLabel = prereq
    self.warningLabel = warning
    self.bodyLabel = body
    self.footerLabel = foot
    self.authorLabel = author
    self:CreateChecklist()
end

function NVC:LayoutPanel()
    local w = self.window
    local y = 6

    self.titleLabel:ClearAnchors()
    self.titleLabel:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, y)

    self.hideButton:ClearAnchors()
    self.hideButton:SetAnchor(TOPRIGHT, w, TOPLEFT, MAIN_WIDTH - 6, 5)

    y = y + 27

    self.roomLabel:ClearAnchors()
    self.roomLabel:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, y)
    local roomText = self.roomLabel:GetText()
    local roomH = MeasureLabelHeight(self.roomLabel, roomText, 48, 21, 21)
    self.roomLabel:SetHeight(roomH)
    y = y + roomH + 2

    self.secretLabel:ClearAnchors()
    self.secretLabel:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, y)
    local secretText = self.secretLabel:GetText()
    local secretH = MeasureLabelHeight(self.secretLabel, secretText, 55, 21, 22)
    self.secretLabel:SetHeight(secretH)
    y = y + secretH + 2

    if not self.prereqLabel:IsHidden() then
        self.prereqLabel:ClearAnchors()
        self.prereqLabel:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, y)
        local preText = self.prereqLabel:GetText()
        local preH = MeasureLabelHeight(self.prereqLabel, preText, 37, 23, 23)
        self.prereqLabel:SetHeight(preH)
        y = y + preH + 3
    end

    if not self.warningLabel:IsHidden() then
        self.warningLabel:ClearAnchors()
        self.warningLabel:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, y)
        local warnText = self.warningLabel:GetText()
        local warnH = MeasureLabelHeight(self.warningLabel, warnText, 37, 23, 30)
        self.warningLabel:SetHeight(warnH)
        y = y + warnH + 3
    end

    self.bodyLabel:ClearAnchors()
    self.bodyLabel:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, y)
    local bodyText = self.bodyLabel:GetText()
    -- Slightly generous estimate on purpose: full instructions are more important
    -- than saving a few pixels of panel height.
    local bodyH = MeasureLabelHeight(self.bodyLabel, bodyText, 37, 23, 23)
    self.bodyLabel:SetHeight(bodyH)
    y = y + bodyH + 6

    local footerY = y
    self.footerLabel:ClearAnchors()
    self.footerLabel:SetAnchor(TOPLEFT, w, TOPLEFT, PAD, footerY)

    self.authorLabel:ClearAnchors()
    self.authorLabel:SetAnchor(TOPRIGHT, w, TOPLEFT, MAIN_WIDTH - PAD, footerY + 16)

    local finalHeight = math.max(self.checklistHeight or 0, footerY + 38)
    w:SetHeight(finalHeight)
end

function NVC:RefreshLayout()
    self:LayoutPanel()
    zo_callLater(function()
        if NVC.window then NVC:LayoutPanel() end
    end, 50)
    zo_callLater(function()
        if NVC.window then NVC:LayoutPanel() end
    end, 200)
end

function NVC:UpdatePanel()
    local zoneIndex = GetUnitZoneIndex("player")
    local zoneId = zoneIndex and GetZoneId(zoneIndex) or nil
    local mapId, room = CurrentRoom()

    if zoneId ~= self.VAULT_ZONE_ID or self.sv.hidden then
        self:UpdateVisibility()
        return
    end

    self:UpdateVisibility()

    if not room then
        self.roomLabel:SetText("Nowhere Vault")
        self.secretLabel:SetText("Secret guide unavailable for this room")
        self.prereqLabel:SetHidden(true)
        self.warningLabel:SetHidden(true)
        self.bodyLabel:SetText("No room guide data is available here yet.")
        self:RefreshLayout()
        return
    end

    self.roomLabel:SetText(room.name .. "  |  " .. room.wing)
    self.secretLabel:SetText("Secret: " .. tostring(room.secret))

    if room.prerequisite then
        self.prereqLabel:SetHidden(false)
        self.prereqLabel:SetText(
            WrapGuideLine("REQUIRES: " .. room.prerequisite ..
            " — " .. tostring(room.prerequisiteSource or "earlier secret"), 37)
        )
    else
        self.prereqLabel:SetHidden(true)
        self.prereqLabel:SetText("")
    end

    if room.warning then
        self.warningLabel:SetHidden(false)
        self.warningLabel:SetText(WrapGuideLine("WARNING: " .. room.warning, 37))
    else
        self.warningLabel:SetHidden(true)
        self.warningLabel:SetText("")
    end

    local bodyText = NumberedInstructions(room.instructions)
    if room.hint then bodyText = bodyText .. "\n" .. WrapGuideLine(room.hint, 37) end
    self.bodyLabel:SetText(bodyText)
    self:RefreshLayout()
end

function NVC:PinAdd(pinManager)
    local mapId = GetCurrentMapId()
    local room = self.rooms[mapId]
    if not room then return end

    for _, pinData in ipairs(room.pins or {}) do
        pinData.texture = PIN_TEXTURES[pinData.style or "blue"] or PIN_TEXTURES.blue
        pinManager:CreatePin(_G[NVC.pinType], pinData, pinData.x, pinData.y)
    end
end

function NVC:PinTip(pin)
    local _, tag = pin:GetPinTypeAndTag()
    if not tag then return end

    InformationTooltip:AddLine(tag.label or "Nowhere Vault", "ZoFontGameBold")

    if tag.note and tag.note ~= "" then
        InformationTooltip:AddLine(tag.note, "ZoFontGame")
    end

    local style = tostring(tag.style or "blue")
    if style == "skyshard" then
        InformationTooltip:AddLine("SKYSHARD", "ZoFontGameSmall")
    elseif string.find(style, "green", 1, true) then
        InformationTooltip:AddLine("SECRET INTERACTION", "ZoFontGameSmall")
    elseif style == "red" then
        InformationTooltip:AddLine("OPTIONAL SHORTCUT", "ZoFontGameSmall")
    elseif style == "bluearea" then
        InformationTooltip:AddLine("SEARCH THIS AREA", "ZoFontGameSmall")
    else
        InformationTooltip:AddLine("NAVIGATION / POSSIBLE LOCATION", "ZoFontGameSmall")
    end
end

function NVC:RefreshPins()
    if _G[self.pinType] and ZO_WorldMap_RefreshCustomPinsOfType then
        ZO_WorldMap_RefreshCustomPinsOfType(_G[self.pinType])
    end
end

function NVC:SetupPins()
    local layout = {
        level = 55,

        -- Read the texture directly from the pin tag.
        texture = function(self)
            return self.m_PinTag.texture
        end,

        size = 28,
    }

    local tooltip = {
        creator = function(pin) NVC:PinTip(pin) end,
        -- Current ESO WorldMap custom-pin API expects a TOOLTIP_MODE number here.
        -- 1 = INFORMATION. Using the InformationTooltip control itself was why
        -- our creator never displayed on hover.
        tooltip = 1,
        hasTooltip = function(pin) return true end,
    }

    ZO_WorldMap_AddCustomPin(
        self.pinType,
        function(pinManager) NVC:PinAdd(pinManager) end,
        nil,
        layout,
        tooltip
    )

    ZO_WorldMap_SetCustomPinEnabled(_G[self.pinType], true)
    self:RefreshPins()
end

function NVC:PollRoom()
    local zoneIndex = GetUnitZoneIndex("player")
    local zoneId = zoneIndex and GetZoneId(zoneIndex) or nil

    if zoneId ~= self.VAULT_ZONE_ID then
        if self.lastMapId ~= nil then
            self.lastMapId = nil
            self:UpdatePanel()
        end
        return
    end

    local mapId = GetCurrentMapId and GetCurrentMapId() or nil
    if mapId ~= self.lastMapId then
        self.lastMapId = mapId
        self:UpdatePanel()
        self:RefreshPins()
    end
end

-- Manual, persistent character checklist. Never inferred from achievements.
local CHECKLIST = {
    {"gills", "FG", "Watcher Filtration Gills", "Arcanum Wing"},
    {"fungal", "FS", "Fungal Sight", "Arcanum Wing"},
    {"mindspore", "SM", "Subjugating Mindspore", "Arcanum Wing"},
    {"arcanumSeal", "AS", "Arcanum Wing Seal", "Arcanum Wing"},
    {"core", "RC", "Resonating Core", "Lunar Path Wing"},
    {"starsong", "CS", "Cantor's Starsong", "Lunar Path Wing"},
    {"lumen", "AL", "Astralight Lumen", "Lunar Path Wing"},
    {"lunarSeal", "LS", "Lunar Path Wing Seal", "Lunar Path Wing"},
    {"artist", "AT", "Artist's Touch", "Cursed Castle Wing"},
    {"saltwater", "SW", "Carafe of Salt Water", "Cursed Castle Wing"},
    {"vision", "CV", "Connoisseur's Vision", "Cursed Castle Wing"},
    {"castleSeal", "CCS", "Cursed Castle Wing Seal", "Cursed Castle Wing"},
}

function NVC:CreateChecklist()
    local wm, w = WINDOW_MANAGER, self.window
    local divider = wm:CreateControl(nil, w, CT_TEXTURE)
    divider:SetColor(.5, .4, .2, .6)
    divider:SetAnchor(TOPLEFT, w, TOPLEFT, MAIN_WIDTH, 5)
    divider:SetAnchor(BOTTOMLEFT, w, BOTTOMLEFT, MAIN_WIDTH, -5)
    divider:SetWidth(1)
    self.checklistRows = {}
    local y = 7
    for index, entry in ipairs(CHECKLIST) do
        if index == 5 or index == 9 then
            local separator = wm:CreateControl(nil, w, CT_TEXTURE)
            separator:SetColor(.5, .4, .2, .6)
            separator:SetDimensions(STRIP_WIDTH - 10, 1)
            separator:SetAnchor(TOPLEFT, w, TOPLEFT, MAIN_WIDTH + 5, y + 2)
            y = y + 7
        end
        local row = wm:CreateControl(nil, w, CT_BUTTON)
        row:SetDimensions(STRIP_WIDTH - 6, 19)
        row:SetAnchor(TOPLEFT, w, TOPLEFT, MAIN_WIDTH + 3, y)
        row:SetMouseEnabled(true)
        local label = wm:CreateControl(nil, row, CT_LABEL)
        label:SetFont("ZoFontGameSmall")
        label:SetText(entry[2])
        label:SetDimensions(29, 19)
        label:SetAnchor(LEFT, row, LEFT, 1, 0)
        local box = wm:CreateControl(nil, row, CT_BACKDROP)
        box:SetDimensions(13, 13)
        box:SetAnchor(RIGHT, row, RIGHT, -2, 0)
        box:SetCenterColor(.04, .04, .04, 1)
        box:SetEdgeTexture("", 1, 1, 1)
        box:SetEdgeColor(.6, .6, .6, .8)
        local tick = wm:CreateControl(nil, box, CT_TEXTURE)
        tick:SetAnchorFill()
        tick:SetTexture("EsoUI/Art/Buttons/checkbox_checked.dds")
        tick:SetColor(.1, 1, .15, 1)
        local function Refresh()
            local checked = self.characterSV.checked[entry[1]] == true
            tick:SetHidden(not checked)
            if checked then label:SetColor(.1, 1, .15, 1)
            else label:SetColor(.85, .85, .85, 1) end
        end
        row:SetHandler("OnClicked", function()
            self.characterSV.checked[entry[1]] = not self.characterSV.checked[entry[1]]
            Refresh()
        end)
        row:SetHandler("OnMouseEnter", function(control)
            InitializeTooltip(InformationTooltip, control, TOPRIGHT, -5, 0, TOPLEFT)
            InformationTooltip:AddLine(entry[3], "ZoFontGameBold")
            InformationTooltip:AddLine(entry[4], "ZoFontGameSmall")
            InformationTooltip:AddLine("Manual checklist for this character. Click to check/uncheck.", "ZoFontGameSmall")
        end)
        row:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        row:SetHandler("OnHide", function() ClearTooltip(InformationTooltip) end)
        Refresh()
        self.checklistRows[index] = row
        y = y + 19
    end
    self.checklistHeight = y + 7
end

function NVC:UpdateVisibility()
    if not self.hudFragment then return end
    local zoneIndex = GetUnitZoneIndex("player")
    local inVault = zoneIndex and GetZoneId(zoneIndex) == self.VAULT_ZONE_ID
    local overlay = ZO_Dialogs_IsShowingDialog()
        or (SCENE_MANAGER.numTopLevelShown or 0) > 0
        or (SCENE_MANAGER.numRemoteTopLevelShown or 0) > 0
    local hidden = not inVault or self.sv.hidden or IsUnitDead("player") or overlay
    self.hudFragment:SetHiddenForReason("SecretSeekerVisibility", not not hidden, 0, 0)
end

function NVC:SetupVisibility()
    -- Scene fragments are initialized only after EVENT_PLAYER_ACTIVATED, when ESO HUD scenes exist.
    if self.hudFragment then return end
    self.hudFragment = ZO_HUDFadeSceneFragment:New(self.window, 0, 0)
    self:UpdateVisibility()
    HUD_SCENE:AddFragment(self.hudFragment)
    HUD_UI_SCENE:AddFragment(self.hudFragment)
    EVENT_MANAGER:RegisterForEvent(self.name .. "_Death", EVENT_PLAYER_DEAD,
        function() self:UpdateVisibility() end)
    EVENT_MANAGER:RegisterForEvent(self.name .. "_Alive", EVENT_PLAYER_ALIVE,
        function() self:UpdateVisibility() end)
    -- Dialogs/top-level overlays can open without changing scenes.
    EVENT_MANAGER:RegisterForUpdate(self.name .. "_Visibility", 250,
        function() self:UpdateVisibility() end)
end

function NVC:SetupSettings()
    local panelName = self.name .. "Settings"
    LibAddonMenu2:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "Nowhere Vault: Secret Seeker",
        displayName = "Nowhere Vault: Secret Seeker",
        author = "WifeyRytic",
        version = self.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })
    LibAddonMenu2:RegisterOptionControls(panelName, {
        {
            type = "slider",
            name = "HUD size (%)",
            tooltip = "Scale the whole HUD, including the checklist. 100% is the original size. Saved for this account; checklist progress stays per character. Close the menu to see your chosen size.",
            min = 60,
            max = 150,
            step = 5,
            default = 100,
            getFunc = function() return self.sv.hudSize or 100 end,
            setFunc = function(value)
                self.sv.hudSize = math.max(60, math.min(150, tonumber(value) or 100))
                self.window:SetScale(self.sv.hudSize / 100)
                self:RefreshLayout()
            end,
            width = "full",
        },
    })
end

function NVC:Initialize()
    self.sv = ZO_SavedVars:NewAccountWide(
        "NowhereVaultSecretSeekerSavedVars",
        2,
        nil,
        {
            hidden = false,
            hudSize = 100,
            left = nil,
            top = nil,
        }
    )

    self.characterSV = ZO_SavedVars:NewCharacterIdSettings(
        "NowhereVaultSecretSeekerSavedVars", 1, "ManualChecklist", { checked = {} }, GetWorldName()
    )
    self:CreateUI()
    self:SetupSettings()
    self:SetupPins()

    SLASH_COMMANDS["/nvc"] = function()
        NVC.sv.hidden = not NVC.sv.hidden
        NVC:UpdatePanel()
        Msg(NVC.sv.hidden and "Panel hidden." or "Panel shown.")
    end

    EVENT_MANAGER:RegisterForEvent(
        self.name,
        EVENT_PLAYER_ACTIVATED,
        function()
            NVC:SetupVisibility()
            NVC:UpdateVisibility()
            zo_callLater(function()
                NVC.lastMapId = nil
                NVC:PollRoom()
            end, 800)
        end
    )

    EVENT_MANAGER:RegisterForUpdate(
        self.name .. "_RoomPoll",
        1000,
        function() NVC:PollRoom() end
    )

end

local function OnLoad(_, addonName)
    if addonName ~= NVC.name then return end
    EVENT_MANAGER:UnregisterForEvent(NVC.name, EVENT_ADD_ON_LOADED)
    NVC:Initialize()
end

EVENT_MANAGER:RegisterForEvent(NVC.name, EVENT_ADD_ON_LOADED, OnLoad)
