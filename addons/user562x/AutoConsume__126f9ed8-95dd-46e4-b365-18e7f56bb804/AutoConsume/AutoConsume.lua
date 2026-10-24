AutoConsume = {}
AutoConsume.name = "AutoConsume"
AutoConsume.savedVariables = nil
AutoConsume.ready = false

local AC = AutoConsume

local AC_HUD = {
    panel  = nil,
    rows   = {},
    active = {},
}

--------------------------------------------------
-- DEFAULTS
--------------------------------------------------

local DEFAULTS = {
    autoFood    = false,
    foodID      = nil,
    foodMinutes = 10,

    autoXP   = false,
    xpItemID = nil,

    autoAP   = false,
    apItemID = nil,

    bagScanned      = false,

    hudEnabled    = true,
    hudPosX       = 900,
    hudPosY       = 500,
    hudIconSize   = 40,
    hudHorizontal = false,

    settingsFontSize       = 30,
    settingsFont           = "EsoUI/Common/Fonts/FTN57.otf",
    settingsOpacity        = 100,
    settingsHighlight      = "Alliance",
    settingsHighlightColor = { r = 1, g = 1, b = 1, a = 1 },
    settingsRemember       = true,
}

--------------------------------------------------
-- KNOWN BUFF NAMES
--------------------------------------------------
local XP_BUFF_NAMES = {
    "increased experience",
}

local AP_BUFF_NAMES = {
    "alliance skill gain",
}

local XP_ITEM_NAMES = {
    ["psijic ambrosia"]                    = true,
    ["mythic aetherial ambrosia"]          = true,
    ["aetherial ambrosia"]                 = true,
    ["crown experience scroll"]            = true,
    ["major gold coast experience scroll"] = true,
    ["grand gold coast experience scroll"] = true,
    ["experience scroll"]                  = true,
    ["anniversary experience scroll"]      = true,
    ["minor experience scroll"]            = true,
    ["standard experience scroll"]         = true,
    ["major experience scroll"]            = true,
}

local AP_ITEM_NAMES = {
    ["colovian war torte"]                   = true,
    ["molten war torte"]                     = true,
    ["white-gold war torte"]                 = true,
    ["alliance war skill line scroll"]        = true,
    ["alliance war skill line scroll, major"] = true,
    ["alliance war skill line scroll, grand"] = true,
}

--------------------------------------------------
-- TIMER NAMES
--------------------------------------------------
local TIMER_FOOD = "AutoConsume_FoodTimer"
local TIMER_XP   = "AutoConsume_XPTimer"
local TIMER_AP   = "AutoConsume_APTimer"

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function IsPlayerBusy()
    return IsUnitDeadOrReincarnating("player")
        or IsUnitSwimming("player")
        or IsUnitInCombat("player")
end

local function FindItemSlot(itemID)
    if not itemID then return nil end
    for slotId = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if GetItemId(BAG_BACKPACK, slotId) == itemID then
            if CanInteractWithItem(BAG_BACKPACK, slotId) then
                return slotId
            end
        end
    end
    return nil
end

--------------------------------------------------
-- FOOD BUFF ABILITY IDs
--------------------------------------------------
local FOOD_BUFF_ABILITY_IDS = {
    [17407]=true,[17577]=true,[17581]=true,[17608]=true,[17614]=true,
    [61218]=true,[61255]=true,[61257]=true,[61259]=true,[61260]=true,
    [61261]=true,[61294]=true,[61322]=true,[61325]=true,[61328]=true,
    [61335]=true,[61340]=true,[61345]=true,[61350]=true,[66125]=true,
    [66128]=true,[66130]=true,[66132]=true,[66137]=true,[66141]=true,
    [66551]=true,[66568]=true,[66576]=true,[66586]=true,[66590]=true,
    [66594]=true,[68411]=true,[68416]=true,[72816]=true,[72819]=true,
    [72822]=true,[72824]=true,[72956]=true,[72959]=true,[72961]=true,
    [72965]=true,[72968]=true,[72971]=true,[84678]=true,[84681]=true,
    [84700]=true,[84704]=true,[84709]=true,[84720]=true,[84725]=true,
    [84731]=true,[84732]=true,[84733]=true,[84735]=true,[84736]=true,
    [85484]=true,[85497]=true,[86559]=true,[86560]=true,[86673]=true,
    [86674]=true,[86677]=true,[86678]=true,[86746]=true,[86747]=true,
    [86749]=true,[86787]=true,[86789]=true,[86791]=true,[89955]=true,
    [89957]=true,[89971]=true,[92433]=true,[92435]=true,[92437]=true,
    [92474]=true,[92476]=true,[92477]=true,[100488]=true,[100498]=true,
    [100502]=true,[107748]=true,[107789]=true,[127531]=true,[127537]=true,
    [127572]=true,[127578]=true,[127596]=true,[127619]=true,[127736]=true,
    [148633]=true,[267468]=true,
}

local function GetFoodBuffTimeLeft()
    if not AC.savedVariables then return 0 end
    if not AC.savedVariables.foodID then return 0 end
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local buffName, _, timeEnding, _, _, _, effectType, _, abilityType, _, abilityId = GetUnitBuffInfo("player", i)
        if timeEnding and timeEnding > 0 and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then
            if FOOD_BUFF_ABILITY_IDS[abilityId] or abilityType == ABILITY_TYPE_INTERACTIVES then
                return math.max(0, timeEnding - GetGameTimeSeconds())
            end
        end
    end
    return 0
end

local function HasActiveBuff(nameList)
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local buffName, _, timeEnding = GetUnitBuffInfo("player", i)
        if buffName and timeEnding and timeEnding > 0 then
            local lower = buffName:lower()
            for _, match in ipairs(nameList) do
                if lower:find(match, 1, true) then
                    return true, timeEnding
                end
            end
        end
    end
    return false, 0
end

local function Notify(msg)
    d("|cFFFFFF AutoConsume:|r |cFFFF00" .. msg .. "|r")
end

local function GetItemNameByID(itemID)
    if not itemID then return "None" end
    for slotId = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if GetItemId(BAG_BACKPACK, slotId) == itemID then
            local name = GetItemName(BAG_BACKPACK, slotId)
            if name and name ~= "" then return name end
        end
    end
    return "None"
end

--------------------------------------------------
-- BAG SCAN
--------------------------------------------------

local cachedFoodChoices = { "None" }
local cachedFoodVals    = { 0 }
local cachedXPChoices   = { "None" }
local cachedXPVals      = { 0 }
local cachedAPChoices   = { "None" }
local cachedAPVals      = { 0 }

local function ScanBag()
    cachedFoodChoices = { "None" }
    cachedFoodVals    = { 0 }
    cachedXPChoices   = { "None" }
    cachedXPVals      = { 0 }
    cachedAPChoices   = { "None" }
    cachedAPVals      = { 0 }

    local seen = {}
    for slotId = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local id    = GetItemId(BAG_BACKPACK, slotId)
        local name  = GetItemName(BAG_BACKPACK, slotId)
        local itype = GetItemType(BAG_BACKPACK, slotId)
        if id and id ~= 0 and name and name ~= "" and not seen[id] then
            local lower = name:lower()
            if XP_ITEM_NAMES[lower] then
                cachedXPChoices[#cachedXPChoices + 1] = name
                cachedXPVals[#cachedXPVals + 1]       = id
                seen[id] = true
            elseif AP_ITEM_NAMES[lower] then
                cachedAPChoices[#cachedAPChoices + 1] = name
                cachedAPVals[#cachedAPVals + 1]       = id
                seen[id] = true
            elseif itype == ITEMTYPE_FOOD or itype == ITEMTYPE_DRINK then
                cachedFoodChoices[#cachedFoodChoices + 1] = name
                cachedFoodVals[#cachedFoodVals + 1]       = id
                seen[id] = true
            end
        end
    end
end

--------------------------------------------------
-- PENDING SELECTIONS
--------------------------------------------------
local pending = {
    foodID   = nil,
    xpItemID = nil,
    apItemID = nil,
}

local ICON_GENERIC  = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_buffsAndDebuffs.dds"
local ICON_SETTINGS = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_settings.dds"

local SAVED_CHARACTER_TIP = "Per character: set separately on each of your characters."
local PREVIEW_TIP         = "Shows it on screen so you can place it. Stays on until you turn it off."

local FRAME_GREY = { r = 0.55, g = 0.55, b = 0.55 }

local DEFAULT_FONT = "EsoUI/Common/Fonts/FTN57.otf"

local FONT_CHOICES = {
    { name = "Gamepad Medium",  value = "EsoUI/Common/Fonts/FTN57.otf" },
    { name = "Gamepad Bold",    value = "EsoUI/Common/Fonts/FTN87.otf" },
    { name = "Gamepad Light",   value = "EsoUI/Common/Fonts/FTN47.otf" },
    { name = "Univers Regular", value = "EsoUI/Common/Fonts/Univers57.otf" },
    { name = "Univers Light",   value = "EsoUI/Common/Fonts/univers55.otf" },
    { name = "Univers Bold",    value = "EsoUI/Common/Fonts/univers67.otf" },
    { name = "Prose Antique",   value = "EsoUI/Common/Fonts/ProseAntiquePSMT.otf" },
    { name = "Trajan Pro",      value = "EsoUI/Common/Fonts/TrajanPro-Regular.otf" },
    { name = "Handwritten",     value = "EsoUI/Common/Fonts/Handwritten_Bold.otf" },
    { name = "Arial Narrow",    value = "EsoUI/Common/Fonts/arialn.ttf" },
    { name = "Consolas",        value = "EsoUI/Common/Fonts/consola.ttf" },
}

local RAINBOW_PALETTE = { "FF2222", "FF9900", "FFEE00", "33DD33", "00CCCC", "3399FF", "BB44EE" }

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

local function BuildChoices(names, values)
    local out = {}
    for i = 1, #names do
        out[i] = { name = names[i], value = values[i] }
    end
    return out
end

--------------------------------------------------
-- FOOD
--------------------------------------------------

function AC:ForceCheckFood()
    if not AC.savedVariables.autoFood then return end
    if not AC.savedVariables.foodID then return end
    if IsPlayerBusy() then
        zo_callLater(function() AC:ForceCheckFood() end, 3000)
        return
    end
    local slotId = FindItemSlot(AC.savedVariables.foodID)
    if slotId then
        CallSecureProtected("UseItem", BAG_BACKPACK, slotId)
    else
        local secsLeft = GetFoodBuffTimeLeft()
        local minsLeft = secsLeft / 60
        if minsLeft > AC.savedVariables.foodMinutes then
            local recheckMs = math.max(10000, (secsLeft - AC.savedVariables.foodMinutes * 60 - 5) * 1000)
            EVENT_MANAGER:UnregisterForUpdate(TIMER_FOOD)
            EVENT_MANAGER:RegisterForUpdate(TIMER_FOOD, recheckMs, function()
                AC:CheckFood()
            end)
        end
    end
end

function AC:CheckFood()
    if not AC.savedVariables.autoFood then return end
    if not AC.savedVariables.foodID then return end

    local secsLeft = GetFoodBuffTimeLeft()
    local minsLeft = secsLeft / 60

    if minsLeft > AC.savedVariables.foodMinutes then
        local recheckMs = math.max(10000, (secsLeft - AC.savedVariables.foodMinutes * 60 - 5) * 1000)
        EVENT_MANAGER:UnregisterForUpdate(TIMER_FOOD)
        EVENT_MANAGER:RegisterForUpdate(TIMER_FOOD, recheckMs, function()
            AC:CheckFood()
        end)
        return
    end

    if IsPlayerBusy() then
        zo_callLater(function() AC:CheckFood() end, 3000)
        return
    end

    local slotId = FindItemSlot(AC.savedVariables.foodID)
    if slotId then
        CallSecureProtected("UseItem", BAG_BACKPACK, slotId)
    end
end

--------------------------------------------------
-- XP SCROLL
--------------------------------------------------

function AC:CheckXP()
    if not AC.savedVariables.autoXP then return end
    if not AC.savedVariables.xpItemID then return end

    local active = HasActiveBuff(XP_BUFF_NAMES)
    if not active then
        if not IsPlayerBusy() then
            local slotId = FindItemSlot(AC.savedVariables.xpItemID)
            if slotId then
                CallSecureProtected("UseItem", BAG_BACKPACK, slotId)
            end
        end
    end

    EVENT_MANAGER:UnregisterForUpdate(TIMER_XP)
    EVENT_MANAGER:RegisterForUpdate(TIMER_XP, 3000, function()
        AC:CheckXP()
    end)
end

--------------------------------------------------
-- WAR TORTE (AP BOOST)
--------------------------------------------------

function AC:CheckAP()
    if not AC.savedVariables.autoAP then return end
    if not AC.savedVariables.apItemID then return end

    local active = HasActiveBuff(AP_BUFF_NAMES)
    if not active then
        if not IsPlayerBusy() then
            local slotId = FindItemSlot(AC.savedVariables.apItemID)
            if slotId then
                CallSecureProtected("UseItem", BAG_BACKPACK, slotId)
            end
        end
    end

    EVENT_MANAGER:UnregisterForUpdate(TIMER_AP)
    EVENT_MANAGER:RegisterForUpdate(TIMER_AP, 3000, function()
        AC:CheckAP()
    end)
end

--------------------------------------------------
-- CHECK ALL
--------------------------------------------------

function AC:CheckAll()
    if not AC.ready then return end
    zo_callLater(function()
        AC:CheckFood()
        AC:CheckXP()
        AC:CheckAP()
    end, 8000)
end

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

function AC:ScanBagAndReload()
    ScanBag()
    pending.foodID   = AC.savedVariables.foodID
    pending.xpItemID = AC.savedVariables.xpItemID
    pending.apItemID = AC.savedVariables.apItemID
    AC.savedVariables.bagScanned = true
    zo_callLater(function()
        ReloadUI()
    end, 500)
end

local function PanelCall(method)
    local panel = AC.settingsPanel
    if panel and panel[method] then panel[method](panel) end
end

function AC:SettingsMenu()
    return {
        type    = "submenu",
        name    = "Settings",
        icon    = ICON_SETTINGS,
        tooltip = SAVED_CHARACTER_TIP,
        options = {
            {
                type    = "slider",
                name    = "Font Size",
                min     = 18,
                max     = 44,
                step    = 1,
                default = DEFAULTS.settingsFontSize,
                tooltip = "Default is 30.",
                getFunc = function() return AC.savedVariables.settingsFontSize end,
                setFunc = function(val)
                    AC.savedVariables.settingsFontSize = val
                    PanelCall("ApplyTextSize")
                end,
            },
            {
                type    = "dropdown",
                name    = "Font",
                choices = FONT_CHOICES,
                default = DEFAULT_FONT,
                tooltip = "Some fonts look bigger or smaller than others, so you may need to adjust Font Size.\n\nDefault is Gamepad Medium.",
                getFunc = function() return AC.savedVariables.settingsFont end,
                setFunc = function(val)
                    AC.savedVariables.settingsFont = val
                    PanelCall("ApplyFont")
                end,
            },
            {
                type    = "slider",
                name    = "Opacity",
                min     = 0,
                max     = 100,
                step    = 5,
                default = DEFAULTS.settingsOpacity,
                tooltip = "Default is 100.",
                getFunc = function() return AC.savedVariables.settingsOpacity end,
                setFunc = function(val)
                    AC.savedVariables.settingsOpacity = val
                    PanelCall("ApplyOpacity")
                end,
            },
            {
                type         = "stylecolor",
                name         = RainbowText("Highlight / Slider Color"),
                choices      = { "Alliance", "Custom" },
                customValue  = "Custom",
                default      = DEFAULTS.settingsHighlight,
                colorDefault = { r = 1, g = 1, b = 1 },
                details      = function()
                    if AC.savedVariables.settingsHighlight == "Custom" then
                        return "Highlights and sliders use your color."
                    end
                    return "Highlights and sliders use your alliance color."
                end,
                getFunc  = function() return AC.savedVariables.settingsHighlight end,
                setFunc  = function(val)
                    AC.savedVariables.settingsHighlight = val
                    PanelCall("ApplyAccent")
                end,
                getColor = function()
                    local c = AC.savedVariables.settingsHighlightColor
                    if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1 end
                    return 1, 1, 1
                end,
                setColor = function(r, g, b)
                    AC.savedVariables.settingsHighlightColor = { r = r, g = g, b = b, a = 1 }
                    PanelCall("ApplyAccent")
                end,
            },
            {
                type    = "toggle",
                name    = "Remember Last Page",
                preset  = "YES_NO",
                default = DEFAULTS.settingsRemember,
                tooltip = "Reopens the last page where you left off.",
                getFunc = function() return AC.savedVariables.settingsRemember end,
                setFunc = function(val) AC.savedVariables.settingsRemember = val end,
            },
            {
                type       = "button",
                name       = "|cFF3333Reset All|r",
                buttonText = "Reset All",
                tooltip    = "Puts every AutoConsume setting back to its default.",
                confirm    = "Reset every AutoConsume setting to its default? This can't be undone.",
                func       = function() AC:ResetSettings() end,
            },
        },
    }
end

function AC:CreateSettings()
    local lib = rawget(_G, "LibUser562")
    if not (lib and lib.RegisterSettings) then
        AC.settingsUnavailable = true
        return
    end

    ScanBag()

    pending.foodID   = AC.savedVariables.foodID
    pending.xpItemID = AC.savedVariables.xpItemID
    pending.apItemID = AC.savedVariables.apItemID

    local screenW, screenH = GuiRoot:GetDimensions()
    screenW = math.floor(tonumber(screenW) or 1920)
    screenH = math.floor(tonumber(screenH) or 1080)

    local options = {

        {
            type    = "submenu",
            name    = "Food/Drink",
            icon    = ICON_GENERIC,
            tooltip = SAVED_CHARACTER_TIP,
            options = {
                {
                    type    = "toggle",
                    name    = "Auto Consume",
                    default = DEFAULTS.autoFood,
                    getFunc = function() return AC.savedVariables.autoFood end,
                    setFunc = function(val)
                        AC.savedVariables.autoFood = val
                        if val then AC:ForceCheckFood() end
                    end,
                },
                {
                    type    = "slider",
                    name    = "Minutes Left",
                    min     = 1,
                    max     = 30,
                    step    = 1,
                    default = DEFAULTS.foodMinutes,
                    tooltip = "Default is " .. DEFAULTS.foodMinutes .. ".",
                    getFunc = function() return AC.savedVariables.foodMinutes end,
                    setFunc = function(val)
                        AC.savedVariables.foodMinutes = val
                        EVENT_MANAGER:UnregisterForUpdate("AutoConsume_FoodMinsChanged")
                        EVENT_MANAGER:RegisterForUpdate("AutoConsume_FoodMinsChanged", 1000, function()
                            EVENT_MANAGER:UnregisterForUpdate("AutoConsume_FoodMinsChanged")
                            AC:CheckFood()
                        end)
                    end,
                },
                {
                    type    = "dropdown",
                    name    = "Food/Drink",
                    tooltip = "Press Scan Bag first if your item is missing.",
                    choices = BuildChoices(cachedFoodChoices, cachedFoodVals),
                    default = 0,
                    getFunc = function() return pending.foodID or 0 end,
                    setFunc = function(val)
                        pending.foodID = (val == 0) and nil or val
                    end,
                },
                {
                    type       = "button",
                    name       = "|c00FF00Confirm|r",
                    buttonText = "Confirm",
                    func       = function()
                        AC.savedVariables.foodID = pending.foodID
                        Notify("Food/Drink set to: |c00FF00" .. GetItemNameByID(pending.foodID))
                        AC:ForceCheckFood()
                    end,
                },
                {
                    type       = "button",
                    name       = "|cFF8800Scan Bag|r",
                    buttonText = "Scan Bag",
                    tooltip    = "Will ReloadUI",
                    func    = function() AC:ScanBagAndReload() end,
                },
            },
        },

        {
            type    = "submenu",
            name    = "|cE6C800XP Bonus|r",
            icon    = ICON_GENERIC,
            tooltip = SAVED_CHARACTER_TIP,
            options = {
                {
                    type    = "toggle",
                    name    = "Auto Use",
                    default = DEFAULTS.autoXP,
                    getFunc = function() return AC.savedVariables.autoXP end,
                    setFunc = function(val)
                        AC.savedVariables.autoXP = val
                        if val then AC:CheckXP() end
                    end,
                },
                {
                    type    = "dropdown",
                    name    = "XP Item",
                    tooltip = "Press Scan Bag first if your item is missing.",
                    choices = BuildChoices(cachedXPChoices, cachedXPVals),
                    default = 0,
                    getFunc = function() return pending.xpItemID or 0 end,
                    setFunc = function(val)
                        pending.xpItemID = (val == 0) and nil or val
                    end,
                },
                {
                    type       = "button",
                    name       = "|c00FF00Confirm|r",
                    buttonText = "Confirm",
                    func       = function()
                        AC.savedVariables.xpItemID = pending.xpItemID
                        Notify("XP Item set to: |c00FF00" .. GetItemNameByID(pending.xpItemID))
                        AC:CheckXP()
                    end,
                },
                {
                    type       = "button",
                    name       = "|cFF8800Scan Bag|r",
                    buttonText = "Scan Bag",
                    tooltip    = "Will ReloadUI",
                    func    = function() AC:ScanBagAndReload() end,
                },
            },
        },

        {
            type    = "submenu",
            name    = "|c00FF00AP Bonus|r",
            icon    = ICON_GENERIC,
            tooltip = SAVED_CHARACTER_TIP,
            options = {
                {
                    type    = "toggle",
                    name    = "Auto Use",
                    default = DEFAULTS.autoAP,
                    getFunc = function() return AC.savedVariables.autoAP end,
                    setFunc = function(val)
                        AC.savedVariables.autoAP = val
                        if val then AC:CheckAP() end
                    end,
                },
                {
                    type    = "dropdown",
                    name    = "AP Item",
                    tooltip = "Press Scan Bag first if your item is missing.",
                    choices = BuildChoices(cachedAPChoices, cachedAPVals),
                    default = 0,
                    getFunc = function() return pending.apItemID or 0 end,
                    setFunc = function(val)
                        pending.apItemID = (val == 0) and nil or val
                    end,
                },
                {
                    type       = "button",
                    name       = "|c00FF00Confirm|r",
                    buttonText = "Confirm",
                    func       = function()
                        AC.savedVariables.apItemID = pending.apItemID
                        Notify("AP Item set to: |c00FF00" .. GetItemNameByID(pending.apItemID))
                        AC:CheckAP()
                    end,
                },
                {
                    type       = "button",
                    name       = "|cFF8800Scan Bag|r",
                    buttonText = "Scan Bag",
                    tooltip    = "Will ReloadUI",
                    func    = function() AC:ScanBagAndReload() end,
                },
            },
        },

        {
            type    = "submenu",
            name    = "Buff Icons",
            icon    = ICON_GENERIC,
            tooltip = SAVED_CHARACTER_TIP,
            options = {
                {
                    type    = "toggle",
                    name    = "Enabled",
                    preset  = "YES_NO",
                    default = DEFAULTS.hudEnabled,
                    getFunc = function() return AC.savedVariables.hudEnabled end,
                    setFunc = function(val)
                        AC.savedVariables.hudEnabled = val
                        if not val then AC:EndPreview() end
                        if AC_HUD.updateScenes then
                            AC_HUD.updateScenes()
                        elseif AC_HUD.panel then
                            AC_HUD.panel:SetHidden(not val)
                        end
                        AC:HUDRefresh()
                    end,
                },
                {
                    type     = "toggle",
                    name     = "Preview",
                    tooltip  = PREVIEW_TIP,
                    disabled = function() return not AC.savedVariables.hudEnabled end,
                    getFunc  = function() return AC.previewing == true end,
                    setFunc  = function(val)
                        if val then AC:StartPreview() else AC:EndPreview() end
                    end,
                },
                {
                    type    = "dropdown",
                    name    = "Layout",
                    choices = { "Vertical", "Horizontal" },
                    default = "Vertical",
                    getFunc = function() return AC.savedVariables.hudHorizontal and "Horizontal" or "Vertical" end,
                    setFunc = function(val)
                        AC.savedVariables.hudHorizontal = (val == "Horizontal")
                        AC:HUDRefresh()
                    end,
                },
                {
                    type    = "slider",
                    name    = "Size",
                    min     = 20,
                    max     = 100,
                    step    = 2,
                    default = DEFAULTS.hudIconSize,
                    tooltip = "Default is " .. DEFAULTS.hudIconSize .. ".",
                    getFunc = function() return AC.savedVariables.hudIconSize end,
                    setFunc = function(val)
                        AC.savedVariables.hudIconSize = val
                        AC:HUDRefresh()
                    end,
                },
                {
                    type    = "slider",
                    name    = "Horizontal Position",
                    min     = 0,
                    max     = screenW,
                    step    = 5,
                    default = DEFAULTS.hudPosX,
                    tooltip = "Default is " .. DEFAULTS.hudPosX .. ".",
                    getFunc = function() return AC.savedVariables.hudPosX end,
                    setFunc = function(val)
                        AC.savedVariables.hudPosX = val
                        AC:ApplyHUDPosition()
                    end,
                },
                {
                    type    = "slider",
                    name    = "Vertical Position",
                    min     = 0,
                    max     = screenH,
                    step    = 5,
                    default = DEFAULTS.hudPosY,
                    tooltip = "Default is " .. DEFAULTS.hudPosY .. ".",
                    getFunc = function() return AC.savedVariables.hudPosY end,
                    setFunc = function(val)
                        AC.savedVariables.hudPosY = val
                        AC:ApplyHUDPosition()
                    end,
                },
            },
        },

        AC:SettingsMenu(),
    }

    AC.settingsPanel = lib:RegisterSettings({
        name            = "AutoConsume",
        placement       = "addons",
        menuTitle       = "AutoConsume",
        menuIcon        = ICON_GENERIC,
        title           = "AutoConsume",
        author          = "user562",
        version         = "3.5",
        frameColor      = FRAME_GREY,
        previewControls = function()
            if AC_HUD.panel then return { AC_HUD.panel } end
            return {}
        end,
        textSize        = function() return AC.savedVariables.settingsFontSize end,
        textFont        = function()
            local font = AC.savedVariables.settingsFont
            if type(font) ~= "string" or font == "" or font == DEFAULT_FONT then return nil end
            return font
        end,
        windowOpacity   = function() return AC.savedVariables.settingsOpacity end,
        rememberPage    = function() return AC.savedVariables.settingsRemember == true end,
        lastPage        = function()
            local sv = AC.savedVariables
            if type(sv.settingsLastPage) ~= "table" then sv.settingsLastPage = {} end
            return sv.settingsLastPage
        end,
        accentColor     = function()
            local sv = AC.savedVariables
            if sv.settingsHighlight ~= "Custom" then return nil end
            local c = sv.settingsHighlightColor
            if type(c) ~= "table" then return nil end
            return c.r or 1, c.g or 1, c.b or 1
        end,
        options         = options,
    })
    if not AC.settingsPanel then AC.settingsUnavailable = true end
end

--------------------------------------------------
-- EVENT_EFFECT_CHANGED
--------------------------------------------------

function AC:OnEffectChanged(eventCode, changeType, effectSlot, effectName,
    unitTag, beginTime, endTime, stackCount, iconName, buffType,
    effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceUnitType)

    if unitTag ~= "player" then return end
    if not AC.ready then return end

    AC:HUDOnEffect(changeType, effectSlot, effectName, effectType, abilityType, iconName, endTime, beginTime, abilityId)

    if changeType ~= EFFECT_RESULT_FADED then return end

    local lower = (effectName or ""):lower()

    for _, match in ipairs(XP_BUFF_NAMES) do
        if lower:find(match, 1, true) then
            zo_callLater(function() AC:CheckXP() end, 1500)
            return
        end
    end

    for _, match in ipairs(AP_BUFF_NAMES) do
        if lower:find(match, 1, true) then
            zo_callLater(function() AC:CheckAP() end, 1500)
            return
        end
    end

    if AC.savedVariables and AC.savedVariables.foodID then
        if FOOD_BUFF_ABILITY_IDS[abilityId] or abilityType == ABILITY_TYPE_INTERACTIVES then
            zo_callLater(function() AC:ForceCheckFood() end, 1500)
            return
        end
    end
end

--------------------------------------------------
-- LOAD
--------------------------------------------------

local function OnAddonLoaded(event, addonName)
    if addonName ~= AC.name then return end

    AC.savedVariables = ZO_SavedVars:New(
        "AutoConsume_SavedVars",
        2,
        nil,
        DEFAULTS
    )

    local settingsOk, settingsErr = pcall(function() AC:CreateSettings() end)
    if not settingsOk then
        AC.settingsUnavailable = true
        AC.settingsError = tostring(settingsErr)
    end

    pcall(function() AC:HUDInit() end)

    EVENT_MANAGER:RegisterForEvent(
        AC.name,
        EVENT_EFFECT_CHANGED,
        function(...) AC:OnEffectChanged(...) end
    )

    EVENT_MANAGER:AddFilterForEvent(
        AC.name,
        EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, "player"
    )

    EVENT_MANAGER:RegisterForEvent(AC.name, EVENT_PLAYER_ACTIVATED, function()
        AC.ready = true
        AC:CheckAll()
        pcall(function() AC:HUDInit() end)
        pcall(function() AC:HUDScan() end)
        EVENT_MANAGER:RegisterForUpdate("AutoConsume_HUDRefresh", 500, function()
            AC:HUDRefresh()
        end)
        if AC.savedVariables.bagScanned then
            AC.savedVariables.bagScanned = false
            Notify("Bag scanned.")
        end
    end)

    EVENT_MANAGER:RegisterForEvent(AC.name, EVENT_PLAYER_REINCARNATED, function()
        if not AC.ready then return end
        zo_callLater(function() AC:CheckAll() end, 3000)
    end)

    EVENT_MANAGER:UnregisterForEvent(AC.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(AC.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)


local AC_HUD_PLACEHOLDER = nil

local HUD_ICON_SIZE = 40
local HUD_SIDE_MARGIN = 4
local HUD_RING_PAD = 10
local HUD_FRAME_PAD = 14
local HUD_RING_WINDOW = 60

local hudRowCounter = 0

local HUD_ORANGE_THRESHOLD = 0.50
local HUD_RED_THRESHOLD    = 0.25

local function GetHUDTimerColor(remaining, totalDuration)
    if totalDuration <= 0 then return 0.2, 1.0, 0.2 end
    local pct = remaining / totalDuration
    if pct <= HUD_RED_THRESHOLD then
        return 1.0, 0.2, 0.2
    elseif pct <= HUD_ORANGE_THRESHOLD then
        return 1.0, 0.55, 0.0
    else
        return 0.2, 1.0, 0.2
    end
end
local HUD_DELVE_BUFF_ID = 66282

--------------------------------------------------
-- HUD
--------------------------------------------------

local function AcHudIsFood(abilityId, buffName)
    if FOOD_BUFF_ABILITY_IDS[abilityId] then return true end
    if abilityId and ABILITY_TYPE_INTERACTIVES and abilityId == ABILITY_TYPE_INTERACTIVES then return true end
    return false
end

local function AcHudIsXP(buffName)
    local lower = (buffName or ""):lower()
    for _, match in ipairs(XP_BUFF_NAMES) do
        if lower:find(match, 1, true) then return true end
    end
    return false
end

local function AcHudIsAP(buffName)
    local lower = (buffName or ""):lower()
    for _, match in ipairs(AP_BUFF_NAMES) do
        if lower:find(match, 1, true) then return true end
    end
    return false
end

local function AcHudIsDelve(abilityId)
    return abilityId == HUD_DELVE_BUFF_ID
end

local function AcHudCreateRow(parent, index)
    hudRowCounter = hudRowCounter + 1

    local row = WINDOW_MANAGER:CreateControlFromVirtual(
        "AutoConsume_HUDRow" .. hudRowCounter,
        parent,
        "AutoConsume_HUDRow"
    )

    row.frame  = row:GetNamedChild("Frame")
    row.radial = row:GetNamedChild("Radial")
    row.inner  = row:GetNamedChild("Inner")
    row.icon   = row:GetNamedChild("Icon")
    row.timer  = row:GetNamedChild("Timer")

    row.timer:SetColor(1, 1, 1, 1)
    row.timer:SetHidden(true)
    row.radial:SetHidden(true)

    row:SetHidden(true)
    return row
end

local function AcHudSizeRow(row, iconSize)
    local frameSize = iconSize + HUD_FRAME_PAD

    if row.sizedFor ~= iconSize then
        row:SetDimensions(frameSize, frameSize)
        row.frame:SetDimensions(frameSize, frameSize)
        row.radial:SetDimensions(iconSize + HUD_RING_PAD, iconSize + HUD_RING_PAD)
        row.inner:SetDimensions(iconSize, iconSize)
        row.icon:SetDimensions(iconSize, iconSize)
        row.timer:SetDimensions(iconSize, iconSize)
        row.timer:SetFont(string.format("EsoUI/Common/Fonts/univers67.otf|%d|soft-shadow-thick",
            math.max(10, math.floor(iconSize * 0.55))))
        row.sizedFor = iconSize
    end

    return frameSize
end

local function AcHudRingSeconds(entry, now)
    local remaining = entry.endTime - now

    if entry.buffType == "food" and AC.savedVariables.autoFood then
        return remaining - (AC.savedVariables.foodMinutes * 60), "eat"
    end

    return remaining, "end"
end

local function AcHudUpdateRing(row, entry, now)
    local seconds, mode = AcHudRingSeconds(entry, now)

    if seconds <= 0 or seconds > HUD_RING_WINDOW then
        row.ringActive = false
        row.ringKey    = nil
        row.radial:SetHidden(true)
        return false
    end

    local key = entry.buffType .. ":" .. entry.endTime .. ":" .. mode

    if not row.ringActive or row.ringKey ~= key then
        row.ringKey    = key
        row.ringActive = true
        row.radial:StartCooldown(seconds * 1000, HUD_RING_WINDOW * 1000,
            CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
    end

    row.radial:SetHidden(false)
    return true
end

function AC:HUDInit()
    if AC_HUD.panel then return end

    AC_HUD.panel = WINDOW_MANAGER:CreateTopLevelWindow("AutoConsume_HUDPanel")
    AC_HUD.panel:SetClampedToScreen(true)
    AC_HUD.panel:SetDrawLayer(DL_BACKGROUND)
    AC_HUD.panel:SetDrawTier(DT_LOW)
    AC_HUD.panel:SetDimensions(HUD_ICON_SIZE + HUD_FRAME_PAD,
        (HUD_ICON_SIZE + HUD_FRAME_PAD) * 4 + HUD_SIDE_MARGIN * 3)
    AC_HUD.panel:ClearAnchors()
    AC_HUD.panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        AC.savedVariables.hudPosX,
        AC.savedVariables.hudPosY)
    AC_HUD.panel:SetHidden(true)

    AC_HUD.hudFragment = ZO_HUDFadeSceneFragment:New(AC_HUD.panel)

    local function UpdateHUDScenes()
        if not AC_HUD.hudFragment then return end
        local valid_scenes = {"hud", "hudui"}

        for _, s_name in ipairs(valid_scenes) do
            local scene = SCENE_MANAGER:GetScene(s_name)
            if scene then
                scene:RemoveFragment(AC_HUD.hudFragment)
            end
        end

        if AC.savedVariables.hudEnabled then
            for _, s_name in ipairs(valid_scenes) do
                local scene = SCENE_MANAGER:GetScene(s_name)
                if scene then
                    scene:AddFragment(AC_HUD.hudFragment)
                end
            end
        end

        local cur_scene = SCENE_MANAGER:GetCurrentScene()
        if not AC.savedVariables.hudEnabled then
            AC_HUD.panel:SetHidden(true)
        else
            local should_show = cur_scene and cur_scene:HasFragment(AC_HUD.hudFragment)
            AC_HUD.panel:SetHidden(not should_show)
        end
    end

    AC_HUD.updateScenes = UpdateHUDScenes
    AC_HUD.hadEntries = false

    AC_HUD.rows = {}
    for i = 1, 4 do
        AC_HUD.rows[i] = AcHudCreateRow(AC_HUD.panel, i)
    end
end

function AC:ApplyHUDPosition()
    if not AC_HUD.panel then return end
    AC_HUD.panel:ClearAnchors()
    AC_HUD.panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        AC.savedVariables.hudPosX,
        AC.savedVariables.hudPosY)
end

--------------------------------------------------
-- PREVIEW
--------------------------------------------------

local function PreviewIcon(itemID)
    local slotId = FindItemSlot(itemID)
    if slotId then
        local icon = GetItemInfo(BAG_BACKPACK, slotId)
        if icon and icon ~= "" then return icon end
    end
    return ICON_GENERIC
end

function AC:StartPreview()
    if AC.previewing then return end
    AC.previewing = true
    AC.previewIcons = {
        PreviewIcon(AC.savedVariables.foodID),
        PreviewIcon(AC.savedVariables.xpItemID),
        PreviewIcon(AC.savedVariables.apItemID),
    }
    AC:HUDRefresh()
end

function AC:EndPreview()
    if not AC.previewing then return end
    AC.previewing = false
    AC.previewIcons = nil
    AC_HUD.hadEntries = false
    if AC_HUD.updateScenes then AC_HUD.updateScenes() end
    AC:HUDRefresh()
end

--------------------------------------------------
-- RESET
--------------------------------------------------

function AC:ResetSettings()
    if not AC.savedVariables then return end

    AC:EndPreview()

    for key, value in pairs(DEFAULTS) do
        if type(value) == "table" then
            local copy = {}
            for k, v in pairs(value) do copy[k] = v end
            AC.savedVariables[key] = copy
        else
            AC.savedVariables[key] = value
        end
    end
    AC.savedVariables.foodID   = nil
    AC.savedVariables.xpItemID = nil
    AC.savedVariables.apItemID = nil
    AC.savedVariables.settingsLastPage = nil

    pending.foodID   = nil
    pending.xpItemID = nil
    pending.apItemID = nil

    AC:ApplyHUDPosition()
    if AC_HUD.updateScenes then AC_HUD.updateScenes() end
    AC:HUDRefresh()

    PanelCall("ApplyTextSize")
    PanelCall("ApplyFont")
    PanelCall("ApplyOpacity")
    PanelCall("ApplyAccent")
end

function AC:HUDScan()
    AC_HUD.active = {}
    if not AC.savedVariables.hudEnabled then return end
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local buffName, startTime, endTime, buffSlot, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, abilityId = GetUnitBuffInfo("player", i)
        if buffName and buffName ~= "" and endTime and endTime > 0 and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then
            local bType = nil
            if AC.savedVariables.foodID and AcHudIsFood(abilityId, buffName) then
                bType = "food"
            elseif AC.savedVariables.xpItemID and AcHudIsXP(buffName) then
                bType = "xp"
            elseif AC.savedVariables.apItemID and AcHudIsAP(buffName) then
                bType = "ap"
            elseif AcHudIsDelve(abilityId) then
                bType = "delve"
            end
            if bType then
                AC_HUD.active[i] = {
                    icon      = iconName,
                    endTime   = endTime,
                    startTime = startTime,
                    buffType  = bType,
                }
            end
        end
    end
end

function AC:HUDOnEffect(changeType, effectSlot, buffName, effectType, abilityType, iconName, endTime, startTime, abilityId)
    if not AC.savedVariables.hudEnabled then return end
    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        if effectType == BUFF_EFFECT_TYPE_DEBUFF then return end
        local bType = nil
        if AC.savedVariables.foodID and AcHudIsFood(abilityId, buffName) then
            bType = "food"
        elseif AC.savedVariables.xpItemID and AcHudIsXP(buffName) then
            bType = "xp"
        elseif AC.savedVariables.apItemID and AcHudIsAP(buffName) then
            bType = "ap"
        elseif AcHudIsDelve(abilityId) then
            bType = "delve"
        end
        if bType then
            AC_HUD.active[effectSlot] = {
                icon      = iconName,
                endTime   = endTime,
                startTime = startTime,
                buffType  = bType,
            }
        end
    elseif changeType == EFFECT_RESULT_FADED then
        AC_HUD.active[effectSlot] = nil
    end
end

function AC:HUDRefresh()
    if not AC_HUD.panel then return end

    if not AC.previewing and not AC.savedVariables.hudEnabled then
        AC_HUD.panel:SetHidden(true)
        return
    end

    AC:HUDScan()

    local now        = GetGameTimeSeconds()
    local iconSize   = AC.savedVariables.hudIconSize
    local horizontal = AC.savedVariables.hudHorizontal

    local entries = {}
    if AC.previewing then
        local icons = AC.previewIcons or {}
        for i = 1, #icons do
            entries[i] = {
                icon      = icons[i],
                endTime   = now + 3600,
                startTime = now,
                buffType  = "preview" .. i,
            }
        end
    else
        local foodEntry, xpEntry, apEntry, delveEntry = nil, nil, nil, nil
        for slot, entry in pairs(AC_HUD.active) do
            if entry.buffType == "food"  and not foodEntry  then foodEntry  = entry end
            if entry.buffType == "xp"    and not xpEntry    then xpEntry    = entry end
            if entry.buffType == "ap"    and not apEntry    then apEntry    = entry end
            if entry.buffType == "delve" and not delveEntry then delveEntry = entry end
        end

        if foodEntry  then entries[#entries+1] = foodEntry  end
        if xpEntry    then entries[#entries+1] = xpEntry    end
        if apEntry    then entries[#entries+1] = apEntry    end
        if delveEntry then entries[#entries+1] = delveEntry end
    end

    local offset = 0
    for i = 1, 4 do
        local row   = AC_HUD.rows[i]
        local entry = entries[i]
        if entry then
            local remaining = math.max(0, entry.endTime - now)

            row:ClearAnchors()
            if horizontal then
                row:SetAnchor(TOPLEFT, AC_HUD.panel, TOPLEFT, offset, 0)
            else
                row:SetAnchor(TOPLEFT, AC_HUD.panel, TOPLEFT, 0, offset)
            end
            local frameSize = AcHudSizeRow(row, iconSize)
            row.icon:SetTexture(entry.icon)
            row.icon:SetHidden(false)

            AcHudUpdateRing(row, entry, now)

            if remaining <= 60 then
                local totalDur = entry.endTime - entry.startTime
                local tr, tg, tb = GetHUDTimerColor(remaining, totalDur)
                row.timer:SetText(string.format("%ds", math.ceil(remaining)))
                row.timer:SetColor(tr, tg, tb, 1)
                row.timer:SetHidden(false)
            else
                row.timer:SetHidden(true)
            end

            row:SetHidden(false)
            offset = offset + frameSize + HUD_SIDE_MARGIN
        else
            row.ringActive = false
            row.ringKey    = nil
            row.radial:SetHidden(true)
            row:SetHidden(true)
        end
    end

    if #entries > 0 then
        local frameSize = iconSize + HUD_FRAME_PAD
        if horizontal then
            AC_HUD.panel:SetDimensions(offset, frameSize)
        else
            AC_HUD.panel:SetDimensions(frameSize, offset)
        end
        if AC_HUD.hadEntries == false then
            AC_HUD.hadEntries = true
            if AC_HUD.updateScenes then AC_HUD.updateScenes() end
        end
        if AC.previewing then
            AC_HUD.panel:SetHidden(false)
        end
    else
        if AC_HUD.hadEntries ~= false then
            AC_HUD.hadEntries = false
        end
        AC_HUD.panel:SetHidden(true)
    end
end
