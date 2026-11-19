-- GroupReset: manual trial exit, independent of Wizard's Wardrobe.
GroupReset = {}
local G = GroupReset
local NAME, VERSION = "GroupReset", "0.1.1"
local CONFIRM_DIALOG = "GROUPRESET_CONFIRM_EXIT"
local SIGNAL_NAME, SIGNAL_ID = "ExitInstanceRequest", 3
-- Interoperable with HodorReflexes' existing ExitInstanceRequest wire event.
-- This is that same operation, not a new allocation or a FastReset protocol.
-- Fail closed if another installed handler already owns this event or ID.
local settings, handler, fireExit, transportError
local pending, arm, lastExit = nil, nil, -100000
local registered = false
local deadPlayers = {}
local RefreshRadial
local timeout = 15000

local function Now() return GetFrameTimeMilliseconds() end
local function Say(text) d("[GroupReset " .. VERSION .. "] " .. text) end
local function Zone() return GetUnitZoneIndex("player") end
local function Leader()
    local tag = GetGroupLeaderUnitTag()
    return tag and DoesUnitExist(tag) and GetUnitDisplayName(tag) or nil
end
local function InTrial()
    return IsPlayerInRaid() or (type(IsPlayerInRaidStagingArea) == "function" and IsPlayerInRaidStagingArea())
end

local function Clear()
    pending, arm = nil, nil
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Pending")
end

local function ValidContext(state)
    return settings.enabled and IsUnitGrouped("player") and InTrial()
        and state.zone == Zone() and state.leader == Leader()
end

local function Poll()
    local state = pending
    if not state then return end
    if not ValidContext(state) then Clear(); return end
    if Now() >= state.expires then
        Clear()
        Say("Verlassen nicht abgeschlossen. ESO gibt die Instanz derzeit nicht frei; erneut versuchen.")
        return
    end
    if Now() < state.notBefore or not CanExitInstanceImmediately() then return end
    -- Clear before calling ESO, so a second event or repeated press cannot
    -- produce another travel request while the loading screen is starting.
    Clear()
    lastExit = Now()
    GroupResetReset.Prepare()
    local ok = pcall(ExitInstanceImmediately)
    if not ok then
        GroupResetReset.CancelPending()
        Say("ESO hat das Verlassen nicht ausgefuehrt. Bitte erneut versuchen.")
    end
end

local function QueueExit(delay)
    if pending or Now() - lastExit < 5000 then return end
    pending = {zone = Zone(), leader = Leader(), notBefore = Now() + delay, expires = Now() + timeout}
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Pending", 100, Poll)
    Poll()
end

local function ReceiveExit(unitTag)
    if not settings.enabled or pending or not IsUnitGrouped("player") or not InTrial() then return end
    if type(unitTag) ~= "string" or not DoesUnitExist(unitTag) or not IsUnitGroupLeader(unitTag) then return end
    if GetUnitZoneIndex(unitTag) ~= Zone() then return end
    if IsUnitGroupLeader("player") then return end -- leader has its own delayed exit
    QueueExit(0)
end

local function InitializeTransport()
    if HodorReflexes then
        transportError = "HodorReflexes ist parallel geladen. Fuer GroupReset bitte deaktivieren und UI neu laden."
        return
    end
    local lgb = LibGroupBroadcast
    if not lgb or type(lgb.RegisterHandler) ~= "function" then
        transportError = "LibGroupBroadcast ist nicht bereit."
        return
    end
    local ok, reason = pcall(function()
        handler = assert(lgb:RegisterHandler(NAME), "Handler nicht verfuegbar")
        handler:SetDisplayName(NAME)
        handler:SetDescription("Gemeinsames Verlassen einer Pruefung auf Anforderung des Gruppenleiters.")
        fireExit = handler:DeclareCustomEvent(SIGNAL_ID, SIGNAL_NAME, {
            displayName = "Pruefung gemeinsam verlassen", isRelevantInCombat = true,
        })
        assert(lgb:RegisterForCustomEvent(SIGNAL_NAME, ReceiveExit), "Empfang nicht verfuegbar")
    end)
    if not ok then
        fireExit = nil
        transportError = "Gruppensignal belegt oder nicht verfuegbar. Andere Gruppen-Auswurffunktionen (z.B. HodorReflexes) nicht parallel laden."
        -- Details are available on explicit status requests, not at login.
        G.transportDetail = tostring(reason)
    end
end

function G.SetEnabled(value)
    settings.enabled = value == true
    deadPlayers = {}
    if not settings.enabled then Clear(); GroupResetReset.CancelPending() end
    RefreshRadial()
end

function G.SetAutoDeath(value)
    settings.autoDeath = value == true
    deadPlayers = {}
    arm = nil
    RefreshRadial()
end

function G.SetAutoReset(value)
    settings.autoReset = value == true
    if not settings.autoReset then GroupResetReset.CancelPending() end
    RefreshRadial()
end

function G.RequestGroupExit(trigger, confirmedRequest)
    local deathTrigger = trigger == "death"
    if deathTrigger and not settings.autoDeath then return false end
    if trigger == "confirmed" then
        if not confirmedRequest or arm ~= confirmedRequest then return false end
        arm = nil -- consume this exact confirmation once
        if not ValidContext(confirmedRequest) then return false end
    end
    if not settings.enabled then Say("Zuerst Teilnahme aktivieren (Schnellrad oder Einstellungen)."); return false end
    if pending or Now() - lastExit < 5000 then return false end
    if not IsUnitGrouped("player") or not IsUnitGroupLeader("player") then
        Say("Nur der Gruppenleiter kann das gemeinsame Verlassen ausloesen."); return false
    end
    if not InTrial() then Say("Nur innerhalb einer Pruefung verfuegbar."); return false end
    if not fireExit then Say(transportError or "Gruppensignal nicht bereit."); return false end
    if not handler:IsCustomEventEnabled(SIGNAL_NAME) then
        Say("Gruppensignal in LibGroupBroadcast deaktiviert. Dort zuerst einschalten."); return false
    end
    if not deathTrigger and trigger ~= "confirmed" and settings.confirmSend then
        if arm or ZO_Dialogs_IsShowingDialog() then return false end
        arm = {zone = Zone(), leader = Leader()}
        ZO_Dialogs_ShowPlatformDialog(CONFIRM_DIALOG, {request = arm})
        return false
    end
    arm = nil
    local ok = pcall(fireExit)
    if not ok then Say("Gruppensignal konnte nicht gesendet werden."); return false end
    -- Leave time for the library's shared channel cooldown and transmission.
    -- A broadcast is a request; it is not an acknowledgement from all players.
    local cooldown = type(GetGroupAddOnDataBroadcastCooldownRemainingMS) == "function"
        and GetGroupAddOnDataBroadcastCooldownRemainingMS() or 0
    QueueExit(math.max(1500, cooldown + 1000))
    return true
end

local function InitializeDialogs()
    local function Cancel(dialog)
        if dialog.data and arm == dialog.data.request then arm = nil end
    end
    ZO_Dialogs_RegisterCustomDialog(CONFIRM_DIALOG, {
        title = {text = "GroupReset"},
        mainText = {text = function()
            return settings.autoReset
                and "Gruppe wirklich aus dem Raid holen und die Instanz danach zuruecksetzen?\n\nAlle Teilnehmer mit aktiviertem GroupReset verlassen den Raid. Die Gruppe bleibt bestehen."
                or "Gruppe wirklich aus dem Raid holen?\n\nAlle Teilnehmer mit aktiviertem GroupReset verlassen den Raid. Die Gruppe bleibt bestehen."
        end},
        buttons = {
            {text = SI_DIALOG_YES, callback = function(dialog)
                G.RequestGroupExit("confirmed", dialog.data and dialog.data.request)
            end},
            {text = SI_DIALOG_NO, callback = Cancel},
        },
        noChoiceCallback = Cancel,
        canQueue = false,
        allowShowOnDead = true,
        gamepadInfo = {dialogType = GAMEPAD_DIALOGS.BASIC},
    })
end

local function OnDeath(_, unitTag, isDead)
    if not settings.enabled or not settings.autoDeath or not IsUnitGrouped("player")
        or not IsUnitGroupLeader("player") or not InTrial() then return end
    if type(unitTag) ~= "string" or (unitTag ~= "player" and not unitTag:match("^group%d+$")) then return end
    if not DoesUnitExist(unitTag) or not IsUnitPlayer(unitTag) or GetUnitZoneIndex(unitTag) ~= Zone() then return end
    local name = GetUnitDisplayName(unitTag)
    if not name or name == "" then return end
    if not isDead then deadPlayers[name] = nil; return end
    if deadPlayers[name] then return end
    deadPlayers[name] = true
    -- Enabling death automation explicitly authorizes this trigger. Manual
    -- presses can still require confirmation; an automatic wipe exit cannot.
    G.RequestGroupExit("death")
end

function G.ShowStatus()
    Say((settings.enabled and "Teilnahme AN" or "Teilnahme AUS")
        .. "; " .. (pending and "Verlassen ausstehend" or "bereit")
        .. "; " .. (fireExit and "Gruppensignal bereit" or (transportError or "Gruppensignal fehlt")))
    Say(GroupResetReset.Describe())
    Say(settings.autoDeath and "Todesautomatik AN (nur Lead)" or "Todesautomatik AUS")
    if G.transportDetail then Say(G.transportDetail) end
end

RefreshRadial = function()
    if not LibRadialMenu then return end
    LibRadialMenu:RegisterEntry("groupreset", "Gruppe: Raid verlassen", "exitgroup",
        "/esoui/art/guild/gamepad/gp_guild_menuicon_leaveguild.dds", G.RequestGroupExit,
        "Nur Lead: teilnehmende Gruppenmitglieder verlassen die Pruefung. Gruppe bleibt bestehen. Alle brauchen GroupReset mit aktivierter Teilnahme. Bei aktiver Bestaetigung erscheint ein ESO-Ja/Nein-Fenster.")
    LibRadialMenu:RegisterEntry("groupreset", settings.enabled and "Teilnahme: AN (umschalten)" or "Teilnahme: AUS (umschalten)",
        "toggle", "/esoui/art/addons/gamepad/gp_addons_manage.dds", function() G.SetEnabled(not settings.enabled) end,
        "Erlaubt das Senden als Lead und das Empfangen von Raid-verlassen-Anforderungen des aktuellen Gruppenleiters.")
    LibRadialMenu:RegisterEntry("groupreset", "Status anzeigen", "status",
        "/esoui/art/addons/gamepad/gp_addons_manage.dds", G.ShowStatus,
        "Zeigt Teilnahme, Gruppensignal und ausstehende Aktion an.")
    LibRadialMenu:RegisterEntry("groupreset", settings.autoReset and "Auto-Reset: AN (umschalten)" or "Auto-Reset: AUS (umschalten)",
        "autoreset", "/esoui/art/icons/mapkey/mapkey_dungeon.dds", function() G.SetAutoReset(not settings.autoReset) end,
        "Lead setzt nach dem gemeinsamen Verlassen die Instanz durch Wechsel und Wiederherstellung der Schwierigkeit zurueck. Wartet, bis alle draussen sind.")
    LibRadialMenu:RegisterEntry("groupreset", settings.autoDeath and "Todesautomatik: AN (umschalten)" or "Todesautomatik: AUS (umschalten)",
        "autodeath", "/esoui/art/icons/mapkey/mapkey_dungeon.dds", function() G.SetAutoDeath(not settings.autoDeath) end,
        "Nur Lead: Bei Tod eines Spielers im selben Raid automatisch gemeinsam verlassen, ohne weitere Bestaetigung. Auto-Reset hat einen eigenen Schalter.")
end

local function InitializeSettings()
    local description = "Alle Teilnehmer brauchen GroupReset und aktivierte Teilnahme. Nur der aktuelle Lead kann das Verlassen ausloesen. Die Gruppe bleibt bestehen. Auto-Reset wechselt danach die Schwierigkeit und stellt sie zurueck, sobald alle draussen sind. Kein automatisches Zurueckporten."
    local console = type(ZO_IsConsoleOrGameCoreUI) == "function" and ZO_IsConsoleOrGameCoreUI()
    if not console and LibAddonMenu2 then
        LibAddonMenu2:RegisterAddonPanel(NAME .. "Settings", {type = "panel", name = NAME, displayName = NAME,
            author = "FiNk3--F13--", version = VERSION, registerForRefresh = true})
        LibAddonMenu2:RegisterOptionControls(NAME .. "Settings", {
            {type = "description", text = description},
            {type = "checkbox", name = "Teilnahme aktivieren", default = false,
                getFunc = function() return settings.enabled end, setFunc = G.SetEnabled},
            {type = "checkbox", name = "Lead: Bestaetigungsfenster anzeigen", default = true,
                getFunc = function() return settings.confirmSend end,
                setFunc = function(value) settings.confirmSend = value == true; arm = nil end},
            {type = "checkbox", name = "Lead: Instanz nach dem Verlassen automatisch zuruecksetzen", default = true,
                getFunc = function() return settings.autoReset end, setFunc = G.SetAutoReset},
            {type = "checkbox", name = "Lead: bei einem Todesfall automatisch gemeinsam verlassen", default = false,
                tooltip = "Ohne weitere Bestaetigung. Nur Spieler im selben Raid; Auto-Reset separat schaltbar.",
                getFunc = function() return settings.autoDeath end, setFunc = G.SetAutoDeath},
        })
    elseif LibHarvensAddonSettings then
        local lib = LibHarvensAddonSettings
        lib:AddAddon(NAME, {allowDefaults = true}):AddSettings({
            {type = lib.ST_LABEL, label = description},
            {type = lib.ST_CHECKBOX, label = "Teilnahme aktivieren", default = false,
                getFunction = function() return settings.enabled end, setFunction = G.SetEnabled},
            {type = lib.ST_CHECKBOX, label = "Lead: Bestaetigungsfenster anzeigen", default = true,
                getFunction = function() return settings.confirmSend end,
                setFunction = function(value) settings.confirmSend = value == true; arm = nil end},
            {type = lib.ST_CHECKBOX, label = "Lead: Instanz nach dem Verlassen automatisch zuruecksetzen", default = true,
                getFunction = function() return settings.autoReset end, setFunction = G.SetAutoReset},
            {type = lib.ST_CHECKBOX, label = "Lead: bei einem Todesfall automatisch gemeinsam verlassen", default = false,
                tooltip = "Ohne weitere Bestaetigung. Auto-Reset separat schaltbar.",
                getFunction = function() return settings.autoDeath end, setFunction = G.SetAutoDeath},
        })
    end
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= NAME or registered then return end
    registered = true
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    settings = ZO_SavedVars:NewAccountWide("GroupResetSV", 1, nil,
        {enabled = false, confirmSend = true, autoReset = true, autoDeath = false})
    GroupResetReset.Initialize(settings, Say)
    InitializeDialogs()
    InitializeTransport()
    InitializeSettings()
    if LibRadialMenu then LibRadialMenu:RegisterAddon("groupreset", NAME) end
    RefreshRadial()
    ZO_CreateStringId("SI_BINDING_NAME_GROUPRESET_EXIT_GROUP", "GroupReset: Gruppe verlaesst Raid")
    SLASH_COMMANDS["/groupreset"] = function(args)
        args = (args or ""):lower():match("^%s*(.-)%s*$")
        if args == "on" then G.SetEnabled(true)
        elseif args == "off" then G.SetEnabled(false)
        elseif args == "status" then G.ShowStatus()
        else G.RequestGroupExit() end
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function() Clear(); deadPlayers = {} end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function() Clear(); GroupResetReset.Activated() end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_LEADER_UPDATE, function()
        Clear(); deadPlayers = {}; GroupResetReset.CancelPending()
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_UNIT_DEATH_STATE_CHANGED, OnDeath)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GROUP_MEMBER_LEFT, function()
        if not IsUnitGrouped("player") then Clear(); GroupResetReset.CancelPending() end
    end)
end)
