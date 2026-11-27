-- ESO MoreTargetInformation

-- This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. 
-- The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. 
-- All rights reserved

----------------------------------------------------------------------------------------------------------------------------------------
local AddonInfo = {
  addon = "MoreTargetInformation",
  version = "3.52.0",
  author = "Lord Richter",
  savename = "MoreTargetInformationVars"
}

----------------------------------------------------------------------------------------------------------------------------------------
-- Addon configuration
----------------------------------------------------------------------------------------------------------------------------------------

local MTI = {
  target = {
    topline = "",
    bottomline = ""
  },
  updated = 0,
  debugstring = "",
  color = {
    white={r=1,g=1,b=1},
    darkcyan={r=0,g=0.8,b=0.8},
    cyan={r=0,g=1,b=1},
    darkred={r=0.5,g=0,b=0},
    red={r=1,g=0,b=0},
    pink={r=1,g=0.7,b=0.8},
    babyblue={r=0.45,g=0.75,b=0.93},
    darkblue={r=0,g=0,b=0.7},
    blue={r=0,g=0.25,b=1},
    purple={r=1,g=0,b=1},
    gold={r=1,g=0.8,b=0},
    yellow={r=1,g=1,b=0},
    gray={r=0.5,g=0.5,b=0.5},
    green={r=0,g=0.7,b=0},
    aquamarine={r=0.5,g=1,b=0.7},
    --
    textcolor = {r=1,g=1,b=1}
  },
  zo_nameplate = {},
  zo_caption = {},
  guild = {
    scanguild=1,
    member = {}
  },
  messages = {},
  settings = {
    announceguard=false,
    guildscan=15000,
    guildmax=5,
    guildmin=1
  },
  savedvariables = {}  
}

local Encounter = {
  type = 0,
  level = "",
  champrank = "",
  title = "",
  reaction = 0,  
  guard = false,
  color = {
    namecolor = MTI.color.white,
    captioncolor = MTI.color.white
  },
  name = {
    primary = "",
    secondary = "",
  }
}

local gender = { "Female" , "Male" }

-- localize calls to ESO API
local CHAT_ROUTER = CHAT_ROUTER
local GetAllianceName = GetAllianceName
local GetAllianceSymbolIcon = ZO_GetAllianceSymbolIcon
local GetAvARankName = GetAvARankName
local GetGuildId = GetGuildId
local GetGuildMemberCharacterInfo = GetGuildMemberCharacterInfo
local GetGuildMemberInfo = GetGuildMemberInfo
local GetGuildName = GetGuildName
local GetMapName = GetMapName
local GetNumGuildMembers = GetNumGuildMembers
local GetPlatformClassIcon = ZO_GetPlatformClassIcon
local GetSetting = GetSetting
local GetUniqueNameForCharacter = GetUniqueNameForCharacter
local GetUnitAlliance = GetUnitAlliance
local GetUnitAvARank = GetUnitAvARank
local GetUnitCaption = GetUnitCaption
local GetUnitChampionPoints = GetUnitChampionPoints
local GetUnitClass = GetUnitClass
local GetUnitClassId = GetUnitClassId
local GetUnitDisplayName = GetUnitDisplayName
local GetUnitGender = GetUnitGender
local GetUnitLevel = GetUnitLevel
local GetUnitName = GetUnitName
local GetUnitRace = GetUnitRace
local GetUnitRaceId = GetUnitRaceId
local GetUnitReaction = GetUnitReaction
local GetUnitTitle = GetUnitTitle
local GetUnitType = GetUnitType
local GetUnitZone = GetUnitZone
local IsInGamepadPreferredMode = IsInGamepadPreferredMode
local IsUnitFriend = IsUnitFriend
local IsUnitGroupLeader = IsUnitGroupLeader
local IsUnitGrouped = IsUnitGrouped
local IsUnitIgnored = IsUnitIgnored
local IsUnitInvulnerableGuard = IsUnitInvulnerableGuard
local IsUnitJusticeGuard = IsUnitJusticeGuard
local UNIT_TYPE_MONSTER = 2
local UNIT_TYPE_OTHER = 11
local UNIT_TYPE_PLAYER = 1
local ZO_GetAllianceSymbolIcon = ZO_GetAllianceSymbolIcon
local ZO_GetPlatformClassIcon  = ZO_GetPlatformClassIcon
local ZO_GetPrimaryPlayerName = ZO_GetPrimaryPlayerName
local ZO_FormatUserFacingCharacterName = ZO_FormatUserFacingCharacterName
local zo_iconFormat = zo_iconFormat
local zo_strformat = zo_strformat

-- define icons
local ICON_SIZE = 24
local CHARACTER_NAME_ICON = "/esoui/art/miscellaneous/gamepad/gp_charEncounter.nameicon.dds"
local FRIEND_ICON_TEXTURE = "/esoui/art/campaign/campaignbrowser_friends.dds"
local GUILD_ICON_TEXTURE = "/esoui/art/campaign/campaignbrowser_guild.dds"
local IGNORE_ICON_TEXTURE = "/esoui/art/contacts/tabicon_ignored_up.dds"
local LEADER_ICON_TEXTURE = "/esoui/art/unitframes/groupicon_leader.dds"
local GROUP_LEADER_ICON = "/esoui/art/icons/mapkey/mapkey_groupleader.dds"
local GROUP_MEMBER_ICON = "/esoui/art/icons/mapkey/mapkey_groupmember.dds"
local RACE_ALTMER_ICON = "/esoui/art/charactercreate/charactercreate_altmericon_down.dds"
local RACE_ARGONIAN_ICON = "/esoui/art/charactercreate/charactercreate_argonianicon_down.dds"
local RACE_BOSMER_ICON = "/esoui/art/charactercreate/charactercreate_bosmericon_down.dds"
local RACE_BRETON_ICON = "/esoui/art/charactercreate/charactercreate_bretonicon_down.dds"
local RACE_DUNMER_ICON = "/esoui/art/charactercreate/charactercreate_dunmericon_down.dds"
local RACE_IMPERIAL_ICON = "/esoui/art/charactercreate/charactercreate_imperialicon_down.dds"
local RACE_KHAJIIT_ICON = "/esoui/art/charactercreate/charactercreate_khajiiticon_down.dds"
local RACE_NORD_ICON = "/esoui/art/charactercreate/charactercreate_nordicon_down.dds"
local RACE_ORC_ICON = "/esoui/art/charactercreate/charactercreate_orcicon_down.dds"
local RACE_REDGUARD_ICON =  "/esoui/art/charactercreate/charactercreate_redguardicon_down.dds"
local RACE_ICONS = { RACE_BRETON_ICON, RACE_REDGUARD_ICON, RACE_ORC_ICON, RACE_DUNMER_ICON, RACE_NORD_ICON, RACE_ARGONIAN_ICON, RACE_ALTMER_ICON, RACE_BOSMER_ICON, RACE_KHAJIIT_ICON, RACE_IMPERIAL_ICON }

-- ESO 2.4 top line:  (CHAMPIONICON) (LEVEL) (NAME) (RANKICON)
--    bottom line:  (CAPTION)

-- debug
local GUARD_ANNOUNCE_SOUND = SOUNDS.JUSTICE_STATE_CHANGED
local guardnotification = false

-- ----------------------------------------------------------------------------------------------------------------------
-- Utility
-- ----------------------------------------------------------------------------------------------------------------------
local function initializeTable(template)
  local t2 = {}
  local k,v
  for k,v in pairs(template) do
    t2[k] = v
  end
  return t2 
end

local function DisplayMessage(text)
  if text and text~="" and CHAT_ROUTER then
    CHAT_ROUTER:AddDebugMessage(text)
  end 
end

-- ----------------------------------------------------------------------------------------------------------------------
-- Override ZOS function with ours
-- ----------------------------------------------------------------------------------------------------------------------
--function ZO_GetPrimaryPlayerNameWithSecondary(crossplayDisplayName, characterName, platformDisplayName)
--  local primaryName = ZO_GetPrimaryPlayerName(crossplayDisplayName, characterName, platformDisplayName, true)
--  return primaryName
--end

-- ----------------------------------------------------------------------------------------------------------------------
-- UI Refresh
-- Very brief since it is called so often
-- ----------------------------------------------------------------------------------------------------------------------
function MoreTargetInformation_Update()
  -- only do this if there has been an update since the last time we were here
  if MTI.updated == 1 then
    MTI.updated = 0
    if (Encounter.type==UNIT_TYPE_PLAYER) then
      ZO_TargetUnitFramereticleoverName:SetColor(Encounter.color.namecolor["r"],Encounter.color.namecolor["g"],Encounter.color.namecolor["b"],1)
      ZO_TargetUnitFramereticleoverName:SetText(MTI.target.topline)
      ZO_TargetUnitFramereticleoverLevel:SetHidden(false)
      ZO_TargetUnitFramereticleoverLevel:SetColor(MTI.color.textcolor["r"],MTI.color.textcolor["g"],MTI.color.textcolor["b"],1)
      ZO_TargetUnitFramereticleoverLevel:SetText(Encounter.level)
      ZO_TargetUnitFramereticleoverCaption:SetHidden(false)
      ZO_TargetUnitFramereticleoverCaption:SetColor(Encounter.color.captioncolor["r"],Encounter.color.captioncolor["g"],Encounter.color.captioncolor["b"],1)
      ZO_TargetUnitFramereticleoverCaption:SetText(MTI.target.bottomline)
    elseif (Encounter.type>=UNIT_TYPE_MONSTER) then 
      ZO_TargetUnitFramereticleoverName:SetColor(Encounter.color.namecolor["r"],Encounter.color.namecolor["g"],Encounter.color.namecolor["b"],1)
      ZO_TargetUnitFramereticleoverName:SetText(MTI.target.topline)
      if (string.len(MTI.target.bottomline)>0) then
        ZO_TargetUnitFramereticleoverCaption:SetHidden(false)
        ZO_TargetUnitFramereticleoverCaption:SetColor(Encounter.color.captioncolor["r"],Encounter.color.captioncolor["g"],Encounter.color.captioncolor["b"],1)
        ZO_TargetUnitFramereticleoverCaption:SetText(MTI.target.bottomline)
      end
    end

    if Encounter.guard and MTI.savedvariables.announceguard and GetFullBountyPayoffAmount()>0 and guardnotification then
      guardnotification = false
      PlaySound( GUARD_ANNOUNCE_SOUND )
    end
  end
end


-- ----------------------------------------------------------------------------------------------------------------------
-- Guild management
-- ----------------------------------------------------------------------------------------------------------------------
local function clearGuildTable()
  local index
  for index in pairs (MTI.guild.member) do
    MTI.guild.member[index].character = nil
    MTI.guild.member[index].firstguild = { size = 0, name="" }
    MTI.guild.member[index].size = { }
    MTI.guild.member[index].guildlist = nil
    MTI.guild.member[index].guild = nil
    MTI.guild.member[index] = false
  end
end

-- ----------------------------------------------------------------------------------------------------------------------
local function getGuildMembership()

  local guildnum = MTI.guild.scanguild

  local id = GetGuildId(guildnum)

  if id then 
    local members = GetNumGuildMembers(id)
    local guildname = GetGuildName(id)

    -- update character history based on the member information
    local member = 0

    for member = 1,members,1 do
      local player, note, rank, status, activelast = GetGuildMemberInfo(id,member)
      local hasCharacter, characterName, zoneName, classid, alliance, level, championRank = GetGuildMemberCharacterInfo(id,member)

      if hasCharacter and members>1 then
        local caret = string.len(characterName) - 3
        local character = ""
        if caret>0 then
          character = string.sub(characterName,1,caret)
        end
        -- add player in database
        MTI.guild.member[player]={}
        MTI.guild.member[player].character = character
        MTI.guild.member[player].firstguild = MTI.guild.member[player].firstguild or { size = 0, name = "" }
        if MTI.guild.member[player].firstguild.size<members then
          MTI.guild.member[player].firstguild.name = guildname
          MTI.guild.member[player].firstguild.size = members
        end     
      end
    end
  end
  
  -- next guild scan
  guildnum = guildnum + 1
  
  if guildnum>MTI.settings.guildmax then
    guildnum = MTI.settings.guildmin
    MTI.guild.scanguild = guildnum
  else
    MTI.guild.scanguild = guildnum
    zo_callLater(getGuildMembership,MTI.settings.guildscan)  
  end
  
  
end

-- ----------------------------------------------------------------------------------------------------------------------
local function startGuildQueries()

  MTI.guild = {}
  MTI.guild.scanguild = MTI.settings.guildmin
  MTI.guild.member = {}

  zo_callLater(getGuildMembership,MTI.settings.guildscan)
  
end   

-- ----------------------------------------------------------------------------------------------------------------------
local function IsUnitGuild(player)
  local guild = nil
  local maxrank = 0
  local inguild = player and MTI and MTI.guild and MTI.guild.member and MTI.guild.member[player]
  if inguild then
    guild = MTI.guild.member[player].firstguild.name
  end

  return inguild, guild
end

-- ----------------------------------------------------------------------------------------------------------------------
-- SLASH COMMAND: guardalert
-- ----------------------------------------------------------------------------------------------------------------------
local function ToggleGuardAlert()

  if MTI.savedvariables.announceguard then
    MTI.savedvariables.announceguard = false
    DisplayMessage("Guard alert sound OFF")
  else
    MTI.savedvariables.announceguard = true
    DisplayMessage("Guard alert sound ON")
  end
  
end

-- ----------------------------------------------------------------------------------------------------------------------
-- Event Handlers
-- ----------------------------------------------------------------------------------------------------------------------

-- ----------------------------------------------------------------------------------------------------------------------
-- Target Change event handler
-- this fires when the target changes, then sets everything up for the next UI update
-- ----------------------------------------------------------------------------------------------------------------------
local function MTIOnTargetChange(eventCode)
  local unitTag = "reticleover"
  local type = GetUnitType(unitTag)
  local name = GetUnitName(unitTag)
  local player = GetUnitDisplayName(unitTag)

  MTI.prefernamesetting = tonumber(GetSetting(SETTING_TYPE_UI,((not IsInGamepadPreferredMode()) and UI_SETTING_PRIMARY_PLAYER_NAME_KEYBOARD) or UI_SETTING_PRIMARY_PLAYER_NAME_GAMEPAD)) == PRIMARY_PLAYER_NAME_SETTING_PREFER_CHARACTER
  Encounter.color.captioncolor = MTI.color.white

  -- catch instances where there is no longer anything to look at
  if name == nil or name == "" then
    MTI.target.topline = ""
    Encounter.type = 0
    MTI.updated = 1
    return
  end

  Encounter.reaction = GetUnitReaction(unitTag);
  Encounter.type = type

  -- NPCs are type 2+, Players are type 1
  if type == UNIT_TYPE_PLAYER then
    Encounter.color.namecolor = MTI.color.white

    -- target gender
    local genderstr = "Genderless"
    local gendernum = GetUnitGender(unitTag)
    if gendernum>0 and gendernum<3 then
      genderstr = gender[gendernum]
    end

    -- target guild affiliation relative to player
    local inguild, guild = IsUnitGuild(player)

    -- character level or account champion points
    Encounter.level = "Level " .. GetUnitLevel(unitTag)
    local rank = GetUnitChampionPoints(unitTag)
    Encounter.champrank = rank

    if rank>0 then
      Encounter.level = Encounter.champrank
    end

    -- target title
    Encounter.title = GetUnitTitle(unitTag)

    -- collect remaining information about target
    local classname = GetUnitClass(unitTag)

    local classicon = ZO_GetPlatformClassIcon(GetUnitClassId(unitTag))
    local racename = GetUnitRace(unitTag)
    -- local raceicon = RACE_ICONS[(GetUnitRaceId(unitTag))]
    local raceclass = GetUnitRace(unitTag) .. " " .. zo_iconFormat(classicon,ICON_SIZE,ICON_SIZE) .. " " .. GetUnitClass(unitTag)

    local avarank = GetUnitAvARank(unitTag)
    local avarankname = GetAvARankName(gendernum,avarank)
    local alliance = GetUnitAlliance(unitTag)
    local alliancename = ""
    local allianceicon = ""

    if alliance>0 then
      alliancename = alliancename ..GetAllianceName(alliance) .. " "
      local allianceiconname = ZO_GetAllianceSymbolIcon(alliance)
      allianceicon = zo_iconFormat(allianceiconname,ICON_SIZE,ICON_SIZE)
    end


    Encounter.name.primary = name
    Encounter.name.secondary = ZO_FormatUserFacingCharacterName(GetUnitDisplayName(unitTag))
    Encounter.guildname = ""

    -- if ignored, summary information, otherwise more detailed
    if IsUnitIgnored(unitTag) then
      Encounter.nameicon = MTI.ignoreicon
      Encounter.color.namecolor = MTI.color.pink
      MTI.target.topline = zo_strformat("<<1>><<2>> (<<3>>) ",Encounter.nameicon,Encounter.name.primary,Encounter.name.secondary)
      MTI.target.bottomline = ""
    else
      Encounter.color.namecolor = MTI.color.darkcyan
      Encounter.color.captioncolor = MTI.color.white

      if inguild then
        Encounter.nameicon = MTI.guildicon
        Encounter.guildname = "<"..guild..">"
        Encounter.color.captioncolor = MTI.color.green
      end

      if IsUnitFriend(unitTag) then
        Encounter.color.namecolor = MTI.color.cyan
        Encounter.nameicon = MTI.friendicon
      end

      if IsUnitGrouped(unitTag) then
        Encounter.color.namecolor = MTI.color.babyblue
        if IsUnitGroupLeader(unitTag) then Encounter.nameicon = MTI.groupleadericon
        else Encounter.nameicon = MTI.groupmembericon
        end
      end

      if MTI.prefernamesetting then
        if Encounter.title ~= "" then
          MTI.target.topline = zo_strformat("<<1>><<2>>, <<3>> ",Encounter.nameicon,Encounter.name.primary,Encounter.title)
        else
          MTI.target.topline = zo_strformat("<<1>><<2>> ",Encounter.nameicon,Encounter.name.primary)
        end
        MTI.target.bottomline = zo_strformat("<<1>> <<2>>",raceclass,Encounter.guildname)
      else
        if Encounter.title ~= "" then
          MTI.target.topline = zo_strformat("<<1>><<2>>, <<3>> ",Encounter.nameicon,Encounter.name.primary,Encounter.title)
        else
          MTI.target.topline = zo_strformat("<<1>><<2>> ",Encounter.nameicon,Encounter.name.primary)
        end
        MTI.target.bottomline = zo_strformat("(<<1>>) <<2>> <<3>>",Encounter.name.secondary,raceclass,Encounter.guildname)
      end
    end
  elseif type >= UNIT_TYPE_MONSTER then
    Encounter.color.namecolor = MTI.color.white
    -- just the name for now
    MTI.target.topline = name
    MTI.target.bottomline = ""
    Encounter.guard = IsUnitInvulnerableGuard(unitTag) or IsUnitJusticeGuard(unitTag)
    guardnotification = Encounter.guard

    Encounter.level = "Level " .. GetUnitLevel(unitTag)
    local rank = GetUnitChampionPoints(unitTag)
    Encounter.champrank = rank

    if rank>0 then
      Encounter.level = Encounter.champrank
    end

    -- shopkeepers and other non-combat units just show name
    if Encounter.reaction == UNIT_REACTION_NEUTRAL then
      Encounter.level = ""
      Encounter.color.namecolor = MTI.color.yellow
    elseif Encounter.reaction == UNIT_REACTION_HOSTILE then
      Encounter.level = ""
      Encounter.color.namecolor = MTI.color.red
    elseif Encounter.reaction == UNIT_REACTION_DEAD then
      Encounter.level = ""
      Encounter.color.namecolor = MTI.color.gray
      --elseif Encounter.reaction == UNIT_REACTION_COMPANION then
    elseif Encounter.reaction == 6 then
      Encounter.nameicon = MTI.friendicon
      Encounter.color.namecolor = MTI.color.babyblue
      MTI.target.topline = zo_strformat("<<1>><<2>> ",Encounter.nameicon,name)
      MTI.target.bottomline = Encounter.level .. " Companion"
    else
      Encounter.level = ""
      Encounter.color.namecolor = MTI.color.green
    end
  else
    MTI.target.topline = name
  end
  MTI.updated = 1
end


-- ----------------------------------------------------------------------------------------------------------------------
-- Guild Event Handlers
-- ----------------------------------------------------------------------------------------------------------------------
local function MTIGuildMemberAddedEvent(eventCode, guildId, displayName)
  clearGuildTable()
  startGuildQueries()
end 

-- ----------------------------------------------------------------------------------------------------------------------
local function MTIGuildMemberRemovedEvent(eventCode, guildId, displayName, characterName)
  clearGuildTable()
  startGuildQueries()
end   

-- ----------------------------------------------------------------------------------------------------------------------
local function MTIGuildSelfLeftEvent(eventCode, guildId, guildName)
  clearGuildTable()
  startGuildQueries()
end   

-- ----------------------------------------------------------------------------------------------------------------------
local function MTIGuildSelfJoinedEvent(eventCode, guildId, guildName)
  clearGuildTable()
  startGuildQueries()
end 

-- ----------------------------------------------------------------------------------------------------------------------
-- Initialize addon
-- ----------------------------------------------------------------------------------------------------------------------
local function LoadAddon(eventCode, addOnName)

  if(addOnName == AddonInfo.addon) then
  
    MTI.savedvariables = ZO_SavedVars:NewCharacterIdSettings(AddonInfo.savename,1,nil,MTI.settings)
    
    startGuildQueries()
    
    MTI.ignoreicon=""
    if zo_iconFormat(IGNORE_ICON_TEXTURE,ICON_SIZE,ICON_SIZE) then
      MTI.ignoreicon = zo_iconFormat(IGNORE_ICON_TEXTURE,ICON_SIZE,ICON_SIZE)
    end

    MTI.friendicon="" 
    if zo_iconFormat(FRIEND_ICON_TEXTURE,ICON_SIZE,ICON_SIZE) then
      MTI.friendicon = zo_iconFormat(FRIEND_ICON_TEXTURE,ICON_SIZE,ICON_SIZE)
    end

    MTI.guildicon=""  
    if zo_iconFormat(GUILD_ICON_TEXTURE,ICON_SIZE,ICON_SIZE) then
      MTI.guildicon = zo_iconFormat(GUILD_ICON_TEXTURE,ICON_SIZE,ICON_SIZE)
    end   

    MTI.playericon="" 
    if zo_iconFormat(CHARACTER_NAME_ICON,ICON_SIZE,ICON_SIZE) then
      MTI.playericon = zo_iconFormat(CHARACTER_NAME_ICON,ICON_SIZE,ICON_SIZE)
    end   

    MTI.groupleadericon=""  
    if zo_iconFormat(GROUP_LEADER_ICON,ICON_SIZE,ICON_SIZE) then
      MTI.groupleadericon = zo_iconFormat(GROUP_LEADER_ICON,ICON_SIZE,ICON_SIZE)
    end   

    MTI.groupmembericon=""  
    if zo_iconFormat(GROUP_MEMBER_ICON,ICON_SIZE,ICON_SIZE) then
      MTI.groupmembericon = zo_iconFormat(GROUP_MEMBER_ICON,ICON_SIZE,ICON_SIZE)
    end 

    if (LibNorthCastle) then LibNorthCastle:Register(AddonInfo.addon,AddonInfo.version) end

    EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_GUILD_MEMBER_CHARACTER_UPDATED, MTIGuildMemberAddedEvent)
    EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_GUILD_MEMBER_ADDED, MTIGuildMemberAddedEvent)
    EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_GUILD_MEMBER_REMOVED, MTIGuildMemberRemovedEvent)
    EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_GUILD_SELF_JOINED_GUILD, MTIGuildSelfJoinedEvent)
    EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_GUILD_SELF_LEFT_GUILD, MTIGuildSelfLeftEvent) 
    EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_RETICLE_TARGET_CHANGED, MTIOnTargetChange)
    EVENT_MANAGER:UnregisterForEvent(AddonInfo.addon, EVENT_ADD_ON_LOADED)
    
    SLASH_COMMANDS["/guardalert"] = ToggleGuardAlert
  end

end

-- ----------------------------------------------------------------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_ADD_ON_LOADED, LoadAddon)
