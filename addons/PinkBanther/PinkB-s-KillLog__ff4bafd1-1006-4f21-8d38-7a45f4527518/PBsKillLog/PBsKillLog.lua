PBsKillLog = PBsKillLog or {}
local ADDON = PBsKillLog
local L = ADDON.L

ADDON.name = "PBsKillLog"
ADDON.author = "PinkBanther"

-- A typographic apostrophe (U+2019), not an ASCII one. The settings list splits a name written
-- "Author's Name" into author and name and shows only the name, so "PB's KillLog" would read
-- "KILLLOG". The manifest keeps the ASCII form, which is what the add-on list wants. Written as
-- the character itself, not "\u{2019}": that escape is Lua 5.3 and the client is 5.1.
local DISPLAY_NAME = "PB’s KillLog"

local SAVED_VARS_NAME = "PBsKillLog_SavedVars"
local SAVED_VARS_VERSION = 1

-- The built-in kill feed receives the same kill twice (once from the local client and once from the
-- kill location) and drops the second copy within 10 seconds. The same rule is applied here.
local DUPLICATE_WINDOW_MS = 10000
local MAX_ENTRIES = 200
local RESIZE_HANDLE_SIZE = 8

-- Only a face the console UI already has loaded may be used. CHAT_FONT (which the keyboard
-- ZoFontChat is built on) was measured crashing a PS5: a face nothing else is drawing with has
-- to be built on use, out of the memory every add-on shares, and on a Japanese client it is the
-- large CJK face. The alias is used, never a resolved path, so the client still picks a face
-- that can draw Japanese names. A size change on a loaded face costs nothing.
local FONT_FACE = "$(GAMEPAD_MEDIUM_FONT)"

-- A control that takes input takes every gamepad button from the game while it is up, and a
-- console has no mouse to move or resize with, so the window can only be unlocked elsewhere.
local CAN_EDIT_WITH_MOUSE = not ZO_IsConsoleOrGameCoreUI()
ADDON.CAN_EDIT_WITH_MOUSE = CAN_EDIT_WITH_MOUSE

ADDON.MIN_WIDTH = 160
ADDON.MIN_HEIGHT = 48
ADDON.MIN_FONT_SIZE = 12
ADDON.MAX_FONT_SIZE = 64
ADDON.MAX_DRAW_LEVEL = 100

ADDON.DRAW_TIERS = {
    low = DT_LOW,
    medium = DT_MEDIUM,
    high = DT_HIGH,
}

local window, frame, buffer, fragment
local sv

local entries = {}       -- raw kill data, kept so the text can be rebuilt when the font size changes
local recentKills = {}   -- duplicate filter: key -> expiry (ms)

local unlocked = false   -- never saved: the window always starts locked

---------------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------------

local function BuildDefaults()
    return {
        left = 60,
        top = zo_round(GuiRoot:GetHeight() * 0.4),
        width = 640,
        height = 240,
        fontSize = 20,
        drawTier = "medium",
        drawLevel = 0,
        killSound = true,
        preview = true,
    }
end

-- The keys "reset" puts back: the window's look and place, not the sound or preview options.
local WINDOW_SETTING_KEYS = { "left", "top", "width", "height", "fontSize", "drawTier", "drawLevel" }

---------------------------------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------------------------------

local function GetIconSize()
    return zo_round(sv.fontSize * 4 / 3)
end

local function GetFontString()
    local shadow = sv.fontSize <= 14 and "soft-shadow-thin" or "soft-shadow-thick"
    return string.format("%s|%d|%s", FONT_FACE, sv.fontSize, shadow)
end

-- Mirrors the text of the built-in chat kill feed (see EVENT_PVP_KILL_FEED_DEATH in chathandlers.lua).
-- Only Cyrodiil kills are ever shown, so the alliance colours and rank icons are the only kind there is;
-- the Battleground team colours and icons of the built-in feed are not needed.
local function FormatEntry(entry, iconSize)
    local killerColor = GetAllianceColor(entry.killerAlliance):GetBright()
    local victimColor = GetAllianceColor(entry.victimAlliance):GetBright()
    local killerIcon = ZO_GetColoredAvARankIconMarkup(entry.killerRank, entry.killerAlliance, iconSize)
    local victimIcon = ZO_GetColoredAvARankIconMarkup(entry.victimRank, entry.victimAlliance, iconSize)

    local killerName = ZO_GetPrimaryPlayerName(entry.killerDisplayName, entry.killerCharacterName) or entry.killerDisplayName
    local victimName = ZO_GetPrimaryPlayerName(entry.victimDisplayName, entry.victimCharacterName) or entry.victimDisplayName

    local hasLocation = entry.killLocation ~= nil and entry.killLocation ~= ""
    local stringId = hasLocation and SI_PVP_KILL_FEED_DEATH_AND_LOCATION or SI_PVP_KILL_FEED_DEATH
    return zo_strformat(stringId, killerColor:Colorize(killerName), killerIcon, victimColor:Colorize(victimName), victimIcon, entry.killLocation)
end

ADDON.GetIconSize = GetIconSize
ADDON.GetFontString = GetFontString
ADDON.FormatEntry = FormatEntry

local function RebuildBuffer()
    buffer:Clear()
    local iconSize = GetIconSize()
    for _, entry in ipairs(entries) do
        buffer:AddMessage(FormatEntry(entry, iconSize), 1, 1, 1)
    end
end

local function AddEntry(entry)
    entries[#entries + 1] = entry
    if #entries > MAX_ENTRIES then
        table.remove(entries, 1)
    end
    buffer:AddMessage(FormatEntry(entry, GetIconSize()), 1, 1, 1)
end

---------------------------------------------------------------------------------------------------
-- Where the log applies
---------------------------------------------------------------------------------------------------

-- Cyrodiil itself, and nothing else the kill feed also covers. The Imperial City is a zone of its own
-- (IsInCyrodiil is false there), its campaigns are fought on a different map entirely even though the
-- world is still Cyrodiil's (PB's CyrodiilAlert makes the same cut), and a Battleground is neither.
function ADDON.IsInCyrodiil()
    if not IsInCyrodiil() or IsInImperialCity() or IsActiveWorldBattleground() then
        return false
    end
    local campaignId = GetCurrentCampaignId()
    return campaignId == 0 or not IsImperialCityCampaign(campaignId)
end

-- The log is drawn only in Cyrodiil. The window itself stays where it is (it is what the unlock frame
-- is drawn on); it is the text that is hidden elsewhere. Run at every loading screen, which is how a
-- player gets into or out of Cyrodiil.
local function UpdateLogVisibility()
    buffer:SetHidden(not ADDON.IsInCyrodiil())
end

---------------------------------------------------------------------------------------------------
-- Kill feed event
---------------------------------------------------------------------------------------------------

local function ForgetExpiredKills(now)
    for key, expiry in pairs(recentKills) do
        if expiry <= now then
            recentKills[key] = nil
        end
    end
end

-- Returns true if the key was tracked and has not expired. The key is consumed either way.
local function TakeRecentKill(key, now)
    local expiry = recentKills[key]
    recentKills[key] = nil
    return expiry ~= nil and expiry > now
end

local function RememberKill(key, now)
    ForgetExpiredKills(now)
    local expiry = recentKills[key]
    local newExpiry = now + DUPLICATE_WINDOW_MS
    recentKills[key] = expiry and zo_max(expiry, newExpiry) or newExpiry
end

-- The killer fields of the event are the crossplay display name and the raw character name, so
-- either one matching this player's own is enough.
local function IsLocalPlayer(displayName, characterName)
    if displayName ~= "" and displayName == GetDisplayName() then
        return true
    end
    return characterName ~= "" and characterName == GetRawUnitName("player")
end

-- The sound the Tales of Tribute board plays when a card's health runs out (ZO_TributeCard:
-- UpdateDefeatCost). The UI has no separate sound for a card being destroyed.
function ADDON.PlayKillSound()
    local sound = SOUNDS.TRIBUTE_AGENT_KNOCKED_OUT
    if sound then
        PlaySound(sound)
    end
end

-- Turning the sound on plays it once, so the player hears what they switched on.
function ADDON.SetKillSound(value)
    sv.killSound = value and true or false
    if sv.killSound then
        ADDON.PlayKillSound()
    end
end

-- The "PvP Kill Feed" option in the social settings is deliberately NOT consulted: the built-in chat
-- handler checks it, but the event itself is delivered to addons regardless.
local function OnPvpKillFeedDeath(_, killLocation, killerDisplayName, killerCharacterName, killerAlliance, killerRank, victimDisplayName, victimCharacterName, victimAlliance, victimRank, isKillLocation)
    -- The feed also reports the Imperial City and Battlegrounds; this log is for Cyrodiil only.
    if not ADDON.IsInCyrodiil() then
        return
    end

    local now = GetFrameTimeMilliseconds()
    local suffix = string.format("%s___%s", killerDisplayName, victimDisplayName)
    local ownKey = (isKillLocation and "B" or "L") .. suffix
    local otherKey = (isKillLocation and "L" or "B") .. suffix

    if TakeRecentKill(otherKey, now) then
        return
    end
    RememberKill(ownKey, now)

    AddEntry({
        killLocation = killLocation,
        killerDisplayName = killerDisplayName,
        killerCharacterName = killerCharacterName,
        killerAlliance = killerAlliance,
        killerRank = killerRank,
        victimDisplayName = victimDisplayName,
        victimCharacterName = victimCharacterName,
        victimAlliance = victimAlliance,
        victimRank = victimRank,
    })

    if sv.killSound and IsLocalPlayer(killerDisplayName, killerCharacterName) then
        ADDON.PlayKillSound()
    end
end

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------

-- The preview frame (Preview.lua) follows every change made to the window.
local function UpdatePreview()
    if ADDON.preview then
        ADDON.preview:Update()
    end
end

local function UpdateEditState()
    frame:SetHidden(not unlocked)
    window:SetMouseEnabled(unlocked)
    window:SetMovable(unlocked)
    window:SetResizeHandleSize(unlocked and RESIZE_HANDLE_SIZE or 0)
end

function ADDON.ApplyLayout()
    window:ClearAnchors()
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.left, sv.top)
    window:SetDimensions(sv.width, sv.height)
    UpdatePreview()
end

function ADDON.ApplyFont()
    buffer:SetFont(GetFontString())
    RebuildBuffer()
    UpdatePreview()
end

function ADDON.ApplyLayer()
    window:SetDrawTier(ADDON.DRAW_TIERS[sv.drawTier] or DT_MEDIUM)
    window:SetDrawLevel(sv.drawLevel)
    UpdatePreview()
end

-- Called after the user dragged or resized the window, so the saved values follow the mouse.
local function SaveWindowRect()
    sv.left = zo_round(window:GetLeft())
    sv.top = zo_round(window:GetTop())
    sv.width = zo_round(window:GetWidth())
    sv.height = zo_round(window:GetHeight())
    ADDON.ApplyLayout()
    if ADDON.RefreshSettingsPanel then
        ADDON.RefreshSettingsPanel()
    end
end

ADDON.OnMoveStop = SaveWindowRect
ADDON.OnResizeStop = SaveWindowRect

function ADDON.IsUnlocked()
    return unlocked
end

-- Returns false when the window cannot be unlocked on this platform.
function ADDON.SetUnlocked(value)
    value = value and true or false
    if value and not CAN_EDIT_WITH_MOUSE then
        return false
    end
    unlocked = value
    UpdateEditState()
    return true
end

function ADDON.AddTestEntry()
    AddEntry({
        killLocation = L("TEST_LOCATION"),
        killerDisplayName = "@" .. L("TEST_KILLER"),
        killerCharacterName = L("TEST_KILLER"),
        killerAlliance = ALLIANCE_ALDMERI_DOMINION,
        killerRank = 10,
        victimDisplayName = "@" .. L("TEST_VICTIM"),
        victimCharacterName = L("TEST_VICTIM"),
        victimAlliance = ALLIANCE_EBONHEART_PACT,
        victimRank = 3,
    })
end

function ADDON.ClearLog()
    entries = {}
    recentKills = {}
    buffer:Clear()
end

function ADDON.ResetWindowSettings()
    for _, key in ipairs(WINDOW_SETTING_KEYS) do
        sv[key] = ADDON.defaults[key]
    end
    ADDON.ApplyLayout()
    ADDON.ApplyFont()
    ADDON.ApplyLayer()
    if ADDON.RefreshSettingsPanel then
        ADDON.RefreshSettingsPanel()
    end
end

---------------------------------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------------------------------

local function Print(text)
    CHAT_ROUTER:AddSystemMessage("[PBsKillLog] " .. text)
end

local function OnSlashCommand(argument)
    local command, option = string.lower(argument or ""):match("^%s*(%S*)%s*(%S*)")
    if command == "unlock" then
        Print(ADDON.SetUnlocked(true) and L("CMD_UNLOCKED") or L("CMD_NO_CURSOR"))
    elseif command == "lock" then
        ADDON.SetUnlocked(false)
        Print(L("CMD_LOCKED"))
    elseif command == "test" then
        ADDON.AddTestEntry()
        if not ADDON.IsInCyrodiil() then
            -- The line is in the log but the log is not drawn here.
            Print(L("CMD_TEST_ELSEWHERE"))
        end
    elseif command == "clear" then
        ADDON.ClearLog()
        Print(L("CMD_CLEARED"))
    elseif command == "preview" then
        Print(ADDON.preview and ADDON.preview:Toggle() and L("CMD_PREVIEW_ON") or L("CMD_PREVIEW_OFF"))
    elseif command == "sound" then
        -- "on" / "off", or no option to flip the current state
        local enable
        if option == "on" then
            enable = true
        elseif option == "off" then
            enable = false
        else
            enable = not sv.killSound
        end
        ADDON.SetKillSound(enable)
        Print(enable and L("CMD_SOUND_ON") or L("CMD_SOUND_OFF"))
    elseif command == "reset" then
        ADDON.ResetWindowSettings()
        Print(L("CMD_RESET"))
    else
        Print(L("CMD_HELP"))
    end
end

---------------------------------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------------------------------

-- The version is written only in the manifest's ## Title line; read it back from there.
local function ReadManifestVersion()
    local manager = GetAddOnManager()
    for index = 1, manager:GetNumAddOns() do
        local name, title = manager:GetAddOnInfo(index)
        if name == ADDON.name and title then
            local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
            return plain:match("([%d]+[%d%.]*)%s*$") or ""
        end
    end
    return ""
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED)

    ADDON.version = ReadManifestVersion()
    ADDON.title = ADDON.version ~= "" and (DISPLAY_NAME .. " " .. ADDON.version) or DISPLAY_NAME

    ADDON.defaults = BuildDefaults()
    sv = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, ADDON.defaults)
    ADDON.sv = sv

    window = PBsKillLogWindow
    frame = PBsKillLogWindowFrame
    buffer = PBsKillLogWindowBuffer

    ADDON.ApplyLayout()
    ADDON.ApplyLayer()
    ADDON.ApplyFont()

    -- Visible on the HUD and while the cursor is free (chat, etc.); hidden in full-screen menus.
    fragment = ZO_SimpleSceneFragment:New(window)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_PVP_KILL_FEED_DEATH, OnPvpKillFeedDeath)
    EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_PLAYER_ACTIVATED, UpdateLogVisibility)
    SLASH_COMMANDS["/pbkl"] = OnSlashCommand

    if ADDON.InitializeSettings then
        ADDON.InitializeSettings()
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
