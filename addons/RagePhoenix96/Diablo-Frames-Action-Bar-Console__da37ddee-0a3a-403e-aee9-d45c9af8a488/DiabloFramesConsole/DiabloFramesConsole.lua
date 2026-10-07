-- Diablo Frames Console 0.1.3, GPL-3.0-or-later.
-- Original art: Forsion. Original addon: BulDeZir.
-- Gamepad HUD port: native active buttons, event-driven orbs, shared addon settings.
local NAME = "DiabloFramesConsole"
local TEX = NAME .. "/Textures/"
local DFC = { pending = false, originals = {}, backSlots = {}, pools = {}, active = false }
DiabloFramesConsole = DFC
local PRESETS = {
    { name = "Compact", scale = 0.80, bottom = 35 },
    { name = "Standard", scale = 1.00, bottom = 35 },
    { name = "Large", scale = 1.10, bottom = 45 },
}
local DEFAULTS = {
    enabled = true, preset = 2, backBar = true,
    moveBuffs = true, buffX = 0, buffY = 0,
    moveSynergy = true, synergyX = 0, synergyY = 0,
}
local unpack = unpack or table.unpack
local function Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end
local function FormatPower(value)
    if value >= 1000 then return string.format("%.1fk", value / 1000) end
    return tostring(math.floor(value))
end
local function Anchor(control, point, relative, relativePoint, x, y)
    control:ClearAnchors()
    control:SetAnchor(point, relative, relativePoint, x or 0, y or 0)
end
local function Texture(name, parent, file, width, height, level)
    local control = WINDOW_MANAGER:CreateControl(NAME .. name, parent, CT_TEXTURE)
    control:SetDimensions(width, height)
    control:SetTexture(TEX .. file)
    control:SetDrawLayer(DL_BACKGROUND)
    control:SetDrawLevel(level or 1)
    control:SetMouseEnabled(false)
    return control
end
local function Label(name, parent, width, height)
    local control = WINDOW_MANAGER:CreateControl(NAME .. name, parent, CT_LABEL)
    control:SetDimensions(width, height)
    control:SetFont("ZoFontGamepad18")
    control:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetMouseEnabled(false)
    return control
end
-- All native state touched by this addon is recorded and restored on disable.
function DFC:Remember(control)
    if not control or self.originals[control] then return end
    local state = { anchors = {}, scale = control:GetScale() }
    for index = 0, control:GetNumAnchors() - 1 do
        local valid, point, relative, relativePoint, x, y, constraints = control:GetAnchor(index)
        if valid then state.anchors[#state.anchors + 1] = { point, relative, relativePoint, x, y, constraints } end
    end
    self.originals[control] = state
end
function DFC:RestoreNative()
    for control in pairs(self.originals) do self:RestoreControl(control) end
end
function DFC:RestoreControl(control)
    local state = control and self.originals[control]
    if not state then return end
    control:ClearAnchors()
    for _, anchor in ipairs(state.anchors) do control:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5], anchor[6]) end
    control:SetScale(state.scale)
    self.originals[control] = nil
end
local function SynergyContainer()
    return ZO_SynergyTopLevelContainer or (ZO_SynergyTopLevel and ZO_SynergyTopLevel:GetNamedChild("Container"))
end
function DFC:LayoutAuxiliaryControls(preset, scale)
    local hudHeight = preset.bottom + self.root:GetHeight() * scale
    local function Position(control, enabled, x, y, gap)
        if not control then return end
        if not enabled then self:RestoreControl(control); return end
        self:Remember(control)
        local horizontalLimit = math.max(0, GuiRoot:GetWidth() / 2 - 280)
        local offsetX = Clamp(x, -horizontalLimit, horizontalLimit)
        local height = Clamp(hudHeight + gap - y, 72, math.max(72, GuiRoot:GetHeight() - 72))
        Anchor(control, BOTTOM, GuiRoot, BOTTOM, offsetX, -height)
    end
    -- Move the containers only; ESO keeps ownership of icons, timers, visibility and bindings.
    Position(ZO_BuffDebuffTopLevelSelfContainer, self.settings.moveBuffs, self.settings.buffX, self.settings.buffY, 40)
    Position(SynergyContainer(), self.settings.moveSynergy, self.settings.synergyX, self.settings.synergyY, 120)
end
function DFC:CreatePool(name, parent, powerType, left, right, width, offset, color)
    local pool = { powerType = powerType, left = left, right = right, width = width,
        offset = offset or 0, value = -1, maximum = -1 }
    pool.fill = Texture(name .. "Fill", parent, "Smoke.dds", width, 150, 3)
    pool.fill:SetColor(unpack(color))
    pool.label = Label(name .. "Value", parent, 120, 46)
    pool.label:SetFont("ZoFontGamepad34")
    local bubble = Texture(name .. "Bubble", parent, "TooltipBorder.dds", 84, 84, 6)
    Anchor(bubble, CENTER, parent, TOPLEFT, offset == 75 and 150 or 0, -32)
    Anchor(pool.label, CENTER, bubble, CENTER)
    self.pools[powerType] = pool
    return pool
end
function DFC:UpdatePool(powerType, value, maximum)
    local pool = self.pools[powerType]
    if not pool then return end
    value, maximum = math.max(0, value or 0), math.max(0, maximum or 0)
    if pool.value == value and pool.maximum == maximum then return end
    pool.value, pool.maximum = value, maximum
    local fraction = maximum > 0 and Clamp(value / maximum, 0, 1) or 0
    local height = 150 * fraction
    pool.fill:SetHidden(height <= 0)
    pool.fill:SetHeight(math.max(0.01, height))
    pool.fill:SetTextureCoords(pool.left, pool.right, 1 - fraction, 1)
    Anchor(pool.fill, TOPLEFT, pool.parent, TOPLEFT, pool.offset, 150 - height)
    local text = FormatPower(value)
    if pool.text ~= text then pool.label:SetText(text); pool.text = text end
end
function DFC:Build()
    self.root = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "Root")
    self.root:SetDimensions(605, 256)
    self.root:SetMouseEnabled(false)
    self.root:SetHidden(true)
    local middle = Texture("Middle", self.root, "FancyActionBarXpMiddleTest.dds", 605, 256)
    Anchor(middle, BOTTOM, self.root, BOTTOM)
    local left = Texture("Left", self.root, "FancyActionBarXpLeftTest.dds", 256, 256, 2)
    local right = Texture("Right", self.root, "FancyActionBarXpRightTest.dds", 256, 256, 2)
    Anchor(left, BOTTOMRIGHT, middle, BOTTOMLEFT, 77, 0)
    Anchor(right, BOTTOMLEFT, middle, BOTTOMRIGHT, -77, 0)
    local demon = Texture("Demon", self.root, "Demon.dds", 200, 200, 10)
    local angel = Texture("Angel", self.root, "Angel.dds", 200, 200, 10)
    Anchor(demon, BOTTOMRIGHT, left, BOTTOMLEFT, 90, 0)
    Anchor(angel, BOTTOMLEFT, right, BOTTOMRIGHT, -90, 0)
    local function Orb(name, relative, point, relativePoint, x)
        local orb = WINDOW_MANAGER:CreateControl(NAME .. name, self.root, CT_CONTROL)
        orb:SetDimensions(150, 150)
        Anchor(orb, point, relative, relativePoint, x, -16)
        local shade = Texture(name .. "Shade", orb, "Shade.dds", 150, 150, 4)
        local border = Texture(name .. "Border", orb, "border.dds", 166, 166, 7)
        Anchor(shade, CENTER, orb, CENTER)
        Anchor(border, CENTER, orb, CENTER)
        return orb
    end
    local health = Orb("Health", left, BOTTOMLEFT, BOTTOMLEFT, 20)
    local resource = Orb("Resource", right, BOTTOMRIGHT, BOTTOMRIGHT, -20)
    self:CreatePool("Health", health, COMBAT_MECHANIC_FLAGS_HEALTH, 0, 1, 150, 0, { 1, 0.05, 0.05 }).parent = health
    self:CreatePool("Magicka", resource, COMBAT_MECHANIC_FLAGS_MAGICKA, 0, 0.5, 75, 0, { 0, 0.4, 1 }).parent = resource
    self:CreatePool("Stamina", resource, COMBAT_MECHANIC_FLAGS_STAMINA, 0.5, 0, 75, 75, { 0.1, 0.9, 0.1 }).parent = resource
    local split = Texture("Split", resource, "Split.dds", 166, 166, 8)
    Anchor(split, CENTER, resource, CENTER)
    -- Preserve native attribute bars while mounted / transformed (different power types).
    self.barName = Label("BarName", self.root, 320, 24)
    Anchor(self.barName, BOTTOM, self.root, BOTTOM, 0, -186)
    self.line = WINDOW_MANAGER:CreateControl(NAME .. "UltimateLine", self.root, CT_STATUSBAR)
    self.line:SetDimensions(591, 6)
    Anchor(self.line, BOTTOM, self.root, BOTTOM, 0, -165)
    self.line:SetMinMax(0, 1)
    self.line:SetColor(0.73, 0.3, 0.035, 1)
    self.line:SetMouseEnabled(false)
    -- Inactive row is a display only. It never executes abilities or rebinds controls.
    self.backRoot = WINDOW_MANAGER:CreateControl(NAME .. "BackRoot", self.root, CT_CONTROL)
    self.backRoot:SetDimensions(605, 60)
    Anchor(self.backRoot, BOTTOM, self.root, BOTTOM)
    for index = 1, 6 do
        local icon = WINDOW_MANAGER:CreateControl(NAME .. "Back" .. index, self.backRoot, CT_TEXTURE)
        icon:SetDimensions(44, 44)
        icon:SetDrawLayer(DL_CONTROLS)
        icon:SetAlpha(1)
        icon:SetDesaturation(0)
        icon:SetMouseEnabled(false)
        Anchor(icon, BOTTOMLEFT, self.backRoot, BOTTOMLEFT, index <= 5 and 102 + (index - 1) * 74 or 510, -10)
        self.backSlots[index] = icon
    end
    self.fragment = ZO_HUDFadeSceneFragment:New(self.root)
    HUD_SCENE:AddFragment(self.fragment)
    HUD_UI_SCENE:AddFragment(self.fragment)
end
function DFC:RefreshBackBar()
    local category = GetActiveHotbarCategory()
    local normal = category == HOTBAR_CATEGORY_PRIMARY or category == HOTBAR_CATEGORY_BACKUP
    self.backRoot:SetHidden(not (normal and self.settings.backBar))
    self.barName:SetText(category == HOTBAR_CATEGORY_BACKUP and "BACK BAR ACTIVE" or normal and "FRONT BAR ACTIVE" or "SPECIAL BAR ACTIVE")
    if not normal then return end
    local inactive = category == HOTBAR_CATEGORY_PRIMARY and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    for index = 1, 6 do
        local slot = index <= 5 and ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + index or ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
        local texture = GetSlotTexture(slot, inactive)
        local icon = self.backSlots[index]
        icon:SetHidden(not texture or texture == "")
        if texture and texture ~= "" and icon.currentTexture ~= texture then
            icon:SetTexture(texture); icon.currentTexture = texture
        end
    end
end
function DFC:RefreshPowers()
    for powerType in pairs(self.pools) do
        local value, maximum = GetUnitPower("player", powerType)
        self:UpdatePool(powerType, value, maximum)
    end
    self:UpdateUltimate()
end
function DFC:UpdateUltimate()
    local value = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
    local cost = GetSlotAbilityCost(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, COMBAT_MECHANIC_FLAGS_ULTIMATE, GetActiveHotbarCategory())
    self.line:SetValue(cost and cost > 0 and Clamp((value or 0) / cost, 0, 1) or 0)
end
function DFC:RefreshVisibility()
    local transformed = IsPlayerInWerewolfForm and IsPlayerInWerewolfForm() or false
    self.active = self.settings.enabled and IsInGamepadPreferredMode() and not IsMounted() and not transformed
    self.fragment:SetHiddenForReason(NAME, not self.active or IsUnitDead("player"))
    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason(NAME, self.active and not IsUnitDead("player"))
    end
end
-- Reposition existing labels/textures; ESO supplies platform-specific glyphs and bindings.
function DFC:PlacePrompts(button)
    if not button or not button.slot then return end
    if button.buttonText then
        self:Remember(button.buttonText)
        Anchor(button.buttonText, TOP, button.slot, BOTTOM, 0, 3)
    end
    local leftKey = button.leftKey or button.slot:GetNamedChild("LeftKeybind")
    local rightKey = button.rightKey or button.slot:GetNamedChild("RightKeybind")
    if leftKey and rightKey then
        self:Remember(leftKey)
        self:Remember(rightKey)
        leftKey:SetScale(0.7)
        rightKey:SetScale(0.7)
        Anchor(leftKey, TOPRIGHT, button.slot, BOTTOM, -2, 3)
        Anchor(rightKey, TOPLEFT, button.slot, BOTTOM, 2, 3)
    end
end
function DFC:Layout()
    self:RefreshVisibility()
    if not self.active then self:RestoreNative(); return end
    local preset = PRESETS[self.settings.preset] or PRESETS[2]
    local available = GuiRoot:GetWidth() / 1024
    local scale = math.min(preset.scale, available)
    self.root:SetScale(scale)
    Anchor(self.root, BOTTOM, GuiRoot, BOTTOM, 0, -preset.bottom)
    self:LayoutAuxiliaryControls(preset, scale)
    -- Native active bar has its own scene/visibility logic. Keep that intact.
    self:Remember(ZO_ActionBar1)
    ZO_ActionBar1:SetScale(scale)
    Anchor(ZO_ActionBar1, BOTTOM, self.root, BOTTOM, 0, -92)
    for index = 1, 5 do
        local button = ZO_ActionBar_GetButton(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + index)
        if button and button.slot then
            self:Remember(button.slot)
            Anchor(button.slot, BOTTOMLEFT, ZO_ActionBar1, BOTTOMLEFT, 94 + (index - 1) * 74, 0)
            self:PlacePrompts(button)
        end
    end
    local ultimate = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1)
    if ultimate and ultimate.slot then
        self:Remember(ultimate.slot)
        Anchor(ultimate.slot, BOTTOMLEFT, ZO_ActionBar1, BOTTOMLEFT, 504, 0)
        self:PlacePrompts(ultimate)
    end
    local quick = ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if quick and quick.slot then
        self:Remember(quick.slot)
        Anchor(quick.slot, BOTTOMLEFT, ZO_ActionBar1, BOTTOMLEFT, 10, 0)
        self:PlacePrompts(quick)
    end
    local companion = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION)
    if companion and companion.slot then
        self:Remember(companion.slot)
        Anchor(companion.slot, BOTTOMLEFT, ZO_ActionBar1, BOTTOMLEFT, 10, 90)
        self:PlacePrompts(companion)
    end
    -- Native inactive timers follow the active slots and remain native.
    self:RefreshBackBar()
    self:RefreshPowers()
end
function DFC:QueueLayout()
    if self.pending then return end
    self.pending = true
    zo_callLater(function()
        self.pending = false
        self:Layout()
    end, 100)
end
function DFC:ShowSettings()
    local library = LibHarvensAddonSettings
    if self.settingsMenu and library and library.ShowSettingsMenu then
        library.ShowSettingsMenu(self.settingsMenu)
    end
end
function DFC:ResetSettings()
    for key, value in pairs(DEFAULTS) do self.settings[key] = value end
    self:QueueLayout()
    if self.settingsMenu then self.settingsMenu:UpdateControls() end
end
function DFC:ResetPosition(kind)
    local keys = kind == "buff" and { "moveBuffs", "buffX", "buffY" } or { "moveSynergy", "synergyX", "synergyY" }
    for _, key in ipairs(keys) do self.settings[key] = DEFAULTS[key] end
    self:QueueLayout()
    if self.settingsMenu then self.settingsMenu:UpdateControls() end
end
function DFC:BuildSettings()
    if self.settingsMenu then return end
    local library = LibHarvensAddonSettings
    if not library or not library.AddAddon then return end
    local menu = library:AddAddon("Diablo Frames Console", { allowDefaults = false, allowRefresh = true })
    self.settingsMenu = menu
    menu.author = "BulDeZir, Forsion; Console Adaptation Contributors"
    menu.version = "0.1.3"
    local function Checkbox(label, key)
        menu:AddSetting({
            type = library.ST_CHECKBOX, label = label, default = DEFAULTS[key],
            getFunction = function() return self.settings[key] end,
            setFunction = function(value) self.settings[key] = value == true; self:QueueLayout() end,
        })
    end
    local function Offset(label, key, enableKey, low, high)
        menu:AddSetting({
            type = library.ST_SLIDER, label = label, default = DEFAULTS[key],
            min = low, max = high, step = 10, format = "%d", unit = " px",
            getFunction = function() return self.settings[key] end,
            setFunction = function(value)
                self.settings[key] = Clamp(math.floor(tonumber(value) or 0), low, high)
                self:QueueLayout()
            end,
            disable = function() return not self.settings.enabled or not self.settings[enableKey] end,
        })
    end
    Checkbox("Enable Diablo HUD", "enabled")
    local sizes = {}
    for index, preset in ipairs(PRESETS) do sizes[index] = { name = preset.name, preset = index } end
    menu:AddSetting({
        type = library.ST_DROPDOWN, label = "HUD Size", items = sizes, default = PRESETS[DEFAULTS.preset].name,
        getFunction = function() return PRESETS[self.settings.preset].name end,
        setFunction = function(_, name, item)
            for index, preset in ipairs(PRESETS) do
                if (item and item.preset == index) or name == preset.name then
                    self.settings.preset = index; self:QueueLayout(); return
                end
            end
        end,
    })
    Checkbox("Show Inactive Bar", "backBar")
    menu:AddSetting({ type = library.ST_LABEL, label = "Player Buff Bar" })
    Checkbox("Move Player Buff Bar", "moveBuffs")
    Offset("Buff Bar Horizontal Offset", "buffX", "moveBuffs", -600, 600)
    Offset("Buff Bar Vertical Offset", "buffY", "moveBuffs", -400, 400)
    menu:AddSetting({ type = library.ST_BUTTON, label = "Reset Buff Bar Position", clickHandler = function() self:ResetPosition("buff") end })
    menu:AddSetting({ type = library.ST_LABEL, label = "Synergy Prompt" })
    Checkbox("Move Synergy Prompt", "moveSynergy")
    Offset("Synergy Horizontal Offset", "synergyX", "moveSynergy", -600, 600)
    Offset("Synergy Vertical Offset", "synergyY", "moveSynergy", -400, 400)
    menu:AddSetting({ type = library.ST_BUTTON, label = "Reset Synergy Position", clickHandler = function() self:ResetPosition("synergy") end })
    menu:AddSetting({ type = library.ST_BUTTON, label = "Restore All Defaults", clickHandler = function() self:ResetSettings() end })
    SLASH_COMMANDS["/dfc"] = function(command)
        if command == "off" then self.settings.enabled = false; self:QueueLayout()
        elseif command == "on" then self.settings.enabled = true; self:QueueLayout()
        elseif command == "reset" then self:ResetSettings()
        else self:ShowSettings() end
    end
end
function DFC:Initialize()
    self.settings = ZO_SavedVars:NewAccountWide("DiabloFramesConsoleSavedVariables", 1, nil, DEFAULTS)
    self.settings.preset = Clamp(math.floor(tonumber(self.settings.preset) or 2), 1, #PRESETS)
    for _, key in ipairs({ "buffX", "buffY", "synergyX", "synergyY" }) do
        local value = tonumber(self.settings[key]) or 0
        if value ~= value then value = 0 end
        local limit = (key == "buffX" or key == "synergyX") and 600 or 400
        self.settings[key] = Clamp(math.floor(value), -limit, limit)
    end
    self:Build()
    self:BuildSettings()
    local function LayoutEvent() self:QueueLayout() end
    local events = { EVENT_PLAYER_ACTIVATED, EVENT_ADD_ONS_LOADED, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED,
        EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, EVENT_HOTBAR_SLOT_UPDATED,
        EVENT_ACTIVE_COMPANION_STATE_CHANGED, EVENT_SCREEN_RESIZED,
        EVENT_ALL_GUI_SCREENS_RESIZED, EVENT_PLAYER_DEAD, EVENT_PLAYER_ALIVE,
        EVENT_MOUNTED_STATE_CHANGED, EVENT_WEREWOLF_STATE_CHANGED }
    for _, event in ipairs(events) do
        if event then EVENT_MANAGER:RegisterForEvent(NAME, event, LayoutEvent) end
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        -- The native platform style is reapplied by ESO. Do not restore obsolete anchors over it.
        for control, state in pairs(self.originals) do control:SetScale(state.scale) end
        self.originals = {}
        self:QueueLayout()
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_POWER_UPDATE, function(_, _, _, powerType, value, maximum)
        if self.active then
            if powerType == COMBAT_MECHANIC_FLAGS_ULTIMATE then self:UpdateUltimate()
            else self:UpdatePool(powerType, value, maximum) end
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    if EVENT_ULTIMATE_ABILITY_COST_CHANGED then
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ULTIMATE_ABILITY_COST_CHANGED, function() self:UpdateUltimate() end)
    end
    if HUD_MANAGER and HUD_MANAGER.RegisterCallback then
        HUD_MANAGER:RegisterCallback("PropagateSettings", function()
            -- Native resize/style changes establish new restore anchors before our deferred layout.
            if ZO_BuffDebuffTopLevelSelfContainer then self.originals[ZO_BuffDebuffTopLevelSelfContainer] = nil end
            local synergy = SynergyContainer()
            if synergy then self.originals[synergy] = nil end
            self:QueueLayout()
        end)
    end
    self:QueueLayout()
end
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    DFC:Initialize()
end)
