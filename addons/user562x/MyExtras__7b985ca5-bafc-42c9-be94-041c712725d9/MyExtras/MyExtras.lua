MyExtras = {}
MyExtras.name = "MyExtras"
MyExtras.version = "9.7"
MyExtras.savedVariables = nil
MyExtras.charVariables = nil
MyExtras.defaults = {
    settingsFontSize       = 30,
    settingsFont           = "EsoUI/Common/Fonts/FTN57.otf",
    settingsOpacity        = 100,
    settingsHighlight      = "Custom",
    settingsHighlightColor = { r = 214 / 255, g = 90 / 255, b = 214 / 255, a = 1 },
    settingsRemember       = true,
}
MyExtras.charDefaults = {}
MyExtras.features = {}

--------------------------------------------------
-- Settings Details
--------------------------------------------------
MyExtras.SAVED_ACCOUNT_TIP   = "Account wide: the same on all your characters."
MyExtras.SAVED_CHARACTER_TIP = "Per character: set separately on each of your characters."
MyExtras.CHARACTER_SETTINGS_TIP = "On: this character has its own settings. Off: it uses your account settings."

local SOCIAL_MENU  = "Social"
local MENU_ORDER   = { "ActionBar", "Trackers", "Gear", "Items", "DungeonsTrials", "QualityOfLife", SOCIAL_MENU, "Antiquity" }
local SOCIAL_ORDER = { "FriendsStatus", "ChatTravel", "TitleLoop", "GuildLoop", "Streamer" }
local NESTED       = { "Performance" }

local ICON_SETTINGS = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_settings.dds"
local ICON_MENU     = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_misc.dds"
local ICON_SOCIAL   = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_contacts.dds"

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
MyExtras.FONT_CHOICES = FONT_CHOICES

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
MyExtras.RainbowText = RainbowText

local function PanelCall(method)
    local panel = MyExtras.settingsPanel
    if panel and panel[method] then panel[method](panel) end
end

--------------------------------------------------
-- Game Calls
--------------------------------------------------
local function ShowOnScreenChat(text)
    local chat = GAMEPAD_CHAT_SYSTEM
    local container = chat and chat.primaryContainer
    if not (container and container.currentBuffer and container.AddMessageToWindow) then return end
    local window = container.currentBuffer:GetParent()
    if not window then return end
    local category = CHAT_CATEGORY_SYSTEM or 0
    if IsChatContainerTabCategoryEnabled and window.tab and window.tab.index
        and IsChatContainerTabCategoryEnabled(container.id, window.tab.index, category) then
        return
    end
    container:AddMessageToWindow(window, text, 1, 1, 1, category)
    if container.windowContainer and container.windowContainer.SetHidden then
        container.windowContainer:SetHidden(false)
    end
    if chat.StartVisibilityTimer then chat:StartVisibilityTimer() end
end

function MyExtras:Chat(text)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(text)
    elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(text)
    else
        d(text)
        return
    end
    pcall(ShowOnScreenChat, text)
end

function MyExtras:Icon(texture)
    if type(texture) ~= "string" or texture == "" then return "" end
    return zo_iconFormat(texture, "100%", "100%") .. " "
end

function MyExtras:AccentHex()
    local sv = self.savedVariables
    if sv and sv.settingsHighlight == "Custom" and type(sv.settingsHighlightColor) == "table" then
        local c = sv.settingsHighlightColor
        return ZO_ColorDef:New(c.r or 1, c.g or 1, c.b or 1):ToHex()
    end
    local color = GetAllianceColor(GetUnitAlliance("player"))
    if color then return color:ToHex() end
    return "FFFFFF"
end

function MyExtras:ChatPrefix(feature, icon)
    local prefix = "|c" .. self:AccentHex() .. self.name .. "|r"
    if feature and feature ~= "" then prefix = prefix .. " [" .. self:Icon(icon) .. feature .. "]" end
    return prefix .. ": "
end

function MyExtras:CallGame(name, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then return false end
    if IsPrivateFunction and IsPrivateFunction(name) then return false end
    if IsProtectedFunction and IsProtectedFunction(name) then
        if type(CallSecureProtected) ~= "function" then return false end
        local ok, done = pcall(CallSecureProtected, name, ...)
        return ok and done ~= false
    end
    return (pcall(fn, ...))
end

--------------------------------------------------
-- Features
--------------------------------------------------
function MyExtras:RegisterFeature(feature)
    self.features[#self.features + 1] = feature
    if type(feature.defaults) == "table" then
        for key, value in pairs(feature.defaults) do
            self.defaults[key] = value
        end
    end
    if type(feature.charDefaults) == "table" then
        for key, value in pairs(feature.charDefaults) do
            self.charDefaults[key] = value
        end
    end
end

local function AnyMoving()
    for _, feature in ipairs(MyExtras.features) do
        if feature.moving then return true end
    end
    return false
end

local function CallFeatures(method, ...)
    for _, feature in ipairs(MyExtras.features) do
        if type(feature[method]) == "function" then
            pcall(feature[method], feature, ...)
        end
    end
end

--------------------------------------------------
-- Placing
--------------------------------------------------
function MyExtras:SetPlacing(value)
    self.placing = value == true
    CallFeatures("OnPlacing", self.placing)
end

--------------------------------------------------
-- Round Box
--------------------------------------------------
local BOX_FILL   = "MyExtras/Textures/boxfill.dds"
local BOX_EDGE   = "MyExtras/Textures/boxedge.dds"
local BOX_SILVER = 0.55
local BOX_COORDS = {
    { 0,    0.25, 0,    0.25 }, { 0.25, 0.75, 0,    0.25 }, { 0.75, 1,    0,    0.25 },
    { 0,    0.25, 0.25, 0.75 }, { 0.25, 0.75, 0.25, 0.75 }, { 0.75, 1,    0.25, 0.75 },
    { 0,    0.25, 0.75, 1    }, { 0.25, 0.75, 0.75, 1    }, { 0.75, 1,    0.75, 1    },
}

local RoundBox = {}
RoundBox.__index = RoundBox

local function BoxPieces(name, parent, file, level)
    local pieces = {}
    for i = 1, #BOX_COORDS do
        local piece = WINDOW_MANAGER:CreateControl(name .. i, parent, CT_TEXTURE)
        local c = BOX_COORDS[i]
        piece:SetTexture(file)
        piece:SetTextureCoords(c[1], c[2], c[3], c[4])
        piece:SetDrawLevel(level)
        pieces[i] = piece
    end
    return pieces
end

local function PlacePieces(pieces, box, r)
    for i = 1, #pieces do pieces[i]:ClearAnchors() end
    pieces[1]:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
    pieces[1]:SetDimensions(r, r)
    pieces[3]:SetAnchor(TOPRIGHT, box, TOPRIGHT, 0, 0)
    pieces[3]:SetDimensions(r, r)
    pieces[7]:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT, 0, 0)
    pieces[7]:SetDimensions(r, r)
    pieces[9]:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, 0, 0)
    pieces[9]:SetDimensions(r, r)
    pieces[2]:SetAnchor(TOPLEFT, box, TOPLEFT, r, 0)
    pieces[2]:SetAnchor(BOTTOMRIGHT, box, TOPRIGHT, -r, r)
    pieces[8]:SetAnchor(TOPLEFT, box, BOTTOMLEFT, r, -r)
    pieces[8]:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, -r, 0)
    pieces[4]:SetAnchor(TOPLEFT, box, TOPLEFT, 0, r)
    pieces[4]:SetAnchor(BOTTOMRIGHT, box, BOTTOMLEFT, r, -r)
    pieces[6]:SetAnchor(TOPLEFT, box, TOPRIGHT, -r, r)
    pieces[6]:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, 0, -r)
    pieces[5]:SetAnchor(TOPLEFT, box, TOPLEFT, r, r)
    pieces[5]:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, -r, -r)
end

local function TintPieces(pieces, r, g, b, a)
    for i = 1, #pieces do pieces[i]:SetColor(r, g, b, a) end
end

function MyExtras:CreateRoundBox(name, parent, level)
    level = level or 0
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    local box = setmetatable({ control = control, corner = 0 }, RoundBox)
    box.fill = BoxPieces(name .. "Fill", control, BOX_FILL, level)
    box.edge = BoxPieces(name .. "Edge", control, BOX_EDGE, level + 1)
    TintPieces(box.edge, BOX_SILVER, BOX_SILVER, BOX_SILVER, 1)
    box:SetCorner(12)
    return box
end

function RoundBox:SetCorner(r)
    r = math.max(2, zo_floor(r))
    if r == self.corner then return end
    self.corner = r
    PlacePieces(self.fill, self.control, r)
    PlacePieces(self.edge, self.control, r)
end

function RoundBox:SetFillColor(r, g, b, a)
    TintPieces(self.fill, r, g, b, a)
end

function RoundBox:SetEdgeColor(r, g, b, a)
    TintPieces(self.edge, r, g, b, a)
end

function RoundBox:SetHidden(hidden)
    self.control:SetHidden(hidden)
end

--------------------------------------------------
-- Stretch
--------------------------------------------------
MyExtras.STRETCH_MIN = LibUser562.STRETCH_MIN
MyExtras.STRETCH_MAX = LibUser562.STRETCH_MAX

function MyExtras:ApplyStretch(control, percent, originX, originY)
    LibUser562:ApplyStretch(control, percent, originX, originY)
end

--------------------------------------------------
-- Scopes
--------------------------------------------------
local function CopyValue(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = v end
    return copy
end

local Scope = {}
Scope.__index = Scope

function MyExtras:NewScope(charKey, legacyKey)
    local scope = setmetatable({
        charKey  = charKey,
        legacyKey = legacyKey,
        defaults = {},
        groups   = {},
    }, Scope)
    scope.proxy = setmetatable({}, {
        __index    = function(_, key) return scope:Store(key)[key] end,
        __newindex = function(_, key, value) scope:Store(key)[key] = value end,
    })
    return scope
end

function Scope:AddDefaults(list, group)
    for key, value in pairs(list) do
        self.defaults[key] = value
        MyExtras.defaults[key] = value
        local keyGroup = group
        if type(group) == "function" then keyGroup = group(key) end
        self.groups[key] = keyGroup
    end
end

function Scope:Flags()
    local cv = MyExtras.charVariables
    if not cv then return nil end
    local name = self.charKey .. "Scopes"
    if type(cv[name]) ~= "table" then
        cv[name] = {}
        if self.legacyKey and cv[self.legacyKey] == true then cv[name].all = true end
    end
    return cv[name]
end

function Scope:UsesCharacter(group)
    if not group then return false end
    local flags = self:Flags()
    if not flags then return false end
    if flags[group] ~= nil then return flags[group] == true end
    return flags.all == true
end

function Scope:CharTable()
    local cv = MyExtras.charVariables
    if type(cv[self.charKey]) ~= "table" then cv[self.charKey] = {} end
    local settings = cv[self.charKey]
    if type(settings.seededGroups) ~= "table" then settings.seededGroups = {} end
    return settings
end

function Scope:Seed(group)
    local settings = self:CharTable()
    local account = MyExtras.savedVariables or {}
    for key, keyGroup in pairs(self.groups) do
        if keyGroup == group then
            local value = account[key]
            if value == nil then value = self.defaults[key] end
            settings[key] = CopyValue(value)
        end
    end
    settings.seededGroups[group] = true
end

function Scope:Store(key)
    local group = self.groups[key]
    if group and MyExtras.charVariables and self:UsesCharacter(group) then
        local settings = self:CharTable()
        if not (settings.seeded or settings.seededGroups[group]) then self:Seed(group) end
        if settings[key] == nil and self.defaults[key] ~= nil then
            local value = MyExtras.savedVariables and MyExtras.savedVariables[key]
            if value == nil then value = self.defaults[key] end
            settings[key] = CopyValue(value)
        end
        return settings
    end
    return MyExtras.savedVariables
end

function Scope:SetUsesCharacter(group, value)
    local flags = self:Flags()
    if not flags or not group then return end
    value = value == true
    flags[group] = value
    if value then
        local settings = self:CharTable()
        if not (settings.seeded or settings.seededGroups[group]) then self:Seed(group) end
    end
end

function Scope:Settings()
    return self.proxy
end

function Scope:ResetSkipKeys()
    local keys = {}
    for key, group in pairs(self.groups) do
        if group and self:UsesCharacter(group) then keys[#keys + 1] = key end
    end
    return keys
end

function Scope:ResetCharacter()
    if not MyExtras.charVariables then return end
    local settings = self:CharTable()
    for key, group in pairs(self.groups) do
        if group and self:UsesCharacter(group) then
            settings[key] = CopyValue(self.defaults[key])
        end
    end
end

function MyExtras:CharacterOption(scope, group, onChange)
    return {
        type    = "toggle",
        name    = "Character Settings",
        tooltip = MyExtras.CHARACTER_SETTINGS_TIP,
        getFunc = function() return scope:UsesCharacter(group) end,
        setFunc = function(val)
            scope:SetUsesCharacter(group, val)
            if onChange then onChange() end
            local panel = MyExtras.settingsPanel
            if panel and panel.Refresh then panel:Refresh() end
        end,
    }
end

function MyExtras:SavedTip(scope, group)
    if scope:UsesCharacter(group) then return self.SAVED_CHARACTER_TIP end
    return self.SAVED_ACCOUNT_TIP
end

--------------------------------------------------
-- Reset
--------------------------------------------------
function MyExtras:ResetSettings()
    if not self.savedVariables then return end

    local skip = {}
    for _, feature in ipairs(self.features) do
        if type(feature.ResetSkipKeys) == "function" then
            local ok, keys = pcall(feature.ResetSkipKeys, feature)
            if ok and type(keys) == "table" then
                for i = 1, #keys do skip[keys[i]] = true end
            end
        end
    end

    for key, value in pairs(self.defaults) do
        if not skip[key] then
            if type(value) == "table" then
                local copy = {}
                for k, v in pairs(value) do copy[k] = v end
                self.savedVariables[key] = copy
            else
                self.savedVariables[key] = value
            end
        end
    end
    self.savedVariables.settingsLastPage = nil

    CallFeatures("OnReset")

    PanelCall("ApplyTextSize")
    PanelCall("ApplyFont")
    PanelCall("ApplyOpacity")
    PanelCall("ApplyAccent")
end

--------------------------------------------------
-- Info
--------------------------------------------------
local GAMERTAG       = "user562"
local DISCORD        = "user562."
local NAME_COLOR     = "D65AD6"
local TITLE_COLORED  = "|c" .. NAME_COLOR .. "MyExtras|r"

local function AccentTitle()
    return "|c" .. MyExtras:AccentHex() .. "MyExtras|r"
end

local function AccentAuthor()
    return "user|c" .. MyExtras:AccentHex() .. "562|r"
end

local STATUS_INSTALLED = "|c33DD33Installed|r"
local STATUS_OFF       = "|cFFAA33Turned Off|r"
local STATUS_MISSING   = "|c8C8C8CNot Installed|r"

local MY_ADDONS = {
    {
        name        = "MyExtras",
        title       = TITLE_COLORED,
        description = "Extra features in one place, like your action bar, trackers, gear tools, trial timer and more.",
    },
    {
        name        = "PvPUA",
        title       = "|c4F81BDP|r|cC2AA49v|r|cDE5B4EP|r |cFF8800UA!|r",
        description = "Tells you when something is under attack in Cyrodiil, Imperial City and more.",
    },
    {
        name        = "WhereIsIt",
        title       = "Where Is It?",
        description = "Shows where your items and currencies are across your characters, bank, guild banks and houses.",
    },
    {
        name        = "AutoConsume",
        title       = "AutoConsume",
        description = "Uses your food, drinks and experience and Alliance Point boosts for you.",
    },
    {
        name        = "VerticalBuffsDebuffs",
        title       = "VerticalBuffsDebuffs",
        description = "Shows your buffs and debuffs in vertical lists with timers.",
    },
    {
        name        = "LibUser562",
        title       = "LibUser562",
        description = "The settings library these addons use.",
    },
}

local function PlainName(text)
    local plain = tostring(text or "")
    plain = plain:gsub("|c%x%x%x%x%x%x", "")
    plain = plain:gsub("|r", "")
    plain = plain:gsub("[^%w]", "")
    return plain:lower()
end

local function FindAddOn(entry)
    if type(GetAddOnManager) ~= "function" then return nil end
    local manager = GetAddOnManager()
    if not manager then return nil end
    local wantName, wantTitle = PlainName(entry.name), PlainName(entry.title)
    for i = 1, manager:GetNumAddOns() do
        local name, title, _, _, enabled = manager:GetAddOnInfo(i)
        if PlainName(name) == wantName or PlainName(title) == wantTitle then
            return title, enabled == true
        end
    end
    return nil
end

local MANAGE_SCENE = "gamepad_addons"

local function ManageAvailable()
    if type(DoesPlatformSupportModBrowser) ~= "function" or not DoesPlatformSupportModBrowser() then return false end
    if type(AreUserAddOnsSupported) == "function" and not AreUserAddOnsSupported() then return false end
    return SCENE_MANAGER:GetScene(MANAGE_SCENE) ~= nil
end

local function OpenManage()
    if not ManageAvailable() then return end
    SCENE_MANAGER:Push(MANAGE_SCENE)
end

local function AddOnRow(entry)
    local function State()
        if entry.name == MyExtras.name then return "installed", AccentTitle() end
        local title, enabled = FindAddOn(entry)
        if not title then return "missing", entry.title end
        if title == "" then title = entry.title end
        return enabled and "installed" or "off", title
    end

    local function Action()
        local state = State()
        if state == "off" and ManageAvailable() then
            return OpenManage, "Manage My Add-Ons"
        end
        return nil
    end

    local row = {
        type       = "button",
        name       = function()
            local state, title = State()
            if state == "missing" then return title .. "   " .. STATUS_MISSING end
            if state == "off" then return title .. "   " .. STATUS_OFF end
            return title .. "   " .. STATUS_INSTALLED
        end,
        buttonText = function()
            local _, text = Action()
            return text
        end,
        tooltip    = function()
            local state = State()
            if state == "off" and ManageAvailable() then
                return entry.description .. "\n\nManage My Add-Ons opens so you can turn it back on."
            end
            return entry.description
        end,
    }
    return setmetatable(row, {
        __index = function(_, key)
            if key == "func" then return (Action()) end
        end,
    })
end

function MyExtras:InfoMenu()
    local options = {
        { type = "header", name = "Contact" },
        {
            type    = "button",
            name    = "Xbox: " .. GAMERTAG,
        },
        {
            type    = "button",
            name    = "Discord: " .. DISCORD,
            tooltip = "The period at the end is part of the name.",
        },
        { type = "header", name = "My Addons" },
    }
    for i = 1, #MY_ADDONS do
        options[#options + 1] = AddOnRow(MY_ADDONS[i])
    end
    return {
        type    = "submenu",
        name    = "Info",
        tooltip = "How to reach me, and my other addons.",
        options = options,
    }
end

--------------------------------------------------
-- Social
--------------------------------------------------
function MyExtras:SocialMenu()
    local options = {}
    for i = 1, #SOCIAL_ORDER do
        local feature = self[SOCIAL_ORDER[i]]
        if feature and type(feature.GetOptions) == "function" then
            local featureOptions = feature:GetOptions()
            for j = 1, #featureOptions do
                local option = featureOptions[j]
                if type(option) == "table" and option.type == "submenu" then option.icon = nil end
                options[#options + 1] = option
            end
        end
    end
    if #options == 0 then return nil end
    return {
        type    = "submenu",
        name    = "Social",
        icon    = ICON_SOCIAL,
        tooltip = "Tells you when friends come online, lets you travel to people from chat, cycles your titles "
               .. "and guilds, and puts a message on screen for your viewers.",
        options = options,
    }
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function MyExtras:SettingsMenu()
    local defaults = self.defaults
    return {
        type    = "submenu",
        name    = "Settings",
        icon    = ICON_SETTINGS,
        tooltip = self.SAVED_ACCOUNT_TIP,
        options = {
            {
                type    = "slider",
                name    = "Font Size",
                min     = 18, max = 44, step = 1,
                default = defaults.settingsFontSize,
                tooltip = "Default is 30.",
                getFunc = function() return self.savedVariables.settingsFontSize end,
                setFunc = function(val)
                    self.savedVariables.settingsFontSize = val
                    PanelCall("ApplyTextSize")
                end,
            },
            {
                type    = "dropdown",
                name    = "Font",
                choices = FONT_CHOICES,
                default = defaults.settingsFont,
                tooltip = "Some fonts look bigger or smaller than others, so you may need to adjust Font Size.\n\nDefault is Gamepad Medium.",
                getFunc = function() return self.savedVariables.settingsFont end,
                setFunc = function(val)
                    self.savedVariables.settingsFont = val
                    PanelCall("ApplyFont")
                end,
            },
            {
                type    = "slider",
                name    = "Opacity",
                min     = 0, max = 100, step = 5,
                default = defaults.settingsOpacity,
                tooltip = "Default is 100.",
                getFunc = function() return self.savedVariables.settingsOpacity end,
                setFunc = function(val)
                    self.savedVariables.settingsOpacity = val
                    PanelCall("ApplyOpacity")
                end,
            },
            {
                type         = "stylecolor",
                name         = RainbowText("Accent Color"),
                choices      = { "Alliance", "Custom" },
                customValue  = "Custom",
                default      = defaults.settingsHighlight,
                colorDefault = { r = 214 / 255, g = 90 / 255, b = 214 / 255 },
                details      = function()
                    local where = ", like the settings window and the MyExtras name in chat."
                    if self.savedVariables.settingsHighlight == "Custom" then
                        return "Colors MyExtras' highlights with your color" .. where
                    end
                    return "Colors MyExtras' highlights with your alliance color" .. where
                end,
                getFunc  = function() return self.savedVariables.settingsHighlight end,
                setFunc  = function(val)
                    self.savedVariables.settingsHighlight = val
                    PanelCall("ApplyAccent")
                end,
                getColor = function()
                    local c = self.savedVariables.settingsHighlightColor
                    if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1 end
                    return 1, 1, 1
                end,
                setColor = function(r, g, b)
                    self.savedVariables.settingsHighlightColor = { r = r, g = g, b = b, a = 1 }
                    PanelCall("ApplyAccent")
                end,
            },
            {
                type    = "toggle",
                name    = "Remember Last Page",
                preset  = "YES_NO",
                default = defaults.settingsRemember,
                tooltip = "Reopens the last page where you left off.",
                getFunc = function() return self.savedVariables.settingsRemember end,
                setFunc = function(val) self.savedVariables.settingsRemember = val end,
            },
            {
                type       = "button",
                name       = "|cFF3333Reset All|r",
                buttonText = "Reset All",
                details    = "Resets every MyExtras setting to its default.",
                confirm    = "Reset every MyExtras setting to its default? This can't be undone.",
                func       = function() self:ResetSettings() end,
            },
            self:InfoMenu(),
        },
    }
end

function MyExtras:SettingsPreviewControls()
    local controls = {}
    for _, feature in ipairs(self.features) do
        if type(feature.GetPreviewControls) == "function" then
            local list = feature:GetPreviewControls()
            for i = 1, #list do
                controls[#controls + 1] = list[i]
            end
        end
    end
    return controls
end

function MyExtras:CreateSettings()
    local lib = rawget(_G, "LibUser562")
    if not (lib and lib.RegisterSettings) then
        self.settingsUnavailable = true
        return
    end

    local listed = {}
    local function List(names)
        for i = 1, #names do
            local feature = self[names[i]]
            if feature then listed[feature] = true end
        end
    end
    List(MENU_ORDER)
    List(SOCIAL_ORDER)
    List(NESTED)
    local extra = {}
    for _, feature in ipairs(self.features) do
        if not listed[feature] then extra[#extra + 1] = feature end
    end

    local options = {}
    local function AddFeatures(list)
        for _, feature in ipairs(list) do
            if type(feature.GetOptions) == "function" then
                local featureOptions = feature:GetOptions()
                for i = 1, #featureOptions do
                    options[#options + 1] = featureOptions[i]
                end
            end
        end
    end
    for i = 1, #MENU_ORDER do
        local name = MENU_ORDER[i]
        if name == SOCIAL_MENU then
            local social = self:SocialMenu()
            if social then options[#options + 1] = social end
        elseif self[name] then
            AddFeatures({ self[name] })
        end
    end
    AddFeatures(extra)
    options[#options + 1] = self:SettingsMenu()

    local sv = self.savedVariables
    self.settingsPanel = lib:RegisterSettings({
        name            = "MyExtras",
        placement       = "main",
        menuAfter       = "SOCIAL",
        menuTitle       = AccentTitle,
        menuIcon        = ICON_MENU,
        title           = AccentTitle,
        author          = AccentAuthor,
        version         = self.version,
        frameColor      = FRAME_GREY,
        previewControls = function() return MyExtras:SettingsPreviewControls() end,
        textSize        = function() return sv.settingsFontSize end,
        textFont        = function()
            local font = sv.settingsFont
            if type(font) ~= "string" or font == "" or font == DEFAULT_FONT then return nil end
            return font
        end,
        windowOpacity   = function() return sv.settingsOpacity end,
        rememberPage    = function()
            return MyExtras.forcedPage ~= nil or sv.settingsRemember == true
                or MyExtras.keepPage == true or AnyMoving()
        end,
        lastPage        = function()
            if MyExtras.forcedPage then return MyExtras.forcedPage end
            if type(sv.settingsLastPage) ~= "table" then sv.settingsLastPage = {} end
            return sv.settingsLastPage
        end,
        accentColor     = function()
            if sv.settingsHighlight ~= "Custom" then return nil end
            local c = sv.settingsHighlightColor
            if type(c) ~= "table" then return nil end
            return c.r or 1, c.g or 1, c.b or 1
        end,
        options         = options,
    })
    if not self.settingsPanel then
        self.settingsUnavailable = true
        return
    end

    local scene = self.settingsPanel.scene
    if scene then
        scene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_HIDDEN and AnyMoving() then
                MyExtras.keepPage = true
                return
            end
            if newState == SCENE_SHOWN then
                MyExtras.keepPage = nil
            end
            if newState == SCENE_SHOWN or newState == SCENE_HIDDEN then
                MyExtras.forcedPage = nil
            end
            CallFeatures("OnSettingsState", newState)
        end)
    end
end

function MyExtras:OpenPage(option, row)
    local panel = self.settingsPanel
    if not (panel and panel.Open) then return false end
    local categories = panel.categories
    if type(categories) ~= "table" then return false end
    local index
    for i = 1, #categories do
        if categories[i] == option then
            index = i
            break
        end
    end
    if not index then return false end
    self.forcedPage = { cat = index, pane = 2, rows = { row or 1 } }
    panel:Open()
    return true
end

--------------------------------------------------
-- Main Menu
--------------------------------------------------
local MENU_ENTRY_ID   = "LibUser562_MyExtras"
local ADDONS_ENTRY_ID = "LibUser562_Addons"

local function EntryText(entry)
    local text = entry.text
    if (text == nil or text == "") and entry.data then text = entry.data.name end
    if type(text) == "function" then text = text() end
    return text
end

local function AddonsEntryIndex()
    for i = 1, #ZO_MENU_ENTRIES do
        if ZO_MENU_ENTRIES[i].id == ADDONS_ENTRY_ID then return i end
    end
    local title = GetString(SI_GAME_MENU_ADDONS)
    for i = 1, #ZO_MENU_ENTRIES do
        local entry = ZO_MENU_ENTRIES[i]
        if type(entry.subMenu) == "table" and EntryText(entry) == title then return i end
    end
    return nil
end

local function KeepBeforeAddons()
    if type(ZO_MENU_ENTRIES) ~= "table" then return end
    local own
    for i = 1, #ZO_MENU_ENTRIES do
        if ZO_MENU_ENTRIES[i].id == MENU_ENTRY_ID then own = i break end
    end
    if not own then return end
    local addons = AddonsEntryIndex()
    if not addons or own == addons - 1 then return end
    local entry = table.remove(ZO_MENU_ENTRIES, own)
    if own < addons then addons = addons - 1 end
    table.insert(ZO_MENU_ENTRIES, addons, entry)
    if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.UpdateEntryEnabledStates then
        MAIN_MENU_GAMEPAD:UpdateEntryEnabledStates()
    end
end

local function KeepBeforeAddonsSoon()
    zo_callLater(function() zo_callLater(KeepBeforeAddons, 0) end, 0)
end

local function WatchMainMenu()
    if MyExtras.mainMenuWatched or not MAIN_MENU_GAMEPAD_SCENE then return end
    MyExtras.mainMenuWatched = true
    MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then KeepBeforeAddonsSoon() end
    end)
end

--------------------------------------------------
-- Access
--------------------------------------------------
local ALLOWED_ACCOUNTS = { "user562", "SGT BEAR78FH", "Zavaki Akena" }

local function PlainAccount(name)
    local plain = tostring(name or "")
    plain = plain:gsub("^@", "")
    plain = plain:gsub("%s", "")
    return plain:lower()
end

local function IsAllowedAccount()
    if type(GetDisplayName) ~= "function" then return false end
    local mine = PlainAccount(GetDisplayName())
    if mine == "" then return false end
    for i = 1, #ALLOWED_ACCOUNTS do
        if PlainAccount(ALLOWED_ACCOUNTS[i]) == mine then return true end
    end
    return false
end

--------------------------------------------------
-- Load
--------------------------------------------------
local function OnAddonLoaded(event, addonName)
    if addonName ~= MyExtras.name then return end
    if not IsAllowedAccount() then
        EVENT_MANAGER:UnregisterForEvent(MyExtras.name, EVENT_ADD_ON_LOADED)
        return
    end

    MyExtras.freshInstall = MyExtras_SavedVars == nil

    MyExtras.savedVariables = ZO_SavedVars:NewAccountWide(
        "MyExtras_SavedVars",
        1,
        nil,
        MyExtras.defaults
    )

    local sv = MyExtras.savedVariables
    if not sv.settingsAccentSwitched then
        local c = MyExtras.defaults.settingsHighlightColor
        sv.settingsHighlight = "Custom"
        sv.settingsHighlightColor = { r = c.r, g = c.g, b = c.b, a = 1 }
        sv.settingsAccentSwitched = true
    end

    MyExtras.charVariables = ZO_SavedVars:NewCharacterIdSettings(
        "MyExtras_CharVars",
        1,
        nil,
        MyExtras.charDefaults
    )

    CallFeatures("Init")

    local settingsOk, settingsErr = pcall(function() MyExtras:CreateSettings() end)
    if not settingsOk then
        MyExtras.settingsUnavailable = true
        MyExtras.settingsError = tostring(settingsErr)
    end

    if settingsOk then WatchMainMenu() end

    EVENT_MANAGER:RegisterForEvent(MyExtras.name, EVENT_PLAYER_ACTIVATED,
        function(_, initial)
            CallFeatures("OnPlayerActivated", initial)
            KeepBeforeAddonsSoon()
        end)

    EVENT_MANAGER:UnregisterForEvent(MyExtras.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(MyExtras.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
