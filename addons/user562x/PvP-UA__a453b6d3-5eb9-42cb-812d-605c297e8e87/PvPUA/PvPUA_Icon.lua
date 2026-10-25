local PvPUA = PvPUA
local U = PvPUA.util
local wm = U.wm
local DC_HEX = U.DC_HEX
local SAVED_CHARACTER_TIP = U.SAVED_CHARACTER_TIP

--------------------------------------------------
-- Player Icon System
--------------------------------------------------
local PI = PvPUA.playerIcon

PI.toplevel = nil
PI.markers  = {}
PI.remote   = {}
PI.running  = false
PI.updateInterval = 10

PI.SIZE_MIN    = 50
PI.SIZE_MAX    = 200
PI.SIZE_STEP   = 5
PI.HEIGHT_MIN  = -1.0
PI.HEIGHT_MAX  = 3.0
PI.HEIGHT_STEP = 0.1
PI.OPACITY_MIN  = 20
PI.OPACITY_MAX  = 100
PI.OPACITY_STEP = 5

local ICON_MARKER_DATA = {
    scaleX = 2,
    scaleY = 2,
    X = 0,
    Y = 3.75,
    Z = 0,
    depthBuffer = false,
}

local function PICreate3D(toplevel, data)
    local marker = wm:CreateControl(nil, toplevel, CT_TEXTURE)

    function marker:updateSize()
        self:Set3DLocalDimensions(self.size.X * self.scale, self.size.Y * self.scale)
    end

    function marker:updateMarkerData(data)
        self.offset = {
            X = data.X or 0,
            Y = data.Y or 0,
            Z = data.Z or 0
        }
        self.size = {
            X = data.scaleX or 1,
            Y = data.scaleY or 1
        }
        self.texture = data.texture or ""

        if data.depthBuffer == nil then self.depthBuffer = true else self.depthBuffer = data.depthBuffer end
        if data.facePlayer == nil then self.facePlayer = true else self.facePlayer = data.facePlayer end

        self:Set3DRenderSpaceUsesDepthBuffer(self.depthBuffer)
        self:SetTexture(self.texture)
        self:updateSize()
    end

    marker.scale = 1
    marker.userOffset = 0

    marker:Create3DRenderSpace()
    marker:SetDrawLevel(1)
    marker:Set3DRenderSpaceOrigin(0, 0, 0)
    marker:updateMarkerData(data)
    marker:SetHidden(true)

    function marker:setPos(X, Y, Z)
        if not self.enabled then return end
        self:turnToFace()
        self:Set3DRenderSpaceOrigin(X + self.offset.X, Y + self.offset.Y + self.userOffset, Z + self.offset.Z)
    end

    function marker:turnToFace()
        if not self.enabled then return end
        if self.facePlayer then
            local heading = GetPlayerCameraHeading()
            if heading > math.pi then
                heading = heading - 2 * math.pi
            end
            self:Set3DRenderSpaceOrientation(0, heading, 0)
        end
    end

    function marker:setColour(r, g, b, a)
        self:SetColor(r, g, b, a)
    end

    function marker:setUserOffset(offset)
        self.userOffset = offset
    end

    function marker:show()
        if self.enabled then
            self:SetTexture(self.texture)
            self:SetHidden(false)
        end
    end
    function marker:hide()
        self:SetTexture("")
        if self.enabled then
            self:SetHidden(true)
        end
    end

    function marker:enable()
        self.enabled = true
    end
    function marker:disable()
        self.enabled = false
        self:SetHidden(true)
        self:SetTexture("")
    end

    function marker:setScale(scale)
        self.scale = scale
        self:updateSize()
    end

    function marker:applyStyle(texture, alpha, sizePct, height)
        if self.styleTexture ~= texture then
            self.styleTexture = texture
            self.texture = texture
            if self.enabled then self:SetTexture(self.texture) end
        end
        if self.styleAlpha ~= alpha then
            self.styleAlpha = alpha
            self:setColour(1, 1, 1, alpha)
        end
        local scale = (sizePct or 100) / 100
        if self.scale ~= scale then
            self:setScale(scale)
        end
        self:setUserOffset(height or 0)
    end

    return marker
end

local function PIListEntry(nameLower)
    local info = PvPUA.constants.userIcons[nameLower]
    if type(info) == "string" then info = { texture = info } end
    return info
end

local function PIRoundOpacity(v)
    v = zo_clamp(tonumber(v) or 100, PI.OPACITY_MIN, PI.OPACITY_MAX)
    return math.floor(v / PI.OPACITY_STEP + 0.5) * PI.OPACITY_STEP
end

local function PIListStyle(nameLower)
    local info = PIListEntry(nameLower)
    if not info or not info.texture then return nil end
    return PvPUA.constants.ICON_DEFAULT, math.floor((info.scale or 1) * 100 + 0.5), info.heightOffset or 0, PIRoundOpacity((info.alpha or 1) * 100)
end

local function PIIconTexture(iconIndex, nameLower)
    local icon = iconIndex and PvPUA.constants.iconChoices[iconIndex]
    if not icon or icon.none then return nil end
    if icon.isDefault then
        local info = nameLower and PIListEntry(nameLower)
        if not info or not info.texture then return nil end
        return info.texture, 1.0
    end
    return icon.texture, icon.alpha or 1.0
end

local function PIMyNameLower()
    local name = GetDisplayName()
    if not name or name == "" then return nil end
    return string.lower(name)
end

local function PIRoundHeight(v)
    v = zo_clamp(tonumber(v) or 0, PI.HEIGHT_MIN, PI.HEIGHT_MAX)
    return math.floor(v * 10 + 0.5) / 10
end

local function PIRoundSize(v)
    v = zo_clamp(tonumber(v) or 100, PI.SIZE_MIN, PI.SIZE_MAX)
    return math.floor(v / PI.SIZE_STEP + 0.5) * PI.SIZE_STEP
end

local function PIIsChoiceAllowedForMe(index)
    local icon = index and PvPUA.constants.iconChoices[index]
    if not icon then return false end
    if icon.isDefault then
        local me = PIMyNameLower()
        local info = me and PIListEntry(me)
        return info ~= nil and info.texture ~= nil
    end
    return true
end

function PI.GetCategoryChoices()
    local list = {}
    for i, category in ipairs(PvPUA.constants.iconCategories) do
        list[i] = { name = category.name, value = category.id }
    end
    return list
end

function PI.GetIconCategory(index)
    local icon = index and PvPUA.constants.iconChoices[index]
    return icon and icon.category or PvPUA.constants.iconCategories[1].id
end

function PI.GetFirstIconInCategory(categoryId)
    for i, icon in ipairs(PvPUA.constants.iconChoices) do
        if icon.category == categoryId and PIIsChoiceAllowedForMe(i) then return i end
    end
    return nil
end

function PI.GetMyCategory()
    return PI.GetIconCategory(PI.GetMyIcon())
end

function PI.RefreshIconMenu()
    zo_callLater(function()
        local panel = PvPUA.settingsPanel
        if panel and panel.Refresh then
            pcall(panel.Refresh, panel)
        end
    end, 1)
end

function PI.SetMyCategory(categoryId)
    if categoryId == PI.GetMyCategory() then return end
    local first = PI.GetFirstIconInCategory(categoryId)
    if not first then return end
    PI.SetMyIcon(first)
    PI.RefreshIconMenu()
end

function PI.BuildPickerChoices(categoryId)
    categoryId = categoryId or PI.GetMyCategory()
    PI.pickerToIndex = {}
    PI.indexToPicker = {}
    local textures = {}
    local me = PIMyNameLower()
    for i, icon in ipairs(PvPUA.constants.iconChoices) do
        if icon.category == categoryId and PIIsChoiceAllowedForMe(i) then
            local texture = icon.texture
            if icon.isDefault then texture = PIIconTexture(i, me) end
            textures[#textures + 1] = texture
            PI.pickerToIndex[#textures] = i
            PI.indexToPicker[i] = #textures
        end
    end
    return textures
end

function PI.GetMyPickerIndex()
    PI.BuildPickerChoices()
    return PI.indexToPicker[PI.GetMyIcon()] or 1
end

function PI.SetMyPickerIndex(pickerIndex)
    PI.BuildPickerChoices()
    local index = PI.pickerToIndex[tonumber(pickerIndex) or 1]
    if index then PI.SetMyIcon(index) end
end

function PI.GetMyDefaults()
    local me = PIMyNameLower()
    local iconIndex, sizePct, height, opacity
    if me then
        iconIndex, sizePct, height, opacity = PIListStyle(me)
    end
    return iconIndex or PvPUA.constants.ICON_NONE, PIRoundSize(sizePct or 100), PIRoundHeight(height or 0), PIRoundOpacity(opacity or 100)
end

function PI.GetMyIcon()
    local cv = PvPUA.charVariables
    local index = cv and tonumber(cv.iconChoice)
    if index and PIIsChoiceAllowedForMe(index) then return index end
    local defaultIndex = PI.GetMyDefaults()
    return defaultIndex
end

function PI.GetMySize()
    local cv = PvPUA.charVariables
    if cv and cv.iconSize ~= nil then return PIRoundSize(cv.iconSize) end
    local _, defaultSize = PI.GetMyDefaults()
    return defaultSize
end

function PI.GetMyHeight()
    local cv = PvPUA.charVariables
    if cv and cv.iconHeight ~= nil then return PIRoundHeight(cv.iconHeight) end
    local _, _, defaultHeight = PI.GetMyDefaults()
    return defaultHeight
end

function PI.OnMyStyleChanged(delay)
    PI.ScheduleGroupRefresh()
    PI.ScheduleBroadcast(delay or 500)
end

function PI.SetMyIcon(index)
    index = tonumber(index)
    if not index or not PIIsChoiceAllowedForMe(index) then return end
    PvPUA.charVariables.iconChoice = index
    PI.OnMyStyleChanged()
end

function PI.SetMySize(v)
    PvPUA.charVariables.iconSize = PIRoundSize(v)
    PI.OnMyStyleChanged(750)
end

function PI.SetMyHeight(v)
    PvPUA.charVariables.iconHeight = PIRoundHeight(v)
    PI.OnMyStyleChanged(750)
end

function PI.GetMyOpacity()
    local cv = PvPUA.charVariables
    if cv and cv.iconOpacity ~= nil then return PIRoundOpacity(cv.iconOpacity) end
    local _, _, _, defaultOpacity = PI.GetMyDefaults()
    return defaultOpacity
end

function PI.SetMyOpacity(v)
    PvPUA.charVariables.iconOpacity = PIRoundOpacity(v)
    PI.OnMyStyleChanged(750)
end

local function PIResolve(unit, nameLower)
    if unit == "player" then
        return PI.GetMyIcon(), PI.GetMySize(), PI.GetMyHeight(), PI.GetMyOpacity()
    end
    local r = PI.remote[nameLower]
    if r then
        return r.icon, r.size, r.height, r.opacity
    end
    return PIListStyle(nameLower)
end

function PI.Init()
    PI.toplevel = wm:CreateTopLevelWindow("PvPUA_PIWin")
    PI.toplevel:SetDrawLayer(0)
end

local function PIGetMarker(nameLower)
    local marker = PI.markers[nameLower]
    if not marker then
        marker = PICreate3D(PI.toplevel, ICON_MARKER_DATA)
        PI.markers[nameLower] = marker
    end
    return marker
end

local PI_SEEN = {}

local function PIShowUnit(unit, nameLower)
    local iconIndex, sizePct, height, opacity = PIResolve(unit, nameLower)
    local texture, alpha = PIIconTexture(iconIndex, nameLower)
    if not texture then return end

    local marker = PIGetMarker(nameLower)
    marker:applyStyle(texture, alpha * (opacity or 100) / 100, sizePct, height)
    if not marker.enabled then
        marker:enable()
        marker:show()
    end
    local _, Xw, Yw, Zw = GetUnitRawWorldPosition(unit)
    local X, Y, Z = WorldPositionToGuiRender3DPosition(Xw, Yw, Zw)
    marker:setPos(X, Y, Z)
    PI_SEEN[nameLower] = true
end

function PI.updateMarker()
    local sv = PvPUA.charVariables
    if not sv or not PI.toplevel then return end

    for k in pairs(PI_SEEN) do PI_SEEN[k] = nil end

    if sv.iconShowSelf then
        local selfName = GetDisplayName()
        if selfName and selfName ~= "" then
            PIShowUnit("player", string.lower(selfName))
        end
    end

    if sv.iconShowOthers and IsUnitGrouped("player") then
        for i = 1, 12 do
            local unit = "group" .. i
            if DoesUnitExist(unit) and IsUnitOnline(unit) and not AreUnitsEqual(unit, "player") then
                local dn = GetUnitDisplayName(unit)
                if dn and dn ~= "" then
                    PIShowUnit(unit, string.lower(dn))
                end
            end
        end
    end

    for nameLower, marker in pairs(PI.markers) do
        if marker.enabled and not PI_SEEN[nameLower] then
            marker:disable()
        end
    end
end

function PI.StartPolling()
    if PI.running then return end
    EVENT_MANAGER:RegisterForUpdate("PvPUA_PlayerIconUpdate", PI.updateInterval, function()
        local ok = pcall(PI.updateMarker)
        if not ok then
            EVENT_MANAGER:UnregisterForUpdate("PvPUA_PlayerIconUpdate")
            PI.running = false
        end
    end)
    PI.running = true
end

function PI.StopPolling()
    if not PI.running then return end
    EVENT_MANAGER:UnregisterForUpdate("PvPUA_PlayerIconUpdate")
    PI.running = false
    for _, marker in pairs(PI.markers) do
        marker:disable()
    end
end

--------------------------------------------------
-- Icon Sharing
--------------------------------------------------
local ICON_PROTOCOL_ID   = 271
local ICON_PROTOCOL_NAME = "PvPUAIconStyle"

local function PIEncodeSize(v)
    return zo_clamp(math.floor((PIRoundSize(v) - PI.SIZE_MIN) / PI.SIZE_STEP + 0.5), 0, 63)
end

local function PIDecodeSize(steps)
    return PIRoundSize(PI.SIZE_MIN + (tonumber(steps) or 10) * PI.SIZE_STEP)
end

local function PIEncodeHeight(v)
    return zo_clamp(math.floor((PIRoundHeight(v) - PI.HEIGHT_MIN) / PI.HEIGHT_STEP + 0.5), 0, 63)
end

local function PIDecodeHeight(steps)
    return PIRoundHeight(PI.HEIGHT_MIN + (tonumber(steps) or 10) * PI.HEIGHT_STEP)
end

local function PIEncodeOpacity(v)
    return zo_clamp(math.floor((PIRoundOpacity(v) - PI.OPACITY_MIN) / PI.OPACITY_STEP + 0.5), 0, 31)
end

local function PIDecodeOpacity(steps)
    return PIRoundOpacity(PI.OPACITY_MIN + (tonumber(steps) or 16) * PI.OPACITY_STEP)
end

function PI.Broadcast(request)
    if not PI.protocol or not IsUnitGrouped("player") then return end
    if not PvPUA.savedVariables or not PvPUA.charVariables then return end
    PI.protocol:Send({
        icon    = PI.GetMyIcon(),
        size    = PIEncodeSize(PI.GetMySize()),
        height  = PIEncodeHeight(PI.GetMyHeight()),
        opacity = PIEncodeOpacity(PI.GetMyOpacity()),
        request = request == true,
    })
end

function PI.ScheduleBroadcast(delay, request)
    if not PI.protocol then return end
    if request then PI.pendingRequest = true end
    EVENT_MANAGER:UnregisterForUpdate("PvPUA_IconBroadcast")
    EVENT_MANAGER:RegisterForUpdate("PvPUA_IconBroadcast", delay or 1000, function()
        EVENT_MANAGER:UnregisterForUpdate("PvPUA_IconBroadcast")
        local wantReply = PI.pendingRequest == true
        PI.pendingRequest = false
        pcall(PI.Broadcast, wantReply)
    end)
end

function PI.PruneRemote()
    if not IsUnitGrouped("player") then
        for k in pairs(PI.remote) do PI.remote[k] = nil end
        return
    end
    local present = {}
    for i = 1, 12 do
        local unit = "group" .. i
        if DoesUnitExist(unit) then
            local dn = GetUnitDisplayName(unit)
            if dn and dn ~= "" then present[string.lower(dn)] = true end
        end
    end
    for nameLower in pairs(PI.remote) do
        if not present[nameLower] then PI.remote[nameLower] = nil end
    end
end

local function PIOnIconData(unitTag, data)
    if type(unitTag) ~= "string" or type(data) ~= "table" then return end
    if not DoesUnitExist(unitTag) or AreUnitsEqual(unitTag, "player") then return end

    local dn = GetUnitDisplayName(unitTag)
    if not dn or dn == "" then return end

    if data.request then
        PI.ScheduleBroadcast(500)
    end

    local iconIndex = tonumber(data.icon)
    if not iconIndex or not PvPUA.constants.iconChoices[iconIndex] then return end

    PI.remote[string.lower(dn)] = {
        icon   = iconIndex,
        size   = PIDecodeSize(data.size),
        height = PIDecodeHeight(data.height),
        opacity = PIDecodeOpacity(data.opacity),
    }
    PI.ScheduleGroupRefresh()
end

local function PIOnGroupChanged()
    PI.PruneRemote()
    PI.ScheduleGroupRefresh()
    PI.ScheduleBroadcast(500)
end

function PI.InitNetwork()
    local LGB = rawget(_G, "LibGroupBroadcast")
    if type(LGB) ~= "table" or type(LGB.RegisterHandler) ~= "function" then return end

    local handler = LGB:RegisterHandler(PvPUA.name, "PvPUAIcon")
    if not handler then return end
    handler:SetDisplayName("PvP UA!")
    handler:SetDescription("Shares your PvPUA icon, size and height with group members.")

    local protocol = handler:DeclareProtocol(ICON_PROTOCOL_ID, ICON_PROTOCOL_NAME)
    protocol:AddField(LGB.CreateNumericField("icon",   { minValue = 0, maxValue = 63, trimValues = true }))
    protocol:AddField(LGB.CreateNumericField("size",   { minValue = 0, maxValue = 63, trimValues = true }))
    protocol:AddField(LGB.CreateNumericField("height", { minValue = 0, maxValue = 63, trimValues = true }))
    protocol:AddField(LGB.CreateNumericField("opacity", { minValue = 0, maxValue = 31, trimValues = true }))
    protocol:AddField(LGB.CreateFlagField("request", { defaultValue = false }))
    protocol:OnData(PIOnIconData)
    protocol:Finalize({ isRelevantInCombat = true, replaceQueuedMessages = true })
    PI.protocol = protocol

    local ns = PvPUA.name .. "_IconNet"
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_PLAYER_ACTIVATED, function()
        PI.PruneRemote()
        PI.ScheduleBroadcast(1000, true)
    end)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_GROUP_MEMBER_JOINED, PIOnGroupChanged)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_GROUP_MEMBER_LEFT, PIOnGroupChanged)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_GROUP_MEMBER_CONNECTED_STATUS, PIOnGroupChanged)
end

--------------------------------------------------
-- Group Frame Icons
--------------------------------------------------
local PI_GROUP_FRAMES_ENABLED = false

local function PIGetGroupFrameIconInfo(unitTag, frameStyle)
    if not PI_GROUP_FRAMES_ENABLED then return nil end
    local sv = PvPUA.charVariables
    if not sv or type(unitTag) ~= "string" then return nil end
    if frameStyle == "ZO_RaidUnitFrame" then
        if not sv.iconShowLargeGroupFrames then return nil end
    elseif not sv.iconShowSmallGroupFrames then
        return nil
    end
    if not string.match(unitTag, "^group%d+$") then return nil end

    local displayName = GetUnitDisplayName(unitTag)
    if not displayName or displayName == "" then return nil end

    local unit = unitTag
    if AreUnitsEqual(unitTag, "player") then
        if not sv.iconShowSelf then return nil end
        unit = "player"
    elseif not sv.iconShowOthers then
        return nil
    end

    local nameLower = string.lower(displayName)
    local iconIndex, _, _, opacity = PIResolve(unit, nameLower)
    local texture, alpha = PIIconTexture(iconIndex, nameLower)
    if not texture then return nil end
    return texture, alpha * (opacity or 100) / 100
end

local function PIUpdateGroupFrameIcon(frame)
    local electionIcon = frame.electionIcon
    if not electionIcon then return end

    local texture, alpha = PIGetGroupFrameIconInfo(frame.unitTag, frame.style)
    if not texture or not electionIcon:IsHidden() then
        if frame.piIcon then
            frame.piIcon:SetHidden(true)
        end
        return
    end

    if not frame.piIcon then
        frame.piIcon = wm:CreateControl(nil, frame.frame, CT_TEXTURE)
        frame.piIcon:SetDrawLayer(DL_OVERLAY)
    end

    local icon = frame.piIcon
    local width, height = electionIcon:GetDimensions()
    icon:ClearAnchors()
    icon:SetAnchor(CENTER, electionIcon, CENTER, 0, 0)
    icon:SetDimensions(width * 2, height * 2)
    icon:SetTexture(texture)
    icon:SetAlpha(alpha or 1.0)
    icon:SetHidden(false)
end

function PI.RefreshGroupFrameIcons()
    if UNIT_FRAMES and UNIT_FRAMES.UpdateNames then
        pcall(UNIT_FRAMES.UpdateNames, UNIT_FRAMES)
    end
end

function PI.ScheduleGroupRefresh()
    EVENT_MANAGER:UnregisterForUpdate("PvPUA_GroupIconRefresh")
    EVENT_MANAGER:RegisterForUpdate("PvPUA_GroupIconRefresh", 100, function()
        EVENT_MANAGER:UnregisterForUpdate("PvPUA_GroupIconRefresh")
        PI.RefreshGroupFrameIcons()
    end)
end

function PI.InitGroupFrameIcons()
    if PI.groupFrameHooked then return end
    if not (ZO_PostHook and ZO_UnitFrameObject and ZO_UnitFrameObject.UpdateName) then return end

    ZO_PostHook(ZO_UnitFrameObject, "UpdateName", function(frame)
        pcall(PIUpdateGroupFrameIcon, frame)
    end)
    ZO_PostHook(ZO_UnitFrameObject, "RefreshElectionIcon", function(frame)
        pcall(PIUpdateGroupFrameIcon, frame)
    end)
    PI.groupFrameHooked = true

    EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_GroupIconsUpdate", EVENT_GROUP_UPDATE, PI.ScheduleGroupRefresh)
    EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_GroupIconsJoined", EVENT_GROUP_MEMBER_JOINED, PI.ScheduleGroupRefresh)
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function PvPUA:IconMenu()
    local myIconDefault, mySizeDefault, myHeightDefault, myOpacityDefault = PI.GetMyDefaults()
    local myCategoryDefault = PI.GetIconCategory(myIconDefault)
    PI.BuildPickerChoices(myCategoryDefault)
    local myPickerDefault = PI.indexToPicker[myIconDefault] or 1
    return { type = "submenu",
          name = "|c" .. DC_HEX .. "Icon|r",
          tooltip = "Sharing icons with group members needs LibGroupBroadcast. Without it, only you see your icon.\n\n"
                 .. SAVED_CHARACTER_TIP,
          icon = "EsoUI/Art/Options/Gamepad/gp_options_nameplates.dds",
          options = {
        { type = "selector",
          name = "Category",
          tooltip = "Pick a category, then choose your icon below.",
          choices = PI.GetCategoryChoices(),
          default = myCategoryDefault,
          getFunc = function() return PI.GetMyCategory() end,
          setFunc = function(categoryId) PI.SetMyCategory(categoryId) end },
        { type = "iconpicker",
          name = "Icon",
          choices = function() return PI.BuildPickerChoices() end,
          default = myPickerDefault,
          getFunc = function() return PI.GetMyPickerIndex() end,
          setFunc = function(index) PI.SetMyPickerIndex(index) end },
        { type = "slider", name = "Size", min = PI.SIZE_MIN, max = PI.SIZE_MAX, step = PI.SIZE_STEP,
          default = mySizeDefault,
          tooltip = "Default is 100.",
          getFunc = function() return PI.GetMySize() end,
          setFunc = function(v) PI.SetMySize(v) end },
        { type = "slider", name = "Height", min = PI.HEIGHT_MIN, max = PI.HEIGHT_MAX, step = PI.HEIGHT_STEP,
          default = myHeightDefault,
          tooltip = "How high your icon sits above your head. Default is " .. string.format("%g", myHeightDefault) .. ".",
          getFunc = function() return PI.GetMyHeight() end,
          setFunc = function(v) PI.SetMyHeight(v) end },
        { type = "slider", name = "Opacity", min = PI.OPACITY_MIN, max = PI.OPACITY_MAX, step = PI.OPACITY_STEP,
          default = myOpacityDefault,
          tooltip = "100 is fully visible. Default is " .. string.format("%g", myOpacityDefault) .. ".",
          getFunc = function() return PI.GetMyOpacity() end,
          setFunc = function(v) PI.SetMyOpacity(v) end },
        { type = "checklist",
          name = "Show",
          noSelectionText = "None",
          choices = {
              { name = "Self",   value = "self" },
              { name = "Others", value = "others" },
              { name = "Small Group Frames - Disabled NEED TO WORK ON IT!", value = "smallGroupFrames" },
              { name = "Large Group Frames - Disabled NEED TO WORK ON IT!", value = "largeGroupFrames" },
          },
          default = { "self", "others" },
          getFunc = function()
              local sv = PvPUA.charVariables
              local sel = {}
              if sv.iconShowSelf then sel[#sel + 1] = "self" end
              if sv.iconShowOthers then sel[#sel + 1] = "others" end
              if PI_GROUP_FRAMES_ENABLED and sv.iconShowSmallGroupFrames then sel[#sel + 1] = "smallGroupFrames" end
              if PI_GROUP_FRAMES_ENABLED and sv.iconShowLargeGroupFrames then sel[#sel + 1] = "largeGroupFrames" end
              return sel
          end,
          setFunc = function(values)
              local on = {}
              if type(values) == "table" then
                  for _, v in ipairs(values) do on[v] = true end
              end
              PvPUA.charVariables.iconShowSelf = on.self == true
              PvPUA.charVariables.iconShowOthers = on.others == true
              PvPUA.charVariables.iconShowSmallGroupFrames = PI_GROUP_FRAMES_ENABLED and on.smallGroupFrames == true
              PvPUA.charVariables.iconShowLargeGroupFrames = PI_GROUP_FRAMES_ENABLED and on.largeGroupFrames == true
              PI.RefreshGroupFrameIcons()
          end },
          } }
end
