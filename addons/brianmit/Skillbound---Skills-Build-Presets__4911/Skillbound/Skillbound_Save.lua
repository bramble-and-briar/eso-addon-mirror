-- Skillbound_Save.lua : the save window (2026-10-01). Opens from "Save what I'm wearing"
-- (new build) and from a build's "..." menu (edit: name, picture, parts).
--   name  : text field (Enter saves)
--   picture: "automatic" (your ultimate) + 18 own icons (Textures/icons/*.dds, made by
--           _SkillboundDev/make_icons.ps1); hover lifts a tile and lights it, click pops
--           it and the amber selector glides over
--   parts : one toggle switch per part (gear, skills, champion, food, ...); a new build
--           only reads the parts that are on (the rest stays empty and is never touched
--           when you wear it). The last choice is remembered (sv.saveParts).
-- Same look and motion as the main window (ember panel, gilded corners, Skillbound_Anim).

local B = Skillbound
local L = B.L
local C = B.COLOR
local W = B.W
local Anim = B.Anim
local Capture = B.Capture
local Save = {}
B.Save = Save

local WIN_W, WIN_H = 536, 664
local PAD = 24
local TILE, TILE_GAP, TILES_PER_ROW = 40, 8, 10
local ROW_W, ROW_H, ROW_GAP = 236, 30, 6

Save.ICONS = { "sword", "swords", "shield", "heart", "bow", "staff", "flame", "frost", "lightning",
    "skull", "crown", "moon", "sun", "leaf", "eye", "hammer", "potion", "book" }
local ICON_DIR = B.TEX .. "icons/"

local PARTS = {
    { "gear", "PART_GEAR" }, { "skills", "PART_SKILLS" }, { "cp", "PART_CP" }, { "food", "PART_FOOD" },
    { "quick", "PART_QUICK" }, { "outfit", "PART_OUTFIT" }, { "title", "PART_TITLE" },
    { "collect", "PART_COLLECT" }, { "companion", "PART_COMPANION" },
}

local ui = { tiles = {}, rows = {} }
local state = {}   -- build (nil = new), icon (nil = automatic), parts

-- the icon "automatic" would show for a new build: the ultimate on your front bar now
local function AutoIcon()
    if state.build then
        local saved = state.build.icon
        state.build.icon = nil
        local icon = B.UI.BuildIcon(state.build)
        state.build.icon = saved
        return icon
    end
    local ok, e = pcall(Capture.SlotSkill, Capture.BARS[1], Capture.ULT_SLOT)
    if ok and e and e.id then return GetAbilityIcon(e.id) end
    return B.LOGO
end

-- ---------------------------------------------------------------------------
-- Picture tiles

local function TilePos(i)
    local col = (i - 1) % TILES_PER_ROW
    local row = math.floor((i - 1) / TILES_PER_ROW)
    return col * (TILE + TILE_GAP), row * (TILE + TILE_GAP)
end

local function PaintTile(t)
    local p = t.hoverP
    local chosen = t.icon == state.icon
    t.inner:SetScale(1 + 0.1 * p)
    Anim.Offset(t.inner, 0, -3 * p)
    t.glow:SetAlpha(0.35 * p + (chosen and 0.18 or 0))
    t.img:SetColor(1, 1, 1, Anim.Lerp(chosen and 1 or 0.78, 1, p))
end

-- the amber selector glides to the chosen tile
local function MoveSelector(instant)
    local index = 1
    for i, t in ipairs(ui.tiles) do
        if t.icon == state.icon then index = i end
    end
    local tx, ty = TilePos(index)
    local sel = ui.selector
    local fx, fy = sel.x or tx, sel.y or ty
    sel.x, sel.y = tx, ty
    if instant then
        Anim.Stop("Skillbound_SaveSel")
        Anim.Anchor(sel, CENTER, ui.grid, TOPLEFT, tx + TILE / 2, ty + TILE / 2)
        return
    end
    Anim.Run("Skillbound_SaveSel", Anim.STD, Anim.InOut, function(p)
        Anim.Anchor(sel, CENTER, ui.grid, TOPLEFT, Anim.Lerp(fx, tx, p) + TILE / 2, Anim.Lerp(fy, ty, p) + TILE / 2)
    end)
end

local function PaintTiles()
    for _, t in ipairs(ui.tiles) do PaintTile(t) end
end

local function MakeTile(i, icon)
    local t = WINDOW_MANAGER:CreateControl(nil, ui.grid, CT_CONTROL)
    t:SetDimensions(TILE, TILE)
    local x, y = TilePos(i)
    t:SetAnchor(TOPLEFT, ui.grid, TOPLEFT, x, y)
    t:SetMouseEnabled(true)
    t.icon = icon
    t.hoverP = 0
    t.inner = WINDOW_MANAGER:CreateControl(nil, t, CT_CONTROL)
    t.inner:SetDimensions(TILE, TILE)
    Anim.Anchor(t.inner, CENTER, t, CENTER, 0, 0)
    t.glow = W.Glow(t.inner, TILE * 1.9, TILE * 1.9, C.glow, 0)
    t.glow:SetAnchor(CENTER, t.inner, CENTER, 0, 0)
    t.img = W.Tex(t.inner, icon or AutoIcon(), TILE - 4, TILE - 4)
    t.img:SetAnchor(CENTER, t.inner, CENTER, 0, 0)
    t.img:SetDrawLevel(2)
    if not icon then
        -- "automatic": the game's own icon in a thin gold frame + a small AUTO tag
        t.frame = W.Frame(t.inner, C.goldDark, 1)
        t.tag = W.Label(t.inner, B.Font("head", 10), C.text, zo_strupper(L("ICON_AUTO_TAG")), TEXT_ALIGN_CENTER)
        t.tag:SetAnchor(BOTTOM, t.inner, BOTTOM, 0, 1)
        t.tag:SetDrawLevel(4)
        t.tagBg = W.Tex(t.inner, nil, TILE - 4, 12, C.slot, 0.75)
        t.tagBg:SetAnchor(BOTTOM, t.inner, BOTTOM, 0, -2)
        t.tagBg:SetDrawLevel(3)
    end
    local key = W.Name("Tile")
    local function Hover(on)
        local from = t.hoverP
        Anim.Run(key, Anim.MICRO, Anim.Out, function(p)
            t.hoverP = Anim.Lerp(from, on and 1 or 0, p)
            PaintTile(t)
        end)
    end
    t:SetHandler("OnMouseEnter", function()
        Hover(true)
        if not icon then
            InitializeTooltip(InformationTooltip, t, BOTTOM, 0, -6, TOP)
            SetTooltipText(InformationTooltip, L("ICON_AUTO_TT"))
        end
    end)
    t:SetHandler("OnMouseExit", function()
        Hover(false)
        ClearTooltip(InformationTooltip)
    end)
    t:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then t.inner:SetScale(0.94) end
    end)
    t:SetHandler("OnMouseUp", function(_, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        PaintTile(t)
        if not upInside then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        state.icon = t.icon   -- (the first tile can hold a build's own picture: t.icon, not icon)
        MoveSelector(false)
        PaintTiles()
        Anim.Pulse(t.img, 1.22, 260, key .. "P")
        Anim.Flash(ui.selGlow, C.theme, Anim.FLASH, "Skillbound_SaveFlash")
    end)
    ui.tiles[i] = t
end

-- ---------------------------------------------------------------------------
-- Toggle switches: a pill track (dark -> amber), a cream knob that glides across

local function PaintRow(r)
    local p, on = r.hoverP, r.onP
    r.bg:SetAlpha(0.35 + 0.5 * p)
    r.label:SetColor(Anim.Lerp(C.soft.r, C.text.r, math.max(on, p)), Anim.Lerp(C.soft.g, C.text.g, math.max(on, p)),
        Anim.Lerp(C.soft.b, C.text.b, math.max(on, p)), 1)
    r.track:SetColor(Anim.Lerp(C.slot.r, C.theme.r * 0.55, on), Anim.Lerp(C.slot.g, C.theme.g * 0.55, on),
        Anim.Lerp(C.slot.b, C.theme.b * 0.55, on), 1)
    local edge = on > 0.5 and C.theme or (p > 0.5 and C.gold or C.goldDark)
    r.edge:SetColor(B.RGBA(edge, Anim.Lerp(0.8, 1, math.max(on, p))))
    Anim.Offset(r.knob, 20 * on, 0)
    r.knob:SetColor(Anim.Lerp(C.dim.r, C.text.r, on), Anim.Lerp(C.dim.g, C.text.g, on), Anim.Lerp(C.dim.b, C.text.b, on), 1)
    r.knob:SetScale(1 + 0.12 * p)
    r.knobGlow:SetAlpha(0.45 * on)
    -- (dimmed on its parts: the row's own alpha belongs to the slide-in animation)
    local a = r.locked and 0.4 or 1
    r.label:SetAlpha(a)
    r.track:SetAlpha(a)
    r.edge:SetAlpha(a)
    r.knob:SetAlpha(a)
end

-- Companion (2026-10-04): the switch stays off and can't be turned on while there's no
-- companion to save (none summoned, and the build has no companion saved yet). It unlocks by
-- itself when you summon one with the window open. "All" leaves a locked switch alone.
local function CompanionLocked()
    if state.build and state.build.companion then return false end
    return not (HasActiveCompanion and HasActiveCompanion())
end

local function IsLocked(r) return r.locked == true end

local function AllOn()
    for _, r in ipairs(ui.rows) do
        if not IsLocked(r) and not state.parts[r.part] then return false end
    end
    return true
end

local function SetRow(r, on, animate)
    if r.part ~= "all" then state.parts[r.part] = on or nil end
    if r.part == "companion" and not r.locked then state.wantCompanion = on end
    local from, to = r.onP, on and 1 or 0
    if not animate then
        Anim.Stop(r.key .. "T")
        r.onP = to
        PaintRow(r)
        return
    end
    Anim.Run(r.key .. "T", Anim.STD, Anim.Out, function(p)
        r.onP = Anim.Lerp(from, to, p)
        PaintRow(r)
    end)
end

local SetAll   -- (below)

-- i = nil: the "All" switch on the header line (anchored by the caller)
local function MakeRow(i, def, parent)
    local r = WINDOW_MANAGER:CreateControl(nil, parent or ui.parts, CT_CONTROL)
    r:SetDimensions(i and ROW_W or 104, ROW_H)
    if i then
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        Anim.Anchor(r, TOPLEFT, ui.parts, TOPLEFT, col * (ROW_W + 16), row * (ROW_H + ROW_GAP))
    end
    r:SetMouseEnabled(true)
    r.part = def[1]
    r.key = W.Name("Switch")
    r.hoverP, r.onP = 0, 0
    r.bg = W.Tex(r, nil, nil, nil, C.hover)
    r.bg:SetAnchorFill(r)
    r.line = W.Tex(r, nil, 10, 1, C.line)
    r.line:SetAnchor(BOTTOMLEFT, r, BOTTOMLEFT, 0, 0)
    r.line:SetAnchor(BOTTOMRIGHT, r, BOTTOMRIGHT, 0, 0)
    r.label = W.Label(r, B.Font("head", 13), C.soft, L(def[2]))
    r.label:SetAnchor(LEFT, r, LEFT, 10, 0)
    -- the switch: 42 x 22 track, 16 px knob
    r.track = W.Tex(r, B.TEX .. "pill.dds", 42, 22)
    r.track:SetAnchor(RIGHT, r, RIGHT, -8, 0)
    r.edge = W.Tex(r, B.TEX .. "pill_edge.dds", 42, 22)
    r.edge:SetAnchor(CENTER, r.track, CENTER, 0, 0)
    r.edge:SetDrawLevel(2)
    r.knobGlow = W.Glow(r, 34, 34, C.theme, 0)
    r.knob = W.Tex(r, B.TEX .. "disc.dds", 16, 16)
    Anim.Anchor(r.knob, LEFT, r.track, LEFT, 3, 0)
    r.knob:SetDrawLevel(3)
    r.knobGlow:SetAnchor(CENTER, r.knob, CENTER, 0, 0)
    r.knobGlow:SetDrawLevel(1)
    local function Hover(on)
        local from = r.hoverP
        Anim.Run(r.key, Anim.MICRO, Anim.Out, function(p)
            r.hoverP = Anim.Lerp(from, on and 1 or 0, p)
            PaintRow(r)
        end)
    end
    r:SetHandler("OnMouseEnter", function()
        Hover(true)
        InitializeTooltip(InformationTooltip, r, BOTTOM, 0, -4, TOP)
        SetTooltipText(InformationTooltip, IsLocked(r) and L("COMPANION_LOCKED") or L("SAVE_TT_" .. string.upper(def[1])))
    end)
    r:SetHandler("OnMouseExit", function()
        Hover(false)
        ClearTooltip(InformationTooltip)
    end)
    r:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if IsLocked(r) then
            -- no companion out: say why, the switch stays off
            PlaySound(SOUNDS.NEGATIVE_CLICK)
            ui.note:SetText(B.Colorize(C.warn, L("COMPANION_LOCKED")))
            Anim.Shake(r, W.Name("LockShake"))
            return
        end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        if r.part == "all" then
            SetAll(not AllOn())
        else
            SetRow(r, not state.parts[r.part], true)
            SetRow(ui.allRow, AllOn(), true)
        end
        ui.note:SetText("")
    end)
    if i then ui.rows[i] = r end
    return r
end

-- all switches on / off, one after another (a small ripple down the list)
function SetAll(on)
    local n = 0
    for _, r in ipairs(ui.rows) do
        if not IsLocked(r) and (state.parts[r.part] and true or false) ~= on then
            state.parts[r.part] = on or nil
            n = n + 1
            B.Later(function()
                if (state.parts[r.part] and true or false) == on then SetRow(r, on, true) end   -- (not if clicked again meanwhile)
            end, n * 25)
        end
    end
    SetRow(ui.allRow, on, true)
    ui.note:SetText("")
end

-- lock / unlock the companion switch (unlocked: back to what you had chosen before)
-- (force: on opening; else only when it changed, e.g. you summoned one with the window open)
local function RefreshCompanionLock(animate, force)
    local r = ui.compRow
    if not r then return end
    local locked = CompanionLocked()
    if not force and locked == IsLocked(r) then return end
    local want = state.wantCompanion
    r.locked = locked
    SetRow(r, (not locked) and want or false, animate)
    SetRow(ui.allRow, AllOn(), animate)
end

-- ---------------------------------------------------------------------------
-- Window

local function Section(text, y)
    local h = W.Header(ui.win, text)
    h:SetAnchor(TOPLEFT, ui.win, TOPLEFT, PAD, y)
    h:SetAnchor(TOPRIGHT, ui.win, TOPRIGHT, -PAD, y)
    return h
end

function Save.Hide(instant)
    if not ui.win or ui.win:IsHidden() then return end
    ClearTooltip(InformationTooltip)
    ui.edit:LoseFocus()
    if instant then
        ui.win:SetHidden(true)
        return
    end
    local win = ui.win
    Anim.Run("Skillbound_SaveWin", Anim.CLOSE, Anim.In, function(p)
        win:SetAlpha(1 - p)
        win:SetScale(1 - 0.03 * p)
    end, function() win:SetHidden(true) end)
end

local function Commit()
    local name = zo_strtrim(ui.edit:GetText() or "")
    local any = false
    for _, def in ipairs(PARTS) do
        if state.parts[def[1]] then any = true end
    end
    if name == "" then
        ui.note:SetText(B.Colorize(C.warn, L("SAVE_NEED_NAME")))
        Anim.Shake(ui.editBox, "Skillbound_SaveShake")
        return
    end
    if not any then
        ui.note:SetText(B.Colorize(C.warn, L("SAVE_NEED_PART")))
        Anim.Shake(ui.parts, "Skillbound_SaveShake")
        return
    end
    local parts = {}
    for _, def in ipairs(PARTS) do parts[def[1]] = state.parts[def[1]] and true or false end
    local note = zo_strtrim(ui.notes:GetText() or "")
    if note == "" then note = nil end
    local b = state.build
    local autoEat = state.parts.autoEat and true or nil
    if b then
        b.name = name
        b.icon = state.icon
        b.note = note
        b.foodAuto = autoEat
        local refused = {}
        for part, on in pairs(parts) do
            if on and b[part] == nil then
                b[part] = Capture.Read(part)   -- nothing saved for it yet: read it now
                -- food stays on without one: you pick it on the build (click the food)
                if b[part] == nil and part ~= "food" then
                    on = false
                    refused[#refused + 1] = L(part == "companion" and "COMPANION_NEEDED" or "PART_EMPTY", L("PART_" .. string.upper(part)))
                end
            end
            b.parts[part] = on
        end
        if parts.food and not b.food then B.Print(L("FOOD_PICK_HINT")) end
        b.updated = GetTimeStamp()
        B.callbacks:FireCallbacks("BuildsChanged")
        -- (said in the middle of the screen: in chat only, it looked as if Save did nothing)
        for _, text in ipairs(refused) do B.Announce(text, true) end
    else
        -- remembered for next time; a locked companion switch keeps your earlier choice
        local remember = {}
        for k, v in pairs(parts) do remember[k] = v end
        if IsLocked(ui.compRow) then remember.companion = state.wantCompanion and true or false end
        B.sv.saveParts = remember
        B.sv.saveAutoEat = autoEat
        local nb = B.UI.SaveBuild(name, parts, state.icon, note)
        if nb then nb.foodAuto = autoEat end
        if parts.food and nb and not nb.food then B.Print(L("FOOD_PICK_HINT")) end
    end
    Save.Hide()
end

local function Create()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_SaveWindow")
    ui.win = win
    win:SetDimensions(WIN_W, WIN_H)
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    -- where you left it last time (also after a restart), else the middle of the screen
    if not W.RememberPlace(win, "save") then win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -20) end
    B.callbacks:RegisterCallback("PositionsReset", function() B.Anim.Anchor(win, CENTER, GuiRoot, CENTER, 0, -20) end)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_HIGH)

    local bg = W.Tex(win, B.BG)
    bg:SetAnchorFill(win)
    W.Frame(win, C.goldDark, 1)
    local inner = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    inner:SetAnchor(TOPLEFT, win, TOPLEFT, 5, 5)
    inner:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -5, -5)
    W.Frame(inner, C.line, 1)
    W.TopLight(win, 30, 0.5)
    W.Brackets(win)

    local logo = W.Tex(win, B.LOGO, 30, 30)
    logo:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 18)
    ui.title = W.Label(win, B.Font("title", 20), C.text, "")
    ui.title:SetAnchor(LEFT, logo, RIGHT, 10, 1)
    local close = W.CloseButton(win, function() Save.Hide() end, 20, L("CANCEL"))
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -16, 16)
    local sub = W.Label(win, B.Font("text", 13), C.dim, L("SAVE_WIN_SUB"))
    sub:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 54)

    Section(L("SAVE_NAME"), 84)
    local box, edit = W.Edit(win, WIN_W - 2 * PAD)
    Anim.Anchor(box, TOPLEFT, win, TOPLEFT, PAD, 104)
    edit:SetMaxInputChars(40)
    edit:SetHandler("OnEnter", function() Commit() end)
    edit:SetHandler("OnEscape", function() Save.Hide() end)
    ui.editBox, ui.edit = box, edit

    local picHead = Section(L("SAVE_PICTURE"), 146)
    ui.more = W.Button(win, L("ICON_MORE"), function()
        if state.build then B.UI.IconMenu(state.build) end
        Save.Hide()
    end, "quiet", 150, 16)
    ui.more:SetAnchor(RIGHT, picHead, RIGHT, 0, 0)
    ui.picLine = picHead.line
    ui.picHead = picHead
    ui.grid = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.grid:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 168)
    ui.grid:SetDimensions(TILES_PER_ROW * (TILE + TILE_GAP), 2 * (TILE + TILE_GAP))
    -- the selector (behind the tiles): soft amber light + a rounded amber frame
    ui.selGlow = W.Glow(ui.grid, TILE * 2.2, TILE * 2.2, C.theme, 0)
    ui.selGlow:SetHidden(true)
    ui.selector = W.Tex(ui.grid, B.TEX .. "rounded_edge.dds", TILE + 8, TILE + 8, C.theme)
    ui.selector:SetDrawLevel(5)
    ui.selGlow:SetAnchor(CENTER, ui.selector, CENTER, 0, 0)
    MakeTile(1, nil)
    for i, name in ipairs(Save.ICONS) do MakeTile(i + 1, ICON_DIR .. name .. ".dds") end

    local partsHead = Section(L("SAVE_PARTS"), 278)
    -- "All": a switch like the others, right after the "What to save" label
    ui.allRow = MakeRow(nil, { "all", "SAVE_ALL" }, win)
    ui.allRow:SetAnchor(LEFT, partsHead.label, RIGHT, 12, 0)
    partsHead.line:ClearAnchors()
    partsHead.line:SetAnchor(LEFT, ui.allRow, RIGHT, 10, 0)
    partsHead.line:SetAnchor(RIGHT, partsHead, RIGHT, 0, 0)
    ui.parts = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.parts:SetDimensions(2 * ROW_W + 16, 5 * (ROW_H + ROW_GAP))
    Anim.Anchor(ui.parts, TOPLEFT, win, TOPLEFT, PAD, 300)
    for i, def in ipairs(PARTS) do
        local r = MakeRow(i, def)
        if def[1] == "companion" then ui.compRow = r end
    end
    -- summoning / dismissing a companion while the window is open (un)locks its switch
    if EVENT_ACTIVE_COMPANION_STATE_CHANGED then
        B.EM:RegisterForEvent("Skillbound_SaveCompanion", EVENT_ACTIVE_COMPANION_STATE_CHANGED, function()
            B.Later(function() if Save.IsShown() then RefreshCompanionLock(true) end end, 300)
        end)
    end
    -- the free 10th spot: "Eat in dungeons" (not a part: "All" leaves it alone)
    ui.eatRow = MakeRow(#PARTS + 1, { "autoEat", "SAVE_AUTO_EAT" })
    ui.rows[#PARTS + 1] = nil

    -- notes (rotation, what it's for...): shown in the arch under the build's picture
    Section(L("SAVE_NOTES"), 492)
    local nbox, nedit = W.Edit(win, WIN_W - 2 * PAD, L("SAVE_NOTES_HINT"), true)
    nbox:SetHeight(56)
    nbox:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 512)
    nedit:SetMaxInputChars(300)
    ui.notes = nedit
    ui.notesGlow = W.Glow(nbox, WIN_W, 90, C.theme, 0)   -- (lights up once when opened for the notes)
    ui.notesGlow:SetAnchor(CENTER, nbox, CENTER, 0, 0)
    ui.notesGlow:SetHidden(true)

    -- footer: the game's divider, then [note ...... Cancel  Save build], all on one center line
    local footer = W.Divider(win, C.goldDark)
    footer:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PAD, -74)
    footer:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -PAD, -74)
    ui.ok = W.Button(win, "", Commit, "plate", 214, 42)   -- ("Save changes" needs the room)
    ui.ok:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -PAD, -20)
    local cancel = W.Button(win, L("CANCEL"), function() Save.Hide() end, "normal", 110, 34)
    cancel:SetAnchor(RIGHT, ui.ok, LEFT, -14, 0)
    ui.note = W.Label(win, B.Font("text", 13), C.warn, "")
    ui.note:SetAnchor(LEFT, win, BOTTOMLEFT, PAD, -41)
    ui.note:SetAnchor(RIGHT, cancel, LEFT, -10, 0)
    ui.note:SetMaxLineCount(2)
end

-- build = nil: save what you wear as a new build; else edit that build.
-- focusNotes: the cursor starts in the Notes box (the build menu's "Add notes..." / "Edit notes...")
function Save.Open(build, focusNotes)
    if not ui.win then Create() end
    state.build = build
    state.icon = build and build.icon or nil
    state.parts = {}
    local src = build and build.parts or B.sv.saveParts or Capture.DEFAULT_PARTS
    for _, def in ipairs(PARTS) do state.parts[def[1]] = src[def[1]] and true or nil end
    if build then state.parts.autoEat = build.foodAuto and true or nil else state.parts.autoEat = B.sv.saveAutoEat end
    ui.title:SetText(zo_strupper(L(build and "SAVE_WIN_EDIT" or "SAVE_WIN_NEW")))
    ui.ok:SetText(L(build and "SAVE_CHANGES" or "SAVE_BUTTON"))
    ui.more:SetHidden(build == nil)
    ui.picLine:ClearAnchors()
    ui.picLine:SetAnchor(LEFT, ui.picHead.label, RIGHT, 8, 0)
    ui.picLine:SetAnchor(RIGHT, build and ui.more or ui.picHead, build and LEFT or RIGHT, build and -10 or 0, 0)
    ui.note:SetText("")
    ui.edit:SetText(build and build.name or B.UI.DefaultName())
    ui.notes:SetText(build and build.note or "")
    -- a custom picture from the build's own skills / gear is not one of the tiles: show "automatic"
    local known = state.icon == nil
    for _, t in ipairs(ui.tiles) do
        if t.icon == state.icon then known = true end
    end
    ui.tiles[1].img:SetTexture(known and AutoIcon() or state.icon)
    ui.tiles[1].icon = (not known) and state.icon or nil
    for _, t in ipairs(ui.tiles) do
        t.hoverP = 0
        t.inner:SetScale(1)
    end
    PaintTiles()
    ui.selector.x, ui.selector.y = nil, nil
    MoveSelector(true)
    state.wantCompanion = state.parts.companion and true or false
    for _, r in ipairs(ui.rows) do
        r.hoverP = 0
        SetRow(r, state.parts[r.part] and true or false, false)
    end
    RefreshCompanionLock(false, true)
    ui.allRow.hoverP = 0
    SetRow(ui.allRow, AllOn(), false)
    ui.eatRow.hoverP = 0
    SetRow(ui.eatRow, state.parts.autoEat and true or false, false)

    local win = ui.win
    win:SetHidden(false)
    Anim.Run("Skillbound_SaveWin", Anim.OPEN, Anim.Out, function(p)
        win:SetAlpha(p)
        win:SetScale(0.96 + 0.04 * p)
    end)
    -- tiles and switches arrive one after another
    for i, t in ipairs(ui.tiles) do
        Anim.SlideIn(t.inner, 0, 8, Anim.STD, W.Name("TileIn"), 60 + i * 12, true)
    end
    for i, r in ipairs(ui.rows) do
        Anim.SlideIn(r, -10, 0, Anim.STD, W.Name("RowIn"), 120 + i * Anim.STAGGER, true)
    end
    if focusNotes then
        ui.notes:TakeFocus()
        if ui.notes.SetCursorPosition then ui.notes:SetCursorPosition(#(ui.notes:GetText() or "")) end
        Anim.Flash(ui.notesGlow, C.theme, Anim.FLASH, "Skillbound_NotesFlash")
    else
        ui.edit:TakeFocus()
        ui.edit:SelectAll()
    end
end

function Save.IsShown() return ui.win ~= nil and not ui.win:IsHidden() end
