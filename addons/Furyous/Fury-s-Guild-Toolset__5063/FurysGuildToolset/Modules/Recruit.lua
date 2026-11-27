-- Recruiting: zone ads with a cooldown per zone, a zone tour that moves on when you post,
-- whisper leads, "Invite to" on player names in chat, join notices, and welcomes.
--
-- Written from the ESO API and the ZOS UI source. What the game lets an addon do here:
--   Chat: an addon can't send chat. Ads and welcomes are put into the chat box with
--   StartChatInput and you press Enter.
--   Travel: JumpToGuildMember, JumpToFriend and RequestJumpToHouse are normal API calls.
--   The tour only travels after you post the ad yourself (or press the Next zone key), so
--   every jump comes from a keypress of yours. There is no unattended loop.
--   Invites: GuildInvite only runs when you click Invite. Whispers never invite anyone
--   on their own.
--   Mail: the welcome mail opens filled in for you to send, unless you turn on
--   "Send automatically" (sent through GT.Actions.SendMailNow, like the demotion mail).
-- Every part starts turned off on a new install.

local GT = FurysGuildToolset
local U = GT.Util
local A = GT.Actions

local Recruit = GT:RegisterModule("recruit", {})

local GUILD_MAX_MEMBERS = 500
local MAX_CHAT = 350
local LINK_TYPE = "furygmt"
local LEAD_KEEP_SECONDS = 24 * 3600
local INVITE_KEEP_SECONDS = 7 * 86400
local MAIL_KEEP_SECONDS = 3 * 86400
local TRAVEL_TIMEOUT_MS = 15000   -- no load screen by then: the jump failed or was cancelled

local GUILD_CHANNELS = {
    CHAT_CHANNEL_GUILD_1, CHAT_CHANNEL_GUILD_2, CHAT_CHANNEL_GUILD_3,
    CHAT_CHANNEL_GUILD_4, CHAT_CHANNEL_GUILD_5,
}

ZO_CreateStringId("SI_BINDING_NAME_FURYGMT_RECRUIT_AD", "Recruit: put the zone ad in chat")
ZO_CreateStringId("SI_BINDING_NAME_FURYGMT_RECRUIT_TOUR", "Recruit: start/stop the zone tour")
ZO_CreateStringId("SI_BINDING_NAME_FURYGMT_RECRUIT_NEXT", "Recruit: travel to the next ready zone")
ZO_CreateStringId("SI_BINDING_NAME_FURYGMT_RECRUIT_NEXTAD", "Recruit: switch to the next saved ad")

local MAX_ADS = 5                   -- 1.34.0: saved ads per guild (ad 1 is the old single ad)
local SCORE_KEEP_SECONDS = 90 * 86400

Recruit.defaults = {
    -- Every part starts turned off on a new install (Albert's rule).
    enabled = false,          -- zone ads, cooldowns and the zone tour
    guildId = 0,              -- guild you recruit for; 0 = your first guild
    ads = {},                 -- [guildId] = zone ad text ({guild} = guild name); saved ad 1
    moreAds = {},             -- 1.34.0: [guildId] = { [2] = text, ..., [5] = text }: saved ads 2 to 5
    adInUse = {},             -- 1.34.0: [guildId] = number of the saved ad that goes in chat
    adRotate = "off",         -- 1.34.0: "off", "post" (next saved ad after every post) or "tour" (next ad each tour)
    score = false,            -- 1.34.0: recruit scoreboard: which zones and ads bring in new members
    scoreMinutes = 30,        -- a join counts for an ad posted in the new member's zone this many minutes before
    scoreDays = 30,           -- the scoreboard covers this many days
    adPosts = {},             -- packed "ts:zoneId:adKey", one per ad post, kept 90 days
    adJoins = {},             -- packed "ts:zoneId:adKey:how:@name", one per join the scoreboard counted, kept 90 days
    adNames = {},             -- [adKey] = the ad's words (so the scoreboard can show wordings you have since changed)
    cooldownMinutes = 15,     -- wait this long before posting in the same zone again
    useFriends = true,        -- travel through friends as well as guildmates
    useHouses = true,         -- travel to a house you own when nobody is in the zone
    statusBar = "off",        -- small on-screen bar: "off", "tour" (while the zone tour runs) or "always"
    -- barX, barY: where you dragged the bar (left/top); not set = top middle of the screen
    playerMenu = false,       -- "Invite to (guild)" when you right-click a name in chat
    leads = false,            -- whispers with a keyword become leads
    keywords = "inv, invite, join, guild",
    leadsAutoInvite = false,  -- a keyword whisper sends the guild invite right away, no click
    joinNotice = false,       -- chat line when someone joins
    nearlyFull = 10,          -- warn when this many slots or fewer are open (0 = never)
    traderWarning = true,     -- the join line also says when the guild has no trader
    welcomeChat = false,      -- put a welcome in the guild chat box when someone joins
    welcomeWho = "mine",      -- "mine" = people you invited or accepted, "all" = everyone
    welcomeCooldownMinutes = 5,
    welcomeMail = false,      -- welcome mail to new members who were offline when they joined
    welcomeMailAuto = false,  -- send it without opening the mail window
    welcomeMailOnline = false, -- also mail new members who join while online (not only offline ones)
    welcomes = {},            -- [guildId] = { on =, text =, subject =, body = }: each guild's own welcome; no entry = no welcome there
    posted = {},              -- [zoneId] = GetTimeStamp() of your last ad there
    skipZones = {},           -- [zoneId] = true: the tour never goes there
    leadList = {},            -- ["@name"] = { at =, text = }
    invited = {},             -- ["guildId:@name"] = when you invited them
    mailWaiting = {},         -- ["guildId:@name"] = { guildId =, name =, at = }
}

-- Starting text when you turn welcomes on for a guild. Each guild keeps its own copy.
local WELCOME_TEXT = "Welcome to {guild}, {new}! Glad to have you here. Check the guild MOTD for our rules and say hi any time."
local MAIL_SUBJECT = "Welcome to {guild}!"
local MAIL_BODY = "Hi {new},\n\nWelcome to {guild}! We're glad you joined.\n\nCheck the guild MOTD for our rules and links, say hi in guild chat when you're on, and ask an officer if you need anything.\n\nSee you in game!"

-- Settings -------------------------------------------------------------------

function Recruit:Initialize(sv)
    self.sv = sv
    self.lastWelcome = {}
    self.badTargets = {}   -- people (and houses) a jump failed on this session
    self.view = "zones"    -- 1.34.0: or "score" (the scoreboard)
    self:Prune()
    self:RegisterTab()
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_Recruit", EVENT_CHAT_MESSAGE_CHANNEL, function(_, channel, _, text, _, fromDisplayName)
        self:OnChat(channel, text, fromDisplayName)
    end)
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_Recruit", EVENT_GUILD_MEMBER_ADDED, function(_, guildId, displayName)
        self:OnMemberAdded(guildId, displayName)
    end)
    LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, self.OnLink, self)
    LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT, self.OnLink, self)
    -- Accepting an application from the game's Applications list.
    self.acceptedAt = {}
    ZO_PreHook("AcceptGuildApplication", function(guildId) self.acceptedAt[guildId] = GetTimeStamp() end)
    ZO_PostHook(CHAT_SYSTEM, "ShowPlayerContextMenu", function(_, playerName, rawName)
        self:AddPlayerMenu(playerName, rawName)
    end)
    self:SetUpBar()
end

-- Status bar -------------------------------------------------------------------
-- One line on the HUD: zones posted out of the zones the tour can visit, pending guild
-- applications, and whether whisper leads are on. Hidden in menus like the rest of the HUD.
local BAR_UPDATE_MS = 2000

function Recruit:SetUpBar()
    local bar = FurysGuildToolset_RecruitBar
    self.barText = bar:GetNamedChild("Text")
    if self.sv.barX and self.sv.barY then
        bar:ClearAnchors()
        bar:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.sv.barX, self.sv.barY)
    end
    self.barFragment = ZO_HUDFadeSceneFragment:New(bar)
    self.barFragment:SetConditional(function() return self:BarWanted() end)
    HUD_SCENE:AddFragment(self.barFragment)
    HUD_UI_SCENE:AddFragment(self.barFragment)
end

function Recruit:BarWanted()
    local mode = self.sv.statusBar
    return mode == "always" or (mode == "tour" and self.touring == true)
end

-- Call after anything the bar shows or depends on changes.
function Recruit:RefreshBar()
    self.barFragment:Refresh()
    if self:BarWanted() then
        self:UpdateBar()
        EVENT_MANAGER:RegisterForUpdate("FurysGuildToolset_RecruitBar", BAR_UPDATE_MS, function() self:UpdateBar() end)
    else
        EVENT_MANAGER:UnregisterForUpdate("FurysGuildToolset_RecruitBar")
    end
end

-- Zones posted (on cooldown) and zones the tour can visit, leaving out zones you skip.
function Recruit:ZoneProgress()
    local done, total = 0, 0
    for _, zone in ipairs(self.zones or {}) do
        if not self.sv.skipZones[zone.id] then
            total = total + 1
            if self:CooldownLeft(zone.id) > 0 then done = done + 1 end
        end
    end
    return done, total
end

function Recruit:UpdateBar()
    -- No nested colors: each piece gets its own |c...|r.
    local function Gray(t) return "|cB4B0D8" .. t .. "|r" end
    local guildId = self:GuildId()
    local parts = { "|cA08CFF" .. ((guildId and guildId ~= 0) and U.GuildName(guildId) or "No guild") .. "|r" }
    if self.touring then parts[#parts + 1] = "|c5EE6A0Tour on|r" end
    if self.sv.enabled then
        local done, total = self:ZoneProgress()
        parts[#parts + 1] = Gray("Zones ") .. string.format("%d/%d", done, total)
        if guildId and guildId ~= 0 and self:CountAds(guildId) > 1 then
            parts[#parts + 1] = Gray("Ad ") .. tostring(self:AdInUse(guildId))
        end
    end
    if guildId and guildId ~= 0 then
        local apps = GetGuildFinderNumGuildApplications(guildId)
        parts[#parts + 1] = Gray("Applications ") .. (apps > 0 and ("|cFFC857" .. apps .. "|r") or "0")
    end
    if self.sv.leads then
        local n = U.Count(self.sv.leadList)
        parts[#parts + 1] = Gray("Whispers ") .. "|c5EE6A0listening|r" .. (n > 0 and Gray(string.format(" (%d %s)", n, n == 1 and "lead" or "leads")) or "")
    else
        parts[#parts + 1] = Gray("Whispers ") .. "|c8A86B0off|r"
    end
    self.barText:SetText(table.concat(parts, "    "))
    FurysGuildToolset_RecruitBar:SetWidth(self.barText:GetTextWidth() + 24)
end

function Recruit:BarTip()
    return "Recruiting status. Zones: zones you posted in that are still on cooldown, out of every zone the tour can visit. Ad: which saved ad is in use (shown when you have more than one). Applications: pending guild applications. Whispers: whether whispers with your keywords become leads. Drag to move; turn it off in /gtsettings under Recruiting."
end

function Recruit:SaveBarPosition()
    self.sv.barX, self.sv.barY = FurysGuildToolset_RecruitBar:GetLeft(), FurysGuildToolset_RecruitBar:GetTop()
end

function Recruit:ResetBarPosition()
    self.sv.barX, self.sv.barY = nil, nil
    FurysGuildToolset_RecruitBar:ClearAnchors()
    FurysGuildToolset_RecruitBar:SetAnchor(TOP, GuiRoot, TOP, 0, 70)
end

function Recruit:OnPlayerActivated()
    self:MoveOldWelcome()
    self:BuildZoneList()
    self:RefreshBar()
    -- Every load screen (the tour waits for the one after a jump).
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_RecruitArrive", EVENT_PLAYER_ACTIVATED, function() self:OnArrived() end)
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_RecruitArrive", EVENT_PLAYER_DEACTIVATED, function() self:OnLeaving() end)
end

-- Roster history tells us who invited or accepted whom; only needed for welcomes.
function Recruit:GetHistoryCategories()
    if not (self.sv.welcomeChat or self.sv.welcomeMail) then return {} end
    return { GUILD_HISTORY_EVENT_CATEGORY_ROSTER }
end

function Recruit:AnyOn()
    local sv = self.sv
    return sv.enabled or sv.leads or sv.playerMenu or sv.joinNotice or sv.welcomeChat or sv.welcomeMail
end

function Recruit:Prune()
    local now = GetTimeStamp()
    for name, lead in pairs(self.sv.leadList) do
        if now - lead.at > LEAD_KEEP_SECONDS then self.sv.leadList[name] = nil end
    end
    for key, at in pairs(self.sv.invited) do
        if now - at > INVITE_KEEP_SECONDS then self.sv.invited[key] = nil end
    end
    for key, job in pairs(self.sv.mailWaiting) do
        if now - job.at > MAIL_KEEP_SECONDS then self.sv.mailWaiting[key] = nil end
    end
    self:PruneScore(now)
end

-- Up to 1.5.6 there was one welcome for every guild. It belongs to the guild you set
-- recruiting up for, so it moves there; no other guild gets a welcome until you turn it on.
function Recruit:MoveOldWelcome()
    local sv = self.sv
    if sv.welcomeText == nil and sv.mailSubject == nil and sv.mailBody == nil then return end
    local guildId = self:GuildId()
    if guildId and guildId ~= 0 and not sv.welcomes[guildId] then
        sv.welcomes[guildId] = { on = (sv.welcomeChat or sv.welcomeMail) == true,
            text = sv.welcomeText or WELCOME_TEXT, subject = sv.mailSubject or MAIL_SUBJECT, body = sv.mailBody or MAIL_BODY }
    end
    sv.welcomeText, sv.mailSubject, sv.mailBody = nil, nil, nil
end

-- This guild's welcome, or nil when welcomes are off for it.
function Recruit:WelcomeFor(guildId)
    local w = self.sv.welcomes[guildId]
    if w and w.on then return w end
end

-- The guild you recruit for: the one picked in settings, or your first guild.
function Recruit:GuildId()
    local wanted = self.sv.guildId
    if wanted ~= 0 and U.IsPlayerInGuild(wanted) then return wanted end
    return GetGuildId(1)
end

local function GuildChannel(guildId)
    for i = 1, GetNumGuilds() do
        if GetGuildId(i) == guildId then return GUILD_CHANNELS[i] end
    end
end

local function Fill(text, guildId, name)
    text = (text or ""):gsub("{guild}", function() return U.GuildName(guildId) end)
    return (text:gsub("{new}", function() return name or "" end))
end

local function Link(label, action, ...)
    local data = table.concat({ LINK_TYPE, action, ... }, ":")
    return string.format("|c5CC2FF|H1:%s|h[%s]|h|r", data, label)
end

-- Guild slots ----------------------------------------------------------------

-- Open slots, counting invites that haven't been answered yet (they hold a slot too).
function Recruit:OpenSlots(guildId)
    local numMembers, _, _, numInvitees = GetGuildInfo(guildId)
    return GUILD_MAX_MEMBERS - numMembers - numInvitees, numMembers
end

function Recruit:HasTrader(guildId)
    local kiosk = GetGuildOwnedKioskInfo(guildId)
    return kiosk ~= nil and kiosk ~= ""
end

-- Zones ----------------------------------------------------------------------

-- Every zone on the world map's zone list that you can travel to. 1.31.4: small zones the game
-- files under another zone (a city with its own map, such as Fargrave) are on the list too, and
-- every zone that is left out is kept with the reason, shown at the end of the Recruiting tab.
function Recruit:BuildZoneList()
    local zones, seen, ids, leftOut = {}, {}, {}, {}
    for i = 1, GetNumMaps() do
        local _, mapType, mapContentType, zoneIndex = GetMapInfoByIndex(i)
        local isZoneMap = mapType == MAPTYPE_ZONE or mapType == MAPTYPE_SUBZONE
        if isZoneMap and zoneIndex and zoneIndex > 0 then
            local zoneId = GetZoneId(zoneIndex)
            if zoneId ~= 0 and not seen[zoneId] then
                seen[zoneId] = true
                local name = zo_strformat("<<C:1>>", GetZoneNameById(zoneId))
                if mapContentType == MAP_CONTENT_AVA then
                    leftOut[#leftOut + 1] = { name = name, why = "an Alliance War zone: the game doesn't let you jump to players there" }
                elseif mapContentType ~= MAP_CONTENT_NONE then
                    leftOut[#leftOut + 1] = { name = name, why = "a dungeon or battleground map, not a zone with zone chat" }
                elseif not CanJumpToPlayerInZone(zoneId) then
                    leftOut[#leftOut + 1] = { name = name, why = "the game doesn't let you jump to players there" }
                else
                    ids[zoneId] = true
                    zones[#zones + 1] = { id = zoneId, name = name }
                end
            end
        end
    end
    self.zones, self.zoneIds, self.leftOut = zones, ids, leftOut
end

-- The zone you are standing in, as the tour counts it: the zone itself when it is on the tour
-- list, otherwise the zone it belongs to (a delve or a city inside a zone counts as that zone).
function Recruit:CurrentZoneId()
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    if self.zoneIds and self.zoneIds[zoneId] then return zoneId end
    return GetParentZoneId(zoneId)
end

function Recruit:ZoneName(zoneId)
    return zo_strformat("<<C:1>>", GetZoneNameById(zoneId))
end

-- Seconds left on a zone's cooldown, 0 when it's ready.
function Recruit:CooldownLeft(zoneId)
    local at = self.sv.posted[zoneId]
    if not at then return 0 end
    return math.max(0, self.sv.cooldownMinutes * 60 - (GetTimeStamp() - at))
end

-- Houses you own, by the zone they're in: [zoneId] = { houseId =, name = }.
function Recruit:OwnedHouses()
    local houses = {}
    for i = 1, GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_HOUSE) do
        local collectibleId = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_HOUSE, i)
        if IsCollectibleUnlocked(collectibleId) then
            local houseId = GetCollectibleReferenceId(collectibleId)
            local zoneId = GetParentZoneId(GetHouseFoundInZoneId(houseId))
            if not houses[zoneId] then
                houses[zoneId] = { houseId = houseId, name = zo_strformat("<<1>>", GetCollectibleName(collectibleId)) }
            end
        end
    end
    return houses
end

-- Everyone you could travel to in a zone's open world: guildmates, then friends, then a house
-- you own there. Only people standing in the zone itself count. Anyone inside a public
-- dungeon, delve, group dungeon, trial or any other instance has a different zone id (the
-- zone is only its parent), so they are skipped. People a jump already failed on this
-- session are left out too.
-- Returns a list of { kind =, name =, houseId = } (empty when there's no way in).
function Recruit:FindWaysInto(zoneId, houses)
    local me, bad = GetDisplayName(), self.badTargets
    local ways, seen = {}, {}
    for _, guildId in ipairs(U.GetGuildIds()) do
        for i = 1, GetNumGuildMembers(guildId) do
            local name, _, _, status = GetGuildMemberInfo(guildId, i)
            if status ~= PLAYER_STATUS_OFFLINE and name ~= me and not bad[name] and not seen[name] then
                local _, _, _, _, _, _, _, memberZoneId = GetGuildMemberCharacterInfo(guildId, i)
                if memberZoneId == zoneId then
                    seen[name] = true
                    ways[#ways + 1] = { kind = "guild", name = name }
                end
            end
        end
    end
    if self.sv.useFriends then
        for i = 1, GetNumFriends() do
            local name, _, status = GetFriendInfo(i)
            if status ~= PLAYER_STATUS_OFFLINE and not bad[name] and not seen[name] then
                local _, _, _, _, _, _, _, friendZoneId = GetFriendCharacterInfo(i)
                if friendZoneId == zoneId then ways[#ways + 1] = { kind = "friend", name = name } end
            end
        end
    end
    if self.sv.useHouses and houses[zoneId] and not bad["house:" .. zoneId] then
        ways[#ways + 1] = { kind = "house", name = houses[zoneId].name, houseId = houses[zoneId].houseId }
    end
    return ways
end

-- The next zone in list order after the one you're in that's ready, not skipped, not in
-- exclude, and has a way in. Returns zone, ways.
function Recruit:NextReadyZone(exclude)
    if not self.zones then self:BuildZoneList() end
    local here = self:CurrentZoneId()
    local start = 0
    for i, zone in ipairs(self.zones) do
        if zone.id == here then start = i end
    end
    local houses = self.sv.useHouses and self:OwnedHouses() or {}
    local count = #self.zones
    for step = 1, count do
        local zone = self.zones[(start + step - 1) % count + 1]
        if zone.id ~= here and not self.sv.skipZones[zone.id] and not (exclude and exclude[zone.id]) and self:CooldownLeft(zone.id) == 0 then
            local ways = self:FindWaysInto(zone.id, houses)
            if #ways > 0 then return zone, ways end
        end
    end
    return nil
end

-- Zone ad --------------------------------------------------------------------

-- Saved ads (1.34.0) ----------------------------------------------------------
-- Each guild has up to five saved ads. Ad 1 is the one ad of earlier versions (sv.ads), so an
-- older version still finds it. One of them is "in use": that one goes in the chat box.

function Recruit:SavedAd(guildId, n)
    if n == 1 then return self.sv.ads[guildId] or "" end
    local more = self.sv.moreAds[guildId]
    return more and more[n] or ""
end

function Recruit:SetSavedAd(guildId, n, text)
    if n == 1 then
        self.sv.ads[guildId] = text
        return
    end
    self.sv.moreAds[guildId] = self.sv.moreAds[guildId] or {}
    self.sv.moreAds[guildId][n] = text
end

function Recruit:HasAd(guildId, n)
    return zo_strtrim(self:SavedAd(guildId, n)) ~= ""
end

-- The number of the ad in use: the one you picked, or the first saved ad when that one is empty.
function Recruit:AdInUse(guildId)
    guildId = guildId or self:GuildId()
    local n = self.sv.adInUse[guildId] or 1
    if self:HasAd(guildId, n) then return n end
    for i = 1, MAX_ADS do
        if self:HasAd(guildId, i) then return i end
    end
    return 1
end

-- The saved ad after the one in use, skipping empty ones (back to the first after the last).
function Recruit:NextAdNumber()
    local guildId = self:GuildId()
    local current = self:AdInUse(guildId)
    for step = 1, MAX_ADS do
        local n = (current + step - 1) % MAX_ADS + 1
        if self:HasAd(guildId, n) then return n end
    end
    return current
end

function Recruit:CountAds(guildId)
    local count = 0
    for n = 1, MAX_ADS do
        if self:HasAd(guildId, n) then count = count + 1 end
    end
    return count
end

-- First words of an ad, for chat lines and lists.
local function Short(text, size)
    size = size or 60
    text = zo_strtrim((tostring(text or ""):gsub("|H[^|]*|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", " ")))
    if #text > size then text = text:sub(1, size - 3) .. "..." end
    return text
end

function Recruit:UseAd(n, quiet)
    local guildId = self:GuildId()
    if not self:HasAd(guildId, n) then
        U.Print("Saved ad %d is empty. Write it in /gtsettings under Recruiting.", n)
        return
    end
    self.sv.adInUse[guildId] = n
    if not quiet then U.Print("Zone ad %d is now in use: \"%s\"", n, Short(self:AdText(n))) end
    if self.barText then self:RefreshBar() end
    GT.Report:RefreshIfShown()
end

-- Keybind and footer: the next saved ad goes in use.
function Recruit:SwitchAd()
    local guildId = self:GuildId()
    if self:CountAds(guildId) < 2 then
        U.Print("You have %d saved ad for %s. Save more ads in /gtsettings under Recruiting to switch between them.", self:CountAds(guildId), U.GuildName(guildId))
        return
    end
    self:UseAd(self:NextAdNumber())
end

-- n: a saved ad's number; the ad in use when left out.
function Recruit:AdText(n)
    local guildId = self:GuildId()
    return Fill(zo_strtrim(self:SavedAd(guildId, n or self:AdInUse(guildId))), guildId)
end

-- How long after the ad goes in the chat box your first post in that zone still counts as the ad.
local PASTE_WINDOW_SECONDS = 300

-- Puts the ad in the zone chat box. Asks first if you posted in this zone too recently.
function Recruit:PasteAd(skipCheck)
    if not self.sv.enabled then
        U.Print("Zone ads are turned off. Turn on Recruiting in /gtsettings.")
        return
    end
    local ad = self:AdText()
    if ad == "" then
        U.Print("You haven't written a zone ad for %s yet. Write one in /gtsettings under Recruiting.", U.GuildName(self:GuildId()))
        return
    end
    local zoneId = self:CurrentZoneId()
    local left = self:CooldownLeft(zoneId)
    if left > 0 and not skipCheck then
        A.Confirm("Zone ad", zo_strformat("You posted your ad in <<1>> <<2>>. Its cooldown has <<3>> left.\n\nPut the ad in chat anyway?",
            self:ZoneName(zoneId), U.FormatAgo(self.sv.posted[zoneId]), U.FormatDuration(left)), function() self:PasteAd(true) end)
        return
    end
    if #ad > MAX_CHAT then
        U.Print("Your ad is %d characters. ESO cuts chat at %d.", #ad, MAX_CHAT)
    end
    -- Fury's Chat Shortcuts reads pasted.zoneId and pasted.at: keep those names.
    self.pasted = { zoneId = zoneId, at = GetTimeStamp(), ad = self:AdInUse() }
    self:PutInChatBox(ad)
end

-- The ad goes into the chat box's text first (zone channel), then the box opens.
-- If the game window isn't in front (alt-tabbed during the load screen), opening can't take
-- the keyboard, and the box can sit "open" without it, so Enter never reaches it. The text is
-- already in the box either way, and the watch below closes a box that has no keyboard, keeping
-- the text: pressing Enter then opens chat with the ad ready to post.
local AD_WATCH_MS = 1000
function Recruit:PutInChatBox(ad)
    local textEntry = CHAT_SYSTEM.textEntry
    CHAT_SYSTEM:SetChannel(CHAT_CHANNEL_ZONE)
    textEntry:SetText(ad)
    StartChatInput(ad, CHAT_CHANNEL_ZONE)
    local pasted = self.pasted
    EVENT_MANAGER:UnregisterForUpdate("FurysGuildToolset_RecruitAdBox")
    EVENT_MANAGER:RegisterForUpdate("FurysGuildToolset_RecruitAdBox", AD_WATCH_MS, function()
        if self.pasted ~= pasted or GetTimeStamp() - pasted.at > PASTE_WINDOW_SECONDS then
            EVENT_MANAGER:UnregisterForUpdate("FurysGuildToolset_RecruitAdBox")
        elseif CHAT_SYSTEM:IsTextEntryOpen() and not textEntry:GetEditControl():HasFocus() then
            local KEEP_TEXT = true
            CHAT_SYSTEM:CloseTextEntry(KEEP_TEXT)
        end
    end)
end

-- Your own zone message that matches the ad starts that zone's cooldown, and moves the tour on.
-- Compares chat text by what it says: links become their names, colors and extra spaces go,
-- case doesn't matter. The game can send a posted message back with links or spacing
-- written a little differently from how it was typed.
local function Plain(text)
    text = tostring(text or ""):gsub("|H[^|]*|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    return zo_strlower(zo_strtrim((text:gsub("%s+", " "))))
end

-- A zone post counts as your ad when it reads the same as the ad, or when it's the first
-- thing you post in that zone within a few minutes of the addon putting the ad in your chat box.

-- 1.34.0: any saved ad counts, not only the one in use. Returns true and the ad's number.
function Recruit:IsAdPost(text, zoneId)
    local plain = Plain(text)
    local guildId = self:GuildId()
    for n = 1, MAX_ADS do
        if self:HasAd(guildId, n) and plain == Plain(self:AdText(n)) then return true, n end
    end
    local pasted = self.pasted
    if pasted ~= nil and pasted.zoneId == zoneId and GetTimeStamp() - pasted.at <= PASTE_WINDOW_SECONDS then
        return true, pasted.ad or self:AdInUse(guildId)
    end
    return false
end

function Recruit:OnChat(channel, text, fromDisplayName)
    local me = GetDisplayName()
    if channel == CHAT_CHANNEL_ZONE and fromDisplayName == me then
        if not self.sv.enabled then return end
        local zoneId = self:CurrentZoneId()
        local isAd, adNumber = self:IsAdPost(text, zoneId)
        if not isAd then return end
        self.pasted = nil
        self.sv.posted[zoneId] = GetTimeStamp()
        self:RecordPost(zoneId, adNumber)
        U.Print("Ad posted in %s. It's on cooldown for %d minutes.", self:ZoneName(zoneId), self.sv.cooldownMinutes)
        if self.sv.adRotate == "post" and self:CountAds(self:GuildId()) > 1 then
            self:UseAd(self:NextAdNumber(), true)
            U.Print("Next post uses ad %d.", self:AdInUse())
        end
        self:RefreshBar()
        GT.Report:RefreshIfShown()
        -- Travel a moment later, once the chat box has closed.
        if self.touring then zo_callLater(function() if self.touring and not self.trip then self:TravelNext() end end, 1000) end
    elseif channel == CHAT_CHANNEL_WHISPER and fromDisplayName ~= me and self.sv.leads then
        self:CheckLead(fromDisplayName, text or "")
    end
end

-- Zone tour ------------------------------------------------------------------
-- Start: you get the ad in this zone's chat box (or travel on if this zone is on cooldown).
-- Each time you press Enter on the ad, you travel to the next ready zone, and on arrival the
-- ad is in the chat box again. Nothing happens until you press Enter.

function Recruit:ToggleTour()
    if self.touring then self:StopTour() else self:StartTour() end
end

function Recruit:StartTour()
    if not self.sv.enabled then
        U.Print("Zone ads are turned off. Turn on Recruiting in /gtsettings.")
        return
    end
    if self:AdText() == "" then
        U.Print("You haven't written a zone ad for %s yet. Write one in /gtsettings under Recruiting.", U.GuildName(self:GuildId()))
        return
    end
    if self.sv.adRotate == "tour" and self:CountAds(self:GuildId()) > 1 then
        self:UseAd(self:NextAdNumber(), true)
        U.Print("This tour uses ad %d: \"%s\"", self:AdInUse(), Short(self:AdText()))
    end
    self.touring = true
    if not self.zones then self:BuildZoneList() end
    self:RefreshBar()
    local waiting = {}
    for _, zone in ipairs(self.zones) do
        local left = self:CooldownLeft(zone.id)
        if left > 0 and not self.sv.skipZones[zone.id] then waiting[#waiting + 1] = zone.name .. " (" .. U.FormatDuration(left) .. ")" end
    end
    U.Print("Zone tour started. Press Enter to post the ad; you'll travel to the next ready zone after each post. Use the tour key or /gt tour to stop.")
    if #waiting > 0 then U.Print("Left out while on cooldown: %s.", table.concat(waiting, ", ")) end
    local here = self:CurrentZoneId()
    if self:CooldownLeft(here) == 0 and not self.sv.skipZones[here] then
        self:PasteAd(true)
    else
        self:TravelNext()
    end
    GT.Report:RefreshIfShown()
end

function Recruit:StopTour(reason)
    if not self.touring then return end
    self.touring = false
    self.trip = nil
    self:RefreshBar()
    EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_RecruitJump", EVENT_SOCIAL_ERROR)
    EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_RecruitCombat", EVENT_PLAYER_COMBAT_STATE)
    U.Print(reason or "Zone tour stopped.")
    GT.Report:RefreshIfShown()
end

-- One trip. Called by your ad post during a tour, the Next zone key, or a row's menu.
-- If a jump fails (the game says no, or the travel never starts), the same trip tries the
-- next person in that zone, then the next ready zone, up to MAX_TRIP_TRIES jumps. It never
-- goes on to a second trip by itself: after you arrive, the next trip waits for your post.
local MAX_TRIP_TRIES = 8

function Recruit:TravelNext()
    self:StartTrip({ exclude = {} })
end

function Recruit:StartTrip(trip, zoneId)
    local zone, ways
    if zoneId then
        zone = { id = zoneId, name = self:ZoneName(zoneId) }
        ways = self:FindWaysInto(zoneId, self.sv.useHouses and self:OwnedHouses() or {})
        if #ways == 0 then
            U.Print("Nobody you can travel to is in %s right now.", zone.name)
            return
        end
    else
        zone, ways = self:NextReadyZone(trip.exclude)
    end
    if not zone then
        local soonest
        for _, z in ipairs(self.zones or {}) do
            if not self.sv.skipZones[z.id] then
                local left = self:CooldownLeft(z.id)
                if left > 0 and (not soonest or left < soonest) then soonest = left end
            end
        end
        local msg = "No other zone is ready with a guildmate, friend or house of yours in it."
        if soonest then msg = msg .. " The next cooldown ends in " .. U.FormatDuration(soonest) .. "." end
        if self.touring then self:StopTour("Zone tour finished. " .. msg) else U.Print(msg) end
        return
    end
    trip.zone, trip.ways, trip.index, trip.tries, trip.oneZone = zone, ways, 1, trip.tries or 0, zoneId ~= nil
    self.trip = trip
    self:Jump(trip)
end

function Recruit:Jump(trip)
    local way, zone = trip.ways[trip.index], trip.zone
    -- The game refuses every jump while you're in combat (an aggressive mob near where you
    -- landed is enough), so don't spend a try on it: wait until combat clears.
    if IsUnitInCombat("player") then
        self:WaitThenJump(trip, true, true)
        return
    end
    trip.tries = trip.tries + 1
    trip.from = self:CurrentZoneId()
    trip.started = false
    local token = {}
    trip.token = token
    U.Print("Traveling to %s in %s...", way.name, zone.name)
    if way.kind == "house" then
        RequestJumpToHouse(way.houseId, true)   -- true: arrive outside the house, in the zone
    elseif way.kind == "friend" then
        JumpToFriend(way.name)
    else
        JumpToGuildMember(way.name)
    end
    -- The game reports a refused jump ("not in same group", "can't travel there") as a social
    -- error; a jump that never starts (cancelled, they moved) just times out.
    EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_RecruitJump", EVENT_SOCIAL_ERROR)
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_RecruitJump", EVENT_SOCIAL_ERROR, function(_, result)
        if self.trip == trip and trip.token == token and not trip.started then self:JumpFailed(trip, GetString("SI_SOCIALACTIONRESULT", result)) end
    end)
    zo_callLater(function()
        if self.trip == trip and trip.token == token and not trip.started then self:JumpFailed(trip) end
    end, TRAVEL_TIMEOUT_MS)
end

-- reason: the game's own text for a refused jump, or nil when the travel never started.
-- The next try always waits a moment. Jumping again straight from the game's error event
-- would register the next attempt's listener while that same error is still being handed
-- out, so one refusal would count as a failure for every attempt in a row (1.5.5 bug).
-- A refusal that is about you, not the person (you're in combat, or the game gave the same
-- answer for two different people in a row): the trip waits a few seconds, or until combat
-- clears, and tries the same person again, up to MAX_TRIP_WAITS times. (Before 1.24.5 it
-- gave up and asked you to press the Next zone key.)
local RETRY_DELAY_MS = 2000
local SETTLE_MS = 4000        -- after combat ends (or a repeated refusal), wait this long before trying again
local MAX_TRIP_WAITS = 5

-- inCombat: true when you're in combat; false for another refusal about you.
-- beforeTry: true when the trip saw the combat before asking the game (nothing was refused yet).
function Recruit:WaitThenJump(trip, inCombat, beforeTry)
    trip.waits = (trip.waits or 0) + 1
    if trip.waits > MAX_TRIP_WAITS then
        self.trip = nil
        EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_RecruitCombat", EVENT_PLAYER_COMBAT_STATE)
        local msg = inCombat and "Still in combat after several tries, so travel is paused." or "The game kept refusing travel, so travel is paused."
        U.Print("%s Press the Next zone key when you're ready to try again.", msg)
        return
    end
    local token = {}
    trip.waitToken = token
    local function Go()
        if self.trip ~= trip or trip.waitToken ~= token then return end
        if IsUnitInCombat("player") then
            EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_RecruitCombat", EVENT_PLAYER_COMBAT_STATE)
            EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_RecruitCombat", EVENT_PLAYER_COMBAT_STATE, function(_, nowInCombat)
                if nowInCombat then return end
                EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_RecruitCombat", EVENT_PLAYER_COMBAT_STATE)
                zo_callLater(Go, SETTLE_MS)
            end)
            return
        end
        trip.waitToken = nil
        self:Jump(trip)
    end
    if inCombat and beforeTry then
        if trip.waits == 1 then U.Print("You're in combat. Travel waits until it clears...") end
    elseif inCombat then
        U.Print("Couldn't travel: the game says you're in combat. Waiting until it clears...")
    else
        U.Print("Couldn't travel: the game refused twice for the same reason, so it's something on your side for a moment. Trying again in a few seconds...")
    end
    zo_callLater(Go, SETTLE_MS)
end

function Recruit:JumpFailed(trip, reason)
    EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_RecruitJump", EVENT_SOCIAL_ERROR)
    trip.token = nil
    local way, zone = trip.ways[trip.index], trip.zone
    local hasReason = reason ~= nil and reason ~= ""
    -- In combat (or the game's text says combat): not the person's fault, so wait and retry them.
    local combat = IsUnitInCombat("player") or (hasReason and zo_strlower(reason):find("combat", 1, true) ~= nil)
    local repeated = hasReason and reason == trip.lastReason
    if combat or repeated then
        trip.tries = trip.tries - 1   -- this try doesn't count against the person
        if repeated and trip.lastTarget then
            self.badTargets[trip.lastTarget] = nil   -- the earlier refusal wasn't their fault either
            trip.tries = trip.tries - 1
        end
        trip.lastReason, trip.lastTarget = nil, nil
        zo_callLater(function()
            if self.trip == trip then self:WaitThenJump(trip, combat) end
        end, RETRY_DELAY_MS)
        return
    end
    local why = hasReason and reason or "the travel didn't start"
    U.Print("Couldn't travel to %s: %s.", way.name, why)
    trip.lastReason = reason
    trip.lastTarget = way.kind == "house" and ("house:" .. zone.id) or way.name
    self.badTargets[trip.lastTarget] = true
    if trip.tries >= MAX_TRIP_TRIES then
        self.trip = nil
        local msg = string.format("Travel didn't work after %d tries.", trip.tries)
        if self.touring then self:StopTour(msg .. " Zone tour stopped. Start it again to keep going.") else U.Print(msg) end
        return
    end
    zo_callLater(function()
        if self.trip ~= trip then return end
        if trip.index < #trip.ways then
            trip.index = trip.index + 1
            self:Jump(trip)
        elseif trip.oneZone then
            self.trip = nil
            U.Print("Couldn't travel to anyone in %s.", zone.name)
        else
            trip.exclude[zone.id] = true
            U.Print("Nobody else to try in %s. Trying the next zone.", zone.name)
            self:StartTrip(trip)
        end
    end, RETRY_DELAY_MS)
end

-- The load screen started: the jump worked.
function Recruit:OnLeaving()
    local trip = self.trip
    if trip and trip.token then
        trip.started = true
        EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_RecruitJump", EVENT_SOCIAL_ERROR)
    end
end

function Recruit:OnArrived()
    local trip = self.trip
    if not trip or not trip.started then return end
    -- Landed somewhere other than the open zone (they went into an instance during the cast):
    -- this jump counts as failed, and the trip goes on to the next way in.
    -- (Outside a house you may stand in a town that belongs to the zone, which is fine.)
    local actual = GetZoneId(GetUnitZoneIndex("player"))
    local way = trip.ways[trip.index]
    local ok = actual == trip.zone.id or (way.kind == "house" and GetParentZoneId(actual) == trip.zone.id)
    if not ok then
        U.Print("That put you in %s, not the open zone.", zo_strformat("<<C:1>>", GetZoneNameById(actual)))
        self:JumpFailed(trip)
        return
    end
    self.trip = nil
    if self.touring then
        -- Give the chat window a moment after the load screen.
        zo_callLater(function() if self.touring then self:PasteAd() end end, 1500)
    end
    GT.Report:RefreshIfShown()
end

function Recruit:TravelToZone(zoneId)
    self:StartTrip({ exclude = {} }, zoneId)
end

-- Invites and leads ----------------------------------------------------------

function Recruit:Invite(guildId, name)
    if not U.HasPermission(guildId, GUILD_PERMISSION_INVITE) then
        U.Print("Your rank in %s can't invite.", U.GuildName(guildId))
        return
    end
    if U.IsMember(guildId, name) then
        U.Print("%s is already in %s.", name, U.GuildName(guildId))
        return
    end
    GuildInvite(guildId, name)
    self.sv.invited[guildId .. ":" .. name] = GetTimeStamp()
    self.sv.leadList[name] = nil
    U.Print("Invited %s to %s.", name, U.GuildName(guildId))
    GT.Report:RefreshIfShown()
end

-- Whole words only: both sides become " word word word " and the keyword's words must appear
-- in a row. (No %f frontier patterns: ESO's Lua doesn't match them, so the old version never
-- found a keyword in game.)
local function Words(text)
    local words = {}
    for word in text:gmatch("%w+") do words[#words + 1] = word end
    return " " .. table.concat(words, " ") .. " "
end

local function MatchesKeyword(text, keyword)
    if keyword:find("%w") then
        return Words(text):find(Words(keyword), 1, true) ~= nil
    end
    return zo_strtrim(text) == keyword   -- a keyword like "+" counts only on its own
end

local REINVITE_SECONDS = 10 * 60
function Recruit:CheckLead(name, text)
    local lower = zo_strlower(text)
    local hit
    for keyword in pairs(U.ParseList(self.sv.keywords)) do
        if MatchesKeyword(lower, keyword) then hit = keyword break end
    end
    if not hit then return end
    local guildId = self:GuildId()
    if U.IsMember(guildId, name) then return end
    if self.sv.leadsAutoInvite and U.HasPermission(guildId, GUILD_PERMISSION_INVITE) then
        -- One invite per person: a second whisper while the invite is still open does nothing.
        local sent = self.sv.invited[guildId .. ":" .. name]
        if sent and GetTimeStamp() - sent < REINVITE_SECONDS then return end
        U.Print("%s whispered \"%s\".", name, text)
        self:Invite(guildId, name)
        return
    end
    self.sv.leadList[name] = { at = GetTimeStamp(), text = text }
    U.Print("Lead: %s whispered \"%s\". %s", name, text, Link("Invite to " .. U.GuildName(guildId), "invite", guildId, name))
    GT.Report:RefreshIfShown()
end

-- "Invite to (guild)" on player names in chat, for each guild where you can invite.
function Recruit:AddPlayerMenu(playerName, rawName)
    if not self.sv.playerMenu then return end
    local name = (rawName and rawName:sub(1, 1) == "@") and rawName or playerName
    if not name or name == "" or name == GetDisplayName() then return end
    local added = false
    for _, guildId in ipairs(U.GetGuildIds()) do
        if U.HasPermission(guildId, GUILD_PERMISSION_INVITE) and not U.IsMember(guildId, name) then
            local gid = guildId
            AddMenuItem("Invite to " .. U.GuildName(gid), function() self:Invite(gid, name) end)
            added = true
        end
    end
    if added then ShowMenu() end
end

-- Joins and welcomes ---------------------------------------------------------

-- The game fires this twice for an invite: once when the invite goes out (they aren't on
-- the roster yet) and again when they accept. Only the second one is a join.
function Recruit:OnMemberAdded(guildId, name)
    if name == GetDisplayName() or not U.IsMember(guildId, name) then return end
    if self.sv.score and guildId == self:GuildId() then self:CountJoin(guildId, name) end
    -- Only the guild you recruit for and guilds you turned welcomes on for. Nothing for your other guilds.
    local welcome = self:WelcomeFor(guildId)
    if not welcome and guildId ~= self:GuildId() then return end
    if self.sv.joinNotice and U.HasPermission(guildId, GUILD_PERMISSION_INVITE) then self:JoinNotice(guildId, name) end
    if welcome and (self.sv.welcomeChat or self.sv.welcomeMail) then self:Welcome(guildId, name, self:IsMine(guildId, name)) end
end

-- Did you bring them in? You invited them (from this addon, or the game's invite as roster
-- history shows it), or you accepted an application in that guild in the last minute.
local ACCEPT_WINDOW_SECONDS = 60
function Recruit:IsMine(guildId, name)
    local key = guildId .. ":" .. name
    local invited = self.sv.invited[key] ~= nil
    self.sv.invited[key] = nil
    local accepted = self.acceptedAt[guildId] and GetTimeStamp() - self.acceptedAt[guildId] <= ACCEPT_WINDOW_SECONDS
    return invited or accepted == true
end

function Recruit:JoinNotice(guildId, name)
    local open, numMembers = self:OpenSlots(guildId)
    local line = string.format("%s joined %s. %d/%d members, %d open.", name, U.GuildName(guildId), numMembers, GUILD_MAX_MEMBERS, open)
    if self.sv.nearlyFull > 0 and open <= self.sv.nearlyFull then
        line = line .. (open <= 0 and " |cFF6B86The guild is full.|r" or " |cFF6B86Nearly full.|r")
    end
    if self.sv.traderWarning and not self:HasTrader(guildId) then
        line = line .. " |cFFC857No trader hired this week.|r"
    end
    U.Print(line)
end

-- Roster history: invites you sent from the game's own menus, so "People I invited or
-- accepted" knows about them. Welcomes themselves come from the join (OnMemberAdded), which
-- arrives at once; history can arrive later.
function Recruit:OnHistoryEvent(guildId, category, info, isLive)
    if info.eventType == GUILD_HISTORY_ROSTER_EVENT_INVITE and info.actingDisplayName == GetDisplayName()
        and GetTimeStamp() - info.timestampS < INVITE_KEEP_SECONDS and not U.IsMember(guildId, info.targetDisplayName) then
        self.sv.invited[guildId .. ":" .. info.targetDisplayName] = info.timestampS
    end
end

function Recruit:Welcome(guildId, name, mine)
    if name == GetDisplayName() then return end
    if self.sv.welcomeWho == "mine" and not mine then return end
    local index = GetGuildMemberIndexFromDisplayName(guildId, name)
    if not index then return end
    local _, _, _, status = GetGuildMemberInfo(guildId, index)
    local online = status ~= PLAYER_STATUS_OFFLINE
    if online and self.sv.welcomeChat then self:WelcomeInChat(guildId, name) end
    if self.sv.welcomeMail and (not online or self.sv.welcomeMailOnline) then self:WelcomeMail(guildId, name, online) end
end

-- Puts the welcome in the guild's chat box, if you aren't typing and the cooldown is over.
-- Otherwise you get a chat line with a link that does it when you're ready.
function Recruit:WelcomeInChat(guildId, name, fromLink)
    local welcome = self:WelcomeFor(guildId)
    local channel = GuildChannel(guildId)
    if not (welcome and channel) or zo_strtrim(welcome.text or "") == "" then return end
    local text = Fill(welcome.text, guildId, name)
    local recent = self.lastWelcome[guildId] and (GetTimeStamp() - self.lastWelcome[guildId] < self.sv.welcomeCooldownMinutes * 60)
    if fromLink or (not recent and not CHAT_SYSTEM:IsTextEntryOpen()) then
        self.lastWelcome[guildId] = GetTimeStamp()
        StartChatInput(text, channel)
        if not fromLink then U.Print("Welcome for %s is in the %s chat box. Press Enter to post it.", name, U.GuildName(guildId)) end
    else
        U.Print("%s joined %s. %s", name, U.GuildName(guildId), Link("Say welcome", "welcome", guildId, name))
    end
end

function Recruit:MailText(guildId, name)
    local welcome = self:WelcomeFor(guildId)
    if not welcome or zo_strtrim(welcome.body or "") == "" then return end
    return Fill(welcome.subject or "", guildId, name), Fill(welcome.body, guildId, name)
end

function Recruit:WelcomeMail(guildId, name, online)
    if not self:MailText(guildId, name) then return end
    if self.sv.welcomeMailAuto then
        local subject, body = self:MailText(guildId, name)
        A.SendMailNow(name, subject, body, function(ok, why)
            if ok then
                U.Print("Welcome mail sent to %s (%s).", name, U.GuildName(guildId))
            else
                U.Print("Welcome mail to %s failed: %s. %s", name, why or "unknown", Link("Write it", "mail", guildId, name))
                self.sv.mailWaiting[guildId .. ":" .. name] = { guildId = guildId, name = name, at = GetTimeStamp() }
                GT.Report:RefreshIfShown()
            end
        end)
        return
    end
    self.sv.mailWaiting[guildId .. ":" .. name] = { guildId = guildId, name = name, at = GetTimeStamp() }
    U.Print("%s joined %s%s. %s", name, U.GuildName(guildId), online and "" or " while offline", Link("Write welcome mail", "mail", guildId, name))
    GT.Report:RefreshIfShown()
end

function Recruit:OpenWelcomeMail(guildId, name)
    local subject, body = self:MailText(guildId, name)
    self.sv.mailWaiting[guildId .. ":" .. name] = nil
    if not body then
        U.Print("Welcomes are off for %s, so there's no welcome mail to write.", U.GuildName(guildId))
        GT.Report:RefreshIfShown()
        return
    end
    A.Warn(name, subject, body, "mail")
    GT.Report:RefreshIfShown()
end

-- Chat links: [Invite to ...], [Say welcome], [Write welcome mail].
function Recruit:OnLink(link, button, text, color, linkType, action, guildId, name, extra)
    if linkType ~= LINK_TYPE then return end
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return true end
    -- The game can report one click as both a mouse-up and a click; act once.
    local now = GetGameTimeMilliseconds()
    if self.lastLink == link and now - (self.lastLinkAt or 0) < 500 then return true end
    self.lastLink, self.lastLinkAt = link, now
    guildId = tonumber(guildId)
    if action == "invite" then
        self:Invite(guildId, name)
    elseif action == "welcome" then
        self:WelcomeInChat(guildId, name, true)
    elseif action == "mail" then
        self:OpenWelcomeMail(guildId, name)
    elseif action == "congrats" then
        GT.Milestones:FromLink(guildId, name, extra)   -- 1.34.0: member anniversaries
    end
    return true
end

-- Recruit scoreboard (1.34.0) ------------------------------------------------------
-- Every ad you post is noted (when, which zone, which wording). When someone joins the guild
-- you recruit for, the join counts for an ad when:
--   * you posted an ad in the zone they are in, within the last scoreMinutes, or
--   * you invited them or accepted their application, and you posted an ad within the last
--     scoreMinutes (they may have moved on to another zone since).
-- The newest matching post gets the join. Other joins are counted as "not from an ad".
-- An ad is known by its words: change the words and it counts as a new ad, so the scoreboard
-- shows which wording works. Saved as short text lines to keep the saved file small.

local function AdKey(text)
    local plain = Plain(text)
    local h = 5381
    for i = 1, #plain do h = (h * 33 + plain:byte(i)) % 4294967296 end
    return string.format("%08x", h)
end

local function SplitPost(line)
    local ts, zoneId, key = line:match("^(%d+):(%d+):(%w*)$")
    return tonumber(ts), tonumber(zoneId), key
end

local function SplitJoin(line)
    local ts, zoneId, key, how, name = line:match("^(%d+):(%d+):(%w*):(%a+):(.*)$")
    return tonumber(ts), tonumber(zoneId), key, how, name
end

-- The zone as the tour counts it (a delve or city counts as the zone it is in).
function Recruit:TourZoneId(zoneId)
    if self.zoneIds and self.zoneIds[zoneId] then return zoneId end
    return GetParentZoneId(zoneId)
end

function Recruit:RecordPost(zoneId, adNumber)
    if not self.sv.score then return end
    local text = self:AdText(adNumber)
    local key = AdKey(text)
    self.sv.adNames[key] = Short(text, 120)
    self.sv.adPosts[#self.sv.adPosts + 1] = string.format("%d:%d:%s", GetTimeStamp(), zoneId, key)
end

-- Was this person invited by you, or did you accept their application just now? (Doesn't
-- clear anything: the welcome asks the same question right after.)
function Recruit:BroughtInByYou(guildId, name)
    if self.sv.invited[guildId .. ":" .. name] then return true end
    local at = self.acceptedAt[guildId]
    return at ~= nil and GetTimeStamp() - at <= 60
end

function Recruit:CountJoin(guildId, name)
    local index = GetGuildMemberIndexFromDisplayName(guildId, name)
    if not index then return end
    local now = GetTimeStamp()
    local window = self.sv.scoreMinutes * 60
    local _, _, _, _, _, _, _, theirZone = GetGuildMemberCharacterInfo(guildId, index)
    if theirZone and theirZone ~= 0 then theirZone = self:TourZoneId(theirZone) else theirZone = nil end
    local mine = self:BroughtInByYou(guildId, name)
    local posts = self.sv.adPosts
    local found, how
    for i = #posts, 1, -1 do
        local ts, zoneId = SplitPost(posts[i])
        if ts and now - ts > window then break end
        if ts and theirZone and zoneId == theirZone then found, how = posts[i], "zone"; break end
        if ts and mine and not found then found, how = posts[i], "invite" end
    end
    local line
    if found then
        local _, zoneId, key = SplitPost(found)
        line = string.format("%d:%d:%s:%s:%s", now, zoneId, key, how, name)
        U.Print("Scoreboard: %s's join counts for your ad in %s.", name, self:ZoneName(zoneId))
    else
        line = string.format("%d:%d::other:%s", now, theirZone or 0, name)
    end
    self.sv.adJoins[#self.sv.adJoins + 1] = line
    GT.Report:RefreshIfShown()
end

function Recruit:PruneScore(now)
    local sv = self.sv
    local function Keep(list, split)
        local kept = {}
        for _, line in ipairs(list) do
            local ts = split(line)
            if ts and now - ts <= SCORE_KEEP_SECONDS then kept[#kept + 1] = line end
        end
        return kept
    end
    sv.adPosts = Keep(sv.adPosts, SplitPost)
    sv.adJoins = Keep(sv.adJoins, SplitJoin)
    -- Wordings no post refers to any more.
    local used = {}
    for _, line in ipairs(sv.adPosts) do
        local _, _, key = SplitPost(line)
        used[key] = true
    end
    for key in pairs(sv.adNames) do
        if not used[key] then sv.adNames[key] = nil end
    end
end

-- Totals over the last scoreDays: by zone, by ad wording, and joins not from an ad.
function Recruit:Score()
    return GT.Report:Cached("recruit:score", function()
        local since = GetTimeStamp() - self.sv.scoreDays * 86400
        local zones, ads = {}, {}
        local function Zone(zoneId)
            zones[zoneId] = zones[zoneId] or { id = zoneId, posts = 0, joins = 0 }
            return zones[zoneId]
        end
        local function Ad(key)
            ads[key] = ads[key] or { key = key, posts = 0, joins = 0, last = 0 }
            return ads[key]
        end
        local total = { posts = 0, joins = 0, other = 0 }
        for _, line in ipairs(self.sv.adPosts) do
            local ts, zoneId, key = SplitPost(line)
            if ts and ts >= since then
                Zone(zoneId).posts = Zone(zoneId).posts + 1
                local ad = Ad(key)
                ad.posts = ad.posts + 1
                if ts > ad.last then ad.last = ts end
                total.posts = total.posts + 1
            end
        end
        for _, line in ipairs(self.sv.adJoins) do
            local ts, zoneId, key, how = SplitJoin(line)
            if ts and ts >= since then
                if how == "other" then
                    total.other = total.other + 1
                else
                    Zone(zoneId).joins = Zone(zoneId).joins + 1
                    Ad(key).joins = Ad(key).joins + 1
                    total.joins = total.joins + 1
                end
            end
        end
        return { zones = zones, ads = ads, total = total }
    end)
end

-- "12 posts, 3 joins (1 in 4)"
local function ScoreText(posts, joins)
    local text = string.format("%d %s, %d %s", posts, posts == 1 and "post" or "posts", joins, joins == 1 and "join" or "joins")
    if joins > 0 and posts > 0 then text = text .. string.format(" |cB4B0D8(1 join per %.1f posts)|r", posts / joins) end
    return text
end

-- Best first: more joins, then fewer posts for them, then more posts.
local function Better(a, b)
    if a.joins ~= b.joins then return a.joins > b.joins end
    local ra, rb = a.joins / math.max(a.posts, 1), b.joins / math.max(b.posts, 1)
    if ra ~= rb then return ra > rb end
    return a.posts > b.posts
end

function Recruit:ScoreSummary()
    local t = self:Score().total
    return string.format("Scoreboard, last %d days: %d ad %s, %d %s from your ads, %d other %s.  Best first.",
        self.sv.scoreDays, t.posts, t.posts == 1 and "post" or "posts", t.joins, t.joins == 1 and "join" or "joins",
        t.other, t.other == 1 and "join" or "joins")
end

function Recruit:ScoreRows()
    local rows = {}
    local score = self:Score()
    local guildId = self:GuildId()
    -- Saved ads first (even unposted ones), then older wordings that were posted.
    local inUse = self:AdInUse(guildId)
    local list, seen = {}, {}
    for n = 1, MAX_ADS do
        if self:HasAd(guildId, n) then
            local key = AdKey(self:AdText(n))
            seen[key] = true
            local s = score.ads[key] or { posts = 0, joins = 0, last = 0 }
            list[#list + 1] = { n = n, key = key, posts = s.posts, joins = s.joins, last = s.last, text = self:AdText(n) }
        end
    end
    for key, s in pairs(score.ads) do
        if not seen[key] then
            list[#list + 1] = { key = key, posts = s.posts, joins = s.joins, last = s.last, text = self.sv.adNames[key] or "?" }
        end
    end
    table.sort(list, Better)
    for _, ad in ipairs(list) do
        local label
        if ad.n then
            label = string.format("|cA08CFFAd %d|r%s", ad.n, ad.n == inUse and " |c5EE6A0(in use)|r" or "")
        else
            label = "|c8A86B0Old wording|r"
        end
        local row = { text = string.format("%s  %s  \"%s\"%s", label, ScoreText(ad.posts, ad.joins), Short(ad.text, 50),
                ad.last > 0 and ("  |cB4B0D8last posted " .. U.FormatAgo(ad.last) .. "|r") or "  |cB4B0D8never posted|r"),
            tooltip = ad.text .. (ad.n and "" or "\n\nThis wording isn't saved any more: you changed or removed it.") }
        if ad.n then
            rows[#rows + 1] = GT.Report.AddMenu(row, {
                { label = ad.n == inUse and "In use" or "Use this ad", fn = function() self:UseAd(ad.n) end },
                { label = "Edit saved ads", fn = function() self:OpenSettings() end },
            })
        else
            rows[#rows + 1] = row
        end
    end
    -- Zones with posts or joins.
    local zones = {}
    for _, z in pairs(score.zones) do zones[#zones + 1] = z end
    table.sort(zones, Better)
    for _, z in ipairs(zones) do
        local zoneId = z.id
        local row = { text = string.format("Zone  %s  %s%s", zoneId ~= 0 and self:ZoneName(zoneId) or "Unknown zone", ScoreText(z.posts, z.joins),
            self.sv.skipZones[zoneId] and "  |c8A86B0skipped in the tour|r" or "") }
        local items = {}
        if zoneId ~= 0 then
            items[#items + 1] = { label = "Travel here", fn = function() self:TravelToZone(zoneId) end }
            if self.sv.skipZones[zoneId] then
                items[#items + 1] = { label = "Include in the tour", fn = function() self.sv.skipZones[zoneId] = nil; GT.Report:RefreshIfShown() end }
            else
                items[#items + 1] = { label = "Skip in the tour", fn = function() self.sv.skipZones[zoneId] = true; GT.Report:RefreshIfShown() end }
            end
        end
        rows[#rows + 1] = #items > 0 and GT.Report.AddMenu(row, items) or row
    end
    return rows
end

function Recruit:ScoreExportLines()
    local lines = { "Type\tName\tPosts\tJoins" }
    local score = self:Score()
    for key, s in pairs(score.ads) do
        lines[#lines + 1] = table.concat({ "Ad", self.sv.adNames[key] or key, s.posts, s.joins }, "\t")
    end
    for zoneId, z in pairs(score.zones) do
        lines[#lines + 1] = table.concat({ "Zone", zoneId ~= 0 and self:ZoneName(zoneId) or "Unknown zone", z.posts, z.joins }, "\t")
    end
    lines[#lines + 1] = table.concat({ "Other joins", "", "", score.total.other }, "\t")
    return lines
end

function Recruit:ConfirmClearScore()
    A.Confirm("Clear the scoreboard", "Forget every ad post and join the scoreboard has counted? Your saved ads stay.", function()
        self.sv.adPosts, self.sv.adJoins, self.sv.adNames = {}, {}, {}
        U.Print("Scoreboard cleared.")
        GT.Report:RefreshIfShown()
    end)
end

-- Number of the zone's joins over the scoreboard days, for the zone rows.
function Recruit:ZoneJoins(zoneId)
    local z = self:Score().zones[zoneId]
    return z and z.joins or 0
end

-- Recruit tab ----------------------------------------------------------------

function Recruit:TabTitle()
    local n = U.Count(self.sv.leadList) + U.Count(self.sv.mailWaiting)
    return n > 0 and string.format("Recruit (%d)", n) or "Recruit"
end

function Recruit:TabOffText()
    if self:AnyOn() then return nil end
    return "Recruiting is turned off. Click Set up below, or turn it on in /gtsettings under Recruiting."
end

function Recruit:TabSummary()
    if self.view == "score" and self.sv.score then return self:ScoreSummary() end
    local guildId = self:GuildId()
    if not guildId or guildId == 0 then return "You aren't in a guild." end
    local open, numMembers = self:OpenSlots(guildId)
    local parts = { string.format("Recruiting for %s: %d/%d members, %d open", U.GuildName(guildId), numMembers, GUILD_MAX_MEMBERS, open) }
    parts[#parts + 1] = string.format("%d pending %s", GetGuildFinderNumGuildApplications(guildId),
        GetGuildFinderNumGuildApplications(guildId) == 1 and "application" or "applications")
    if not self:HasTrader(guildId) then parts[#parts + 1] = "|cFFC857no trader this week|r" end
    local line = table.concat(parts, ", ") .. "."
    if self.sv.enabled then
        local ready, total = 0, 0
        for _, zone in ipairs(self.zones or {}) do
            if not self.sv.skipZones[zone.id] then
                total = total + 1
                if self:CooldownLeft(zone.id) == 0 then ready = ready + 1 end
            end
        end
        line = line .. string.format("  Zones ready: %d of %d.%s", ready, total, self.touring and "  |c5EE6A0Tour on.|r" or "")
    end
    return line
end

function Recruit:TabRows()
    if self.view == "score" and self.sv.score then return self:ScoreRows() end
    local rows = {}
    local guildId = self:GuildId()
    local leads = {}
    for name, lead in pairs(self.sv.leadList) do leads[#leads + 1] = { name = name, lead = lead } end
    table.sort(leads, function(a, b) return a.lead.at > b.lead.at end)
    for _, entry in ipairs(leads) do
        local name = entry.name
        local row = { text = string.format("|c5CC2FFLead|r  %s  whispered \"%s\"  %s", name, entry.lead.text, U.FormatAgo(entry.lead.at)),
            tooltip = "Someone whispered one of your keywords." }
        local items = {
            { label = "Invite to " .. U.GuildName(guildId), fn = function() self:Invite(guildId, name) end },
        }
        for _, item in ipairs(GT.Report.ContactItems(name)) do items[#items + 1] = item end
        items[#items + 1] = { label = "Dismiss", fn = function() self.sv.leadList[name] = nil; GT.Report:RefreshIfShown() end }
        rows[#rows + 1] = GT.Report.AddMenu(row, items)
    end
    for key, job in pairs(self.sv.mailWaiting) do
        local row = { text = string.format("|cA08CFFWelcome mail|r  %s joined %s %s", job.name, U.GuildName(job.guildId), U.FormatAgo(job.at)),
            tooltip = "They joined while offline. Write them a welcome mail." }
        rows[#rows + 1] = GT.Report.AddMenu(row, {
            { label = "Write welcome mail", fn = function() self:OpenWelcomeMail(job.guildId, job.name) end },
            { label = "Dismiss", fn = function() self.sv.mailWaiting[key] = nil; GT.Report:RefreshIfShown() end },
        })
    end
    if self.sv.enabled then
        local here = self:CurrentZoneId()
        for _, zone in ipairs(self.zones or {}) do
            local zoneId = zone.id
            local status
            if self.sv.skipZones[zoneId] then
                status = "|c8A86B0skipped|r"
            elseif self:CooldownLeft(zoneId) > 0 then
                status = string.format("posted %s, ready in %s", U.FormatAgo(self.sv.posted[zoneId]), U.FormatDuration(self:CooldownLeft(zoneId)))
            else
                status = "|c5EE6A0ready|r" .. (self.sv.posted[zoneId] and (" (posted " .. U.FormatAgo(self.sv.posted[zoneId]) .. ")") or "")
            end
            if self.sv.score then
                local joins = self:ZoneJoins(zoneId)
                if joins > 0 then status = status .. string.format("  |cB4B0D8%d %s|r", joins, joins == 1 and "join" or "joins") end
            end
            local row = { text = string.format("Zone  %s%s  %s", zone.name, zoneId == here and " |c5CC2FF(you are here)|r" or "", status) }
            local items = {}
            if zoneId == here then
                items[#items + 1] = { label = "Put the ad in chat", fn = function() self:PasteAd() end }
            else
                items[#items + 1] = { label = "Travel here", fn = function() self:TravelToZone(zoneId) end }
            end
            if self.sv.posted[zoneId] then
                items[#items + 1] = { label = "Clear cooldown", fn = function() self.sv.posted[zoneId] = nil; GT.Report:RefreshIfShown() end }
            end
            if self.sv.skipZones[zoneId] then
                items[#items + 1] = { label = "Include in the tour", fn = function() self.sv.skipZones[zoneId] = nil; GT.Report:RefreshIfShown() end }
            else
                items[#items + 1] = { label = "Skip in the tour", fn = function() self.sv.skipZones[zoneId] = true; GT.Report:RefreshIfShown() end }
            end
            rows[#rows + 1] = GT.Report.AddMenu(row, items)
        end
        -- 1.31.4: zones on the world map that the tour leaves out, each with the reason.
        for _, zone in ipairs(self.leftOut or {}) do
            rows[#rows + 1] = { text = string.format("|c8A86B0Not in the tour  %s: %s|r", zone.name, zone.why),
                tooltip = "The tour can only go where the game lets you jump to a player." }
        end
    end
    return rows
end

function Recruit:TabFooter()
    if self.view == "score" and self.sv.score then
        return {
            { label = "Back to zones", tip = "Shows the zones, leads and welcome mails again.", fn = function() self.view = "zones"; GT.Report:Refresh() end },
            { label = "Switch ad", tip = "Puts the next saved ad in use (you can save up to five in /gtsettings under Recruiting). Right-click an ad above to pick one.",
              fn = function() self:SwitchAd() end },
            { label = "Clear scoreboard", tip = "Forgets every ad post and join counted so far. Asks first.", fn = function() self:ConfirmClearScore() end },
        }
    end
    if not self.sv.enabled then
        return { { label = "Clear leads", tip = "Removes every lead from the list.", fn = function() self:ClearLeads() end } }
    end
    local footer = {
        { label = self.touring and "Stop tour" or "Start tour",
          tip = "Zone tour: the ad goes in the chat box, and each time you press Enter to post it you travel to the next ready zone. Click again to stop.",
          fn = function() self:ToggleTour() end },
        { label = "Put ad in chat", tip = "Puts your zone ad in the chat box. You press Enter to post it. Asks first if this zone is still on cooldown.",
          fn = function() self:PasteAd() end },
        { label = "Next zone", tip = "Travels once to the next ready zone through a guildmate, friend or house of yours.",
          fn = function() self:TravelNext() end },
        { label = "Reset zone timers", tip = "Clears the cooldown on every zone so the tour can visit them all again right away. Asks first.",
          fn = function() self:ConfirmResetTimers() end },
    }
    -- 1.34.0: only while there are leads, to leave room for Switch ad and Scoreboard.
    if next(self.sv.leadList) then
        footer[#footer + 1] = { label = "Clear leads", tip = "Removes every lead from the list.", fn = function() self:ClearLeads() end }
    end
    if self:CountAds(self:GuildId()) > 1 then
        table.insert(footer, 3, { label = "Switch ad", tip = function() return string.format("Ad %d is in use. Click to use the next saved ad instead.", self:AdInUse()) end,
            fn = function() self:SwitchAd() end })
    end
    if self.sv.score then
        footer[#footer + 1] = { label = "Scoreboard", tip = "Which zones and which ads bring in new members, best first.", fn = function() self.view = "score"; GT.Report:Refresh() end }
    end
    -- Seven buttons (with Export / copy) only fit when they are a little narrower.
    if #footer >= 6 then
        for _, button in ipairs(footer) do button.width = 152 end
    end
    return footer
end

-- 1.33.5: clears every zone cooldown by hand, after a confirm.
function Recruit:ConfirmResetTimers()
    local count = 0
    for zoneId in pairs(self.sv.posted) do
        if self:CooldownLeft(zoneId) > 0 then count = count + 1 end
    end
    if count == 0 then
        U.Print("No zones are on cooldown.")
        return
    end
    A.Confirm("Reset zone timers", string.format("Clear the cooldown on %d zone%s? The tour can then post in every zone again right away.",
        count, count == 1 and "" or "s"), function() self:ResetTimers() end)
end

function Recruit:ResetTimers()
    self.sv.posted = {}
    U.Print("Zone timers reset. Every zone is ready for your ad.")
    if self.UpdateBar then self:UpdateBar() end
    GT.Report:RefreshIfShown()
end

function Recruit:ClearLeads()
    self.sv.leadList = {}
    GT.Report:RefreshIfShown()
end

function Recruit:TabExportLines()
    if self.view == "score" and self.sv.score then return self:ScoreExportLines() end
    local lines = { "Type\tName\tDetail" }
    for name, lead in pairs(self.sv.leadList) do lines[#lines + 1] = table.concat({ "Lead", name, lead.text }, "\t") end
    for _, job in pairs(self.sv.mailWaiting) do lines[#lines + 1] = table.concat({ "Welcome mail", job.name, U.GuildName(job.guildId) }, "\t") end
    if self.sv.enabled then
        for _, zone in ipairs(self.zones or {}) do
            local at = self.sv.posted[zone.id]
            lines[#lines + 1] = table.concat({ "Zone", zone.name, at and U.FormatDate(at) or "never posted" }, "\t")
        end
    end
    return lines
end

function Recruit:RegisterTab()
    GT.Report:RegisterTab({
        id = "recruit",
        tip = "Recruiting: zone ad cooldowns, the zone tour, whisper leads and welcome mails waiting to be written.",
        title = function() return self:TabTitle() end,
        GetOffText = function() return self:TabOffText() end,
        about = {
            "Helps you advertise in zone chat: which zones are ready for an ad, a tour from zone to zone, and people who whispered you about joining.",
            "An ad is put in your chat box and waits for your Enter. Nothing is posted by itself.",
            "Save up to five ads and switch between them (by hand or after every post), and turn on the scoreboard to see which zones and ads bring in new members.",
            "Welcome messages, welcome mails and whisper leads are turned on separately on the Recruiting settings page.",
        },
        emptyText = "No whisper leads or welcome mails are waiting.",
        GetSummary = function() return self:TabSummary() end,
        GetRows = function() return self:TabRows() end,
        footer = function() return self:TabFooter() end,
        GetExportLines = function() return self:TabExportLines() end,
    })
end

-- Settings panel -------------------------------------------------------------

function Recruit:BuildSettings(options)
    local sv, d = self.sv, self.defaults
    local names, ids = { "Your first guild" }, { 0 }
    for _, guildId in ipairs(U.GetGuildIds()) do
        names[#names + 1] = U.GuildName(guildId)
        ids[#ids + 1] = guildId
    end
    local refresh = function() GT.Report:RefreshIfShown() end
    -- Which guild's welcome the boxes below edit (not saved; starts on the guild you recruit for).
    local welcomeNames, welcomeIds = {}, {}
    for _, guildId in ipairs(U.GetGuildIds()) do
        welcomeNames[#welcomeNames + 1] = U.GuildName(guildId)
        welcomeIds[#welcomeIds + 1] = guildId
    end
    local editing = self:GuildId()
    local function W() return sv.welcomes[editing] end
    local function SetW(key, v)
        local w = sv.welcomes[editing]
        if not w then
            w = { on = false, text = WELCOME_TEXT, subject = MAIL_SUBJECT, body = MAIL_BODY }
            sv.welcomes[editing] = w
        end
        w[key] = v
    end
    local function NotOn() local w = W(); return not (w and w.on) end
    local controls = {
        { type = "description", text = "Everything here starts turned off. Chat is never sent for you: ads and welcomes go into the chat box and you press Enter. Nobody is invited until you click Invite." },
        { type = "header", name = "Zone ads and zone tour" },
        { type = "checkbox", name = "Turn on zone ads and the zone tour",
          tooltip = "Adds zone cooldowns and the zone tour to the Recruit tab (/gt recruit), plus keybinds to put the ad in chat, start or stop the tour, and travel to the next ready zone.",
          getFunc = function() return sv.enabled end, setFunc = function(v) sv.enabled = v; if not v then self:StopTour() end; refresh() end, default = d.enabled },
        { type = "dropdown", name = "Recruit for", choices = names, choicesValues = ids,
          tooltip = "The guild your zone ad, whisper leads and the Recruit tab are for.",
          getFunc = function() return sv.guildId end, setFunc = function(v) sv.guildId = v; refresh() end, default = d.guildId },
        { type = "description", text = "Save up to five zone ads for the guild picked above and pick the one to use, or let the addon switch to the next one by itself. {guild} becomes the guild's name. ESO cuts chat at 350 characters. Empty ads are skipped." },
        { type = "editbox", name = "Zone ad 1", isMultiline = true, isExtraWide = true,
          tooltip = "Saved ad 1 for the guild picked above. Since this addon had one ad, this is the ad you wrote before.",
          getFunc = function() return self:SavedAd(self:GuildId(), 1) end, setFunc = function(v) self:SetSavedAd(self:GuildId(), 1, v); refresh() end, default = "" },
        { type = "editbox", name = "Zone ad 2", isMultiline = true, isExtraWide = true,
          tooltip = "Saved ad 2 for the guild picked above.",
          getFunc = function() return self:SavedAd(self:GuildId(), 2) end, setFunc = function(v) self:SetSavedAd(self:GuildId(), 2, v); refresh() end, default = "" },
        { type = "editbox", name = "Zone ad 3", isMultiline = true, isExtraWide = true,
          tooltip = "Saved ad 3 for the guild picked above.",
          getFunc = function() return self:SavedAd(self:GuildId(), 3) end, setFunc = function(v) self:SetSavedAd(self:GuildId(), 3, v); refresh() end, default = "" },
        { type = "editbox", name = "Zone ad 4", isMultiline = true, isExtraWide = true,
          tooltip = "Saved ad 4 for the guild picked above.",
          getFunc = function() return self:SavedAd(self:GuildId(), 4) end, setFunc = function(v) self:SetSavedAd(self:GuildId(), 4, v); refresh() end, default = "" },
        { type = "editbox", name = "Zone ad 5", isMultiline = true, isExtraWide = true,
          tooltip = "Saved ad 5 for the guild picked above.",
          getFunc = function() return self:SavedAd(self:GuildId(), 5) end, setFunc = function(v) self:SetSavedAd(self:GuildId(), 5, v); refresh() end, default = "" },
        { type = "dropdown", name = "Ad in use", choices = { "Ad 1", "Ad 2", "Ad 3", "Ad 4", "Ad 5" }, choicesValues = { 1, 2, 3, 4, 5 },
          tooltip = "The saved ad that goes in the chat box. If it is empty, the first saved ad is used. The Switch ad button on the Recruit tab and the \"switch to the next saved ad\" keybind change it too.",
          getFunc = function() return self:AdInUse() end, setFunc = function(v) self:UseAd(v, true) end, default = 1 },
        { type = "dropdown", name = "Switch ads by themselves", choices = { "Off: always the ad in use", "Next ad after every post", "Next ad each time you start the tour" },
          choicesValues = { "off", "post", "tour" },
          tooltip = "Rotates through your saved ads so zone chat doesn't see the same words every time. Off: the ad in use stays until you change it.",
          getFunc = function() return sv.adRotate end, setFunc = function(v) sv.adRotate = v end, default = d.adRotate },
        { type = "slider", name = "Zone cooldown (minutes)", min = 5, max = 240, step = 5,
          tooltip = "After you post the ad in a zone, wait this long before posting there again. The tour leaves zones on cooldown out. The time counts from each post, so if a whole tour takes longer than this, the first zones are ready again by the end.",
          getFunc = function() return sv.cooldownMinutes end, setFunc = function(v) sv.cooldownMinutes = v; refresh() end, default = d.cooldownMinutes },
        { type = "checkbox", name = "Travel through friends too", tooltip = "Besides guildmates, the tour can travel to friends in a zone.",
          getFunc = function() return sv.useFriends end, setFunc = function(v) sv.useFriends = v end, default = d.useFriends },
        { type = "dropdown", name = "Status bar", choices = { "Off", "While the zone tour runs", "Always" }, choicesValues = { "off", "tour", "always" },
          tooltip = "A small bar on screen with zones posted out of the total (x/y), pending guild applications and whether whisper leads are listening. Drag it to move it. It hides in menus like the rest of the HUD.",
          getFunc = function() return sv.statusBar end, setFunc = function(v) sv.statusBar = v; self:RefreshBar() end, default = d.statusBar },
        { type = "button", name = "Reset bar position", width = "half",
          tooltip = "Moves the status bar back to the top middle of the screen.",
          func = function() self:ResetBarPosition() end },
        { type = "checkbox", name = "Travel to my houses when nobody is there", tooltip = "If no guildmate or friend is in a zone, the tour travels to a house you own there (you arrive outside).",
          getFunc = function() return sv.useHouses end, setFunc = function(v) sv.useHouses = v end, default = d.useHouses },
        { type = "header", name = "Recruit scoreboard" },
        { type = "checkbox", name = "Turn on the recruit scoreboard",
          tooltip = "Counts your ad posts, and which of them bring in new members of the guild you recruit for, by zone and by ad. A join counts for your ad when you posted it in the zone the new member is in, or when you invited or accepted them, within the minutes below. See it with the Scoreboard button on the Recruit tab.",
          getFunc = function() return sv.score end, setFunc = function(v) sv.score = v; if not v then self.view = "zones" end; refresh() end, default = d.score },
        { type = "slider", name = "A join counts for an ad posted up to (minutes) before", min = 5, max = 120, step = 5,
          tooltip = "How long after an ad post a new member still counts for that ad.",
          getFunc = function() return sv.scoreMinutes end, setFunc = function(v) sv.scoreMinutes = v end, default = d.scoreMinutes,
          disabled = function() return not sv.score end },
        { type = "slider", name = "Scoreboard covers the last (days)", min = 1, max = 90, step = 1,
          tooltip = "The scoreboard adds up this many days. Posts and joins are kept for 90 days.",
          getFunc = function() return sv.scoreDays end, setFunc = function(v) sv.scoreDays = v; refresh() end, default = d.scoreDays,
          disabled = function() return not sv.score end },
        { type = "header", name = "Invites" },
        { type = "checkbox", name = "Invite from player names in chat",
          tooltip = "Right-click a player's name in chat for \"Invite to (guild)\", for each guild where your rank can invite.",
          getFunc = function() return sv.playerMenu end, setFunc = function(v) sv.playerMenu = v end, default = d.playerMenu },
        { type = "checkbox", name = "Whisper leads",
          tooltip = "When someone who isn't in the guild you recruit for whispers one of the keywords below, you get a chat line with an Invite link and a row on the Recruit tab. Nobody is invited until you click, unless you tick the option below.",
          getFunc = function() return sv.leads end, setFunc = function(v) sv.leads = v; refresh() end, default = d.leads },
        { type = "checkbox", name = "Invite automatically",
          tooltip = "A keyword whisper sends the guild invite right away, without a click, and a chat line says who was invited. Each person gets one invite; whispering again within 10 minutes doesn't send another.",
          getFunc = function() return sv.leadsAutoInvite end, setFunc = function(v) sv.leadsAutoInvite = v end, default = d.leadsAutoInvite,
          disabled = function() return not sv.leads end },
        { type = "editbox", name = "Lead keywords",
          tooltip = "Separated by commas. Whole words only, upper or lower case. A keyword like + counts only when it's the whole whisper.",
          getFunc = function() return sv.keywords end, setFunc = function(v) sv.keywords = v end, default = d.keywords },
        { type = "header", name = "New members" },
        { type = "checkbox", name = "Join notices",
          tooltip = "A chat line when someone joins the guild you recruit for, or a guild you turned welcomes on for (if your rank there can invite), with the member count and open slots. Your other guilds get nothing.",
          getFunc = function() return sv.joinNotice end, setFunc = function(v) sv.joinNotice = v end, default = d.joinNotice },
        { type = "slider", name = "Warn when open slots are at or below", min = 0, max = 50, step = 1,
          tooltip = "The join notice says the guild is nearly full. 0 = never.",
          getFunc = function() return sv.nearlyFull end, setFunc = function(v) sv.nearlyFull = v end, default = d.nearlyFull },
        { type = "checkbox", name = "Say when the guild has no trader", tooltip = "The join notice also says when the guild hasn't hired a trader this week.",
          getFunc = function() return sv.traderWarning end, setFunc = function(v) sv.traderWarning = v end, default = d.traderWarning },
        { type = "dropdown", name = "Welcome", choices = { "People I invited or accepted", "Everyone who joins" }, choicesValues = { "mine", "all" },
          tooltip = "Who gets the welcome message and welcome mail below. With several officers online, \"People I invited or accepted\" keeps you from welcoming the same person twice.",
          getFunc = function() return sv.welcomeWho end, setFunc = function(v) sv.welcomeWho = v end, default = d.welcomeWho },
        { type = "checkbox", name = "Welcome message in guild chat", requiresReload = true,
          tooltip = "When a new member joins while online, the welcome goes into that guild's chat box and you press Enter to post it. If you're typing, or the cooldown hasn't ended, you get a [Say welcome] link instead.",
          getFunc = function() return sv.welcomeChat end, setFunc = function(v) sv.welcomeChat = v end, default = d.welcomeChat },
        { type = "description", text = "Each guild has its own welcome message and mail. A guild only gets a welcome after you pick it below and tick \"Welcome new members in this guild\". Your other guilds get nothing." },
        { type = "dropdown", name = "Welcome settings for", choices = welcomeNames, choicesValues = welcomeIds,
          tooltip = "Pick a guild to see and edit its own welcome. This only chooses what the boxes below show.",
          getFunc = function() return editing end, setFunc = function(v) editing = v end, default = self:GuildId() },
        { type = "checkbox", name = "Welcome new members in this guild",
          tooltip = "Turns the welcome message and welcome mail on for the guild picked above only, using that guild's own text below.",
          getFunc = function() local w = W(); return w and w.on or false end, setFunc = function(v) SetW("on", v) end, default = false },
        { type = "editbox", name = "Welcome message", isMultiline = true, isExtraWide = true,
          tooltip = "For the guild picked above only. {new} = the new member's @name, {guild} = the guild's name. Leave it empty for no chat welcome in this guild.",
          getFunc = function() local w = W(); return w and w.text or WELCOME_TEXT end, setFunc = function(v) SetW("text", v) end, default = WELCOME_TEXT,
          disabled = NotOn },
        { type = "slider", name = "Welcome cooldown (minutes)", min = 0, max = 60, step = 1,
          tooltip = "After a welcome, the next one in the same guild waits this long and comes as a link instead, so a burst of joins doesn't flood guild chat.",
          getFunc = function() return sv.welcomeCooldownMinutes end, setFunc = function(v) sv.welcomeCooldownMinutes = v end, default = d.welcomeCooldownMinutes },
        { type = "checkbox", name = "Welcome mail", requiresReload = true,
          tooltip = "When a new member joins while offline, you get a [Write welcome mail] link and a row on the Recruit tab. The mail opens filled in for you to send.",
          getFunc = function() return sv.welcomeMail end, setFunc = function(v) sv.welcomeMail = v; refresh() end, default = d.welcomeMail },
        { type = "checkbox", name = "Mail new members who join while online too",
          tooltip = "Normally only members who joined while offline get the welcome mail (online ones get the chat welcome). Tick this to mail everyone who joins, online or not.",
          getFunc = function() return sv.welcomeMailOnline end, setFunc = function(v) sv.welcomeMailOnline = v end, default = d.welcomeMailOnline,
          disabled = function() return not sv.welcomeMail end },
        { type = "checkbox", name = "Send the welcome mail automatically",
          tooltip = "Sends the welcome mail in the background instead of opening it (normal postage). Waits while you're in combat or busy. If sending fails, you get the link instead.",
          getFunc = function() return sv.welcomeMailAuto end, setFunc = function(v) sv.welcomeMailAuto = v end, default = d.welcomeMailAuto,
          disabled = function() return not sv.welcomeMail end },
        { type = "editbox", name = "Welcome mail subject", tooltip = "For the guild picked above only. {new} = their @name, {guild} = the guild's name.",
          getFunc = function() local w = W(); return w and w.subject or MAIL_SUBJECT end, setFunc = function(v) SetW("subject", v) end, default = MAIL_SUBJECT,
          disabled = NotOn },
        { type = "editbox", name = "Welcome mail text", isMultiline = true, isExtraWide = true,
          tooltip = "For the guild picked above only. {new} = their @name, {guild} = the guild's name. Leave it empty for no welcome mail in this guild.",
          getFunc = function() local w = W(); return w and w.body or MAIL_BODY end, setFunc = function(v) SetW("body", v) end, default = MAIL_BODY,
          disabled = NotOn },
    }
    -- 1.10.0: on a page of its own, "Fury's Guild Toolset - Recruiting"; the main page points to it.
    self.panel = GT.Settings:AddPage("Recruit", "Recruiting", controls, true)
    GT.Settings:AddPointer(options, "Recruiting", "Zone ads, the zone tour, welcomes, whisper leads, the status bar and the rest of recruiting are on their own page: \"Fury's Guild Toolset - Recruiting\" in the Add-Ons list.",
        function() self:OpenSettings() end)
end

function Recruit:OpenSettings()
    LibAddonMenu2:OpenToPanel(self.panel)
end

-- Keybinds
function Recruit.KeyAd() Recruit:PasteAd() end
function Recruit.KeyTour() Recruit:ToggleTour() end
function Recruit.KeyNextAd() Recruit:SwitchAd() end
function Recruit.KeyNext() if Recruit.sv.enabled then Recruit:TravelNext() else U.Print("Zone ads are turned off. Turn on Recruiting in /gtsettings.") end end
GT.Recruit = Recruit
