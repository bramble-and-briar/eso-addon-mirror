-- NORCommands.lua — Utility slash commands for NOR Guild Tools

local Addon = NORGuildTools
Addon.Commands = Addon.Commands or {}
local Cmd = Addon.Commands

-- AutoLootToggle.lua - Slash command to toggle Auto Loot

local function ToggleAutoLoot()
    local currentState = GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT)
    local newState = (currentState == "1") and "0" or "1" -- Toggle between enabled (1) and disabled (0)
    
    SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT, newState)
    
    local statusMessage = (newState == "1") and "|c00FF00ENABLED|r" or "|cFF0000DISABLED|r"
    d("|cFFD700AutoLoot|r: Auto Loot is now " .. statusMessage .. ".")
end

-- Register slash command
SLASH_COMMANDS["/autoloot"] = ToggleAutoLoot

d("|cFFD700AutoLoot|r: AutoLootToggle initialized. Use /autoloot to toggle Auto Loot.")

local function ToggleSetting(system, settingId, enabledSound, disabledSound, label, color)
    local currentValue = tonumber(GetSetting(system, settingId))
    local newValue = (currentValue == 1) and "0" or "1"
    SetSetting(system, settingId, newValue)

    PlaySound((newValue == "1") and enabledSound or disabledSound)
    d("|c" .. color .. label .. ": " .. ((newValue == "1") and "|c00FF00Enabled|r" or "|cFF0000Disabled|r"))
end

-- Below are extra slash commands I've slipped in to toggle Thiefly settings
-- Slash Commands to Toggle Individual Settings
SLASH_COMMANDS["/steal"] = function()
    ToggleSetting(SETTING_TYPE_LOOT, LOOT_SETTING_PREVENT_STEALING_PLACED, SOUNDS.ITEM_SET_BONUS_GAINED, SOUNDS.ITEM_SET_BONUS_LOST, "Prevent Stealing Placed Items", "FFD700")
end

SLASH_COMMANDS["/murder"] = function()
    ToggleSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS, SOUNDS.DUEL_ACCEPT, SOUNDS.DUEL_DECLINE, "Prevent Attacking Innocents", "FF4500")
end

-- Slash Command to Toggle Both Settings at Once
SLASH_COMMANDS["/stealandmurder"] = function()
    d("|c00BFFFToggle Both Settings:")
    ToggleSetting(SETTING_TYPE_LOOT, LOOT_SETTING_PREVENT_STEALING_PLACED, SOUNDS.ITEM_SET_BONUS_GAINED, SOUNDS.ITEM_SET_BONUS_LOST, "Prevent Stealing Placed Items", "FFD700")
    ToggleSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS, SOUNDS.DUEL_ACCEPT, SOUNDS.DUEL_DECLINE, "Prevent Attacking Innocents", "FF4500")
end


-- These display Guild holdings in the chat window as a clickable reference if someone would rather use than G for guild menu.
SLASH_COMMANDS["/nor_holdings"] = function()
    d("|t34:34:/NORGuildTools/Textures/norlogodds.dds|t|c00FF00Choose a NOR property and click the link to jump to it:|r") -- Green prompt message
    d("|H1:housing:38:@Garadian|h1. New OutRiders Castle|h")
    d("|H1:housing:55:@Xirrasha|h2. Xirrasha's NOR Crafting/Mundus Stones|h ")
    d("|H1:housing:80:@Xirrasha|h3. NOR Combat Training/Duelling|h")
    d("|H1:housing:38:@AbinSur|h4. Abin's NOR Workshop|h")
    
    
end

NORRecruiting = {}

-- Function to send "Recruiting Message" to chat when /recruit is used
function NORRecruiting.SendGuildMessage()
	StartChatInput("|H1:guild:13021|hNew OutRiders|h [NOR] Looking for a guild to call home? Since 1992, NOR has brought gamers together through friendship and adventure! We're a mature, family-friendly community growing our ESO ranks. Enjoy questing, crafting, dungeons, or Saturday trials? Help shape NOR's next chapter! Check out our guild listing and apply today!", CHAT_CHANNEL_G1) -- Change if needed
end

-- Register the slash command
SLASH_COMMANDS["/nor_recruit"] = NORRecruiting.SendGuildMessage


HailNOR = {}

-- Function to send "Hail *NOR/" to guild chat when /h is used
function HailNOR.SendGuildMessage()
    StartChatInput("Hail *NOR/", CHAT_CHANNEL_G1) -- Change GUILD1 if needed
end

-- Register the slash command
SLASH_COMMANDS["/h"] = HailNOR.SendGuildMessage

-- Function to send private message to player chat on player activation/load-in
local function OnPlayerActivated()
    local playerName = GetUnitName("player")
    local accountName = GetDisplayName()

    d("|c00FF00Hail *NOR/!\nWelcome back, " .. playerName .. " (" .. accountName .. ")!|r\n|cFFFFFFNew OutRiders' Guild Tools Loaded!: Use /nor to access.|r")

    -- Unregister event after execution to prevent multiple triggers
    EVENT_MANAGER:UnregisterForEvent("HailNOR_OnPlayerActivated", EVENT_PLAYER_ACTIVATED)
end

--Summon Smuggler

SLASH_COMMANDS["/smuggler"] = function()
    if IsCollectibleUsable(300) then
        UseCollectible(300)
        d("Your smuggler has arrived!")
    else
        d("You can't summon that right now.")
    end
end

-- Logic for summoning assistants, jeez let's hope this one works, hard to test when I'm a brokie.
-- Define known assistant collectible IDs
local assistantIDs = {
    banker = {8994, 12413, 11097, 267}, -- Banking Assistants
    merchant = {9744, 301, 8955},       -- Merchant Assistants
    armory = {9745},                    -- Armory Assistants
    decon = {10617},                     -- Deconstruction Assistants
    smuggler = {300}                     -- Pirharri the Smuggler
}

-- Define NOR shield texture reference for chat messages
local norShieldTexture = "|t32:32:NORGuildTools/Textures/norlogodds.dds|t"

-- Function to summon an assistant based on category
local function SummonAssistant(category)
    local idList = assistantIDs[category]

    if idList then
        for _, id in ipairs(idList) do
            if IsCollectibleUsable(id) then
                UseCollectible(id)
                d(norShieldTexture .. " Summoning your " .. category .. " assistant!")
                return
            end
        end
        d(norShieldTexture .. " You don't have a usable " .. category .. " assistant.")
    else
        d(norShieldTexture .. " Unknown assistant type.")
    end
end

-- Register individual slash commands for each type
SLASH_COMMANDS["/banker"] = function() SummonAssistant("banker") end
SLASH_COMMANDS["/merchant"] = function() SummonAssistant("merchant") end
SLASH_COMMANDS["/armory"] = function() SummonAssistant("armory") end
SLASH_COMMANDS["/smuggler"] = function() SummonAssistant("smuggler") end
SLASH_COMMANDS["/decon"] = function() SummonAssistant("decon") end





-- Register event for player activation (fires after UI is fully loaded)
EVENT_MANAGER:RegisterForEvent("HailNOR_OnPlayerActivated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)




