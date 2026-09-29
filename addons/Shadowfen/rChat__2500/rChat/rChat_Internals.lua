--[[ ---------------------------------------
This file separates out functions that are used by rChat but that
are "testable" because they use few enough of the ZOS functions
that I don't have to reproduce the entirety of ESO in my offline
test environment.
--]] ---------------------------------------

local ZO_ChatSystem_GetCategoryColorFromChannel = ZO_ChatSystem_GetCategoryColorFromChannel
local ZO_LinkHandler_CreateLink= ZO_LinkHandler_CreateLink
local zo_strformat = zo_strformat
local ZO_LinkHandler_CreateLinkWithoutBrackets = ZO_LinkHandler_CreateLinkWithoutBrackets
rChat_Internals = {}


local SF = LibSFUtils

local L = GetString


local RC_SEGTYPE_BARE = 0
local RC_SEGTYPE_MENTION = 1
local RC_SEGTYPE_LINK = 2
local RC_SEGTYPE_PAD = 3
local RC_SEGTYPE_TEXTURE = 4
local RC_SEGTYPE_QUICKLINK = 5

-- Used for rChat LinkHandling
local RCHAT_LINK = "p"
local RCHAT_URL_CHAN = 97
local RCHAT_CHANNEL_NONE = 99

-- "decision" tables for various channel groups
-- if entry is not nil then it belongs to the group
-- if it is true then it has special colors in GetChannelColors()
local npc_channels = {
    [CHAT_CHANNEL_MONSTER_SAY] = true,
    [CHAT_CHANNEL_MONSTER_YELL] = true,
    [CHAT_CHANNEL_MONSTER_WHISPER] = true,
    [CHAT_CHANNEL_MONSTER_EMOTE] = true,
}
local guild_mem_channels = {
    [CHAT_CHANNEL_GUILD_1] = true,
    [CHAT_CHANNEL_GUILD_2] = true,
    [CHAT_CHANNEL_GUILD_3] = true,
    [CHAT_CHANNEL_GUILD_4] = true,
    [CHAT_CHANNEL_GUILD_5] = true,
}
local guild_ofc_channels = {
    [CHAT_CHANNEL_OFFICER_1] = true,
    [CHAT_CHANNEL_OFFICER_2] = true,
    [CHAT_CHANNEL_OFFICER_3] = true,
    [CHAT_CHANNEL_OFFICER_4] = true,
    [CHAT_CHANNEL_OFFICER_5] = true,
}
local lang_zone_channels = {
    [CHAT_CHANNEL_ZONE_LANGUAGE_1] = true,
    [CHAT_CHANNEL_ZONE_LANGUAGE_2] = true,
    [CHAT_CHANNEL_ZONE_LANGUAGE_3] = true,
    [CHAT_CHANNEL_ZONE_LANGUAGE_4] = true,
    [CHAT_CHANNEL_ZONE_LANGUAGE_5] = true,
    [CHAT_CHANNEL_ZONE_LANGUAGE_6] = true,
    [CHAT_CHANNEL_ZONE_LANGUAGE_7] = true,
}

--Detect the QuickChat messages |s<number><number:optional><number:optional><number:optional>|s
-- (taken from pChat with permission)
local function isQuickLink(text, start)
	local start, _ = string.find(text, "|s%d%d-|s", start)
	return start
end


-- return true if chanCode is one of the two whisper channels
local function isWhisperChannel( chanCode )
    return (chanCode == CHAT_CHANNEL_WHISPER or chanCode == CHAT_CHANNEL_WHISPER_SENT)
end

-- return true if chanCode is one of the NPC/Monster chat channels
local function isMonsterChannel( chanCode )
    if npc_channels[chanCode] then
        return true
    end
    return false
end

-- return true if the chanCode is one of the guild or guild officer channels
local function isGuildChannel( chanCode )
    if guild_mem_channels[chanCode] then
        return true
    elseif guild_ofc_channels[chanCode]  then
        return true
    end
    return false
end
--rChat_Internals.isGuildChannel = isGuildChannel     -- make available

-- return true if chanCode is one of the language zone channels
local function isLanguageChannel( chanCode )
    return lang_zone_channels[chanCode] ~= nil
end

-------------------------------------------------------
-- return the index of the guild associated with the channel
-- that was passed in. If the channel is not associated with a
-- guild, then return 0.
function rChat_Internals.GetGuildIndex(channel)
    if not channel then return 0,false end
    local index = 0
    local isOfc = false
    if channel >= CHAT_CHANNEL_GUILD_1 and channel <= CHAT_CHANNEL_GUILD_5 then
        index = channel - CHAT_CHANNEL_GUILD_1 + 1
    elseif channel >= CHAT_CHANNEL_OFFICER_1 and channel <= CHAT_CHANNEL_OFFICER_5 then
        index = channel - CHAT_CHANNEL_OFFICER_1 + 1
        isOfc = true
    end
    return index, isOfc
end


-- creates raw and display-ready timestamp strings for the current time
function rChat_Internals.formatTimestamp(entry, ndx)
    local db = rChat.save
    if not db.showTimestamp then return "","" end

    -- Message is timestamp for now
    -- Add RCHAT_HANDLER for display
    local tsString = rChat.CreateTimestamp(db.timestampFormat)
    local timestamp = rChat.LinkHandler_CreateLink( ndx, entry.channel, tsString ) .. " "

    -- Timestamp color
    local display = timestamp
    local raw = string.format("[%s] ", tsString)
    return display, raw
end

-- create guild/officer tag
function rChat_Internals.formatTag(entry, ndx)
     local db = rChat.save

   -- Guild tag
    local guild_number, isOfc = rChat_Internals.GetGuildIndex(entry.channel)
    if guild_number == 0 then return nil end

    local guild_name = SF.SafeGetGuildName(guild_number)
    local tag
    if not isOfc then
        tag = db.guildTags[guild_name]
    else
        tag = db.officertag[guild_name]
    end
    if not tag or tag == "" then
        tag = guild_name
    end

    if db.showGuildNumbers then
        tag = guild_number .. "-" .. tag
    end

    local link_tag = ""
    if tag then
        link_tag = ZO_LinkHandler_CreateLink(tag, nil, CHANNEL_LINK_TYPE, entry.channel) or ""
        tag = "["..tag.."] "
        link_tag = link_tag .. " "
    end

    return link_tag, tag
end

-- overall message format
--  [timestamp] from separator text
--
function rChat_Internals.reduceString(entry, ndx, lvl)

    local rawS = {}     -- A list of strings to turn into a reduced message
	if not lvl then lvl = 0 end

	rawS[#rawS+1] = "*"	-- I'm a reduced message

    -- timestamp
	if lvl == 0 then
		-- try to keep the copy link (without color)
		rawS[#rawS+1] = entry.displayT.timestamp
	elseif lvl == 1 then
		rawS[#rawS+1] = entry.rawT.timestamp
	elseif lvl == 2 then
		-- absolute minimum - no timestamp
	end

    -- message header

    if entry.original.fromDisplayName then
		local name = zo_strformat(SI_UNIT_NAME, entry.original.fromDisplayName)

		if lvl == 0 then
			-- minimal from with linking
			rawS[#rawS+1] = "|H0:display:"..name.."|h"..name.."|h"
		else
			-- no linking
			rawS[#rawS+1] = name
		end
    end

    -- colon and optional CR
	if lvl == 0 then
		rawS[#rawS+1] = entry.rawT.separator
	else
		rawS[#rawS+1] = ": "
	end

    -- message body
    -- text might be a string or it might be a table of segments
    --    (whose first value is a string)
	-- no links!
    local text = entry.rawT.text
    if text then
        if type(text) == "string" then
            rawS[#rawS+1] = text
        elseif type(text) == "table" then
            for _,v in ipairs(text) do
                rawS[#rawS+1] = v[1]
            end
        end
    end

	text = table.concat(rawS)
	if lvl == 2 then
		text = string.sub(text,1,350)
	end
    return text
end

-- overall message format
--  [timestamp] [guildtag|partyTag|langtag|whisptag] from [zonetag] separator linktext
--
function rChat_Internals.produceRawString(entry, ndx, rawT)
    if not rawT then return "" end

    local rawS = {}     -- A list of strings to turn into a raw message

    -- timestamp
    if not rawT.timestamp then return "" end  -- timestamps are required!
    rawS[#rawS+1] = rawT.timestamp

    -- message header

    -- optional party, guild, language, whisper tag
    if rawT.partyTag then
        rawS[#rawS+1] = rawT.partyTag
    elseif rawT.tag then        -- note: this is the guild tag
        rawS[#rawS+1] = rawT.tag
    elseif rawT.languageTag then
        rawS[#rawS+1] = rawT.languageTag
    elseif rawS.whisper then
        rawS[#rawS+1] = rawT.whisper
    end

    if rawT.from then
        rawS[#rawS+1] = rawT.from
    end

    if rawT.zonetag then
        rawS[#rawS+1] = rawT.zonetag
    end
    -- colon and optional CR
    rawS[#rawS+1] = rawT.separator

    -- message body
    -- text might be a string or it might be a table of segments
    --    (whose first value is a string)
    local text = rawT.text
    if text then
        if type(text) == "string" then
            rawS[#rawS+1] = text
        elseif type(text) == "table" then
            for _,v in ipairs(text) do
                rawS[#rawS+1] = v[1]
            end
        end
    end

    return table.concat(rawS)
end

-- overall message format
--  [timestamp] lcol[guildtag|partyTag|langtag|whisptag] from [zonetag] |r separator rcol linktext |r
--
-- Similar message format as used by produceRawString, but this function will
-- produce a message string containing colors, links, etc.
-- The colorT table provides the various colors that are applicable to THIS message.
function rChat_Internals.produceDisplayString(entry, ndx, displayT, colorT)
    if not displayT then return "" end
    local db = rChat.save

    -- get colors for current message -  (see initColorTable() )
    local tcol, lcol, rcol, mcol = colorT.timecol, colorT.lcol, colorT.rcol, colorT.mentioncol

    -- message header

    local displayS = {}     -- A list of strings to turn into a display message

    -- timestamp and lcol
    if db.showTimestamp and db.showTimestamp == true then
        if displayT.timestamp and tcol  then
            displayS[#displayS+1] = tcol .. displayT.timestamp .. "|r" .. lcol
        elseif displayT.timestamp then
            displayS[#displayS+1] = lcol .. displayT.timestamp
        end
    else
        displayS[#displayS+1] = lcol
    end

    -- optional party, guild, language, whisper tag
    if displayT.partyTag then
        displayS[#displayS+1] = displayT.partyTag
    elseif displayT.tag then
        displayS[#displayS+1] = displayT.tag    -- note: this is the guild tag
    elseif displayT.languageTag then
        displayS[#displayS+1] = displayT.languageTag
    elseif displayT.whisper then
        displayS[#displayS+1] = displayT.whisper
    end

    if displayT.from then
        displayS[#displayS+1] = displayT.from
    end

    if displayT.zonetag then
        displayS[#displayS+1] = displayT.zonetag
    end
    -- colon and optional CR
    displayS[#displayS+1] = "|r"        -- end of lcol
    displayS[#displayS+1] = displayT.separator

    -- message body
    local text = displayT.text
    if text then
        if type(text) == "string" then
            --displayS[#displayS+1] = rcol .. text .. "|r"
            displayS[#displayS+1] = text
        elseif type(text) == "table" then
            for _,v in ipairs(text) do
                if v[2] == RC_SEGTYPE_MENTION and mcol then
                    displayS[#displayS+1] = v[1]
                    --displayS[#displayS+1] = mcol .. v[1] .. "|r"
                else
                    displayS[#displayS+1] = v[1]
                    --displayS[#displayS+1] = rcol .. v[1] .. "|r"
                end
            end
        end
    end

    return table.concat(displayS)
end

-- overall copy from format
--  [guildtag|partyTag|langtag|whisptag] from [zonetag]
--
-- npc and emote format never has []s
-- otherwise [] around player is controllable
function rChat_Internals.produceCopyFrom(entry, ndx, rawT)
    if not rawT then return "" end

    local rawS = {}

    -- message header (only)

    -- optional party, guild, language, whisper tag
    if rawT.partyTag then
        rawS[#rawS+1] = rawT.partyTag
    elseif rawT.tag then
        rawS[#rawS+1] = rawT.tag
    elseif rawT.languageTag then
        rawS[#rawS+1] = rawT.languageTag
    end

    if rawT.from then
        rawS[#rawS+1] = rawT.from
    end

    if rawT.zonetag then
        rawS[#rawS+1] = rawT.zonetag
    end
    -- colon and optional CR
    rawS[#rawS+1] = rawT.separator

    return table.concat(rawS)
end

-- creates formatted zonetag/partyTag for message prefix
-- returns linked and raw zone and party tags (which will be nil if nozonetags is true)
-- returns nil if not applicable
function rChat_Internals.formatZoneTag(entry, ndx)
    local db = rChat.save
    if db.nozonetags == true then 
		return nil,nil,nil,nil 
	end

    local channel = entry.channel
    -- Init zonetag to keep the channel tag
    local zonetag
    local partytag
    if     channel == CHAT_CHANNEL_PARTY then partytag = L(RCHAT_ZONETAGPARTY)
    elseif channel == CHAT_CHANNEL_SAY   then zonetag  = L(RCHAT_ZONETAGSAY)
    elseif channel == CHAT_CHANNEL_YELL  then zonetag  = L(RCHAT_ZONETAGYELL)
    elseif channel == CHAT_CHANNEL_ZONE  then zonetag  = L(RCHAT_ZONETAGZONE)
    end
    local link_zonetag
    if zonetag then
        link_zonetag = " " .. rChat.LinkHandler_CreateLink( ndx, entry.channel, zonetag )
        zonetag = " " .. zonetag
    end
    local link_partytag
    if partytag then  -- yes, I'm different
        link_partytag = rChat.LinkHandler_CreateLink( ndx, entry.channel, partytag ).." "
        partytag = partytag .. " "
    end
    return link_zonetag, zonetag, link_partytag, partytag
end

-- return language tag (both "raw" and "display" version currently identical)
-- returns nil if not applicable
function rChat_Internals.formatLanguageTag(entry, ndx)
    local channel = entry.channel
    if not isLanguageChannel(channel) then return nil, nil end

    local lang = nil
    if     channel == CHAT_CHANNEL_ZONE_LANGUAGE_1 then lang = "[EN] "
    elseif channel == CHAT_CHANNEL_ZONE_LANGUAGE_2 then lang = "[FR] "
    elseif channel == CHAT_CHANNEL_ZONE_LANGUAGE_3 then lang = "[DE] "
    elseif channel == CHAT_CHANNEL_ZONE_LANGUAGE_4 then lang = "[JP] "
    elseif channel == CHAT_CHANNEL_ZONE_LANGUAGE_5 then lang = "[JP] "
    elseif channel == CHAT_CHANNEL_ZONE_LANGUAGE_6 then lang = "[ES] "
    elseif channel == CHAT_CHANNEL_ZONE_LANGUAGE_7 then lang = "[ZH-Hans] "
    end
    return lang, lang
end

-- required in some form
function rChat_Internals.formatSeparator(entry, ndx)
    local db = rChat.save
    local sep
    if db.carriageReturn then
        sep = ":\n"
    else
        sep = ": "
    end
    return sep, sep
end

-- returns nil if not applicable
function rChat_Internals.formatWhisperTag(entry, ndx)
    local channel = entry.channel
    if not isWhisperChannel(channel) then return nil, nil end

    local tag
    if channel == CHAT_CHANNEL_WHISPER then
        tag = ""
    end
    if channel == CHAT_CHANNEL_WHISPER_SENT then
        tag = "-> "
    end
    return tag, tag
end


-- returns r,g,b colors that were set for the specified channel
-- from is optional - who the message is from - used in the PARTY channel (only)
--    to determine if sender is the group leader (who might have a special color)
function rChat_Internals.GetChannelColors(channel, from)
    local db = rChat.save

     -- Substract XX to a color (darker)
    local function FirstEsoColor(r, g, b)
        -- Scale is from 0-100 so divide per 300 will maximise difference at 0.33 (*2)
        r = math.max(r - (db.diffforESOcolors / 300 ),0)
        g = math.max(g - (db.diffforESOcolors / 300 ),0)
        b = math.max(b - (db.diffforESOcolors / 300 ),0)
        return r,g,b
    end

     -- Add XX to a color (brighter)
    local function SecondEsoColor(r, g, b)
        r = math.min(r + (db.diffforESOcolors / 300 ),1)
        g = math.min(g + (db.diffforESOcolors / 300 ),1)
        b = math.min(b + (db.diffforESOcolors / 300 ),1)
        return r,g,b
    end

    local lcol, rcol
    if db.useESOcolors then

        -- ESO actual color, return r,g,b
        local rESO, gESO, bESO
        -- Handle the same-colour options.
        if db.allNPCSameColour and npc_channels[channel] then
            rESO, gESO, bESO = ZO_ChatSystem_GetCategoryColorFromChannel(CHAT_CHANNEL_MONSTER_SAY)

        elseif db.allGuildsSameColour and guild_mem_channels[channel] then
            rESO, gESO, bESO = ZO_ChatSystem_GetCategoryColorFromChannel(CHAT_CHANNEL_GUILD_1)

        elseif db.allGuildsSameColour and guild_ofc_channels[channel] then
            rESO, gESO, bESO = ZO_ChatSystem_GetCategoryColorFromChannel(CHAT_CHANNEL_OFFICER_1)

        elseif db.allZonesSameColour and lang_zone_channels[channel] then
            rESO, gESO, bESO = ZO_ChatSystem_GetCategoryColorFromChannel(CHAT_CHANNEL_ZONE_LANGUAGE_1)

        elseif channel == CHAT_CHANNEL_PARTY and from and db.groupLeader
                and zo_strformat(SI_UNIT_NAME, from) == GetUnitName(GetGroupLeaderUnitTag()) then
            rESO, gESO, bESO = SF.ConvertHexToRGBA(db.colours["groupleader"])

        else
            rESO, gESO, bESO = ZO_ChatSystem_GetCategoryColorFromChannel(channel)
        end

        -- Set right colour to left colour - cause ESO colors are rewritten; if onecolor, no rewriting
        lcol = SF.ConvertRGBToHex(FirstEsoColor(rESO,gESO,bESO))
        rcol = SF.ConvertRGBToHex(SecondEsoColor(rESO,gESO,bESO))

    else
        -- rChat Colors
        -- Handle the same-colour options.
        if db.allNPCSameColour and npc_channels[channel] then
            lcol, rcol = rChat.getColors(CHAT_CHANNEL_MONSTER_SAY)
        elseif db.allGuildsSameColour and guild_mem_channels[channel] then
            lcol, rcol = rChat.getColors(CHAT_CHANNEL_GUILD_1)
        elseif db.allGuildsSameColour and guild_ofc_channels[channel] then
            lcol, rcol = rChat.getColors(CHAT_CHANNEL_OFFICER_1)
        elseif db.allZonesSameColour and lang_zone_channels[channel] then
            lcol, rcol = rChat.getColors(CHAT_CHANNEL_ZONE)
        elseif channel == CHAT_CHANNEL_PARTY and from and db.groupLeader and zo_strformat(SI_UNIT_NAME, from) == GetUnitName(GetGroupLeaderUnitTag()) then
            lcol = db.colours["groupleader"]
            rcol = db.colours["groupleader1"]

        else
            lcol, rcol = rChat.getColors(channel)
        end

    end

    -- Set right colour to left colour
    if db.oneColour then
        rcol = lcol
    end
    return lcol, rcol
end

-- get a color (hex) pair from the chat colors table (indexed by channel id)
function rChat.getColors(channelId)
    local db = rChat.save
    if not db.newcolors then return nil,nil end

    local colorsEntry = db.newcolors[channelId]
    if not colorsEntry then
        colorsEntry = db.newcolors[1]
    end
    return colorsEntry[1], colorsEntry[2]    -- left, right
end

-- create a table of the colors to be used in a particular message
-- lcol and rcol are required to be provided.
-- timecol is always provided, but might just be set to lcol
-- mentioncol is only provided if it is both available
-- 		and enabled, otherwise it will be nil
function rChat_Internals.initColorTable(channel, from)
    local db = rChat.save

    local colorT = {}
	-- base colors for this message
    colorT.lcol, colorT.rcol = rChat_Internals.GetChannelColors(channel, from)

    if db.colours and db.colours.timestamp then
        colorT.timecol = db.colours.timestamp
    end
    if db.timestampcolorislcol then
        colorT.timecol = colorT.lcol
    end

	-- mentioncol if mentions are enabled
    if db.mention.mentionEnabled and db.mention.colorEnabled then
        colorT.mentioncol = db.mention.color
    end
    return colorT
end

-- Create a string in the closest format to the requested one.
-- We must know at least atname or toonname (since we have to have
-- one of these to have successfully looked up the nickname).
--
-- (Note that knowing the nickname will override the requested
-- format to use the nickname instead.)
--
-- (For instance: If a format requires toon name and we don't know it,
--  we have to degrade to a format that we know all of the parts of.)
--
-- Will return nil for bad formatId
function rChat_Internals.UseNameFormat(atname, toonname, nickname, formatId)
    -- determine the usable format (if the desired one won't work)
    if nickname then
        formatId = 0    -- fake id for use "nickname"
    elseif formatId == 1 then       -- "@UserID"
        if not atname then formatId = 2 end
    elseif formatId == 2 then   -- 2 = "Character Name"
        if not toonname then formatId = 1 end
    elseif formatId == 3 then   -- "Character Name@UserID"
        -- both ifs cannot be true
        if not toonname then formatId = 1 end
        if not atname then formatId = 2 end
    elseif formatId == 4 then   -- "Character Name(@UserID)
        -- both ifs cannot be true
        if not toonname then formatId = 1 end
        if not atname then formatId = 2 end
    elseif formatId == 5 then   -- "Character Name/@UserID
        -- both ifs cannot be true
        if not toonname then formatId = 1 end
        if not atname then formatId = 2 end
    end

    local name
    -- create the display name (nicknames override format when available)
    if formatId == 0     then name = nickname                          -- "Nickname" -- (unoffical format)
    elseif formatId == 1 then name = atname                            -- "@UserID"
    elseif formatId == 2 then name = toonname                          -- "Character Name"
    elseif formatId == 3 then name = toonname .. atname                -- "Character Name@UserID"
    elseif formatId == 4 then name = toonname .. "(" .. atname .. ")"  -- "Character Name(@UserID)
    elseif formatId == 5 then name = toonname .. "/" .. atname         -- "Character/Name@UserID"
    end
    return name
end


-- Add link handler to character/at name
-- linkType is either DISPLAY_NAME_LINK_TYPE or CHARACTER_LINK_TYPE or nil
--   if linkType is nil:
--     if anchor is an @name, use DISPLAY_NAME_LINK_TYPE,
--     else use CHARACTER_LINK_TYPE
--
-- disablebrackets = true, false, or nil
--   if nil then obey db.disablebrackets,
--   otherwise ignore db.disablebrackets in favor of this param
function rChat_Internals.GetNameLink(anchor, display, disablebrackets, linkType)
    local  db = rChat.save

    if not linkType then
        if IsDecoratedDisplayName(anchor) then
            linkType = DISPLAY_NAME_LINK_TYPE
        else
            linkType = CHARACTER_LINK_TYPE
        end
    end
    local link
    if disablebrackets == true then
        link = ZO_LinkHandler_CreateLinkWithoutBrackets(display, nil, linkType, anchor)

    elseif db.disableBrackets and disablebrackets == nil then
        link = ZO_LinkHandler_CreateLinkWithoutBrackets(display, nil, linkType, anchor)

    else
        link = ZO_LinkHandler_CreateLink(display, nil, linkType, anchor)
        display = "[" .. display .. "]"
    end
    return link, display
end

-- Tries to get toon name from guild roster using @name
-- if not found then return nil
function rChat_Internals.GetGuildToon(guildIndex, atname)
    if guildIndex == 0 then return nil end

    local guildName, guildId = SF.SafeGetGuildName(guildIndex)
    if not guildId then return nil end

    local hastoon, rawtoonname = GetGuildMemberCharacterInfo(guildId,
                GetGuildMemberIndexFromDisplayName(guildId, atname))
    if hastoon then
        return rawtoonname
    end
    return nil
end

-- Format "From" name
function rChat_Internals.formatName(channel, from, isCS, fromDisplayName)
    local db = rChat.save

    -- if we don't have a from, there is nothing to do here!
    if not from then return nil, nil end

    -- ------------------------
    -- "From" can be Character or UserID (if char not available)
    -- (or NPC name) depending on which channel we are
    local atname = fromDisplayName
    local toonname = from
    if IsDecoratedDisplayName(from) == true then
        toonname = nil
        -- Messages from @Someone (guild / whisps)
        if isGuildChannel(channel) == true then
            local guildIndex = rChat_Internals.GetGuildIndex(channel)
            -- guild msg, look up in roster
            toonname = rChat_Internals.GetGuildToon(guildIndex, from)   -- still might be nil

        -- else is a whisper, can't get toon name           -- is nil
        end
    end
    if toonname then
        -- strip gender marker
        toonname = zo_strformat(SI_UNIT_NAME, toonname)
    end
    -- after this, at least one of atname or toonname is non-nil

    -- look for nickname
    local nick
    if atname and db.nicknames[atname] then -- @UserID Nicknamed
        nick = db.nicknames[atname]
    elseif toonname and db.nicknames[toonname] then   -- Char Nicknamed
        nick = db.nicknames[toonname]
    end
    -- nick might still be nil

    local new_from = from
    local displayed = from      -- raw

    -- No brackets / UserID for emotes
    local overrideBrackets
    if channel == CHAT_CHANNEL_EMOTE then
        overrideBrackets = true
    end

    if isMonsterChannel(channel) then
        -- no changes for NPCs
        new_from, displayed = toonname, toonname

    elseif channel == CHAT_CHANNEL_PARTY then
        local anchor = atname or toonname
        --overrideBrackets = true		-- requested by saenic
        local displaynm = rChat_Internals.UseNameFormat(atname, toonname, nick, db.groupNames)
        new_from, displayed = rChat_Internals.GetNameLink(atname, displaynm, overrideBrackets)

    elseif isWhisperChannel(channel) then
        local anchor = atname
        overrideBrackets = true
        new_from, displayed = rChat_Internals.GetNameLink(atname, atname, overrideBrackets)

	elseif isGuildChannel(channel) then
        local anchor = atname or toonname
		local displaynm
		local guildIndex = rChat_Internals.GetGuildIndex(channel)
		local guildName, guildId = SF.SafeGetGuildName(guildIndex)
		if db.formatguild[guildName] then
        	displaynm = rChat_Internals.UseNameFormat(atname, toonname, nick, db.formatguild[guildName])
		else
        	displaynm = rChat_Internals.UseNameFormat(atname, toonname, nick, db.geoChannelsFormat)
		end
        new_from, displayed = rChat_Internals.GetNameLink(anchor, displaynm, overrideBrackets)

    else -- zones / say / tell.
        local anchor = atname or toonname
        local displaynm = rChat_Internals.UseNameFormat(atname, toonname, nick, db.geoChannelsFormat)
        new_from, displayed = rChat_Internals.GetNameLink(anchor, displaynm, overrideBrackets)

    end

    if isCS then -- ZOS icon
        new_from = "|t16:16:EsoUI/Art/ChatWindow/csIcon.dds|t" .. new_from
        displayed = "|t16:16:EsoUI/Art/ChatWindow/csIcon.dds|t" .. displayed
    end

    return new_from, displayed

end


-- --------------------------------------------
-- text formatting functions

-- Add a rChat handler for URL's
local function AddURLHandling(text, lineNum)
    local rData = rChat.data

    -- handle complex URLs and do
    for pos, url, prot, subd, tld, colon, port, slash, path in text:gmatch("()(([%w_.~!*:@&+$/?%%#-]-)(%w[-.%w]*%.)(%w+)(:?)(%d*)(/?)([%w_.~!*:@&+$/?%#=-]*))") do
        if rData.protocols[prot:lower()] == (1 - #slash) * #path
                and (colon == "" or port ~= "" and port + 0 < 65536)
                and (rData.tlds[tld:lower()] or tld:find("^%d+$") and subd:find("^%d+%.%d+%.%d+%.$")
                and math.max(tld, subd:match("^(%d+)%.(%d+)%.(%d+)%.$")) < 256)
                and not subd:find("%W%W") and url
                then
            local urlHandled = string.format("|H1:%s:%s:%s|h%s|h", RCHAT_LINK, lineNum, RCHAT_URL_CHAN, url)
            url = url:gsub("([?+-])", "%%%1")
            text, count = text:gsub(url, urlHandled)
        end
    end

    return text

end

--[[
----------------------------------------------------------------------------------
  In the text parsing functions, we build and manipulate a "text segment array",
  which holds a segInfo table for each entry describing the text segment.
  segInfo = {
    text,
    segment_type,
        0 = bare,    RC_SEGTYPE_BARE
        1 = mention, RC_SEGTYPE_MENTION
        2 = link,    RC_SEGTYPE_LINK
        3 = pad,     RC_SEGTYPE_PAD
        4 = texture, RC_SEGTYPE_TEXTURE
    mention_col, (will be nil if not a RC_SEGTYPE_MENTION)
    raw, (uncolored, link display text)
  }

--]]
local function addSegment(tbl, ftype, text)
	local entry = {text, ftype or RC_SEGTYPE_BARE}
	table.insert(tbl,entry)
	return entry
end

-- lookup segment in a segment table
-- returns displayText, segType, [mentionColor], [rawText]
local function getSegment(tbl,key)
	local entry = tbl[key]
	if not entry then return nil end
	return entry[1], entry[2], entry[3], entry[4]
end

-- returns displayText, segType, [mentionColor], [rawText]
local function getSegInfo(seg)
	if not seg then return nil end
	if type(seg) ~= "table" then return tostring(seg) end
	return seg[1], seg[2], seg[3], seg[4]
end

--[[
----------------------------------------------------------------------------------
  In the text parsing functions, we also build and manipulate a "text fragment array",
  which holds a fragInfo table for each entry describing the text fragments.
  fragInfo = {
    start = index to the start of the substring
    stop = index to the end of the substring
    text = substring text,
    type = fragment_type,
        0 = bare,    RC_SEGTYPE_BARE
        1 = mention, RC_SEGTYPE_MENTION
        2 = link,    RC_SEGTYPE_LINK
        3 = pad,     RC_SEGTYPE_PAD
        4 = texture, RC_SEGTYPE_TEXTURE
		5 = qlink,   RC_SEGTYPE_QUICKLINK
    raw = rawText, (if nil then raw is the same as text)
  }

--]]
-- a fragment table is not the same as a segment table! (yet)
local function addFragment(tbl, start, stop, ftype, msgtext)
	ftype =ftype or RC_SEGTYPE_BARE
	if start > stop then return {} end
	local entry = {
		start=start,
		stop=stop,
		type=ftype,
		text = string.sub(msgtext,start,stop)
		}
	table.insert(tbl,entry)
	return entry
end

-- convert a fragment into a segment
local function frag2seg(frag)
	if not frag then return end

	local segentry = {
		frag.text,
		frag.type,
	}
	return segentry
end

-- Find out if segment is the specified type
-- returns true or false
local function isSegType(entry, stype)
	if not entry or not entry[2] then return false end
	if entry[2] == stype then
		return true
	end
	return false
end

-- not currently used (or tested)
-- get a table of start and end positions for the link
-- handlers in the text string (returns fragment table)
function rChat_Internals.getPad(textstr)
    if not textstr or type(textstr) ~= "string" then return {} end
    local db = rChat.save

    local linkpattern = "|u.-:.-:.-:(.-)|u"
    local rslts={}
    local last = 1
    local start,fin, rt = string.find(textstr, linkpattern)
    if not start then
		addFragment(rslts,1,#textstr,RC_SEGTYPE_BARE, textstr)
		return rslts
	end
	local ent
    while( start ) do
        if last ~= start then
			addFragment(rslts, last, start-1, RC_SEGTYPE_BARE, textstr)
            last = start
        end
		ent = addFragment(rslts, start, fin, RC_SEGTYPE_PAD, textstr)
		ent.raw = rt
        last = fin+1
        start,fin = string.find(textstr,linkpattern, last)
    end
    if last < #textstr then
		addFragment(rslts, last, #textstr, RC_SEGTYPE_BARE, textstr)
    end
    return rslts
end


-- QuickChat messages |s<number><number:optional><number:optional><number:optional>|s
local function getQuickLinks(rslts, text, starttxt, endtxt)
	if rslts == nil then rslts = {} end
	local quicklinkpattern = "|s(%d%d-)|s"
    local last = 1
	starttxt = starttxt or 1
	endtxt = endtxt or #text
	local segtxt = string.sub(text, starttxt, endtxt)
    local start,fin, b, d, t = string.find(segtxt, quicklinkpattern, last)
    if not start then
		--addFragment(rslts, starttxt, #segtxt, RC_SEGTYPE_BARE, segtxt)
		return rslts, starttxt, #segtxt
	end
	local ent
    while( start ) do
        if last ~= start then
			addFragment(rslts, last, start-1, RC_SEGTYPE_BARE, segtxt)
            last = start
        end
		ent = addFragment(rslts, start, fin, RC_SEGTYPE_QUICKLINK, segtxt)
		ent.raw = t
        last = fin+1
        start, fin, b, d, t = string.find(segtxt,quicklinkpattern, last)
    end
    if last < #segtxt then
		addFragment(rslts, last, #segtxt, RC_SEGTYPE_BARE, segtxt)
    end
    return rslts, start, endtxt
end

-- get a table of start and end positions for the link
-- handlers in the text string (returns fragment table)
local function getLinks(text)
    if not text or type(text) ~= "string" then return {} end
    local db = rChat.save

    local linkpattern = "|H(.-):(.-)|h(.-)|h"
    local rslts={}
    local last = 1
    local start,fin, b, dr, t = string.find(text, linkpattern, last)
    if not start then
		-- no links in text
		rslts, start1 = getQuickLinks(rslts,text,last)
		if next(rslts) == nil then
			-- no quick links either
			addFragment(rslts, last, #text-last+1, RC_SEGTYPE_BARE, text)
		end
		return rslts
	end
	
	local ent
	-- got here so found a link
    while( start ) do
		if last ~= start then
			rslts, start1 = getQuickLinks(rslts,text, last,start-1)
			if start == start1 then
				addFragment(rslts, start, #text-start+1, RC_SEGTYPE_BARE, text)
			end
			addFragment(rslts, last, start-1, RC_SEGTYPE_BARE, text)
            last = start
        end
		ent = addFragment(rslts, start, fin, RC_SEGTYPE_LINK, text)
		ent.raw = t
        last = fin+1
        start, fin, b, dr, t = string.find(text,linkpattern, last)
    end
    if last < #text then
		addFragment(rslts, last, #text, RC_SEGTYPE_BARE, text)
    end
    return rslts
end
rChat_Internals.getLinks = getLinks

-- not currently used
-- split text of a message into a table of segments containing entries
-- for each type of segment. (returns segment table)
local function parseText(entry, textstr)
    local db = rChat.save
    if type(textstr) ~= "string" then return {} end

    local channel = entry.channel
    local newtext = {}
    -- monster/npc channel messages never have link handlers
    if isMonsterChannel(channel) then
        addSegment(newtext, RC_SEGTYPE_BARE)
        return newtext
    end

    local rslts = rChat_Internals.getLinks(textstr)    -- get the locations of link handlers
    local last = 1
    -- Look for link handlers
    for k, v in ipairs(rslts) do
		newtext[k] = frag2seg(v)
    end
    return newtext
end
rChat_Internals.parseText = parseText


-- ------------------------------------------------------------------------

-- find if the text contains any of the mention triggers
-- returns true/false, and if true, a table of the first
-- text matched and the location in the text where it is found.
local function mentioned(text)
    local db = rChat.save
	if not db.mention.mentionEnabled then return false end
    if not db.mention.mentiontbl or #db.mention.mentiontbl == 0 then return false end

	local segtext
	if type(text) == "string" then
		segtext = {}
		addSegment(segtext, RC_SEGTYPE_BARE, text)
	else
		segtext = text
	end

	local found = false     -- quit looking when becomes true
	local ntxt = {}
	for fk,seg in ipairs(segtext) do
		if found then
			ntxt[#ntxt+1] = seg     -- preserve the segments that we don't search
        else
			if isSegType(seg, RC_SEGTYPE_BARE) then
				-- only looking for first mention (that is not a link!)
				for k,mention in ipairs(db.mention.mentiontbl) do
					if found then break end     -- only need to match one

                    local start,fin = string.find(seg[1], mention[1])
                    if start then
                        found = true
                        -- break the segment into 2 or 3 segments - one of which is a mention!
                        if start > 1 then
                            -- create bare prefix segment
                            addSegment(ntxt, seg[2], string.sub(seg[1], 1, start-1) )
                        end
                        -- create the mention segment
                        addSegment(ntxt, RC_SEGTYPE_MENTION, string.sub(seg[1], start, fin))
                        if fin < #seg[1] then
                            -- create the bare postfix segment if necessary
                            addSegment(ntxt, seg[2], string.sub(seg[1], fin+1))
                        end

                    end -- if start (find returned) non-nil
				end -- for any mention entries
            else
                -- we don't search non-BARE segments for mentions (yet)
                ntxt[#ntxt+1] = seg     -- preserve the segments that we don't search
			end -- isBare
		end
	end
    if found then return found, ntxt end
    return false, text
end

-- split text of a message into a table of segments containing entries
-- for each bare text section and each link handler section.
-- each entry = { textfrag, enttype (0=bare text, 2=handler) }
local function processLinks(entry, text)
    local db = rChat.save

    local channel = entry.channel
    -- monster/npc channel messages never have link handlers
    if isMonsterChannel(channel) then  return text end

    local rslts = getLinks(text)    -- get the locations of link handlers
    local newtext = {}              -- segment table
    -- Look for link handlers
	for k, v in ipairs(rslts) do
		addSegment(newtext, v.type, v.text)
    end
    return newtext
end
rChat_Internals.processLinks = processLinks

-- only used in channels with players posting and only on
-- the message text.
-- Especially NOT used in whispers, emotes, and NPC chat.
-- text is expected to be a segment table of { textfrag, type, shouldcolor }
-- if it is not, it is turned into a segment table
local function processMentions(entry, text)
    local db = rChat.save

    if type(text) == "string" then
        local newtxt = {}
        addSegment(newtxt,RC_SEGTYPE_BARE, text)
        text = newtxt
    end

    local channel = entry.channel
    if isMonsterChannel(channel) or isWhisperChannel(channel)
            or channel == CHAT_CHANNEL_SYSTEM then
		return text
    end
    if channel == CHAT_CHANNEL_EMOTE and not db.mention.emoteEnabled then
		return text
    end

    -- Look for mentions
    local wasMentioned, rslts = mentioned(text)
	if not wasMentioned then return text end

    -- we've found a mention
	if db.mention.soundEnabled then
		-- play sound
		SF.PlaySound(db.mention.sound)
	end
    return rslts
end

-- examine and format full text of message
-- colorT is a struct containing the colors to be used
-- for messages (lcol & rcol), mentions (mentioncol)
-- colorT is produced by initColorTable()
function rChat_Internals.formatText(entry, ndx, colorT)
    local db = rChat.save
    local text = entry.original.text
    entry.rawT.text = text

    if isMonsterChannel(entry.channel) then
        -- we don't do that much with them
        -- monsters don't get mention checked, url checked, or link handled
		entry.displayT.text = text
		entry.rawT.text = text
        return entry.displayT.text, entry.rawT.text
	end

    -- strip existing colors because you can't embed them in links
    -- and we're going to override anyway
    local markertable = SF.getAllColorDelim(text)
    text = SF.stripColors(markertable, text)

    -- Add URL Handling
    if db.urlHandling and type(text) == "string" then
        text = AddURLHandling(text,ndx)
    end

    -- parse text to separate out existing links
    texttbl = processLinks(entry, text)

    -- split the text string into a table of strings and mention-strings (also a table)
    local segtext = processMentions(entry, texttbl)

    local tmptbl = {}
	local tmplen = 0
	local needtoquit = false

    -- Add rChat link handling and color
    for k,v in ipairs(segtext) do
        local vtext, vtype, vmcol, vraw = getSegInfo(v)
        -- apply link first
        if isSegType(v,RC_SEGTYPE_BARE) or isSegType(v,RC_SEGTYPE_MENTION) then
            if type(vtext) == "table" then vtext = vtext[1] end
            vtext = rChat.LinkHandler_CreateLink(ndx, entry.channel, vtext, true)
        end

        -- apply color
        if isSegType(v,RC_SEGTYPE_MENTION) and colorT.mentioncol then  -- color with mention color
            vtext = string.format("%s%s|r", colorT.mentioncol, vtext)

        else -- RC_SEGTYPE_LINK or RC_SEGTYPE_BARE
            vtext = string.format("%s%s|r", colorT.rcol, vtext)
        end
        tmptbl[#tmptbl+1] = vtext
		tmplen = tmplen + string.len(vtext)
		if needtoquit == true then
			break
		end
    end
    -- recombine
    entry.displayT.text = table.concat(tmptbl)

    return entry.displayT.text, entry.rawT.text
end