-- Questbound_Tracker.lua : the quest tracker panel.
--  * Tabs: Current (only the followed quest) / Main (main story) / Here (this zone,
--    nearest first) / All / Dungeons / Daily, with counts.
--  * The followed quest is pinned on top as a card: name + badge (Story,
--    Dungeon, Daily, Turn in), objectives with progress bars, and a footer with
--    distance, time, step progress and the teleport/queue and map icons.
--  * Other quests show their distance when they're on this map.
--  * Click a quest to follow it (click again: objectives open/close), shift-click
--    to put a map marker on it, right-click for more. Mouse wheel scrolls.
--  * Drag by the header, resize by the edges, fades in combat (setting).
-- Clicks on the small icons are found by mouse position in the row / header /
-- tab bar handlers (like Set Hunter's row icons), not by the icons themselves.

local W = Questbound
local L = W.L
local C = W.COLOR
local Tracker = {}
W.Tracker = Tracker

local HEADER_H = 32
local TABS_H = 24
local PAD = 10
local INDENT = 20
local RIGHT_W = 70
local CORNER = 12          -- ledger frame: length of the gold corner brackets
local EDGE = 8             -- resize handles on every side / corner (like Set Hunter's window);
                           -- rows, header and tabs keep their clicks out of this border
local HEADER_TEXT = C.header   -- tabs and quest count: lighter than C.dim, easier to read (follows the color theme)
local ICON = 18            -- teleport / map icon size
local BAR_H = 3            -- progress bars
local TEX_TELEPORT = "EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds"
-- current = only the followed quest, main = main story quests
local TABS = { "current", "main", "here", "all", "dungeons", "daily" }
local RESORT_MS = 10000    -- nearest-first order is refreshed this often (not while hovered)

local ui = { rows = {}, pinned = {}, lines = {}, offset = 0, order = {}, counts = {}, tabs = {} }
local inCombat = false

-- ---------------------------------------------------------------------------
-- Game's own tracker

local gameTrackerHooked = false

local function ApplyGameTracker()
    local hide = W.sv.hideGameTracker and W.sv.tracker.shown
    local fragment = FOCUSED_QUEST_TRACKER_FRAGMENT
    if fragment and ZO_FocusedQuestTrackerPanel then
        -- same way as our own panels: take the game's tracker out of the HUD scenes
        fragment.wfControl = ZO_FocusedQuestTrackerPanel
        if fragment.wfShown == nil then fragment.wfShown = true end   -- the game added it
        W.ShowOnHud(fragment, not hide)
    elseif ZO_FocusedQuestTrackerPanel then
        if not gameTrackerHooked then
            gameTrackerHooked = true
            ZO_PostHookHandler(ZO_FocusedQuestTrackerPanel, "OnEffectivelyShown", function(self)
                if W.sv.hideGameTracker and W.sv.tracker.shown then self:SetHidden(true) end
            end)
        end
        ZO_FocusedQuestTrackerPanel:SetHidden(hide)
    end
end

-- Advanced UI's own quest tracker (AUI_Questtracker, under its minimap). On by default
-- (sv.hideAuiTracker; the first time a chat note says so and how to get it back, once
-- per account) and only while Questbound's tracker is shown: the panel is hidden, and
-- hidden again whenever AUI's scene fragment shows it (after closing a menu). AUI's
-- minimap, settings and files are never touched; turn the option off (or disable
-- Questbound) and its tracker is back as before.
local auiHooked = false

local function AuiTrackerReady()
    return AUI and AUI.Questtracker and AUI.Questtracker.g_isInit and AUI.Questtracker.g_isInit()
        and AUI_Questtracker ~= nil
end
Tracker.AuiTrackerReady = AuiTrackerReady

local function WantAuiHidden()
    return W.sv.hideAuiTracker and W.sv.tracker.shown
end

local function ApplyAuiTracker()
    if not AuiTrackerReady() then return end
    if not auiHooked then
        auiHooked = true
        ZO_PostHookHandler(AUI_Questtracker, "OnEffectivelyShown", function(self)
            if WantAuiHidden() then self:SetHidden(true) end
        end)
    end
    if WantAuiHidden() then
        AUI_Questtracker:SetHidden(true)
        if not W.sv.auiNoticeShown then
            W.sv.auiNoticeShown = true
            W.Print(L("AUI_HIDDEN_NOTE"))
        end
    elseif AUI_Questtracker:IsHidden() and (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()) then
        AUI_Questtracker:SetHidden(false)   -- back as AUI shows it on the HUD
    end
end

-- ---------------------------------------------------------------------------
-- Quest list -> lines

local function PlayerZones()
    local names = {}
    local zoneIndex = GetUnitZoneIndex("player")
    names[zo_strformat("<<1>>", GetZoneNameByIndex(zoneIndex))] = true
    local parent = GetParentZoneId(GetZoneId(zoneIndex))
    if parent and parent ~= 0 then names[zo_strformat("<<1>>", GetZoneNameById(parent))] = true end
    return names
end

local function IsExpanded(name, followed)
    local sv = W.sv.tracker
    local manual = sv.expanded[name]
    if manual ~= nil then return manual end
    return followed or sv.expandAll
end

local function AddConditions(lines, qi)
    for step = 1, GetJournalQuestNumSteps(qi) do
        local _, visibility, _, overrideText, numConditions = GetJournalQuestStepInfo(qi, step)
        if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN then
            local optional = visibility == QUEST_STEP_VISIBILITY_OPTIONAL
            if overrideText and overrideText ~= "" then
                lines[#lines + 1] = { kind = "cond", qi = qi, text = zo_strformat("<<1>>", overrideText), optional = optional }
            else
                for cond = 1, numConditions or 0 do
                    local text, cur, max, isFail, isComplete, _, isVisible = GetJournalQuestConditionInfo(qi, step, cond)
                    if text and text ~= "" and not isFail and isVisible ~= false then
                        text = zo_strformat("<<1>>", text)
                        local a, b
                        local base, ta, tb = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
                        if base then
                            text, a, b = base, tonumber(ta), tonumber(tb)
                        elseif max and max > 1 then
                            a, b = cur, max
                        end
                        lines[#lines + 1] = {
                            kind = "cond", qi = qi, text = text, done = isComplete, optional = optional,
                            counter = a and (a .. "/" .. b) or nil,
                            progress = (a and b and b > 1) and zo_clamp(a / b, 0, 1) or nil,
                        }
                    end
                end
            end
        end
    end
end

-- Objectives done / total of the current step.
local function StepProgress(qi)
    local done, total = 0, 0
    local _, _, _, _, numConditions = GetJournalQuestStepInfo(qi, 1)
    for cond = 1, numConditions or 0 do
        local text, _, _, isFail, isComplete, _, isVisible = GetJournalQuestConditionInfo(qi, 1, cond)
        if text and text ~= "" and not isFail and isVisible ~= false then
            total = total + 1
            if isComplete then done = done + 1 end
        end
    end
    return done, total
end

-- Small icons after the quest name for rewards worth knowing about: a skill point
-- (or a skill line) and items of blue quality or better (the item's own icon).
-- Reward types as the game's interact window reads them (esoui interactwindow_shared).
local REWARD_ICON = 15
local TEX_SKILL = "EsoUI/Art/MainMenu/menuBar_skills_up.dds"
local function Icon(file)
    return string.format(" |t%d:%d:%s|t", REWARD_ICON, REWARD_ICON, file)
end

local function RewardIcons(qi)
    if not GetJournalQuestNumRewards then return "" end
    local skill, items = false, {}
    local minQuality = ITEM_DISPLAY_QUALITY_ARCANE or 3
    for i = 1, GetJournalQuestNumRewards(qi) or 0 do
        local rewardType, _, amount, icon, _, quality = GetJournalQuestRewardInfo(qi, i)
        if rewardType == REWARD_TYPE_PARTIAL_SKILL_POINTS or rewardType == REWARD_TYPE_SKILL_LINE then
            skill = (amount or 1) > 0
        elseif rewardType == REWARD_TYPE_AUTO_ITEM and quality and quality >= minQuality and icon and icon ~= "" then
            if #items < 2 then items[#items + 1] = icon end
        end
    end
    local out = skill and Icon(TEX_SKILL) or ""
    for _, icon in ipairs(items) do out = out .. Icon(icon) end
    return out
end

local function QuestLine(qi, followed)
    local name, _, _, activeStepType, _, _, _, _, _, questType = GetJournalQuestInfo(qi)
    name = zo_strformat("<<1>>", name)
    local repeatable = GetJournalQuestRepeatType and GetJournalQuestRepeatType(qi) ~= QUEST_REPEAT_NOT_REPEATABLE
    local needsQueue, dungeon = W.Dungeon.NeedsQueue(qi)
    return {
        rewards = RewardIcons(qi),
        kind = "quest", qi = qi, name = name, followed = followed,
        story = questType == QUEST_TYPE_MAIN_STORY, repeatable = repeatable,
        turnIn = activeStepType == QUEST_STEP_TYPE_END,
        dungeonQuest = W.Dungeon.Info(qi) ~= nil,
        pvp = W.Dungeon.IsPvPQuest(qi),            -- no wayshrine travel there
        dungeon = needsQueue and dungeon or nil,   -- group dungeon you're not in: offer to queue
    }
end

local function Badge(q)
    if q.turnIn then return L("BADGE_TURNIN"), C.done end
    if q.dungeonQuest then return L("BADGE_DUNGEON"), C.theme end
    if q.story then return L("BADGE_STORY"), C.story end
    if q.repeatable then return L("BADGE_DAILY"), C.theme end
end

local function Distance(qi)
    return W.Nav.QuestDistance(qi) or math.huge
end

local function Build()
    local sv = W.sv.tracker
    local tab = sv.tab or "all"
    local search = (ui.search and ui.search ~= "") and ui.search or nil   -- lowercase search text
    local followed = W.Nav.state.questIndex
    if followed and not IsValidQuestIndex(followed) then followed = nil end
    local here = PlayerZones()
    local groups, byName, names = {}, {}, {}
    local counts = ui.counts
    counts.here, counts.all, counts.dungeons, counts.daily = 0, 0, 0, 0
    counts.current = followed and 1 or 0
    counts.main = 0
    local journal = {}   -- Current tab: /wf next goes through the journal

    -- followed quest: card on top
    local pinned = {}
    if followed then
        local q = QuestLine(followed, true)
        q.expanded = IsExpanded(q.name, true)
        pinned[#pinned + 1] = { kind = "section", text = L("FOLLOWING") }
        pinned[#pinned + 1] = q
        if q.dungeon then
            pinned[#pinned + 1] = { kind = "hint", qi = followed, text = L("DUNGEON_HINT", q.dungeon.name) }
        end
        if q.expanded then AddConditions(pinned, followed) end
        local done, total = StepProgress(followed)
        pinned[#pinned + 1] = { kind = "footer", qi = followed, quest = q, done = done, total = total }
    end

    for qi = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(qi) then
            local q = QuestLine(qi, qi == followed)
            names[q.name] = true
            local zone = zo_strformat("<<1>>", (GetJournalQuestLocationInfo(qi)) or "")
            -- dungeon quests (pledges...) under their dungeon, not where you picked them up
            local dungeon = W.Dungeon.Info(qi)
            if dungeon then zone = dungeon.name end
            if zone == "" then zone = L("ZONE_OTHER") end
            local isHere = here[zone] == true or (dungeon ~= nil and dungeon.inside)
            counts.all = counts.all + 1
            if qi ~= followed then journal[#journal + 1] = qi end
            if isHere then counts.here = counts.here + 1 end
            if q.dungeonQuest then counts.dungeons = counts.dungeons + 1 end
            if q.repeatable then counts.daily = counts.daily + 1 end
            if q.story then counts.main = counts.main + 1 end
            local inTab = tab == "all" or (tab == "here" and isHere) or (tab == "main" and q.story)
                or (tab == "dungeons" and q.dungeonQuest) or (tab == "daily" and q.repeatable)
            -- searching: every quest whose name or zone contains the text, whatever the tab
            if search then
                inTab = zo_strlower(q.name):find(search, 1, true) ~= nil
                    or zo_strlower(zone):find(search, 1, true) ~= nil
            end
            if inTab and qi ~= followed then
                -- pinned quests in their own group on top, hidden ones in a folded group at the end
                local key, special = (tab == "here") and "" or zone, nil   -- Here: one list, no zone headers
                if sv.hide[q.name] then
                    key, special = L("GROUP_HIDDEN"), "hide"
                elseif sv.pins[q.name] then
                    key, special = L("GROUP_PINNED"), "pin"
                elseif q.turnIn then
                    -- done, only the hand-in left: its own green group near the top
                    key, special = L("GROUP_TURNIN"), "turnin"
                end
                q.pinned = special == "pin"
                local g = byName[key]
                if not g then
                    g = { name = key, here = isHere and not special, special = special, quests = {} }
                    byName[key] = g
                    groups[#groups + 1] = g
                end
                g.quests[#g.quests + 1] = q
            end
        end
    end

    -- forget opened/closed state of quests that left the journal
    for _, list in ipairs({ sv.expanded, sv.pins, sv.hide }) do
        for name in pairs(list) do
            if not names[name] then list[name] = nil end
        end
    end

    -- pinned first, then this zone, then A-Z; "Other quests" and then hidden ones last
    local other = L("ZONE_OTHER")
    local ORDER = { pin = 0, turnin = 0.5, hide = 2 }
    table.sort(groups, function(a, b)
        local oa, ob = ORDER[a.special] or 1, ORDER[b.special] or 1
        if oa ~= ob then return oa < ob end
        if a.here ~= b.here then return a.here end
        if (a.name == other) ~= (b.name == other) then return b.name == other end
        return a.name < b.name
    end)

    local lines = {}
    ZO_ClearTable(ui.order)
    if followed then ui.order[1] = followed end
    for _, g in ipairs(groups) do
        -- quests on this map: nearest first; elsewhere A-Z
        if g.here or tab == "here" then
            table.sort(g.quests, function(a, b)
                local da, db = Distance(a.qi), Distance(b.qi)
                if da ~= db then return da < db end
                return a.name < b.name
            end)
        else
            table.sort(g.quests, function(a, b) return a.name < b.name end)
        end
        -- (the hidden group starts folded: only an explicit "open" keeps it open)
        local state = sv.collapsedZones[g.name]
        local collapsed = g.name ~= "" and (state == true or (g.special == "hide" and state == nil))
        if g.name ~= "" then
            lines[#lines + 1] = { kind = "zone", text = g.name, count = #g.quests, collapsed = collapsed, special = g.special }
        end
        for _, q in ipairs(g.quests) do
            ui.order[#ui.order + 1] = q.qi
            if not collapsed then
                q.expanded = IsExpanded(q.name, false)
                lines[#lines + 1] = q
                if q.expanded then AddConditions(lines, q.qi) end
            end
        end
    end
    if tab == "current" then
        for _, qi in ipairs(journal) do ui.order[#ui.order + 1] = qi end
    end
    if #pinned > 0 and #lines > 0 then pinned[#pinned + 1] = { kind = "divider" } end

    ui.pinned = pinned
    ui.lines = lines
    ui.offset = zo_clamp(ui.offset, 0, math.max(0, #lines - 1))
end

function Tracker.QuestOrder()
    return ZO_ShallowTableCopy(ui.order)
end

-- ---------------------------------------------------------------------------
-- Actions

local Refresh

local function Alert(text)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, text)
end

local function Follow(qi, name)
    W.sv.tracker.expanded[name] = nil
    W.Nav.Assist(qi)
    W.Dungeon.Offer(qi)   -- dungeon quest and you're not inside: suggest queueing
end

-- The icon next to a quest: queue for its dungeon, or teleport near it.
-- The icon next to a quest: queue for its dungeon, join a PvP campaign, or teleport near it.
local function QuestAction(line)
    local q = line.quest or line
    if q.dungeon then
        W.Dungeon.Offer(q.qi)
    elseif q.pvp then
        W.Dungeon.JoinPvP(q.qi)
    else
        W.Teleport.Start(q.qi)
    end
end

-- Picture for that icon (PvP: the Alliance War icon).
local function ActionIcon(q)
    if q.dungeon then return W.Dungeon.ICON end
    if q.pvp then return W.Dungeon.PVP_ICON end
    return TEX_TELEPORT
end

local function ShowOnMap(qi)
    if ZO_WorldMap_ShowQuestOnMap then ZO_WorldMap_ShowQuestOnMap(qi) end
end

local function MarkQuest(qi)
    if W.Nav.MarkQuest(qi) then
        PlaySound(SOUNDS.MAP_PING)
    else
        Alert(L("MARK_NONE"))
    end
end

local function ToggleExpanded(line)
    W.sv.tracker.expanded[line.name] = not line.expanded
    Refresh()
end

local function OpenJournal(qi)
    local function Focus()
        if QUEST_JOURNAL_KEYBOARD and QUEST_JOURNAL_KEYBOARD.FocusQuestWithIndex then
            QUEST_JOURNAL_KEYBOARD:FocusQuestWithIndex(qi)
        end
    end
    Focus()
    if MAIN_MENU_KEYBOARD then
        MAIN_MENU_KEYBOARD:ShowScene("questJournal")
    else
        SCENE_MANAGER:Show("questJournal")
    end
    zo_callLater(Focus, 100)
end

local function QuestMenu(row, line)
    ClearMenu()
    if not line.followed then
        AddMenuItem(L("MENU_ASSIST"), function() Follow(line.qi, line.name) end)
    end
    AddMenuItem(L(line.expanded and "MENU_COLLAPSE" or "MENU_EXPAND"), function() ToggleExpanded(line) end)
    if line.dungeon then
        AddMenuItem(L("MENU_QUEUE"), function() W.Dungeon.Offer(line.qi) end)
    end
    if not line.pvp and not line.dungeon then
        AddMenuItem(L("MENU_TELEPORT"), function() W.Teleport.Start(line.qi) end)
    elseif line.pvp and not line.dungeon then
        AddMenuItem(L("MENU_PVP"), function() W.Dungeon.JoinPvP(line.qi) end)
    end
    AddMenuItem(L("MENU_MARK"), function() MarkQuest(line.qi) end)
    if ZO_WorldMap_ShowQuestOnMap then
        AddMenuItem(L("MENU_MAP"), function() ShowOnMap(line.qi) end)
    end
    AddMenuItem(L("MENU_JOURNAL"), function() OpenJournal(line.qi) end)
    -- what Skip dialogs clicked through for this quest
    if W.Story.Has(line.name) then
        AddMenuItem(L("MENU_STORY"), function() W.Story.Open(line.name) end)
    end
    if IsUnitGrouped("player") and GetIsQuestSharable(line.qi) then
        AddMenuItem(L("MENU_SHARE"), function() ShareQuest(line.qi) end)
    end
    -- pin to the top / hide from the list (kept by quest name, across characters)
    local sv = W.sv.tracker
    if not line.followed then
        AddMenuItem(L(sv.pins[line.name] and "MENU_UNPIN" or "MENU_PIN"), function()
            sv.pins[line.name] = not sv.pins[line.name] or nil
            if sv.pins[line.name] then sv.hide[line.name] = nil end
            Refresh()
        end)
    end
    AddMenuItem(L(sv.hide[line.name] and "MENU_UNHIDE" or "MENU_HIDE"), function()
        sv.hide[line.name] = not sv.hide[line.name] or nil
        if sv.hide[line.name] then sv.pins[line.name] = nil end
        Refresh()
    end)
    -- abandon, with the game's own confirmation (main story quests can't be abandoned)
    if not line.story then
        AddMenuItem(L("MENU_ABANDON"), function()
            ZO_Dialogs_ShowDialog("ABANDON_QUEST", { questIndex = line.qi }, { mainTextParams = { line.name } })
        end)
    end
    ShowMenu(row)
end

-- Is the mouse over control (pad = extra pixels around small targets)?
local function IsOver(control, pad)
    if not control or control:IsHidden() then return false end
    pad = pad or 0
    local x, y = GetUIMousePosition()
    return x >= control:GetLeft() - pad and x <= control:GetRight() + pad
        and y >= control:GetTop() - pad and y <= control:GetBottom() + pad
end

local function OnRowClick(row, button, upInside)
    if not upInside then return end
    local line = row.line
    if not line then return end
    local left = button == MOUSE_BUTTON_INDEX_LEFT
    -- icons first
    if left and IsOver(row.tp, 3) then
        ClearTooltip(InformationTooltip)
        PlaySound(SOUNDS.DEFAULT_CLICK)
        QuestAction(line)
        return
    end
    if left and IsOver(row.map, 3) then
        ClearTooltip(InformationTooltip)
        PlaySound(SOUNDS.DEFAULT_CLICK)
        ShowOnMap(line.qi)
        return
    end
    if line.kind == "zone" then
        -- stored as true / false (the hidden group needs an explicit "open")
        W.sv.tracker.collapsedZones[line.text] = not line.collapsed
        Refresh()
    elseif line.kind == "quest" then
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            QuestMenu(row, line)
        elseif IsShiftKeyDown() then
            MarkQuest(line.qi)
        elseif line.followed then
            W.Nav.DropWaypoint()   -- clicking the quest = go for the quest, not your map marker
            ToggleExpanded(line)
        else
            Follow(line.qi, line.name)
        end
    elseif line.kind == "hint" and left then
        W.Dungeon.Offer(line.qi)
    elseif line.kind == "cond" and left then
        if line.qi ~= W.Nav.state.questIndex then W.Nav.Assist(line.qi) end
        -- this objective is the one to go to (click it again: back to the nearest)
        if not line.done then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            W.Nav.ChooseObjective(line.text)
            Refresh()
        end
    end
end

local function Scroll(delta)
    local new = zo_clamp(ui.offset - delta, 0, math.max(0, #ui.lines - 1))
    if new ~= ui.offset then
        ui.offset = new
        Tracker.Layout()
    end
end

-- ---------------------------------------------------------------------------
-- Rows

local function Tex(parent, file)
    local t = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    if file then t:SetTexture(file) end
    return t
end

-- Clickable icon for the header: a real button (CT_BUTTON + OnClicked) with the
-- picture as a child texture; the header also checks clicks by position.
local function IconButton(parent, file, size, tooltip, onClick)
    local b = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    b:SetDimensions(size + 6, size + 6)
    b:SetMouseEnabled(true)
    b:SetDrawLevel(5)
    b:SetClickSound(SOUNDS.DEFAULT_CLICK)
    local icon = WINDOW_MANAGER:CreateControl(nil, b, CT_TEXTURE)
    icon:SetTexture(file)
    icon:SetDimensions(size, size)
    icon:SetAnchor(CENTER, b, CENTER, 0, 0)
    icon:SetDrawLevel(6)
    b.icon = icon
    b.onClick = onClick
    b.idle = function(tex) tex:SetColor(W.RGBA(C.dim)) end
    b:SetHandler("OnMouseEnter", function(self)
        self.icon:SetColor(1, 1, 1, 1)
        InitializeTooltip(InformationTooltip, self, TOP, 0, 4, BOTTOM)
        SetTooltipText(InformationTooltip, tooltip())
    end)
    b:SetHandler("OnMouseExit", function(self)
        self.idle(self.icon)
        ClearTooltip(InformationTooltip)
    end)
    b:SetHandler("OnClicked", function()
        ClearTooltip(InformationTooltip)
        onClick()
    end)
    return b
end

-- Row icon (teleport / queue / map): a plain picture, clicks come from the row.
local function RowIcon(row)
    local t = Tex(row)
    t:SetDimensions(ICON, ICON)
    t:SetDrawLevel(4)
    t:SetHidden(true)
    return t
end

local function IdleIcon(t)
    t:SetColor(1, 1, 1, 0.8)
    t:SetDesaturation(0.4)
end

local function IconTooltip(row, icon)
    local line = row.line
    if not line then return "" end
    if icon == row.map then return L("TT_MAP") end
    local q = line.quest or line
    if q.dungeon then return L("TT_QUEUE", q.dungeon.name) end
    if q.pvp then return L("TT_PVP_ROW") end
    return L("TT_TELEPORT")
end

-- Quest tooltip (hovering a quest line, not its icons): the journal's short description
-- and every reward spelled out (skill point, items in their quality color, gold...).
local function RewardLine(qi, i)
    local rewardType, name, amount, _, _, quality = GetJournalQuestRewardInfo(qi, i)
    name = (name and name ~= "") and zo_strformat("<<1>>", name) or nil
    if rewardType == REWARD_TYPE_PARTIAL_SKILL_POINTS then
        if ZO_QuestReward_GetSkillPointText then
            local ok, text = pcall(ZO_QuestReward_GetSkillPointText, amount)
            if ok and text and text ~= "" then return text end
        end
        return L("REWARD_SKILL")
    end
    if rewardType == REWARD_TYPE_MONEY and amount and amount > 0 then
        return ZO_Currency_FormatKeyboard and ZO_Currency_FormatKeyboard(CURT_MONEY, amount, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
            or L("TP_GOLD", amount)
    end
    if not name then return nil end
    if amount and amount > 1 then name = name .. " x" .. amount end
    if rewardType == REWARD_TYPE_AUTO_ITEM and quality and GetItemQualityColor then
        local ok, color = pcall(GetItemQualityColor, quality)
        if ok and color then name = color:Colorize(name) end
    end
    return name
end

local function QuestTooltip(line)
    local qi = line.qi
    if not qi or not IsValidQuestIndex(qi) then return nil end
    local parts = { W.Colorize(C.theme, line.name) }
    local _, background = GetJournalQuestInfo(qi)
    if background and background ~= "" then
        parts[#parts + 1] = "|cC5C29E" .. zo_strformat("<<1>>", background) .. "|r"
    end
    local rewards = {}
    for i = 1, (GetJournalQuestNumRewards and GetJournalQuestNumRewards(qi)) or 0 do
        local text = RewardLine(qi, i)
        if text then rewards[#rewards + 1] = "  " .. text end
    end
    if #rewards > 0 then
        parts[#parts + 1] = W.Colorize(C.theme, L("REWARDS")) .. "\n" .. table.concat(rewards, "\n")
    end
    return table.concat(parts, "\n\n")
end

-- While the mouse is over a row: light up the icon under it, with its tooltip;
-- over the rest of a quest line: the quest tooltip (left of the tracker).
local function RowHover(row)
    local over
    for _, icon in ipairs({ row.tp, row.map }) do
        if IsOver(icon, 3) then over = icon end
    end
    local line = row.line
    local tip = over and "icon" or ((line and line.kind == "quest") and "quest") or nil
    if over == row.hoverIcon and tip == row.tipState then return end
    if row.hoverIcon and row.hoverIcon ~= over then IdleIcon(row.hoverIcon) end
    row.hoverIcon, row.tipState = over, tip
    if over then
        over:SetColor(1, 1, 1, 1)
        over:SetDesaturation(0)
        InitializeTooltip(InformationTooltip, over, RIGHT, -6, 0, LEFT)
        SetTooltipText(InformationTooltip, IconTooltip(row, over))
    elseif tip == "quest" then
        local text = QuestTooltip(line)
        if text then
            InitializeTooltip(InformationTooltip, row, RIGHT, -12, 0, LEFT)
            SetTooltipText(InformationTooltip, text)
        else
            ClearTooltip(InformationTooltip)
        end
    else
        ClearTooltip(InformationTooltip)
    end
end

local function CreateRow()
    local row = WINDOW_MANAGER:CreateControl(nil, ui.win, CT_CONTROL)
    row:SetMouseEnabled(true)
    row:SetHitInsets(EDGE, 0, -EDGE, 0)   -- leave the panel's side edges to the resize handles
    row:SetDrawLevel(2)

    row.hl = Tex(row)
    row.hl:SetAnchorFill(row)
    row.hl:SetHidden(true)

    row.bar = Tex(row)
    row.bar:SetWidth(3)
    row.bar:SetAnchor(TOPLEFT, row, TOPLEFT, 1, 2)
    row.bar:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 1, -2)

    -- trail (panel style "trail"): a gold line linking the quests, broken around each quest's
    -- ring (railA above it, railB below it; rows without a ring only use railA)
    row.railA = Tex(row)
    row.railA:SetWidth(2)
    row.railA:SetDrawLevel(2)
    row.railB = Tex(row)
    row.railB:SetWidth(2)
    row.railB:SetDrawLevel(2)

    row.div = Tex(row, W.TEX .. "divider.dds")
    row.div:SetHeight(12)
    row.div:SetAnchor(LEFT, row, LEFT, PAD, 0)
    row.div:SetAnchor(RIGHT, row, RIGHT, -PAD, 0)

    row.icon = Tex(row)
    row.icon:SetDrawLevel(3)
    -- dark middle over the icon: turns a dot into an open ring (trail stops)
    row.hole = Tex(row, W.UI("dot.dds", 8))
    row.hole:SetDrawLevel(4)
    row.hole:SetAnchor(CENTER, row.icon, CENTER, 0, 0)
    row.hole:SetHidden(true)

    row.label = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.label:SetDrawLevel(3)

    row.right = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.right:SetWidth(RIGHT_W)
    row.right:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    row.right:SetDrawLevel(3)

    -- ledger style: thin gold line after a zone name, green badge behind "turn in"
    row.rule = Tex(row)
    row.rule:SetHeight(1)
    row.rule:SetDrawLevel(2)
    row.rule:SetHidden(true)
    row.pill = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
    row.pill:SetEdgeTexture("", 1, 1, 1)
    row.pill:SetCenterColor(0.24, 0.35, 0.16, 0.85)
    row.pill:SetEdgeColor(0.49, 0.72, 0.49, 0.7)
    row.pill:SetDrawLevel(2)
    row.pill:SetHidden(true)

    row.progBg = Tex(row)
    row.progBg:SetColor(1, 1, 1, 0.12)
    row.progBg:SetHeight(BAR_H)
    row.progBg:SetDrawLevel(3)
    row.prog = Tex(row)
    row.prog:SetHeight(BAR_H)
    row.prog:SetAnchor(LEFT, row.progBg, LEFT, 0, 0)
    row.prog:SetDrawLevel(4)

    row.tp = RowIcon(row)
    row.map = RowIcon(row)
    row.map:SetTexture(W.TEX .. "pin.dds")
    IdleIcon(row.tp)
    IdleIcon(row.map)

    row:SetHandler("OnMouseEnter", function(self)
        local kind = self.line and self.line.kind
        if kind == "quest" or kind == "zone" or kind == "hint" then self.hl:SetHidden(false) end
        self:SetHandler("OnUpdate", RowHover)
    end)
    row:SetHandler("OnMouseExit", function(self)
        self.hl:SetHidden(true)
        self:SetHandler("OnUpdate", nil)
        if self.hoverIcon then IdleIcon(self.hoverIcon) end
        if self.hoverIcon or self.tipState then ClearTooltip(InformationTooltip) end
        self.hoverIcon, self.tipState = nil, nil
    end)
    row:SetHandler("OnMouseUp", OnRowClick)
    row:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)
    return row
end

local function Dot(icon, color, size, alpha)
    icon:SetTexture(W.UI("dot.dds", size))
    icon:SetDimensions(size, size)
    icon:SetColor(color.r, color.g, color.b, alpha or 1)
end

local function ProgressBar(row, x, y, w, fraction)
    row.progBg:ClearAnchors()
    row.progBg:SetAnchor(TOPLEFT, row, TOPLEFT, x, y)
    row.progBg:SetWidth(w)
    row.prog:SetWidth(math.max(1, w * fraction))
    row.progBg:SetHidden(false)
    row.prog:SetHidden(false)
end

-- Fills a row for a line; returns its height.
local function SetupRow(row, line, width)
    local sv = W.sv.tracker
    local fs = sv.fontSize
    local label, right, icon = row.label, row.right, row.icon
    row.line = line
    -- accent colors set here so a new accent color applies at once
    local t = C.theme
    row.hl:SetColor(t.r, t.g, t.b, 0.10)
    row.bar:SetColor(t.r, t.g, t.b, 1)
    row.prog:SetColor(t.r, t.g, t.b, 1)
    row.div:SetColor(W.RGBA(C.gold))
    row.bar:SetHidden(true)
    row.div:SetHidden(true)
    row.tp:SetHidden(true)
    row.map:SetHidden(true)
    row.progBg:SetHidden(true)
    row.prog:SetHidden(true)
    row.rule:SetHidden(true)
    row.pill:SetHidden(true)
    icon:SetHidden(false)
    label:SetHidden(false)
    icon:SetTextureRotation(0)
    icon:ClearAnchors()
    label:ClearAnchors()
    right:ClearAnchors()
    right:SetAnchor(TOPRIGHT, row, TOPRIGHT, -PAD, 3)
    right:SetText("")
    row.tp:ClearAnchors()
    row.map:ClearAnchors()

    if line.kind == "divider" then
        -- just a little space after the card (the gold line there was too much)
        icon:SetHidden(true)
        label:SetHidden(true)
        return 6
    end

    local labelX, maxLines, font
    local reserve = 0   -- room kept free on the right of the label
    local tpShown = false
    local trail = sv.panelStyle == "trail"
    local ledger = sv.panelStyle == "ledger"
    row.nodeGap = nil   -- set for rows with a ring on the trail
    row.hole:SetHidden(true)
    row.railA:SetHidden(true)
    row.railB:SetHidden(true)
    if line.kind == "section" then
        font, maxLines, labelX = W.Font("title", fs - 4), 1, PAD
        icon:SetHidden(true)
        label:SetColor(t.r, t.g, t.b, 0.9)
        label:SetText(line.text)
    elseif line.kind == "hint" then
        font, maxLines, labelX = W.Font("text", fs - 2), 2, PAD + INDENT + 14
        icon:SetTexture(W.Dungeon.ICON)
        icon:SetDimensions(18, 18)
        icon:SetColor(1, 1, 1, 1)
        label:SetColor(W.RGBA(t))
        label:SetText(line.text)
    elseif line.kind == "footer" then
        -- distance · time · step progress (text set in UpdateDistance), icons on the right
        font, maxLines, labelX = W.Font("title", fs - 3), 1, PAD + INDENT - 2
        icon:SetHidden(true)
        label:SetColor(W.RGBA(t))
        label:SetText(" ")
        local q = line.quest
        row.tp:SetTexture(ActionIcon(q))
        -- (no join icon while you're already in a PvP zone)
        row.tp:SetHidden(not sv.showTeleport or (q.pvp and not q.dungeon and IsInAvAZone()))
        row.map:SetHidden(false)
        reserve = ICON * 2 + 16
        tpShown = true
    elseif line.kind == "zone" then
        -- on the trail the zone's arrow sits on the line, like a quest's ring
        font, maxLines, labelX = W.Font("title", fs - 4), 1, trail and (PAD + INDENT - 2) or (PAD + 14)
        if trail then row.nodeGap = 6 end
        icon:SetTexture(W.UI("arrow.dds", 9))
        icon:SetDimensions(9, 9)
        icon:SetTextureRotation(line.collapsed and (-math.pi / 2) or math.pi)
        -- "Ready to turn in" header in green, the others in the accent color
        local zc = line.special == "turnin" and C.done or t
        icon:SetColor(zc.r, zc.g, zc.b, 0.8)
        label:SetColor(zc.r, zc.g, zc.b, ledger and 0.8 or 0.9)
        label:SetText(zo_strupper(line.text))
        right:SetFont(W.Font("text", fs - 3))
        right:SetColor(W.RGBA(C.dim))
        if line.collapsed then
            right:SetText(tostring(line.count))
            reserve = RIGHT_W
        end
    elseif line.kind == "quest" then
        font, maxLines, labelX = W.Font("quest", fs), 2, PAD + INDENT - 2
        right:SetFont(W.Font("text", fs - 3))
        reserve = RIGHT_W
        if line.followed then
            -- card title: name + badge
            icon:SetTexture(W.UI((line.turnIn and "check.dds" or "arrow.dds"), 13))
            icon:SetDimensions(13, 13)
            icon:SetColor(W.RGBA(line.turnIn and C.done or t))
            row.bar:SetHidden(trail)
            label:SetColor(W.RGBA(C.bright))
            if trail then
                -- the quest you follow: a filled gold stop on the trail, name a bit bigger
                font = W.Font("quest", fs + 1)
                row.nodeGap = 8
                if not line.turnIn then
                    icon:SetTexture(W.UI("dot.dds", 12))
                    icon:SetDimensions(12, 12)
                end
                label:SetColor(W.RGBA(C.cream))
            end
            local badge, color = Badge(line)
            if badge then
                right:SetColor(W.RGBA(color))
                right:SetText(badge)
            end
        else
            local tp = sv.showTeleport and (line.dungeon or not line.pvp or not IsInAvAZone())
            if tp then
                right:ClearAnchors()
                right:SetAnchor(TOPRIGHT, row, TOPRIGHT, -PAD - ICON - 4, 3)
                reserve = reserve + ICON + 4
                row.tp:SetTexture(ActionIcon(line))
                row.tp:SetHidden(false)
                tpShown = true
            end
            if trail then row.nodeGap = 7 end
            if line.turnIn then
                icon:SetTexture(W.UI("check.dds", 13))
                icon:SetDimensions(13, 13)
                icon:SetColor(W.RGBA(C.done))
                label:SetColor(W.RGBA(C.done))
                right:SetColor(W.RGBA(C.done))
                right:SetText(L("TURN_IN"))
            else
                local c = line.story and C.story or ((line.repeatable or line.dungeonQuest) and t or C.dim)
                if trail then
                    -- an open stop on the trail: a dot with a dark middle
                    Dot(icon, c, 11)
                    row.hole:SetDimensions(6, 6)
                    row.hole:SetColor(C.hole.r, C.hole.g, C.hole.b, 1)
                    row.hole:SetHidden(false)
                else
                    Dot(icon, c, 9)
                end
                label:SetColor(W.RGBA(line.story and C.story or C.quest))
                right:SetColor(W.RGBA(C.dim))   -- distance, set in UpdateDistance
            end
        end
        label:SetText(line.name .. (line.rewards or ""))   -- + skill point / item reward icons
    else
        font, maxLines, labelX = W.Font("text", fs - 2), 3, PAD + INDENT + 14
        if line.done then
            icon:SetTexture(W.UI("check.dds", 12))
            icon:SetDimensions(12, 12)
            icon:SetColor(W.RGBA(C.done))
            label:SetColor(W.RGBA(C.dim))
        else
            local c = line.optional and C.optional or C.text
            local nt = W.Nav.state.target
            if line.qi == W.Nav.state.questIndex and nt and nt.kind == "quest" and nt.text == line.text then
                -- the objective the arrow is heading to
                icon:SetTexture(W.UI("arrow.dds", 9))
                icon:SetDimensions(9, 9)
                icon:SetTextureRotation(-math.pi / 2)
                icon:SetColor(W.RGBA(t))
                label:SetColor(W.RGBA(t))
            else
                Dot(icon, c, 6, 0.8)
                label:SetColor(W.RGBA(c))
            end
        end
        local text = line.text
        if line.optional then text = L("OPTIONAL") .. ": " .. text end
        label:SetText(text)
        right:SetFont(W.Font("text", fs - 3))
        right:SetColor(W.RGBA(line.done and C.done or C.dim))
        if line.counter then
            right:SetText(line.counter)
            reserve = RIGHT_W
        end
    end

    label:SetFont(font)
    label:SetMaxLineCount(maxLines)
    local labelW = width - labelX - PAD - reserve
    label:SetWidth(labelW)
    label:SetAnchor(TOPLEFT, row, TOPLEFT, labelX, 2)
    local lineH = label:GetFontHeight()
    local h = math.min(label:GetTextHeight(), lineH * maxLines)
    icon:SetAnchor(CENTER, row, TOPLEFT, labelX - 10, 2 + lineH / 2)
    row.nodeY = 2 + lineH / 2

    if ledger and line.kind == "zone" then
        -- zone name, then a faint gold line to the right edge (or to the count)
        local x = labelX + math.min(label:GetTextWidth(), labelW) + 8
        local endX = line.collapsed and (right:GetTextWidth() + 8) or 0
        if width - PAD - endX - x > 10 then
            row.rule:ClearAnchors()
            row.rule:SetAnchor(LEFT, row, TOPLEFT, x, 2 + lineH / 2)
            row.rule:SetAnchor(RIGHT, row, TOPRIGHT, -PAD - endX, 2 + lineH / 2)
            local rc = line.special == "turnin" and C.done or t
            row.rule:SetColor(rc.r, rc.g, rc.b, 0.3)
            row.rule:SetHidden(false)
        end
    elseif ledger and line.kind == "quest" and line.turnIn and right:GetText() ~= "" then
        -- "turn in" on a small green badge
        local tw, th = right:GetTextWidth(), right:GetFontHeight()
        row.pill:ClearAnchors()
        row.pill:SetAnchor(TOPRIGHT, right, TOPRIGHT, 5, -1)
        row.pill:SetDimensions(tw + 10, th + 2)
        row.pill:SetHidden(false)
        right:SetColor(0.81, 0.91, 0.69, 1)
    end

    if tpShown then
        local cy = 2 + lineH / 2
        if line.kind == "footer" then
            row.map:SetAnchor(RIGHT, row, TOPRIGHT, -PAD, cy)
            row.tp:SetAnchor(RIGHT, row.map, LEFT, -8, 0)
        else
            row.tp:SetAnchor(RIGHT, row, TOPRIGHT, -PAD, cy)
        end
    end

    -- progress bars: objectives with a counter, and the step in the card footer
    if line.kind == "cond" and line.progress and not line.done then
        ProgressBar(row, labelX, h + 4, math.min(labelW, 160), line.progress)
        h = h + BAR_H + 3
    elseif line.kind == "footer" and line.total > 1 then
        ProgressBar(row, labelX, h + 4, width - labelX - PAD, line.done / line.total)
        h = h + BAR_H + 3
    end

    if line.kind == "section" then return h + 4 end
    if line.kind == "hint" then return math.max(h, 18) + 4 end
    if line.kind == "zone" then return h + 10 end
    if line.kind == "quest" then return h + 6 end
    if line.kind == "footer" then return math.max(h, ICON) + 8 end
    return h + 4
end

-- ---------------------------------------------------------------------------
-- Layout

-- Standard spot (until you move it): DEFAULT_RIGHT from the screen's right edge, top
-- at DEFAULT_TOP of the screen height, so it lands the same on every resolution.
-- (release layout 2026-09-30, on a 1920 x 1080 UI: right edge at 1920, top at 283)
local DEFAULT_RIGHT = 0
local DEFAULT_TOP = 283 / 1080

local function Place()
    local sv = W.sv.tracker
    ui.win:ClearAnchors()
    ui.win:SetAnchor(TOPRIGHT, GuiRoot, TOPLEFT, sv.x or (GuiRoot:GetWidth() - DEFAULT_RIGHT),
        sv.y or zo_round(GuiRoot:GetHeight() * DEFAULT_TOP))
end

-- The tracker window (the launcher's standard spot sits right above it).
function Tracker.Window()
    return ui.win
end

local function UpdateTabs()
    local sv = W.sv.tracker
    -- five tabs: smaller letters and gaps when the panel is narrow
    local room = sv.width - PAD * 2
    local size, gap = 13, 14   -- (13: Trajan's thin strokes stay sharp; shrinks when narrow)
    while true do
        local total = 0
        for _, tab in ipairs(ui.tabs) do
            tab.label:SetFont(W.Font("title", size, true))
            tab.label:SetText(L("TAB_" .. zo_strupper(tab.id), ui.counts[tab.id] or 0))
            total = total + tab.label:GetTextWidth() + gap
        end
        if total - gap <= room or size <= 10 then break end
        size, gap = size - 1, math.max(8, gap - 3)
    end
    local x = PAD
    for _, tab in ipairs(ui.tabs) do
        tab.label:ClearAnchors()
        tab.label:SetAnchor(LEFT, ui.tabBar, LEFT, x, 0)
        local w = tab.label:GetTextWidth()
        tab.line:SetWidth(w)
        x = x + w + gap
    end
    Tracker.PaintTabs()
end

-- Colors only: the chosen tab gold with its underline; the tab under the mouse
-- bright with a faint underline (shows it can be clicked); the others beige.
local TAB_HOVER = C.hover
function Tracker.PaintTabs()
    local current = W.sv.tracker.tab or "all"
    for _, tab in ipairs(ui.tabs) do
        local active = current == tab.id
        local hover = not active and ui.hoverTab == tab
        tab.label:SetColor(W.RGBA((active and C.theme) or (hover and TAB_HOVER) or HEADER_TEXT))
        tab.line:SetHidden(not active and not hover)
        tab.line:SetColor(C.theme.r, C.theme.g, C.theme.b, active and 1 or 0.45)
    end
end

local function UpdateHeader()
    local sv = W.sv.tracker
    ui.title:SetFont(W.Font("title", 16))
    ui.count:SetFont(W.Font("text", 12))
    ui.count:SetText(L("TRACKER_COUNT", GetNumJournalQuests(), MAX_JOURNAL_QUESTS))
    -- padlock: body + moving shackle once those images are loaded, else the old two pictures
    local newLock = W.TextureLoaded("lock_body.dds") and W.TextureLoaded("lock_shackle.dds")
    ui.btnLock.icon:SetTexture(W.UI(newLock and "lock_body.dds" or (sv.locked and "lock.dds" or "unlock.dds")))
    ui.btnLock.shackle:SetHidden(not newLock)
    ui.logo:Refresh()   -- the logo images may only have loaded now
    ui.btnSkip.icon:SetTexture(W.UI(W.TextureLoaded("skip.dds") and "skip.dds" or "chevron.dds"))
    -- narrow panel: the quest count makes room for the header buttons
    ui.count:SetHidden(sv.width < 380)
    -- crisp 32 px copies of the coin pictures (they may only have loaded now)
    for _, b in ipairs({ ui.btnMin, ui.btnPath, ui.btnSearch }) do
        if b and b.file then b.icon:SetTexture(W.UI(b.file)) end
    end
    for _, b in ipairs({ ui.btnMin, ui.btnLock, ui.btnPath, ui.btnSkip, ui.btnSearch }) do
        if b and b.ring then
            b.halo:SetTexture(W.UI("dot.dds"))
            b.fill:SetTexture(W.UI(W.TextureLoaded("disc.dds") and "disc.dds" or "dot.dds"))
            b.fill:SetColor(C.coin.r, C.coin.g, C.coin.b, 0.9)   -- (color theme)
            b.ring:SetTexture(W.UI("rim.dds"))
            b.ripple:SetTexture(W.UI("rim.dds"))
        end
    end
    ui.btnLock.shackle:SetTexture(W.UI("lock_shackle.dds"))
    for _, b in ipairs({ ui.iconBtn, ui.btnMin, ui.btnLock, ui.btnPath, ui.btnSkip, ui.btnSearch }) do
        if b and not IsOver(b) then b.idle(b.icon) end
        if b and b.animate then b.animate() end   -- coins: colors, minimize turn, shackle
    end
    local t = C.theme
    ui.title:SetColor(W.RGBA(t))
    ui.moreUp:SetColor(t.r, t.g, t.b, 0.7)
    ui.moreDown:SetColor(t.r, t.g, t.b, 0.7)
    UpdateTabs()
end

local function ApplyFrame()
    local sv = W.sv.tracker
    local eso = sv.panelStyle == "eso"
    local ledger = sv.panelStyle == "ledger"
    ui.bg:SetCenterColor(C.panel.r, C.panel.g, C.panel.b, sv.bgAlpha)
    local framed = sv.bgAlpha > 0.05
    -- ledger: a faint glassy gold edge (the corners carry the gold), else as before
    ui.bg:SetEdgeColor(C.gold.r, C.gold.g, C.gold.b, ((eso or ledger) and framed) and (ledger and 0.3 or 0.7) or 0)
    local glass = ledger and framed
    ui.outer:SetHidden(not glass)
    ui.outer:SetEdgeColor(0, 0, 0, 0.45)
    ui.shine:SetHidden(not glass)
    ui.shine:SetColor(1, 0.96, 0.86, 0.22)
    for _, t in ipairs(ui.corners) do
        t:SetHidden(not glass)
        t:SetColor(W.RGBA(C.theme))
    end
    if ledger then
        -- a warm dark card with a gold edge, clearly apart from the list
        ui.card:SetCenterColor(C.card.r, C.card.g, C.card.b, 0.35 + 0.55 * sv.bgAlpha)
        ui.card:SetEdgeColor(C.theme.r, C.theme.g, C.theme.b, 0.7)
    else
        -- the card's tint follows the background opacity too (text and icons never fade)
        ui.card:SetCenterColor(C.theme.r, C.theme.g, C.theme.b, 0.07 * math.min(1, sv.bgAlpha * 1.5))
        ui.card:SetEdgeColor(C.theme.r, C.theme.g, C.theme.b, 0.45 * math.min(1, sv.bgAlpha * 1.5 + 0.2))
    end
    ui.headRule:SetColor(C.gold.r, C.gold.g, C.gold.b, 0.8)
    ui.headRule:SetHidden(not ledger or sv.minimized)

    -- header opacity slider follows the value
    if ui.opTrack then
        local w = ui.opTrack:GetWidth()
        -- left = see-through, right = darker
        local dark = sv.bgAlpha
        ui.opFill:SetWidth(math.max(1, w * dark))
        ui.opFill:SetColor(W.RGBA(C.theme))
        ui.opKnob:SetColor(W.RGBA(C.theme))
        ui.opKnob:SetTexture(W.UI(W.TextureLoaded("diamond.dds") and "diamond.dds" or "dot.dds"))
        ui.opKnob:ClearAnchors()
        ui.opKnob:SetAnchor(CENTER, ui.opTrack, LEFT, w * dark, 0)
    end
end

-- ---------------------------------------------------------------------------
-- Background opacity slider in the header (next to the padlock)

local OP_W = 44

local function SetOpacity(v)
    v = zo_round(zo_clamp(v, 0, 1) * 20) / 20   -- steps of 5 %
    if v == W.sv.tracker.bgAlpha then return end
    W.sv.tracker.bgAlpha = v
    ApplyFrame()
end

-- background opacity for the mouse position (the slider runs see-through -> dark)
local function OpacityFromMouse()
    local mx = GetUIMousePosition()
    return (mx - ui.opTrack:GetLeft()) / ui.opTrack:GetWidth()
end

local function CreateOpacitySlider(win, anchorTo)
    local op = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.op = op
    op:SetDimensions(OP_W + 10, 20)
    op:SetAnchor(RIGHT, anchorTo, LEFT, -2, 0)
    op:SetMouseEnabled(true)
    op:SetDrawLevel(5)

    ui.opTrack = WINDOW_MANAGER:CreateControl(nil, op, CT_TEXTURE)
    ui.opTrack:SetDimensions(OP_W, 3)
    ui.opTrack:SetAnchor(LEFT, op, LEFT, 5, 0)
    ui.opTrack:SetColor(C.dim.r, C.dim.g, C.dim.b, 0.6)
    ui.opTrack:SetDrawLevel(6)

    ui.opFill = WINDOW_MANAGER:CreateControl(nil, op, CT_TEXTURE)
    ui.opFill:SetHeight(3)
    ui.opFill:SetAnchor(LEFT, ui.opTrack, LEFT, 0, 0)
    ui.opFill:SetDrawLevel(7)

    ui.opKnob = WINDOW_MANAGER:CreateControl(nil, op, CT_TEXTURE)
    -- a small gold diamond (the round dot until the new image is loaded)
    ui.opKnob:SetTexture(W.UI(W.TextureLoaded("diamond.dds") and "diamond.dds" or "dot.dds"))
    ui.opKnob:SetDimensions(10, 10)
    ui.opKnob:SetDrawLevel(8)

    op:SetHandler("OnMouseDown", function(self, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        ClearTooltip(InformationTooltip)
        SetOpacity(OpacityFromMouse())
        self:SetHandler("OnUpdate", function() SetOpacity(OpacityFromMouse()) end)
    end)
    op:SetHandler("OnMouseUp", function(self) self:SetHandler("OnUpdate", nil) end)
    op:SetHandler("OnMouseWheel", function(_, delta) SetOpacity(W.sv.tracker.bgAlpha + delta * 0.05) end)   -- wheel up = darker
    -- one short line while hovering; set once (never updated), gone when you click
    op:SetHandler("OnMouseEnter", function(self)
        if self:GetHandler("OnUpdate") then return end   -- already dragging
        InitializeTooltip(InformationTooltip, self, TOP, 0, 4, BOTTOM)
        SetTooltipText(InformationTooltip, L("TT_OPACITY"))
    end)
    op:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
end

-- ---------------------------------------------------------------------------
-- Search box (over the tab bar while open)

local function CreateSearchBox(win)
    local bg = WINDOW_MANAGER:CreateControlFromVirtual(nil, win, "ZO_EditBackdrop")
    bg:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, HEADER_H + 1)
    bg:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PAD, HEADER_H + 1)
    bg:SetHeight(TABS_H - 2)
    bg:SetDrawLevel(4)
    bg:SetHidden(true)
    local edit = WINDOW_MANAGER:CreateControlFromVirtual(nil, bg, "ZO_DefaultEditForBackdrop")
    edit:SetMaxInputChars(40)
    if edit.SetDefaultText then edit:SetDefaultText(L("SEARCH_HINT")) end
    edit:SetHandler("OnTextChanged", function(self)
        ui.search = zo_strlower(zo_strtrim(self:GetText()))
        ui.offset = 0
        Refresh()
    end)
    edit:SetHandler("OnEscape", function() Tracker.ToggleSearch(false) end)
    edit:SetHandler("OnEnter", function(self) self:LoseFocus() end)
    ui.searchBox, ui.searchEdit = bg, edit
end

-- open = true / false, nil = switch. Closing clears the search.
function Tracker.ToggleSearch(open)
    if not ui.searchEdit then return end
    if open == nil then open = not ui.searchOpen end
    ui.searchOpen = open
    if open then
        ui.searchEdit:SetFont(W.Font("text", 14))
        ui.searchBox:SetHidden(false)
        ui.searchEdit:TakeFocus()
    else
        ui.searchEdit:LoseFocus()
        ui.searchEdit:SetText("")
        ui.search = nil
    end
    ui.offset = 0
    Refresh()
end

-- Places one line at y; returns the new y, or nil when it doesn't fit.
local function PlaceLine(n, line, y, maxY, width, force)
    local row = ui.rows[n]
    if not row then
        row = CreateRow()
        ui.rows[n] = row
    end
    local h = SetupRow(row, line, width)
    if y + h > maxY and not force then
        row:SetHidden(true)
        row.line = nil
        return nil
    end
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, ui.win, TOPLEFT, 0, y)
    row:SetDimensions(width, h)
    row:SetHidden(false)
    row.y = y   -- for the height animation (rows fade in as the panel's edge passes them)
    ui.visible[#ui.visible + 1] = row
    return y + h
end

function Tracker.Layout()
    if not ui.win then return end
    local sv = W.sv.tracker
    local win = ui.win
    local width = sv.width
    win:SetWidth(width)
    win:SetResizeHandleSize(sv.locked and 0 or EDGE)
    ApplyFrame()
    UpdateHeader()

    for _, row in ipairs(ui.rows) do
        row:SetHidden(true)
        row.line = nil
    end
    ui.visible = {}
    ui.moreUp:SetHidden(true)
    ui.moreDown:SetHidden(true)
    ui.empty:SetHidden(true)
    ui.card:SetHidden(true)
    ui.sep:SetHidden(true)   -- no gold line under the tabs
    -- searching: the search box sits where the tabs are
    ui.tabBar:SetHidden(sv.minimized or ui.searchOpen)
    if ui.searchBox then ui.searchBox:SetHidden(sv.minimized or not ui.searchOpen) end

    if sv.minimized then
        Tracker.AnimateHeight(HEADER_H)
        return
    end

    local y = HEADER_H + TABS_H + 6
    local maxY = math.max(sv.maxHeight, HEADER_H + TABS_H + 80) - PAD
    local n = 0

    -- pinned card: always shown, never scrolled
    -- (ledger style: the card also holds the "FOLLOWING" title)
    local ledger = sv.panelStyle == "ledger"
    local cardTop, cardBottom
    for _, line in ipairs(ui.pinned) do
        n = n + 1
        if ledger and line.kind == "section" then
            y = y + 4
            cardTop = y - 2
        end
        if line.kind == "quest" and not cardTop then cardTop = y end
        y = PlaceLine(n, line, y, maxY, width, true)
        if line.kind == "footer" then cardBottom = y end
    end
    ui.pinnedRows = #ui.visible
    -- frameless style: no card, the followed quest stands out on the trail instead
    if cardTop and cardBottom and sv.panelStyle ~= "trail" then
        ui.card:ClearAnchors()
        ui.card:SetAnchor(TOPLEFT, win, TOPLEFT, 5, cardTop - 2)
        ui.card:SetAnchor(BOTTOMRIGHT, win, TOPRIGHT, -5, cardBottom)
        ui.card:SetHidden(false)
    end

    -- the rest scrolls
    local lines = ui.lines
    ui.moreUp:ClearAnchors()
    ui.moreUp:SetAnchor(TOP, win, TOPLEFT, width / 2, y - 3)
    ui.moreUp:SetHidden(ui.offset == 0)
    local first = true
    for i = ui.offset + 1, #lines do
        n = n + 1
        local nextY = PlaceLine(n, lines[i], y, maxY, width, first)
        if not nextY then
            ui.moreDown:SetHidden(false)
            break
        end
        y = nextY
        first = false
    end

    if #lines == 0 and #ui.pinned == 0 then
        ui.empty:SetFont(W.Font("text", 14))
        local key = ((ui.search or "") ~= "" and "TRACKER_EMPTY_SEARCH") or (sv.tab == "current" and "TRACKER_EMPTY_CURRENT")
            or (sv.tab == "main" and "TRACKER_EMPTY_MAIN") or "TRACKER_EMPTY_TAB"
        ui.empty:SetText(L(key))
        ui.empty:ClearAnchors()
        ui.empty:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, y + 2)
        ui.empty:SetHidden(false)
        y = y + 28
    end
    -- a height set by dragging the edge stays; otherwise the panel fits the list
    Tracker.AnimateHeight(sv.height and math.max(sv.height, y + PAD) or (y + PAD))
    Tracker.DrawTrail()
    Tracker.UpdateDistance()
end

-- Smooth height changes (minimize / restore, zones and quests opened or closed, tabs):
-- the panel eases to its new height and rows fade in as its bottom edge reaches them.
-- Instant with Animations: Off, on the first layout and right after a resize by hand.
local ANIM_H = 0.25

local function Reveal(h)
    for _, row in ipairs(ui.visible or {}) do
        local rh = math.max(1, row:GetHeight())
        row.revealA = zo_clamp((h - PAD / 2 - (row.y or 0)) / rh, 0, 1)
        if not row.fadeStart then row:SetAlpha(row.revealA) end
    end
end

-- Rows that weren't on screen in the last layout fade in (0.25 s) instead of
-- popping up: while dragging the panel bigger, and after the height animation.
local FADE_IN = 0.25

local function RowKey(line)
    return table.concat({ line.kind or "", tostring(line.qi or ""), line.text or line.name or "" }, "|")
end

local function FadeTick()
    local now, busy = GetFrameTimeSeconds(), false
    for _, row in ipairs(ui.visible or {}) do
        if row.fadeStart then
            local a = zo_clamp((now - row.fadeStart) / FADE_IN, 0, 1)
            row:SetAlpha(math.min(a, row.revealA or 1))
            if a >= 1 then row.fadeStart, row.fadeKey = nil, nil else busy = true end
        end
    end
    if not busy then EVENT_MANAGER:UnregisterForUpdate("Questbound_TrackerFade") end
end

-- After each layout: rows showing a line that wasn't on screen before start fading in;
-- a reused row that now shows an old line stops fading. (First layout: no fades.)
local function FadeNewRows()
    local keys, now, any = {}, GetFrameTimeSeconds(), false
    for _, row in ipairs(ui.visible or {}) do
        local key = row.line and RowKey(row.line)
        if key then keys[key] = true end
        local isNew = key and ui.prevKeys and not ui.prevKeys[key] and W.sv.anim ~= "off"
        if isNew and row.fadeKey ~= key then
            row.fadeStart, row.fadeKey = now, key
            row:SetAlpha(0)
        elseif not isNew and row.fadeStart then
            row.fadeStart, row.fadeKey = nil, nil
            row:SetAlpha(row.revealA or 1)
        end
        if row.fadeStart then any = true end
    end
    ui.prevKeys = keys
    if any then EVENT_MANAGER:RegisterForUpdate("Questbound_TrackerFade", 0, FadeTick) end
end

local Animate

function Tracker.AnimateHeight(target)
    Animate(target)
    FadeNewRows()
end

Animate = function(target)
    local win = ui.win
    if ui.resizing then
        -- dragging the edge: the mouse sets the height
        ui.shownH, ui.animTo = win:GetHeight(), win:GetHeight()
        for _, row in ipairs(ui.visible or {}) do
            row.revealA = 1
            if not row.fadeStart then row:SetAlpha(1) end
        end
        return
    end
    if not ui.shownH or W.sv.anim == "off" then
        win:SetHandler("OnUpdate", nil)
        ui.animating = false
        ui.shownH, ui.animTo = target, target
        win:SetHeight(target)
        Reveal(target + PAD)
        return
    end
    if ui.animating and target == ui.animTo then
        Reveal(ui.shownH)   -- same goal, new rows: show them as far as the edge is
        return
    end
    if not ui.animating and math.abs(target - ui.shownH) < 1 then
        win:SetHeight(target)
        Reveal(target + PAD)
        return
    end
    ui.animFrom, ui.animTo, ui.animStart, ui.animating = ui.shownH, target, GetFrameTimeSeconds(), true
    win:SetHandler("OnUpdate", function(self)
        local p = math.min(1, (GetFrameTimeSeconds() - ui.animStart) / ANIM_H)
        local e = 1 - (1 - p) ^ 3   -- ease out: quick start, gentle stop
        ui.shownH = ui.animFrom + (ui.animTo - ui.animFrom) * e
        self:SetHeight(ui.shownH)
        if p >= 1 then
            self:SetHandler("OnUpdate", nil)
            ui.animating = false
            Reveal(ui.shownH + PAD)
        else
            Reveal(ui.shownH)
        end
    end)
end

-- Frameless style: one gold line down the left, from the first quest's stop through
-- every row, broken around each stop. Bright along the followed quest, faint below.
local TRAIL_X = PAD + INDENT - 13   -- the stops' center (labelX - 10 = 18), minus half the line
function Tracker.DrawTrail()
    local trail = W.sv.tracker.panelStyle == "trail"
    local t = C.theme
    local started = false
    local function Seg(tex, row, top, bottom, a)
        if bottom - top < 1 then return end
        tex:ClearAnchors()
        tex:SetAnchor(TOPLEFT, row, TOPLEFT, TRAIL_X, top)
        tex:SetHeight(bottom - top)
        tex:SetColor(t.r, t.g, t.b, a)
        tex:SetHidden(false)
    end
    for i, row in ipairs(ui.visible) do
        row.railA:SetHidden(true)
        row.railB:SetHidden(true)
        local kind = row.line and row.line.kind
        if trail and kind ~= "section" then
            local a = (i <= (ui.pinnedRows or 0)) and 0.85 or 0.35
            local h = row:GetHeight()
            if row.nodeGap then
                local y = row.nodeY
                if started then Seg(row.railA, row, 0, y - row.nodeGap, a) end
                Seg(row.railB, row, y + row.nodeGap, h, a)
                started = true
            elseif started then
                Seg(row.railA, row, 0, h, a)
            end
        end
    end
end


-- Distances (every 250 ms): card footer and the other quests on this map.
function Tracker.UpdateDistance()
    if not ui.visible then return end
    local nav = W.Nav.state
    local sv = W.sv.tracker
    for _, row in ipairs(ui.visible) do
        local line = row.line
        if line and line.kind == "footer" then
            local parts, hasDest = {}, false
            if nav.target and nav.target.kind == "quest" and nav.questIndex == line.qi then
                if nav.arrived then
                    parts[#parts + 1] = "|c7DB87D" .. L("ARRIVED") .. "|r"
                elseif nav.dist and sv.showDistance then
                    parts[#parts + 1] = W.FormatDistance(nav.dist)
                end
                -- through a door / to the next area: where it really leads
                -- (only the place, not ", zone": the card is narrow)
                local dest = nav.target.other and not nav.arrived and W.Nav.DestinationName(line.qi)
                if dest then
                    parts[#parts + 1] = "› " .. (dest:match("^(.-),") or dest)
                    hasDest = true
                end
                -- up or down a floor (compass): "Upstairs" / "Downstairs"
                local level = nav.targetLevel
                if not nav.arrived and (level == "above" or level == "below") then
                    local text = L(level == "above" and "LEVEL_ABOVE" or "LEVEL_BELOW"):gsub("^·%s*", "")
                    parts[#parts + 1] = text
                end
            end
            -- "1 of 3 done": left out when a destination is shown (the progress bar under the
            -- line shows it anyway), so the line fits the card
            if line.total > 1 and not hasDest then
                parts[#parts + 1] = "|c8E8C86" .. L("ARROW_PROGRESS", line.done, line.total) .. "|r"
            end
            local text = table.concat(parts, "  ·  ")
            if row.label:GetText() ~= text then row.label:SetText(text) end
        elseif line and line.kind == "quest" and not line.followed and not line.turnIn and sv.showDistance then
            local d = W.Nav.QuestDistance(line.qi)
            local text = d and W.FormatDistance(d) or ""
            if row.right:GetText() ~= text then row.right:SetText(text) end
        end
    end
end

local function UpdateFade()
    if not ui.win then return end
    local over = IsOver(ui.win)
    local fade = W.sv.combatFade and inCombat and not over
    ui.win:SetAlpha(fade and 0.3 or 1)
    -- frameless style: header buttons and tabs step back until the mouse comes over
    local quiet = W.sv.tracker.panelStyle == "trail" and not over
    local a = quiet and 0.35 or 1
    for _, c in ipairs({ ui.iconBtn, ui.count, ui.btnMin, ui.btnLock, ui.btnPath, ui.btnSkip, ui.btnSearch, ui.op, ui.tabBar }) do
        if c then c:SetAlpha(a) end
    end
end

Refresh = function()
    if not ui.win then return end
    Build()
    Tracker.Layout()
end
Tracker.Refresh = Refresh

function Tracker.Apply()
    local sv = W.sv.tracker
    W.ShowOnHud(ui.fragment, sv.shown)
    ApplyGameTracker()
    ApplyAuiTracker()
    Refresh()
end

-- ---------------------------------------------------------------------------
-- Window

-- Header buttons as gold-ring coins (sketch A): dark disc + gold rim behind the icon,
-- a soft gold halo fading in on hover (6), a gold ring rippling out on click (1).
-- b.extraTick(b, dt) animates more (minimize turn, lock shackle); returns true while busy.
local COIN = 22
local COIN_GAP = 3

local function CoinTick(b)
    local now = GetFrameTimeSeconds()
    local dt = b.lastTick and (now - b.lastTick) or 0
    b.lastTick = now
    local instant = W.sv.anim == "off"
    local busy = false
    if instant then
        b.hover = b.hoverTo
    else
        b.hover = b.hover + (b.hoverTo - b.hover) * math.min(1, dt * 12)
        if math.abs(b.hover - b.hoverTo) > 0.01 then busy = true else b.hover = b.hoverTo end
    end
    local t = C.theme
    b.ring:SetColor(t.r, t.g, t.b, 0.55 + 0.45 * b.hover)
    b.halo:SetColor(t.r, t.g, t.b, 0.35 * b.hover)
    if b.rippleAt then
        local p = (now - b.rippleAt) / 0.45
        if p >= 1 or instant then
            b.ripple:SetHidden(true)
            b.rippleAt = nil
        else
            local s = COIN * (1 + 0.8 * p)
            b.ripple:SetDimensions(s, s)
            b.ripple:SetColor(1, 0.85, 0.55, 0.8 * (1 - p))
            b.ripple:SetHidden(false)
            busy = true
        end
    end
    if b.extraTick and b.extraTick(b, dt, instant) then busy = true end
    if not busy then
        b:SetHandler("OnUpdate", nil)
        b.lastTick = nil
    end
end

local function Animate(b)
    b.lastTick = nil
    b:SetHandler("OnUpdate", CoinTick)
end

local function Coin(b, iconSize)
    b:SetDimensions(COIN, COIN)
    b.icon:SetDimensions(iconSize, iconSize)
    b.icon:SetDrawLevel(9)
    local function Part(file, level)
        local t = WINDOW_MANAGER:CreateControl(nil, b, CT_TEXTURE)
        t:SetTexture(W.UI(file))   -- (crisp 32 px copy)
        t:SetAnchor(CENTER, b, CENTER, 0, 0)
        t:SetDimensions(COIN, COIN)
        t:SetDrawLevel(level)
        t:SetMouseEnabled(false)
        return t
    end
    b.halo = Part("dot.dds", 5)
    b.halo:SetDimensions(COIN * 1.8, COIN * 1.8)
    b.fill = Part(W.TextureLoaded("disc.dds") and "disc.dds" or "dot.dds", 6)
    b.fill:SetColor(C.coin.r, C.coin.g, C.coin.b, 0.9)
    b.ring = Part("rim.dds", 7)
    b.ripple = Part("rim.dds", 8)
    b.ripple:SetHidden(true)
    b.hover, b.hoverTo = 0, 0
    b.animate = function() Animate(b) end
    ZO_PostHookHandler(b, "OnMouseEnter", function() b.hoverTo = 1; Animate(b) end)
    ZO_PostHookHandler(b, "OnMouseExit", function() b.hoverTo = 0; Animate(b) end)
    CoinTick(b)
end

local function Ripple(b)
    if not b or not b.ripple then return end
    b.rippleAt = GetFrameTimeSeconds()
    Animate(b)
end

local function HeaderButton(file, size, tooltip, onClick)
    local b
    b = IconButton(ui.win, W.UI(file), size, tooltip, function()
        Ripple(b)
        onClick()
        UpdateHeader()
    end)
    Coin(b, size)
    b.file = file   -- (UpdateHeader swaps in the crisp copy once it's loaded)
    return b
end

local function SelectTab(id)
    W.sv.tracker.tab = id
    ui.offset = 0
    PlaySound(SOUNDS.DEFAULT_CLICK)
    Refresh()
end

function Tracker.Init()
    local sv = W.sv.tracker
    if sv.zoneOnly then   -- before tabs: "this zone only" = the Here tab
        sv.tab = "here"
        sv.zoneOnly = nil
    end

    local win = WINDOW_MANAGER:CreateTopLevelWindow("Questbound_Tracker")
    ui.win = win
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetDimensionConstraints(300, HEADER_H, 700, 1400)   -- 300: room for the six tabs
    -- resizing by hand: the list follows the edge while you drag (quests that come
    -- into view fade in, see FadeNewRows); no height animation fighting the mouse
    win:SetHandler("OnResizeStart", function(self)
        ui.animating = false
        ui.resizing = true
        local lastW, lastH = self:GetWidth(), self:GetHeight()
        self:SetHandler("OnUpdate", function()
            local w, h = self:GetWidth(), self:GetHeight()
            if math.abs(w - lastW) + math.abs(h - lastH) < 2 then return end
            lastW, lastH = w, h
            local s = W.sv.tracker
            s.width = zo_round(w)
            if not s.minimized then
                s.height = math.max(140, zo_round(h))
                s.maxHeight = s.height
            end
            Tracker.Layout()
        end)
    end)
    win:SetHandler("OnResizeStop", function(self)
        local s = W.sv.tracker
        self:SetHandler("OnUpdate", nil)
        ui.resizing = false
        ui.shownH = self:GetHeight()
        s.width = zo_round(self:GetWidth())
        if not s.minimized then
            -- the size you drag it to stays (it used to shrink back to the list's height)
            s.height = math.max(140, zo_round(self:GetHeight()))
            s.maxHeight = s.height
        end
        s.x, s.y = self:GetRight(), self:GetTop()
        Place()
        Tracker.Layout()
    end)
    win:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)

    -- frame: dark panel; "eso" style adds a thin gold border
    ui.bg = WINDOW_MANAGER:CreateControl(nil, win, CT_BACKDROP)
    ui.bg:SetAnchorFill(win)
    ui.bg:SetEdgeTexture("", 1, 1, 1)
    ui.bg:SetDrawLevel(0)

    -- ledger frame, sketch 6 "glass + corners": a soft dark line just outside the panel,
    -- a faint light line along the inside of the top edge, and small gold L-corners
    -- (plain colored rectangles, no image needed)
    ui.outer = WINDOW_MANAGER:CreateControl(nil, win, CT_BACKDROP)
    ui.outer:SetAnchor(TOPLEFT, win, TOPLEFT, -1, -1)
    ui.outer:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, 1, 1)
    ui.outer:SetEdgeTexture("", 1, 1, 1)
    ui.outer:SetCenterColor(0, 0, 0, 0)
    ui.outer:SetDrawLevel(0)
    ui.shine = Tex(win)
    ui.shine:SetHeight(1)
    ui.shine:SetAnchor(TOPLEFT, win, TOPLEFT, 1, 1)
    ui.shine:SetAnchor(TOPRIGHT, win, TOPRIGHT, -1, 1)
    ui.shine:SetDrawLevel(1)
    ui.corners = {}
    for _, c in ipairs({ { TOPLEFT, 1, 1 }, { TOPRIGHT, -1, 1 }, { BOTTOMLEFT, 1, -1 }, { BOTTOMRIGHT, -1, -1 } }) do
        local point, sx, sy = c[1], c[2], c[3]
        -- each corner: a flat bar and an upright bar meeting at the panel's corner
        local across = Tex(win)
        across:SetDimensions(CORNER, 2)
        across:SetAnchor(point, win, point, -sx, -sy)
        local down = Tex(win)
        down:SetDimensions(2, CORNER)
        down:SetAnchor(point, win, point, -sx, -sy)
        for _, t in ipairs({ across, down }) do
            t:SetDrawLevel(6)
            ui.corners[#ui.corners + 1] = t
        end
    end

    -- card behind the followed quest
    ui.card = WINDOW_MANAGER:CreateControl(nil, win, CT_BACKDROP)
    ui.card:SetEdgeTexture("", 1, 1, 1)
    ui.card:SetDrawLevel(1)
    ui.card:SetHidden(true)

    -- Dragging by the header. The window itself isn't movable: in ESO a movable
    -- window takes the clicks of the buttons on it (same as Set Hunter's launcher).
    local drag = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    drag:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
    drag:SetAnchor(BOTTOMRIGHT, win, TOPRIGHT, 0, HEADER_H)
    drag:SetMouseEnabled(true)
    drag:SetHitInsets(EDGE, EDGE, -EDGE, 0)   -- top edge and corners stay resize handles
    drag:SetDrawLevel(1)
    local dx, dy, startX, startY
    local function DragUpdate()
        local mx, my = GetUIMousePosition()
        win:ClearAnchors()
        win:SetAnchor(TOPRIGHT, GuiRoot, TOPLEFT, mx + dx, my + dy)
    end
    drag:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local mx, my = GetUIMousePosition()
        startX, startY = mx, my
        if W.sv.tracker.locked then return end
        dx, dy = win:GetRight() - mx, win:GetTop() - my
        drag:SetHandler("OnUpdate", DragUpdate)
    end)
    drag:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local mx, my = GetUIMousePosition()
        local moved = startX and (math.abs(mx - startX) + math.abs(my - startY)) > 4
        if dx then
            drag:SetHandler("OnUpdate", nil)
            dx, dy = nil, nil
            W.sv.tracker.x, W.sv.tracker.y = win:GetRight(), win:GetTop()
            Place()
        end
        -- a click (not a drag) on a header button that didn't get the click itself
        if not moved then
            if IsOver(ui.op, 2) then SetOpacity(OpacityFromMouse()) end
            for _, b in ipairs({ ui.iconBtn, ui.btnMin, ui.btnLock, ui.btnPath, ui.btnSkip, ui.btnSearch }) do
                if IsOver(b, 2) then
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                    b.onClick()
                    break
                end
            end
        end
    end)
    drag:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)

    -- header: Questbound logo (opens the settings), title, quest count, buttons.
    -- The logo's gold part takes the button's icon role (tinted, white on hover).
    ui.iconBtn = IconButton(win, W.TEX .. "compass.dds", 22,
        function() return L("TT_SETTINGS") end,
        function() W.OpenSettings() end)
    ui.iconBtn:SetAnchor(LEFT, win, TOPLEFT, PAD - 5, HEADER_H / 2)
    ui.iconBtn.icon:SetHidden(true)
    ui.logo = W.Logo(ui.iconBtn, 22, 5)
    ui.logo:SetAnchor(CENTER, ui.iconBtn, CENTER, 0, 0)
    ui.iconBtn.icon = ui.logo.gold
    ui.iconBtn.idle = function(tex) tex:SetColor(W.RGBA(C.theme)) end

    ui.title = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
    ui.title:SetText(L("TRACKER_TITLE"))
    ui.title:SetAnchor(LEFT, ui.iconBtn, RIGHT, 4, 1)
    ui.title:SetDrawLevel(3)

    ui.count = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
    ui.count:SetColor(W.RGBA(HEADER_TEXT))
    ui.count:SetAnchor(LEFT, ui.title, RIGHT, 7, 1)
    ui.count:SetDrawLevel(3)

    ui.btnMin = HeaderButton("arrow.dds", 10,
        function() return L(W.sv.tracker.minimized and "TT_RESTORE" or "TT_MINIMIZE") end,
        function()
            W.sv.tracker.minimized = not W.sv.tracker.minimized
            Tracker.Layout()
        end)
    ui.btnMin:SetAnchor(RIGHT, win, TOPRIGHT, -PAD + 1, HEADER_H / 2)
    -- (2) the arrow turns smoothly between up (open) and down (minimized)
    ui.btnMin.rot = W.sv.tracker.minimized and math.pi or 0
    ui.btnMin.extraTick = function(b, dt, instant)
        local target = W.sv.tracker.minimized and math.pi or 0
        b.rot = instant and target or (b.rot + (target - b.rot) * math.min(1, dt * 10))
        if math.abs(target - b.rot) < 0.01 then b.rot = target end
        b.icon:SetTextureRotation(b.rot)
        return b.rot ~= target
    end

    -- (3) padlock in two parts: the shackle lifts when unlocked and snaps down when locked
    ui.btnLock = HeaderButton("lock_body.dds", 14,
        function()
            local locked = W.sv.tracker.locked
            return L(locked and "TT_UNLOCK" or "TT_LOCK", W.State(locked, locked and "STATE_LOCKED" or "STATE_UNLOCKED"))
        end,
        function()
            W.sv.tracker.locked = not W.sv.tracker.locked
            Tracker.Layout()
        end)
    ui.btnLock:SetAnchor(RIGHT, ui.btnMin, LEFT, -COIN_GAP, 0)
    local lb = ui.btnLock
    -- locked = gold (easy to see why the panel won't move), unlocked = grey
    lb.idle = function(tex)
        if W.sv.tracker.locked then tex:SetColor(W.RGBA(C.theme)) else tex:SetColor(W.RGBA(C.dim)) end
    end
    lb.shackle = WINDOW_MANAGER:CreateControl(nil, lb, CT_TEXTURE)
    lb.shackle:SetTexture(W.UI("lock_shackle.dds"))
    lb.shackle:SetDimensions(14, 14)
    lb.shackle:SetDrawLevel(9)
    lb.shackle:SetMouseEnabled(false)
    lb.lift = W.sv.tracker.locked and 0 or -3
    lb.extraTick = function(b, dt, instant)
        local target = W.sv.tracker.locked and 0 or -3
        b.lift = instant and target or (b.lift + (target - b.lift) * math.min(1, dt * 14))
        if math.abs(target - b.lift) < 0.05 then b.lift = target end
        b.shackle:ClearAnchors()
        b.shackle:SetAnchor(CENTER, b.icon, CENTER, 0, b.lift)
        b.shackle:SetColor(b.icon:GetColor())
        return b.lift ~= target
    end

    -- arrows on the ground on / off: gold when shown, grey when hidden
    ui.btnPath = HeaderButton("chevron.dds", 12,
        function()
            local on = W.sv.path.shown
            return L(on and "TT_PATH_HIDE" or "TT_PATH_SHOW", W.State(on, on and "STATE_ON" or "STATE_OFF"))
        end,
        function()
            W.sv.path.shown = not W.sv.path.shown
            W.callbacks:FireCallbacks("SettingsChanged")
        end)
    ui.btnPath.idle = function(tex)
        if W.sv.path.shown then
            tex:SetColor(W.RGBA(C.theme))
        else
            tex:SetColor(C.dim.r, C.dim.g, C.dim.b, 0.45)
        end
    end
    ui.btnPath:SetAnchor(RIGHT, ui.btnLock, LEFT, -COIN_GAP, 0)

    -- skip dialogs on / off (speech bubble with »): gold when on, grey when off
    ui.btnSkip = HeaderButton(W.TextureLoaded("skip.dds") and "skip.dds" or "chevron.dds", 14,
        function() return W.Skip.Tooltip() end,
        function() W.Skip.Toggle() end)
    ui.btnSkip.idle = function(tex)
        if W.Skip.IsOn() then
            tex:SetColor(W.RGBA(C.theme))
        else
            tex:SetColor(C.dim.r, C.dim.g, C.dim.b, 0.45)
        end
    end
    ui.btnSkip:SetAnchor(RIGHT, ui.btnPath, LEFT, -COIN_GAP, 0)

    -- search: the magnifier opens a search box over the tabs; typing filters every
    -- quest by name or zone (all tabs). Click the magnifier again or Escape: closed and cleared.
    ui.btnSearch = HeaderButton("search.dds", 12,
        function() return L(ui.searchOpen and "TT_SEARCH_CLOSE" or "TT_SEARCH") end,
        function() Tracker.ToggleSearch() end)
    ui.btnSearch.idle = function(tex)
        if ui.searchOpen then tex:SetColor(W.RGBA(C.theme)) else tex:SetColor(W.RGBA(C.dim)) end
    end
    ui.btnSearch:SetAnchor(RIGHT, ui.btnSkip, LEFT, -COIN_GAP, 0)
    CreateOpacitySlider(win, ui.btnSearch)
    CreateSearchBox(win)

    -- tabs: labels in a bar; the bar finds which one was clicked
    ui.tabBar = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.tabBar:SetAnchor(TOPLEFT, win, TOPLEFT, 0, HEADER_H + 2)
    ui.tabBar:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0, HEADER_H + 2)
    ui.tabBar:SetHeight(TABS_H)
    ui.tabBar:SetMouseEnabled(true)
    ui.tabBar:SetHitInsets(EDGE, 0, -EDGE, 0)
    ui.tabBar:SetDrawLevel(3)
    for _, id in ipairs(TABS) do
        local tab = { id = id }
        tab.label = WINDOW_MANAGER:CreateControl(nil, ui.tabBar, CT_LABEL)
        tab.label:SetDrawLevel(4)
        tab.line = Tex(ui.tabBar)
        tab.line:SetHeight(2)
        tab.line:SetAnchor(TOPLEFT, tab.label, BOTTOMLEFT, 0, 1)
        tab.line:SetDrawLevel(4)
        ui.tabs[#ui.tabs + 1] = tab
    end
    ui.tabBar:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        for _, tab in ipairs(ui.tabs) do
            if IsOver(tab.label, 5) then
                SelectTab(tab.id)
                return
            end
        end
    end)
    ui.tabBar:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)
    -- hover: light up the tab under the mouse (checked while the mouse is on the bar)
    local function TabHover()
        local over
        for _, tab in ipairs(ui.tabs) do
            if IsOver(tab.label, 5) then over = tab end
        end
        if over ~= ui.hoverTab then
            ui.hoverTab = over
            Tracker.PaintTabs()
        end
    end
    ui.tabBar:SetHandler("OnMouseEnter", function(self) self:SetHandler("OnUpdate", TabHover) end)
    ui.tabBar:SetHandler("OnMouseExit", function(self)
        self:SetHandler("OnUpdate", nil)
        ui.hoverTab = nil
        Tracker.PaintTabs()
    end)

    -- ledger style: gold line under the header
    ui.headRule = Tex(win)
    ui.headRule:SetHeight(1)
    ui.headRule:SetAnchor(TOPLEFT, win, TOPLEFT, 6, HEADER_H)
    ui.headRule:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, HEADER_H)
    ui.headRule:SetDrawLevel(3)
    ui.headRule:SetHidden(true)

    ui.sep = Tex(win, W.TEX .. "divider.dds")
    ui.sep:SetColor(W.RGBA(C.gold))
    ui.sep:SetHeight(12)
    ui.sep:SetAnchor(LEFT, win, TOPLEFT, 4, HEADER_H + TABS_H + 2)
    ui.sep:SetAnchor(RIGHT, win, TOPRIGHT, -4, HEADER_H + TABS_H + 2)
    ui.sep:SetDrawLevel(3)

    -- "more above / below" chevrons
    local function More(rotation)
        local t = Tex(win, W.UI("arrow.dds", 10))
        t:SetDimensions(10, 10)
        t:SetTextureRotation(rotation)
        t:SetDrawLevel(5)
        return t
    end
    ui.moreUp = More(0)
    ui.moreDown = More(math.pi)
    ui.moreDown:SetAnchor(BOTTOM, win, BOTTOM, 0, -1)

    ui.empty = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
    ui.empty:SetColor(W.RGBA(C.dim))
    ui.empty:SetDrawLevel(3)

    ui.fragment = W.HudFragment(win)
    Place()

    W.callbacks:RegisterCallback("QuestsChanged", Refresh)
    W.callbacks:RegisterCallback("TargetChanged", Refresh)
    W.callbacks:RegisterCallback("MapChanged", Refresh)
    W.callbacks:RegisterCallback("SettingsChanged", Tracker.Apply)
    W.callbacks:RegisterCallback("PositionsReset", function()
        Place()
        ui.shownH = nil   -- (standard height at once, no animation)
        Tracker.Layout()
    end)
    EVENT_MANAGER:RegisterForUpdate("Questbound_TrackerDist", 250, function()
        Tracker.UpdateDistance()
        UpdateFade()
    end)
    -- nearest-first order follows you as you move (not while the mouse is on the panel)
    EVENT_MANAGER:RegisterForUpdate("Questbound_TrackerSort", RESORT_MS, function()
        if not IsOver(ui.win) and not W.sv.tracker.minimized then Refresh() end
    end)
    -- AUI sets up its tracker after loading: apply the "hide AUI's tracker" option then
    EVENT_MANAGER:RegisterForEvent("Questbound_TrackerAui", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(ApplyAuiTracker, 500)
    end)
    EVENT_MANAGER:RegisterForEvent("Questbound_Tracker", EVENT_PLAYER_COMBAT_STATE, function(_, combat)
        inCombat = combat
        UpdateFade()
    end)
    inCombat = IsUnitInCombat("player")
    Tracker.Apply()
end
