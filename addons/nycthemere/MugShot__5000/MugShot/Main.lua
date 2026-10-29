-- =========================================================
-- MugShot - Main  (Main.lua)
-- Bootstrap entry point.
-- Assembles all modules on EVENT_ADD_ON_LOADED and registers
-- two-word slash commands for runtime control.
-- =========================================================

local C = MugShot.Constants

-- ── Bootstrap ─────────────────────────────────────────────
-- All assembly happens inside this callback so that ESO has
-- fully initialised SavedVariables and UI controls before
-- we touch them.
local function OnAddonLoaded(_eventCode, addonName)
    if addonName ~= C.ADDON_NAME then return end

    -- Unregister immediately — we only need this once
    EVENT_MANAGER:UnregisterForEvent(C.ADDON_NAME .. "_Load", EVENT_ADD_ON_LOADED)

    MugShot.logger:Info("=== MugShot %s by %s — initialising ===",
        C.ADDON_VERSION, C.AUTHOR)

    -- Discover all registered companions from Collectibles
    if MugShot.Portraits and MugShot.Portraits.RegisterCompanionCollectibles then
        MugShot.Portraits.RegisterCompanionCollectibles()
    end

    if EVENT_PLAYER_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent(C.ADDON_NAME .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
            if MugShot.Portraits and MugShot.Portraits.RegisterCompanionCollectibles then
                MugShot.Portraits.RegisterCompanionCollectibles()
            end
        end)
    end
    if EVENT_COMPANION_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent(C.ADDON_NAME .. "_CompanionActivated", EVENT_COMPANION_ACTIVATED, function()
            if MugShot.Portraits and MugShot.Portraits.RegisterCompanionCollectibles then
                MugShot.Portraits.RegisterCompanionCollectibles()
            end
        end)
    end

    -- ── 1. Settings ──────────────────────────────────────
    local settings = MugShot.Settings.New()
    settings:Load()
    MugShot.settings = settings   -- stash for drag-save in TargetFrameView

    -- ── 2. Core objects ───────────────────────────────────
    local state         = MugShot.TargetState.New()
    local adapter       = MugShot.EsoAdapter.New()
    local eventBindings = MugShot.EventBindings.New()
    local nativeBridge  = MugShot.NativeFrameBridge.New()
    local view          = MugShot.TargetFrameView.New()

    -- Apply saved position immediately
    view:ApplyLayout(settings:Get())

    -- ── 3. Controller ─────────────────────────────────────
    local controller = MugShot.TargetController.New({
        state         = state,
        adapter       = adapter,
        eventBindings = eventBindings,
        nativeBridge  = nativeBridge,
        view          = view,
        settings      = settings,
    })

    -- Stash references for tests and commands
    MugShot._controller   = controller
    MugShot._view         = view
    MugShot._nativeBridge = nativeBridge

    -- ── 4. Start (if enabled) ─────────────────────────────
    if settings:Get().enabled then
        controller:Start()
    else
        MugShot.logger:Info(MugShot.GetText("DISABLED_HELP"))
    end

    -- ── 5. Slash commands (/mugshot <action>) ──────────────
    local handlers = {
        toggle = function(arg)
            local current = settings:Get()
            local nowEnabled
            if arg == "on" then nowEnabled = true
            elseif arg == "off" then nowEnabled = false
            else nowEnabled = not current.enabled end

            settings:Set("enabled", nowEnabled)
            if nowEnabled then
                controller:Start()
                CHAT_SYSTEM:AddMessage(MugShot.GetText("ENABLED"))
            else
                controller:Stop()
                CHAT_SYSTEM:AddMessage(MugShot.GetText("DISABLED"))
            end
        end,

        move = function()
            local current = settings:Get()
            local nowLocked = not current.locked
            settings:Set("locked", nowLocked)
            controller:SetMoveMode(not nowLocked)

            if nowLocked then
                pcall(function() SetGameCameraUIMode(false) end)
                CHAT_SYSTEM:AddMessage(MugShot.GetText("FRAME_LOCKED"))
            else
                pcall(function() SetGameCameraUIMode(true) end)
                CHAT_SYSTEM:AddMessage(MugShot.GetText("FRAME_UNLOCKED"))
            end
        end,

        reset = function()
            local defaultPos = {
                point         = TOPLEFT,
                relativePoint = TOPLEFT,
                offsetX       = 100,
                offsetY       = 200,
            }
            settings:Set("position", defaultPos)
            settings:Set("locked", false)
            view:ApplyLayout(settings:Get())
            controller:SetMoveMode(true)
            pcall(function() SetGameCameraUIMode(true) end)
            CHAT_SYSTEM:AddMessage(MugShot.GetText("POSITION_RESET"))
        end,

        trial = function(arg)
            local current = settings:Get()
            local nowFilter
            if arg == "on" then nowFilter = true
            elseif arg == "off" then nowFilter = false
            else nowFilter = not current.onlyHostileInTrials end

            settings:Set("onlyHostileInTrials", nowFilter)
            if nowFilter then
                CHAT_SYSTEM:AddMessage(MugShot.GetText("TRIAL_FILTER_ENABLED"))
            else
                CHAT_SYSTEM:AddMessage(MugShot.GetText("TRIAL_FILTER_DISABLED"))
            end
            controller:RefreshTarget()
        end,

        hodor = function()
            local current = settings:Get().useHodorIcons
            if current == nil then current = true end
            local newState = not current
            settings:Set("useHodorIcons", newState)
            if newState then
                CHAT_SYSTEM:AddMessage(MugShot.GetText("HODOR_ICONS_ENABLED"))
            else
                CHAT_SYSTEM:AddMessage(MugShot.GetText("HODOR_ICONS_DISABLED"))
            end
            controller:RefreshIdentity(true)
        end,

        help = function()
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_TITLE"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_TOGGLE"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_MOVE"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_RESET"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_TRIAL"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_HODOR"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_HELP"))
        end,
    }

    local function CommandDispatcher(extra)
        local raw = extra or ""
        local action, param = string.match(raw, "^%s*(%S+)%s*(%S*)")
        action = action and string.lower(action) or ""
        param  = param and string.lower(param) or ""

        if action == "" or action == "help" or action == "?" then
            handlers.help()
        elseif handlers[action] then
            handlers[action](param)
        else
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_UNKNOWN", action))
        end
    end

    -- In-game autocompletion via LibSlashCommander if installed
    if LibSlashCommander and LibSlashCommander.Register then
        local cmd = LibSlashCommander:Register("/mugshot", CommandDispatcher, MugShot.GetText("CMD_HELP_TITLE"))
        if cmd and cmd.RegisterSubCommand then
            local function AddSub(alias, callback, description)
                local sub = cmd:RegisterSubCommand()
                sub:AddAlias(alias)
                sub:SetCallback(callback)
                sub:SetDescription(description)
            end

            AddSub("toggle", handlers.toggle, MugShot.GetText("CMD_HELP_TOGGLE"))
            AddSub("move",   handlers.move,   MugShot.GetText("CMD_HELP_MOVE"))
            AddSub("reset",  handlers.reset,  MugShot.GetText("CMD_HELP_RESET"))
            AddSub("trial",  handlers.trial,  MugShot.GetText("CMD_HELP_TRIAL"))
            AddSub("hodor",  handlers.hodor,  MugShot.GetText("CMD_HELP_HODOR"))
            AddSub("help",   handlers.help,   MugShot.GetText("CMD_HELP_HELP"))
        end
    end

    -- Primary native slash command registration
    SLASH_COMMANDS["/mugshot"] = CommandDispatcher

    MugShot.logger:Info("=== MugShot initialisation complete ===")
end

-- Register the load listener (filtered to our addon name for efficiency)
EVENT_MANAGER:RegisterForEvent(
    MugShot.Constants.ADDON_NAME .. "_Load",
    EVENT_ADD_ON_LOADED,
    OnAddonLoaded)
