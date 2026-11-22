Teleport = {}

Teleport.COLORS = {
    NONE = nil,
    NOT_FOUND = "FF8811",
    NOT_UNLOCKED = "FF8811",
    
    ALIAS = "CCCCCC",
    
    ZONE = "FFAA11",
    WAYSHRINE = "FFAA11",
    DUNGEON = "FFAA11",
    HOUSE = "AAFFAA",
    
    PLAYER = "CCCCCC",
    LEADER = "AAFFAA",

    SURVEY = "3A93FF",
    QUEST = "3A93FF",
}

Teleport.info  =           function(msg) CHAT_SYSTEM:AddMessage("[Teleport]: "        .. msg) end
Teleport.dbg   = false and function(msg) CHAT_SYSTEM:AddMessage("[Teleport][DEBUG]: " .. msg) end or function() end

Teleport.color = function(msg, color) if color then return "|c" .. color .. msg .. "|r" end return msg end

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------

local function printHelp()
    info([[/tp <destination>: type the start of a name, any case.
Full manual: README.md in the addon folder, or
https://github.com/wjtk4444/eso-addons/tree/master/Teleport

Zones (free, through a group member, friend or guildmate there):
    /tp deshaan    /tp crag    /tp reach
Dungeons, trials, arenas (free if a group member is inside):
    /tp fg1    /tp vmol (veteran)    /tp nka (normal)    /tp rbrp (reset)
    /tp crypt of hearts
    /tp --aliases    (all short names)
Wayshrines (paid, free at a wayshrine):
    /tp vivec city    /tp solitude wayshrine
Your houses:
    /tp snugpod    /tp outside snugpod
Players and their houses:
    /tp @fren    /tp leader
    /tp @fren snug    /tp @fren primary
    /tp @@exactaccountname snugpod    (anyone, not just friends)
Survey and treasure maps, tracked quest (free if possible, paid otherwise):
    /tp maps    /tp maps free    /tp maps paid
    /tp quest   /tp quest free   /tp quest paid
Your own aliases:
    /tp --add s maps    /tp --add home @@myaccount primary
    /tp --list    /tp --remove s]])
end

--------------------------------------------------------------------------------

-- exact matches only, so prefixes like `/tp ma` / `/tp que` still search zones etc.
local COMMANDS = {
    ['maps']           = function() return Teleport.SurveyMaps:teleportToSurveyMap(true) end,
    ['maps free']      = function() return Teleport.SurveyMaps:teleportToSurveyMap()     end,
    ['maps paid']      = function() return Teleport.SurveyMaps:paidTeleportToSurveyMap() end,
    ['quest']          = function() return Teleport.Quests:teleportToQuest(true, false)  end,
    ['quest free']     = function() return Teleport.Quests:teleportToQuest(false, false) end,
    ['quest paid']     = function() return Teleport.Quests:teleportToQuest(false, true)  end,
}
-- pre-1.3 names, kept so existing aliases keep working
COMMANDS['bothsurveymaps'] = COMMANDS['maps']
COMMANDS['freesurveymaps'] = COMMANDS['maps free']
COMMANDS['paidsurveymaps'] = COMMANDS['maps paid']
COMMANDS['bothquest']      = COMMANDS['quest']
COMMANDS['freequest']      = COMMANDS['quest free']
COMMANDS['paidquest']      = COMMANDS['quest paid']

local function removeExtraWhitespace(args)
    if not args then return nil end
    args = string.gsub(args, "%s+", " ")
    args = string.gsub(args, "^%s*(.-)%s*$", "%1")
    return args
end

local function tp(args)
    args = removeExtraWhitespace(args)
    if not args or args =='' then
        info("Where to? See " .. color("/tp --help", C.NOT_FOUND) .. " for examples.")
        return
    end

    args = Teleport.Aliases:expandUserDefined(args)
   
    if args == '--help' or args == 'help' then return printHelp() end
    if args == '--aliases'       then return Teleport.Aliases:listDungeonAliases() end

    if Teleport.Helpers:startsWith(args, '--list') then
        return Teleport.Aliases:listAliases()
    end
    if Teleport.Helpers:startsWith(args, '--add') then
        return Teleport.Aliases:addAlias(string.sub(args, 7))
    end
    if Teleport.Helpers:startsWith(args, '--remove') then
        return Teleport.Aliases:removeAlias(string.sub(args, 10))
    end

    if args == 'leader'          then return Teleport.Players:teleportToLeader()           end
    local command = COMMANDS[args]
    if command then return command() end

    if Teleport.Helpers:startsWith(args, '@') then 
        local playerNamePrefix, houseNamePrefix = Teleport.Helpers:splitOnSpace(args)
        if playerNamePrefix and houseNamePrefix then
            return Teleport.Houses:teleportToPlayersHouse(playerNamePrefix, houseNamePrefix)
        else
            local player = Teleport.Players:findPlayerByNamePrefix(args, true)
            if not player then
                info("Failed to teleport to " .. color(args, C.NOT_FOUND) .. ": Player not found.")
                return
            end
            return Teleport.Players:teleportToPlayer(player)
        end
    end

    -- check dungeon alias-only matches first - they can start with n, v or r for [n]ormal, [v]eteran or [r]eset instances
    if Teleport.Dungeons:teleportToDungeon(args, true) then return end

    -- prioritize direct node travel when wayshrine menu is open
    if Teleport.Helpers:isAtWayshrine() then
        if Teleport.Wayshrines:teleportToWayshrine(args) then return end
        if Teleport.Dungeons  :teleportToDungeon  (args) then return end
        if Teleport.Houses    :teleportToHouse    (args) then return end
        if Teleport.Zones     :teleportToZone     (args) then return end
    else
        if Teleport.Zones     :teleportToZone     (args) then return end
        if Teleport.Dungeons  :teleportToDungeon  (args) then return end
        if Teleport.Houses    :teleportToHouse    (args) then return end
        if Teleport.Wayshrines:teleportToWayshrine(args) then return end
    end

    info("Failed to teleport to " .. color(args, C.NOT_FOUND) .. ": No dungeon/zone/house/wayshrine found")
end

EVENT_MANAGER:RegisterForEvent('Teleport', EVENT_ADD_ON_LOADED, function(_, addonName) 
        if addonName ~= 'Teleport' then return end
        
        EVENT_MANAGER:UnregisterForEvent('Teleport', EVENT_ADD_ON_LOADED)
        SLASH_COMMANDS['/tp'] = tp
        local SAVED_VARS = ZO_SavedVars:NewAccountWide('TeleportAliases', 1, nil, { ALIASES = { } })
        Teleport.Aliases:setSavedVars(SAVED_VARS.ALIASES)
		
		Teleport.Zones:initialize()
		Teleport.Nodes:initialize()
    end)
