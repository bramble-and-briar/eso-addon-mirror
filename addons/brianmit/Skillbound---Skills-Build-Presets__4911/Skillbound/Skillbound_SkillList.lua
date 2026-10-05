-- Skillbound_SkillList.lua : the skill picker (2026-10-03), same look as the gear picker:
-- a small panel beside the slot with a search box on top, then
--   "On your bars now" (both bars),
--   every other skill this character has learned, under its skill line's name.
-- Each row: icon, name; the skill the slot holds now gets an amber mark; hover = the skill's
-- tooltip. Wheel scrolls; a click picks; X / Escape / a click outside closes.
-- Used for the build's skill slots and for the prebuff slots (Skillbound_Prebuff.lua).
--   SkillList.Open(anchor, { title, ult = true|false|nil, current = entry, onPick(entry),
--                            onClear = function (nil = no "don't change" line), clearText })

local B = Skillbound
local L = B.L
local C = B.COLOR
local W = B.W
local Anim = B.Anim
local Capture = B.Capture
local SkillList = {}
B.SkillList = SkillList

local PICK_W, PICK_ROW, PICK_ROWS = 340, 24, 14
local p = { rows = {} }

-- every active skill this character has learned: { id, name, line, ult, crafted }
local function Learned()
    local list = {}
    if not SKILLS_DATA_MANAGER then return list end
    for _, typeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        for _, lineData in typeData:SkillLineIterator() do
            local okName, lineName = pcall(function() return B.Name(lineData:GetName()) end)
            local okAvail, avail = pcall(function() return lineData:IsAvailable() end)
            if not okAvail or avail ~= false then
                for _, skillData in lineData:SkillIterator() do
                    pcall(function()
                        if skillData:IsPassive() or not skillData:IsPurchased() then return end
                        local prog = skillData:GetPointAllocatorProgressionData()
                        local id = prog and prog:GetAbilityId()
                        if not id or id == 0 then return end
                        local e = { id = id, name = B.Name(prog:GetName()), line = okName and lineName or nil,
                            ult = skillData:IsUltimate() and true or false }
                        if skillData.IsCraftedAbility and skillData:IsCraftedAbility() and skillData.GetCraftedAbilityId then
                            e.crafted = skillData:GetCraftedAbilityId()
                            if GetCraftedAbilityDisplayName then
                                local ok, n = pcall(GetCraftedAbilityDisplayName, e.crafted)
                                if ok and n and n ~= "" then e.name = B.Name(n) end
                            end
                        end
                        list[#list + 1] = e
                    end)
                end
            end
        end
    end
    return list
end

-- the rows: { head = text } or { e = entry }
local function Rows()
    local rows = {}
    local q = zo_strlower(zo_strtrim(p.query or ""))
    local want = p.opts.ult
    local function Fits(e)
        if want ~= nil and e.ult ~= want then return false end
        return q == "" or zo_strlower(e.name):find(q, 1, true) ~= nil
    end
    local seen = {}
    -- on your bars now first (scribed skills come out right from there)
    local first = true
    for _, cat in ipairs(Capture.BARS) do
        for s = Capture.FIRST_SLOT, Capture.ULT_SLOT do
            local ok, e = pcall(Capture.SlotSkill, cat, s)
            if ok and e and not seen[e.id] then
                e.ult = s == Capture.ULT_SLOT
                seen[e.id] = true
                if Fits(e) then
                    if first then rows[#rows + 1] = { head = L("SKL_ON_BARS") } first = false end
                    rows[#rows + 1] = { e = e }
                end
            end
        end
    end
    local line
    for _, e in ipairs(p.learned) do
        if not seen[e.id] and Fits(e) then
            seen[e.id] = true
            if e.line ~= line then
                line = e.line
                rows[#rows + 1] = { head = line or "" }
            end
            rows[#rows + 1] = { e = e }
        end
    end
    if #rows == 0 then rows[1] = { head = L(q ~= "" and "PICK_NO_MATCH" or "SKL_NONE"), empty = true } end
    return rows
end

function SkillList.Close()
    if not p.win or p.win:IsHidden() then return end
    p.win:SetHidden(true)
    p.edit:LoseFocus()
    ClearTooltip(AbilityTooltip)
    B.EM:UnregisterForEvent("Skillbound_SkillListClick", EVENT_GLOBAL_MOUSE_DOWN)
end

local function Refresh()
    if not p.win or p.win:IsHidden() then return end
    local rows = Rows()
    p.offset = zo_clamp(p.offset or 0, 0, math.max(0, #rows - PICK_ROWS))
    local cur = p.opts.current
    for i = 1, PICK_ROWS do
        local data = rows[p.offset + i]
        local r = p.rows[i]
        r.data = data
        r:SetHidden(data == nil)
        if data then
            local isHead = data.head ~= nil
            r.head:SetHidden(not isHead)
            r.line:SetHidden(not isHead or data.empty)
            r.icon:SetHidden(isHead)
            r.name:SetHidden(isHead)
            r.mark:SetHidden(true)
            if isHead then
                r.head:SetText(data.empty and data.head or zo_strupper(data.head))
                r.head:SetFont(B.Font(data.empty and "text" or "head", 11))
                r.head:SetColor(B.RGBA(data.empty and C.dim or C.gold))
            else
                r.icon:SetTexture(GetAbilityIcon(data.e.id))
                r.name:SetText(data.e.name)
                r.name:SetColor(B.RGBA(data.e.ult and C.theme or C.text))
                r.mark:SetHidden(not (cur and cur.id == data.e.id))
            end
        end
    end
    p.more:SetHidden(p.offset + PICK_ROWS >= #rows)
end

local function Scroll(delta)
    p.offset = math.max(0, (p.offset or 0) + delta * 3)
    Refresh()
end

local function MakeRow(i)
    local r = WINDOW_MANAGER:CreateControl(nil, p.list, CT_CONTROL)
    r:SetHeight(PICK_ROW)
    r:SetAnchor(TOPLEFT, p.list, TOPLEFT, 0, (i - 1) * PICK_ROW)
    r:SetAnchor(TOPRIGHT, p.list, TOPRIGHT, 0, (i - 1) * PICK_ROW)
    r:SetMouseEnabled(true)
    r.bg = W.Tex(r, nil, nil, nil, C.hover)
    r.bg:SetAnchorFill(r)
    r.bg:SetAlpha(0)
    r.mark = W.Tex(r, nil, 3, PICK_ROW - 6, C.theme)
    r.mark:SetAnchor(LEFT, r, LEFT, 0, 0)
    r.icon = W.Tex(r, nil, 20, 20)
    r.icon:SetAnchor(LEFT, r, LEFT, 8, 0)
    r.name = W.Label(r, B.Font("name", 11), C.text, "")
    r.name:SetAnchor(LEFT, r.icon, RIGHT, 8, 0)
    r.name:SetWidth(PICK_W - 60)
    r.name:SetMaxLineCount(1)
    r.head = W.Label(r, B.Font("head", 11), C.gold, "")
    r.head:SetAnchor(LEFT, r, LEFT, 4, 2)
    r.line = W.Tex(r, nil, 10, 1, C.line)
    r.line:SetAnchor(LEFT, r.head, RIGHT, 8, 2)
    r.line:SetAnchor(RIGHT, r, RIGHT, -4, 2)
    r:SetHandler("OnMouseEnter", function(self)
        if self.data and self.data.e then
            self.bg:SetAlpha(0.9)
            InitializeTooltip(AbilityTooltip, p.win, RIGHT, -8, 0, LEFT)
            AbilityTooltip:SetAbilityId(self.data.e.id)
        end
    end)
    r:SetHandler("OnMouseExit", function(self)
        self.bg:SetAlpha(0)
        ClearTooltip(AbilityTooltip)
    end)
    r:SetHandler("OnMouseWheel", function(_, delta) Scroll(-delta) end)
    r:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT or not (self.data and self.data.e) then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        local pick, e = p.opts.onPick, self.data.e
        SkillList.Close()
        if pick then pick({ id = e.id, name = e.name, line = e.line, crafted = e.crafted }) end
    end)
    p.rows[i] = r
end

local function Create()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_SkillList")
    p.win = win
    win:SetDimensions(PICK_W, 70 + PICK_ROWS * PICK_ROW + 34)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    local fill = W.Tex(win)
    fill:SetAnchorFill(win)
    fill:SetColor(B.RGBA(C.panel, 1))
    W.Frame(win, C.goldDark, 1)
    W.Brackets(win, 2, 6)
    local top = W.Tex(win, nil, 10, 2, C.theme, 0.9)
    top:SetAnchor(TOPLEFT, win, TOPLEFT, 1, 1)
    top:SetAnchor(TOPRIGHT, win, TOPRIGHT, -1, 1)
    p.title = W.Label(win, B.Font("head", 12), C.dim, "")
    p.title:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 10)
    local close = W.CloseButton(win, SkillList.Close, 14, L("CLOSE"))
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 10)
    local box, edit = W.Edit(win, PICK_W - 28, L("PICK_SEARCH"))
    box:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 32)
    edit:SetMaxInputChars(40)
    edit:SetHandler("OnTextChanged", function(self)
        p.query = self:GetText()
        p.offset = 0
        Refresh()
    end)
    edit:SetHandler("OnEscape", SkillList.Close)
    p.edit = edit
    p.list = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    p.list:SetAnchor(TOPLEFT, win, TOPLEFT, 10, 68)
    p.list:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 68)
    p.list:SetHeight(PICK_ROWS * PICK_ROW)
    p.list:SetMouseEnabled(true)
    p.list:SetHandler("OnMouseWheel", function(_, delta) Scroll(-delta) end)
    for i = 1, PICK_ROWS do MakeRow(i) end
    p.more = W.Label(win, B.Font("text", 10), C.faint, L("RULES_MORE"))
    p.more:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -14, -10)
    p.clear = W.Button(win, "", function()
        local clear = p.opts.onClear
        SkillList.Close()
        if clear then clear() end
    end, "quiet", 230, 18)
    p.clear:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 10, -8)
    p.clear.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
end

function SkillList.Open(anchor, opts)
    if not p.win then Create() end
    p.opts = opts or {}
    p.learned = Learned()
    p.query = ""
    p.offset = 0
    p.edit:SetText("")
    p.title:SetText(zo_strupper(p.opts.title or L("SKL_TITLE")))
    p.clear:SetText(p.opts.clearText or L("SKILL_LEAVE_OUT"))
    p.clear:SetHidden(p.opts.onClear == nil)
    p.win:ClearAnchors()
    p.win:SetAnchor(TOPLEFT, anchor, TOPRIGHT, 10, -20)
    p.win:SetHidden(false)
    Refresh()
    Anim.Alpha(p.win, 0, 1, Anim.STD, Anim.Out, "Skillbound_SkillListOpen")
    p.edit:TakeFocus()
    B.Later(function()
        if not EVENT_GLOBAL_MOUSE_DOWN or p.win:IsHidden() then return end
        B.EM:RegisterForEvent("Skillbound_SkillListClick", EVENT_GLOBAL_MOUSE_DOWN, function()
            if not B.IsOver(p.win, 0) then SkillList.Close() end
        end)
    end, 50)
end
