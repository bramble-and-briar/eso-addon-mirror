-- =========================================================
-- MugShot - Main  (Main.lua)
-- Entry point and initialization orchestrator.
-- Listens to EVENT_ADD_ON_LOADED and registers slash commands.
-- =========================================================

local MugShot = MugShot

-- ── Event Callback ────────────────────────────────────────
local function OnAddonLoaded(_eventCode, addonName)
    if addonName ~= MugShot.Constants.ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(
        MugShot.Constants.ADDON_NAME .. "_Load",
        EVENT_ADD_ON_LOADED
    )

    if MugShot.InitLanguage then
        MugShot.InitLanguage()
    end

    -- ── Instantiate Dependencies ──────────────────────────
    local settings = MugShot.Settings.New()
    settings:Load()
    MugShot.settings = settings

    local state         = MugShot.TargetState.New()
    local adapter       = MugShot.EsoAdapter.New()
    local eventBindings = MugShot.EventBindings.New(adapter)
    local nativeBridge  = MugShot.NativeFrameBridge.New()
    local view          = MugShot.TargetFrameView.New()

    local controller = MugShot.TargetController.New({
        state         = state,
        adapter       = adapter,
        eventBindings = eventBindings,
        nativeBridge  = nativeBridge,
        view          = view,
        settings      = settings,
    })

    -- Wire up bidirectional bridge between View and Controller
    view._controller = controller
    MugShot._controller = controller
    MugShot._view = view
    MugShot._nativeBridge = nativeBridge

    -- Apply saved layout and position
    view:ApplyLayout(settings:Get())

    -- Respect the master enabled setting
    if settings:Get().enabled then
        controller:Start()
    else
        controller:Stop()
    end

    -- If the frame was saved in an unlocked state, restore Move Mode on reload
    if not settings:Get().locked then
        controller:SetMoveMode(true, "enemy")
        SetGameCameraUIMode(true)
        CHAT_SYSTEM:AddMessage(MugShot.GetText("FRAME_UNLOCKED"))
    end

    -- ── Slash Command Handlers ────────────────────────────
    local handlers = {
        toggle = function()
            local current = settings:Get().enabled
            local newState = not current
            settings:Set("enabled", newState)

            if newState then
                controller:Start()
                CHAT_SYSTEM:AddMessage(MugShot.GetText("ENABLED"))
            else
                controller:Stop()
                CHAT_SYSTEM:AddMessage(MugShot.GetText("DISABLED"))
            end
        end,

        move = function(param)
            local current = settings:Get()
            param = param and string.lower(param) or ""

            if param == "enemy" or param == "boss" then
                if current.locked then
                    settings:Set("locked", false)
                    SetGameCameraUIMode(true)
                    CHAT_SYSTEM:AddMessage(MugShot.GetText("FRAME_UNLOCKED"))
                end
                controller:SetMoveMode(true, "enemy")
                return
            elseif param == "player" or param == "self" then
                if current.locked then
                    settings:Set("locked", false)
                    SetGameCameraUIMode(true)
                    CHAT_SYSTEM:AddMessage(MugShot.GetText("FRAME_UNLOCKED"))
                end
                controller:SetMoveMode(true, "player")
                return
            elseif param == "toggle" then
                if not current.locked and controller:IsInMoveMode() then
                    controller:ToggleMoveModeTarget()
                    return
                end
            end

            local nowLocked = not current.locked
            settings:Set("locked", nowLocked)
            controller:SetMoveMode(not nowLocked, "enemy")

            if nowLocked then
                SetGameCameraUIMode(false)
                CHAT_SYSTEM:AddMessage(MugShot.GetText("FRAME_LOCKED"))
            else
                SetGameCameraUIMode(true)
                CHAT_SYSTEM:AddMessage(MugShot.GetText("FRAME_UNLOCKED"))
            end
        end,

        reset = function()
            local defaultPos = MugShot.Defaults.position
            settings:Set("position", defaultPos)
            settings:Set("locked", false)
            view:ApplyLayout(settings:Get())
            controller:SetMoveMode(true, "enemy")
            SetGameCameraUIMode(true)
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

        debuffs = function(arg)
            local current = settings:Get()
            local nowTrack
            if arg == "on" then nowTrack = true
            elseif arg == "off" then nowTrack = false
            else nowTrack = not (current.trackGroupDebuffs ~= false) end

            settings:Set("trackGroupDebuffs", nowTrack)
            if nowTrack then
                CHAT_SYSTEM:AddMessage(MugShot.GetText("GROUP_DEBUFFS_ENABLED"))
            else
                CHAT_SYSTEM:AddMessage(MugShot.GetText("GROUP_DEBUFFS_DISABLED"))
            end
            controller:RefreshEffects()
        end,

        layout = function(arg)
            local current = settings:Get()
            arg = arg and string.lower(arg) or ""
            local newLayout
            if arg == "classic" or arg == "on" or arg == "2" then
                newLayout = "classic"
            elseif arg == "compact" or arg == "off" or arg == "3" then
                newLayout = "compact"
            else
                newLayout = (current.layout == "classic") and "compact" or "classic"
            end

            settings:Set("layout", newLayout)
            controller:SetLayout(newLayout)
            if newLayout == "classic" then
                CHAT_SYSTEM:AddMessage(MugShot.GetText("LAYOUT_CLASSIC"))
            else
                CHAT_SYSTEM:AddMessage(MugShot.GetText("LAYOUT_COMPACT"))
            end
        end,

        classic = function(arg)
            local current = settings:Get()
            local nowClassic
            if arg == "on" then nowClassic = true
            elseif arg == "off" then nowClassic = false
            else nowClassic = not (current.layout == "classic") end

            local newLayout = nowClassic and "classic" or "compact"
            settings:Set("layout", newLayout)
            controller:SetLayout(newLayout)
            if nowClassic then
                CHAT_SYSTEM:AddMessage(MugShot.GetText("LAYOUT_CLASSIC"))
            else
                CHAT_SYSTEM:AddMessage(MugShot.GetText("LAYOUT_COMPACT"))
            end
        end,

        help = function()
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_TITLE"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_TOGGLE"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_MOVE"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_RESET"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_LAYOUT"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_CLASSIC"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_TRIAL"))
            CHAT_SYSTEM:AddMessage(MugShot.GetText("CMD_HELP_DEBUFFS"))
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
    if LibSlashCommander then
        local cmd = LibSlashCommander:Register("/mugshot", CommandDispatcher, MugShot.GetText("CMD_HELP_TITLE"))
        if cmd and cmd.RegisterSubCommand then
            local function AddSub(alias, callback, description)
                local sub = cmd:RegisterSubCommand()
                sub:AddAlias(alias)
                sub:SetCallback(callback)
                sub:SetDescription(description)
            end

            AddSub("toggle",  handlers.toggle,  MugShot.GetText("CMD_HELP_TOGGLE"))
            AddSub("move",    handlers.move,    MugShot.GetText("CMD_HELP_MOVE"))
            AddSub("reset",   handlers.reset,   MugShot.GetText("CMD_HELP_RESET"))
            AddSub("layout",  handlers.layout,  MugShot.GetText("CMD_HELP_LAYOUT"))
            AddSub("classic", handlers.classic, MugShot.GetText("CMD_HELP_CLASSIC"))
            AddSub("trial",   handlers.trial,   MugShot.GetText("CMD_HELP_TRIAL"))
            AddSub("debuffs", handlers.debuffs, MugShot.GetText("CMD_HELP_DEBUFFS"))
            AddSub("hodor",   handlers.hodor,   MugShot.GetText("CMD_HELP_HODOR"))
            AddSub("help",   handlers.help,   MugShot.GetText("CMD_HELP_HELP"))
        end
    end

    -- Primary native slash command registration
    SLASH_COMMANDS["/mugshot"] = CommandDispatcher

    MugShot.logger:Info("=== MugShot initialisation complete ===")
end

-- Register the load listener
EVENT_MANAGER:RegisterForEvent(
    MugShot.Constants.ADDON_NAME .. "_Load",
    EVENT_ADD_ON_LOADED,
    OnAddonLoaded)
