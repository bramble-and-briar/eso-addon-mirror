-- Questbound_Story.lua : "Read the story": the conversations Skip dialogs clicked through,
-- kept per quest, in a small window (tracker right-click on a quest, /qb story, settings).
-- Saved in sv.skip.story = { { name, t, convos = { { npc, lines = { { w = "npc"|"you", s } } } } } },
-- newest quest first. A quest's story stays after it's done (its name is the key).

local W = Questbound
local L = W.L
local C = W.COLOR

local Story = {}
W.Story = Story

local MAX_QUESTS = 40      -- oldest stories are dropped beyond this
local MAX_CONVOS = 30      -- per quest
local MAX_LINES = 80       -- per conversation
local WIDTH, HEIGHT, PAD = 480, 540, 14
local MIN_W, MIN_H, MAX_W, MAX_H = 320, 220, 1000, 1200
local EDGE = 8             -- resize handles on every side / corner

local ui = {}
local current = 1          -- which story the window shows (index in the list)

local function List()
    local s = W.sv.skip
    s.story = s.story or {}
    return s.story
end

local function Find(name)
    for i, e in ipairs(List()) do
        if e.name == name then return i, e end
    end
end

-- name nil = "Other conversations"
function Story.Add(name, npc, lines)
    local list = List()
    local key = name or ""
    local i, entry = Find(key)
    if entry then
        table.remove(list, i)
    else
        entry = { name = key, convos = {} }
    end
    table.insert(list, 1, entry)   -- the newest story first
    entry.t = GetTimeStamp()
    local kept = {}
    for n = math.max(1, #lines - MAX_LINES + 1), #lines do kept[#kept + 1] = lines[n] end
    entry.convos[#entry.convos + 1] = { npc = npc, lines = kept }
    while #entry.convos > MAX_CONVOS do table.remove(entry.convos, 1) end
    while #list > MAX_QUESTS do table.remove(list) end
    if ui.win and not ui.win:IsHidden() then Story.Paint() end
end

function Story.Has(name)
    return Find(name or "") ~= nil
end

-- ---------------------------------------------------------------------------
-- Window

local function Label(parent, font, color)
    local l = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    l:SetFont(font)
    l:SetColor(W.RGBA(color))
    return l
end

-- a small clickable text ("‹" / "›"): bright on hover
local function Arrow(text, tip, onClick)
    local a = Label(ui.win, "$(BOLD_FONT)|22|soft-shadow-thin", C.theme)
    a:SetText(text)
    a:SetMouseEnabled(true)
    a:SetDrawLevel(3)   -- above the header's drag area
    a:SetHandler("OnMouseEnter", function(self)
        if self.enabled then self:SetColor(1, 1, 1, 1) end
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
        SetTooltipText(InformationTooltip, L(tip))
    end)
    a:SetHandler("OnMouseExit", function(self)
        Story.PaintArrows()
        ClearTooltip(InformationTooltip)
    end)
    a:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and self.enabled then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            onClick()
        end
    end)
    return a
end

-- the text wraps to the window's width; the scroll area grows with the text
function Story.Fit()
    if not ui.text then return end
    ui.text:SetWidth(ui.win:GetWidth() - PAD * 2 - 24)
    ui.child:SetHeight(ui.text:GetTextHeight() + 12)
end

-- where you left it, else the middle of the screen
function Story.Place()
    local win = ui.win
    if not win then return end
    local pos, size = W.sv.skip.storyPos, W.sv.skip.storySize
    win:SetDimensions(size and size.w or WIDTH, size and size.h or HEIGHT)
    Story.Fit()
    win:ClearAnchors()
    if pos and pos.x and pos.y then
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    else
        win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -40)
    end
end

local function Build()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Questbound_Story")
    ui.win = win
    local size = W.sv.skip.storySize
    win:SetDimensions(size and size.w or WIDTH, size and size.h or HEIGHT)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetDrawTier(DT_HIGH)
    win:SetHidden(true)
    Story.Place()
    -- resizable from every side and corner (like the tracker); the text re-wraps while you drag
    win:SetResizeHandleSize(EDGE)
    win:SetDimensionConstraints(MIN_W, MIN_H, MAX_W, MAX_H)
    win:SetHandler("OnResizeStart", function(self)
        self:SetHandler("OnUpdate", function() Story.Fit() end)
    end)
    win:SetHandler("OnResizeStop", function(self)
        self:SetHandler("OnUpdate", nil)
        Story.Fit()
        W.sv.skip.storySize = { w = zo_round(self:GetWidth()), h = zo_round(self:GetHeight()) }
        W.sv.skip.storyPos = { x = zo_round(self:GetLeft()), y = zo_round(self:GetTop()) }
    end)

    local bg = WINDOW_MANAGER:CreateControl(nil, win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetEdgeTexture("", 1, 1, 1)
    ui.bg = bg   -- (colors: Story.Paint, from the color theme)

    -- Moved by dragging the header (title area). Not SetMovable on the window: a movable
    -- window takes its buttons' clicks (same as the tracker). Where you leave it is kept
    -- in sv.skip.storyPos (top left).
    local drag = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    drag:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
    drag:SetAnchor(BOTTOMRIGHT, win, TOPRIGHT, 0, 64)
    drag:SetMouseEnabled(true)
    drag:SetDrawLevel(1)
    drag:SetHitInsets(EDGE, EDGE, -EDGE, 0)   -- the top edge and corners stay resize handles
    local dx, dy
    drag:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local mx, my = GetUIMousePosition()
        dx, dy = win:GetLeft() - mx, win:GetTop() - my
        drag:SetHandler("OnUpdate", function()
            local x, y = GetUIMousePosition()
            win:ClearAnchors()
            win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x + dx, y + dy)
        end)
    end)
    drag:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not dx then return end
        drag:SetHandler("OnUpdate", nil)
        dx, dy = nil, nil
        W.sv.skip.storyPos = { x = zo_round(win:GetLeft()), y = zo_round(win:GetTop()) }
    end)

    ui.title = Label(win, W.Font("title", 18), C.theme)
    ui.title:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, PAD - 2)
    ui.title:SetAnchor(TOPRIGHT, win, TOPRIGHT, -96, PAD - 2)
    ui.title:SetMaxLineCount(1)
    ui.title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    ui.sub = Label(win, W.Font("text", 13), C.dim)
    ui.sub:SetAnchor(TOPLEFT, ui.title, BOTTOMLEFT, 0, 2)

    local close = WINDOW_MANAGER:CreateControlFromVirtual("Questbound_StoryClose", win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -8, 8)
    close:SetDrawLevel(3)   -- above the header's drag area
    close:SetHandler("OnClicked", function() Story.Close() end)

    -- older / newer story (the list is newest first)
    ui.next = Arrow("›", "STORY_OLDER", function() current = current + 1; Story.Paint() end)
    ui.next:SetAnchor(RIGHT, close, LEFT, -14, 0)
    ui.prev = Arrow("‹", "STORY_NEWER", function() current = current - 1; Story.Paint() end)
    ui.prev:SetAnchor(RIGHT, ui.next, LEFT, -12, 0)

    local rule = WINDOW_MANAGER:CreateControl(nil, win, CT_TEXTURE)
    ui.rule = rule
    rule:SetHeight(1)
    rule:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 64)
    rule:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PAD, 64)

    ui.scroll = WINDOW_MANAGER:CreateControlFromVirtual("Questbound_StoryScroll", win, "ZO_ScrollContainer")
    ui.scroll:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 72)
    ui.scroll:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -PAD + 4, -PAD)
    ui.child = ui.scroll:GetNamedChild("ScrollChild")
    ui.text = Label(ui.child, W.Font("text", 15), C.text)
    ui.text:SetAnchor(TOPLEFT, ui.child, TOPLEFT, 0, 0)
    Story.Fit()

    -- Escape closes it, and the mouse cursor shows while it's open
    if SCENE_MANAGER and SCENE_MANAGER.RegisterTopLevel then
        pcall(SCENE_MANAGER.RegisterTopLevel, SCENE_MANAGER, win, false)
        ui.topLevel = true
    end
end

function Story.PaintArrows()
    if not ui.win then return end
    local n = #List()
    ui.prev.enabled = current > 1
    ui.next.enabled = current < n
    for _, a in ipairs({ ui.prev, ui.next }) do
        a:SetHidden(n < 2)
        if a.enabled then a:SetColor(W.RGBA(C.theme)) else a:SetColor(C.dim.r, C.dim.g, C.dim.b, 0.35) end
    end
end

function Story.Paint()
    local list = List()
    current = zo_clamp(current, 1, math.max(1, #list))
    local entry = list[current]
    ui.title:SetFont(W.Font("title", 18))
    ui.text:SetFont(W.Font("text", 15))
    -- the color theme
    ui.bg:SetCenterColor(C.panel.r, C.panel.g, C.panel.b, 0.95)
    ui.bg:SetEdgeColor(C.gold.r, C.gold.g, C.gold.b, 0.6)
    ui.rule:SetColor(C.gold.r, C.gold.g, C.gold.b, 0.4)
    ui.title:SetColor(W.RGBA(C.theme))
    ui.sub:SetColor(W.RGBA(C.dim))
    ui.text:SetColor(W.RGBA(C.text))
    if not entry then
        ui.title:SetText(L("STORY_TITLE"))
        ui.sub:SetText("")
        ui.text:SetText(W.Colorize(C.dim, L("STORY_EMPTY")))
    else
        ui.title:SetText(entry.name ~= "" and entry.name or L("STORY_OTHER"))
        ui.sub:SetText(L("STORY_SUB", #entry.convos, current, #list))
        -- each conversation: the NPC's name, then what they said (the game's text color)
        -- and the answers given ("› ...", dim)
        local parts = {}
        for _, c in ipairs(entry.convos) do
            local block = { W.Colorize(C.theme, zo_strupper(c.npc or L("STORY_SOMEONE"))) }
            for _, line in ipairs(c.lines) do
                if line.w == "you" then
                    block[#block + 1] = W.Colorize(C.dim, "› " .. line.s)
                else
                    block[#block + 1] = W.Colorize(C.quest, line.s)
                end
            end
            parts[#parts + 1] = table.concat(block, "\n\n")
        end
        ui.text:SetText(table.concat(parts, "\n\n\n"))
    end
    Story.Fit()
    if ZO_Scroll_ResetToTop then ZO_Scroll_ResetToTop(ui.scroll) end
    Story.PaintArrows()
end

-- name = a quest's story (nil: the newest one)
function Story.Open(name)
    if not ui.win then Build() end
    current = name and Find(name) or 1
    Story.Paint()
    if ui.topLevel then
        SCENE_MANAGER:ShowTopLevel(ui.win)
    else
        ui.win:SetHidden(false)
    end
end

function Story.Close()
    if not ui.win then return end
    if ui.topLevel then
        SCENE_MANAGER:HideTopLevel(ui.win)
    else
        ui.win:SetHidden(true)
    end
end
