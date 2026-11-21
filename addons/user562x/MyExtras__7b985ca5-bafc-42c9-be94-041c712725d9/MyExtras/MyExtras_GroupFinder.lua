local ME = MyExtras
local DT = ME.DungeonsTrials
local GF = {}
ME.GroupFinder = GF

--------------------------------------------------
-- Config
--------------------------------------------------
local EVENT_NAME      = ME.name .. "_GroupFinder"
local TIMER_NAME      = EVENT_NAME .. "Timer"
local TIMEOUT_NAME    = EVENT_NAME .. "Timeout"
local STATUS_NAME     = EVENT_NAME .. "Status"
local MOVE_SCENE      = "MyExtras_GroupFinderMove"
local ONE_MS          = 30000
local MANY_MS         = 60000
local SEARCH_WAIT_MS  = 30000
local STATUS_MS       = 1000
local MOVE_SPEED      = 500
local SCALE_SPEED     = 40
local SCALE_MIN       = 60
local SCALE_MAX       = 160
local WIDTH_MIN       = 300
local WIDTH_MAX       = 680
local SPREAD_MIN      = WIDTH_MIN
local SPREAD_MAX      = WIDTH_MAX
local SPREAD_SPEED    = 200
local ROWS_MIN        = 2
local ROWS_MAX        = 15
local PADDING         = 14
local HEADER_HEIGHT   = 70
local ROW_GAP         = 6
local ROW_HEIGHT      = 78
local BASE_SIZE       = 24
local ROLE_WIDTH      = 124
local ROLE_ICON       = 20
local BOX_CORNER      = 16
local ROW_CORNER      = 10
local WHITE_TEXTURE   = "EsoUI/Art/Miscellaneous/white.dds"

local GAMEPLAY_SCENES = { hud = true, hudui = true, siegeBar = true }

local VETERAN_COLOR = { 1, 0.65, 0.19 }
local OTHER_COLOR   = { 0.70, 0.49, 1 }
local NEW_COLOR     = { 0.49, 0.95, 0.56 }
local ALARM_COLOR   = { 1, 0.20, 0.17 }
local TEXT_COLOR    = { 0.96, 0.98, 1 }

local DEFAULTS = {
    groupFinderShow              = false,
    groupFinderCloseOnJoin       = true,
    groupFinderRole              = "any",
    groupFinderDungeons          = "off",
    groupFinderArenas            = "off",
    groupFinderTrials            = "off",
    groupFinderArchive           = false,
    groupFinderPvP               = false,
    groupFinderZone              = false,
    groupFinderCustom            = false,
    groupFinderAlarm             = false,
    groupFinderAlarmDungeons     = {},
    groupFinderAlarmTrials       = {},
    groupFinderAlarmArenas       = {},
    groupFinderAlarmOther        = {},
    groupFinderAlarmSound        = "duelStart",
    groupFinderFont              = "EsoUI/Common/Fonts/FTN57.otf",
    groupFinderScale             = 100,
    groupFinderWidth             = 420,
    groupFinderRows              = 8,
    groupFinderPosX              = 405,
    groupFinderPosY              = -400,
    groupFinderBackground        = true,
    groupFinderBackgroundOpacity = 100,
}
DT:AddDefaults(DEFAULTS)

local CATEGORIES = {
    { key = "groupFinderDungeons", id = "GROUP_FINDER_CATEGORY_DUNGEON",         modes = true },
    { key = "groupFinderArenas",   id = "GROUP_FINDER_CATEGORY_ARENA",           modes = true },
    { key = "groupFinderTrials",   id = "GROUP_FINDER_CATEGORY_TRIAL",           modes = true },
    { key = "groupFinderArchive",  id = "GROUP_FINDER_CATEGORY_ENDLESS_DUNGEON" },
    { key = "groupFinderPvP",      id = "GROUP_FINDER_CATEGORY_PVP",             expand = true },
    { key = "groupFinderZone",     id = "GROUP_FINDER_CATEGORY_ZONE" },
    { key = "groupFinderCustom",   id = "GROUP_FINDER_CATEGORY_CUSTOM" },
}

GF.modeChoices = {
    { name = "Off",     value = "off"     },
    { name = "Normal",  value = "normal"  },
    { name = "Veteran", value = "veteran" },
    { name = "All",     value = "all"     },
}

GF.roleChoices = {
    { name = "Any",    value = "any"    },
    { name = "DD",     value = "damage" },
    { name = "Tank",   value = "tank"   },
    { name = "Healer", value = "healer" },
}

GF.otherChoices = {
    { name = "Infinite Archive", value = "archive" },
    { name = "PvP",              value = "pvp"     },
    { name = "Zone",             value = "zone"    },
    { name = "Custom",           value = "custom"  },
}

GF.alarmDungeonChoices = {}
GF.alarmTrialChoices   = {}
GF.alarmArenaChoices   = {}

local ALARM_ALL = "*all*"

local ALARM_LISTS = {
    { id = "GROUP_FINDER_CATEGORY_DUNGEON", key = "groupFinderAlarmDungeons", choices = GF.alarmDungeonChoices, all = "All Dungeons" },
    { id = "GROUP_FINDER_CATEGORY_TRIAL",   key = "groupFinderAlarmTrials",   choices = GF.alarmTrialChoices,   all = "All Trials"   },
    { id = "GROUP_FINDER_CATEGORY_ARENA",   key = "groupFinderAlarmArenas",   choices = GF.alarmArenaChoices,   all = "All Arenas"   },
}

local OTHER_CATEGORY_IDS = {
    archive = "GROUP_FINDER_CATEGORY_ENDLESS_DUNGEON",
    pvp     = "GROUP_FINDER_CATEGORY_PVP",
    zone    = "GROUP_FINDER_CATEGORY_ZONE",
    custom  = "GROUP_FINDER_CATEGORY_CUSTOM",
}

local OTHER_KEYS = {
    archive = "groupFinderArchive",
    pvp     = "groupFinderPvP",
    zone    = "groupFinderZone",
    custom  = "groupFinderCustom",
}

local SOUNDS_LIST = {
    { name = "Off",                  value = "off" },
    { name = "Ability Ready",        value = "abilityReady",        sound = "ABILITY_READY" },
    { name = "Achievement Awarded",  value = "achievementAwarded",  sound = "ACHIEVEMENT_AWARDED" },
    { name = "Alert Error",          value = "alertError",          sound = "GENERAL_ALERT_ERROR" },
    { name = "Champion Committed",   value = "championCommitted",   sound = "CHAMPION_POINTS_COMMITTED" },
    { name = "Collectible Unlocked", value = "collectibleUnlocked", sound = "COLLECTIBLE_UNLOCKED" },
    { name = "Duel Accepted",        value = "duelAccepted",        sound = "DUEL_ACCEPTED" },
    { name = "Duel Started",         value = "duelStart",           sound = "DUEL_START" },
    { name = "Justice Bonus",        value = "justiceBonus",        sound = "JUSTICE_PICKPOCKET_BONUS" },
    { name = "Level Up",             value = "levelUp",             sound = "LEVEL_UP" },
    { name = "Map Ping",             value = "mapPing",             sound = "MAP_PING" },
    { name = "New Notification",     value = "newNotification",     sound = "NEW_NOTIFICATION" },
    { name = "Objective Discovered", value = "objectiveDiscovered", sound = "OBJECTIVE_DISCOVERED" },
    { name = "Positive Click",       value = "positiveClick",       sound = "POSITIVE_CLICK" },
    { name = "Quest Complete",       value = "questComplete",       sound = "QUEST_COMPLETED" },
    { name = "Tel Var Gained",       value = "telVarGained",        sound = "TELVAR_GAINED" },
    { name = "Trial Completed",      value = "trialCompleted",      sound = "RAID_TRIAL_COMPLETED" },
    { name = "Ultimate Ready",       value = "ultimateReady",       sound = "ABILITY_ULTIMATE_READY" },
}
GF.soundChoices = {}
for i = 1, #SOUNDS_LIST do
    GF.soundChoices[i] = { name = SOUNDS_LIST[i].name, value = SOUNDS_LIST[i].value }
end

local PREVIEW_ROWS = {
    {
        key = "p1", categoryText = "Dungeon", primary = "Veteran", isVeteran = true,
        activity = "Lair of Maarselok", preferActivityTitle = true, title = "vLoM HM, need tank",
        leader = "@Player", description = "", supportsRoles = true,
        roles = { tank = 0, heal = 1, dps = 2 }, isNew = true,
    },
    {
        key = "p2", categoryText = "Trial", primary = "Veteran", isVeteran = true, minimumChampionPoints = 160,
        activity = "Sunspire", preferActivityTitle = true, title = "vSS prog",
        leader = "@Player", description = "Discord required", supportsRoles = true,
        roles = { tank = 2, heal = 1, dps = 5 }, isAlarm = true,
    },
    {
        key = "p3", categoryText = "Arena", primary = "Normal",
        activity = "Maelstrom Arena", preferActivityTitle = true, title = "",
        leader = "@Player", description = "Quick run", supportsRoles = false,
    },
}

GF.preview = false
GF.moving  = false

local ready          = false
local active         = false
local hooksInstalled = false
local startOnClose   = false
local paused         = false
local scanActive     = false
local stopRequested  = false
local scanPhase      = "idle"
local scanTasks      = {}
local baseTasks      = {}
local taskIndex      = 0
local scanRows       = {}
local previousRows   = {}
local sourceOrder    = {}
local alarmedKeys    = {}
local namesLoaded    = false
local scanConfig     = {}
local hadScan        = false
local publishedCount = 0
local rows           = {}
local savedFilters   = nil
local completedScan  = false
local scanFailed     = false
local timerQueued    = false
local nextScanAt     = nil
local renderQueued   = false
local statusTicking  = false
local rowControls    = {}

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return DT:Settings()
end

local function Now()
    return GetFrameTimeMilliseconds()
end

local function ClearTable(value)
    for key in pairs(value) do value[key] = nil end
end

local function ClearArray(value)
    for i = #value, 1, -1 do value[i] = nil end
end

local function Upper(text)
    return zo_strupper(tostring(text or ""))
end

local function Lower(text)
    return zo_strlower(tostring(text or ""))
end

local function Font(offset)
    local font = SV().groupFinderFont or DEFAULTS.groupFinderFont
    return string.format("%s|%d|soft-shadow-thin", font, BASE_SIZE + (offset or 0))
end

local function SampleFont()
    return string.format("%s|40|soft-shadow-thin", SV().groupFinderFont or DEFAULTS.groupFinderFont)
end

local function CategoryId(definition)
    return rawget(_G, definition.id)
end

local function CategoryName(category)
    return GetString("SI_GROUPFINDERCATEGORY", category)
end

local function ApiReady()
    return GROUP_FINDER_SEARCH_MANAGER ~= nil
        and type(SetGroupFinderFilterCategory) == "function"
        and type(GetGroupFinderSearchListingTitleByIndex) == "function"
end

local function PlayAlarm(value)
    value = value or SV().groupFinderAlarmSound
    for i = 1, #SOUNDS_LIST do
        local entry = SOUNDS_LIST[i]
        if entry.value == value then
            local sound = entry.sound and SOUNDS[entry.sound]
            if sound then PlaySound(sound) end
            return
        end
    end
end

local function IsOn()
    return SV().groupFinderShow == true
end

local function AccentColor()
    local sv = ME.savedVariables
    if sv and sv.settingsHighlight == "Custom" and type(sv.settingsHighlightColor) == "table" then
        local c = sv.settingsHighlightColor
        return { c.r or 1, c.g or 1, c.b or 1 }
    end
    local c = GetAllianceColor(GetUnitAlliance("player"))
    if c then return { c.r, c.g, c.b } end
    return { 1, 1, 1 }
end

local function CurrentSceneName()
    local scene = SCENE_MANAGER:GetCurrentScene()
    return scene and scene.GetName and scene:GetName() or nil
end

--------------------------------------------------
-- Group Finder
--------------------------------------------------
local function GroupFinderShowing()
    if GROUP_FINDER_GAMEPAD_FRAGMENT and GROUP_FINDER_GAMEPAD_FRAGMENT:IsShowing() then return true end
    if GROUP_FINDER_GAMEPAD_LIST_SCENE and GROUP_FINDER_GAMEPAD_LIST_SCENE:IsShowing() then return true end
    if GROUP_FINDER_KEYBOARD_FRAGMENT and GROUP_FINDER_KEYBOARD_FRAGMENT:IsShowing() then return true end
    local name = CurrentSceneName()
    return name == "GroupFinderGamepad" or name == "group_finder_gamepad_list"
end

local function DisabledInZone()
    return GetGroupFinderStatusReason ~= nil
        and GROUP_FINDER_ACTION_RESULT_FAILED_DISABLED_IN_ZONE ~= nil
        and GetGroupFinderStatusReason() == GROUP_FINDER_ACTION_RESULT_FAILED_DISABLED_IN_ZONE
end

local function CaptureFilters()
    local state = {
        category       = GetGroupFinderFilterCategory(),
        searchString   = GetGroupFinderGroupFilterSearchString(),
        primary        = {},
        secondary      = {},
        groupSizes     = GetGroupFinderFilterGroupSizes(),
        playstyles     = GetGroupFinderFilterPlaystyles(),
        champion       = DoesGroupFinderFilterRequireChampion(),
        voip           = DoesGroupFinderFilterRequireVOIP(),
        inviteCode     = DoesGroupFinderFilterRequireInviteCode(),
        autoAccept     = DoesGroupFinderFilterAutoAcceptRequests(),
        enforceRoles   = DoesGroupFinderFilterRequireEnforceRoles(),
        championPoints = GetGroupFinderFilterChampionPoints(),
    }
    for i = 1, GetGroupFinderFilterNumPrimaryOptions() do
        local _, selected = GetGroupFinderFilterPrimaryOptionByIndex(i)
        state.primary[i] = selected == true
    end
    for i = 1, GetGroupFinderFilterNumSecondaryOptions() do
        local _, selected = GetGroupFinderFilterSecondaryOptionByIndex(i)
        state.secondary[i] = selected == true
    end
    return state
end

local function ApplyFilters(state)
    if not state then return end
    SetGroupFinderFilterCategory(state.category, false)
    UpdateGroupFinderFilterOptions()
    SetGroupFinderGroupFilterSearchString(state.searchString or "")
    for i = 1, GetGroupFinderFilterNumPrimaryOptions() do
        SetGroupFinderFilterPrimaryOptionByIndex(i, state.primary[i] == true)
    end
    for i = 1, GetGroupFinderFilterNumSecondaryOptions() do
        SetGroupFinderFilterSecondaryOptionByIndex(i, state.secondary[i] == true)
    end
    SetGroupFinderFilterGroupSizeFlags(state.groupSizes or 0)
    SetGroupFinderFilterPlaystyleFlags(state.playstyles or 0)
    SetGroupFinderFilterRequiresChampion(state.champion == true)
    SetGroupFinderFilterRequiresVOIP(state.voip == true)
    SetGroupFinderFilterRequiresInviteCode(state.inviteCode == true)
    SetGroupFinderFilterAutoAcceptRequests(state.autoAccept == true)
    SetGroupFinderFilterEnforceRoles(state.enforceRoles == true)
    SetGroupFinderFilterChampionPoints(state.championPoints or 0)
end

local function BroadSearch(category)
    SetGroupFinderFilterCategory(category, false)
    UpdateGroupFinderFilterOptions()
    ResetGroupFinderFilterOptionsToDefault()
    SetGroupFinderGroupFilterSearchString("")
end

local function ClearSearchState()
    local manager = GROUP_FINDER_SEARCH_MANAGER
    if manager and manager.SetSearchState and ZO_GROUP_FINDER_SEARCH_STATES then
        manager:SetSearchState(ZO_GROUP_FINDER_SEARCH_STATES.NONE)
    end
end

local function CategoryCount()
    local sv, count = SV(), 0
    for i = 1, #CATEGORIES do
        local value = sv[CATEGORIES[i].key]
        if value == true or (CATEGORIES[i].modes and value ~= nil and value ~= "off" and value ~= false) then
            count = count + 1
        end
    end
    return count
end

local function RefreshDelay()
    local count = CategoryCount()
    if count == 0 then return nil end
    if count > 1 then return MANY_MS end
    return ONE_MS
end

local function BuildTasks(tasks)
    ClearArray(tasks)
    local sv = SV()
    for i = 1, #CATEGORIES do
        local definition = CATEGORIES[i]
        local category = CategoryId(definition)
        local value = sv[definition.key]
        local available = category ~= nil
            and (not IsGroupFinderCategoryAvailable or IsGroupFinderCategoryAvailable(category))
        if available and value ~= false and value ~= "off" and value ~= nil then
            if definition.modes then
                if value == "normal" or value == "all" then
                    tasks[#tasks + 1] = { category = category, primaryOption = DUNGEON_DIFFICULTY_NORMAL }
                end
                if value == "veteran" or value == "all" then
                    tasks[#tasks + 1] = { category = category, primaryOption = DUNGEON_DIFFICULTY_VETERAN }
                end
            elseif definition.expand then
                tasks[#tasks + 1] = { category = category, expandPrimary = true }
            else
                tasks[#tasks + 1] = { category = category }
            end
        end
    end
    return tasks
end

local function ExpandTasks(tasks, expanded)
    ClearArray(expanded)
    for i = 1, #tasks do
        local task = tasks[i]
        if task.expandPrimary then
            BroadSearch(task.category)
            local count = GetGroupFinderFilterNumPrimaryOptions()
            if count == 0 then
                expanded[#expanded + 1] = { category = task.category }
            else
                for option = 1, count do
                    expanded[#expanded + 1] = { category = task.category, primaryOption = option }
                end
            end
        else
            expanded[#expanded + 1] = task
        end
    end
    return expanded
end

local function PrepareTasks(tasks)
    ClearTable(sourceOrder)
    for i = 1, #tasks do
        local task = tasks[i]
        task.sourceKey = string.format("%s:%s", task.category, task.primaryOption or 0)
        task.sourceOrder = i
        sourceOrder[task.sourceKey] = i
    end
    local changed = false
    for i = #rows, 1, -1 do
        local row = rows[i]
        local order = sourceOrder[row.sourceKey]
        if order then
            row.sourceOrder = order
        else
            table.remove(rows, i)
            changed = true
        end
    end
    return changed
end

local function CleanText(value)
    local text = tostring(value or "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|c%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|t.-|t", "")
    text = text:gsub("|u.-|u", "")
    if EscapeMarkup then text = EscapeMarkup(text) end
    return text
end

local function PickList(value)
    local list = {}
    if type(value) == "table" then
        for i = 1, #value do
            if type(value[i]) == "string" and value[i] ~= "" then list[#list + 1] = value[i] end
        end
    end
    return list
end

local function UnnamedText(category)
    return Lower(CleanText(GetString("SI_GROUPFINDERCATEGORY_SINGLESELECTDEFAULT", category)))
end

local function BuildAlarmPicks(sv)
    local picks, other = {}, {}
    for i = 1, #ALARM_LISTS do
        local list = ALARM_LISTS[i]
        local category = rawget(_G, list.id)
        if category then
            local unnamed = UnnamedText(category)
            local set, count = {}, 0
            local names = PickList(sv[list.key])
            local cleaned, changed = {}, false
            for j = 1, #names do
                local name = names[j]
                if unnamed ~= "" and Lower(name) == unnamed then
                    name = ALARM_ALL
                    changed = true
                end
                if not set[Lower(name)] then
                    set[Lower(name)] = true
                    count = count + 1
                    cleaned[#cleaned + 1] = name
                end
            end
            if changed then sv[list.key] = cleaned end
            picks[category] = { names = set, count = count, unnamed = unnamed }
        end
    end
    local others = PickList(sv.groupFinderAlarmOther)
    for i = 1, #others do
        local category = rawget(_G, OTHER_CATEGORY_IDS[others[i]] or "")
        if category then other[category] = true end
    end
    return picks, other
end

local function MatchesAlarm(category, secondary)
    local picks = scanConfig.picks
    local pick = picks and picks[category]
    if pick then
        if pick.count == 0 then return false end
        if pick.names[ALARM_ALL] then return true end
        local name = Lower(secondary)
        if name == "" or name == pick.unnamed then return true end
        return pick.names[name] == true
    end
    return scanConfig.other ~= nil and scanConfig.other[category] == true
end

local function RoleCount(role, count)
    local texture = ZO_GetGamepadRoleIcon and ZO_GetGamepadRoleIcon(role)
    local icon = texture and zo_iconFormat(texture, ROLE_ICON, ROLE_ICON) or ""
    return icon .. count
end

local function RoleText(tank, heal, dps)
    return RoleCount(LFG_ROLE_TANK, tank) .. " " .. RoleCount(LFG_ROLE_HEAL, heal) .. " " .. RoleCount(LFG_ROLE_DPS, dps)
end

local ROLE_IDS = { damage = "LFG_ROLE_DPS", tank = "LFG_ROLE_TANK", healer = "LFG_ROLE_HEAL" }

local function RoleData(index, capacity, hasRoles, enforces, choice)
    if not hasRoles then return true, "" end
    local tankWant, tankCount = GetGroupFinderSearchListingRoleStatusCount(index, LFG_ROLE_TANK)
    local healWant, healCount = GetGroupFinderSearchListingRoleStatusCount(index, LFG_ROLE_HEAL)
    local dpsWant, dpsCount = GetGroupFinderSearchListingRoleStatusCount(index, LFG_ROLE_DPS)
    tankWant, tankCount = tonumber(tankWant) or 0, tonumber(tankCount) or 0
    healWant, healCount = tonumber(healWant) or 0, tonumber(healCount) or 0
    dpsWant, dpsCount = tonumber(dpsWant) or 0, tonumber(dpsCount) or 0
    local text = RoleText(tankCount, healCount, dpsCount)
    local role = ROLE_IDS[choice] and rawget(_G, ROLE_IDS[choice])
    if not role then return true, text end
    if tankCount + healCount + dpsCount >= capacity then return false, text end
    if not enforces then return true, text end
    local wanted, have = dpsWant, dpsCount
    if role == LFG_ROLE_TANK then
        wanted, have = tankWant, tankCount
    elseif role == LFG_ROLE_HEAL then
        wanted, have = healWant, healCount
    end
    return tankWant + healWant + dpsWant < capacity or wanted > have, text
end

local function LeaderChampionPoints(displayName)
    if displayName == "" then return 0 end
    local plain = UndecorateDisplayName and UndecorateDisplayName(displayName) or displayName
    local wanted = Lower(plain)
    for i = 1, GetNumFriends() do
        local friendName = GetFriendInfo(i)
        friendName = UndecorateDisplayName and UndecorateDisplayName(friendName) or friendName
        if Lower(friendName) == wanted then
            local hasCharacter, _, _, _, _, _, cp = GetFriendCharacterInfo(i)
            cp = tonumber(cp) or 0
            if hasCharacter and cp > 0 then return cp end
        end
    end
    for g = 1, GetNumGuilds() do
        local guildId = GetGuildId(g)
        local member = guildId and GetGuildMemberIndexFromDisplayName(guildId, displayName)
        if not member and guildId and plain ~= displayName then
            member = GetGuildMemberIndexFromDisplayName(guildId, plain)
        end
        if member then
            local hasCharacter, _, _, _, _, _, cp = GetGuildMemberCharacterInfo(guildId, member)
            cp = tonumber(cp) or 0
            if hasCharacter and cp > 0 then return cp end
        end
    end
    return 0
end

local function LoadActivityNames()
    if namesLoaded or scanActive or GroupFinderShowing() then return end
    local ok, saved = pcall(CaptureFilters)
    if not ok then return end
    local found = 0
    for i = 1, #ALARM_LISTS do
        local list = ALARM_LISTS[i]
        local category = rawget(_G, list.id)
        ClearArray(list.choices)
        if category then
            list.choices[1] = { name = list.all, value = ALARM_ALL }
            local unnamed = UnnamedText(category)
            local loaded = pcall(function()
                BroadSearch(category)
                for option = 1, GetGroupFinderFilterNumSecondaryOptions() do
                    local name = CleanText(GetGroupFinderFilterSecondaryOptionByIndex(option))
                    if name ~= "" and Lower(name) ~= unnamed then
                        list.choices[#list.choices + 1] = { name = name, value = name }
                    end
                end
            end)
            if loaded then found = found + #list.choices - 1 end
        end
    end
    pcall(ApplyFilters, saved)
    namesLoaded = found > 0
end

local function CaptureResults(task)
    local results = GROUP_FINDER_SEARCH_MANAGER:GetSearchResults() or {}
    for _, data in ipairs(results) do
        local index = data.listingIndex
        local primary, secondary = GetGroupFinderSearchListingOptionsSelectionTextByIndex(index)
        local category = GetGroupFinderSearchListingCategoryByIndex(index)
        local title = CleanText(GetGroupFinderSearchListingTitleByIndex(index))
        local description = CleanText(GetGroupFinderSearchListingDescriptionByIndex(index))
        local rawLeader = CleanText(GetGroupFinderSearchListingLeaderDisplayNameByIndex(index))
        local leaderCp = LeaderChampionPoints(rawLeader)
        local leader = rawLeader
        if ZO_FormatUserFacingDisplayName then leader = ZO_FormatUserFacingDisplayName(leader) end
        if leader ~= "" and leader:sub(1, 1) ~= "@" then leader = "@" .. leader end
        primary = CleanText(primary)
        secondary = CleanText(secondary)
        local categoryText = CategoryName(category)
        local activity = secondary ~= "" and secondary or (title ~= "" and title or categoryText)
        local preferActivity = category == GROUP_FINDER_CATEGORY_DUNGEON
            or category == GROUP_FINDER_CATEGORY_TRIAL
            or category == GROUP_FINDER_CATEGORY_ARENA
        local capacity = tonumber(GetGroupFinderSearchListingNumRolesByIndex(index)) or 0
        local hasRoles = capacity > 0
        local enforces = hasRoles and DoesGroupFinderSearchListingEnforceRoles(index) == true
        local hasSpace, roleText = RoleData(index, capacity, hasRoles, enforces, scanConfig.role)
        if hasSpace then
            local minimumCp = 0
            if category == GROUP_FINDER_CATEGORY_TRIAL and DoesGroupFinderSearchListingRequireChampion(index) then
                minimumCp = tonumber(GetGroupFinderSearchListingChampionPointsByIndex(index)) or 0
            end
            scanRows[#scanRows + 1] = {
                key                   = string.format("%s\31%s\31%s\31%s\31%s\31%s", category, primary, secondary, leader, title, description),
                sourceKey             = task.sourceKey,
                sourceOrder           = task.sourceOrder,
                categoryText          = categoryText,
                primary               = primary,
                activity              = activity,
                preferActivityTitle   = preferActivity,
                title                 = title,
                leader                = leader,
                leaderChampionPoints  = leaderCp,
                minimumChampionPoints = minimumCp,
                description           = description,
                supportsRoles         = hasRoles,
                roleText              = roleText,
                category              = category,
                secondary             = secondary,
                isAlarm               = scanConfig.alarm and MatchesAlarm(category, secondary),
                isVeteran             = primary ~= "" and primary == scanConfig.veteranText,
            }
        end
    end
end

--------------------------------------------------
-- Scan
--------------------------------------------------
local ScheduleNextScan, StopTimer, OnSearchTimeout, RunNextTask, BeginRestore

local function PublishRows(task)
    local alarm = false
    local first = publishedCount + 1
    for i = first, #scanRows do
        local row = scanRows[i]
        local previous = previousRows[row.key]
        row.isNew = hadScan and previous == nil
        if row.isAlarm and (not previous or not previous.isAlarm) and not alarmedKeys[row.key] then
            alarmedKeys[row.key] = true
            alarm = true
        end
    end
    local insertAt
    for i = #rows, 1, -1 do
        if rows[i].sourceKey == task.sourceKey then
            insertAt = i
            table.remove(rows, i)
        end
    end
    if not insertAt then
        insertAt = #rows + 1
        for i, row in ipairs(rows) do
            if (row.sourceOrder or math.huge) > task.sourceOrder then
                insertAt = i
                break
            end
        end
    end
    for i = first, #scanRows do
        table.insert(rows, insertAt, scanRows[i])
        insertAt = insertAt + 1
    end
    publishedCount = #scanRows
    if alarm then PlayAlarm(scanConfig.sound) end
    GF:QueueRender()
end

local function StopTimeout()
    EVENT_MANAGER:UnregisterForUpdate(TIMEOUT_NAME)
end

local function StartTimeout()
    StopTimeout()
    EVENT_MANAGER:RegisterForUpdate(TIMEOUT_NAME, SEARCH_WAIT_MS, function()
        StopTimeout()
        OnSearchTimeout()
    end)
end

local function ResetScan()
    ClearArray(scanRows)
    scanActive = false
    stopRequested = false
    scanPhase = "idle"
    ClearArray(scanTasks)
    ClearArray(baseTasks)
    taskIndex = 0
    ClearTable(previousRows)
    ClearTable(sourceOrder)
    ClearTable(alarmedKeys)
    ClearTable(scanConfig)
    hadScan = false
    publishedCount = 0
    savedFilters = nil
    scanFailed = false
end

local function FinishScan(commit)
    StopTimeout()
    if commit then
        ClearArray(scanRows)
        completedScan = true
    end
    ResetScan()
    GF:QueueRender()
    if IsOn() then ScheduleNextScan(RefreshDelay()) end
end

local function RunSearch()
    StopTimeout()
    local manager = GROUP_FINDER_SEARCH_MANAGER
    if not (manager and manager.ExecuteSearch) then return false end
    manager:ExecuteSearch()
    local state = manager:GetSearchState()
    local pending = state == ZO_GROUP_FINDER_SEARCH_STATES.WAITING or state == ZO_GROUP_FINDER_SEARCH_STATES.QUEUED
    if pending then StartTimeout() end
    return pending
end

BeginRestore = function()
    if not scanActive then return end
    scanPhase = "restore"
    GF:QueueStatus()
    ApplyFilters(savedFilters)
    if not RunSearch() then FinishScan(false) end
end

RunNextTask = function()
    if not scanActive then return end
    if stopRequested then BeginRestore() return end
    taskIndex = taskIndex + 1
    local task = scanTasks[taskIndex]
    if not task then BeginRestore() return end
    scanPhase = "monitor"
    GF:QueueStatus()
    BroadSearch(task.category)
    if task.primaryOption then SetGroupFinderFilterPrimaryOptionByIndex(task.primaryOption, true) end
    if not RunSearch() then
        scanFailed = true
        BeginRestore()
    end
end

OnSearchTimeout = function()
    if not scanActive then return end
    local phase = scanPhase
    scanPhase = "timeout"
    ClearSearchState()
    if phase == "monitor" then
        zo_callLater(function()
            if scanActive and scanPhase == "timeout" then RunNextTask() end
        end, 0)
    elseif phase == "restore" then
        FinishScan(not stopRequested and not scanFailed)
    end
end

local function OnResultsReady()
    if not scanActive or scanPhase == "timeout" then return end
    StopTimeout()
    if scanPhase == "restore" then
        FinishScan(not stopRequested and not scanFailed)
        return
    end
    local task = scanTasks[taskIndex]
    if task then
        CaptureResults(task)
        PublishRows(task)
    end
    zo_callLater(RunNextTask, 0)
end

local function TryStartScan()
    local sv = SV()
    if not IsOn() or paused or scanActive or GroupFinderShowing() then return false end
    if HasGroupListingForUserType and GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING
        and HasGroupListingForUserType(GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING) then
        return false
    end
    local manager = GROUP_FINDER_SEARCH_MANAGER
    if not (manager and manager.IsSearchStateReady and manager:IsSearchStateReady()) then return false end
    BuildTasks(baseTasks)
    if #baseTasks == 0 then
        if #rows > 0 then ClearArray(rows) end
        GF:QueueRender()
        return false
    end
    UpdateGroupFinderFilterOptions()
    savedFilters = CaptureFilters()
    ExpandTasks(baseTasks, scanTasks)
    local changed = PrepareTasks(scanTasks)
    taskIndex = 0
    ClearTable(previousRows)
    for _, row in ipairs(rows) do previousRows[row.key] = row end
    ClearTable(alarmedKeys)
    scanConfig.role = sv.groupFinderRole
    scanConfig.alarm = sv.groupFinderAlarm == true
    scanConfig.sound = sv.groupFinderAlarmSound
    scanConfig.veteranText = GetString("SI_DUNGEONDIFFICULTY", DUNGEON_DIFFICULTY_VETERAN)
    scanConfig.picks, scanConfig.other = BuildAlarmPicks(sv)
    hadScan = completedScan
    ClearArray(scanRows)
    publishedCount = 0
    scanFailed = false
    stopRequested = false
    scanActive = true
    StopTimer()
    if changed then GF:QueueRender() else GF:QueueStatus() end
    RunNextTask()
    return true
end

StopTimer = function()
    EVENT_MANAGER:UnregisterForUpdate(TIMER_NAME)
    timerQueued = false
    nextScanAt = nil
end

ScheduleNextScan = function(delay)
    StopTimer()
    if not delay or not IsOn() or paused or scanActive then return end
    timerQueued = true
    nextScanAt = Now() + delay
    EVENT_MANAGER:RegisterForUpdate(TIMER_NAME, delay, function()
        StopTimer()
        if not TryStartScan() and IsOn() and not scanActive then
            ScheduleNextScan(RefreshDelay())
        end
    end)
end

local function StartTimer(immediate)
    if scanActive or timerQueued then return end
    local delay = RefreshDelay()
    if not delay then StopTimer() return end
    ScheduleNextScan(immediate and 250 or delay)
end

local function AbortScan(searchAgain)
    StopTimeout()
    local filters = savedFilters
    ResetScan()
    if filters then
        ApplyFilters(filters)
        ClearSearchState()
        if searchAgain then
            local manager = GROUP_FINDER_SEARCH_MANAGER
            if manager and manager.ExecuteSearch then manager:ExecuteSearch() end
        end
    end
end

local function StopMonitoring()
    StopTimer()
    if scanActive then AbortScan(false) end
    StopTimeout()
    GF:QueueRender()
end

local function RefreshCategories()
    if not IsOn() then return end
    local delay = RefreshDelay()
    if not delay then
        StopMonitoring()
        ClearArray(rows)
        completedScan = false
        GF:QueueRender()
        return
    end
    if not scanActive and not TryStartScan() then ScheduleNextScan(delay) end
    GF:QueueStatus()
end

local function RecolorRows()
    local sv = SV()
    scanConfig.alarm = sv.groupFinderAlarm == true
    scanConfig.picks, scanConfig.other = BuildAlarmPicks(sv)
    for _, row in ipairs(rows) do
        if row.category ~= nil then
            row.isAlarm = scanConfig.alarm and MatchesAlarm(row.category, row.secondary or "")
            if row.isAlarm then alarmedKeys[row.key] = true end
        end
    end
    GF:QueueRender()
end

local function RescanSoon()
    if IsOn() and not scanActive then TryStartScan() end
    GF:QueueStatus()
end

local function PauseForZone()
    StopTimer()
    if scanActive then AbortScan(false) end
    StopTimeout()
    ClearArray(rows)
    completedScan = false
    GF:QueueRender()
end

--------------------------------------------------
-- Events
--------------------------------------------------
local function OnSceneChanged()
    if active then
        if GroupFinderShowing() then
            StopTimer()
            if scanActive then AbortScan(true) end
        elseif not scanActive then
            if startOnClose then
                startOnClose = false
                StopTimer()
                StartTimer(true)
            else
                StartTimer(false)
            end
        end
    end
    GF:QueueRender()
end

local function OnGroupJoined(_, _, _, isLocalPlayer)
    if isLocalPlayer == true and IsOn() and SV().groupFinderCloseOnJoin == true then
        GF:SetEnabled(false)
    end
end

local function OnStatusChanged()
    local disabled = DisabledInZone() == true
    local wasPaused = paused
    paused = disabled
    if not active then return end
    if disabled then
        PauseForZone()
    elseif wasPaused then
        StopTimer()
        StartTimer(true)
        GF:QueueRender()
    end
end

function GF:Activate(on, immediate)
    if on == active then
        if on then StartTimer(immediate) end
        return
    end
    active = on
    if on then
        GROUP_FINDER_SEARCH_MANAGER:RegisterCallback("OnGroupFinderSearchResultsReady", OnResultsReady)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_GROUP_MEMBER_JOINED, OnGroupJoined)
        if EVENT_GROUP_FINDER_STATUS_UPDATED then
            EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_GROUP_FINDER_STATUS_UPDATED, OnStatusChanged)
        end
        OnStatusChanged()
        StartTimer(immediate)
    else
        startOnClose = false
        StopMonitoring()
        GROUP_FINDER_SEARCH_MANAGER:UnregisterCallback("OnGroupFinderSearchResultsReady", OnResultsReady)
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_GROUP_MEMBER_JOINED)
        if EVENT_GROUP_FINDER_STATUS_UPDATED then
            EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_GROUP_FINDER_STATUS_UPDATED)
        end
    end
end

function GF:SetEnabled(value)
    SV().groupFinderShow = value == true
    self:Refresh(value == true)
    local panel = ME.settingsPanel
    if panel and panel.Refresh then pcall(panel.Refresh, panel) end
end

function GF:EnableFromGroupFinder()
    startOnClose = true
    self:SetEnabled(true)
    SCENE_MANAGER:ShowBaseScene()
end

--------------------------------------------------
-- Monitor Button
--------------------------------------------------
local function MonitorKeybind()
    local descriptor = {
        alignment           = KEYBIND_STRIP_ALIGN_LEFT,
        keybind             = "UI_SHORTCUT_RIGHT_STICK",
        sound               = SOUNDS.GAMEPAD_MENU_FORWARD,
        myExtrasGroupFinder = true,
    }
    descriptor.name = function()
        if IsOn() then return "Stop Monitor" end
        return "Monitor"
    end
    descriptor.callback = function()
        if IsOn() then
            GF:SetEnabled(false)
        else
            GF:EnableFromGroupFinder()
        end
        if KEYBIND_STRIP.UpdateKeybindButton then KEYBIND_STRIP:UpdateKeybindButton(descriptor) end
    end
    return descriptor
end

local function RebuildGroup(descriptor, change)
    local wasActive = KEYBIND_STRIP.HasKeybindButtonGroup and KEYBIND_STRIP:HasKeybindButtonGroup(descriptor)
    if wasActive then KEYBIND_STRIP:RemoveKeybindButtonGroup(descriptor) end
    change()
    if wasActive then KEYBIND_STRIP:AddKeybindButtonGroup(descriptor) end
end

local function AddOuterKeybind(groupFinder)
    local descriptor = groupFinder and groupFinder.keybindStripDescriptor
    if not descriptor then return end
    for _, keybind in ipairs(descriptor) do
        if keybind.myExtrasGroupFinder then return end
    end
    RebuildGroup(descriptor, function()
        local keybind = MonitorKeybind()
        keybind.visible = function()
            return ZO_GROUP_FINDER_MODES ~= nil and groupFinder.mode == ZO_GROUP_FINDER_MODES.SEARCH
        end
        descriptor[#descriptor + 1] = keybind
    end)
end

local function AddResultsKeybind(resultsList)
    if not resultsList or resultsList.myExtrasGroupFinder then return end
    local areas = { resultsList.panelFocalArea, resultsList.filtersFocalArea, resultsList.appliedToListingArea }
    local shown = {}
    for _, area in ipairs(areas) do
        local descriptor = area and area.keybindDescriptor
        if descriptor and KEYBIND_STRIP.HasKeybindButtonGroup and KEYBIND_STRIP:HasKeybindButtonGroup(descriptor) then
            shown[#shown + 1] = descriptor
            KEYBIND_STRIP:RemoveKeybindButtonGroup(descriptor)
        end
    end
    for _, area in ipairs(areas) do
        local descriptor = area and area.keybindDescriptor
        if descriptor then
            for _, keybind in ipairs(descriptor) do
                if keybind.keybind == "UI_SHORTCUT_RIGHT_STICK" then keybind.keybind = "UI_SHORTCUT_LEFT_STICK" end
            end
        end
    end
    if resultsList.AddUniversalKeybind then resultsList:AddUniversalKeybind(MonitorKeybind()) end
    resultsList.myExtrasGroupFinder = true
    for _, descriptor in ipairs(shown) do
        KEYBIND_STRIP:AddKeybindButtonGroup(descriptor)
    end
end

local function InstallKeybinds()
    AddOuterKeybind(rawget(_G, "GROUP_FINDER_GAMEPAD"))
    local resultsScreen = rawget(_G, "GROUP_FINDER_SEARCH_RESULTS_LIST_SCREEN_GAMEPAD")
    AddResultsKeybind(resultsScreen and resultsScreen.resultsList)
    if hooksInstalled then return end
    hooksInstalled = true
    if ZO_GroupFinder_Gamepad then
        SecurePostHook(ZO_GroupFinder_Gamepad, "InitializeControls", AddOuterKeybind)
    end
    if ZO_GroupFinder_SearchResultsList_Gamepad then
        SecurePostHook(ZO_GroupFinder_SearchResultsList_Gamepad, "InitializeKeybinds", AddResultsKeybind)
    end
end

--------------------------------------------------
-- Panel
--------------------------------------------------
local function CreateLabel(parent, align)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetDrawLevel(6)
    return label
end

function GF:CreatePanel()
    local panel = WINDOW_MANAGER:CreateTopLevelWindow("MyExtras_GroupFinderPanel")
    panel:SetDrawLayer(DL_BACKGROUND)
    panel:SetDrawTier(DT_LOW)
    panel:SetMouseEnabled(false)
    panel:SetDimensions(10, 10)
    panel:SetHidden(true)
    self.panel = panel

    local frame = WINDOW_MANAGER:CreateControl("MyExtras_GroupFinderFrame", panel, CT_CONTROL)
    frame:SetAnchor(TOP, panel, TOP, 0, 0)
    self.frame = frame

    local box = ME:CreateRoundBox("MyExtras_GroupFinderBox", frame, 0)
    box.control:SetAnchorFill(frame)
    box:SetCorner(BOX_CORNER)
    self.box = box

    self.title = CreateLabel(frame)
    self.count = CreateLabel(frame, TEXT_ALIGN_RIGHT)
    self.status = CreateLabel(frame)
    self.empty = CreateLabel(frame, TEXT_ALIGN_CENTER)

    local divider = WINDOW_MANAGER:CreateControl(nil, frame, CT_TEXTURE)
    divider:SetTexture(WHITE_TEXTURE)
    divider:SetDrawLevel(2)
    self.divider = divider
end

local function GetRowControl(index)
    if rowControls[index] then return rowControls[index] end
    local frame = GF.frame
    local row = {}
    row.control = WINDOW_MANAGER:CreateControl(nil, frame, CT_CONTROL)
    row.box = ME:CreateRoundBox("MyExtras_GroupFinderRow" .. index, row.control, 3)
    row.box.control:SetAnchorFill(row.control)
    row.box:SetCorner(ROW_CORNER)
    row.eyebrow = CreateLabel(row.control)
    row.activity = CreateLabel(row.control)
    row.details = CreateLabel(row.control)
    row.population = CreateLabel(row.control, TEXT_ALIGN_RIGHT)
    row.newBadge = CreateLabel(row.control, TEXT_ALIGN_RIGHT)
    rowControls[index] = row
    return row
end

local function HideRows(first)
    for i = first, #rowControls do rowControls[i].control:SetHidden(true) end
end

local function RowAccent(data)
    if data.isAlarm then return ALARM_COLOR end
    if data.isVeteran then return VETERAN_COLOR end
    if data.primary ~= "" then return AccentColor() end
    return OTHER_COLOR
end

local function ChampionText(cp)
    cp = zo_floor(tonumber(cp) or 0)
    if cp <= 0 then return "" end
    local icon = ""
    if ZO_GetChampionIconMarkupStringInheritColor then
        icon = ZO_GetChampionIconMarkupStringInheritColor("100%")
    elseif ZO_GetChampionIconMarkupString then
        icon = ZO_GetChampionIconMarkupString("100%")
    end
    return icon .. cp
end

local function RenderRow(row, data, width, y)
    local accent = RowAccent(data)
    row.control:ClearAnchors()
    row.control:SetAnchor(TOPLEFT, GF.frame, TOPLEFT, PADDING, y)
    row.control:SetDimensions(width - PADDING * 2, ROW_HEIGHT)
    if data.isAlarm then
        row.box:SetFillColor(0.46, 0.025, 0.025, 0.92)
        row.box:SetEdgeColor(ALARM_COLOR[1], ALARM_COLOR[2], ALARM_COLOR[3], 0.9)
    else
        row.box:SetFillColor(0.035, 0.075, 0.11, 0.78)
        row.box:SetEdgeColor(accent[1], accent[2], accent[3], 0.55)
    end

    local inner = width - PADDING * 2 - 24
    local eyebrow = Upper(data.categoryText)
    if data.primary ~= "" and data.primary ~= data.categoryText then
        local primary = Upper(data.primary)
        local cp = ChampionText(data.minimumChampionPoints)
        if cp ~= "" then primary = primary .. "  •  " .. cp end
        eyebrow = eyebrow .. "  •  " .. primary
    end
    row.eyebrow:SetFont(Font(-9))
    row.eyebrow:SetText(eyebrow)
    row.eyebrow:SetColor(accent[1], accent[2], accent[3], 0.92)
    row.eyebrow:ClearAnchors()
    row.eyebrow:SetAnchor(TOPLEFT, row.control, TOPLEFT, 14, 4)
    row.eyebrow:SetDimensions(inner - 76, 18)

    local shownTitle = data.preferActivityTitle and data.activity or (data.title ~= "" and data.title or data.activity)
    local textWidth = inner - (data.supportsRoles and (ROLE_WIDTH + 8) or 0)
    row.activity:SetFont(Font(0))
    row.activity:SetText(shownTitle)
    row.activity:SetColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], 1)
    row.activity:ClearAnchors()
    row.activity:SetAnchor(TOPLEFT, row.control, TOPLEFT, 14, 20)
    row.activity:SetDimensions(textWidth, 28)

    local details = ""
    if data.description ~= "" then
        details = data.description
    elseif data.preferActivityTitle and data.title ~= "" and data.title ~= shownTitle then
        details = data.title
    elseif data.title ~= "" and data.activity ~= data.title then
        details = data.activity
    end
    if data.leader and data.leader ~= "" then
        local leader = data.leader
        local cp = ChampionText(data.leaderChampionPoints)
        if cp ~= "" then leader = leader .. " " .. cp end
        details = details ~= "" and (leader .. " · " .. details) or leader
    end
    row.details:SetFont(Font(-8))
    row.details:SetText(details)
    row.details:SetColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], 0.66)
    row.details:ClearAnchors()
    row.details:SetAnchor(BOTTOMLEFT, row.control, BOTTOMLEFT, 14, -5)
    row.details:SetDimensions(textWidth, 20)

    row.population:SetFont(Font(-7))
    row.population:SetText(data.roleText or "")
    row.population:SetColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], 0.88)
    row.population:ClearAnchors()
    row.population:SetAnchor(RIGHT, row.control, RIGHT, -10, 1)
    row.population:SetDimensions(ROLE_WIDTH, 26)
    row.population:SetHidden(not data.supportsRoles)

    row.newBadge:SetFont(Font(-10))
    row.newBadge:SetText(data.isNew and "NEW" or "")
    row.newBadge:SetColor(NEW_COLOR[1], NEW_COLOR[2], NEW_COLOR[3], 1)
    row.newBadge:ClearAnchors()
    row.newBadge:SetAnchor(TOPRIGHT, row.control, TOPRIGHT, -10, 4)
    row.newBadge:SetDimensions(58, 18)
    row.control:SetHidden(false)
end

local function PreviewData()
    local list = {}
    for i = 1, #PREVIEW_ROWS do
        local data = PREVIEW_ROWS[i]
        local copy = {}
        for k, v in pairs(data) do copy[k] = v end
        if data.roles then copy.roleText = RoleText(data.roles.tank, data.roles.heal, data.roles.dps) end
        list[i] = copy
    end
    return list
end

local function ShowingPreview()
    return GF.preview or GF.moving
end

function GF:StatusText()
    if ShowingPreview() then
        local accent = AccentColor()
        return "Preview", accent[1], accent[2], accent[3]
    elseif paused or CategoryCount() == 0 or (not scanActive and not completedScan) then
        return "Paused", 0.82, 0.57, 0.24
    elseif scanActive then
        if scanPhase == "monitor" then
            local task = scanTasks[taskIndex]
            if task then return "Checking " .. CategoryName(task.category) .. "...", 1, 0.67, 0.22 end
        end
        return "Restoring your filters...", 1, 0.67, 0.22
    end
    if timerQueued and nextScanAt then
        local seconds = zo_max(math.ceil((nextScanAt - Now()) / 1000), 0)
        return string.format("Live  •  %d:%02d", zo_floor(seconds / 60), seconds % 60), 0.39, 0.92, 0.55
    end
    return "Live", 0.39, 0.92, 0.55
end

function GF:EmptyText()
    if paused then
        return "Paused"
    elseif CategoryCount() == 0 then
        return "Pick at least one category."
    elseif scanActive and scanPhase ~= "monitor" then
        return "Restoring your filters..."
    elseif scanActive then
        return "Checking the Group Finder..."
    end
    return "No matching groups found."
end

function GF:RefreshStatus()
    if not self.panel or self.panel:IsHidden() then return end
    local text, r, g, b = self:StatusText()
    self.status:SetText(Upper(text))
    self.status:SetColor(r, g, b, 0.92)
    if not self.empty:IsHidden() then self.empty:SetText(self:EmptyText()) end
end

function GF:ApplyBox()
    if not self.box then return end
    local sv = SV()
    local show = sv.groupFinderBackground == true
    self.box:SetHidden(not show)
    if not show then return end
    local opacity = tonumber(sv.groupFinderBackgroundOpacity) or DEFAULTS.groupFinderBackgroundOpacity
    self.box:SetFillColor(0.018, 0.035, 0.052, opacity / 100)
end

function GF:ApplyPosition()
    if not self.panel then return end
    local sv = SV()
    self.panel:ClearAnchors()
    self.panel:SetAnchor(TOP, GuiRoot, CENTER, sv.groupFinderPosX, sv.groupFinderPosY)
end

function GF:Render()
    if not self.panel then return end
    if not self:ShouldShow() then
        self.panel:SetHidden(true)
        self:UpdateTicking()
        return
    end

    local sv = SV()
    local screenW, screenH = GuiRoot:GetDimensions()
    local scale = zo_clamp(tonumber(sv.groupFinderScale) or DEFAULTS.groupFinderScale, SCALE_MIN, SCALE_MAX) / 100
    local width = zo_min(zo_clamp(tonumber(sv.groupFinderWidth) or DEFAULTS.groupFinderWidth, WIDTH_MIN, WIDTH_MAX),
        zo_floor(screenW * 0.88 / scale))
    local available = zo_floor(screenH * 0.86 / scale) - HEADER_HEIGHT - PADDING * 2
    local screenRows = zo_max(zo_floor((available + ROW_GAP) / (ROW_HEIGHT + ROW_GAP)), 2)
    local data = ShowingPreview() and PreviewData() or rows
    local maxRows = zo_clamp(tonumber(sv.groupFinderRows) or DEFAULTS.groupFinderRows, ROWS_MIN, ROWS_MAX)
    local visible = zo_min(#data, maxRows, screenRows)
    local contentRows = zo_max(visible, 1)
    local height = PADDING + HEADER_HEIGHT + contentRows * ROW_HEIGHT + (contentRows - 1) * ROW_GAP + PADDING

    self.frame:SetScale(scale)
    self.frame:SetDimensions(width, height)
    self.panel:SetDimensions(width * scale, height * scale)
    self:ApplyBox()

    self.title:SetFont(Font(3))
    self.title:SetText("GROUP FINDER")
    local accent = AccentColor()
    self.title:SetColor(accent[1], accent[2], accent[3], 1)
    self.title:ClearAnchors()
    self.title:SetAnchor(TOPLEFT, self.frame, TOPLEFT, PADDING, PADDING + 2)
    self.title:SetDimensions(width * 0.58, 30)

    self.count:SetFont(Font(-8))
    self.count:SetText(#data == 1 and "1 listing" or (#data .. " listings"))
    self.count:SetColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], 0.62)
    self.count:ClearAnchors()
    self.count:SetAnchor(TOPRIGHT, self.frame, TOPRIGHT, -PADDING, PADDING + 5)
    self.count:SetDimensions(width * 0.46, 22)

    self.status:SetFont(Font(-10))
    self.status:ClearAnchors()
    self.status:SetAnchor(TOPLEFT, self.frame, TOPLEFT, PADDING, PADDING + 33)
    self.status:SetDimensions(width - PADDING * 2, 20)

    self.divider:SetColor(accent[1], accent[2], accent[3], 0.24)
    self.divider:ClearAnchors()
    self.divider:SetAnchor(TOPLEFT, self.frame, TOPLEFT, PADDING, PADDING + HEADER_HEIGHT - 7)
    self.divider:SetDimensions(width - PADDING * 2, 1)

    local top = PADDING + HEADER_HEIGHT
    if visible == 0 then
        self.empty:SetFont(Font(-3))
        self.empty:SetColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], 0.68)
        self.empty:ClearAnchors()
        self.empty:SetAnchor(TOP, self.frame, TOP, 0, top)
        self.empty:SetDimensions(width - PADDING * 2 - 24, ROW_HEIGHT)
        self.empty:SetHidden(false)
        self.empty:SetText(self:EmptyText())
        HideRows(1)
    else
        self.empty:SetHidden(true)
        for i = 1, visible do
            RenderRow(GetRowControl(i), data[i], width, top + (i - 1) * (ROW_HEIGHT + ROW_GAP))
        end
        HideRows(visible + 1)
    end

    self.panel:SetHidden(false)
    self:RefreshStatus()
    self:UpdateTicking()
end

function GF:QueueRender()
    if renderQueued then return end
    renderQueued = true
    zo_callLater(function()
        renderQueued = false
        GF:Render()
    end, 0)
end

function GF:QueueStatus()
    if renderQueued then return end
    zo_callLater(function()
        if not renderQueued then GF:RefreshStatus() end
    end, 0)
end

function GF:UpdateTicking()
    local tick = self.panel ~= nil and not self.panel:IsHidden()
    if tick == statusTicking then return end
    statusTicking = tick
    if tick then
        EVENT_MANAGER:RegisterForUpdate(STATUS_NAME, STATUS_MS, function() GF:RefreshStatus() end)
    else
        EVENT_MANAGER:UnregisterForUpdate(STATUS_NAME)
    end
end

--------------------------------------------------
-- Visibility
--------------------------------------------------
function GF:ShouldShow()
    if ShowingPreview() then return true end
    if not IsOn() then return false end
    if ME.placing == true then return true end
    return GAMEPLAY_SCENES[CurrentSceneName() or ""] == true
end

function GF:OnPlacing()
    self:QueueRender()
end

function GF:SetPreview(value)
    self.preview = value == true
    self:Render()
end

function GF:Refresh(immediate)
    if not ready then return end
    self:Activate(IsOn(), immediate)
    self:ApplyPosition()
    self:Render()
end

--------------------------------------------------
-- Move
--------------------------------------------------
GF.mover = {}

function GF.mover:UpdateDirectionalInput(deltaS)
    local x, y = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    if x ~= 0 or y ~= 0 then
        GF:SetPosition(GF.moveX + x * MOVE_SPEED * deltaS, GF.moveY - y * MOVE_SPEED * deltaS)
    end
    local spreadX, scaleY = DIRECTIONAL_INPUT:GetXY(ZO_DI_RIGHT_STICK)
    if math.abs(spreadX) > math.abs(scaleY) then
        GF:SetSpread(GF.moveSpread + spreadX * SPREAD_SPEED * deltaS)
    elseif scaleY ~= 0 then
        GF:SetScale(GF.moveScale + scaleY * SCALE_SPEED * deltaS)
    end
end

GF.moveKeybinds = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    {
        name     = "Save",
        keybind  = "UI_SHORTCUT_PRIMARY",
        callback = function() GF:EndMove(true) end,
    },
    {
        name     = "Default",
        keybind  = "UI_SHORTCUT_TERTIARY",
        callback = function() GF:MoveToDefault() end,
    },
    {
        name     = "Cancel",
        keybind  = "UI_SHORTCUT_NEGATIVE",
        callback = function() GF:EndMove(false) end,
    },
}

function GF:SetPosition(x, y)
    local screenW, screenH = GuiRoot:GetDimensions()
    local halfW, halfH = screenW / 2, screenH / 2
    self.moveX = zo_clamp(x, -halfW, halfW)
    self.moveY = zo_clamp(y, -halfH, halfH)
    local sv = SV()
    sv.groupFinderPosX = zo_floor(self.moveX + 0.5)
    sv.groupFinderPosY = zo_floor(self.moveY + 0.5)
    self:ApplyPosition()
end

function GF:SetScale(value)
    self.moveScale = zo_clamp(value, SCALE_MIN, SCALE_MAX)
    local rounded = zo_floor(self.moveScale + 0.5)
    local sv = SV()
    if sv.groupFinderScale ~= rounded then
        sv.groupFinderScale = rounded
        self:Render()
    end
end

function GF:SetSpread(value)
    self.moveSpread = zo_clamp(value, SPREAD_MIN, SPREAD_MAX)
    local rounded = zo_floor(self.moveSpread + 0.5)
    local sv = SV()
    if sv.groupFinderWidth ~= rounded then
        sv.groupFinderWidth = rounded
        self:Render()
    end
end

function GF:MoveToDefault()
    self:SetSpread(DEFAULTS.groupFinderWidth)
    self:SetScale(DEFAULTS.groupFinderScale)
    self:SetPosition(DEFAULTS.groupFinderPosX, DEFAULTS.groupFinderPosY)
end

function GF:GetMoveScene()
    if self.moveScene then return self.moveScene end
    local scene = ZO_Scene:New(MOVE_SCENE, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_NO_KEYBIND_BACKGROUND_WINDOW)
    ME:AddPlacementFragments(scene)
    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            GF:OnMoveShowing()
        elseif newState == SCENE_HIDDEN then
            GF:OnMoveHidden()
        end
    end)
    self.moveScene = scene
    return scene
end

function GF:StartMove()
    if self.moving then return end
    self.movePreview = self.preview
    self.moveSaved = false
    self.moving = true
    self:GetMoveScene()
    SCENE_MANAGER:Push(MOVE_SCENE)
end

function GF:OnMoveShowing()
    local sv = SV()
    self.moving = true
    ME:RaiseWhilePlacing({ self.panel }, true)
    self.moveStartX, self.moveStartY = sv.groupFinderPosX, sv.groupFinderPosY
    self.moveStartScale = sv.groupFinderScale
    self.moveX, self.moveY = sv.groupFinderPosX, sv.groupFinderPosY
    self.moveScale = sv.groupFinderScale
    self.moveStartSpread = sv.groupFinderWidth or DEFAULTS.groupFinderWidth
    self.moveSpread = sv.groupFinderWidth or DEFAULTS.groupFinderWidth
    KEYBIND_STRIP:AddKeybindButtonGroup(self.moveKeybinds)
    DIRECTIONAL_INPUT:Activate(self.mover, self.panel)
    ME:SetPlacing(true)
    self:Render()
end

function GF:OnMoveHidden()
    DIRECTIONAL_INPUT:Deactivate(self.mover)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.moveKeybinds)
    if not self.moveSaved then
        self:SetScale(self.moveStartScale)
        self:SetSpread(self.moveStartSpread)
        self:SetPosition(self.moveStartX, self.moveStartY)
    end
    self.moving = false
    ME:RaiseWhilePlacing({ self.panel }, false)
    ME:SetPlacing(false)
    if self.movePreview then
        self.movePreview = false
        self:SetPreview(true)
    else
        self:Render()
    end
end

function GF:EndMove(save)
    if not self.moving then return end
    self.moveSaved = save == true
    if save then
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    else
        PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
    end
    SCENE_MANAGER:HideCurrentScene()
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function GF:GetPreviewControls()
    if self.panel then return { self.panel } end
    return {}
end

local function ModeOption(name, key, what)
    return {
        type    = "dropdown",
        name    = name,
        choices = GF.modeChoices,
        default = DEFAULTS[key],
        tooltip = "Which " .. what .. " groups it checks.\n\n"
               .. "Off: doesn't check them.\n"
               .. "Normal: normal groups only.\n"
               .. "Veteran: veteran groups only.\n"
               .. "All: normal and veteran groups.",
        getFunc = function() return SV()[key] end,
        setFunc = function(val)
            SV()[key] = val
            RefreshCategories()
            GF:QueueRender()
        end,
    }
end

local function PickOption(name, key, choices, note, disabled)
    return {
        type     = "checklist",
        name     = name,
        choices  = choices,
        default  = {},
        tooltip  = "Which ones set off your alarm.\n\n" .. note,
        disabled = disabled,
        getFunc  = function() return PickList(SV()[key]) end,
        setFunc  = function(values)
            SV()[key] = PickList(values)
            RecolorRows()
            RescanSoon()
        end,
    }
end

function GF:SubmenuOption()
    if not ApiReady() then return nil end
    local function AlarmOff() return not SV().groupFinderAlarm end

    return {
        type    = "submenu",
        name    = "Group Finder",
        tooltip = "Checks the Group Finder for you and lists matching groups on screen while you play.",
        options = {
            {
                type    = "toggle",
                name    = "Enabled",
                preset  = "YES_NO",
                default = DEFAULTS.groupFinderShow,
                tooltip = "Checks the Group Finder every 30 seconds, or every 60 seconds if you pick more than one category, "
                       .. "and lists matching groups on screen while you play.\n\n"
                       .. "You can also turn it on or off with Monitor in the Group Finder. "
                       .. "It pauses while the Group Finder is open, while you have your own group listed "
                       .. "and where the Group Finder can't be used, and it puts your Group Finder filters back after each check.",
                getFunc = function() return SV().groupFinderShow end,
                setFunc = function(val)
                    SV().groupFinderShow = val
                    GF:Refresh(val)
                end,
            },
            {
                type    = "toggle",
                name    = "Preview",
                tooltip = "Shows sample groups here so you can see your changes. "
                       .. "Stays on until you turn it off or leave the settings.",
                getFunc = function() return GF.preview end,
                setFunc = function(val) GF:SetPreview(val) end,
            },
            {
                type       = "button",
                name       = "Move / Scale",
                buttonText = "Move / Scale",
                tooltip    = "Move it with the left stick. Right stick up and down scales it, left and right makes it longer or shorter.",
                func       = function() GF:StartMove() end,
            },
            {
                type    = "toggle",
                name    = "Close On Join",
                preset  = "YES_NO",
                default = DEFAULTS.groupFinderCloseOnJoin,
                tooltip = "Turns Group Finder off when you join a group.",
                getFunc = function() return SV().groupFinderCloseOnJoin end,
                setFunc = function(val) SV().groupFinderCloseOnJoin = val end,
            },
            {
                type    = "dropdown",
                name    = "Role",
                choices = self.roleChoices,
                default = DEFAULTS.groupFinderRole,
                tooltip = "Only shows groups that still have room for this role. Any shows every group.",
                getFunc = function() return SV().groupFinderRole end,
                setFunc = function(val)
                    SV().groupFinderRole = val
                    RescanSoon()
                end,
            },
            { type = "header", name = "Categories" },
            ModeOption("Dungeons", "groupFinderDungeons", "dungeon"),
            ModeOption("Arenas", "groupFinderArenas", "arena"),
            ModeOption("Trials", "groupFinderTrials", "trial"),
            {
                type    = "checklist",
                name    = "Other Categories",
                choices = self.otherChoices,
                default = {},
                tooltip = "Other groups it checks.",
                getFunc = function()
                    local sv = SV()
                    local values = {}
                    for i = 1, #GF.otherChoices do
                        local value = GF.otherChoices[i].value
                        if sv[OTHER_KEYS[value]] then values[#values + 1] = value end
                    end
                    return values
                end,
                setFunc = function(values)
                    local sv = SV()
                    local set = {}
                    if type(values) == "table" then
                        for i = 1, #values do set[values[i]] = true end
                    end
                    for value, key in pairs(OTHER_KEYS) do
                        sv[key] = set[value] == true
                    end
                    RefreshCategories()
                    GF:QueueRender()
                end,
            },
            {
                type    = "submenu",
                name    = "Alarm",
                tooltip = "Plays a sound and highlights the groups you pick.",
                options = {
                    {
                        type    = "toggle",
                        name    = "Alarm",
                        preset  = "YES_NO",
                        default = DEFAULTS.groupFinderAlarm,
                        tooltip = "Plays a sound and highlights a group in red when it's one you picked below. "
                               .. "With nothing picked, it stays quiet.\n\n"
                               .. "It only works for groups Group Finder is checking, so turn on their category in Categories too.",
                        getFunc = function() return SV().groupFinderAlarm end,
                        setFunc = function(val)
                            SV().groupFinderAlarm = val
                            RecolorRows()
                            RescanSoon()
                        end,
                    },
                    PickOption("Dungeons", "groupFinderAlarmDungeons", self.alarmDungeonChoices,
                        "All Dungeons covers every dungeon group. Groups that don't name a dungeon count for any dungeon you pick.\n\nDungeons also has to be on in Categories.", AlarmOff),
                    PickOption("Trials", "groupFinderAlarmTrials", self.alarmTrialChoices,
                        "All Trials covers every trial group. Groups that don't name a trial count for any trial you pick.\n\nTrials also has to be on in Categories.", AlarmOff),
                    PickOption("Arenas", "groupFinderAlarmArenas", self.alarmArenaChoices,
                        "All Arenas covers every arena group. Groups that don't name an arena count for any arena you pick.\n\nArenas also has to be on in Categories.", AlarmOff),
                    PickOption("Other", "groupFinderAlarmOther", self.otherChoices,
                        "The ones you pick also have to be checked in Other Categories.", AlarmOff),
                    {
                        type     = "dropdown",
                        name     = "Alarm Sound",
                        choices  = self.soundChoices,
                        default  = DEFAULTS.groupFinderAlarmSound,
                        tooltip  = "The sound it plays. You'll hear it when you pick one.",
                        disabled = AlarmOff,
                        getFunc  = function() return SV().groupFinderAlarmSound end,
                        setFunc  = function(val)
                            if SV().groupFinderAlarmSound == val then return end
                            SV().groupFinderAlarmSound = val
                            PlayAlarm(val)
                        end,
                    },
                },
            },
            {
                type    = "submenu",
                name    = "Appearance",
                tooltip = "Font, size of the list and background.",
                options = {
                    {
                        type    = "dropdown",
                        name    = "Font",
                        choices = ME.FONT_CHOICES,
                        default = DEFAULTS.groupFinderFont,
                        sample  = function() return "Lair of Maarselok", SampleFont(), 1, 1, 1 end,
                        getFunc = function() return SV().groupFinderFont end,
                        setFunc = function(val)
                            SV().groupFinderFont = val
                            GF:Render()
                        end,
                    },
                    {
                        type    = "slider",
                        name    = "Width",
                        min     = WIDTH_MIN, max = WIDTH_MAX, step = 10,
                        default = DEFAULTS.groupFinderWidth,
                        tooltip = "How wide the list is. Default is " .. DEFAULTS.groupFinderWidth .. ".",
                        getFunc = function() return SV().groupFinderWidth end,
                        setFunc = function(val)
                            SV().groupFinderWidth = val
                            GF:Render()
                        end,
                    },
                    {
                        type    = "slider",
                        name    = "Visible Listings",
                        min     = ROWS_MIN, max = ROWS_MAX, step = 1,
                        default = DEFAULTS.groupFinderRows,
                        tooltip = "How many groups the list shows at once. Default is " .. DEFAULTS.groupFinderRows .. ".",
                        getFunc = function() return SV().groupFinderRows end,
                        setFunc = function(val)
                            SV().groupFinderRows = val
                            GF:Render()
                        end,
                    },
                    {
                        type    = "toggle",
                        name    = "Background",
                        preset  = "YES_NO",
                        default = DEFAULTS.groupFinderBackground,
                        tooltip = "Puts a dark box behind the list so it's easier to read.",
                        getFunc = function() return SV().groupFinderBackground end,
                        setFunc = function(val)
                            SV().groupFinderBackground = val
                            GF:ApplyBox()
                        end,
                    },
                    {
                        type     = "slider",
                        name     = "Background Opacity",
                        min      = 0, max = 100, step = 5,
                        default  = DEFAULTS.groupFinderBackgroundOpacity,
                        tooltip  = "Default is " .. DEFAULTS.groupFinderBackgroundOpacity .. ".",
                        disabled = function() return not SV().groupFinderBackground end,
                        getFunc  = function() return SV().groupFinderBackgroundOpacity end,
                        setFunc  = function(val)
                            SV().groupFinderBackgroundOpacity = val
                            GF:ApplyBox()
                        end,
                    },
                },
            },
        },
    }
end

function GF:OnSettingsState(newState)
    if newState == SCENE_SHOWING then LoadActivityNames() end
    if newState == SCENE_HIDDEN and self.preview then
        self:SetPreview(false)
    end
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function GF:Init()
    if not ApiReady() then return end
    self:CreatePanel()
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneChanged)
    InstallKeybinds()
    ready = true
    self:Refresh(true)
end

function GF:OnPlayerActivated()
    if not ready then return end
    LoadActivityNames()
    InstallKeybinds()
    OnStatusChanged()
    self:Refresh(false)
end

function GF:OnReset()
    self.preview = false
    self:Refresh(false)
end

ME:RegisterFeature(GF)
