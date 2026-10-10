KApplicationHistory = KApplicationHistory or {}
local GFA = KApplicationHistory

local ADDON_NAME = "KApplicationHistory"

local MAX_HISTORY = 100

GFA.pending = {}
GFA.hints   = {}

local STATUS_TEXT = {
    pending  = "Pending",
    joined   = "Joined",
    accepted = "Accepted",
    declined = "Declined",
    expired  = "Expired",
    removed  = "Removed",
}

local function isInGroup(displayName)
    if not displayName or displayName == "" then return false end
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and GetUnitDisplayName(tag) == displayName then return true end
    end
    return false
end

local function setColor(label, color)
    label:SetColor(color:UnpackRGBA())
end

local function clean(name)
    if not name or name == "" then return "" end
    return zo_strformat("<<1>>", name)
end

local function roleText(role)
    if role == LFG_ROLE_TANK then return "Tank" end
    if role == LFG_ROLE_HEAL then return "Healer" end
    if role == LFG_ROLE_DPS  then return "DPS" end
    return "?"
end

local function history()
    return GFA.SV and GFA.SV.history or {}
end

local function hasListing()
    return HasGroupListingForUserType(GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING)
end

local ROLE_ICONS = {
    { role = LFG_ROLE_TANK, texture = "EsoUI/Art/LFG/LFG_tank_up.dds" },
    { role = LFG_ROLE_HEAL, texture = "EsoUI/Art/LFG/LFG_healer_up.dds" },
    { role = LFG_ROLE_DPS,  texture = "EsoUI/Art/LFG/LFG_dps_up.dds" },
}
local CP_ICON = "EsoUI/Art/Champion/Champion_Icon_32.dds"

local function levelNumber(entry)
    if entry.cp and entry.cp > 0 then return tostring(entry.cp), true end
    if entry.level and entry.level > 0 then return tostring(entry.level), false end
    return "", false
end

local function levelText(entry)
    if entry.cp and entry.cp > 0 then return "CP" .. entry.cp end
    if entry.level and entry.level > 0 then return "L" .. entry.level end
    return ""
end

local function upsert(charId)
    if not charId then return nil end
    local displayName, characterName, classId, level, cp, role = GetGroupListingApplicationInfoByCharacterId(charId)
    if not displayName or displayName == "" then return nil end

    local key   = Id64ToString(charId)
    local entry = GFA.pending[key]
    local isNew = false

    if not entry then
        entry = { key = key, time = GetTimeStamp(), status = "pending" }
        table.insert(history(), 1, entry)
        while #history() > MAX_HISTORY do table.remove(history()) end
        GFA.pending[key] = entry
        isNew = true
    end

    entry.displayName   = clean(displayName)
    entry.characterName = clean(characterName)
    entry.classId       = classId
    entry.level         = level
    entry.cp            = cp
    entry.role          = role

    local note = GetGroupListingApplicationNoteByCharacterId(charId)
    if note and note ~= "" then entry.note = note end

    local remaining = GetGroupListingApplicationTimeRemainingSecondsByCharacterId(charId) or 0
    entry.expiresAt = GetTimeStamp() + remaining

    return entry, isNew
end

local function scanPending()
    local seen = {}
    local id = GetNextGroupListingApplicationCharacterId(nil)
    local guard = 0
    while id and guard < 200 do
        guard = guard + 1
        local entry = upsert(id)
        if entry then
            seen[entry.key] = true
        end
        id = GetNextGroupListingApplicationCharacterId(id)
    end
    return seen
end

local function finalize(entry, forcedStatus)
    local hint = GFA.hints[entry.key]
    GFA.hints[entry.key] = nil

    local status = forcedStatus
    if not status then
        if hint then
            status = hint
        elseif entry.displayName and isInGroup(entry.displayName) then
            status = "joined"
        elseif GetTimeStamp() >= ((entry.expiresAt or 0) - 3) then
            status = "expired"
        else
            status = "removed"
        end
    end

    entry.status = status
    GFA.pending[entry.key] = nil
end

local function sweep()
    local seen = scanPending()
    if hasListing() then
        for key, entry in pairs(GFA.pending) do
            if not seen[key] then finalize(entry) end
        end
    end
    GFA:Refresh()
end

GFA.views = {}

local function menuIsOpen()
    if IsMenuVisible then return IsMenuVisible() end
    return ZO_Menu ~= nil and not ZO_Menu:IsHidden()
end

local function setViewsMenuMode(open)
    for _, view in ipairs(GFA.views) do
        local win = view.window
        win:SetMouseEnabled(not open)
        win:SetDrawLayer(open and DL_CONTROLS or DL_OVERLAY)
        win:SetDrawTier(open and DT_LOW or DT_MEDIUM)
        for _, row in ipairs(view.rows) do row:SetMouseEnabled(not open) end
    end
end

local function showMenuOnTop(anchor)
    ClearTooltip(InformationTooltip)
    ShowMenu(anchor)
    GFA.menuOpen = true
    setViewsMenuMode(true)
end

local function showRowTooltip(row)
    local e = row.entry
    if not e then return end
    InitializeTooltip(InformationTooltip, row, BOTTOM, 0, -30)
    InformationTooltip:SetDrawLayer(DL_TEXT)
    InformationTooltip:SetDrawTier(DT_HIGH)
    InformationTooltip:SetDrawLevel(10000)
    local text = (e.note and e.note ~= "") and e.note or "(no message)"
    SetTooltipText(InformationTooltip, text)
end

local function showRowMenu(row)
    local e = row.entry
    if not e or not e.displayName then return end
    ClearMenu()

    AddMenuItem("Whisper " .. e.displayName, function()
        StartChatInput("/w " .. e.displayName .. " ")
    end)

    if not IsUnitGrouped("player") or IsUnitGroupLeader("player") then
        AddMenuItem("Invite to group", function()
            GroupInviteByName(e.displayName)
        end)
    end

    if e.note and e.note ~= "" then
        AddMenuItem("Copy message to chat box", function()
            StartChatInput(e.displayName .. ": " .. e.note)
        end)
    end

    AddMenuItem(" ", function() end)
    AddMenuItem("Remove from history", function()
        local h = history()
        for i, v in ipairs(h) do
            if v == e then
                table.remove(h, i)
                break
            end
        end
        GFA.pending[e.key] = nil
        GFA:Refresh()
    end)

    showMenuOnTop(row)
end

local function createView(cfg)
    local wm = WINDOW_MANAGER
    local view = { cfg = cfg, offset = 0, rows = {} }
    local W, RC, RH = cfg.width, cfg.rows, cfg.rowHeight
    local HEAD, FOOT = cfg.header, cfg.footer

    local win = wm:CreateTopLevelWindow(cfg.name)
    win:SetDimensions(W, HEAD + RC * RH + FOOT)
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_MEDIUM)
    win:SetDrawLevel(0)
    win:SetHandler("OnMouseWheel", function(_, delta) GFA:ScrollView(view, delta) end)

    local bg = wm:CreateControl(cfg.name .. "_BG", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0, 0, 0, cfg.bgAlpha)
    bg:SetEdgeColor(1, 1, 1, cfg.standalone and 0.3 or 0)

    local title = wm:CreateControl(cfg.name .. "_Title", win, CT_LABEL)
    title:SetFont(cfg.standalone and "ZoFontWinH5" or "ZoFontHeader2")
    title:SetAnchor(TOPLEFT, win, TOPLEFT, cfg.standalone and 12 or 10, cfg.standalone and 10 or 4)
    setColor(title, ZO_NORMAL_TEXT)
    view.title = title

    local RW = W - 20
    local roleX = RW - 135
    local lvlX = roleX - 85
    local classX = lvlX - 70
    view.cols = { class = classX, lvl = lvlX, role = roleX }

    local function columnHeader(text, x)
        local lbl = wm:CreateControl(cfg.name .. "_Col" .. text, win, CT_LABEL)
        lbl:SetFont(cfg.standalone and "ZoFontGameSmall" or "ZoFontHeader2")
        lbl:SetText(text)
        setColor(lbl, ZO_NORMAL_TEXT)
        lbl:SetDimensions(80, 24)
        lbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        lbl:SetAnchor(TOP, win, TOPLEFT, 10 + x, cfg.standalone and 26 or 4)
    end
    columnHeader("CLASS", classX)
    columnHeader("LVL", lvlX)
    columnHeader("ROLE", roleX)

    local clear = wm:CreateControl(cfg.name .. "_Clear", win, CT_LABEL)
    clear:SetFont("ZoFontGameSmall")
    clear:SetText("[ Clear history ]")
    setColor(clear, ZO_NORMAL_TEXT)
    clear:SetDimensions(190, 20)
    clear:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    clear:SetMouseEnabled(true)
    clear:SetHandler("OnMouseEnter", function() if not GFA.clearArmed then setColor(clear, ZO_SELECTED_TEXT) end end)
    clear:SetHandler("OnMouseExit",  function() if not GFA.clearArmed then setColor(clear, ZO_NORMAL_TEXT) end end)
    clear:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if GFA.clearArmed then
            GFA:ResetClearLabels()
            GFA:ClearHistory()
        else
            GFA:ArmClear()
        end
    end)
    view.clearLabel = clear

    if not cfg.standalone then
        local divider = wm:CreateControl(cfg.name .. "_Divider", win, CT_TEXTURE)
        divider:SetTexture("EsoUI/Art/Miscellaneous/horizontalDivider.dds")
        divider:SetDimensions(W, 4)
        divider:SetAnchor(TOPLEFT, win, TOPLEFT, 0, HEAD - 5)
    end

    if cfg.standalone then
        win:SetMovable(true)
        win:SetClampedToScreen(true)
        local pos = GFA.SV.position or { x = 400, y = 200 }
        win:ClearAnchors()
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
        win:SetHandler("OnMoveStop", function()
            GFA.SV.position = { x = win:GetLeft(), y = win:GetTop() }
        end)

        local close = wm:CreateControl(cfg.name .. "_Close", win, CT_LABEL)
        close:SetFont("ZoFontWinH4")
        close:SetText("X")
        setColor(close, ZO_NORMAL_TEXT)
        close:SetDimensions(24, 24)
        close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -8, 8)
        close:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        close:SetMouseEnabled(true)
        close:SetHandler("OnMouseEnter", function() setColor(close, ZO_SELECTED_TEXT) end)
        close:SetHandler("OnMouseExit",  function() setColor(close, ZO_NORMAL_TEXT) end)
        close:SetHandler("OnMouseUp", function(_, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then GFA:Toggle() end
        end)
        clear:SetAnchor(TOPRIGHT, close, TOPLEFT, -10, 3)
    else
        clear:SetAnchor(TOPRIGHT, win, TOPRIGHT, -8, 4)
    end

    for i = 1, RC do
        local row = wm:CreateControl(cfg.name .. "_Row" .. i, win, CT_CONTROL)
        row:SetDimensions(W - 20, RH)
        row:SetAnchor(TOPLEFT, win, TOPLEFT, 10, HEAD + (i - 1) * RH)
        row:SetMouseEnabled(true)

        local hl = wm:CreateControl(row:GetName() .. "_HL", row, CT_BACKDROP)
        hl:SetAnchorFill(row)
        hl:SetCenterColor(1, 1, 1, 0.08)
        hl:SetEdgeColor(0, 0, 0, 0)
        hl:SetHidden(true)
        row.hl = hl

        local line1 = wm:CreateControl(row:GetName() .. "_L1", row, CT_LABEL)
        line1:SetFont("ZoFontGame")
        setColor(line1, ZO_SECOND_CONTRAST_TEXT or ZO_ColorDef:New(0.46, 0.74, 0.77, 1))
        line1:SetDimensions(classX - 30, RH)
        line1:SetAnchor(LEFT, row, LEFT, cfg.standalone and 6 or 0, 0)
        line1:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        line1:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.line1 = line1

        local classIcon = wm:CreateControl(row:GetName() .. "_Class", row, CT_TEXTURE)
        classIcon:SetDimensions(26, 26)
        classIcon:SetAnchor(CENTER, row, LEFT, classX, 0)
        row.classIcon = classIcon

        local cpIcon = wm:CreateControl(row:GetName() .. "_CP", row, CT_TEXTURE)
        cpIcon:SetTexture(CP_ICON)
        cpIcon:SetDimensions(22, 22)
        cpIcon:SetAnchor(LEFT, row, LEFT, lvlX - 32, 0)
        row.cpIcon = cpIcon

        local lvl = wm:CreateControl(row:GetName() .. "_Lvl", row, CT_LABEL)
        lvl:SetFont("ZoFontGame")
        setColor(lvl, ZO_SECOND_CONTRAST_TEXT or ZO_ColorDef:New(0.46, 0.74, 0.77, 1))
        lvl:SetDimensions(48, RH)
        lvl:SetAnchor(LEFT, row, LEFT, lvlX - 8, 0)
        lvl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        row.lvl = lvl

        row.roleIcons = {}
        for r, info in ipairs(ROLE_ICONS) do
            local icon = wm:CreateControl(row:GetName() .. "_Role" .. r, row, CT_TEXTURE)
            icon:SetTexture(info.texture)
            icon:SetDimensions(24, 24)
            icon:SetAnchor(CENTER, row, LEFT, roleX + (r - 2) * 28, 0)
            icon.role = info.role
            row.roleIcons[r] = icon
        end

        local status = wm:CreateControl(row:GetName() .. "_ST", row, CT_LABEL)
        status:SetFont("ZoFontGame")
        setColor(status, ZO_NORMAL_TEXT)
        status:SetDimensions(100, RH)
        status:SetAnchor(RIGHT, row, RIGHT, -6, 0)
        status:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        status:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        row.status = status

        row:SetHandler("OnMouseEnter", function(ctrl)
            ctrl.hl:SetHidden(false)
            showRowTooltip(ctrl)
        end)
        row:SetHandler("OnMouseExit", function(ctrl)
            ctrl.hl:SetHidden(true)
            ClearTooltip(InformationTooltip)
        end)
        row:SetHandler("OnMouseUp", function(ctrl, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then showRowMenu(ctrl) end
        end)
        row:SetHandler("OnMouseWheel", function(_, delta) GFA:ScrollView(view, delta) end)

        view.rows[i] = row
    end

    local footer = wm:CreateControl(cfg.name .. "_Footer", win, CT_LABEL)
    footer:SetFont("ZoFontGameSmall")
    setColor(footer, ZO_DISABLED_TEXT)
    footer:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, cfg.standalone and 12 or 10, cfg.standalone and -8 or 10)
    view.footer = footer

    view.window = win
    table.insert(GFA.views, view)
    return view
end

local function refreshView(view)
    local cfg = view.cfg
    local h = history()
    local total = #h
    local maxOffset = math.max(0, total - cfg.rows)
    if view.offset > maxOffset then view.offset = maxOffset end
    if view.offset < 0 then view.offset = 0 end

    local pendingCount = 0
    for _ in pairs(GFA.pending) do pendingCount = pendingCount + 1 end
    local pendTxt = pendingCount > 0 and string.format("  -  %d PENDING", pendingCount) or ""
    if cfg.standalone then
        view.title:SetText(string.format("::[KApplicationHistory]:: Group Finder applicants (%d)%s", total, pendTxt))
    else
        view.title:SetText(string.format("APPLICATION HISTORY (%d)", total))
    end

    for i, row in ipairs(view.rows) do
        local e = h[view.offset + i]
        row.entry = e
        if e then
            row:SetHidden(false)
            row.line1:SetText(string.format("%s  (%s)", e.displayName or "?", e.characterName or "?"))
            row.status:SetText(STATUS_TEXT[e.status] or tostring(e.status))
            setColor(row.status, e.status == "pending" and ZO_SELECTED_TEXT or ZO_NORMAL_TEXT)

            local classTexture = e.classId and e.classId > 0 and GetClassIcon and GetClassIcon(e.classId) or nil
            if classTexture and classTexture ~= "" then
                row.classIcon:SetTexture(classTexture)
                row.classIcon:SetHidden(false)
            else
                row.classIcon:SetHidden(true)
            end

            local lvlStr, isCP = levelNumber(e)
            row.lvl:SetText(lvlStr)
            row.cpIcon:SetHidden(not isCP)

            for _, icon in ipairs(row.roleIcons) do
                local active = icon.role == e.role
                icon:SetAlpha(active and 1 or 0.3)
                icon:SetDesaturation(active and 0 or 1)
            end
        else
            row:SetHidden(true)
        end
    end

    if total == 0 then
        view.footer:SetText("No applications recorded yet.")
    else
        view.footer:SetText(string.format("::[KApplicationHistory]:: %d-%d of %d   -   right-click a row for options, mouse wheel to scroll",
            view.offset + 1, math.min(view.offset + cfg.rows, total), total))
    end
end

function GFA:ResetClearLabels()
    self.clearArmed = false
    self.clearToken = (self.clearToken or 0) + 1
    for _, view in ipairs(self.views) do
        if view.clearLabel then
            view.clearLabel:SetText("[ Clear history ]")
            setColor(view.clearLabel, ZO_NORMAL_TEXT)
        end
    end
end

function GFA:ArmClear()
    self.clearArmed = true
    self.clearToken = (self.clearToken or 0) + 1
    local token = self.clearToken
    for _, view in ipairs(self.views) do
        if view.clearLabel then
            view.clearLabel:SetText("[ CONFIRM ]")
            setColor(view.clearLabel, ZO_SELECTED_TEXT)
        end
    end
    zo_callLater(function()
        if GFA.clearToken == token then GFA:ResetClearLabels() end
    end, 4000)
end

function GFA:ScrollView(view, delta)
    view.offset = view.offset - delta
    refreshView(view)
end

function GFA:Refresh()
    for _, view in ipairs(self.views) do refreshView(view) end
end

function GFA:ClearHistory()
    ZO_ClearNumericallyIndexedTable(history())
    ZO_ClearTable(self.pending)
    ZO_ClearTable(self.hints)
    for _, view in ipairs(self.views) do view.offset = 0 end
    self:Refresh()
end

function GFA:Toggle()
    if not self.SV then return end
    if not self.main then
        self.main = createView({
            name = "KApplicationHistoryWindow", standalone = true,
            width = 720, rows = 10, rowHeight = 32, header = 44, footer = 30, bgAlpha = 0.75,
        })
    end
    local win = self.main.window

    if not win:IsHidden() then
        win:SetHidden(true)
        ClearTooltip(InformationTooltip)
        if self.enteredUIMode then
            self.enteredUIMode = false
            SCENE_MANAGER:SetInUIMode(false)
        end
        return
    end

    local alreadyUI = SCENE_MANAGER.IsInUIMode and SCENE_MANAGER:IsInUIMode()
    if not alreadyUI then
        self.enteredUIMode = true
        SCENE_MANAGER:SetInUIMode(true)
    end

    sweep()
    win:SetHidden(false)
    self:Refresh()
end

function KApplicationHistory_Toggle()
    GFA:Toggle()
end

local EMBED_OFFSET_X = -324
local EMBED_OFFSET_Y = 300
local ROOT_CANDIDATES = { "ZO_GroupMenu_Keyboard", "ZO_GroupFinder_Keyboard", "ZO_GroupFinder_KeyboardTopLevel" }

local function findRoot()
    for _, name in ipairs(ROOT_CANDIDATES) do
        local c = _G[name]
        if c and c.IsControlHidden then return c, name end
    end
    return GuiRoot, "GuiRoot (fallback search)"
end

local function isHeaderText(t)
    if not t then return false end
    t = t:lower()
    return t:find("pending", 1, true) and (t:find("group", 1, true) or t:find("request", 1, true)) and true or false
end

local function findHeader(root, limit, collect)
    local queue, head, guard = { root }, 1, 0
    limit = limit or 6000
    while queue[head] and guard < limit do
        local c = queue[head]
        head = head + 1
        guard = guard + 1
        if c:GetType() == CT_LABEL then
            local t = c:GetText()
            if isHeaderText(t) then
                if not collect then return c end
                table.insert(collect, c)
            end
        end
        for i = 1, c:GetNumChildren() do
            queue[#queue + 1] = c:GetChild(i)
        end
    end
end

local function reallyVisible(c)
    local guard = 0
    while c and guard < 30 do
        if c:IsHidden() or c:GetAlpha() < 0.05 then return false end
        c = c:GetParent()
        guard = guard + 1
    end
    return true
end

local function pickBestHeader(list)
    local best, bestX
    for _, c in ipairs(list) do
        if reallyVisible(c) then
            local cx = c:GetCenter()
            if cx and (not bestX or cx > bestX) then best, bestX = c, cx end
        end
    end
    return best
end

local function findHeaderEverywhere()
    local found = {}
    local root = findRoot()
    findHeader(root, 6000, found)
    local best = pickBestHeader(found)
    if not best and root ~= GuiRoot then
        found = {}
        findHeader(GuiRoot, 60000, found)
        best = pickBestHeader(found)
    end
    return best
end

local function findLeftLabel(header)
    local top = header
    for _ = 1, 3 do
        if top:GetParent() then top = top:GetParent() end
    end
    local queue, head, guard = { top }, 1, 0
    while queue[head] and guard < 3000 do
        local c = queue[head]
        head = head + 1
        guard = guard + 1
        if c:GetType() == CT_LABEL then
            local t = c:GetText()
            if t and t:lower():find("character name", 1, true) then return c end
        end
        for i = 1, c:GetNumChildren() do queue[#queue + 1] = c:GetChild(i) end
    end
end

local function currentSceneName()
    local sm = SCENE_MANAGER
    local sc = sm and sm.GetCurrentScene and sm:GetCurrentScene()
    if sc and sc.GetName then return sc:GetName() or "" end
    return ""
end

local ICON_SIZE = 40
local ICON_TEXTURE      = "EsoUI/Art/MainMenu/menuBar_group_up.dds"
local ICON_TEXTURE_OVER = "EsoUI/Art/MainMenu/menuBar_group_over.dds"
local ICON_SCENES = { hud = true, hudui = true }

local function iconSV()
    GFA.SV.icon = GFA.SV.icon or { x = 200, y = 200, locked = false, enabled = true }
    return GFA.SV.icon
end

local function updateIconLockVisual()
    local win = GFA.iconWin
    if not win then return end
    local locked = iconSV().locked
    win:SetMovable(not locked)
    if locked then
        win.bg:SetEdgeColor(0.5, 0.5, 0.5, 0.6)
    else
        win.bg:SetEdgeColor(1, 0.85, 0.3, 0.9)
    end
end

local function showIconTooltip(ctrl)
    InitializeTooltip(InformationTooltip, ctrl, BOTTOM, 0, -10)
    local state = iconSV().locked and "Locked" or "Unlocked"
    SetTooltipText(InformationTooltip, string.format(
        "KApplicationHistory\nLeft-click: open/close\nRight-click: lock/unlock position (%s)\nDrag to move%s",
        state, iconSV().locked and " (unlock first)" or ""))
end

local function createIcon()
    if GFA.iconWin then return end
    local wm = WINDOW_MANAGER
    local sv = iconSV()

    local win = wm:CreateTopLevelWindow("KApplicationHistoryIcon")
    win:SetDimensions(ICON_SIZE, ICON_SIZE)
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_MEDIUM)
    win:SetDrawLevel(0)
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x or 200, sv.y or 200)

    local bg = wm:CreateControl("KApplicationHistoryIcon_BG", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0, 0, 0, 0.55)
    bg:SetEdgeColor(1, 0.85, 0.3, 0.9)
    bg:SetEdgeTexture("", 1, 1, 1)
    win.bg = bg

    local tex = wm:CreateControl("KApplicationHistoryIcon_Tex", win, CT_TEXTURE)
    tex:SetTexture(ICON_TEXTURE)
    tex:SetDimensions(ICON_SIZE - 6, ICON_SIZE - 6)
    tex:SetAnchor(CENTER, win, CENTER, 0, 0)
    win.tex = tex

    local downX, downY
    win:SetHandler("OnMouseEnter", function(ctrl)
        tex:SetTexture(ICON_TEXTURE_OVER)
        showIconTooltip(ctrl)
    end)
    win:SetHandler("OnMouseExit", function()
        tex:SetTexture(ICON_TEXTURE)
        ClearTooltip(InformationTooltip)
    end)
    win:SetHandler("OnMouseDown", function(ctrl)
        downX, downY = ctrl:GetLeft(), ctrl:GetTop()
        ClearTooltip(InformationTooltip)
    end)
    win:SetHandler("OnMoveStop", function(ctrl)
        local s = iconSV()
        s.x, s.y = ctrl:GetLeft(), ctrl:GetTop()
    end)
    win:SetHandler("OnMouseUp", function(ctrl, button, upInside)
        if not upInside then return end
        if button == MOUSE_BUTTON_INDEX_LEFT then
            local moved = downX and (math.abs(ctrl:GetLeft() - downX) > 2 or math.abs(ctrl:GetTop() - downY) > 2)
            if not moved then GFA:Toggle() end
        elseif button == MOUSE_BUTTON_INDEX_RIGHT then
            local s = iconSV()
            s.locked = not s.locked
            updateIconLockVisual()
            showIconTooltip(ctrl)
        end
    end)

    GFA.iconWin = win
    updateIconLockVisual()
end

local function updateIconVisibility()
    local win = GFA.iconWin
    if not win then return end
    local show = iconSV().enabled ~= false and ICON_SCENES[currentSceneName():lower()] == true
    if show and win:IsHidden() then
        win:SetHidden(false)
    elseif not show and not win:IsHidden() then
        win:SetHidden(true)
        ClearTooltip(InformationTooltip)
    end
end

local function setupMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panel = LAM:RegisterAddonPanel("KApplicationHistoryPanel", {
        type = "panel",
		name = "KApplicationHistory",
		displayName = "KApplicationHistory",
		author = "|cFF9B15@Konten|r",
		version = "1.0.1",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls("KApplicationHistoryPanel", {
        {
            type = "checkbox",
            name = "Show HUD icon",
            tooltip = "Show the small movable icon that opens the Application History window. Right-click the icon to lock/unlock its position.",
            getFunc = function() return iconSV().enabled ~= false end,
            setFunc = function(value)
                iconSV().enabled = value
                updateIconVisibility()
            end,
            default = true,
        },
    })
end

local lastSearch = 0
local function embeddedTick()
    if not GFA.SV then return end

    updateIconVisibility()

    if GFA.menuOpen and not menuIsOpen() then
        GFA.menuOpen = false
        setViewsMenuMode(false)
    end

    local inGroupScene = currentSceneName():lower():find("group", 1, true) ~= nil
    local header = GFA.header
    local show = false

    if inGroupScene then
        if not header then
            local now = GetFrameTimeMilliseconds()
            if now - lastSearch > 1000 then
                lastSearch = now
                header = findHeaderEverywhere()
                GFA.header = header
            end
        end
        if header then
            show = reallyVisible(header)
            if show and not GFA.embedded then
                GFA.embedded = createView({
                    name = "KApplicationHistoryEmbedded", standalone = false,
                    width = 580, rows = 3, rowHeight = 32, header = 32, footer = 18, bgAlpha = 0,
                })
            end
            if show then
                local cx, cy = header:GetCenter()
                if cx then
                    if GFA.leftLabel == nil then GFA.leftLabel = findLeftLabel(header) or false end
                    local left = cx + EMBED_OFFSET_X
                    if GFA.leftLabel then left = GFA.leftLabel:GetLeft() - 10 end
                    if left ~= GFA.lastLeft or cy ~= GFA.lastCY then
                        GFA.lastLeft, GFA.lastCY = left, cy
                        local win = GFA.embedded.window
                        win:ClearAnchors()
                        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, cy + EMBED_OFFSET_Y)
                    end
                end
            end
        end
    end

    if GFA.embedded then
        local win = GFA.embedded.window
        if show and win:IsHidden() then
            win:SetHidden(false)
            GFA:Refresh()
        elseif not show and not win:IsHidden() then
            win:SetHidden(true)
            ClearTooltip(InformationTooltip)
        end
    end
end

local function onApplicationReceived(_, applicantCharId)
    upsert(applicantCharId)
    GFA:Refresh()
end

local function onApplicationRemoved()
    sweep()
    zo_callLater(sweep, 1000)
end

local function onListingRemoved()
    for _, entry in pairs(GFA.pending) do
        finalize(entry, "removed")
    end
    GFA:Refresh()
end

local function onMemberJoined(_, characterName, displayName)
    local name = clean(displayName)
    if name == "" then return end
    for _, e in ipairs(history()) do
        if e.displayName == name then
            if e.status == "pending" or e.status == "accepted" or e.status == "removed" then
                e.status = "joined"
                GFA.pending[e.key] = nil
            end
            break
        end
    end
    GFA:Refresh()
end

local function onPlayerActivated()
    scanPending()
    GFA:Refresh()
end

local function hookResolve()
    if not ZO_PreHook or not _G.RequestResolveGroupListingApplication then return end
    ZO_PreHook("RequestResolveGroupListingApplication", function(requestType, applicantCharId)
        if applicantCharId then
            local key = Id64ToString(applicantCharId)
            if requestType == RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_APPROVE then
                GFA.hints[key] = "accepted"
            elseif requestType == RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_REJECT
                or requestType == RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_REJECTED_IGNORE then
                GFA.hints[key] = "declined"
            end
        end
        return false
    end)
end

local function onAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent("KApplicationHistory_Init", EVENT_ADD_ON_LOADED)

    GFA.SV = ZO_SavedVars:NewAccountWide("KApplicationHistory_SavedVars", 1, "Data", {
        history  = {},
        position = { x = 400, y = 200 },
        icon     = { x = 200, y = 200, locked = false, enabled = true },
    })
    createIcon()
    setupMenu()

    local now = GetTimeStamp()
    for _, e in ipairs(GFA.SV.history) do
        if e.status == "pending" then
            if (e.expiresAt or 0) + 5 < now then
                e.status = "expired"
            else
                GFA.pending[e.key] = e
            end
        end
    end

    hookResolve()
    EVENT_MANAGER:RegisterForUpdate("KApplicationHistory_Embedded", 250, embeddedTick)

    local em = EVENT_MANAGER
    em:RegisterForEvent("KApplicationHistory_Events", EVENT_GROUP_FINDER_APPLICATION_RECEIVED, onApplicationReceived)
    em:RegisterForEvent("KApplicationHistory_Events", EVENT_GROUP_FINDER_UPDATE_APPLICATIONS, sweep)
    em:RegisterForEvent("KApplicationHistory_Events", EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_APPLICATION, onApplicationRemoved)
    em:RegisterForEvent("KApplicationHistory_Events", EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_RESULT, onListingRemoved)
    em:RegisterForEvent("KApplicationHistory_Events", EVENT_GROUP_MEMBER_JOINED, onMemberJoined)
    em:RegisterForEvent("KApplicationHistory_Events", EVENT_PLAYER_ACTIVATED, onPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent("KApplicationHistory_Init", EVENT_ADD_ON_LOADED, onAddonLoaded)

SLASH_COMMANDS["/kah"] = function() GFA:Toggle() end
SLASH_COMMANDS["/applicationhistory"] = function() GFA:Toggle() end
