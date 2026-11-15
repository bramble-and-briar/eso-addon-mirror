-- Settings (LibAddonMenu-2.0, optional: without it the addon works with its defaults and the window's own buttons).

local WWS = WhoWantsSpaulder
local D = WWS.DEFAULTS

function WWS.SetupSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end
    local sv = WWS.sv

    LAM:RegisterAddonPanel("WhoWantsSpaulder_Settings", {
        type = "panel",
        name = "Who Wants Spaulder?",
        displayName = "|cF3D27AWho Wants Spaulder?|r",
        author = "SkullElf",
        version = WWS.version,
        slashCommand = "/spaulderset",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local profileChoices = {}
    local profileToDelete
    local function RefreshProfileChoices()
        profileChoices = WWS.ProfileNames()
        if profileToDelete and not sv.profiles[profileToDelete] then profileToDelete = nil end
        local dd = WhoWantsSpaulder_SettingsProfileDropdown
        if dd and dd.UpdateChoices then dd:UpdateChoices(profileChoices) end
    end
    RefreshProfileChoices()
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if panel and panel.data and panel.data.name == "Who Wants Spaulder?" then RefreshProfileChoices() end
    end)

    local function Look() WWS.ApplyLook() end

    LAM:RegisterOptionControls("WhoWantsSpaulder_Settings", {
        {
            type = "description",
            text = "Mark the group members who shouldn't keep the Spaulder of Ruin's Aura of Pride, then press Reinvite "
                .. "(or the keybind): each is kicked and invited straight back, which takes the buff off them. "
                .. "Open the window with /spaulder or a keybind (Controls > Who Wants Spaulder?).",
        },
        {
            type = "button",
            name = "Open the window",
            func = function() WWS.ShowWindow() end,
            width = "half",
        },

        { type = "header", name = "Reinvite" },
        {
            type = "slider",
            name = "Wait before inviting back (ms)",
            tooltip = "Time between the kick and the invite. Inviting sooner than 1000 ms doesn't register (the game "
                .. "still sees them in the group), so it can't go lower. Raise it if invites fail on a laggy connection.",
            min = WWS.MIN_DELAY, max = 5000, step = 100,
            getFunc = function() return sv.reinviteDelay end,
            setFunc = function(v) sv.reinviteDelay = math.max(WWS.MIN_DELAY, v) end,
            default = D.reinviteDelay,
        },
        {
            type = "checkbox",
            name = "Remember marks after /reloadui and logging out",
            tooltip = "Off: the marks last for this session only (as in 1.0).",
            getFunc = function() return sv.rememberChecks end,
            setFunc = function(v)
                -- carry the current marks over to the other store
                local from = WWS.Checks()
                sv.rememberChecks = v
                local to = WWS.Checks()
                if from ~= to then
                    for n in pairs(to) do to[n] = nil end
                    for n in pairs(from) do to[n] = true end
                end
                WWS.Refresh()
            end,
            default = D.rememberChecks,
        },
        {
            type = "button",
            name = "Clear all marks",
            func = function()
                local c = WWS.Checks()
                for n in pairs(c) do c[n] = nil end
                WWS.Refresh()
            end,
            width = "half",
        },
        {
            type = "checkbox",
            name = "Chat messages",
            tooltip = "Who is being reinvited, loadouts saved and loaded. Problems (not the leader, nobody marked) are always shown.",
            getFunc = function() return sv.chatMessages end,
            setFunc = function(v) sv.chatMessages = v end,
            default = D.chatMessages,
        },

        { type = "header", name = "Group menu" },
        {
            type = "checkbox",
            name = "Show the window with the group menu",
            getFunc = function() return sv.openWithGroupMenu end,
            setFunc = function(v) sv.openWithGroupMenu = v; WWS.UpdateGroupMenu() end,
            default = D.openWithGroupMenu,
        },
        {
            type = "checkbox",
            name = "...only when I'm the group leader",
            getFunc = function() return sv.groupMenuLeaderOnly end,
            setFunc = function(v) sv.groupMenuLeaderOnly = v; WWS.UpdateGroupMenu() end,
            disabled = function() return not sv.openWithGroupMenu end,
            default = D.groupMenuLeaderOnly,
        },
        {
            type = "slider",
            name = "...in groups of at least",
            tooltip = "The Aura of Pride reaches up to 6 members: in smaller groups there is nothing to choose.",
            min = 2, max = 12, step = 1,
            getFunc = function() return sv.groupMenuMinSize end,
            setFunc = function(v) sv.groupMenuMinSize = v; WWS.UpdateGroupMenu() end,
            disabled = function() return not sv.openWithGroupMenu end,
            default = D.groupMenuMinSize,
        },

        { type = "header", name = "Window" },
        {
            type = "checkbox",
            name = "Lock the position",
            getFunc = function() return sv.locked end,
            setFunc = function(v) sv.locked = v; Look() end,
            default = D.locked,
        },
        {
            type = "slider",
            name = "Size",
            min = 70, max = 150, step = 5,
            getFunc = function() return math.floor((sv.scale or 1) * 100 + 0.5) end,
            setFunc = function(v) sv.scale = v / 100; Look() end,
            default = D.scale * 100,
        },
        {
            type = "slider",
            name = "Background opacity",
            min = 0, max = 100, step = 5,
            getFunc = function() return math.floor((sv.bgAlpha or 0.85) * 100 + 0.5) end,
            setFunc = function(v) sv.bgAlpha = v / 100; Look() end,
            default = D.bgAlpha * 100,
        },
        {
            type = "button",
            name = "Reset the position",
            func = function() WWS.ResetPosition() end,
            width = "half",
        },

        { type = "header", name = "Loadouts" },
        {
            type = "description",
            text = "Save, load and delete loadouts in the window. A loadout is a list of names: loading it marks exactly "
                .. "those members (whoever of them is in the group).",
        },
        {
            type = "dropdown",
            name = "Loadout",
            choices = profileChoices,
            getFunc = function() return profileToDelete end,
            setFunc = function(v) profileToDelete = v end,
            reference = "WhoWantsSpaulder_SettingsProfileDropdown",
            width = "half",
        },
        {
            type = "button",
            name = "Delete this loadout",
            func = function()
                if profileToDelete then
                    WWS.DeleteProfile(profileToDelete)
                    profileToDelete = nil
                    RefreshProfileChoices()
                end
            end,
            isDangerous = true,
            warning = "The loadout is deleted for good.",
            disabled = function() return profileToDelete == nil end,
            width = "half",
        },
    })
end
