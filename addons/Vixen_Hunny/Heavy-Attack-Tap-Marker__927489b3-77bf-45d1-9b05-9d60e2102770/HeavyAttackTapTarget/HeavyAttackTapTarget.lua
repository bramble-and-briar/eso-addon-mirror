-- Heavy Attack Tap Target
-- Marks the enemy you heavy attack with a target marker and removes the
-- marker again once that enemy dies.
--
-- Why a target marker and not a real tab target: the game function that sets
-- the tab ("preferred") target is private, so addons cannot call it.

local ADDON = "HeavyAttackTapTarget"
local RETICLE = "reticleover"
local em = EVENT_MANAGER

local MARKERS = {
    TARGET_MARKER_TYPE_ONE, TARGET_MARKER_TYPE_TWO, TARGET_MARKER_TYPE_THREE,
    TARGET_MARKER_TYPE_FOUR, TARGET_MARKER_TYPE_FIVE, TARGET_MARKER_TYPE_SIX,
    TARGET_MARKER_TYPE_SEVEN, TARGET_MARKER_TYPE_EIGHT,
}

local MARKER_NAMES = {
    "Square", "Star", "Orb / Circle", "Triangle",
    "Moon", "Oblivion", "Crossed Swords", "Skull",
}

local defaults = {
    enabled = true,
    marker = 1, -- index into MARKERS
    leaderOnly = true, -- in a group, only mark while you are the leader
    bgEveryone = true, -- battlegrounds pick the leader at random, so ignore leaderOnly there
    useCaller = true,  -- follow the group's caller (needs LibGroupBroadcast)
    playersOnly = false, -- only mark enemy players, never monsters
}

local sv
local markedUnitId       -- combat unit id of the enemy carrying our marker
local pendingClear = false -- marked enemy died while we were not looking at it
local lastAssignMs = 0
local ASSIGN_COOLDOWN_MS = 500 -- the marker state lags a moment behind the assign call

local function Print(text, ...)
    CHAT_ROUTER:AddSystemMessage("|cffaa33[HeavyAttackTapTarget]|r " .. string.format(text, ...))
end

local function MarkerType()
    return MARKERS[sv.marker] or MARKERS[1]
end

local function ReticleHasOurMarker()
    return DoesUnitExist(RETICLE) and GetUnitTargetMarkerType(RETICLE) == MarkerType()
end

---------------------------------------------------------------------------
-- Caller
---------------------------------------------------------------------------
-- A caller is one group member whose heavy attacks set the mark for the
-- whole group. Anyone running the addon can claim the role; the claim is
-- sent to the other addon users through LibGroupBroadcast and the latest
-- claim wins. While a caller is set, nobody else's addon places markers.
--
-- NOTE: LibGroupBroadcast protocol ids must be unique across all addons and
-- reserved at https://wiki.esoui.com/LibGroupBroadcast_IDs before a public
-- release. This id has NOT been reserved yet.
local CALLER_PROTOCOL_ID = 717
local REBROADCAST_DELAY_MS = 2000

local callerName     -- @display name of the current caller, nil when there is none
local callerProtocol -- nil when LibGroupBroadcast is missing or the id is taken
local RefreshSettings = function() end -- replaced once the settings panel exists

local function IsCallerMe()
    return callerName ~= nil and callerName == GetDisplayName()
end

local function IsInMyGroup(displayName)
    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        if unitTag and GetUnitDisplayName(unitTag) == displayName then return true end
    end
    return false
end

local function SendCallerState(isCaller)
    if not callerProtocol or not IsUnitGrouped("player") then return false end
    return callerProtocol:Send({ claim = isCaller })
end

local function OnCallerData(unitTag, data)
    if not DoesUnitExist(unitTag) then return end
    local name = GetUnitDisplayName(unitTag)
    if not name or name == "" then return end
    -- The caller is still remembered while the feature is off, so switching
    -- it back on picks up the group's current caller straight away.
    if data.claim then
        if callerName ~= name then
            callerName = name
            if sv.useCaller then Print("%s is now the caller", name) end
        end
    elseif callerName == name then
        callerName = nil
        if sv.useCaller then Print("%s is no longer the caller", name) end
    end
    RefreshSettings()
end

local function ClaimCaller()
    if not sv.useCaller then
        Print("the caller feature is turned off in the settings")
    elseif not callerProtocol then
        Print("the caller feature needs LibGroupBroadcast")
    elseif not IsUnitGrouped("player") then
        Print("join a group before becoming the caller")
    else
        callerName = GetDisplayName()
        SendCallerState(true)
        Print("you are now the caller")
    end
    RefreshSettings()
end

local function ReleaseCaller()
    if IsCallerMe() then
        callerName = nil
        SendCallerState(false)
        Print("you are no longer the caller")
    else
        Print("you are not the caller")
    end
    RefreshSettings()
end

-- Turning the feature off while you are the caller hands the role back, so
-- the rest of the group is not left waiting on marks that will never come.
local function SetUseCaller(value)
    if not value and IsCallerMe() then ReleaseCaller() end
    sv.useCaller = value
    RefreshSettings()
end

-- Someone who joins late has not heard the claim, so the caller repeats it.
local function OnGroupMemberJoined()
    if not IsCallerMe() then return end
    zo_callLater(function()
        if IsCallerMe() then SendCallerState(true) end
    end, REBROADCAST_DELAY_MS)
end

local function InitializeCaller()
    local LGB = LibGroupBroadcast
    if not LGB then return end

    -- Declaring throws when another addon already uses the id or name.
    local ok, err = pcall(function()
        local handler = LGB:RegisterHandler(ADDON)
        handler:SetDisplayName("Heavy Attack Tap Target")
        handler:SetDescription("Shares who the group's marking caller is.")

        local protocol = handler:DeclareProtocol(CALLER_PROTOCOL_ID, "HeavyAttackTapTargetCaller")
        protocol:AddField(LGB.CreateFlagField("claim"))
        protocol:OnData(OnCallerData)
        protocol:Finalize({ isRelevantInCombat = true, replaceQueuedMessages = true })
        callerProtocol = protocol
    end)
    if not ok then
        Print("caller feature disabled: %s", tostring(err))
        return
    end

    em:RegisterForEvent(ADDON, EVENT_GROUP_MEMBER_JOINED, OnGroupMemberJoined)
end

-- Who may place markers:
--   solo            -> always you
--   caller is set   -> only the caller
--   otherwise       -> the "leader only" and battleground rules
local function CanMark()
    if not IsUnitGrouped("player") then
        callerName = nil
        return true
    end
    if callerName and not IsInMyGroup(callerName) then
        callerName = nil -- the caller left the group
    end
    if callerName and sv.useCaller then return IsCallerMe() end
    if not sv.leaderOnly then return true end
    if sv.bgEveryone and IsActiveWorldBattleground() then return true end
    return IsUnitGroupLeader("player")
end

-- Assigning the marker a unit already has toggles it off.
local function ToggleOnReticle()
    AssignTargetMarkerToReticleTarget(MarkerType())
    lastAssignMs = GetFrameTimeMilliseconds()
end

---------------------------------------------------------------------------
-- Marking on heavy attack
---------------------------------------------------------------------------
local function OnPlayerCombatEvent(_, _, _, _, _, slotType, _, _, targetName, targetType, _, _, _, _, _, targetUnitId)
    if slotType ~= ACTION_SLOT_TYPE_HEAVY_ATTACK or not sv.enabled then return end
    if targetUnitId == 0 or targetType == COMBAT_UNIT_TYPE_PLAYER then return end
    if not DoesUnitExist(RETICLE) or IsUnitDead(RETICLE) or not IsUnitAttackable(RETICLE) then return end
    -- Enemies only: hostile (red) monsters and enemy players. Skips neutral
    -- (yellow) creatures and citizens, which are attackable but not enemies.
    if GetUnitReaction(RETICLE) ~= UNIT_REACTION_HOSTILE then return end
    if sv.playersOnly and not IsUnitPlayer(RETICLE) then return end
    -- Heavy attacks can splash; only accept the hit on the enemy under the crosshair.
    if targetName ~= "" and targetName ~= GetRawUnitName(RETICLE) then return end

    local current = GetUnitTargetMarkerType(RETICLE)
    if current == MarkerType() then
        markedUnitId = targetUnitId
        pendingClear = false
        return
    end
    if current ~= TARGET_MARKER_TYPE_NONE then return end -- leave other markers alone
    if not CanMark() then return end
    if GetFrameTimeMilliseconds() - lastAssignMs < ASSIGN_COOLDOWN_MS then return end

    ToggleOnReticle()
    markedUnitId = targetUnitId
    pendingClear = false
end

---------------------------------------------------------------------------
-- Removing on death
---------------------------------------------------------------------------
-- A marker can only be changed on the unit under the crosshair, so if the
-- enemy dies while we look elsewhere the removal waits until we look at it.
local function TryClear()
    if not pendingClear then return end
    if ReticleHasOurMarker() then
        ToggleOnReticle()
        pendingClear = false
    end
end

local function OnDeath(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, targetUnitId)
    if not markedUnitId or targetUnitId ~= markedUnitId then return end
    markedUnitId = nil
    pendingClear = true
    TryClear()
end

local function OnReticleChanged()
    if pendingClear and DoesUnitExist(RETICLE) and IsUnitDead(RETICLE) then
        TryClear()
    end
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
-- Switching marker forgets the old one: the addon only ever tracks the
-- marker type that is currently selected.
local function SetMarker(index)
    if index == sv.marker then return end
    sv.marker = index
    markedUnitId = nil
    pendingClear = false
end

local settingsPanel

local function CreateSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = ADDON .. "_Settings"
    settingsPanel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "Heavy Attack Tap Target",
        displayName = "Heavy Attack Tap Target",
        author = "Vixen Hunny",
        version = "1.0.0",
        slashCommand = "/hattsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local choices, choicesValues = {}, {}
    for i, name in ipairs(MARKER_NAMES) do
        choices[i] = string.format("%d - %s", i, name)
        choicesValues[i] = i
    end

    LAM:RegisterOptionControls(panelName, {
        {
            type = "description",
            text = "Puts a target marker on the enemy you heavy attack and removes it when that enemy dies. "
                .. "Target markers are shared with your group.",
        },
        {
            type = "checkbox",
            name = "Enabled",
            tooltip = "Mark the enemy under your crosshair when your heavy attack hits it.",
            getFunc = function() return sv.enabled end,
            setFunc = function(value) sv.enabled = value end,
            default = defaults.enabled,
        },
        {
            type = "dropdown",
            name = "Marker",
            tooltip = "Which of the eight game target markers to place.",
            choices = choices,
            choicesValues = choicesValues,
            getFunc = function() return sv.marker end,
            setFunc = SetMarker,
            default = defaults.marker,
            disabled = function() return not sv.enabled end,
        },
        {
            type = "checkbox",
            name = "Players only",
            tooltip = "Only mark enemy players. Monsters and NPCs are never marked.",
            getFunc = function() return sv.playersOnly end,
            setFunc = function(value) sv.playersOnly = value end,
            default = defaults.playersOnly,
            disabled = function() return not sv.enabled end,
        },
        {
            type = "checkbox",
            name = "Group leader only",
            tooltip = "While grouped, only place markers when you are the group leader. "
                .. "Solo, you can always mark.",
            getFunc = function() return sv.leaderOnly end,
            setFunc = function(value) sv.leaderOnly = value end,
            default = defaults.leaderOnly,
            disabled = function() return not sv.enabled end,
        },
        {
            type = "checkbox",
            name = "Everyone can mark in battlegrounds",
            tooltip = "Battlegrounds hand the crown to a random player, so inside one the "
                .. "group leader rule is ignored and anyone running the addon can mark.",
            getFunc = function() return sv.bgEveryone end,
            setFunc = function(value) sv.bgEveryone = value end,
            default = defaults.bgEveryone,
            disabled = function() return not sv.enabled or not sv.leaderOnly end,
        },
        {
            type = "header",
            name = "Caller",
        },
        {
            type = "description",
            text = function()
                local intro = "A caller is one group member whose heavy attacks set the mark for everyone. "
                    .. "While a caller is set, the leader and battleground rules above are ignored. "
                    .. "Everyone needs this addon and LibGroupBroadcast.\n\n"
                if not callerProtocol then
                    return intro .. "|cff5555Unavailable: LibGroupBroadcast is not loaded.|r"
                end
                return intro .. "Current caller: |cffffff" .. (callerName or "none") .. "|r"
            end,
        },
        {
            type = "checkbox",
            name = "Use caller",
            tooltip = "On: follow the group's caller, and allow yourself to become one. "
                .. "Off: ignore any caller and use the leader and battleground rules instead. "
                .. "Turning this off while you are the caller gives up the role.",
            getFunc = function() return sv.useCaller end,
            setFunc = SetUseCaller,
            default = defaults.useCaller,
            disabled = function() return not sv.enabled or not callerProtocol end,
        },
        {
            type = "button",
            name = "Become caller",
            tooltip = "Tell the group you are the caller. This replaces any current caller.",
            func = ClaimCaller,
            width = "half",
            disabled = function()
                return not sv.useCaller or not callerProtocol or not IsUnitGrouped("player") or IsCallerMe()
            end,
        },
        {
            type = "button",
            name = "Stop being caller",
            func = ReleaseCaller,
            width = "half",
            disabled = function() return not IsCallerMe() end,
        },
    })

    RefreshSettings = function()
        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", settingsPanel)
    end
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
local function OnSlash(args)
    local cmd, rest = zo_strlower(args or ""):match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "on" or cmd == "off" then
        sv.enabled = cmd == "on"
        Print("%s", sv.enabled and "enabled" or "disabled")
    elseif cmd == "marker" and MARKERS[tonumber(rest)] then
        SetMarker(tonumber(rest))
        Print("using marker %d (%s)", sv.marker, MARKER_NAMES[sv.marker])
    elseif cmd == "leader" and (rest == "on" or rest == "off") then
        sv.leaderOnly = rest == "on"
        Print("group leader only %s", sv.leaderOnly and "on" or "off")
    elseif cmd == "players" and (rest == "on" or rest == "off") then
        sv.playersOnly = rest == "on"
        Print("players only %s", sv.playersOnly and "on" or "off")
    elseif cmd == "bg" and (rest == "on" or rest == "off") then
        sv.bgEveryone = rest == "on"
        Print("everyone can mark in battlegrounds %s", sv.bgEveryone and "on" or "off")
    elseif cmd == "caller" and rest == "" then
        ClaimCaller()
    elseif cmd == "caller" and rest == "off" then
        ReleaseCaller()
    elseif cmd == "usecaller" and (rest == "on" or rest == "off") then
        SetUseCaller(rest == "on")
        Print("use caller %s", sv.useCaller and "on" or "off")
    elseif cmd == "caller" and rest == "who" then
        Print("current caller: %s", callerName or "none")
    elseif cmd == "settings" then
        if settingsPanel then
            LibAddonMenu2:OpenToPanel(settingsPanel)
        else
            Print("the settings panel needs LibAddonMenu-2.0")
        end
    else
        Print("/hatt on | off  - enable or disable (now %s)", sv.enabled and "on" or "off")
        Print("/hatt marker 1-8  - which target marker to use (now %d)", sv.marker)
        Print("/hatt players on | off  - only mark enemy players (now %s)", sv.playersOnly and "on" or "off")
        Print("/hatt leader on | off  - only mark as group leader (now %s)", sv.leaderOnly and "on" or "off")
        Print("/hatt bg on | off  - everyone can mark in battlegrounds (now %s)", sv.bgEveryone and "on" or "off")
        Print("/hatt caller | caller off | caller who  - become, stop being, or show the caller (now %s)", callerName or "none")
        Print("/hatt usecaller on | off  - follow the group's caller (now %s)", sv.useCaller and "on" or "off")
        Print("/hatt settings  - open the settings panel")
    end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local function Initialize()
    sv = ZO_SavedVars:NewAccountWide("HeavyAttackTapTargetSV", 1, nil, defaults)

    em:RegisterForEvent(ADDON, EVENT_COMBAT_EVENT, OnPlayerCombatEvent)
    em:AddFilterForEvent(ADDON, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    for _, result in ipairs({ ACTION_RESULT_DIED, ACTION_RESULT_DIED_XP, ACTION_RESULT_KILLING_BLOW }) do
        local name = ADDON .. "_Death" .. result
        em:RegisterForEvent(name, EVENT_COMBAT_EVENT, OnDeath)
        em:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, result)
    end

    em:RegisterForEvent(ADDON, EVENT_RETICLE_TARGET_CHANGED, OnReticleChanged)

    InitializeCaller()
    CreateSettings()
    SLASH_COMMANDS["/hatt"] = OnSlash
end

em:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON then return end
    em:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    Initialize()
end)
