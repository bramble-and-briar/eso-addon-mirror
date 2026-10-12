local PvPUA = PvPUA
local U = PvPUA.util
local DC_HEX = U.DC_HEX
local AD_HEX = U.AD_HEX
local EP_HEX = U.EP_HEX
local ColorText = U.ColorText
local GetGuildAllianceColor = U.GetGuildAllianceColor
local IsInCyrodiilOrIC = U.IsInCyrodiilOrIC
local SAVED_CHARACTER_TIP = U.SAVED_CHARACTER_TIP

--------------------------------------------------
-- Auto Invite
--------------------------------------------------
PvPUA.aiListening = false

local function AIEcho(msg)
    CHAT_ROUTER:AddSystemMessage("|cFFFFFF[|r|c" .. DC_HEX .. "P|r|c" .. AD_HEX .. "v|r|c" .. EP_HEX .. "P|r|cFF8800 UA!|r|cFFFFFF]|r |c" .. AD_HEX .. "" .. msg)
end

local function AIEchoRed(msg)
    CHAT_ROUTER:AddSystemMessage("|cFFFFFF[|r|c" .. DC_HEX .. "P|r|c" .. AD_HEX .. "v|r|c" .. EP_HEX .. "P|r|cFF8800 UA!|r|cFFFFFF]|r |c" .. EP_HEX .. "" .. msg)
end

local function AIGuildChannelToIndex(messageType)
    if messageType == CHAT_CHANNEL_GUILD_1 then return 1 end
    if messageType == CHAT_CHANNEL_GUILD_2 then return 2 end
    if messageType == CHAT_CHANNEL_GUILD_3 then return 3 end
    if messageType == CHAT_CHANNEL_GUILD_4 then return 4 end
    if messageType == CHAT_CHANNEL_GUILD_5 then return 5 end
    return nil
end

local function AIIsZoneChannel(messageType)
    if messageType == CHAT_CHANNEL_ZONE then return true end
    if messageType == CHAT_CHANNEL_ZONE_LANGUAGE_1 then return true end
    if messageType == CHAT_CHANNEL_ZONE_LANGUAGE_2 then return true end
    if messageType == CHAT_CHANNEL_ZONE_LANGUAGE_3 then return true end
    return false
end

local function AIResolveInvitee(messageType, from)
    local raw = from or ""

    local function strip(n) return (n or ""):gsub("%^.+", "") end

    if ZO_ShouldPreferUserId and ZO_ShouldPreferUserId() then
        return strip(raw)
    end

    if messageType == CHAT_CHANNEL_WHISPER then
        return strip(raw)
    end

    local gIdx = AIGuildChannelToIndex(messageType)
    if gIdx then
        local guildId = GetGuildId(gIdx)
        if guildId and guildId > 0 then
            for i = 1, GetNumGuildMembers(guildId) do
                local acct = GetGuildMemberInfo(guildId, i)
                if acct == raw then
                    local hasChar, charName = GetGuildMemberCharacterInfo(guildId, i)
                    if hasChar then return strip(charName) end
                    return ""
                end
            end
        end
        return strip(raw)
    end

    for i = 1, GetNumFriends() do
        local hasChar, cName = GetFriendCharacterInfo(i)
        local acct = GetFriendInfo(i)
        if acct == raw and hasChar then
            return strip(cName)
        end
    end
    for g = 1, 5 do
        local guildId = GetGuildId(g)
        if guildId and guildId > 0 then
            for i = 1, GetNumGuildMembers(guildId) do
                local acct = GetGuildMemberInfo(guildId, i)
                if acct == raw then
                    local hasChar, charName = GetGuildMemberCharacterInfo(guildId, i)
                    if hasChar then return strip(charName) end
                end
            end
        end
    end
    return strip(raw)
end

local function AIKeywordList()
    local raw = PvPUA.charVariables.aiKeyword
    if not raw or raw == "" then return nil end
    local list = {}
    for word in string.gmatch(raw, "[^,]+") do
        word = word:gsub("^%s+", ""):gsub("%s+$", "")
        if word ~= "" then
            list[#list + 1] = string.lower(word)
        end
    end
    if #list == 0 then return nil end
    return list
end

local aiSelfName, aiSelfAccount
local function AIIsSelf(from, fromDisplayName)
    if not aiSelfName then
        aiSelfName = (GetUnitName("player") or ""):gsub("%^.+", "")
        aiSelfAccount = GetUnitDisplayName("player") or ""
    end
    local n = (from or ""):gsub("%^.+", "")
    if n ~= "" and n == aiSelfName then return true end
    if fromDisplayName and fromDisplayName ~= "" and fromDisplayName == aiSelfAccount then return true end
    return false
end

local function AIIsPvPZoneName(zoneName)
    if not zoneName or zoneName == "" then return nil end
    if zoneName:find("Cyrodiil") then return true end
    if zoneName:find("Imperial") then return true end
    return false
end

local function AIResolveSenderZoneStatus(messageType, from)
    local gIdx = AIGuildChannelToIndex(messageType)
    if gIdx then
        local guildId = GetGuildId(gIdx)
        if guildId and guildId > 0 then
            for i = 1, GetNumGuildMembers(guildId) do
                local acct = GetGuildMemberInfo(guildId, i)
                if acct == from then
                    local hasChar, _, zoneName = GetGuildMemberCharacterInfo(guildId, i)
                    if hasChar then return AIIsPvPZoneName(zoneName) end
                    return nil
                end
            end
        end
        return nil
    end

    if messageType == CHAT_CHANNEL_WHISPER then
        for g = 1, 5 do
            local guildId = GetGuildId(g)
            if guildId and guildId > 0 then
                for i = 1, GetNumGuildMembers(guildId) do
                    local acct = GetGuildMemberInfo(guildId, i)
                    if acct == from then
                        local hasChar, _, zoneName = GetGuildMemberCharacterInfo(guildId, i)
                        if hasChar then return AIIsPvPZoneName(zoneName) end
                        return nil
                    end
                end
            end
        end
        for i = 1, GetNumFriends() do
            local acct = GetFriendInfo(i)
            if acct == from then
                local hasChar, _, zoneName = GetFriendCharacterInfo(i)
                if hasChar then return AIIsPvPZoneName(zoneName) end
                return nil
            end
        end
        return nil
    end

    return nil
end

local function AIOnWhisper(_, messageType, from, message, isCustomerService, fromDisplayName)
    local keywords = AIKeywordList()
    if not keywords then return end

    if AIIsSelf(from, fromDisplayName) then return end

    local allowed = false
    if messageType == CHAT_CHANNEL_WHISPER then
        allowed = PvPUA.charVariables.aiWhisper
    elseif messageType == CHAT_CHANNEL_SAY then
        allowed = PvPUA.charVariables.aiSay
    elseif AIIsZoneChannel(messageType) then
        allowed = PvPUA.charVariables.aiZone
    else
        local gIdx = AIGuildChannelToIndex(messageType)
        if gIdx then
            local toggles = PvPUA.charVariables.aiGuildToggles
            if toggles and toggles[gIdx] then
                allowed = true
            end
        end
    end
    if not allowed then return end

    local aiPvP = PvPUA.charVariables.aiPvP
    local aiPvE = PvPUA.charVariables.aiPvE
    if not (aiPvP and aiPvE) then
        local isPvPZone
        if messageType == CHAT_CHANNEL_SAY or AIIsZoneChannel(messageType) then
            isPvPZone = IsInCyrodiilOrIC()
        else
            isPvPZone = AIResolveSenderZoneStatus(messageType, from)
        end
        if isPvPZone == true and not aiPvP then return end
        if isPvPZone == false and not aiPvE then return end
    end

    local lowerMsg = string.lower(message)
    local matched = false
    for _, kw in ipairs(keywords) do
        if lowerMsg == kw then
            matched = true
            break
        end
    end
    if not matched then return end

    if GetGroupSize() >= 12 then
        AIEcho("Group is full. |c" .. EP_HEX .. "Pausing|r auto invite.")
        PvPUA:AIStop(true)
        return
    end

    local name = AIResolveInvitee(messageType, from)
    if not name or name == "" then return end
    name = name:gsub("%^.+", "")
    if name == "" then return end

    local shown = fromDisplayName
    if not shown or shown == "" then shown = name end

    AIEcho("Inviting |c00FF00" .. shown .. "|r")
    GroupInviteByName(name)
end


local function AICanInvite()
    if GetGroupSize() > 1 and not IsUnitGroupLeader("player") then
        return false
    end
    return true
end

local function AIOnLeaderUpdate()
    if not PvPUA.charVariables.aiEnabled then return end

    if not AICanInvite() then
        if PvPUA.aiListening then
            AIEcho("Not group leader. |c" .. EP_HEX .. "Pausing|r auto invite.")
            PvPUA:AIStop(true)
        end
        return
    end

    if PvPUA.aiListening then return end
    if GetGroupSize() >= 12 then return end

    local kw = PvPUA.charVariables.aiKeyword or ""
    if GetGroupSize() > 1 then
        AIEcho("You are now group leader. Listening again for keyword(s): |c00FF00" .. kw .. "|r")
    else
        AIEcho("Now solo. Listening again for keyword(s): |c00FF00" .. kw .. "|r")
    end
    PvPUA:AIStart(true)
end

local function AIOnGroupMemberLeft()
    if not PvPUA.charVariables.aiEnabled then return end
    if PvPUA.aiListening then return end
    if not AICanInvite() then return end
    if GetGroupSize() <= 1 then
        AIOnLeaderUpdate()
        return
    end
    AIEcho("Spot opened. Listening again for keyword(s): |c00FF00" .. (PvPUA.charVariables.aiKeyword or "") .. "|r")
    PvPUA:AIStart(true)
end

local function AICheckGroupFull()
    if not PvPUA.aiListening then return end
    if GetGroupSize() >= 12 then
        AIEcho("Group is full. |c" .. EP_HEX .. "Pausing|r auto invite.")
        PvPUA:AIStop(true)
        return
    end
    if not AICanInvite() then
        AIEcho("Not group leader. |c" .. EP_HEX .. "Pausing|r auto invite.")
        PvPUA:AIStop(true)
    end
end

PvPUA.aiKickTable = {}

local function AIKickScanOffline()
    local now = GetTimeStamp()
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and tag ~= "" and not IsUnitOnline(tag) then
            local n = GetUnitName(tag)
            if n then n = n:gsub("%^.+", "") end
            if n and n ~= "" and PvPUA.aiKickTable[n] == nil then
                PvPUA.aiKickTable[n] = now
            end
        end
    end
end

local function AIKickByName(name)
    PvPUA.aiKickTable[name] = nil
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        local tagName = nil
        if tag and tag ~= "" then
            tagName = GetUnitName(tag)
            if tagName then tagName = tagName:gsub("%^.+", "") end
        end
        if tag and tag ~= "" and tagName == name then
            local mins = PvPUA.charVariables.aiKickMinutes or 5
            local shown = GetUnitDisplayName(tag)
            if not shown or shown == "" then shown = name end
            AIEcho("|c" .. EP_HEX .. "Kicked|r |c00FF00" .. shown .. "|r - offline " .. mins .. " min.")
            GroupKick(tag)
            return
        end
    end
end

local function AIOnConnectedStatus(_, unitTag, isOnline)
    if not unitTag or unitTag == "" then return end
    local n = GetUnitName(unitTag)
    if not n or n == "" then return end
    n = n:gsub("%^.+", "")
    if n == "" then return end
    if isOnline then
        PvPUA.aiKickTable[n] = nil
    elseif PvPUA.aiKickTable[n] == nil then
        PvPUA.aiKickTable[n] = GetTimeStamp()
        if PvPUA.charVariables.aiKickOffline
           and GetGroupSize() > 1
           and IsUnitGroupLeader("player") then
            local mins = PvPUA.charVariables.aiKickMinutes or 5
            local shown = GetUnitDisplayName(unitTag)
            if not shown or shown == "" then shown = n end
            AIEcho("|c00FF00" .. shown .. "|r went offline. |c" .. EP_HEX .. "Kicking|r in " .. mins .. " min.")
        end
    end
end

local function AIOnKickGroupLeft(_, characterName, _, isLocalPlayer)
    if isLocalPlayer then
        PvPUA.aiKickTable = {}
        return
    end
    if type(characterName) == "string" and characterName ~= "" then
        PvPUA.aiKickTable[(characterName:gsub("%^.+", ""))] = nil
    end
end

local function AIKickCheck()
    if not PvPUA.charVariables.aiKickOffline then return end
    if GetGroupSize() <= 1 then return end
    if not IsUnitGroupLeader("player") then return end

    local limit = (PvPUA.charVariables.aiKickMinutes or 5) * 60
    local now = GetTimeStamp()
    for n, t in pairs(PvPUA.aiKickTable) do
        if GetDiffBetweenTimeStamps(now, t) > limit then
            AIKickByName(n)
        end
    end
end

function PvPUA:AIKickStart()
    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_AIKickStatus",
        EVENT_GROUP_MEMBER_CONNECTED_STATUS,
        AIOnConnectedStatus
    )
    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_AIKickLeft",
        EVENT_GROUP_MEMBER_LEFT,
        AIOnKickGroupLeft
    )
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_AIKickTick", 1000, AIKickCheck)
    AIKickScanOffline()
end

function PvPUA:AIKickStop()
    EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_AIKickStatus", EVENT_GROUP_MEMBER_CONNECTED_STATUS)
    EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_AIKickLeft", EVENT_GROUP_MEMBER_LEFT)
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_AIKickTick")
    PvPUA.aiKickTable = {}
end

function PvPUA:AIStart(internal)
    if not AICanInvite() then
        if not internal then
            PvPUA.charVariables.aiEnabled = true
            AIEcho("Not group leader. |c" .. EP_HEX .. "Pausing|r auto invite.")
        end
        return
    end

    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_AI",
        EVENT_CHAT_MESSAGE_CHANNEL,
        AIOnWhisper
    )
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_AIFullCheck", 1000, AICheckGroupFull)
    PvPUA.aiListening = true
    if not internal then
        PvPUA.charVariables.aiEnabled = true
        AIEcho("Listening for keyword(s): |c00FF00" .. (PvPUA.charVariables.aiKeyword or "") .. "|r")
    end
end

function PvPUA:AIStop(internal)
    EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_AI", EVENT_CHAT_MESSAGE_CHANNEL)
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_AIFullCheck")
    PvPUA.aiListening = false
    if not internal then
        PvPUA.charVariables.aiEnabled = false
        EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_AIGroup", EVENT_GROUP_MEMBER_LEFT)
        EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_AILeader", EVENT_LEADER_UPDATE)
        AIEchoRed("|c" .. AD_HEX .. "Auto invite |c" .. EP_HEX .. "disabled|r.")
    end
end

--------------------------------------------------
-- Guild Choices
--------------------------------------------------
PvPUA.AIGuildChoices = {}

function PvPUA:AIRefreshGuildChoices()
    local choices = PvPUA.AIGuildChoices
    for i = #choices, 1, -1 do choices[i] = nil end
    for i = 1, 5 do
        local guildId = GetGuildId(i)
        if guildId and guildId > 0 then
            local gName = GetGuildName(guildId)
            if gName and gName ~= "" then
                choices[#choices + 1] = gName
            end
        end
    end

    if not PvPUA.charVariables.aiGuildMigrated then
        PvPUA.charVariables.aiGuildToggles = PvPUA.charVariables.aiGuildToggles or {}
        local guildDataReady = false
        for i = 1, 5 do
            local id = GetGuildId(i)
            if id and id > 0 then guildDataReady = true break end
        end
        if guildDataReady then
            if PvPUA.charVariables.aiGuild and PvPUA.charVariables.aiGuildName ~= "" then
                for i = 1, 5 do
                    local guildId = GetGuildId(i)
                    if guildId and guildId > 0
                       and GetGuildName(guildId) == PvPUA.charVariables.aiGuildName then
                        PvPUA.charVariables.aiGuildToggles[i] = true
                        break
                    end
                end
            end
            PvPUA.charVariables.aiGuildMigrated = true
        end
    end

    local sel2 = PvPUA.charVariables.aiGuildName
    if sel2 and sel2 ~= "" then
        local found2 = false
        for _, n in ipairs(PvPUA.AIGuildChoices) do if n == sel2 then found2 = true break end end
        if not found2 then PvPUA.charVariables.aiGuildName = "" end
    end
end

function PvPUA:AIChannelChoices()
    local choices = {
        { name = ColorText("Whisper", 0.1725, 1, 0.9725),   value = "whisper" },
        { name = ColorText("Say Chat", 1, 1, 1),            value = "say" },
        { name = ColorText("Zone Chat", 0.7725, 0.7608, 0.6196), value = "zone" },
    }
    for i = 1, 5 do
        local id = GetGuildId(i)
        local label
        if id and id > 0 then
            local c = GetGuildAllianceColor(id)
            label = ColorText("Guild: " .. GetGuildName(id), c.r, c.g, c.b)
        else
            label = "Guild " .. i
        end
        choices[#choices + 1] = { name = label, value = "guild" .. i }
    end
    return choices
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function PvPUA:AutoInviteMenu()
    self:AIRefreshGuildChoices()
    return { type = "submenu",
          name = "|c" .. EP_HEX .. "Auto Invite|r",
          tooltip = SAVED_CHARACTER_TIP,
          icon = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_inviteGroup_down.dds",
          options = {
        { type = "toggle",
          name = "Enabled",
          preset = "YES_NO",
          tooltip = "Pauses automatically when the group is full and un-pauses when a spot opens.",
          getFunc = function() return PvPUA.charVariables.aiEnabled end,
          setFunc = function(val)
              if val then
                  EVENT_MANAGER:RegisterForEvent(
                      PvPUA.name .. "_AIGroup",
                      EVENT_GROUP_MEMBER_LEFT,
                      AIOnGroupMemberLeft
                  )
                  EVENT_MANAGER:RegisterForEvent(
                      PvPUA.name .. "_AILeader",
                      EVENT_LEADER_UPDATE,
                      AIOnLeaderUpdate
                  )
                  PvPUA:AIStart()
              else
                  PvPUA:AIStop()
              end
          end },
        { type = "editbox",
          name = "Keyword(s)",
          tooltip = "Words that trigger an invite. Separate multiple with commas (e.g., \"lfg, inv, x\"). Any ONE of them works on its own; a person is invited if their message is EXACTLY one of these words.",
          getFunc = function() return PvPUA.charVariables.aiKeyword end,
          setFunc = function(val)
              if val == PvPUA.charVariables.aiKeyword then return end
              PvPUA.charVariables.aiKeyword = val
              if PvPUA.charVariables.aiEnabled then
                  AIEcho("Keyword(s) updated to: |c00FF00" .. val .. "|r")
              end
          end },
        { type = "checklist",
          name = "Zones",
          tooltip = "Where the sender must be for their message to trigger an invite.",
          noSelectionText = "None",
          choices = {
              { name = "PvP", value = "pvp" },
              { name = "PvE", value = "pve" },
          },
          default = { "pvp", "pve" },
          getFunc = function()
              local cv = PvPUA.charVariables
              local sel = {}
              if cv.aiPvP then sel[#sel + 1] = "pvp" end
              if cv.aiPvE then sel[#sel + 1] = "pve" end
              return sel
          end,
          setFunc = function(values)
              local on = {}
              if type(values) == "table" then
                  for _, v in ipairs(values) do on[v] = true end
              end
              PvPUA.charVariables.aiPvP = on.pvp == true
              PvPUA.charVariables.aiPvE = on.pve == true
          end },
        { type = "checklist",
          name = "Channels",
          tooltip = "Channels the auto invite listens to for your keyword.",
          noSelectionText = "None",
          choices = PvPUA:AIChannelChoices(),
          default = { "whisper" },
          getFunc = function()
              local cv = PvPUA.charVariables
              local sel = {}
              if cv.aiWhisper then sel[#sel + 1] = "whisper" end
              if cv.aiSay then sel[#sel + 1] = "say" end
              if cv.aiZone then sel[#sel + 1] = "zone" end
              cv.aiGuildToggles = cv.aiGuildToggles or {}
              for i = 1, 5 do
                  if cv.aiGuildToggles[i] then sel[#sel + 1] = "guild" .. i end
              end
              return sel
          end,
          setFunc = function(values)
              local on = {}
              if type(values) == "table" then
                  for _, v in ipairs(values) do on[v] = true end
              end
              local cv = PvPUA.charVariables
              cv.aiWhisper = on.whisper == true
              cv.aiSay = on.say == true
              cv.aiZone = on.zone == true
              cv.aiGuildToggles = cv.aiGuildToggles or {}
              for i = 1, 5 do
                  cv.aiGuildToggles[i] = on["guild" .. i] == true
              end
          end },
        { type = "button",
          name = "|cFF8800ReloadUI|r",
          tooltip = "Guild names in the Channels list are read once when the addon loads. If you have joined or left a guild this session, reloadui to refresh them.",
          func = function() ReloadUI("ingame") end },
        { type = "toggle",
          name = "Auto Kick",
          tooltip = "Automatically removes group members who have been offline longer than the time below.",
          default = PvPUA.charDefaults.aiKickOffline,
          getFunc = function() return PvPUA.charVariables.aiKickOffline end,
          setFunc = function(val)
              PvPUA.charVariables.aiKickOffline = val
              if val then PvPUA:AIKickStart() else PvPUA:AIKickStop() end
          end },
        { type = "slider", name = "Offline Minutes", min = 1, max = 30, step = 1,
          default = PvPUA.charDefaults.aiKickMinutes,
          details = function()
              local m = tonumber(PvPUA.charVariables.aiKickMinutes) or 0
              return string.format("Kicks members who have been offline longer than %d minute%s.", m, m == 1 and "" or "s")
          end,
          getFunc = function() return PvPUA.charVariables.aiKickMinutes end,
          setFunc = function(v) PvPUA.charVariables.aiKickMinutes = v end,
          disabled = function() return not PvPUA.charVariables.aiKickOffline end },
          } }
end

function PvPUA:AIEnableOnLoad()
    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_AIGroup",
        EVENT_GROUP_MEMBER_LEFT,
        AIOnGroupMemberLeft
    )
    EVENT_MANAGER:RegisterForEvent(
        PvPUA.name .. "_AILeader",
        EVENT_LEADER_UPDATE,
        AIOnLeaderUpdate
    )
    PvPUA:AIStart(true)
end
