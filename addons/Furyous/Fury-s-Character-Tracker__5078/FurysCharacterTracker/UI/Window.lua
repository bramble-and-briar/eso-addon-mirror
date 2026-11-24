-- The board (/fct): one row per character, one view per group of columns.
-- A column is { title =, width =, value = function(name, c, m) -> number or text,
--               max = number or function(c) (makes it a progress cell), align =, tip =,
--               pick = { field =, values = } (click for a dropdown of your own picks) }.
local CT = FurysCharacterTracker
local U = CT.Util
local Win = {}
CT.Window = Win

local ROW_TYPE = 1
local ROW_HEIGHT = 28
local MAX_CELLS = 16
local GAP = 6
local NAME_WIDTH = 184

-- Colors: violet tile = maxed, white text = in progress, dim dash = not started.
local T = CT.Theme                    -- Fury Night colors and fonts (UI/Theme.lua)
local GOLD = T.RGB.VIOLET             -- maxed tiles and totals
local INK = T.RGB.VOID                -- text on a maxed tile
local PARCH = T.RGB.TEXT
local DIM = T.RGB.MUTED
local MANUAL = T.RGB.BLUE             -- cells you pick from a dropdown
local HEAD = T.RGB.BLUE               -- column headers

-- Columns -----------------------------------------------------------------------------

local function Rank(lineName) return function(_, c) return (c.lines or {})[lineName] or 0 end end

local NAME = { title = "Character", width = NAME_WIDTH, align = TEXT_ALIGN_LEFT, value = function(name) return name end,
               tip = function(name, c)
                   return string.format("%s\nLevel %s %s %s\nRead from the game %s\nClick for details", name, c.level or "?", c.race or "", c.class or "", U.FormatDate(c.lastScan))
               end }
local CLASS = { title = "Class", width = 96, align = TEXT_ALIGN_LEFT, value = function(_, c) return c.class or "" end }
local ROLE = { title = "Role", width = 96, value = function(_, _, m) return m.role or "" end,
               tip = function(_, _, m) return m.role end }

local function GroupCount(group)
    return { title = group.title, width = 80, max = #group.lines,
             value = function(_, c) return CT.Roster:MaxedInGroup(c, group) end,
             display = function(v) return v .. "/" .. #group.lines end,
             tip = function(_, c)
                 local lines = {}
                 for _, line in ipairs(group.lines) do
                     lines[#lines + 1] = string.format("%s  %d / %d", line.name, math.min((c.lines or {})[line.name] or 0, line.max), line.max)
                 end
                 return table.concat(lines, "\n")
             end }
end

local function GroupById(id)
    for _, group in ipairs(CT.GROUPS) do
        if group.id == id then return group end
    end
end

local function LineColumns(groupId)
    local cols = { NAME, CLASS, ROLE }
    for _, line in ipairs(GroupById(groupId).lines) do
        local tip = line.name
        if line.name == "Assault" then tip = "Alliance War: Assault (Support ranks with it)" end
        if line.name == "Excavation" then tip = "Antiquities: Excavation (Scrying ranks with it)" end
        if line.keepPeak then tip = line.name .. "\nThe game hides this line when you are cured; this shows the best rank ever seen." end
        cols[#cols + 1] = { title = line.short, width = 84, max = line.max, value = Rank(line.name), tip = function() return tip end }
    end
    return cols
end

local SKILL_POINTS = { title = "Skill pts", width = 76, max = CT.SKILL_POINTS_MAX, value = function(_, c) return c.skillPoints or 0 end,
                       tip = function(_, c) return string.format("Skill points earned: %d of %d\nNot assigned yet: %s", c.skillPoints or 0, CT.SKILL_POINTS_MAX, c.unspent or "?") end }
local RESEARCH = { title = "Research", width = 84, max = function(c) return c.researchTotal or CT.RESEARCH_TOTAL end,
                   value = function(_, c) return c.research or 0 end, tip = "Traits researched (smithing, clothing, woodworking, jewelry)" }
local RECIPES = { title = "Recipes", width = 84, max = function(c) return c.recipesTotal end,
                  value = function(_, c) return c.recipes or 0 end,
                  tip = function(_, c) return string.format("Provisioning recipes known: %d%s", c.recipes or 0, c.recipesTotal and (" of " .. c.recipesTotal) or "") end }
local PLANS = { title = "Furnishing", width = 92, max = function(c) return c.furnishingsTotal end,
                value = function(_, c) return c.furnishings or 0 end,
                tip = function(_, c) return string.format("Furnishing plans known: %d%s", c.furnishings or 0, c.furnishingsTotal and (" of " .. c.furnishingsTotal) or "") end }
local SCRIPTS = { title = "Scribing", width = 80, max = function(c) return c.scriptsTotal or CT.SCRIPTS_TOTAL end,
                  value = function(_, c) return c.scripts or 0 end,
                  tip = function(_, c)
                      local text = string.format("Scribing learned: %d of %d (grimoires + scripts)", c.scripts or 0, c.scriptsTotal or CT.SCRIPTS_TOTAL)
                      if c.grimoires then
                          text = text .. string.format("\nGrimoires %d / %d\nScripts %d / %d", c.grimoires, c.grimoiresTotal, c.scriptsOnly, c.scriptsOnlyTotal)
                      end
                      return text
                  end }
local ACHIEVEMENTS = { title = "Ach. points", width = 84, value = function(_, c) return c.achievementPoints or 0 end,
                       display = function(v) return ZO_CommaDelimitNumber(v) end,
                       tip = function(_, c) return string.format("Achievement points: %s", ZO_CommaDelimitNumber(c.achievementPoints or 0)) end }
local MOTIFS = { title = "Motifs", width = 72, max = function(c) return c.motifsTotal end,
                 value = function(_, c) return c.motifs or 0 end,
                 tip = function(_, c)
                     return string.format("Motif styles known in full: %d%s\nThe game's own count; it can be off by one or two from crafting addons.",
                                          c.motifs or 0, c.motifsTotal and (" of " .. c.motifsTotal) or "")
                 end }
local RIDING = { title = "Riding", width = 72, max = function(c) return c.ridingMax or CT.RIDING_MAX end,
                 value = function(_, c) return c.riding or 0 end, tip = "Speed + stamina + carry capacity" }
local COMPANIONS = { title = "Companions", width = 100, max = function(c) return c.companionsTotal or CT.COMPANION_TOTAL end,
                     value = function(_, c) return #(c.companions or {}) end,
                     display = function(v, c) return v .. "/" .. (c.companionsTotal or CT.COMPANION_TOTAL) end,
                     tip = function(_, c)
                         local list = c.companions or {}
                         return #list > 0 and ("Unlocked: " .. table.concat(list, ", ")) or "No companions unlocked"
                     end }
local HOURS = { title = "Hours", width = 76, value = function(_, c) return c.playedHours or 0 end,
                display = function(v) return ZO_CommaDelimitNumber(v) end, tip = "Hours played (/played)" }
local CRAFT_MAXED = { title = "Crafting", width = 84, max = 7, value = function(_, c) return c.craftMaxed or 0 end,
                      display = function(v) return v .. "/7" end,
                      tip = function(_, c)
                          local done = (c.craftMaxed or 0) >= 7 and (c.research or 0) >= (c.researchTotal or CT.RESEARCH_TOTAL)
                          return "Crafting lines at 50" .. (done and "\nGrandmaster Crafter: all 7 lines maxed and every trait researched" or "")
                      end }
-- Research view: one column per craft, then slots and the next timer. Timers count down live.
local R = CT.Research
-- Characters read before 1.1.0 have only the total: show them as done if every trait is known.
local function AllKnown(c) return (c.research or 0) >= (c.researchTotal or CT.RESEARCH_TOTAL) end
local function CraftResearch(def)
    return { title = def.short, width = 96,
             max = function(c) local e = R.Entry(c, def.craft); return e and e.total or 1 end,
             value = function(_, c)
                 local e = R.Entry(c, def.craft)
                 if e then return e.known end
                 return AllKnown(c) and 1 or 0
             end,
             display = function(v, c)
                 local e = R.Entry(c, def.craft)
                 if e then return v .. "/" .. e.total end
                 return AllKnown(c) and "all" or "-"
             end,
             tip = function(_, c)
                 if not R.Entry(c, def.craft) and AllKnown(c) then
                     return R.CraftName(def.craft) .. "\nEvery trait researched."
                 end
                 return R.CraftTip(c, def.craft)
             end }
end
local SLOTS = { title = "Slots", width = 84,
                max = function(c) local _, slots = R.Summary(c); return slots > 0 and slots or nil end,
                value = function(_, c) return (R.Summary(c)) end,
                display = function(v, c) local _, slots = R.Summary(c); return slots > 0 and (v .. "/" .. slots) or "-" end,
                dim = function(_, c) local _, slots = R.Summary(c); return slots == 0 end,
                tip = "Research slots busy right now, across the crafts that still have traits to learn.\nViolet = every slot working. Counts down live, even for characters you are not on." }
local NEXT_DONE = { title = "Next done", width = 104,
                    value = function(_, c) local _, _, nextIn = R.Summary(c); return nextIn or math.huge end,
                    display = function(v) return v == math.huge and "-" or R.Duration(v) end,
                    dim = function(v) return v == math.huge end,
                    tip = function(_, c)
                        local _, _, nextIn, finished = R.Summary(c)
                        local text = nextIn and ("Next research finishes in " .. R.Duration(nextIn)) or "Nothing researching"
                        if finished > 0 then text = text .. string.format("\n%d finished since this character was last read", finished) end
                        return text
                    end }

-- Daily tab: crafting writs today and the riding lesson timer.
local D = CT.Daily
local function WritColumn(def)
    return { title = def.short, width = 84, max = D.DONE,
             value = function(_, c) return D.State(c, def.craft, CT.view.world) end,
             display = function(v) return D.LABEL[v] end,
             tip = function(_, c)
                 local entry, state = (c.writs or {})[def.craft], D.State(c, def.craft, CT.view.world)
                 local craft = U.Plain(GetString("SI_TRADESKILLTYPE", def.craft))
                 local text = state == D.NONE and (craft .. " writ: not taken today")
                     or string.format("%s writ: %s (%s)", craft, ({ "started", "ready to deliver", "done today" })[state], os.date("%a %I:%M %p", entry.at))
                 return text .. "\nWrits reset daily at " .. os.date("%I:%M %p", D.LastReset(CT.view.world) + 86400) .. " your time."
             end }
end
local WRITS_DONE = { title = "Done", width = 72, max = #D.CRAFTS, display = function(v) return v .. "/" .. #D.CRAFTS end,
                     value = function(_, c)
                         local n = 0
                         for _, def in ipairs(D.CRAFTS) do if D.State(c, def.craft, CT.view.world) == D.DONE then n = n + 1 end end
                         return n
                     end, tip = "Crafting writs turned in since today's reset" }
local RIDING_LESSON = { title = "Riding lesson", width = 120,
                        value = function(_, c)
                            if not c.ridingReadyAt then return -1 end
                            return math.max(0, c.ridingReadyAt - GetTimeStamp())
                        end,
                        display = function(v) return v < 0 and "Maxed" or (v == 0 and "Ready" or CT.Research.Duration(v)) end,
                        gold = function(v) return v < 0 end,
                        tip = function(_, c)
                            if not c.ridingReadyAt then return "Riding maxed (" .. (c.riding or 0) .. " / " .. (c.ridingMax or CT.RIDING_MAX) .. ")" end
                            if c.ridingReadyAt <= GetTimeStamp() then return "A riding lesson is ready: visit a stablemaster." end
                            return "Next riding lesson at " .. os.date("%a %I:%M %p", c.ridingReadyAt)
                        end }

-- Wallet & CP tab.
local function Money(title, width, field, tip)
    return { title = title, width = width, sum = true, value = function(_, c) return c[field] or 0 end,
             display = function(v) return ZO_CommaDelimitNumber(v) end, dim = function(v) return v == 0 end, tip = tip }
end
local BAG = { title = "Bag", width = 84, value = function(_, c) return c.bagUsed or 0 end,
              display = function(v, c) return c.bagSize and (v .. "/" .. c.bagSize) or "-" end,
              dim = function(_, c) return not c.bagSize end,
              tip = function(_, c) return c.bagSize and string.format("Backpack: %d used, %d free", c.bagUsed, c.bagSize - c.bagUsed) or "Not read yet" end }
local function ChampionTree(index)
    return { title = "CP " .. index, width = 96,
             max = function(c) local t = (c.cp or {})[index]; return t and (t.spent + t.unspent) > 0 and (t.spent + t.unspent) or nil end,
             value = function(_, c) local t = (c.cp or {})[index]; return t and t.spent or 0 end,
             display = function(v, c) local t = (c.cp or {})[index]; return t and (v .. "/" .. (t.spent + t.unspent)) or "-" end,
             tip = function(_, c)
                 local t = (c.cp or {})[index]
                 if not t then return "Not read yet" end
                 return string.format("%s: %d spent, %d not spent\nViolet = every point in this tree spent", t.name, t.spent, t.unspent)
             end }
end
-- Tree names come from the game; use the first character that has them.
local function TreeTitles()
    local titles = {}
    for _, c in pairs(CT.Data().characters) do
        for i, t in ipairs(c.cp or {}) do titles[i] = titles[i] or t.name end
    end
    return titles
end

local UPDATED = { title = "Updated", width = 104, value = function(_, c) return U.FormatDate(c.lastScan) end,
                  tip = "When this character was last read from the game. /fct todo lists the ones that are out of date." }

-- Your own picks: click the cell for a dropdown.
local function Manual(width, field, tip)
    local def = CT.Roster.FIELDS[field]
    return { title = def.title, width = width, value = function(_, _, m) return m[field] or "" end,
             pick = { field = field, values = def.values }, tip = tip }
end

Win.VIEWS = {
    { id = "overview", title = "Overview", tip = "Everything at a glance: how many lines of each group are maxed",
      columns = function()
          return { NAME, CLASS, ROLE, SKILL_POINTS, GroupCount(GroupById("weapons")), GroupCount(GroupById("armor")),
                   GroupCount(GroupById("guilds")), GroupCount(GroupById("world")), CRAFT_MAXED, RESEARCH,
                   COMPANIONS, RIDING, ACHIEVEMENTS, HOURS }
      end },
    { id = "weapons",  title = "Weapons",  columns = function() return LineColumns("weapons") end },
    { id = "armor",    title = "Armor",    columns = function() return LineColumns("armor") end },
    { id = "guilds",   title = "Guilds & AvA", columns = function() return LineColumns("guilds") end },
    { id = "world",    title = "World",    columns = function()
          local cols = LineColumns("world")
          cols[#cols + 1] = SCRIPTS
          return cols
      end },
    { id = "crafting", title = "Crafting", columns = function()
          local cols = LineColumns("crafting")
          cols[#cols + 1] = RESEARCH
          return cols
      end },
    { id = "traits", title = "Research", tip = "Traits known and missing per craft, research slots and timers. Hover a craft for details.\nResearch timers (button below, or /fct timers) lists every research with its time left.",
      columns = function()
          local cols = { NAME, CLASS, ROLE }
          for _, def in ipairs(R.CRAFTS) do cols[#cols + 1] = CraftResearch(def) end
          cols[#cols + 1] = SLOTS
          cols[#cols + 1] = NEXT_DONE
          cols[#cols + 1] = RESEARCH
          return cols
      end },
    { id = "daily", title = "Daily", tip = "Crafting writs since today's reset and the next riding lesson, per character.",
      columns = function()
          local cols = { NAME, CLASS, ROLE }
          for _, def in ipairs(D.CRAFTS) do cols[#cols + 1] = WritColumn(def) end
          cols[#cols + 1] = WRITS_DONE
          cols[#cols + 1] = RIDING_LESSON
          return cols
      end },
    { id = "collections", title = "Collections", tip = "Recipes, furnishing plans, motifs, riding, companions, time played",
      columns = function() return { NAME, CLASS, ROLE, RECIPES, PLANS, MOTIFS, SCRIPTS, RIDING, COMPANIONS, ACHIEVEMENTS, HOURS, SKILL_POINTS } end },
    { id = "wallet", title = "Wallet & CP", totalsLabel = "Total",
      tip = "Gold, Tel Var, Alliance Points, writ vouchers and bag space per character, and Champion Points spent per tree.\nThe line above the columns shows the bank.",
      columns = function()
          local titles = TreeTitles()
          local cols = { NAME, CLASS, ROLE,
                         Money("Gold", 112, "gold", "Gold carried"), Money("Tel Var", 88, "telvar", "Tel Var stones carried"),
                         Money("AP", 100, "ap", "Alliance Points"), Money("Vouchers", 96, "vouchers", "Writ vouchers"), BAG }
          for i = 1, 3 do
              local col = ChampionTree(i)
              col.title = titles[i] or col.title
              cols[#cols + 1] = col
          end
          return cols
      end },
    { id = "sets", title = "Roles & gear", tip = "Your own picks per character. Click a blue cell for a dropdown.",
      columns = function()
          return { NAME, CLASS,
                   Manual(136, "role", "The role(s) you play this character in."),
                   Manual(124, "dpsGear", "The DPS gear you have farmed for this character (not what it is wearing)."),
                   Manual(150, "roleGear", "The tank or healer gear you have farmed for this character.\nFor a DPS/Healer: DPS gear = DPS role, this = healer role."),
                   { title = "Race", width = 96, align = TEXT_ALIGN_LEFT, value = function(_, c) return c.race or "" end },
                   Manual(120, "plannedRace", "A race change you plan (blank = none)."),
                   { title = "Alliance", width = 150, align = TEXT_ALIGN_LEFT, value = function(_, c) return c.alliance or "" end },
                   UPDATED }
      end },
}

function Win:HasView(id)
    for _, view in ipairs(self.VIEWS) do
        if view.id == id then return true end
    end
    return false
end

local function CurrentView()
    for _, view in ipairs(Win.VIEWS) do
        if view.id == CT.sv.lastView then return view end
    end
    return Win.VIEWS[1]
end

-- Hover text --------------------------------------------------------------------------

-- Pinned to the mouse position on the screen, not to the cell: cells are reused and moved
-- every time the board redraws, and a tooltip pinned to one could end up anchored in a loop.
local function ShowTip(_, text)
    if not text or text == "" then return end
    local x, y = GetUIMousePosition()
    ClearTooltip(InformationTooltip)
    InitializeTooltip(InformationTooltip, GuiRoot, TOPLEFT, x + 18, y + 18, TOPLEFT)
    SetTooltipText(InformationTooltip, text)
end

local function HideTip()
    ClearTooltip(InformationTooltip)
end

local function SetTip(control, tipFn)
    control.furyTip = tipFn
    if not control.furyTipHooked then
        control.furyTipHooked = true
        control:SetHandler("OnMouseEnter", function(self)
            if self.furyRow then T.RowHover(self.furyRow, true) end
            if self.furyTip then ShowTip(self, self.furyTip()) end
        end)
        control:SetHandler("OnMouseExit", function(self)
            if self.furyRow then T.RowHover(self.furyRow, false) end
            HideTip()
        end)
    end
end

-- Setup -------------------------------------------------------------------------------

function Win:Initialize()
    self.control = FurysCharacterTracker_Window
    self.list = FurysCharacterTracker_WindowList
    SCENE_MANAGER:RegisterTopLevel(FurysCharacterTracker_Window, false)
    FurysCharacterTracker_Window:SetHandler("OnHide", HideTip)

    ZO_ScrollList_AddDataType(self.list, ROW_TYPE, "FurysCharacterTracker_Row", ROW_HEIGHT, function(control, data)
        self:SetupRow(control, data)
    end)

    -- Column headers, made once and reused by every view.
    self.headers = {}
    for i = 1, MAX_CELLS do
        local label = WINDOW_MANAGER:CreateControl("FurysCharacterTracker_WindowHeaderCol" .. i, FurysCharacterTracker_WindowHeader, CT_LABEL)
        label:SetFont(T.FONT_HEADER)
        label:SetColor(HEAD[1], HEAD[2], HEAD[3], 1)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        label:SetMouseEnabled(true)
        label:SetHidden(true)
        self.headers[i] = label
    end

    -- View buttons.
    local previous
    for i, view in ipairs(self.VIEWS) do
        local button = WINDOW_MANAGER:CreateControlFromVirtual("FurysCharacterTracker_WindowView" .. i, FurysCharacterTracker_WindowViews, "ZO_DefaultButton")
        button:SetDimensions(120, 28)
        button:SetText(view.title)
        if previous then button:SetAnchor(LEFT, previous, RIGHT, 6, 0) else button:SetAnchor(LEFT, FurysCharacterTracker_WindowViews, LEFT, 0, 0) end
        button:SetHandler("OnClicked", function() self:Show(view.id) end)
        if view.tip then SetTip(button, function() return view.tip end) end
        view.button = button
        previous = button
    end

    -- Footer buttons.
    local footer = {
        { label = "Read this character", tip = "Reads the character you are on right now (it also happens by itself at login and after progress).",
          fn = function() CT.Scan:Run(); U.Print("Updated %s.", CT.Scan.CurrentName()) end },
        { label = "Brag card", tip = "Your roster's best numbers on one card, sized for a screenshot to share on Discord.",
          fn = function() CT.Brag:Toggle() end },
        { label = "Show removed", tip = "Puts back every character you removed with right-click > Remove from board.",
          fn = function() CT.Roster:ShowAll(); CT.Roster:BuildExportRows(); self:Refresh() end },
        { label = "Research timers", tip = "Every research slot on this account: what is researching, time left, and slots that are free.",
          fn = function() CT.Timers:Toggle() end },
        { label = "Export to Excel", tip = "Saves the board and reloads the UI.\nWith Auto Export turned on (Windows Tools: /fct settings > Get the Windows Tools), ESO Characters.csv appears in Documents\\Elder Scrolls Online a few seconds later.",
          fn = function() CT.RequestExport() end },
    }
    previous = nil
    for i, def in ipairs(footer) do
        local button = WINDOW_MANAGER:CreateControlFromVirtual("FurysCharacterTracker_WindowFooter" .. i, FurysCharacterTracker_WindowFooter, "ZO_DefaultButton")
        button:SetDimensions(150, 28)
        button:SetText(def.label)
        if previous then button:SetAnchor(LEFT, previous, RIGHT, 8, 0) else button:SetAnchor(LEFT, FurysCharacterTracker_WindowFooter, LEFT, 0, 0) end
        button:SetHandler("OnClicked", def.fn)
        SetTip(button, function() return def.tip end)
        previous = button
    end

    FurysCharacterTracker_WindowLegend:SetText("|cA08CFFViolet|r maxed  ·  white in progress  ·  |c8A86B0-|r none  ·  |c5CC2FFblue|r pick  ·  click details  ·  right-click remove")
    FurysCharacterTracker_WindowSubtitle:SetText("v" .. CT.version .. "  ·  /fct")

    -- Which account and megaserver you are looking at.
    local picker = WINDOW_MANAGER:CreateControlFromVirtual("FurysCharacterTracker_WindowAccount", FurysCharacterTracker_Window, "ZO_DefaultButton")
    picker:SetDimensions(300, 28)
    picker:SetAnchor(TOPRIGHT, FurysCharacterTracker_Window, TOPRIGHT, -52, 12)
    picker:SetHandler("OnClicked", function(control) Win.PickAccount(control) end)
    SetTip(picker, function()
        return "The account and megaserver on the board. Every account that plays on this PC shows up here after it logs in once with the addon on.\nOther accounts show what they saved at their last logout."
    end)
    self.accountButton = picker

    -- Settings: the gear left of the account button.
    local gear = WINDOW_MANAGER:CreateControl("FurysCharacterTracker_WindowSettings", FurysCharacterTracker_Window, CT_BUTTON)
    gear:SetDimensions(32, 32)
    gear:SetAnchor(RIGHT, picker, LEFT, -10, 0)
    gear:SetNormalTexture("/esoui/art/chatwindow/chat_options_up.dds")
    gear:SetPressedTexture("/esoui/art/chatwindow/chat_options_down.dds")
    gear:SetMouseOverTexture("/esoui/art/chatwindow/chat_options_over.dds")
    gear:SetHandler("OnClicked", function() CT.Settings:Open() end)
    SetTip(gear, function() return "Settings\n(also Settings > Addons > Fury's Character Tracker, or /fct settings)" end)

    local pos = CT.sv.window
    if pos then
        self.control:ClearAnchors()
        self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end
end

function Win.SavePosition()
    CT.sv.window = { x = FurysCharacterTracker_Window:GetLeft(), y = FurysCharacterTracker_Window:GetTop() }
end

-- Show / hide -------------------------------------------------------------------------

function Win:Toggle()
    if FurysCharacterTracker_Window:IsHidden() then self:Show() else self:Hide() end
end

function Win:Show(viewId)
    if viewId then CT.sv.lastView = viewId end
    SCENE_MANAGER:ShowTopLevel(FurysCharacterTracker_Window)
    CT.Raise(FurysCharacterTracker_Window)
    self:Refresh()
end

function Win:Hide()
    SCENE_MANAGER:HideTopLevel(FurysCharacterTracker_Window)
end

function Win:RefreshIfShown()
    if self.control and not self.control:IsHidden() then self:Refresh() end
end

-- Cells -------------------------------------------------------------------------------

local function EnsureCells(row)
    if row.cells then return end
    row.cells = {}
    local base = row:GetName()
    for i = 1, MAX_CELLS do
        local tile = WINDOW_MANAGER:CreateControl(base .. "Tile" .. i, row, CT_TEXTURE)
        -- Above the row's stripe (level 3) and hover highlight (level 5), under the cell text.
        tile:SetDrawLayer(DL_BACKGROUND)
        tile:SetDrawLevel(8)
        tile:SetColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
        tile:SetHidden(true)
        local label = WINDOW_MANAGER:CreateControl(base .. "Cell" .. i, row, CT_LABEL)
        label:SetDrawLayer(DL_TEXT)
        label:SetFont("ZoFontGame")
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        label:SetMouseEnabled(true)
        row.cells[i] = { tile = tile, label = label }
    end
end

local function ResolveMax(column, c)
    if type(column.max) == "function" then return column.max(c) end
    return column.max
end

-- Text and look of one cell.
local function PaintCell(cell, column, name, c, m)
    local value = column.value(name, c, m)
    local max = ResolveMax(column, c)
    local text = column.display and column.display(value, c) or tostring(value)
    local color, maxed = PARCH, false
    if type(value) == "number" and max then
        if value >= max then
            maxed = true
            if not column.display then text = tostring(math.min(value, max)) end
        elseif value == 0 then
            color, text = DIM, column.display and text or "-"
        end
    end
    if column.dim and column.dim(value, c) then color = DIM end
    if column.gold and column.gold(value, c) then maxed = true end
    if column.pick then
        color = MANUAL
        if text == "" then text = "-" end
    end
    cell.tile:SetHidden(not maxed)
    cell.label:SetText(text)
    cell.label:SetFont(maxed and "ZoFontGameBold" or "ZoFontGame")
    local rgb = maxed and INK or color
    cell.label:SetColor(rgb[1], rgb[2], rgb[3], 1)
end

local function LayoutCells(row, columns)
    local x = 6
    for i, cell in ipairs(row.cells) do
        local column = columns[i]
        if column then
            cell.tile:ClearAnchors()
            cell.tile:SetAnchor(LEFT, row, LEFT, x, 0)
            cell.tile:SetDimensions(column.width, ROW_HEIGHT - 4)
            cell.label:ClearAnchors()
            cell.label:SetAnchor(LEFT, row, LEFT, x + 4, 0)
            cell.label:SetDimensions(column.width - 8, ROW_HEIGHT)
            cell.label:SetHorizontalAlignment(column.align or TEXT_ALIGN_CENTER)
            cell.label:SetHidden(false)
            x = x + column.width + GAP
        else
            cell.label:SetHidden(true)
            cell.tile:SetHidden(true)
        end
    end
end

-- Dropdown of accounts and megaservers.
function Win.PickAccount(owner)
    ClearMenu()
    for _, entry in ipairs(CT.Accounts()) do
        local label = CT.ViewLabel(entry) .. (entry == CT.home and "  (you)" or "")
        if entry.world == CT.view.world and entry.account == CT.view.account then label = "|cA08CFF" .. label .. "  <|r" end
        AddMenuItem(label, function() CT.SetView(entry) end)
    end
    ShowMenu(owner)
end

-- Dropdown for one of your picks. The current choice is marked.
function Win.Pick(owner, name, field, values)
    local current = (CT.Data().manual[name] or {})[field] or ""
    ClearMenu()
    for _, value in ipairs(values) do
        local label = (value == "") and "(none)" or value
        if value == current then label = "|cA08CFF" .. label .. "  <|r" end
        AddMenuItem(label, function()
            CT.Roster:SetManual(name, field, value)
            Win:Refresh()
        end)
    end
    ShowMenu(owner)
end

local function RowMenu(name)
    ClearMenu()
    AddMenuItem("Remove " .. name .. " from the board", function()
        CT.Roster:Hide(name)
        CT.Roster:BuildExportRows()
        Win:Refresh()
        U.Print("Removed %s from the board. \"Show removed\" puts it back; logging in on it does too.", name)
    end)
    ShowMenu()
end

function Win:SetupRow(row, data)
    EnsureCells(row)
    local columns = self.columns
    LayoutCells(row, columns)
    row:GetNamedChild("Stripe"):SetHidden(data.stripe ~= true)
    T.RowHover(row, false)
    local c, m = CT.Roster:Get(data.name)
    for i, cell in ipairs(row.cells) do
        local column = columns[i]
        if column then
            PaintCell(cell, column, data.name, c, m)
            cell.label.furyRow = row
            local tip = column.tip
            SetTip(cell.label, function()
                if type(tip) == "function" then return tip(data.name, c, m) end
                return tip
            end)
            cell.label:SetHandler("OnMouseUp", function(_, button, upInside)
                if not upInside then return end
                if button == MOUSE_BUTTON_INDEX_RIGHT then
                    RowMenu(data.name)
                elseif column.pick then
                    Win.Pick(cell.label, data.name, column.pick.field, column.pick.values)
                else
                    CT.Details:Show(data.name)
                end
            end)
        end
    end
end

-- Totals row: how many characters have each column maxed (or the sum, for plain numbers).
function Win:SetupTotals(names)
    local row = FurysCharacterTracker_WindowTotals
    EnsureCells(row)
    LayoutCells(row, self.columns)
    for i, cell in ipairs(row.cells) do
        local column = self.columns[i]
        if column then
            local text = ""
            if i == 1 then
                text = CurrentView().totalsLabel or "Maxed on"
            elseif column.max then
                local maxed = 0
                for _, name in ipairs(names) do
                    local c, m = CT.Roster:Get(name)
                    local value, max = column.value(name, c, m), ResolveMax(column, c)
                    if type(value) == "number" and max and value >= max then maxed = maxed + 1 end
                end
                text = maxed .. "/" .. #names
            elseif column == HOURS or column.sum then
                local sum = 0
                for _, name in ipairs(names) do
                    local c, m = CT.Roster:Get(name)
                    sum = sum + (column.value(name, c, m) or 0)
                end
                text = ZO_CommaDelimitNumber(sum)
            end
            cell.tile:SetHidden(true)
            cell.label:SetText(text)
            cell.label:SetFont("ZoFontGameBold")
            cell.label:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
            SetTip(cell.label, nil)
            cell.label.furyRow = nil
            cell.label:SetHandler("OnMouseUp", nil)
        end
    end
end

-- Refresh -----------------------------------------------------------------------------

local function SortValue(column)
    return function(name)
        local c, m = CT.Roster:Get(name)
        local value = column.value(name, c, m)
        if type(value) == "number" then return value end
        return zo_strlower(tostring(value or ""))
    end
end

function Win:Refresh()
    HideTip()
    local view = CurrentView()
    self.columns = view.columns()
    for _, v in ipairs(self.VIEWS) do v.button:SetEnabled(v ~= view) end

    -- Sorting: per view, column index; nil = your board order.
    CT.sv.sort = CT.sv.sort or {}
    local sort = CT.sv.sort[view.id]
    local sortColumn = sort and self.columns[sort.col]

    local entries = CT.Roster:List(sortColumn and SortValue(sortColumn), sort and sort.desc)

    -- Headers.
    local x = 6
    for i, label in ipairs(self.headers) do
        local column = self.columns[i]
        if column then
            local arrow = (sort and sort.col == i) and (sort.desc and " v" or " ^") or ""
            label:ClearAnchors()
            label:SetAnchor(LEFT, FurysCharacterTracker_WindowHeader, LEFT, x + 4, 0)
            label:SetDimensions(column.width - 8, 26)
            label:SetHorizontalAlignment(column.align or TEXT_ALIGN_CENTER)
            label:SetText(column.title .. arrow)
            label:SetHandler("OnMouseUp", function(_, _, upInside)
                if not upInside then return end
                local s = CT.sv.sort[view.id]
                if s and s.col == i then
                    if s.desc then CT.sv.sort[view.id] = nil else s.desc = true end   -- third click: back to board order
                else
                    -- Numbers sort biggest first, names A to Z.
                    local first = entries[1]
                    local sample = first and SortValue(column)(first.name)
                    CT.sv.sort[view.id] = { col = i, desc = type(sample) == "number" }
                end
                self:Refresh()
            end)
            SetTip(label, function() return "Click to sort by " .. column.title .. ". Click again to reverse, a third time for your own order." end)
            label:SetHidden(false)
            x = x + column.width + GAP
        else
            label:SetHidden(true)
        end
    end

    ZO_ScrollList_Clear(self.list)
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    local names = {}
    for i, entry in ipairs(entries) do
        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(ROW_TYPE, { name = entry.name, stripe = (i % 2 == 0) })
        names[#names + 1] = entry.name
    end
    ZO_ScrollList_Commit(self.list)
    self:SetupTotals(names)

    self.accountButton:SetText(CT.ViewLabel() .. "  v")
    local never = #CT.Roster:NeverRead()
    local summary = string.format("%d characters", #names)
    if not CT.IsHome() then
        local saved = (CT.Data().account or {}).lastScan
        summary = summary .. string.format("  ·  %s as saved %s  ·  log in on that account to update it",
                                           CT.ViewLabel(), saved and U.FormatDate(saved) or "at its last logout")
    elseif never > 0 then
        summary = summary .. string.format("  ·  %d more on this account not read yet: log in on each once (/fct todo lists them)", never)
    else
        summary = summary .. "  ·  every character on this account is here  ·  /fct todo lists the out-of-date ones"
    end
    if view.id == "wallet" then
        local a = CT.Data().account or {}
        if a.bankGold then
            summary = string.format("Bank: %s gold  ·  %s Tel Var  ·  %s AP  ·  %s vouchers  ·  %s transmute crystals  ·  bank space %d/%d",
                ZO_CommaDelimitNumber(a.bankGold), ZO_CommaDelimitNumber(a.bankTelvar or 0), ZO_CommaDelimitNumber(a.bankAP or 0),
                ZO_CommaDelimitNumber(a.bankVouchers or 0), ZO_CommaDelimitNumber(a.transmutes or 0), a.bankUsed or 0, a.bankSize or 0)
        else
            summary = "Bank: log in once with version 1.2.0 or later to read it"
        end
    elseif view.id == "daily" then
        summary = summary .. "  ·  writs reset at " .. os.date("%I:%M %p", D.LastReset(CT.view.world) + 86400) .. " your time"
    end
    FurysCharacterTracker_WindowSummary:SetText(summary)
end
