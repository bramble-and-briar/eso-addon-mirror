PullCard = PullCard or {}
local PC = PullCard

PC.name = "PullCard"
PC.version = "0.5.1"
PC.window = nil
PC.savedVars = nil
PC.closeAtMs = 0
PC.currentBossName = nil
PC.currentBossData = nil
PC.manualIndex = 1
PC.detectedBossNames = {}
PC.debugMode = false
-- Last boss/round detected or opened from the menu, even when no card popped
-- (cooldown, Auto Pop-Up off). This is what /currentboss sends to chat.
PC.chatBoss = nil
PC.encountersByName = {}
PC.lastAutoShownAt = {}

local DEFAULT_SETTINGS = {
    displaySeconds = 10,
    repeatCooldownMinutes = 10,
    autoPopup = true,
    chatTag = true,
}

local CHAT_TAG = " (PullCard)"

local function Trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeBossName(name)
    local s = Trim(name)
    if s == "" then return "" end
    return s:lower():gsub("[%s%p]+", " ")
end

local function NormalizeZoneName(name)
    return (NormalizeBossName(name):gsub("^the ", ""))
end

local function GetEncounters()
    return (PullCardData and PullCardData.encounters) or {}
end

function PC:BuildEncounterIndex()
    self.encountersByName = {}

    local function index(name, encounter)
        local key = NormalizeBossName(name)
        if key == "" then return end

        local list = self.encountersByName[key]
        if not list then
            list = {}
            self.encountersByName[key] = list
        end
        for _, existing in ipairs(list) do
            if existing == encounter then return end
        end
        table.insert(list, encounter)
    end

    for _, encounter in ipairs(GetEncounters()) do
        for _, name in ipairs(encounter.names or {}) do
            index(name, encounter)
        end
        for _, alias in ipairs(encounter.aliases or {}) do
            index(alias, encounter)
        end
    end
end

-- Uses the dungeon's zone ID when the data has one, else its name.
local function IsPlayerInDungeon(dungeonInfo, zoneId, zoneName)
    if dungeonInfo.zoneId then
        return dungeonInfo.zoneId == zoneId
    end
    return NormalizeZoneName(dungeonInfo.name) == zoneName
end

-- Returns the card for a boss name in the player's current dungeon, or nil.
-- Matching on zone keeps arenas and instances without cards from popping on
-- bosses that share a name or short alias.
function PC:ResolveEncounter(candidate)
    local key = NormalizeBossName(candidate)
    if key == "" then return nil end

    local matches = self.encountersByName[key]
    if not matches then return nil end

    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    local zoneName = NormalizeZoneName(GetUnitZone("player"))
    for _, encounter in ipairs(matches) do
        if IsPlayerInDungeon(encounter.dungeonInfo, zoneId, zoneName) then
            return encounter
        end
    end

    return nil
end

local BOSS_UNIT_TAGS = {
    "boss1",
    "boss2",
    "boss3",
    "boss4",
    "boss5",
    "boss6",
}

function PC:GetDetectedBossNames()
    local found = {}

    for _, tag in ipairs(BOSS_UNIT_TAGS) do
        if DoesUnitExist(tag) then
            local name = Trim(GetUnitName(tag))
            if name ~= "" then
                table.insert(found, name)
            end
        end
    end

    return found
end

-- Returns (encounter, rawName). encounter is nil when the boss has no card.
function PC:GetBestDetectedBoss()
    local found = self:GetDetectedBossNames()
    self.detectedBossNames = found

    for _, name in ipairs(found) do
        local encounter = self:ResolveEncounter(name)
        if encounter then
            return encounter, name
        end
    end

    return nil, found[1]
end

function PC:GetPlayerRoleText(data)
    if not data then return "" end

    local role = GetSelectedLFGRole()
    if role == LFG_ROLE_TANK then
        return data.tank or ""
    elseif role == LFG_ROLE_HEAL then
        return data.healer or ""
    elseif role == LFG_ROLE_DPS then
        return data.dps or ""
    end

    return ""
end

-- Zone / map / subzone, used to work out matching rules (e.g. solo-arena rounds).
function PC:GetLocationText()
    local zoneName = GetUnitZone("player") or "?"
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))

    return string.format(
        "Zone: %s (%s)\nMap: %s\nSubzone: %s\nGroup dungeon: %s",
        tostring(zoneName),
        tostring(zoneId),
        tostring(GetMapName()),
        tostring(GetPlayerActiveSubzoneName()),
        tostring(self:IsInGroupDungeon())
    )
end

function PC:GetDebugText()
    if not self.debugMode then return "" end

    local bosses = (#self.detectedBossNames > 0) and table.concat(self.detectedBossNames, ", ") or "none"
    return "DEBUG\n" .. self:GetLocationText() .. "\nDetected: " .. bosses
end

function PC:SetBoss(encounter, rawName, source)
    self.currentBossName = encounter and encounter.title or rawName
    self.currentBossData = encounter
    self.currentSource = source or "unknown"
    if encounter then
        self.chatBoss = encounter
    end

    self:Render()
end

function PC:GetDisplaySeconds()
    return (self.savedVars and self.savedVars.displaySeconds) or DEFAULT_SETTINGS.displaySeconds
end

function PC:GetRepeatCooldownSeconds()
    local minutes = self.savedVars and self.savedVars.repeatCooldownMinutes
    return (minutes or DEFAULT_SETTINGS.repeatCooldownMinutes) * 60
end

-- Off = no automatic cards (e.g. farming the same boss); the menu still opens them.
function PC:IsAutoPopupEnabled()
    if not self.savedVars or self.savedVars.autoPopup == nil then
        return DEFAULT_SETTINGS.autoPopup
    end
    return self.savedVars.autoPopup
end

-- True if this boss already auto-popped recently (e.g. re-targeted mid-fight).
function PC:IsOnRepeatCooldown(key)
    local lastShown = self.lastAutoShownAt[key]
    return lastShown ~= nil and (GetFrameTimeSeconds() - lastShown) < self:GetRepeatCooldownSeconds()
end

function PC:UpdateCountdown()
    local remainingMs = self.closeAtMs - GetFrameTimeMilliseconds()
    if remainingMs <= 0 then
        self:CloseWindow()
        return
    end

    self.window.timer:SetText(string.format("%ds", math.ceil(remainingMs / 1000)))
end

function PC:OpenWindow()
    if not self.window then return end
    self.window:SetHidden(false)

    self.closeAtMs = GetFrameTimeMilliseconds() + self:GetDisplaySeconds() * 1000
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "Countdown")
    EVENT_MANAGER:RegisterForUpdate(self.name .. "Countdown", 200, function()
        PC:UpdateCountdown()
    end)

    self:UpdateCountdown()
    self:Render()
end

function PC:CloseWindow()
    if not self.window then return end
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "Countdown")
    self.window:SetHidden(true)
end

function PC:IsInGroupDungeon()
    -- Overland world bosses, delves and public dungeons have no dungeon difficulty.
    -- Group dungeons and trials do. Which card applies is decided by zone match.
    return GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_NONE
end

function PC:RefreshAuto()
    local encounter, rawName = nil, nil
    if self:IsInGroupDungeon() then
        encounter, rawName = self:GetBestDetectedBoss()
    else
        self.detectedBossNames = {}
    end

    -- Only pop for bosses we have a card for in this dungeon.
    if encounter then
        self.chatBoss = encounter
        if not self:IsAutoPopupEnabled() or self:IsOnRepeatCooldown(encounter) then
            return
        end

        self.lastAutoShownAt[encounter] = GetFrameTimeSeconds()
        self:SetBoss(encounter, rawName, "auto")
        self:OpenWindow()
    elseif not self.window or self.window:IsHidden() then
        -- Don't blank a card that's still on screen (e.g. a round card when
        -- the round's boss frames change).
        self.currentBossName = nil
        self.currentBossData = nil
        self.currentSource = "none"
        self:Render()
    end
end

-- Solo arenas: returns the round card for the area the player is standing in.
function PC:ResolveRound()
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    local zoneName = NormalizeZoneName(GetUnitZone("player"))
    local subzone = NormalizeZoneName(GetPlayerActiveSubzoneName())
    local mapName = NormalizeZoneName(GetMapName())

    local function findRound(dungeon, location)
        if location == "" then return nil end
        for _, encounter in ipairs(dungeon.encounters) do
            for _, areaName in ipairs(encounter.area or {}) do
                if NormalizeZoneName(areaName) == location then
                    return encounter
                end
            end
        end
        return nil
    end

    for _, dungeon in ipairs(PullCardData.dungeonOrder) do
        if dungeon.category == "solo" and IsPlayerInDungeon(dungeon, zoneId, zoneName) then
            -- Subzone first: the map name can lag a round behind (in Maelstrom
            -- round 8 the map still reads round 7's "Vault of Umbrage").
            return findRound(dungeon, subzone) or findRound(dungeon, mapName)
        end
    end
    return nil
end

function PC:RefreshRound()
    local encounter = self:ResolveRound()
    if not encounter then return end

    self.chatBoss = encounter
    if not self:IsAutoPopupEnabled() or self:IsOnRepeatCooldown(encounter) then return end

    self.lastAutoShownAt[encounter] = GetFrameTimeSeconds()
    self:SetBoss(encounter, nil, "round")
    self:OpenWindow()
end

function PC:Render()
    if not self.window then return end

    local bossName = self.currentBossName
    local data = self.currentBossData

    if not bossName then
        self.window.title:SetText("PullCard")
        self.window.body:SetText("No active boss detected.")
        self.window.role:SetText("")
    elseif data then
        local summary = data.summary or "Watch the encounter flow, protect your team, and execute one clean mechanic cycle."
        self.window.title:SetText((data.dungeon or "Dungeon") .. " — " .. (data.title or bossName))
        local mechanicsLabel = data.area and "MECHANICS" or "EVERYONE"
        self.window.body:SetText("SUMMARY\n" .. summary .. "\n\n" .. mechanicsLabel .. "\n" .. (data.everyone or "No notes yet."))

        local sections = {}
        local roleText = self:GetPlayerRoleText(data)
        if roleText ~= "" then
            table.insert(sections, "YOUR ROLE\n" .. roleText)
        end
        if GetCurrentZoneDungeonDifficulty() == DUNGEON_DIFFICULTY_VETERAN then
            if data.hardmode then
                table.insert(sections, "HARD MODE\n" .. data.hardmode)
            end
            for _, challenge in ipairs(data.challenges) do
                table.insert(sections, "CHALLENGE\n" .. challenge.text)
            end
        end
        self.window.role:SetText(table.concat(sections, "\n\n"))
    else
        self.window.title:SetText(bossName)
        self.window.body:SetText("Boss detected, but no PullCard exists yet.")
        self.window.role:SetText("")
    end

    local debug = self:GetDebugText()
    if debug ~= "" then
        self.window.debug:SetText(debug)
        self.window.debug:SetHidden(false)
    else
        self.window.debug:SetHidden(true)
    end
end

function PC:Browse(delta)
    local encounters = GetEncounters()
    if #encounters == 0 then return end

    self.manualIndex = self.manualIndex + delta
    if self.manualIndex < 1 then self.manualIndex = #encounters end
    if self.manualIndex > #encounters then self.manualIndex = 1 end

    self:SetBoss(encounters[self.manualIndex], nil, "manual")
    self:OpenWindow()
end

-- Text for the group: the boss's TL;DR (falls back to its "everyone" line),
-- plus a short "(PullCard)" tag unless turned off in Settings.
function PC:GetChatText()
    local data = self.chatBoss
    if not data then return nil end

    local text
    if data.tldr and data.tldr ~= "" then
        text = data.tldr
    elseif data.everyone and data.everyone ~= "" then
        text = "[" .. data.title .. "] " .. data.everyone
    else
        return nil
    end

    local tagOn = not self.savedVars or self.savedVars.chatTag ~= false
    return tagOn and (text .. CHAT_TAG) or text
end

-- /pullcard <part of a boss name>: finds cards by name, alias or title.
-- Matches in the player's current dungeon win over the same name elsewhere.
function PC:SearchEncounters(query)
    local q = NormalizeBossName(query)
    if q == "" then return {} end

    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    local zoneName = NormalizeZoneName(GetUnitZone("player"))
    local here, elsewhere = {}, {}

    for _, encounter in ipairs(GetEncounters()) do
        local found = NormalizeBossName(encounter.title):find(q, 1, true)
        if not found then
            for _, list in ipairs({ encounter.names or {}, encounter.aliases or {} }) do
                for _, name in ipairs(list) do
                    if NormalizeBossName(name):find(q, 1, true) then
                        found = true
                        break
                    end
                end
                if found then break end
            end
        end

        if found then
            if IsPlayerInDungeon(encounter.dungeonInfo, zoneId, zoneName) then
                table.insert(here, encounter)
            else
                table.insert(elsewhere, encounter)
            end
        end
    end

    return #here > 0 and here or elsewhere
end

function PC:HandlePullCardCommand(args)
    local query = Trim(args)
    if query == "" then
        d("PullCard: /currentboss fills chat with the strategy for the boss you're on. /pullcard <part of a boss name> does it for any boss, e.g. /pullcard domi")
        return
    end

    local matches = self:SearchEncounters(query)
    if #matches == 0 then
        d("PullCard: no boss matches \"" .. query .. "\". Try part of the name from the boss's health bar.")
    elseif #matches == 1 then
        self.chatBoss = matches[1]
        self:PrefillGroupChat()
    else
        local lines = {}
        for i = 1, math.min(#matches, 5) do
            table.insert(lines, matches[i].title .. " (" .. matches[i].dungeon .. ")")
        end
        local more = #matches > 5 and (" and " .. (#matches - 5) .. " more") or ""
        d("PullCard: " .. #matches .. " matches, type more of the name: " .. table.concat(lines, "; ") .. more)
    end
end

-- Addons can't send chat; this fills the party chat box and the player presses send.
function PC:PrefillGroupChat()
    local text = self:GetChatText()
    if not text then
        d("PullCard: no boss yet. Get near a boss, or open one from the PullCard menu.")
        return
    end

    -- Deliberately isolated. PC behavior is known; console/gamepad behavior
    -- can be swapped here without changing the rest of the addon.
    local chatSystem = ZO_GetChatSystem and ZO_GetChatSystem()
    if chatSystem and chatSystem.StartTextEntry then
        chatSystem:StartTextEntry(text, CHAT_CHANNEL_PARTY, nil, true)
    else
        -- No chat entry available: at least show it to the player.
        d(text)
    end
end

function PC:RegisterSlashCommands()
    SLASH_COMMANDS["/currentboss"] = function() PC:PrefillGroupChat() end
    SLASH_COMMANDS["/pullcard"] = function(args) PC:HandlePullCardCommand(args) end
end

function PC:RegisterConsoleMenu()
    if not LibConsoleMenu or type(LibConsoleMenu.CreateAddonMenu) ~= "function" then
        return
    end

    local menu = LibConsoleMenu:CreateAddonMenu(self.name, {
        title = self.name,
        author = "yodased",
        version = self.version,
        category = "utility",
    })

    if not menu then return end

    local options = {
        {
            type = "button",
            name = "Explain Boss to Group",
            tooltip = function()
                local text = PC:GetChatText()
                if not text then
                    return "No boss yet. Get near a boss, or open one from the menu below. Also available as /currentboss."
                end
                return "Fills your chat box with this (you press send):\n\n" .. text .. "\n\nMake sure chat is on the Group channel. Also available by typing /currentboss."
            end,
            func = function() PC:PrefillGroupChat() end,
        },
        {
            type = "submenu",
            name = "Settings",
            options = self:BuildSettingsOptions(),
        },
    }

    -- Section -> dungeon -> boss. Kept to two submenu levels (the depth the
    -- 0.2.0 Tips Library used), so DLC dungeons carry their DLC in the label
    -- instead of getting a third level.
    for _, category in ipairs(PullCardData.CATEGORIES) do
        local dungeonSubmenus = self:BuildDungeonSubmenus(category.key)
        if #dungeonSubmenus > 0 then
            table.insert(options, {
                type = "submenu",
                name = category.name,
                options = dungeonSubmenus,
            })
        end
    end

    menu:AddOptions(options)
end

function PC:BuildSettingsOptions()
    return {
        {
            type = "selector",
            name = "Auto Pop-Up",
            tooltip = "Turn off to stop cards popping up automatically, e.g. while farming the same boss over and over. You can still open any card from this menu. Stays off until you turn it back on.",
            choices = {
                { name = "On", value = "on" },
                { name = "Off", value = "off" },
            },
            default = "on",
            getFunc = function() return PC:IsAutoPopupEnabled() and "on" or "off" end,
            setFunc = function(value)
                PC.savedVars.autoPopup = (value == "on")
                if value == "off" then
                    PC:CloseWindow()
                end
            end,
        },
        {
            type = "slider",
            name = "Card display time (seconds)",
            tooltip = "How long the PullCard stays on screen before closing.",
            min = 3,
            max = 60,
            step = 1,
            default = DEFAULT_SETTINGS.displaySeconds,
            getFunc = function() return PC:GetDisplaySeconds() end,
            setFunc = function(value) PC.savedVars.displaySeconds = value end,
        },
        {
            type = "slider",
            name = "Don't re-show same boss for (minutes)",
            tooltip = "After a boss's card pops up, it won't pop up again for that boss until this much time has passed.",
            min = 0,
            max = 30,
            step = 1,
            default = DEFAULT_SETTINGS.repeatCooldownMinutes,
            getFunc = function() return PC:GetRepeatCooldownSeconds() / 60 end,
            setFunc = function(value) PC.savedVars.repeatCooldownMinutes = value end,
        },
        {
            type = "selector",
            name = "Chat Tag",
            tooltip = "Adds \"(PullCard)\" to the end of strategies you put in chat, so your group knows where they came from.",
            choices = {
                { name = "On", value = "on" },
                { name = "Off", value = "off" },
            },
            default = "on",
            getFunc = function() return PC.savedVars.chatTag ~= false and "on" or "off" end,
            setFunc = function(value) PC.savedVars.chatTag = (value == "on") end,
        },
        -- LibConsoleMenu has no checkbox type (rows with unknown types are
        -- silently dropped); "selector" is the confirmed-working on/off control.
        {
            type = "selector",
            name = "Debug Text",
            tooltip = "Shows zone name/ID and detected boss names on the card.",
            choices = {
                { name = "Off", value = "off" },
                { name = "On", value = "on" },
            },
            default = "off",
            getFunc = function() return PC.debugMode and "on" or "off" end,
            setFunc = function(value)
                PC.debugMode = (value == "on")
                PC:Render()
            end,
        },
        {
            type = "button",
            name = "Location Info",
            tooltip = function() return PC:GetLocationText() end,
            func = function() end,
        },
    }
end

local function FormatEncounterTooltip(encounter)
    local text = encounter.title .. "\n"
    if encounter.summary then
        text = text .. "\nSummary: " .. encounter.summary
    end
    if encounter.everyone then
        text = text .. "\n\nEveryone: " .. encounter.everyone
    end
    if encounter.tank then
        text = text .. "\n\nTank: " .. encounter.tank
    end
    if encounter.healer then
        text = text .. "\n\nHealer: " .. encounter.healer
    end
    if encounter.dps then
        text = text .. "\n\nDPS: " .. encounter.dps
    end
    if encounter.hardmode then
        text = text .. "\n\nHard Mode: " .. encounter.hardmode
    end
    for _, challenge in ipairs(encounter.challenges) do
        local label = challenge.name and ("Challenge (" .. challenge.name .. ")") or "Challenge"
        text = text .. "\n\n" .. label .. ": " .. challenge.text
    end
    if encounter.tldr then
        text = text .. "\n\nQuick: " .. encounter.tldr
    end
    return text
end

local function GetDungeonMenuLabel(dungeon)
    if dungeon.group then
        return dungeon.name .. " (" .. dungeon.group .. ")"
    end
    return dungeon.name
end

function PC:BuildDungeonSubmenus(categoryKey)
    local dungeons = {}
    for _, dungeon in ipairs(PullCardData.dungeonOrder) do
        if dungeon.category == categoryKey and #dungeon.encounters > 0 then
            table.insert(dungeons, dungeon)
        end
    end
    table.sort(dungeons, function(a, b) return a.name < b.name end)

    local submenus = {}
    for _, dungeon in ipairs(dungeons) do
        -- Bosses stay in data (run) order.
        local bossOptions = {}
        for _, encounter in ipairs(dungeon.encounters) do
            table.insert(bossOptions, {
                type = "button",
                name = encounter.title,
                tooltip = FormatEncounterTooltip(encounter),
                func = function()
                    PC:SetBoss(encounter, nil, "manual")
                    PC:OpenWindow()
                end,
            })
        end

        table.insert(submenus, {
            type = "submenu",
            name = GetDungeonMenuLabel(dungeon),
            options = bossOptions,
        })
    end
    return submenus
end

function PC:ToggleWindow()
    if not self.window then return end
    local hidden = self.window:IsHidden()
    if hidden then
        self:OpenWindow()
    else
        self:CloseWindow()
    end
end

-- Explicit sizes so the card stays readable on console (TV distance).
local FONT_TITLE = "$(GAMEPAD_BOLD_FONT)|32|soft-shadow-thick"
local FONT_BODY = "$(GAMEPAD_MEDIUM_FONT)|25|soft-shadow-thick"
local FONT_SMALL = "$(GAMEPAD_MEDIUM_FONT)|20|soft-shadow-thick"

function PC:CreateWindow()
    local wm = WINDOW_MANAGER

    local top = wm:CreateTopLevelWindow("PullCardWindow")
    self.window = top
    top:SetDimensions(780, 700)
    top:SetAnchor(CENTER, GuiRoot, CENTER, 0, 80)
    top:SetMovable(true)
    top:SetMouseEnabled(true)
    top:SetClampedToScreen(true)
    top:SetHidden(true)

    local bg = wm:CreateControl(nil, top, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0.05, 0.05, 0.05, 0.94)
    bg:SetEdgeColor(0.5, 0.5, 0.5, 0.9)
    bg:SetEdgeTexture("", 1, 1, 1)

    local timer = wm:CreateControl(nil, top, CT_LABEL)
    top.timer = timer
    timer:SetFont(FONT_TITLE)
    timer:SetColor(0.8, 0.8, 0.8, 1)
    timer:SetDimensions(70, 40)
    timer:SetAnchor(TOPRIGHT, top, TOPRIGHT, -18, 16)
    timer:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local title = wm:CreateControl(nil, top, CT_LABEL)
    top.title = title
    title:SetFont(FONT_TITLE)
    title:SetAnchor(TOPLEFT, top, TOPLEFT, 18, 16)
    title:SetAnchor(TOPRIGHT, timer, TOPLEFT, -10, 0)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetText("PullCard")

    local body = wm:CreateControl(nil, top, CT_LABEL)
    top.body = body
    body:SetFont(FONT_BODY)
    body:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 16)
    body:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 16)
    body:SetHeight(250)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local role = wm:CreateControl(nil, top, CT_LABEL)
    top.role = role
    role:SetFont(FONT_BODY)
    role:SetAnchor(TOPLEFT, body, BOTTOMLEFT, 0, 10)
    role:SetAnchor(TOPRIGHT, body, BOTTOMRIGHT, 0, 10)
    role:SetHeight(240)
    role:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local debug = wm:CreateControl(nil, top, CT_LABEL)
    top.debug = debug
    debug:SetFont(FONT_SMALL)
    debug:SetAnchor(TOPLEFT, role, BOTTOMLEFT, 0, 8)
    debug:SetAnchor(TOPRIGHT, role, BOTTOMRIGHT, 0, 8)
    debug:SetHeight(100)
    debug:SetVerticalAlignment(TEXT_ALIGN_TOP)
end

function PC:Initialize()
    self.savedVars = ZO_SavedVars:NewAccountWide("PullCardSavedVars", 1, nil, DEFAULT_SETTINGS)
    self:BuildEncounterIndex()

    self:CreateWindow()
    self:RegisterSlashCommands()
    self:RegisterConsoleMenu()

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_BOSSES_CHANGED, function()
        zo_callLater(function()
            PC:RefreshAuto()
        end, 150)
    end)

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(function()
            PC:RefreshAuto()
            PC:RefreshRound()
        end, 500)
    end)

    -- Fires on subzone changes too: that's how solo-arena rounds are detected.
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ZONE_CHANGED, function()
        zo_callLater(function()
            PC:RefreshRound()
        end, 300)
    end)
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= PC.name then return end

    EVENT_MANAGER:UnregisterForEvent(PC.name, EVENT_ADD_ON_LOADED)
    PC:Initialize()
end

EVENT_MANAGER:RegisterForEvent(PC.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
