local A, C, S = DeskUI, DeskUI.Core, DeskUI.Style
local P = S.palette
A.BrowserPages, A.lastFamilyPage = {}, {}
A.RootDefaults = {Skills = "Skill Assignment", Champion = "Champion", Collections = "Collectibles",
    Friends = "Friends List", Guilds = "Guild Home", ["Group & Activity Finder"] = "Group",
    Mail = "Inbox", Help = "Tutorials"}
A.FamilyTabs = {
    Skills = {{"Assignment", "Skill Assignment"}, {"Scribing"}},
    Collections = {{"Collectibles", "Collectibles"}, {"Stories", "Stories"}, {"Housing", "Housing"}, {"Outfit Styles", "Outfit Styles"}, {"Set Items"}, {"Tales of Tribute Patrons", "Tales of Tribute Patrons"}},
    Friends = {{"Friends", "Friends List"}, {"Ignored", "Ignored"}},
    Guilds = {{"Home", "Guild Home"}, {"Roster", "Guild Roster"}, {"Ranks", "Guild Ranks"}, {"Guild Tools"}, {"Heraldry"}, {"History"}},
    ["Group & Activity Finder"] = {{"Group", "Group"}, {"Group Finder"}, {"Zone Guide"}, {"Dungeon Finder"}, {"Battlegrounds"}, {"Tribute"}, {"Home Tours"}},
    Mail = {{"Inbox", "Inbox"}, {"Send"}},
    Help = {{"Tutorials", "Tutorials"}, {"Customer Support"}, {"Emotes", "Emotes"}},
}

function A.ResolvePage(name)
    local target = A.RootDefaults[name]
    return target and (A.lastFamilyPage[name] or target) or name
end

function A.PageCategory(name)
    if A.JournalPages[name] then return "Journal" end
    return A.BrowserPages[name] and A.BrowserPages[name].category or name
end

local function Require(name, ...)
    assert(type(_G[name]) == "function", name .. " is unavailable on this client. Other DeskUI pages remain available.")
    return _G[name](...)
end
local function Text(name, value)
    return C.Try("GetString", name, value) or tostring(value or "Unavailable")
end
local function Entry(id, name, subtitle, body, icon)
    return {id = tostring(id), name = name or "Unnamed", subtitle = subtitle or "", body = body or "", icon = icon, kind = "detail"}
end
local function Folder(id, name, subtitle, path)
    local row = Entry(id, name, subtitle)
    row.kind, row.path = "folder", path
    path.label = name
    return row
end
local function Register(name, category, read, notice, empty)
    A.BrowserPages[name] = {category = category, read = read, notice = notice, empty = empty}
end

local function ReadSkills(page)
    local rows, path = {}, page.path
    if not path.skillType then
        for skillType = 1, Require("GetNumSkillTypes") do
            local count = Require("GetNumSkillLines", skillType)
            if count > 0 then rows[#rows + 1] = Folder("skilltype:" .. skillType, Text("SI_SKILLTYPE", skillType),
                count .. " skill lines", {skillType = skillType}) end
        end
    elseif not path.line then
        for line = 1, Require("GetNumSkillLines", path.skillType) do
            local id = Require("GetSkillLineId", path.skillType, line)
            local name = Require("GetSkillLineNameById", id)
            local rank, _, active, discovered = Require("GetSkillLineDynamicInfo", path.skillType, line)
            if discovered then rows[#rows + 1] = Folder("skillline:" .. id, name,
                "Rank " .. tostring(rank) .. (active and " / Active" or " / Inactive"), {skillType = path.skillType, line = line}) end
        end
    else
        for index = 1, Require("GetNumSkillAbilities", path.skillType, path.line) do
            local name, icon, rank, passive, ultimate, purchased = Require("GetSkillAbilityInfo", path.skillType, path.line, index)
            local id = Require("GetSkillAbilityId", path.skillType, path.line, index, false)
            local kind = passive and "Passive" or (ultimate and "Ultimate" or "Active ability")
            rows[#rows + 1] = Entry("ability:" .. id, name, kind .. (purchased and " / Purchased" or " / Not purchased"),
                "Rank " .. tostring(rank) .. "\n\n" .. (C.Try("GetAbilityDescription", id) or "Description unavailable."), icon)
        end
    end
    return rows
end

local function ReadChampion(page)
    local rows = {}
    if C.Try("IsUnitChampion", "player") == false then return rows end
    if not page.path.discipline then
        for index = 1, Require("GetNumChampionDisciplines") do
            local id = Require("GetChampionDisciplineId", index)
            rows[#rows + 1] = Folder("discipline:" .. id, Require("GetChampionDisciplineName", id),
                "Champion discipline", {discipline = index})
        end
    else
        for index = 1, Require("GetNumChampionDisciplineSkills", page.path.discipline) do
            local id = Require("GetChampionSkillId", page.path.discipline, index)
            local points = Require("GetNumPointsSpentOnChampionSkill", id)
            local maximum = Require("GetChampionSkillMaxPoints", id)
            rows[#rows + 1] = Entry("champion:" .. id, Require("GetChampionSkillName", id),
                tostring(points) .. "/" .. tostring(maximum) .. " points",
                Require("GetChampionSkillDescription", id, points))
        end
    end
    return rows
end

local collectionSpecializations = {Collectibles = "NONE", Stories = "DLC", Housing = "HOUSING", ["Outfit Styles"] = "OUTFIT_STYLES", ["Tales of Tribute Patrons"] = "TRIBUTE_PATRONS"}
local function ReadCollectibles(page)
    local rows, path = {}, page.path
    local expected = _G["COLLECTIBLE_CATEGORY_SPECIALIZATION_" .. collectionSpecializations[page.name]]
    assert(expected ~= nil, "Collection category specializations are unavailable on this client.")
    if not path.category then
        for category = 1, Require("GetNumCollectibleCategories") do
            local name, _, _, unlocked, total = Require("GetCollectibleCategoryInfo", category)
            if Require("GetCollectibleCategorySpecialization", category) == expected then
                rows[#rows + 1] = Folder("collectiblecategory:" .. category, name,
                    tostring(unlocked) .. "/" .. tostring(total) .. " unlocked", {category = category})
            end
        end
    else
        local _, subcategories = Require("GetCollectibleCategoryInfo", path.category)
        if not path.subcategory then
            for subcategory = 1, subcategories do
                local name, _, unlocked, total = Require("GetCollectibleSubCategoryInfo", path.category, subcategory)
                rows[#rows + 1] = Folder("collectiblesubcategory:" .. subcategory, name,
                    tostring(unlocked) .. "/" .. tostring(total) .. " unlocked", {category = path.category, subcategory = subcategory})
            end
        end
        local count = Require("GetNumCollectiblesInCollectibleCategory", path.category, path.subcategory)
        for index = 1, count do
            local id = Require("GetCollectibleId", path.category, path.subcategory, index)
            local name, description, icon, _, unlocked, _, active, _, hint = Require("GetCollectibleInfo", id)
            -- Honor native hidden/locked categories instead of exposing their hidden entries.
            local _, _, _, _, _, hidesLocked = Require("GetCollectibleCategoryInfo", path.category)
            if unlocked or not hidesLocked then
                rows[#rows + 1] = Entry("collectible:" .. id, name,
                    (unlocked and "Collected" or "Not collected") .. (active and " / Active" or ""),
                    description .. (not unlocked and hint and hint ~= "" and ("\n\n" .. hint) or ""), icon)
            end
        end
    end
    return rows
end

local function CharacterSummary(hasCharacter, name, zone, _, _, level, cp)
    if not hasCharacter then return "No character information available." end
    return (name or "") .. "\n" .. (zone or "") .. "\n" .. ((level or 0) >= 50 and (cp or 0) > 0
        and ("CP " .. cp) or ("Level " .. tostring(level or "?")))
end
local function ReadFriends(page)
    local rows = {}
    if page.name == "Ignored" then
        for index = 1, Require("GetNumIgnored") do
            local name, note = Require("GetIgnoredInfo", index)
            rows[#rows + 1] = Entry("ignored:" .. name, name, "Ignored", note)
        end
    else
        for index = 1, Require("GetNumFriends") do
            local name, note, status = Require("GetFriendInfo", index)
            local summary = CharacterSummary(Require("GetFriendCharacterInfo", index))
            rows[#rows + 1] = Entry("friend:" .. name, name, Text("SI_PLAYERSTATUS", status),
                summary .. (note ~= "" and ("\n\nNote: " .. note) or ""))
        end
    end
    return rows
end

local function ReadGuilds(page)
    local rows, id = {}, page.path.guild
    if not id then
        for index = 1, Require("GetNumGuilds") do
            local guild = Require("GetGuildId", index)
            local members, online = Require("GetGuildInfo", guild)
            rows[#rows + 1] = Folder("guild:" .. guild, Require("GetGuildName", guild),
                online .. "/" .. members .. " members online", {guild = guild})
        end
        return rows
    end
    -- Recheck membership; a stale saved path must not keep an old guild roster visible.
    local member = false
    for index = 1, Require("GetNumGuilds") do if Require("GetGuildId", index) == id then member = true end end
    assert(member, "You are no longer in this guild. Use Back to choose a current guild.")
    if page.name == "Guild Home" then
        local members, online, leader = Require("GetGuildInfo", id)
        rows[#rows + 1] = Entry("guildhome:" .. id, Require("GetGuildName", id), online .. "/" .. members .. " members online",
            "Guild leader: " .. leader .. "\n\nMESSAGE OF THE DAY\n" .. Require("GetGuildMotD", id)
            .. "\n\nABOUT US\n" .. Require("GetGuildDescription", id))
    elseif page.name == "Guild Ranks" then
        for index = 1, Require("GetNumGuildRanks", id) do
            rows[#rows + 1] = Entry("rank:" .. index, Require("GetGuildRankCustomName", id, index), "Rank " .. index,
                "Rank permissions and editing remain in ESO's guild interface.")
        end
    else
        local members = Require("GetGuildInfo", id)
        for index = 1, members do
            local name, note, rank, status = Require("GetGuildMemberInfo", id, index)
            rows[#rows + 1] = Entry("guildmember:" .. name, name, Text("SI_PLAYERSTATUS", status),
                CharacterSummary(Require("GetGuildMemberCharacterInfo", id, index))
                .. "\n\nRank: " .. Require("GetGuildRankCustomName", id, rank) .. (note ~= "" and ("\n\nNote: " .. note) or ""))
        end
    end
    return rows
end

local function ReadGroup()
    local rows, count = {}, Require("GetGroupSize")
    for index = 1, count do
        local unit = Require("GetGroupUnitTagByIndex", index)
        if unit then
            local name = Require("GetUnitName", unit)
            local role = Require("GetGroupMemberSelectedRole", unit)
            rows[#rows + 1] = Entry("group:" .. unit, name, Text("SI_LFGROLE", role),
                (unit == C.Try("GetGroupLeaderUnitTag") and "Group leader\n\n" or "")
                .. "Class: " .. (C.Try("GetUnitClass", unit) or "Unavailable")
                .. "\nLevel: " .. tostring(C.Try("GetUnitLevel", unit) or "Unavailable")
                .. "\nZone: " .. (C.Try("GetUnitZone", unit) or "Unavailable"))
        end
    end
    return rows
end

A.mailBodies = {}
local function MailKey(id) return C.Try("Id64ToString", id) or tostring(id) end
local function ReadInbox()
    assert(not A.mailboxError, A.mailboxError)
    local rows, previous, seen = {}, nil, {}
    while true do
        local id = Require("GetNextMailId", previous)
        if id == nil then break end
        local key = MailKey(id)
        assert(not seen[key] and #rows < 5000, "The mail list changed unexpectedly. Refresh to try again.")
        seen[key], previous = true, id
        local sender, character, subject, icon, unread, _, _, _, attachments, money, cod, expires = Require("GetMailItemInfo", id)
        local row = Entry("mail:" .. key, subject, sender .. (unread and " / Unread" or ""),
            "From: " .. sender .. (character ~= "" and (" (" .. character .. ")") or "")
            .. "\nAttachments: " .. tostring(attachments) .. " / Gold: " .. tostring(money)
            .. "\nCOD: " .. tostring(cod) .. " / Expires in days: " .. tostring(expires or "-"), icon)
        row.kind, row.mailId, row.mailKey = "mail", id, key
        rows[#rows + 1] = row
    end
    for key in pairs(A.mailBodies) do if not seen[key] then A.mailBodies[key] = nil end end
    return rows
end

function A.MailBody(row)
    return row.body .. "\n\n" .. (A.mailBodies[row.mailKey] or "Select Read message to load the body. Reading may mark the message as read. Sending, deleting and attachment actions remain in ESO's mail interface.")
end
function A.RequestMailBody(page, row)
    if C.Try("IsReadMailInfoReady", row.mailId) then
        local ok, text = pcall(Require, "ReadMail", row.mailId)
        if ok then A.mailBodies[row.mailKey] = text; A.RefreshBrowser(page)
        else page.body:SetText("Could not read message: " .. tostring(text)) end
        return
    end
    A.pendingMail = {id = row.mailId, key = row.mailKey}
    local ok, result = pcall(Require, "RequestReadMail", row.mailId)
    if not ok then A.pendingMail = nil; page.body:SetText("Could not request message: " .. tostring(result))
    elseif result ~= REQUEST_READ_MAIL_RESULT_SUCCESS_CACHED and result ~= REQUEST_READ_MAIL_RESULT_SUCCESS_SERVER_REQUESTED
        and result ~= REQUEST_READ_MAIL_RESULT_ALREADY_REQUESTED then
        A.pendingMail = nil; page.body:SetText("ESO could not load this message (result " .. tostring(result) .. "). Try Read message again.")
    elseif result == REQUEST_READ_MAIL_RESULT_SUCCESS_CACHED then
        local readOK, body = pcall(Require, "ReadMail", row.mailId)
        A.pendingMail = nil
        if readOK then A.mailBodies[row.mailKey] = body; A.RefreshBrowser(page)
        else page.body:SetText("Could not read message: " .. tostring(body)) end
    else page.body:SetText(row.body .. "\n\nLoading message...") end
end

function A.CloseDeskMailbox()
    A.pendingMail = nil
    if A.mailboxOwned then
        A.mailboxOwned = false
        C.Try("CloseMailbox")
    end
end

function A.EnterMenuPage(name, previous)
    if previous == "Inbox" and name ~= "Inbox" then A.CloseDeskMailbox() end
    if name == "Inbox" and not A.mailboxOwned then
        A.mailboxError = nil
        local ok, err = pcall(Require, "RequestOpenMailbox")
        A.mailboxOwned = ok
        if not ok then A.mailboxError = "Could not open mailbox: " .. tostring(err) end
    end
end

local function ReadTutorials(page)
    local rows = {}
    if page.name == "Emotes" then
        for index = 1, Require("GetNumEmotes") do
            local slash, category, id, name = Require("GetEmoteInfo", index)
            rows[#rows + 1] = Entry("emote:" .. id, name ~= "" and name or slash, slash,
                "Category: " .. Text("SI_EMOTECATEGORY", category) .. "\n\nUse " .. slash .. " in chat to perform this emote.")
        end
    else
        for index = 1, Require("GetNumTutorials") do
            local title, description = Require("GetTutorialInfo", index)
            if title ~= "" then rows[#rows + 1] = Entry("tutorial:" .. index, title, "Tutorial", description) end
        end
    end
    return rows
end

local function ReadCadwell(page)
    local rows, path = {}, page.path
    local current = Require("GetCadwellProgressionLevel")
    if not path.progression then
        for _, level in ipairs({CADWELL_PROGRESSION_LEVEL_SILVER, CADWELL_PROGRESSION_LEVEL_GOLD}) do
            if level <= current then rows[#rows + 1] = Folder("cadwell:" .. level,
                level == CADWELL_PROGRESSION_LEVEL_SILVER and "Cadwell's Silver" or "Cadwell's Gold", "Almanac", {progression = level}) end
        end
    elseif path.progression <= current then
        for zone = 1, Require("GetNumZonesForCadwellProgressionLevel", path.progression) do
            local name, description = Require("GetCadwellZoneInfo", path.progression, zone)
            local lines = {description}
            for poi = 1, Require("GetNumPOIsForCadwellProgressionLevelAndZone", path.progression, zone) do
                local title, opening, closing, _, discovered, completed = Require("GetCadwellZonePOIInfo", path.progression, zone, poi)
                if discovered then lines[#lines + 1] = (completed and "[Complete] " or "[In progress] ") .. title
                    .. "\n" .. (completed and closing or opening) end
            end
            rows[#rows + 1] = Entry("cadwellzone:" .. zone, name, "Zone objectives", table.concat(lines, "\n\n"))
        end
    end
    return rows
end

local function ReadAntiquities(page)
    local rows, previous, seen, categories = {}, nil, {}, {}
    while true do
        local id = Require("GetNextAntiquityId", previous)
        if id == nil then break end
        assert(not seen[id], "Antiquity data changed unexpectedly. Refresh to try again.")
        seen[id], previous = true, id
        if C.Try("DoesAntiquityPassVisibilityRequirements", id) ~= false then
            local category = Require("GetAntiquityCategoryId", id)
            if not page.path.antiquityCategory then categories[category] = (categories[category] or 0) + 1
            elseif category == page.path.antiquityCategory then
                local recovered = Require("GetNumAntiquitiesRecovered", id)
                local lead = Require("DoesAntiquityHaveLead", id)
                rows[#rows + 1] = Entry("antiquity:" .. id, Require("GetAntiquityName", id),
                    (lead and "Lead available" or "No lead") .. " / Recovered " .. recovered,
                    "Recovered: " .. recovered .. "\nCodex entries acquired: " .. Require("GetNumAntiquityLoreEntriesAcquired", id)
                    .. "/" .. Require("GetNumAntiquityLoreEntries", id)
                    .. "\n\nScrying, lead tracking and the full codex reader remain in ESO's Antiquities interface.", C.Try("GetAntiquityIcon", id))
            end
        end
    end
    for category, count in pairs(categories) do rows[#rows + 1] = Folder("antiquitycategory:" .. category,
        Require("GetAntiquityCategoryName", category), count .. " antiquities", {antiquityCategory = category}) end
    return rows
end

Register("Skill Assignment", "Skills", ReadSkills, "Skill types > discovered skill lines > abilities. Browsing only; no point spending or slot changes.")
Register("Champion", "Champion", ReadChampion, "Disciplines > stars > current bonuses. Browsing only; no point spending or respec.", "Champion details become available on a Champion-level character.")
Register("Collectibles", "Collections", ReadCollectibles, "Categories > subcategories > collectible details. Activation and previews remain in ESO's Collections interface.")
for _, name in ipairs({"Stories", "Housing", "Outfit Styles", "Tales of Tribute Patrons"}) do
    Register(name, "Collections", ReadCollectibles, "Browse this collection's categories and unlock details. Activation, travel, purchases and previews remain in ESO's interface.")
end
Register("Friends List", "Friends", ReadFriends, "Friends, status, character details and notes. No messaging or social actions are performed.", "Your friends list has no entries available.")
Register("Ignored", "Friends", ReadFriends, "Browse ignored accounts and notes. No changes are made to the ignored list.", "Your ignored list is empty.")
for _, name in ipairs({"Guild Home", "Guild Roster", "Guild Ranks"}) do Register(name, "Guilds", ReadGuilds,
    "Choose a guild, then inspect its information. Guild management and member actions remain in ESO's interface.", "You are not currently in a guild, or this page has no entries.") end
Register("Group", "Group & Activity Finder", ReadGroup, "Current group roster and member details. Invitations, role changes and queueing remain in ESO's interface.", "You are not currently in a group.")
Register("Inbox", "Mail", ReadInbox, "Select a message, then Read message. Sending, deleting and taking attachments are not included.", "The inbox is empty, or ESO is still loading it. Use Refresh to try again.")
Register("Tutorials", "Help", ReadTutorials, "Browse ESO's tutorial titles and descriptions without leaving DeskUI.")
Register("Emotes", "Help", ReadTutorials, "Browse emote names and chat commands. Selecting an entry does not perform the emote.")
Register("Antiquities Codex", "Journal", ReadAntiquities, "Categories > antiquities > lead/recovery status. Scrying and the full codex reader remain in ESO's interface.")
Register("Cadwell's Almanac", "Journal", ReadCadwell, "Progression > zones > discovered objectives. Only unlocked Silver/Gold stages are shown.", "Cadwell's Almanac is not unlocked for this character, or there are no objectives available.")
A.JournalPages["Antiquities Codex"], A.JournalPages["Cadwell's Almanac"] = true, true
for _, name in ipairs({"Skill Assignment", "Champion", "Collectibles", "Stories", "Housing", "Outfit Styles",
    "Tales of Tribute Patrons", "Guild Home", "Guild Ranks", "Cadwell's Almanac"}) do
    A.BrowserPages[name].preserveOrder = true
end

function A.InstallMenuEvents()
    if EVENT_MAIL_CLOSE_MAILBOX then EVENT_MANAGER:RegisterForEvent("DeskUIMail", EVENT_MAIL_CLOSE_MAILBOX, function()
        A.mailboxOwned, A.pendingMail = false, nil
    end) end
    if EVENT_MAIL_READABLE then
        EVENT_MANAGER:RegisterForEvent("DeskUIMail", EVENT_MAIL_READABLE, function(_, id)
            local pending = A.pendingMail
            if not pending or MailKey(id) ~= pending.key then return end
            local ok, body = pcall(Require, "ReadMail", id)
            A.pendingMail = nil
            if ok then A.mailBodies[pending.key] = body end
            if A.ready and A.activePage == "Inbox" and SCENE_MANAGER:IsShowing("deskUIInventory") then
                local page = A.pages.Inbox
                if page.selected and page.selected.mailKey == pending.key then
                    if ok then A.RefreshBrowser(page) else page.body:SetText("Could not read message: " .. tostring(body)) end
                end
            end
        end)
    end
    for _, name in ipairs({"EVENT_SKILLS_FULL_UPDATE", "EVENT_COLLECTIBLES_UPDATED", "EVENT_SOCIAL_DATA_LOADED",
        "EVENT_FRIEND_PLAYER_STATUS_CHANGED", "EVENT_FRIEND_ADDED", "EVENT_FRIEND_REMOVED", "EVENT_IGNORE_ADDED", "EVENT_IGNORE_REMOVED",
        "EVENT_GUILD_MEMBER_ADDED", "EVENT_GUILD_MEMBER_REMOVED", "EVENT_GUILD_MOTD_CHANGED", "EVENT_GUILD_DESCRIPTION_CHANGED",
        "EVENT_GROUP_UPDATE", "EVENT_MAIL_OPEN_MAILBOX", "EVENT_MAIL_INBOX_UPDATE", "EVENT_MAIL_REMOVED", "EVENT_ANTIQUITIES_UPDATED", "EVENT_ANTIQUITY_UPDATED",
        "EVENT_CADWELL_PROGRESSION_LEVEL_CHANGED", "EVENT_CHAMPION_POINT_GAINED"}) do
        if _G[name] then EVENT_MANAGER:RegisterForEvent("DeskUIOtherMenus", _G[name], function()
            if A.ready and A.BrowserPages[A.activePage] and SCENE_MANAGER:IsShowing("deskUIInventory") then
                EVENT_MANAGER:UnregisterForUpdate("DeskUIMenusRefresh")
                EVENT_MANAGER:RegisterForUpdate("DeskUIMenusRefresh", 200, function()
                    EVENT_MANAGER:UnregisterForUpdate("DeskUIMenusRefresh")
                    if SCENE_MANAGER:IsShowing("deskUIInventory") then A.RefreshCurrentPage() end
                end)
            end
        end) end
    end
end
