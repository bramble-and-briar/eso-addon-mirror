VerticalBuffsDebuffs = {}
VerticalBuffsDebuffs.name = "VerticalBuffsDebuffs"
VerticalBuffsDebuffs.savedVariables = nil
VerticalBuffsDebuffs.previewBuffs = false
VerticalBuffsDebuffs.previewDebuffs = false

VerticalBuffsDebuffs.defaults = {
    buffPosX           = 680,
    buffPosY           = 600,
    debuffPosX         = 1470,
    debuffPosY         = 600,
    buffSize           = 31,
    debuffSize         = 31,
    showBuffs          = true,
    showDebuffs        = true,
    showBuffText       = true,
    showDebuffText     = true,
    buffCap            = 0,
    debuffCap          = 0,
}

VerticalBuffsDebuffs.capChoices = {
    { name = "All", value = 0  },
    { name = "5",   value = 5  },
    { name = "10",  value = 10 },
    { name = "15",  value = 15 },
    { name = "20",  value = 20 },
}

local activeBuffs   = {}
local activeDebuffs = {}

local buffBoxes   = {}
local debuffBoxes = {}

local boxCounter = 0

local fontCache   = {}
local numberFonts = {}
local timerTexts  = {}
local entryPool   = {}
local buffList    = {}
local debuffList  = {}
local previewList = nil

local SIDE_MARGIN    = 8
local BOX_GAP        = 6
local RING_PAD       = 10
local FRAME_PAD      = 14
local MAX_EFFECTS    = 30
local SHOW_THRESHOLD = 60

local NAME_SCALE     = 26 / 31

local PERMANENT_MS   = 3600000

local ICON_CATEGORY = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_buffsAndDebuffs.dds"
local ICON_SETTINGS = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_settings.dds"

local SAVED_ACCOUNT_TIP   = "Account wide: the same on all your characters."
local SAVED_CHARACTER_TIP = "Per character: set separately on each of your characters."
local PREVIEW_TIP         = "Shows it on screen so you can place it. Stays on until you turn it off."

local FRAME_GREY = { r = 0.55, g = 0.55, b = 0.55 }

local RAINBOW_PALETTE = { "FF2222", "FF9900", "FFEE00", "33DD33", "00CCCC", "3399FF", "BB44EE" }

local WINDOW_DEFAULTS = {
    settingsFontSize       = 30,
    settingsOpacity        = 100,
    settingsHighlight      = "Alliance",
    settingsHighlightColor = { r = 1, g = 1, b = 1, a = 1 },
    settingsRemember       = true,
}

local ORANGE_THRESHOLD = 0.50
local RED_THRESHOLD    = 0.25

local PREVIEW_EFFECTS = {
    { name = "Major Sorcery",   duration = 20, elapsed = 2,  icon = "/esoui/art/icons/ability_mage_022.dds" },
    { name = "Minor Brutality", duration = 20, elapsed = 8,  icon = "/esoui/art/icons/ability_warrior_003.dds" },
    { name = "Major Resolve",   duration = 20, elapsed = 12, icon = "/esoui/art/icons/ability_armor_002.dds" },
    { name = "Minor Endurance", duration = 20, elapsed = 16, icon = "/esoui/art/icons/ability_rogue_051.dds" },
    { name = "Major Fortitude", duration = 20, elapsed = 18, icon = "/esoui/art/icons/ability_healer_012.dds" },
}

--------------------------------------------------
-- Timer Color (percentage based)
--------------------------------------------------
local function GetTimerColor(remaining, totalDuration)
    if totalDuration <= 0 then
        return 0.2, 1.0, 0.2
    end

    local pct = remaining / totalDuration

    if pct <= RED_THRESHOLD then
        return 1.0, 0.2, 0.2
    elseif pct <= ORANGE_THRESHOLD then
        return 1.0, 0.55, 0.0
    else
        return 0.2, 1.0, 0.2
    end
end

--------------------------------------------------
-- Font / Size
--------------------------------------------------
function VerticalBuffsDebuffs:GetFont(size)
    local font = fontCache[size]
    if not font then
        font = string.format("EsoUI/Common/Fonts/univers67.otf|%d|soft-shadow-thick", size)
        fontCache[size] = font
    end
    return font
end

function VerticalBuffsDebuffs:GetNumberFont(iconSize)
    local font = numberFonts[iconSize]
    if not font then
        font = string.format(
            "EsoUI/Common/Fonts/univers67.otf|%d|outline",
            math.max(12, math.floor(iconSize * 0.5))
        )
        numberFonts[iconSize] = font
    end
    return font
end

local function GetTimerText(remaining)
    local tenths = math.floor(remaining * 10)
    if tenths < 0 then tenths = 0 end

    local text = timerTexts[tenths]
    if not text then
        text = string.format("%.1f", tenths / 10)
        timerTexts[tenths] = text
    end
    return text
end

function VerticalBuffsDebuffs:GetNameFontSize(size)
    return math.max(10, math.floor(size * NAME_SCALE))
end

function VerticalBuffsDebuffs:GetIconSize(size)
    return math.floor(size * 1.60)
end

function VerticalBuffsDebuffs:GetPanelSize(isDebuff)
    if isDebuff then
        return self.savedVariables.debuffSize
    end
    return self.savedVariables.buffSize
end

function VerticalBuffsDebuffs:GetPanelCap(isDebuff)
    if isDebuff then
        return self.savedVariables.debuffCap or 0
    end
    return self.savedVariables.buffCap or 0
end

function VerticalBuffsDebuffs:GetPanelShowText(isDebuff)
    if isDebuff then
        return self.savedVariables.showDebuffText
    end
    return self.savedVariables.showBuffText
end

--------------------------------------------------
-- Apply Panel Positions
--------------------------------------------------
function VerticalBuffsDebuffs:ApplyBuffPosition()
    self.buffPanel:ClearAnchors()
    self.buffPanel:SetAnchor(
        TOPLEFT, GuiRoot, TOPLEFT,
        self.savedVariables.buffPosX,
        self.savedVariables.buffPosY
    )
end

function VerticalBuffsDebuffs:ApplyDebuffPosition()
    self.debuffPanel:ClearAnchors()
    self.debuffPanel:SetAnchor(
        TOPLEFT, GuiRoot, TOPLEFT,
        self.savedVariables.debuffPosX,
        self.savedVariables.debuffPosY
    )
end

--------------------------------------------------
-- Create Panels
--------------------------------------------------
function VerticalBuffsDebuffs:CreatePanels()
    self.buffPanel = WINDOW_MANAGER:CreateTopLevelWindow("VerticalBuffsDebuffs_BuffPanel")
    self.buffPanel:SetClampedToScreen(true)
    self.buffPanel:SetDrawLayer(DL_BACKGROUND)
    self.buffPanel:SetDrawTier(DT_LOW)
    self.buffPanel:SetHidden(true)
    self:ApplyBuffPosition()

    self.debuffPanel = WINDOW_MANAGER:CreateTopLevelWindow("VerticalBuffsDebuffs_DebuffPanel")
    self.debuffPanel:SetClampedToScreen(true)
    self.debuffPanel:SetDrawLayer(DL_BACKGROUND)
    self.debuffPanel:SetDrawTier(DT_LOW)
    self.debuffPanel:SetHidden(true)
    self:ApplyDebuffPosition()
end

--------------------------------------------------
-- Create Effect Box
--------------------------------------------------
function VerticalBuffsDebuffs:CreateEffectBox(parent)
    boxCounter = boxCounter + 1

    local box = WINDOW_MANAGER:CreateControlFromVirtual(
        "VerticalBuffsDebuffs_Box" .. boxCounter,
        parent,
        "VerticalBuffsDebuffs_EffectBox"
    )

    box.frame     = box:GetNamedChild("Frame")
    box.radial    = box:GetNamedChild("Radial")
    box.inner     = box:GetNamedChild("Inner")
    box.icon      = box:GetNamedChild("Icon")
    box.number    = box:GetNamedChild("Number")
    box.nameLabel = box:GetNamedChild("Name")

    box.cdKey = nil
    box.cdEnd = 0

    box:SetHidden(true)
    return box
end

--------------------------------------------------
-- Size Effect Box
--------------------------------------------------
function VerticalBuffsDebuffs:SizeBox(box, iconSize, nameFont)
    local frameSize = iconSize + FRAME_PAD

    if box.sizedFor ~= iconSize then
        local ringSize = iconSize + RING_PAD

        box:SetDimensions(frameSize, frameSize)
        box.frame:SetDimensions(frameSize, frameSize)
        box.radial:SetDimensions(ringSize, ringSize)
        box.inner:SetDimensions(iconSize, iconSize)
        box.icon:SetDimensions(iconSize, iconSize)
        box.number:SetDimensions(iconSize, iconSize)
        box.number:SetFont(self:GetNumberFont(iconSize))

        box.sizedFor = iconSize
    end

    if box.sizedFont ~= nameFont then
        box.nameLabel:SetFont(nameFont)
        box.sizedFont = nameFont
    end

    return frameSize
end

--------------------------------------------------
-- Build Box Pools
--------------------------------------------------
function VerticalBuffsDebuffs:BuildBoxPools()
    for _, box in ipairs(buffBoxes) do
        box:SetHidden(true)
        box:ClearAnchors()
        box:SetParent(nil)
    end
    for _, box in ipairs(debuffBoxes) do
        box:SetHidden(true)
        box:ClearAnchors()
        box:SetParent(nil)
    end

    buffBoxes   = {}
    debuffBoxes = {}

    for i = 1, MAX_EFFECTS do
        buffBoxes[i]   = self:CreateEffectBox(self.buffPanel)
        debuffBoxes[i] = self:CreateEffectBox(self.debuffPanel)
    end
end

--------------------------------------------------
-- Render Box Pool
--------------------------------------------------
function VerticalBuffsDebuffs:RenderBoxes(boxPool, effectsList, isDebuff)
    local ringR, ringG, ringB = 0.2, 1.0, 0.2
    if isDebuff then
        ringR, ringG, ringB = 1.0, 0.2, 0.2
    end

    local now = GetGameTimeSeconds()

    local panelSize = self:GetPanelSize(isDebuff)
    local nameSize  = self:GetNameFontSize(panelSize)
    local fullFont  = self:GetFont(nameSize)
    local fullIcon  = self:GetIconSize(panelSize)

    local showText      = self:GetPanelShowText(isDebuff)
    local cap           = self:GetPanelCap(isDebuff)

    local visible = 0
    local yOffset = 0

    for i, box in ipairs(boxPool) do
        local entry = effectsList[i]
        if cap > 0 and i > cap then
            entry = nil
        end
        if entry then
            local frameSize = self:SizeBox(box, fullIcon, fullFont)

            box:ClearAnchors()
            box:SetAnchor(TOPLEFT, box:GetParent(), TOPLEFT, SIDE_MARGIN, yOffset)

            if entry.fx.icon then
                box.icon:SetTexture(entry.fx.icon)
                box.icon:SetHidden(false)
            else
                box.icon:SetHidden(true)
            end

            box.radial:SetFillColor(ringR, ringG, ringB, 1)

            if box.cdSlot ~= entry.slot or box.cdStamp ~= entry.stamp or now >= box.cdExpire then
                box.cdSlot  = entry.slot
                box.cdStamp = entry.stamp
                if entry.fx.isPermanent then
                    box.cdExpire = now + (PERMANENT_MS / 1000)
                    box.radial:StartCooldown(PERMANENT_MS, PERMANENT_MS, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
                else
                    local remainingMs = math.max(entry.remaining, 0) * 1000
                    local totalMs     = math.max(entry.fx.totalDuration, entry.remaining) * 1000
                    box.cdExpire = now + math.max(entry.remaining, 0)
                    box.radial:StartCooldown(remainingMs, totalMs, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
                end
            end

            if entry.fx.isPermanent then
                box.number:SetText("∞")
                box.number:SetColor(ringR, ringG, ringB, 1)
            else
                box.number:SetText(GetTimerText(entry.remaining))
                local tr, tg, tb = GetTimerColor(entry.remaining, entry.fx.totalDuration)
                box.number:SetColor(tr, tg, tb, 1)
            end

            if showText then
                box.nameLabel:SetText(entry.fx.name)
                box.nameLabel:SetColor(ringR, ringG, ringB, 1)
                box.nameLabel:SetHidden(false)
            else
                box.nameLabel:SetHidden(true)
            end

            box:SetHidden(false)
            visible = visible + 1
            yOffset = yOffset + frameSize + BOX_GAP
        else
            box.cdSlot   = nil
            box.cdStamp  = nil
            box.cdExpire = 0
            box:SetHidden(true)
        end
    end

    return visible, yOffset
end

--------------------------------------------------
-- Refresh Display
--------------------------------------------------
local function SortByRemaining(a, b)
    return a.remaining < b.remaining
end

local function GetPreviewList()
    if not previewList then
        previewList = {}
        for i, fx in ipairs(PREVIEW_EFFECTS) do
            previewList[i] = {
                remaining = fx.duration - fx.elapsed,
                slot      = -i,
                stamp     = fx.duration,
                fx = {
                    name          = fx.name,
                    icon          = fx.icon,
                    isPermanent   = false,
                    totalDuration = fx.duration,
                },
            }
        end
    end
    return previewList
end

local function BuildActiveList(source, now, list)
    for i = #list, 1, -1 do
        entryPool[#entryPool + 1] = list[i]
        list[i] = nil
    end

    local count = 0
    for slot, fx in pairs(source) do
        local remaining = fx.endTime - now
        if remaining > 0 and remaining <= SHOW_THRESHOLD then
            local pooled = #entryPool
            local entry
            if pooled > 0 then
                entry = entryPool[pooled]
                entryPool[pooled] = nil
            else
                entry = {}
            end

            entry.remaining = remaining
            entry.slot      = slot
            entry.stamp     = fx.endTime
            entry.fx        = fx

            count = count + 1
            list[count] = entry
        end
    end

    table.sort(list, SortByRemaining)
    return list
end

function VerticalBuffsDebuffs:RefreshDisplay()
    local now = GetGameTimeSeconds()

    local buffsToShow
    if self.previewBuffs then
        buffsToShow = GetPreviewList()
    else
        buffsToShow = BuildActiveList(activeBuffs, now, buffList)
    end

    local debuffsToShow
    if self.previewDebuffs then
        debuffsToShow = GetPreviewList()
    else
        debuffsToShow = BuildActiveList(activeDebuffs, now, debuffList)
    end

    local buffVisible,   buffHeight   = self:RenderBoxes(buffBoxes,   buffsToShow,   false)
    local debuffVisible, debuffHeight = self:RenderBoxes(debuffBoxes, debuffsToShow, true)

    local showBuffs   = self.savedVariables.showBuffs   or self.previewBuffs
    local showDebuffs = self.savedVariables.showDebuffs or self.previewDebuffs

    self.buffPanel:SetHidden(not showBuffs or buffVisible == 0)
    if showBuffs and buffVisible > 0 then
        self.buffPanel:SetDimensions(400, buffHeight)
    end

    self.debuffPanel:SetHidden(not showDebuffs or debuffVisible == 0)
    if showDebuffs and debuffVisible > 0 then
        self.debuffPanel:SetDimensions(400, debuffHeight)
    end
end

--------------------------------------------------
-- EVENT_EFFECT_CHANGED Handler
--------------------------------------------------
function VerticalBuffsDebuffs:OnEffectChanged(eventCode, changeType, effectSlot, effectName,
    unitTag, beginTime, endTime, stackCount, iconName, buffType,
    effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceUnitType)

    if unitTag ~= "player" then return end

    local isPermanent   = (endTime == 0)
    local totalDuration = endTime - beginTime

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        local entry = {
            name          = effectName,
            icon          = iconName,
            endTime       = endTime,
            isPermanent   = isPermanent,
            totalDuration = totalDuration,
        }
        if effectType == BUFF_EFFECT_TYPE_DEBUFF then
            activeDebuffs[effectSlot] = entry
            activeBuffs[effectSlot]   = nil
        else
            activeBuffs[effectSlot]   = entry
            activeDebuffs[effectSlot] = nil
        end

    elseif changeType == EFFECT_RESULT_FADED then
        activeBuffs[effectSlot]   = nil
        activeDebuffs[effectSlot] = nil
    end
end

--------------------------------------------------
-- Initial Effect Scan
--------------------------------------------------
function VerticalBuffsDebuffs:ScanExistingEffects()
    local numEffects = GetNumBuffs("player")

    if numEffects > 0 then
        activeBuffs   = {}
        activeDebuffs = {}
    end

    for i = 1, numEffects do
        local name, startTime, endTime, buffSlot, stackCount, iconName, buffType, effectType =
            GetUnitBuffInfo("player", i)
        if name and name ~= "" then
            local isPermanent   = (endTime == 0)
            local totalDuration = endTime - startTime
            local entry = {
                name          = name,
                icon          = iconName,
                endTime       = endTime,
                isPermanent   = isPermanent,
                totalDuration = totalDuration,
            }
            local slot = buffSlot or i
            if effectType == BUFF_EFFECT_TYPE_DEBUFF then
                activeDebuffs[slot] = entry
                activeBuffs[slot]   = nil
            else
                activeBuffs[slot]   = entry
                activeDebuffs[slot] = nil
            end
        end
    end
end

--------------------------------------------------
-- Scene Handling
--------------------------------------------------
function VerticalBuffsDebuffs:InitializeSceneHiding()

    local function OnSceneStateChange(oldState, newState)
        if newState == SCENE_SHOWING then
            VerticalBuffsDebuffs.buffPanel:SetHidden(true)
            VerticalBuffsDebuffs.debuffPanel:SetHidden(true)
        elseif newState == SCENE_HIDDEN then
            VerticalBuffsDebuffs:RefreshDisplay()
        end
    end

    if SCENE_MANAGER:GetScene("worldMap") then
        SCENE_MANAGER:GetScene("worldMap"):RegisterCallback("StateChange", OnSceneStateChange)
    end

    if SCENE_MANAGER:GetScene("gameMenuInGame") then
        SCENE_MANAGER:GetScene("gameMenuInGame"):RegisterCallback("StateChange", OnSceneStateChange)
    end

end

--------------------------------------------------
-- Profile
--------------------------------------------------
function VerticalBuffsDebuffs:GetAccountProfile()
    if not self.accountVars then
        self.accountVars = ZO_SavedVars:NewAccountWide(
            "VerticalBuffsDebuffs_SavedVars",
            2,
            nil,
            self.defaults
        )
    end
    return self.accountVars
end

function VerticalBuffsDebuffs:GetCharacterProfile()
    if not self.characterVars then
        self.characterVars = ZO_SavedVars:NewCharacterIdSettings(
            "VerticalBuffsDebuffs_SavedVars",
            2,
            nil,
            self.defaults
        )
    end
    return self.characterVars
end

function VerticalBuffsDebuffs:GetToggleVars()
    if not self.toggleVars then
        self.toggleVars = ZO_SavedVars:NewCharacterIdSettings(
            "VerticalBuffsDebuffs_SavedVars",
            2,
            "CharacterToggle",
            {}
        )
        if self.toggleVars.useCharacterSettings == nil then
            self.toggleVars.useCharacterSettings = self.profileVars and self.profileVars.useCharacterSettings == true
        end
    end
    return self.toggleVars
end

function VerticalBuffsDebuffs:UsesCharacterSettings()
    return self:GetToggleVars().useCharacterSettings == true
end

function VerticalBuffsDebuffs:SeedCharacterProfile(account, character)
    for key in pairs(self.defaults) do
        character[key] = account[key]
    end
    character.seeded = true
end

function VerticalBuffsDebuffs:MigrateProfile(sv)
    if sv.fontSize then
        sv.buffSize   = sv.fontSize
        sv.debuffSize = sv.fontSize
        sv.fontSize   = nil
    end
end

function VerticalBuffsDebuffs:LoadProfile()
    local account = self:GetAccountProfile()
    self:MigrateProfile(account)

    if self:UsesCharacterSettings() then
        local character = self:GetCharacterProfile()
        self:MigrateProfile(character)

        if not character.seeded then
            self:SeedCharacterProfile(account, character)
        end

        self.savedVariables = character
    else
        self.savedVariables = account
    end
end

function VerticalBuffsDebuffs:SetUseCharacterSettings(value)
    value = value == true
    local toggle = self:GetToggleVars()
    if (toggle.useCharacterSettings == true) == value then return end

    toggle.useCharacterSettings = value
    self:LoadProfile()

    self:ApplyBuffPosition()
    self:ApplyDebuffPosition()
    self:RefreshDisplay()

    local panel = self.settingsPanel
    if panel and panel.Refresh then
        panel:Refresh()
    end
end

--------------------------------------------------
-- Settings Window
--------------------------------------------------
local function RainbowText(text)
    local out = {}
    local idx = 1
    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch == " " then
            out[#out + 1] = ch
        else
            local color = RAINBOW_PALETTE[((idx - 1) % #RAINBOW_PALETTE) + 1]
            out[#out + 1] = "|c" .. color .. ch .. "|r"
            idx = idx + 1
        end
    end
    return table.concat(out)
end

local function PanelCall(method)
    local panel = VerticalBuffsDebuffs.settingsPanel
    if panel and panel[method] then panel[method](panel) end
end

local function LayoutTip()
    if VerticalBuffsDebuffs.profileVars and VerticalBuffsDebuffs:UsesCharacterSettings() then
        return SAVED_CHARACTER_TIP
    end
    return SAVED_ACCOUNT_TIP
end

--------------------------------------------------
-- Reset
--------------------------------------------------
function VerticalBuffsDebuffs:ResetSettings()
    if not self.savedVariables then return end

    for key, value in pairs(self.defaults) do
        self.savedVariables[key] = value
    end

    local profile = self.profileVars
    if profile then
        for key, value in pairs(WINDOW_DEFAULTS) do
            if type(value) == "table" then
                local copy = {}
                for k, v in pairs(value) do copy[k] = v end
                profile[key] = copy
            else
                profile[key] = value
            end
        end
        profile.settingsLastPage = nil
    end

    self.previewBuffs   = false
    self.previewDebuffs = false
    self:ApplyBuffPosition()
    self:ApplyDebuffPosition()
    self:RefreshDisplay()

    PanelCall("ApplyTextSize")
    PanelCall("ApplyOpacity")
    PanelCall("ApplyAccent")
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function VerticalBuffsDebuffs:PanelMenu(isDebuff)
    local prefix  = isDebuff and "debuff" or "buff"
    local posX    = prefix .. "PosX"
    local posY    = prefix .. "PosY"
    local size    = prefix .. "Size"
    local cap     = prefix .. "Cap"
    local shown   = isDebuff and "showDebuffs" or "showBuffs"
    local text    = isDebuff and "showDebuffText" or "showBuffText"
    local preview = isDebuff and "previewDebuffs" or "previewBuffs"
    local noun    = isDebuff and "debuff" or "buff"
    local Noun    = isDebuff and "Debuff" or "Buff"

    local screenW, screenH = GuiRoot:GetDimensions()
    screenW = math.floor(tonumber(screenW) or 1920)
    screenH = math.floor(tonumber(screenH) or 1080)

    local function ApplyPosition()
        if isDebuff then self:ApplyDebuffPosition() else self:ApplyBuffPosition() end
    end

    return {
        type    = "submenu",
        name    = isDebuff and "|cFF3333Debuffs|r" or "|c33FF33Buffs|r",
        icon    = ICON_CATEGORY,
        tooltip = LayoutTip,
        options = {
            {
                type    = "toggle",
                name    = "Preview",
                tooltip = PREVIEW_TIP,
                getFunc = function() return self[preview] == true end,
                setFunc = function(val)
                    self[preview] = val
                    self:RefreshDisplay()
                end,
            },
            {
                type    = "toggle",
                name    = "Enabled",
                preset  = "YES_NO",
                default = self.defaults[shown],
                getFunc = function() return self.savedVariables[shown] end,
                setFunc = function(val)
                    self.savedVariables[shown] = val
                    self:RefreshDisplay()
                end,
            },
            {
                type    = "toggle",
                name    = "Text",
                preset  = "SHOW_HIDE",
                default = self.defaults[text],
                getFunc = function() return self.savedVariables[text] end,
                setFunc = function(val)
                    self.savedVariables[text] = val
                    self:RefreshDisplay()
                end,
            },
            {
                type    = "slider",
                name    = "Size",
                min     = 18, max = 60, step = 1,
                default = self.defaults[size],
                tooltip = "Default is " .. self.defaults[size] .. ".",
                getFunc = function() return self.savedVariables[size] end,
                setFunc = function(val)
                    self.savedVariables[size] = val
                    self:RefreshDisplay()
                end,
            },
            {
                type    = "dropdown",
                name    = "Cap At",
                choices = self.capChoices,
                default = 0,
                details = function()
                    local count = tonumber(self.savedVariables[cap]) or 0
                    if count <= 0 then return "Shows every " .. noun .. "." end
                    return string.format("Shows at most %d %ss. %ss past that are hidden.", count, noun, Noun)
                end,
                getFunc = function() return self.savedVariables[cap] end,
                setFunc = function(val)
                    self.savedVariables[cap] = val
                    self:RefreshDisplay()
                end,
            },
            {
                type    = "slider",
                name    = "Horizontal Position",
                min     = 0, max = screenW, step = 5,
                default = self.defaults[posX],
                tooltip = "Default is " .. self.defaults[posX] .. ".",
                getFunc = function() return self.savedVariables[posX] end,
                setFunc = function(val)
                    self.savedVariables[posX] = val
                    ApplyPosition()
                end,
            },
            {
                type    = "slider",
                name    = "Vertical Position",
                min     = 0, max = screenH, step = 5,
                default = self.defaults[posY],
                tooltip = "Default is " .. self.defaults[posY] .. ".",
                getFunc = function() return self.savedVariables[posY] end,
                setFunc = function(val)
                    self.savedVariables[posY] = val
                    ApplyPosition()
                end,
            },
        },
    }
end

function VerticalBuffsDebuffs:SettingsMenu()
    local profile = self.profileVars
    return {
        type    = "submenu",
        name    = "Settings",
        icon    = ICON_SETTINGS,
        tooltip = SAVED_ACCOUNT_TIP .. " Character Settings is set separately on each character.",
        options = {
            {
                type    = "toggle",
                name    = "Character Settings",
                tooltip = "Off uses one layout for the whole account. On gives this character its own layout, copied from the account layout the first time you turn it on.\n\n" .. SAVED_CHARACTER_TIP,
                details = function()
                    if self:UsesCharacterSettings() then
                        return "This character has its own layout."
                    end
                    return "All your characters share one layout."
                end,
                getFunc = function() return self:UsesCharacterSettings() end,
                setFunc = function(val) self:SetUseCharacterSettings(val) end,
            },
            {
                type    = "slider",
                name    = "Font Size",
                min     = 18, max = 44, step = 1,
                default = WINDOW_DEFAULTS.settingsFontSize,
                tooltip = "Default is 30.",
                getFunc = function() return profile.settingsFontSize end,
                setFunc = function(val)
                    profile.settingsFontSize = val
                    PanelCall("ApplyTextSize")
                end,
            },
            {
                type    = "slider",
                name    = "Opacity",
                min     = 0, max = 100, step = 5,
                default = WINDOW_DEFAULTS.settingsOpacity,
                tooltip = "Default is 100.",
                getFunc = function() return profile.settingsOpacity end,
                setFunc = function(val)
                    profile.settingsOpacity = val
                    PanelCall("ApplyOpacity")
                end,
            },
            {
                type         = "stylecolor",
                name         = RainbowText("Highlight / Slider Color"),
                choices      = { "Alliance", "Custom" },
                customValue  = "Custom",
                default      = WINDOW_DEFAULTS.settingsHighlight,
                colorDefault = { r = 1, g = 1, b = 1 },
                details      = function()
                    if profile.settingsHighlight == "Custom" then
                        return "Highlights and sliders use your color."
                    end
                    return "Highlights and sliders use your alliance color."
                end,
                getFunc  = function() return profile.settingsHighlight end,
                setFunc  = function(val)
                    profile.settingsHighlight = val
                    PanelCall("ApplyAccent")
                end,
                getColor = function()
                    local c = profile.settingsHighlightColor
                    if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1 end
                    return 1, 1, 1
                end,
                setColor = function(r, g, b)
                    profile.settingsHighlightColor = { r = r, g = g, b = b, a = 1 }
                    PanelCall("ApplyAccent")
                end,
            },
            {
                type    = "toggle",
                name    = "Remember Last Page",
                preset  = "YES_NO",
                default = WINDOW_DEFAULTS.settingsRemember,
                tooltip = "Reopens the last page where you left off.",
                getFunc = function() return profile.settingsRemember end,
                setFunc = function(val) profile.settingsRemember = val end,
            },
            {
                type       = "button",
                name       = "|cFF3333Reset All|r",
                buttonText = "Reset All",
                tooltip    = "Puts every Vertical Buffs Debuffs setting back to its default.",
                details    = function()
                    if self:UsesCharacterSettings() then
                        return "Resets only this character's layout."
                    end
                    return "Resets the account layout, used by every character with Character Settings off."
                end,
                confirm    = "Reset every Vertical Buffs Debuffs setting to its default? This can't be undone.",
                func       = function() self:ResetSettings() end,
            },
        },
    }
end

function VerticalBuffsDebuffs:CreateSettings()
    local lib = rawget(_G, "LibUser562")
    if not (lib and lib.RegisterSettings) then
        VerticalBuffsDebuffs.settingsUnavailable = true
        return
    end

    local profile = self.profileVars

    local options = {
        self:PanelMenu(false),
        self:PanelMenu(true),
        self:SettingsMenu(),
    }

    self.settingsPanel = lib:RegisterSettings({
        name            = "VerticalBuffsDebuffs",
        placement       = "addons",
        menuTitle       = "Vertical Buffs Debuffs",
        menuIcon        = ICON_CATEGORY,
        title           = "Vertical Buffs Debuffs",
        author          = "user562",
        version         = "1.7",
        frameColor      = FRAME_GREY,
        previewControls = function()
            local controls = {}
            if self.buffPanel then controls[#controls + 1] = self.buffPanel end
            if self.debuffPanel then controls[#controls + 1] = self.debuffPanel end
            return controls
        end,
        textSize        = function() return profile.settingsFontSize end,
        windowOpacity   = function() return profile.settingsOpacity end,
        rememberPage    = function() return profile.settingsRemember == true end,
        lastPage        = function()
            if type(profile.settingsLastPage) ~= "table" then profile.settingsLastPage = {} end
            return profile.settingsLastPage
        end,
        accentColor     = function()
            if profile.settingsHighlight ~= "Custom" then return nil end
            local c = profile.settingsHighlightColor
            if type(c) ~= "table" then return nil end
            return c.r or 1, c.g or 1, c.b or 1
        end,
        options         = options,
    })
    if not self.settingsPanel then VerticalBuffsDebuffs.settingsUnavailable = true end
end

--------------------------------------------------
-- Load
--------------------------------------------------
local function OnAddonLoaded(event, addonName)
    if addonName == VerticalBuffsDebuffs.name then

        VerticalBuffsDebuffs.profileVars = ZO_SavedVars:NewAccountWide(
            "VerticalBuffsDebuffs_SavedVars",
            2,
            "Profile",
            WINDOW_DEFAULTS
        )

        VerticalBuffsDebuffs:LoadProfile()

        VerticalBuffsDebuffs:CreatePanels()
        VerticalBuffsDebuffs:BuildBoxPools()
        local settingsOk, settingsErr = pcall(function() VerticalBuffsDebuffs:CreateSettings() end)
        if not settingsOk then
            VerticalBuffsDebuffs.settingsUnavailable = true
            VerticalBuffsDebuffs.settingsError = tostring(settingsErr)
        end

        VerticalBuffsDebuffs:InitializeSceneHiding()

        EVENT_MANAGER:RegisterForEvent(
            VerticalBuffsDebuffs.name,
            EVENT_EFFECT_CHANGED,
            function(...) VerticalBuffsDebuffs:OnEffectChanged(...) end
        )

        EVENT_MANAGER:AddFilterForEvent(
            VerticalBuffsDebuffs.name,
            EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_UNIT_TAG, "player"
        )

        EVENT_MANAGER:RegisterForUpdate(
            VerticalBuffsDebuffs.name,
            100,
            function() VerticalBuffsDebuffs:RefreshDisplay() end
        )

        EVENT_MANAGER:RegisterForEvent(
            VerticalBuffsDebuffs.name,
            EVENT_PLAYER_ACTIVATED,
            function() VerticalBuffsDebuffs:ScanExistingEffects() end
        )

        EVENT_MANAGER:UnregisterForEvent(VerticalBuffsDebuffs.name, EVENT_ADD_ON_LOADED)
    end
end

EVENT_MANAGER:RegisterForEvent(VerticalBuffsDebuffs.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
