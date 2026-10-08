PullCard = PullCard or {}
local PC = PullCard

PC.name = "PullCard"
PC.version = "0.2.2"
PC.window = nil
PC.savedVars = nil
PC.closeAtMs = 0
PC.currentBossName = nil
PC.currentBossData = nil
PC.manualIndex = 1
PC.detectedBossNames = {}
PC.debugMode = false
PC.lastPrefilledBoss = nil
PC.encountersByName = {}
PC.lastAutoShownAt = {}

local DEFAULT_SETTINGS = {
    displaySeconds = 10,
    repeatCooldownMinutes = 10,
}

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

function PC:GetDebugText()
    if not self.debugMode then return "" end

    local zoneName = GetUnitZone("player") or "?"
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    local bosses = (#self.detectedBossNames > 0) and table.concat(self.detectedBossNames, ", ") or "none"

    return string.format(
        "DEBUG\nZone: %s (%s)\nGroup dungeon: %s\nDetected: %s",
        tostring(zoneName),
        tostring(zoneId),
        tostring(self:IsInGroupDungeon()),
        bosses
    )
end

function PC:SetBoss(encounter, rawName, source)
    self.currentBossName = encounter and encounter.title or rawName
    self.currentBossData = encounter
    self.currentSource = source or "unknown"

    self:Render()
end

function PC:GetDisplaySeconds()
    return (self.savedVars and self.savedVars.displaySeconds) or DEFAULT_SETTINGS.displaySeconds
end

function PC:GetRepeatCooldownSeconds()
    local minutes = self.savedVars and self.savedVars.repeatCooldownMinutes
    return (minutes or DEFAULT_SETTINGS.repeatCooldownMinutes) * 60
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
        if self:IsOnRepeatCooldown(encounter) then
            return
        end

        self.lastAutoShownAt[encounter] = GetFrameTimeSeconds()
        self:SetBoss(encounter, rawName, "auto")
        self:OpenWindow()
    else
        self.currentBossName = nil
        self.currentBossData = nil
        self.currentSource = "none"
        self:Render()
    end
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
        self.window.body:SetText("SUMMARY\n" .. summary .. "\n\nEVERYONE\n" .. (data.everyone or "No notes yet."))

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

function PC:PrefillGroupChat()
    local d = self.currentBossData
    if not d or not d.tldr or d.tldr == "" then return end

    -- Deliberately isolated. PC behavior is known; console/gamepad behavior
    -- can be swapped here without changing the rest of the addon.
    local chatSystem = ZO_GetChatSystem and ZO_GetChatSystem()
    if chatSystem and chatSystem.StartTextEntry then
        chatSystem:StartTextEntry(d.tldr, CHAT_CHANNEL_PARTY, nil, true)
    end
end

function PC:RegisterSlashCommands()
    SLASH_COMMANDS["/currentboss"] = function()
        local data = PC.currentBossData
        if not data or not data.tldr or data.tldr == "" then
            d("PullCard: No boss strategy available")
            return
        end

        local chatSystem = ZO_GetChatSystem and ZO_GetChatSystem()
        if chatSystem and chatSystem.StartTextEntry then
            chatSystem:StartTextEntry(data.tldr, CHAT_CHANNEL_PARTY, nil, true)
        end
    end
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
            type = "checkbox",
            name = "Debug Text",
            tooltip = "Shows zone name/ID and detected boss names on the card.",
            default = false,
            getFunc = function() return PC.debugMode end,
            setFunc = function(value)
                PC.debugMode = value
                PC:Render()
            end,
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
        end, 500)
    end)
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= PC.name then return end

    EVENT_MANAGER:UnregisterForEvent(PC.name, EVENT_ADD_ON_LOADED)
    PC:Initialize()
end

EVENT_MANAGER:RegisterForEvent(PC.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
