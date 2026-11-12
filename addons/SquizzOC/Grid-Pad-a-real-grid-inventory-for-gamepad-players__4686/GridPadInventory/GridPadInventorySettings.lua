-- Grid Pad - settings panel (registered in the game's AddOns menu via
-- LibAddonMenu-2.0, which is a declared DependsOn and must NOT be bundled).
-- Saved settings persist per-account.
local GPI = GridPadInventory
if not GPI then return end

local ADDON_NAME = "GridPadInventory"

-- Defaults for every persisted setting. Add new keys here as options grow.
local DEFAULTS = {
    hideCharacterPanel = false,
    simpleView = true,
    simplePosition = "center", -- "top" | "center" | "bottom" (all right-aligned)
    simpleOpacity = 0.85,      -- 0.30 (very see-through) .. 1.00 (solid)
    simpleFrost = 0.35,        -- 0.00 (none) .. 0.80 (heavy frosted dim)
    esoStyleCompare = false,   -- true = use ESO's native compare tooltips instead of ours
    sortByType = false,        -- simple-view sort button: group the grid by item type
    chatMessages = true,       -- false = no routine Grid Pad lines in chat (alerts still show)
    -- ESO Style Compare card geometry (screen/UI units). Tunable live via /gpi cmp*.
    cmpColX = 60,              -- left X of the first card
    cmpColW = 540,             -- width of each card (match a native currency bar)
    cmpColGap = 8,             -- gap between cards
    cmpTopY = 90,              -- top Y of the cards
    cmpBottomGap = 96,         -- space left at the bottom for the control bar
}

function GPI:ApplySettings()
    local sv = self.sv or {}
    -- Simple view owns layout + panel visibility; apply it first if the addon is ready.
    if self.ApplyLayout and self.simpleView ~= (sv.simpleView == true) then
        self.simpleView = sv.simpleView == true
        self:ApplyLayout()
    elseif self.charPanel then
        self.charPanel:SetHidden(sv.hideCharacterPanel == true)
    end
    if sv.hideCharacterPanel and self.selZone == "doll" then
        self.selZone = "grid"
    end
    if self.IsShowing and self:IsShowing() then self:Render() end
end

-- Load saved variables. Safe to call as soon as GridPad's own addon has loaded.
function GPI:InitSettings()
    if self.sv then return end
    -- Server-scoped (GetWorldName) so NA / EU / PTS settings do not overwrite each other.
    self.sv = ZO_SavedVars:NewAccountWide("GridPadInventory_SavedVars", 1, nil, DEFAULTS, GetWorldName())
    -- v1.4: simple view becomes the standard view. Flip existing saves once;
    -- full view stays reachable via /gpi view or the settings panel.
    if not self.sv.simpleDefaultMigrated then
        self.sv.simpleDefaultMigrated = true
        self.sv.simpleView = true
    end
    self:ApplySettings()
end

-- Register the LibAddonMenu panel. MUST be called only after LAM has initialized
-- (i.e. after at least one EVENT_ADD_ON_LOADED beyond GridPad's own). Idempotent.
function GPI:RegisterSettingsPanel()
    if self.settingsPanelRegistered then return end

    local LAM = _G["LibAddonMenu2"]
    if not LAM then
        d("[GridPad] LibAddonMenu-2.0 not found; the in-game settings panel is unavailable. Use /gpi slash commands instead.")
        return
    end

    if not self.sv then self:InitSettings() end

    local panelData = {
        type = "panel",
        name = "Grid Pad",
        displayName = "Grid Pad",
        author = "SquizzOC",
        version = tostring(self.version or "1.6.1"),
        slashCommand = "/gpisettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    local ok = pcall(function()
        LAM:RegisterAddonPanel(ADDON_NAME .. "_Panel", panelData)
    end)
    if not ok then
        d("[GridPad] Could not register the settings panel this session.")
        return
    end

    local optionsTable = {
        {
            type = "header",
            name = "Layout",
        },
        {
            type = "checkbox",
            name = "Hide character panel",
            tooltip = "Hides the left-hand equipped-gear character panel. The item grid keeps its position; you can still compare and view gear from the grid.",
            getFunc = function() return self.sv.hideCharacterPanel end,
            setFunc = function(value)
                self.sv.hideCharacterPanel = value
                self:ApplySettings()
            end,
            default = DEFAULTS.hideCharacterPanel,
            disabled = function() return self.sv.simpleView == true end,
        },
        {
            type = "checkbox",
            name = "Simple view (compact grid)",
            tooltip = "Switches to a dense icon-only grid with a filter icon bar across the top and both side panels hidden -- closer to a classic inventory grid. LB/RB still cycle every filter; the icon bar covers the main categories.",
            getFunc = function() return self.sv.simpleView end,
            setFunc = function(value)
                self.sv.simpleView = value
                if self.SetSimpleView then self:SetSimpleView(value) else self:ApplySettings() end
            end,
            default = DEFAULTS.simpleView,
        },
        {
            type = "dropdown",
            name = "Simple view position",
            tooltip = "Where the compact grid sits, always aligned to the right edge of the screen: Upper Right, Centered, or Lower Right.",
            choices = { "Upper Right", "Centered", "Lower Right" },
            choicesValues = { "top", "center", "bottom" },
            getFunc = function() return self.sv.simplePosition or DEFAULTS.simplePosition end,
            setFunc = function(value)
                self.sv.simplePosition = value
                if self.ApplyLayout then self:ApplyLayout() end
                if self.IsShowing and self:IsShowing() then self:Render() end
            end,
            default = DEFAULTS.simplePosition,
            disabled = function() return self.sv.simpleView ~= true end,
        },
        {
            type = "slider",
            name = "Simple view opacity",
            tooltip = "How solid the Simple View surfaces are (grid frame, cells, and the LT info panel). Lower = more see-through; higher = more solid.",
            min = 30,
            max = 100,
            step = 5,
            getFunc = function() return math.floor(((self.sv.simpleOpacity or DEFAULTS.simpleOpacity) * 100) + 0.5) end,
            setFunc = function(value)
                self.sv.simpleOpacity = value / 100
                if self.ApplyLayout then self:ApplyLayout() end
                if self.IsShowing and self:IsShowing() then self:Render() end
            end,
            default = math.floor(DEFAULTS.simpleOpacity * 100 + 0.5),
            disabled = function() return self.sv.simpleView ~= true end,
        },
        {
            type = "slider",
            name = "Simple view frost",
            tooltip = "Frosted-glass effect on the LT info panel: darkens and softens what shows through behind it, like the native Currencies panel. 0 = off.",
            min = 0,
            max = 80,
            step = 5,
            getFunc = function() return math.floor(((self.sv.simpleFrost or DEFAULTS.simpleFrost) * 100) + 0.5) end,
            setFunc = function(value)
                self.sv.simpleFrost = value / 100
                if self.IsShowing and self:IsShowing() then self:Render() end
            end,
            default = math.floor(DEFAULTS.simpleFrost * 100 + 0.5),
            disabled = function() return self.sv.simpleView ~= true end,
        },
        {
            type = "checkbox",
            name = "ESO Style Compare",
            tooltip = "When comparing (RT), use ESO's own native comparison tooltips instead of GridPad's custom compare window.",
            getFunc = function() return self.sv.esoStyleCompare == true end,
            setFunc = function(value)
                self.sv.esoStyleCompare = value
                if self.HideCompare then self:HideCompare() end
            end,
            default = DEFAULTS.esoStyleCompare,
        },
        {
            type = "header",
            name = "Chat",
        },
        {
            type = "checkbox",
            name = "Chat messages",
            tooltip = "Show Grid Pad's status lines in the chat window (equipped, deposited, withdrew, loaded, and so on). Turn off for a quiet chat. On-screen alerts in the top-right corner still appear, and replies to /gpi commands you type always show.",
            getFunc = function() return self.sv.chatMessages ~= false end,
            setFunc = function(value) self.sv.chatMessages = (value == true) end,
            default = DEFAULTS.chatMessages,
        },
    }
    LAM:RegisterOptionControls(ADDON_NAME .. "_Panel", optionsTable)

    self.settingsPanelRegistered = true
    if self.sv.chatMessages ~= false then
        d("[GridPad] Settings panel registered. Find it in Settings > Add-Ons > Grid Pad, or type /gpisettings.")
    end
end

-- Deferred registration: fire on the FIRST addon-loaded event AFTER GridPad's own,
-- which guarantees LibAddonMenu has run its initialization. If GridPad happens to
-- be the last addon, fall back to EVENT_PLAYER_ACTIVATED.
do
    local EM = EVENT_MANAGER
    local handle = "GridPadInventory_SettingsDefer"
    local registered = false
    local function tryRegister()
        if registered then return end
        registered = true
        EM:UnregisterForEvent(handle, EVENT_ADD_ON_LOADED)
        EM:UnregisterForEvent(handle, EVENT_PLAYER_ACTIVATED)
        GPI:RegisterSettingsPanel()
    end
    EM:RegisterForEvent(handle, EVENT_ADD_ON_LOADED, function(_, name)
        -- Any addon load after ours means the manager has advanced past GridPad;
        -- LAM (which loads as our bundled dependency) is initialized by now.
        if name ~= ADDON_NAME then tryRegister() end
    end)
    -- Safety net: guaranteed to have everything loaded by the time we're in-world.
    EM:RegisterForEvent(handle, EVENT_PLAYER_ACTIVATED, tryRegister)
end
