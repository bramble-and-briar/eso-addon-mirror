KApplicationHistory = KApplicationHistory or {}
KGT = KGT or {}

local KAH       = KApplicationHistory
local Templates = KGT
local History   = {}
local GF        = {}
local UI        = {}

KAH.History, KAH.Templates, KAH.GF = History, Templates, GF

local ADDON_NAME    = "KApplicationHistory"
local ADDON_VERSION = "2.0.2"
local ADDON_AUTHOR  = "|cFF9B15@Konten|r"
local SV_NAME       = "KApplicationHistory_SV"
local SV_VERSION    = 1

local NS_INIT      = ADDON_NAME .. "_Init"
local NS_HISTORY   = ADDON_NAME .. "_Events"
local NS_TEMPLATES = ADDON_NAME .. "_Templates"
local NS_UPDATE    = ADDON_NAME .. "_Update"

local UPDATE_MS          = 100
local HISTORY_TICK_MS    = 200
local SEARCH_INTERVAL_MS = 1000
local CLEAR_CONFIRM_MS   = 4000

local PANEL_WIDTH  = 580
local PANEL_HEADER = 32
local PANEL_FOOTER = 18
local TEAL = ZO_SECOND_CONTRAST_TEXT or ZO_ColorDef:New(0.46, 0.74, 0.77, 1)

local GROUP_SCENES = { "groupMenuKeyboard", "groupFinderKeyboard" }

local MAX_HISTORY = 100

local STATUS_TEXT = {
    pending  = "Pending",
    joined   = "Joined",
    accepted = "Accepted",
    declined = "Declined",
    expired  = "Expired",
    removed  = "Removed",
}

local ROLE_ICONS = {
    { role = LFG_ROLE_TANK, texture = "EsoUI/Art/LFG/LFG_tank_up.dds" },
    { role = LFG_ROLE_HEAL, texture = "EsoUI/Art/LFG/LFG_healer_up.dds" },
    { role = LFG_ROLE_DPS,  texture = "EsoUI/Art/LFG/LFG_dps_up.dds" },
}
local CP_ICON = "EsoUI/Art/Champion/Champion_Icon_32.dds"

local HISTORY_VIEW = {
    name      = ADDON_NAME .. "Embedded",
    width     = PANEL_WIDTH,
    rows      = 3,
    rowHeight = 32,
    header    = PANEL_HEADER,
    footer    = PANEL_FOOTER,
    bgAlpha   = 0,
}

local CLEAR_TEXT   = "[ Clear ]"
local SAVE_TEXT    = "[ Save ]"
local SAVED_TEXT   = "[ Saved ]"
local CLEAR_TOOLTIP = "Clear history\nClick, then click again to confirm"
local SAVE_TOOLTIP  = "Save listing as template\nAdds your current listing to Listing Templates"
local SAVED_FLASH_MS = 1500
local CONFIRM_TEXT = "[ CONFIRM ]"

local ROOT_CANDIDATES = { "ZO_GroupMenu_Keyboard", "ZO_GroupFinder_Keyboard", "ZO_GroupFinder_KeyboardTopLevel" }
local EMBED_OFFSET_X,      EMBED_OFFSET_Y      = -324, 300
local BLOCK_FROM_TITLE_X,  BLOCK_FROM_TITLE_Y  = 285, 484
local ICON_FROM_TITLE_X,   ICON_FROM_TITLE_Y   = 859, 0

local HIST_ICON_TEXTURE = "EsoUI/Art/Guild/tabIcon_history_up.dds"
local HIST_ICON_SIZE    = 44
local HIST_ICON_DX      = 249
local HIST_ICON_DY      = -191

local DRAFT   = GROUP_FINDER_GROUP_LISTING_USER_TYPE_GROUP_LISTING_DRAFT
local CREATED = GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING

local TEMPLATE_PANEL_WIDTH = 620
local TEMPLATE_ROW_H    = 36
local TEMPLATE_NUM_ROWS = 3

local TEMPLATE_DEFAULTS = {
    templates         = {},
    createImmediately = true,
    autoSave          = true,
    saveInviteCode    = false,
    maxTemplates      = 50,
    menuIconEnabled   = true,
    menuPanelOpen     = false,
    iconTexture       = "/esoui/art/lfg/lfg_indexicon_groupfinder_up.dds",
}

local ROLE_KEYS = {
    { key = "tank", role = LFG_ROLE_TANK },
    { key = "heal", role = LFG_ROLE_HEAL },
    { key = "dps",  role = LFG_ROLE_DPS  },
    { key = "any",  role = LFG_ROLE_INVALID },
}

local MENU_ICON_SIZE       = 40
local MENU_ICON_HOVER      = "/esoui/art/lfg/lfg_indexicon_groupfinder_down.dds"
local MENU_ICON_FROM_BTN_X = 30
local MENU_ICON_FROM_BTN_Y = 0
local PANEL_FROM_BUTTON_Y  = -24
local CREATE_PANELS = {
    "ZO_GroupFinder_Keyboard_TopLevelOverview",
    "ZO_GroupFinder_Keyboard_TopLevelSearchPanel",
}

local debugEnabled = false

local function debugLog(fmt, ...)
    if debugEnabled then d("[KAH] " .. string.format(fmt, ...)) end
end

local function clean(name)
    if not name or name == "" then return "" end
    return zo_strformat("<<1>>", name)
end

local function setColor(label, color)
    label:SetColor(color:UnpackRGBA())
end

local function round(n)
    return math.floor(n + 0.5)
end

local function centerY(control)
    return (control:GetTop() + control:GetBottom()) / 2
end

local function removeFromList(list, item)
    for i, v in ipairs(list) do
        if v == item then
            table.remove(list, i)
            return true
        end
    end
    return false
end

local TEXTURE_SUFFIXES = { "_up.dds", "_over.dds", "_down.dds" }

local function textureBase(path)
    path = path or ""
    for _, suffix in ipairs(TEXTURE_SUFFIXES) do
        if path:sub(-#suffix) == suffix then
            return path:sub(1, -#suffix - 1)
        end
    end
end

local function normalTexture(path)
    local base = textureBase(path)
    return base and (base .. "_up.dds") or path or ""
end

local function hoverTexture(path)
    local base = textureBase(path)
    return base and (base .. "_over.dds") or nil
end

local function reallyVisible(control)
    local guard = 0
    while control and guard < 30 do
        if control:IsHidden() or control:GetAlpha() < 0.05 then return false end
        control = control:GetParent()
        guard = guard + 1
    end
    return true
end

local function walkControls(root, limit, visit)
    local queue, head, count = { root }, 1, 0
    while queue[head] and count < limit do
        local control = queue[head]
        head = head + 1
        count = count + 1
        if visit(control) then return control end
        for i = 1, control:GetNumChildren() do
            queue[#queue + 1] = control:GetChild(i)
        end
    end
end

local function findLabels(root, limit, predicate, collect)
    return walkControls(root, limit, function(control)
        if control:GetType() ~= CT_LABEL then return false end
        if not predicate(control:GetText()) then return false end
        if not collect then return true end
        collect[#collect + 1] = control
        return false
    end)
end

local function hasListing()
    return HasGroupListingForUserType(CREATED)
end

local function importOldSavedVars(newSv, oldGlobal, namespace)
    if newSv.importedOld then return end
    newSv.importedOld = true

    local old  = _G[oldGlobal]
    local acct = old and old["Default"] and old["Default"][GetDisplayName()]
    local data = acct and acct["$AccountWide"]
    if data and namespace then data = data[namespace] end
    if type(data) ~= "table" then return end

    for k, v in pairs(data) do
        if k ~= "version" then
            newSv[k] = (type(v) == "table") and ZO_DeepTableCopy(v) or v
        end
    end
end

local function migrateTemplatesSavedVars(sv)
    if not sv.maxTemplatesV2 then
        sv.maxTemplatesV2 = true
        if sv.maxTemplates == 20 then sv.maxTemplates = 50 end
    end

    local outdated = {
        ["/esoui/art/lfg/lfg_indexicon_groupfinder_down.dds"]     = true,
        ["/esoui/art/lfg/lfg_groupfinder_refreshsearch_over.dds"] = true,
        ["/esoui/art/lfg/lfg_groupfinder_refreshsearch_up.dds"]   = true,
    }
    if outdated[sv.iconTexture] then sv.iconTexture = TEMPLATE_DEFAULTS.iconTexture end
end

History.pending = {}
History.hints   = {}
History.views   = {}

local function history()
    return History.sv and History.sv.history or {}
end

local function isInGroup(displayName)
    if not displayName or displayName == "" then return false end
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and GetUnitDisplayName(tag) == displayName then return true end
    end
    return false
end

local function levelText(entry)
    if entry.cp and entry.cp > 0 then return tostring(entry.cp), true end
    if entry.level and entry.level > 0 then return tostring(entry.level), false end
    return "", false
end

local function upsert(charId)
    if not charId then return nil end
    local displayName, characterName, classId, level, cp, role = GetGroupListingApplicationInfoByCharacterId(charId)
    if not displayName or displayName == "" then return nil end

    local key   = Id64ToString(charId)
    local entry = History.pending[key]
    local isNew = false

    if not entry then
        entry = { key = key, time = GetTimeStamp(), status = "pending" }
        local list = history()
        table.insert(list, 1, entry)
        while #list > MAX_HISTORY do table.remove(list) end
        History.pending[key] = entry
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
    local seen  = {}
    local id    = GetNextGroupListingApplicationCharacterId(nil)
    local guard = 0
    while id and guard < 200 do
        guard = guard + 1
        local entry = upsert(id)
        if entry then seen[entry.key] = true end
        id = GetNextGroupListingApplicationCharacterId(id)
    end
    return seen
end

local function finalize(entry, forcedStatus)
    local hint = History.hints[entry.key]
    History.hints[entry.key] = nil

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
    History.pending[entry.key] = nil
end

local function sweep()
    local seen = scanPending()
    if hasListing() then
        for key, entry in pairs(History.pending) do
            if not seen[key] then finalize(entry) end
        end
    end
    History.Refresh()
end

local function raiseTooltip()
    InformationTooltip:SetDrawLayer(DL_TEXT)
    InformationTooltip:SetDrawTier(DT_HIGH)
    InformationTooltip:SetDrawLevel(10000)
end

function UI.CreateLabel(parent, name, font, color)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font)
    setColor(label, color)
    return label
end

function UI.CreateLink(name, parent, text, onClick)
    local label = UI.CreateLabel(parent, name, "ZoFontGameSmall", ZO_NORMAL_TEXT)
    label:SetText(text)
    label:SetMouseEnabled(true)
    label:SetHandler("OnMouseEnter", function() setColor(label, ZO_SELECTED_TEXT) end)
    label:SetHandler("OnMouseExit",  function() setColor(label, ZO_NORMAL_TEXT) end)
    label:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then onClick() end
    end)
    return label
end

function UI.AddHighlight(row, name)
    local hl = WINDOW_MANAGER:CreateControl(name, row, CT_BACKDROP)
    hl:SetAnchorFill(row)
    hl:SetCenterColor(1, 1, 1, 0.08)
    hl:SetEdgeColor(0, 0, 0, 0)
    hl:SetHidden(true)
    return hl
end

function UI.CreatePanel(spec)
    local wm = WINDOW_MANAGER

    local win = wm:CreateTopLevelWindow(spec.name)
    win:SetDimensions(spec.width, spec.height)
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    if spec.clamped then win:SetClampedToScreen(true) end
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_MEDIUM)
    win:SetDrawLevel(0)

    local bg = wm:CreateControl(spec.bgName, win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0, 0, 0, spec.bgAlpha or 0)
    bg:SetEdgeColor(1, 1, 1, 0)

    local title = UI.CreateLabel(win, spec.titleName, "ZoFontHeader2", ZO_NORMAL_TEXT)
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 10, 4)

    local divider = wm:CreateControl(spec.dividerName, win, CT_TEXTURE)
    divider:SetTexture("EsoUI/Art/Miscellaneous/horizontalDivider.dds")
    divider:SetDimensions(spec.width, 4)
    divider:SetAnchor(TOPLEFT, win, TOPLEFT, 0, spec.header - 5)

    local footer = UI.CreateLabel(win, spec.footerName, "ZoFontGameSmall", ZO_DISABLED_TEXT)
    footer:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 10, 10)

    return win, bg, title, footer
end

function UI.CreateIconButton(spec)
    local wm = WINDOW_MANAGER

    local control
    if spec.parent then
        control = wm:CreateControl(spec.name, spec.parent, CT_CONTROL)
    else
        control = wm:CreateTopLevelWindow(spec.name)
    end
    control:SetMouseEnabled(true)

    local tex = wm:CreateControl(spec.name .. "_Tex", control, CT_TEXTURE)
    tex:SetAnchor(CENTER, control, CENTER, 0, 0)
    tex:SetTexture(spec.normalTexture())
    control.tex = tex

    if spec.size then
        control:SetDimensions(spec.size, spec.size)
        tex:SetDimensions(spec.size, spec.size)
    end

    control:SetHandler("OnMouseEnter", function(ctrl)
        local over = spec.hoverTexture and spec.hoverTexture()
        if over then tex:SetTexture(over) end
        spec.showTooltip(ctrl)
    end)
    control:SetHandler("OnMouseExit", function()
        tex:SetTexture(spec.normalTexture())
        ClearTooltip(InformationTooltip)
    end)
    if spec.clearOnMouseDown then
        control:SetHandler("OnMouseDown", function() ClearTooltip(InformationTooltip) end)
    end
    control:SetHandler("OnMouseUp", function(ctrl, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then spec.onClick(ctrl) end
    end)

    return control
end

local function menuIsOpen()
    if IsMenuVisible then return IsMenuVisible() end
    return ZO_Menu ~= nil and not ZO_Menu:IsHidden()
end

local function setViewsMenuMode(open)
    for _, view in ipairs(History.views) do
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
    History.menuOpen = true
    setViewsMenuMode(true)
end

local function showRowTooltip(row)
    local entry = row.entry
    if not entry then return end
    InitializeTooltip(InformationTooltip, row, BOTTOM, 0, -30)
    raiseTooltip()
    local text = (entry.note and entry.note ~= "") and entry.note or "(no message)"
    SetTooltipText(InformationTooltip, text)
end

local function showRowMenu(row)
    local entry = row.entry
    if not entry or not entry.displayName then return end
    ClearMenu()

    AddMenuItem("Whisper " .. entry.displayName, function()
        StartChatInput("/w " .. entry.displayName .. " ")
    end)

    if not IsUnitGrouped("player") or IsUnitGroupLeader("player") then
        AddMenuItem("Invite to group", function()
            GroupInviteByName(entry.displayName)
        end)
    end

    if entry.note and entry.note ~= "" then
        AddMenuItem("Copy message to chat box", function()
            StartChatInput(entry.displayName .. ": " .. entry.note)
        end)
    end

    AddMenuItem(" ", function() end)
    AddMenuItem("Remove from history", function()
        removeFromList(history(), entry)
        History.pending[entry.key] = nil
        History.Refresh()
    end)

    showMenuOnTop(row)
end

local function createRow(view, index, layout)
    local cfg  = view.cfg
    local win  = view.window
    local RH   = cfg.rowHeight
    local wm   = WINDOW_MANAGER

    local row = wm:CreateControl(cfg.name .. "_Row" .. index, win, CT_CONTROL)
    local name = row:GetName()
    row:SetDimensions(cfg.width - 20, RH)
    row:SetAnchor(TOPLEFT, win, TOPLEFT, 10, cfg.header + (index - 1) * RH)
    row:SetMouseEnabled(true)

    row.hl = UI.AddHighlight(row, name .. "_HL")

    row.line1 = UI.CreateLabel(row, name .. "_L1", "ZoFontGame", TEAL)
    row.line1:SetDimensions(layout.classX - 30, RH)
    row.line1:SetAnchor(LEFT, row, LEFT, 0, 0)
    row.line1:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.line1:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    row.classIcon = wm:CreateControl(name .. "_Class", row, CT_TEXTURE)
    row.classIcon:SetDimensions(26, 26)
    row.classIcon:SetAnchor(CENTER, row, LEFT, layout.classX, 0)

    row.cpIcon = wm:CreateControl(name .. "_CP", row, CT_TEXTURE)
    row.cpIcon:SetTexture(CP_ICON)
    row.cpIcon:SetDimensions(22, 22)
    row.cpIcon:SetAnchor(LEFT, row, LEFT, layout.lvlX - 32, 0)

    row.lvl = UI.CreateLabel(row, name .. "_Lvl", "ZoFontGame", TEAL)
    row.lvl:SetDimensions(48, RH)
    row.lvl:SetAnchor(LEFT, row, LEFT, layout.lvlX - 8, 0)
    row.lvl:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    row.roleIcons = {}
    for r, info in ipairs(ROLE_ICONS) do
        local icon = wm:CreateControl(name .. "_Role" .. r, row, CT_TEXTURE)
        icon:SetTexture(info.texture)
        icon:SetDimensions(24, 24)
        icon:SetAnchor(CENTER, row, LEFT, layout.roleX + (r - 2) * 28, 0)
        icon.role = info.role
        row.roleIcons[r] = icon
    end

    row.status = UI.CreateLabel(row, name .. "_ST", "ZoFontGame", ZO_NORMAL_TEXT)
    row.status:SetDimensions(100, RH)
    row.status:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    row.status:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    row.status:SetVerticalAlignment(TEXT_ALIGN_CENTER)

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
    row:SetHandler("OnMouseWheel", function(_, delta) History.ScrollView(view, delta) end)

    return row
end

local function showLabelTooltip(control, text)
    InitializeTooltip(InformationTooltip, control, BOTTOMRIGHT, 0, -10, TOPRIGHT)
    raiseTooltip()
    SetTooltipText(InformationTooltip, text)
end

local function createSaveLabel(view)
    local save
    save = UI.CreateLink(view.cfg.name .. "_Save", view.window, SAVE_TEXT, function()
        if not Templates.SaveCurrent() then return end
        save:SetText(SAVED_TEXT)
        zo_callLater(function() save:SetText(SAVE_TEXT) end, SAVED_FLASH_MS)
    end)
    save:SetAnchor(TOPRIGHT, view.window, TOPRIGHT, -8, 4)
    ZO_PostHookHandler(save, "OnMouseEnter", function(control) showLabelTooltip(control, SAVE_TOOLTIP) end)
    ZO_PostHookHandler(save, "OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    return save
end

local function createClearLabel(view)
    local win = view.window
    local clear = UI.CreateLabel(win, view.cfg.name .. "_Clear", "ZoFontGameSmall", ZO_NORMAL_TEXT)
    clear:SetText(CLEAR_TEXT)
    clear:SetDimensions(190, 20)
    clear:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    clear:SetAnchor(TOPRIGHT, view.saveLabel, TOPLEFT, -8, 0)
    clear:SetMouseEnabled(true)
    clear:SetHandler("OnMouseEnter", function(control)
        if not History.clearArmed then setColor(clear, ZO_SELECTED_TEXT) end
        showLabelTooltip(control, CLEAR_TOOLTIP)
    end)
    clear:SetHandler("OnMouseExit", function()
        if not History.clearArmed then setColor(clear, ZO_NORMAL_TEXT) end
        ClearTooltip(InformationTooltip)
    end)
    clear:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if History.clearArmed then
            History.ResetClearLabels()
            History.ClearHistory()
        else
            History.ArmClear()
        end
    end)
    return clear
end

local function createView(cfg)
    local W, RC, RH, HEAD = cfg.width, cfg.rows, cfg.rowHeight, cfg.header
    local view = { cfg = cfg, offset = 0, rows = {} }

    local win, _, title, footer = UI.CreatePanel({
        name        = cfg.name,
        bgName      = cfg.name .. "_BG",
        titleName   = cfg.name .. "_Title",
        dividerName = cfg.name .. "_Divider",
        footerName  = cfg.name .. "_Footer",
        width       = W,
        height      = HEAD + RC * RH + cfg.footer,
        header      = HEAD,
        bgAlpha     = cfg.bgAlpha,
    })
    view.window, view.title, view.footer = win, title, footer
    win:SetHandler("OnMouseWheel", function(_, delta) History.ScrollView(view, delta) end)

    local layout = {}
    layout.roleX  = (W - 20) - 135
    layout.lvlX   = layout.roleX - 85
    layout.classX = layout.lvlX - 70

    local function columnHeader(text, x)
        local label = UI.CreateLabel(win, cfg.name .. "_Col" .. text, "ZoFontHeader2", ZO_NORMAL_TEXT)
        label:SetText(text)
        label:SetDimensions(80, 24)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(TOP, win, TOPLEFT, 10 + x, 4)
    end
    columnHeader("CLASS", layout.classX)
    columnHeader("LVL",   layout.lvlX)
    columnHeader("ROLE",  layout.roleX)

    view.saveLabel = createSaveLabel(view)
    view.clearLabel = createClearLabel(view)

    for i = 1, RC do
        view.rows[i] = createRow(view, i, layout)
    end

    table.insert(History.views, view)
    return view
end

local function updateRow(row, entry)
    row.entry = entry
    if not entry then
        row:SetHidden(true)
        return
    end

    row:SetHidden(false)
    row.line1:SetText(string.format("%s  (%s)", entry.displayName or "?", entry.characterName or "?"))
    row.status:SetText(STATUS_TEXT[entry.status] or tostring(entry.status))
    setColor(row.status, entry.status == "pending" and ZO_SELECTED_TEXT or ZO_NORMAL_TEXT)

    local classTexture = entry.classId and entry.classId > 0 and GetClassIcon and GetClassIcon(entry.classId) or nil
    if classTexture and classTexture ~= "" then
        row.classIcon:SetTexture(classTexture)
        row.classIcon:SetHidden(false)
    else
        row.classIcon:SetHidden(true)
    end

    local text, isCP = levelText(entry)
    row.lvl:SetText(text)
    row.cpIcon:SetHidden(not isCP)

    for _, icon in ipairs(row.roleIcons) do
        local active = icon.role == entry.role
        icon:SetAlpha(active and 1 or 0.3)
        icon:SetDesaturation(active and 0 or 1)
    end
end

local function refreshView(view)
    local cfg   = view.cfg
    local list  = history()
    local total = #list
    view.offset = zo_clamp(view.offset, 0, math.max(0, total - cfg.rows))

    view.title:SetText(string.format("APPLICATION HISTORY (%d)", total))

    for i, row in ipairs(view.rows) do
        updateRow(row, list[view.offset + i])
    end

    if total == 0 then
        view.footer:SetText("No applications recorded yet.")
    else
        view.footer:SetText(string.format("::[KApplicationHistory]:: %d-%d of %d   -   right-click a row for options, mouse wheel to scroll",
            view.offset + 1, math.min(view.offset + cfg.rows, total), total))
    end
end

function History.Refresh()
    for _, view in ipairs(History.views) do refreshView(view) end
end

function History.ScrollView(view, delta)
    view.offset = view.offset - delta
    refreshView(view)
end

function History.ResetClearLabels()
    History.clearArmed = false
    History.clearToken = (History.clearToken or 0) + 1
    for _, view in ipairs(History.views) do
        if view.clearLabel then
            view.clearLabel:SetText(CLEAR_TEXT)
            setColor(view.clearLabel, ZO_NORMAL_TEXT)
        end
    end
end

function History.ArmClear()
    History.clearArmed = true
    History.clearToken = (History.clearToken or 0) + 1
    local token = History.clearToken
    for _, view in ipairs(History.views) do
        if view.clearLabel then
            view.clearLabel:SetText(CONFIRM_TEXT)
            setColor(view.clearLabel, ZO_SELECTED_TEXT)
        end
    end
    zo_callLater(function()
        if History.clearToken == token then History.ResetClearLabels() end
    end, CLEAR_CONFIRM_MS)
end

function History.ClearHistory()
    ZO_ClearNumericallyIndexedTable(history())
    ZO_ClearTable(History.pending)
    ZO_ClearTable(History.hints)
    for _, view in ipairs(History.views) do view.offset = 0 end
    History.Refresh()
end

local function findRoot()
    for _, name in ipairs(ROOT_CANDIDATES) do
        local c = _G[name]
        if c and c.IsControlHidden then return c end
    end
    return GuiRoot
end

local function isHeaderText(text)
    if not text then return false end
    text = text:lower()
    return text:find("pending", 1, true) and (text:find("group", 1, true) or text:find("request", 1, true)) and true or false
end

local function isTitleText(text)
    if not text then return false end
    text = text:lower()
    return #text < 40 and text:find("activity", 1, true) and text:find("finder", 1, true) and true or false
end

local function pickRightmostVisible(list)
    local best, bestX
    for _, c in ipairs(list) do
        if reallyVisible(c) then
            local cx = c:GetCenter()
            if cx and (not bestX or cx > bestX) then best, bestX = c, cx end
        end
    end
    return best
end

local function pickFirstVisible(list)
    for _, c in ipairs(list) do
        if reallyVisible(c) then return c end
    end
end

local function searchLabels(predicate, pick)
    local root  = findRoot()
    local found = {}
    findLabels(root, 6000, predicate, found)
    local best = pick(found)
    if not best and root ~= GuiRoot then
        found = {}
        findLabels(GuiRoot, 60000, predicate, found)
        best = pick(found)
    end
    return best
end

local function findLeftLabel(header)
    local top = header
    for _ = 1, 3 do
        if top:GetParent() then top = top:GetParent() end
    end
    return walkControls(top, 3000, function(c)
        if c:GetType() ~= CT_LABEL then return false end
        local text = c:GetText()
        return text ~= nil and text:lower():find("character name", 1, true) ~= nil
    end)
end

local lastSearch = 0

function GF.Locate()
    if GF.header and GF.title then return GF.header, GF.title end

    local now = GetFrameTimeMilliseconds()
    if now - lastSearch > SEARCH_INTERVAL_MS then
        lastSearch = now
        if not GF.header and hasListing() then
            GF.header = searchLabels(isHeaderText, pickRightmostVisible)
        end
        if not GF.title then
            GF.title = searchLabels(isTitleText, pickFirstVisible)
        end
    end
    return GF.header, GF.title
end

local function currentSceneName()
    local sm = SCENE_MANAGER
    local scene = sm and sm.GetCurrentScene and sm:GetCurrentScene()
    if scene and scene.GetName then return scene:GetName() or "" end
    return ""
end

local function iconConfig()
    local sv = History.sv
    sv.histIcon = sv.histIcon or { texture = HIST_ICON_TEXTURE, size = HIST_ICON_SIZE, dx = HIST_ICON_DX, dy = HIST_ICON_DY }
    return sv.histIcon
end

function History.UpdateIconLook()
    local icon = History.icon
    if not icon then return end
    local cfg    = iconConfig()
    local hidden = History.sv.embeddedHidden
    icon:SetDimensions(cfg.size, cfg.size)
    icon.tex:SetDimensions(cfg.size, cfg.size)
    icon.tex:SetTexture(normalTexture(cfg.texture))
    icon.tex:SetAlpha(hidden and 0.45 or 1)
    icon.tex:SetDesaturation(hidden and 1 or 0)
end

local function showIconTooltip(control)
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -10)
    SetTooltipText(InformationTooltip, string.format("Application History\nLeft-click: %s",
        History.sv.embeddedHidden and "show" or "hide"))
end

function History.GetIconRoot()
    if History.iconRoot ~= nil then return History.iconRoot or nil end

    local scenes = {}
    for _, name in ipairs(GROUP_SCENES) do
        local scene = SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(name)
        if scene then scenes[#scenes + 1] = scene end
    end
    if #scenes == 0 or not ZO_FadeSceneFragment then
        History.iconRoot = false
        return nil
    end

    local root = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "IconRoot")
    root:SetAnchorFill(GuiRoot)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetDrawTier(DT_MEDIUM)
    root:SetDrawLevel(5)

    local fragment = ZO_FadeSceneFragment:New(root)
    for _, scene in ipairs(scenes) do scene:AddFragment(fragment) end

    History.iconRoot, History.iconFragment = root, fragment
    return root
end

function History.EnsureIcon(target, point, dx, dy)
    local icon = History.icon

    if not icon then
        icon = UI.CreateIconButton({
            name          = ADDON_NAME .. "ToggleIcon",
            parent        = History.GetIconRoot(),
            normalTexture = function() return normalTexture(iconConfig().texture) end,
            hoverTexture  = function() return hoverTexture(iconConfig().texture) end,
            showTooltip   = showIconTooltip,
            onClick       = function(ctrl)
                History.ToggleEmbedded()
                showIconTooltip(ctrl)
            end,
        })
        icon:SetHidden(true)
        icon:SetDrawLayer(DL_OVERLAY)
        icon:SetDrawTier(DT_MEDIUM)
        icon:SetDrawLevel(5)

        History.icon = icon
        History.iconAnchorKey = nil
        History.UpdateIconLook()
    end

    local key = string.format("%s|%s|%d|%d", tostring(target), tostring(point), dx, dy)
    if History.iconAnchorKey ~= key then
        icon:ClearAnchors()
        icon:SetAnchor(CENTER, target, point, dx, dy)
        History.iconAnchorKey = key
    end
end

function History.AttachIcon(header)
    local icon = History.icon
    if not icon or not header or History.iconPanelFor == header then return end

    local c = header
    for _ = 1, 30 do
        local parent = c:GetParent()
        if not parent then return end
        if (parent:GetName() or "") == "ZO_GroupFinder_Keyboard_TopLevel" then
            icon:SetParent(c)
            icon:SetDrawLevel(100)
            History.iconPanelFor = header
            History.iconAnchorKey = nil
            return
        end
        c = parent
    end
end

function History.SetIconShown(show)
    local icon = History.icon
    if not icon then return end
    if show and icon:IsHidden() then
        icon:SetHidden(false)
    elseif not show and not icon:IsHidden() then
        icon:SetHidden(true)
        ClearTooltip(InformationTooltip)
    end
end

function History.ApplyEmbeddedVisibility(show)
    local view = History.embedded
    if not view then return end
    local win = view.window

    if show then
        if win:IsHidden() or win:GetAlpha() < 1 then
            win:SetAlpha(1)
            win:SetMouseEnabled(true)
            win:SetHidden(false)
            for _, row in ipairs(view.rows) do row:SetMouseEnabled(true) end
            History.ResetClearLabels()
            History.Refresh()
        end
    elseif not win:IsHidden() or win:GetAlpha() > 0 then
        ClearTooltip(InformationTooltip)
        if History.menuOpen then
            ClearMenu()
            History.menuOpen = false
            setViewsMenuMode(false)
        end
        History.ResetClearLabels()
        win:SetMouseEnabled(false)
        win:SetAlpha(0)
        win:SetHidden(true)
        for _, row in ipairs(view.rows) do
            row:SetMouseEnabled(false)
            row:SetHidden(true)
        end
    end
end

local function anchorEmbedded(left, top, iconX, iconY)
    if not History.embedded then
        History.embedded = createView(HISTORY_VIEW)
    end

    local target, point, ax, ay = GuiRoot, TOPLEFT, left, top
    if History.icon and iconX then
        target, point, ax, ay = History.icon, CENTER, round(left - iconX), round(top - iconY)
    end

    if target ~= History.lastTarget or ax ~= History.lastX or ay ~= History.lastY then
        History.lastTarget, History.lastX, History.lastY = target, ax, ay
        local win = History.embedded.window
        win:ClearAnchors()
        win:SetAnchor(TOPLEFT, target, point, ax, ay)
    end
end

function History.Tick()
    local sv = History.sv
    if not sv then return end

    if History.menuOpen and not menuIsOpen() then
        History.menuOpen = false
        setViewsMenuMode(false)
    end

    local headerShown, show = false, false

    if currentSceneName():lower():find("group", 1, true) then
        local header, title = GF.Locate()
        headerShown = header ~= nil and reallyVisible(header)
        local titleShown = title ~= nil and reallyVisible(title)
        show = headerShown

        local cfg = iconConfig()
        local left, top, iconX, iconY

        if headerShown then
            local cx, cy = header:GetCenter()
            if cx then
                if GF.leftLabel == nil then GF.leftLabel = findLeftLabel(header) or false end
                left = cx + EMBED_OFFSET_X
                if GF.leftLabel then left = GF.leftLabel:GetLeft() - 10 end
                top = cy + EMBED_OFFSET_Y
                iconX, iconY = cx + cfg.dx, cy + cfg.dy

                if titleShown then
                    local tl, tcy = title:GetLeft(), centerY(title)
                    local tx, ty = round(cx + cfg.dx - tl), round(cy + cfg.dy - tcy)
                    local bx, by = round(left - tl), round(top - tcy)
                    if cfg.tx ~= tx or cfg.ty ~= ty or cfg.bx ~= bx or cfg.by ~= by then
                        cfg.tx, cfg.ty, cfg.bx, cfg.by = tx, ty, bx, by
                    end
                end
            end
        elseif titleShown then
            left = title:GetLeft() + (cfg.bx or BLOCK_FROM_TITLE_X)
            top  = centerY(title) + (cfg.by or BLOCK_FROM_TITLE_Y)
        end

        if headerShown then History.AttachIcon(header) end
        if titleShown then
            local tx, ty = cfg.tx or ICON_FROM_TITLE_X, cfg.ty or ICON_FROM_TITLE_Y
            History.EnsureIcon(title, LEFT, tx, ty)
            iconX, iconY = title:GetLeft() + tx, centerY(title) + ty
        elseif headerShown then
            History.EnsureIcon(header, CENTER, cfg.dx, cfg.dy)
        end

        if left then anchorEmbedded(left, top, iconX, iconY) end
    end

    History.SetIconShown(headerShown)

    if show and (not History.icon or History.icon:IsControlHidden()) then show = false end
    if sv.embeddedHidden then show = false end

    if History.embedded then History.ApplyEmbeddedVisibility(show) end
end

function History.SetEmbeddedHidden(hidden)
    History.sv.embeddedHidden = hidden and true or false

    if not History.sv.embeddedHidden then Templates.CloseMenuPanel() end

    History.UpdateIconLook()
    ClearTooltip(InformationTooltip)
    History.Tick()
end

function History.ToggleEmbedded()
    History.SetEmbeddedHidden(not History.sv.embeddedHidden)
end

local function onApplicationReceived(_, applicantCharId)
    upsert(applicantCharId)
    History.Refresh()
end

local function onApplicationRemoved()
    sweep()
    zo_callLater(sweep, 1000)
end

local function onListingRemoved()
    for _, entry in pairs(History.pending) do
        finalize(entry, "removed")
    end
    History.Refresh()
end

local function onMemberJoined(_, _, displayName)
    local name = clean(displayName)
    if name == "" then return end

    for _, entry in ipairs(history()) do
        if entry.displayName == name then
            if entry.status == "pending" or entry.status == "accepted" or entry.status == "removed" then
                entry.status = "joined"
                History.pending[entry.key] = nil
            end
            break
        end
    end
    History.Refresh()
end

local function onPlayerActivated()
    scanPending()
    History.Refresh()
end

local function hookResolveApplication()
    if not ZO_PreHook or not _G.RequestResolveGroupListingApplication then return end

    ZO_PreHook("RequestResolveGroupListingApplication", function(requestType, applicantCharId)
        if applicantCharId then
            local key = Id64ToString(applicantCharId)
            if requestType == RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_APPROVE then
                History.hints[key] = "accepted"
            elseif requestType == RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_REJECT
                or requestType == RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_REJECTED_IGNORE then
                History.hints[key] = "declined"
            end
        end
        return false
    end)
end

local function restoreOpenApplications()
    local now = GetTimeStamp()
    for _, entry in ipairs(history()) do
        if entry.status == "pending" then
            if (entry.expiresAt or 0) + 5 < now then
                entry.status = "expired"
            else
                History.pending[entry.key] = entry
            end
        end
    end
end

local function registerHistoryEvents()
    local em = EVENT_MANAGER
    em:RegisterForEvent(NS_HISTORY, EVENT_GROUP_FINDER_APPLICATION_RECEIVED,       onApplicationReceived)
    em:RegisterForEvent(NS_HISTORY, EVENT_GROUP_FINDER_UPDATE_APPLICATIONS,        sweep)
    em:RegisterForEvent(NS_HISTORY, EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_APPLICATION, onApplicationRemoved)
    em:RegisterForEvent(NS_HISTORY, EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_RESULT, onListingRemoved)
    em:RegisterForEvent(NS_HISTORY, EVENT_GROUP_MEMBER_JOINED,                     onMemberJoined)
    em:RegisterForEvent(NS_HISTORY, EVENT_PLAYER_ACTIVATED,                        onPlayerActivated)
end

local ui = { menuIcons = {} }

local pendingSnapshot
local replaying = false
local sorted = {}
local scrollOffset = 0

local function joinNames(list)
    local out = {}
    for _, option in ipairs(list or {}) do out[#out + 1] = option.name end
    return table.concat(out, ",")
end

local OPTION_API = {
    primary = {
        count = GetGroupFinderUserTypeGroupListingNumPrimaryOptions,
        get   = GetGroupFinderUserTypeGroupListingPrimaryOptionByIndex,
        set   = SetGroupFinderUserTypeGroupListingPrimaryOption,
    },
    secondary = {
        count = GetGroupFinderUserTypeGroupListingNumSecondaryOptions,
        get   = GetGroupFinderUserTypeGroupListingSecondaryOptionByIndex,
        set   = SetGroupFinderUserTypeGroupListingSecondaryOption,
    },
}

local function readOptions(kind, userType)
    local api = OPTION_API[kind]
    local selected = {}
    for i = 1, api.count(userType) do
        local name, isSet = api.get(userType, i)
        if isSet then selected[#selected + 1] = { index = i, name = name } end
    end
    return selected
end

local function snapshotListing(userType)
    userType = userType or DRAFT
    local t = {}

    t.category  = GetGroupFinderUserTypeGroupListingCategory(userType)
    t.primary   = readOptions("primary", userType)
    t.secondary = readOptions("secondary", userType)
    t.optionText1, t.optionText2 = GetGroupFinderUserTypeGroupListingOptionsSelectionText(userType)

    t.title        = GetGroupFinderUserTypeGroupListingTitle(userType)
    t.description  = GetGroupFinderUserTypeGroupListingDescription(userType)
    t.size         = GetGroupFinderUserTypeGroupListingGroupSize(userType)
    t.playstyle    = GetGroupFinderUserTypeGroupListingPlaystyle(userType)
    t.requiresCP   = DoesGroupFinderUserTypeGroupListingRequireChampion(userType)
    t.cp           = GetGroupFinderCreateGroupListingChampionPoints(userType)
    t.voip         = DoesGroupFinderUserTypeGroupListingRequireVOIP(userType)
    t.requiresCode = DoesGroupFinderUserTypeGroupListingRequireInviteCode(userType)
    if Templates.sv.saveInviteCode and t.requiresCode then
        t.inviteCode = GetGroupFinderUserTypeGroupListingInviteCode(userType)
    end
    t.autoAccept   = DoesGroupFinderUserTypeGroupListingAutoAcceptRequests(userType)
    t.enforceRoles = DoesGroupFinderUserTypeGroupListingEnforceRoles(userType)

    t.roles = {}
    for _, r in ipairs(ROLE_KEYS) do
        local ok, count = pcall(GetGroupFinderUserTypeGroupListingDesiredRoleCount, userType, r.role)
        t.roles[r.key] = (ok and count) or 0
    end
    return t
end

local function templateKey(t)
    return table.concat({
        tostring(t.title or ""),
        tostring(t.category),
        joinNames(t.primary),
        joinNames(t.secondary),
    }, "|")
end

local function pruneTemplates()
    local list, max = Templates.sv.templates, Templates.sv.maxTemplates
    while #list > max do
        local worstIndex, worstTime
        for i, template in ipairs(list) do
            if not template.pinned and (not worstTime or (template.lastUsed or 0) < worstTime) then
                worstIndex, worstTime = i, template.lastUsed or 0
            end
        end
        if not worstIndex then break end
        table.remove(list, worstIndex)
    end
end

local function commitTemplate(t)
    if not t or not t.category then return end
    t.key = templateKey(t)
    t.lastUsed = GetTimeStamp()

    local list = Templates.sv.templates
    for i, existing in ipairs(list) do
        if existing.key == t.key then
            t.pinned = existing.pinned
            t.uses   = (existing.uses or 1) + 1
            list[i]  = t
            return t, false
        end
    end

    t.uses = 1
    list[#list + 1] = t
    pruneTemplates()
    return t, true
end

local function optionText(t)
    local a, b = clean(t.optionText1), clean(t.optionText2)
    if a == "" then
        a = joinNames(t.primary)
        b = joinNames(t.secondary)
    end
    if b ~= "" then return a .. " - " .. b end
    return a
end

local function roleSummary(t)
    local r = t.roles or {}
    local text = string.format("%dT %dH %dD", r.tank or 0, r.heal or 0, r.dps or 0)
    if (r.any or 0) > 0 then text = text .. string.format(" %dA", r.any) end
    local total = (r.tank or 0) + (r.heal or 0) + (r.dps or 0) + (r.any or 0)
    return total, text
end

local function yesNo(value)
    return value and "Yes" or "No"
end

local function templateTooltipText(t)
    local total, breakdown = roleSummary(t)
    local lines = {}
    lines[#lines + 1] = (t.title and t.title ~= "") and t.title or "(no title)"
    lines[#lines + 1] = optionText(t)
    lines[#lines + 1] = string.format("%d players (%s)", total, breakdown)
    if t.description and t.description ~= "" then
        lines[#lines + 1] = ""
        lines[#lines + 1] = t.description
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Champion Points Required: " .. yesNo(t.requiresCP) .. ((t.requiresCP and t.cp and t.cp > 0) and (" (" .. t.cp .. ")") or "")
    lines[#lines + 1] = "Voice Chat Required: " .. yesNo(t.voip)
    lines[#lines + 1] = "Invite Code: " .. yesNo(t.requiresCode)
    lines[#lines + 1] = "Auto Accept: " .. yesNo(t.autoAccept)
    lines[#lines + 1] = "Enforce Roles: " .. yesNo(t.enforceRoles)
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Created %d time(s)", t.uses or 1)
    lines[#lines + 1] = "|c999999Left click: create\nRight click: pin/unpin|r"
    return table.concat(lines, "\n")
end

local function selectOptions(kind, saved)
    if not saved then return true end
    local api = OPTION_API[kind]

    if #saved == 0 then
        if kind == "secondary" then SetGroupFinderUserTypeGroupListingSecondaryOptionDefault(DRAFT) end
        return true
    end

    local num   = api.count(DRAFT)
    local allOk = true
    for _, option in ipairs(saved) do
        local found
        for i = 1, num do
            if api.get(DRAFT, i) == option.name then found = i break end
        end
        if found then
            api.set(DRAFT, found)
        else
            allOk = false
        end
    end
    return allOk
end

local function applyTemplate(t)
    if hasListing() then return false end

    SetGroupFinderUserTypeGroupListingCategory(DRAFT, t.category)
    UpdateGroupFinderUserTypeGroupListingOptions(DRAFT)

    local primaryOk   = selectOptions("primary", t.primary)
    local secondaryOk = selectOptions("secondary", t.secondary)

    SetGroupFinderUserTypeGroupListingTitle(DRAFT, t.title or "")
    SetGroupFinderUserTypeGroupListingDescription(DRAFT, t.description or "")
    if t.size ~= nil then SetGroupFinderUserTypeGroupListingGroupSize(DRAFT, t.size) end
    if t.playstyle ~= nil then SetGroupFinderUserTypeGroupListingPlaystyle(DRAFT, t.playstyle) end

    SetGroupFinderUserTypeGroupListingRequiresChampion(DRAFT, t.requiresCP and true or false)
    if t.requiresCP and t.cp then SetGroupFinderUserTypeGroupListingChampionPoints(DRAFT, t.cp) end
    SetGroupFinderUserTypeGroupListingRequiresVOIP(DRAFT, t.voip and true or false)
    SetGroupFinderUserTypeGroupListingRequiresInviteCode(DRAFT, t.requiresCode and true or false)
    if t.requiresCode and t.inviteCode then SetGroupFinderUserTypeGroupListingInviteCode(DRAFT, t.inviteCode) end
    SetGroupFinderUserTypeGroupListingAutoAcceptRequests(DRAFT, t.autoAccept and true or false)
    SetGroupFinderUserTypeGroupListingEnforceRoles(DRAFT, t.enforceRoles and true or false)

    GroupFinderUserTypeGroupListingClearDesiredRoles(DRAFT)
    for _, r in ipairs(ROLE_KEYS) do
        local count = t.roles and t.roles[r.key] or 0
        if r.key ~= "any" or count > 0 then
            local ok = pcall(SetGroupFinderUserTypeGroupListingRoleCount, DRAFT, r.role, count)
            if not ok then debugLog("could not set %s role count", r.key) end
        end
    end

    if Templates.sv.createImmediately and (not primaryOk or not secondaryOk) then
        return false
    end
    return true
end

function Templates.Recreate(t)
    if not t then return end
    if not applyTemplate(t) then return end
    if not Templates.sv.createImmediately then return end

    replaying = true
    RequestCreateGroupListing()
end

function Templates.RecreateLast()
    local best
    for _, template in ipairs(Templates.sv.templates) do
        if not best or (template.lastUsed or 0) > (best.lastUsed or 0) then best = template end
    end
    if best then Templates.Recreate(best) end
end

function Templates.SaveCurrent()
    local userType = hasListing() and CREATED or DRAFT
    local ok, t = pcall(snapshotListing, userType)
    if not ok or not t or not t.category then return false end
    commitTemplate(t)
    Templates.Refresh()
    return true
end

local function onCreateResult(_, result)
    local wasReplay = replaying
    replaying = false

    if result == GROUP_FINDER_ACTION_RESULT_SUCCESS then
        if pendingSnapshot and Templates.sv.autoSave then
            local snap = pendingSnapshot

            if hasListing() then
                local ok, real = pcall(snapshotListing, CREATED)
                if ok and real and real.category then
                    if not real.inviteCode then real.inviteCode = pendingSnapshot.inviteCode end
                    snap = real
                end
            end

            commitTemplate(snap)
            Templates.Refresh()
        end

        if wasReplay then Templates.CloseGroupFinder() end
    end
    pendingSnapshot = nil
end

local function showTemplateTooltip(row)
    if not row.data then return end
    InitializeTooltip(InformationTooltip, row, RIGHT, -10, 0, LEFT)
    raiseTooltip()
    SetTooltipText(InformationTooltip, templateTooltipText(row.data))
end

local function sortTemplates()
    sorted = {}
    for _, template in ipairs(Templates.sv.templates) do sorted[#sorted + 1] = template end

    table.sort(sorted, function(a, b)
        local aPinned, bPinned = a.pinned and true or false, b.pinned and true or false
        if aPinned ~= bPinned then return aPinned end
        if (a.lastUsed or 0) ~= (b.lastUsed or 0) then return (a.lastUsed or 0) > (b.lastUsed or 0) end
        return (a.key or "") < (b.key or "")
    end)
end

function Templates.RefreshImmediateLabel()
    if not ui.immediate then return end
    ui.immediate:SetText(string.format("[ Create immediately: %s ]", Templates.sv.createImmediately and "ON" or "OFF"))
end

function Templates.Refresh()
    if not ui.win then return end
    sortTemplates()

    local total = #sorted
    scrollOffset = zo_clamp(scrollOffset, 0, math.max(0, total - TEMPLATE_NUM_ROWS))

    ui.title:SetText(string.format("LISTING TEMPLATES (%d)", total))

    for i = 1, TEMPLATE_NUM_ROWS do
        local row = ui.rows[i]
        local t = sorted[scrollOffset + i]
        row.data = t
        if t then
            local title = (t.title and t.title ~= "") and t.title or "(no title)"
            local _, breakdown = roleSummary(t)
            row.title:SetText((t.pinned and "|cffd700*|r " or "") .. title)
            row.sub:SetText(optionText(t) .. "   |c999999(" .. breakdown .. ")|r")
            row:SetHidden(false)
        else
            row:SetHidden(true)
        end
    end

    ui.empty:SetHidden(total ~= 0)
    if total == 0 then
        ui.footer:SetText("Create a listing once and it is saved automatically")
    else
        ui.footer:SetText(string.format("%d-%d of %d   -   click: recreate, right-click: pin, wheel: scroll",
            scrollOffset + 1, math.min(scrollOffset + TEMPLATE_NUM_ROWS, total), total))
    end
    Templates.RefreshImmediateLabel()
end

local function onTemplateScroll(_, delta)
    scrollOffset = scrollOffset - delta
    Templates.Refresh()
end

local function createTemplateRow(parent, index)
    local wm = WINDOW_MANAGER
    local row = wm:CreateControl("KGT_Row" .. index, parent, CT_CONTROL)
    row:SetDimensions(TEMPLATE_PANEL_WIDTH - 20, TEMPLATE_ROW_H)
    row:SetMouseEnabled(true)

    row.hl = UI.AddHighlight(row, nil)

    row.title = UI.CreateLabel(row, nil, "ZoFontGame", TEAL)
    row.title:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 3)
    row.title:SetAnchor(TOPRIGHT, row, TOPRIGHT, -34, 3)
    row.title:SetMaxLineCount(1)
    row.title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    row.sub = UI.CreateLabel(row, nil, "ZoFontGameSmall", ZO_NORMAL_TEXT)
    row.sub:SetAnchor(TOPLEFT, row.title, BOTTOMLEFT, 0, 1)
    row.sub:SetAnchor(TOPRIGHT, row, TOPRIGHT, -34, 21)
    row.sub:SetMaxLineCount(1)
    row.sub:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    row.del = wm:CreateControl(nil, row, CT_BUTTON)
    row.del:SetDimensions(22, 22)
    row.del:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    row.del:SetNormalTexture("EsoUI/Art/Buttons/decline_up.dds")
    row.del:SetMouseOverTexture("EsoUI/Art/Buttons/decline_over.dds")
    row.del:SetPressedTexture("EsoUI/Art/Buttons/decline_down.dds")
    row.del:SetMouseEnabled(true)
    row.del:SetHandler("OnClicked", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and row.data then
            removeFromList(Templates.sv.templates, row.data)
            ClearTooltip(InformationTooltip)
            Templates.Refresh()
        end
    end)
    row.del:SetHandler("OnMouseEnter", function()
        row.hl:SetHidden(false)
        InitializeTooltip(InformationTooltip, row.del, TOP, 0, -4)
        SetTooltipText(InformationTooltip, "Delete template")
    end)
    row.del:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    row.del:SetHandler("OnMouseWheel", onTemplateScroll)

    row:SetHandler("OnMouseEnter", function()
        row.hl:SetHidden(false)
        showTemplateTooltip(row)
    end)
    row:SetHandler("OnMouseExit", function()
        row.hl:SetHidden(true)
        ClearTooltip(InformationTooltip)
    end)
    row:SetHandler("OnMouseWheel", onTemplateScroll)
    row:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or not row.data then return end
        if button == MOUSE_BUTTON_INDEX_LEFT then
            Templates.Recreate(row.data)
        elseif button == MOUSE_BUTTON_INDEX_RIGHT then
            row.data.pinned = (not row.data.pinned) or nil
            Templates.Refresh()
            showTemplateTooltip(row)
        end
    end)

    return row
end

local function buildTemplatesPanel()
    local win, bg, title, footer = UI.CreatePanel({
        name        = "KGT_Window",
        bgName      = "KGT_WindowBG",
        titleName   = "KGT_Title",
        dividerName = "KGT_Divider",
        footerName  = "KGT_Footer",
        width       = TEMPLATE_PANEL_WIDTH,
        height      = PANEL_HEADER + TEMPLATE_ROW_H * TEMPLATE_NUM_ROWS + PANEL_FOOTER,
        header      = PANEL_HEADER,
        bgAlpha     = 0,
        clamped     = true,
    })
    bg:SetEdgeTexture("", 1, 1, 1)
    ui.win, ui.bg, ui.title, ui.footer = win, bg, title, footer

    ui.recreateBtn = UI.CreateLink("KGT_RecreateBtn", win, "[ Recreate last ]", function() Templates.RecreateLast() end)
    ui.recreateBtn:SetAnchor(TOPRIGHT, win, TOPRIGHT, -8, 4)

    ui.rows = {}
    for i = 1, TEMPLATE_NUM_ROWS do
        local row = createTemplateRow(win, i)
        row:SetAnchor(TOPLEFT, win, TOPLEFT, 10, PANEL_HEADER + (i - 1) * TEMPLATE_ROW_H)
        ui.rows[i] = row
    end

    ui.empty = UI.CreateLabel(win, "KGT_Empty", "ZoFontGame", ZO_DISABLED_TEXT)
    ui.empty:SetText("No templates yet.")
    ui.empty:SetAnchor(TOPLEFT, win, TOPLEFT, 10, PANEL_HEADER + 8)
    ui.empty:SetHidden(true)

    ui.immediate = UI.CreateLink("KGT_ImmediateBtn", win, "", function()
        Templates.sv.createImmediately = not Templates.sv.createImmediately
        Templates.RefreshImmediateLabel()
    end)
    ui.immediate:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -10, 10)

    win:SetHandler("OnMouseWheel", onTemplateScroll)

    Templates.Refresh()
    Templates.UpdateVisibility()
end

local menuPanelOpen = false
local currentScene  = ""

local instantUpdate

local function isMenuScene(name)
    name = name or currentScene
    return name:find("groupmenu", 1, true) ~= nil or name:find("groupfinder", 1, true) ~= nil
end

local function restoreMenuPanelState()
    menuPanelOpen = Templates.sv and Templates.sv.menuPanelOpen == true
    if menuPanelOpen and History.sv and not History.sv.embeddedHidden then
        History.SetEmbeddedHidden(true)
    end
end

function Templates.CloseGroupFinder()
    local sm = SCENE_MANAGER
    local name = sm and sm:GetCurrentSceneName() or ""
    if name == "" or not isMenuScene(name:lower()) then return end
    ClearTooltip(InformationTooltip)
    sm:ShowBaseScene()
end

local function anchorPanelToButton(button)
    if not button then return false end
    if ui.anchorTarget == button then return true end
    ui.anchorTarget = button
    ui.win:ClearAnchors()
    ui.win:SetAnchor(BOTTOM, button, TOP, 0, PANEL_FROM_BUTTON_Y)
    return true
end

function Templates.UpdateVisibility()
    if not ui.win then return end
    local inMenu = isMenuScene()

    local menuIconShown, menuButton = false, nil
    for _, entry in pairs(ui.menuIcons) do
        local button = entry.button
        local buttonVisible = button ~= nil and not button:IsHidden()
        local want = Templates.sv.menuIconEnabled ~= false and buttonVisible
        if entry.win:IsControlHidden() == want then
            entry.win:SetHidden(not want)
            if not want then ClearTooltip(InformationTooltip) end
        end
        if want and not entry.win:IsHidden() then
            menuIconShown = true
            menuButton = menuButton or button
        end
    end

    local showPanel = false
    if inMenu then
        if menuPanelOpen and hasListing() then
            menuPanelOpen = false
            Templates.sv.menuPanelOpen = false
            if History.sv and History.sv.embeddedHidden then
                History.SetEmbeddedHidden(false)
            end
        end

        showPanel = menuPanelOpen and menuIconShown
        if showPanel and not anchorPanelToButton(menuButton) then showPanel = false end
    end

    if ui.win:IsHidden() == showPanel then
        ui.win:SetHidden(not showPanel)
        if not showPanel then ClearTooltip(InformationTooltip) end
    end
end

function Templates.TogglePanel()
    if not isMenuScene() then return end

    if menuPanelOpen then
        menuPanelOpen = false
        Templates.sv.menuPanelOpen = false
    else
        menuPanelOpen = true
        Templates.sv.menuPanelOpen = true
        if History.sv then History.SetEmbeddedHidden(true) end
    end
    ClearTooltip(InformationTooltip)
    Templates.UpdateVisibility()
end

function Templates.CloseMenuPanel()
    if menuPanelOpen then
        menuPanelOpen = false
        Templates.sv.menuPanelOpen = false
        ClearTooltip(InformationTooltip)
        Templates.UpdateVisibility()
    end
end

local function showMenuIconTooltip(control)
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -10)
    SetTooltipText(InformationTooltip, "Listing Templates\nLeft-click: open/close panel")
end

local function createMenuIcon(name, parent)
    return UI.CreateIconButton({
        name             = name,
        parent           = parent,
        size             = MENU_ICON_SIZE,
        normalTexture    = function() return Templates.sv.iconTexture end,
        hoverTexture     = function() return MENU_ICON_HOVER end,
        showTooltip      = showMenuIconTooltip,
        clearOnMouseDown = true,
        onClick          = function() Templates.TogglePanel() end,
    })
end

local function placeMenuIcons()
    local cfg   = History.sv and History.sv.histIcon
    local title = GF.title
    local tx    = cfg and cfg.tx or ICON_FROM_TITLE_X
    local ty    = cfg and cfg.ty or ICON_FROM_TITLE_Y
    local size  = cfg and cfg.size or MENU_ICON_SIZE

    for _, panelName in ipairs(CREATE_PANELS) do
        local panel  = WINDOW_MANAGER:GetControlByName(panelName)
        local button = WINDOW_MANAGER:GetControlByName(panelName .. "CreateGroupButton")
        if panel and button then
            local entry = ui.menuIcons[panelName]
            if not entry then
                local win = createMenuIcon("KGT_MenuIcon_" .. panelName, panel)
                win:SetHidden(true)
                win:SetDrawLevel(100)
                win:SetHandler("OnEffectivelyHidden", function() Templates.UpdateVisibility() end)
                win:SetHandler("OnEffectivelyShown",  function() Templates.UpdateVisibility() end)
                entry = { win = win, tex = win.tex }
                ui.menuIcons[panelName] = entry

                ZO_PostHookHandler(button, "OnEffectivelyShown",  instantUpdate)
                ZO_PostHookHandler(button, "OnEffectivelyHidden", instantUpdate)
            end
            entry.button = button

            local key = title and string.format("%s|%d|%d|%d", tostring(title), tx, ty, size) or "button"
            if entry.anchorKey ~= key then
                entry.win:ClearAnchors()
                if title then
                    entry.win:SetAnchor(CENTER, title, LEFT, tx, ty)
                    entry.win:SetDimensions(size, size)
                    entry.tex:SetDimensions(size, size)
                else
                    entry.win:SetAnchor(CENTER, button, RIGHT, MENU_ICON_FROM_BTN_X, MENU_ICON_FROM_BTN_Y)
                end
                entry.anchorKey = key
            end
        end
    end
end

instantUpdate = function()
    History.Tick()
    placeMenuIcons()
    Templates.UpdateVisibility()
end

local function onGroupSceneChange(sceneName, newState)
    local lname = sceneName:lower()

    if newState == SCENE_SHOWING then
        currentScene = lname
        if isMenuScene(lname) then
            restoreMenuPanelState()
            placeMenuIcons()
            History.Tick()
        end
        Templates.UpdateVisibility()
    elseif newState == SCENE_SHOWN and isMenuScene(lname) then
        placeMenuIcons()
        History.Tick()
        Templates.UpdateVisibility()
    elseif newState == SCENE_HIDDEN and currentScene == lname then
        currentScene = "other"
        Templates.UpdateVisibility()
    end
end

local function registerSceneCallbacks()
    for _, sceneName in ipairs(GROUP_SCENES) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", function(_, newState)
                onGroupSceneChange(sceneName, newState)
            end)
        end
    end
end

function Templates.OnTick()
    local name = (SCENE_MANAGER:GetCurrentSceneName() or ""):lower()
    if name ~= currentScene then
        currentScene = name
        if isMenuScene(name) then restoreMenuPanelState() end
    end
    if isMenuScene() then placeMenuIcons() end
    Templates.UpdateVisibility()
end

function Templates.Init()
    Templates.sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, "Templates", TEMPLATE_DEFAULTS)
    importOldSavedVars(Templates.sv, "KGroupTemplates_SV", nil)
    migrateTemplatesSavedVars(Templates.sv)

    menuPanelOpen = false
    Templates.sv.menuPanelOpen = false

    ZO_PreHook("RequestCreateGroupListing", function()
        local ok, snap = pcall(snapshotListing)
        if not ok then debugLog("snapshot failed: %s", tostring(snap)) end
        pendingSnapshot = ok and snap or nil
        return false
    end)

    EVENT_MANAGER:RegisterForEvent(NS_TEMPLATES, EVENT_GROUP_FINDER_CREATE_GROUP_LISTING_RESULT, onCreateResult)

    buildTemplatesPanel()
    registerSceneCallbacks()
    placeMenuIcons()
    Templates.UpdateVisibility()
end

function Templates.GetLAMOptions()
    return {
        { type = "header", name = "Listing Templates" },
        {
            type = "checkbox",
            name = "Show icon in Group & Activity Finder",
            tooltip = "Icon at the top right of the Group Finder that opens the Listing Templates block. Shown only while you have no listing (the block only exists while this icon is shown); once you create a listing, the Application History icon takes its place.",
            getFunc = function() return Templates.sv.menuIconEnabled ~= false end,
            setFunc = function(value)
                Templates.sv.menuIconEnabled = value
                Templates.UpdateVisibility()
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = "Create listing immediately",
            tooltip = "When off, clicking a template only fills the Create form instead of creating the listing.",
            getFunc = function() return Templates.sv.createImmediately end,
            setFunc = function(value)
                Templates.sv.createImmediately = value
                Templates.RefreshImmediateLabel()
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = "Auto-save templates",
            tooltip = "Save a template automatically every time you create a listing.",
            getFunc = function() return Templates.sv.autoSave end,
            setFunc = function(value) Templates.sv.autoSave = value end,
            default = true,
        },
        {
            type = "checkbox",
            name = "Also save the invite code",
            getFunc = function() return Templates.sv.saveInviteCode end,
            setFunc = function(value) Templates.sv.saveInviteCode = value end,
            default = false,
        },
        {
            type = "slider",
            name = "Max saved templates",
            tooltip = "When the limit is reached the least recently used, unpinned template is deleted.",
            min = 5, max = 100, step = 1,
            getFunc = function() return Templates.sv.maxTemplates end,
            setFunc = function(value) Templates.sv.maxTemplates = value end,
            default = 50,
        },
    }
end

local PromptNote = { label = nil, bg = nil, cachedEntry = nil, cachedText = nil }

local function isGroupFinderPrompt(incomingEntry)
    if not incomingEntry then return false end
    local fmt = incomingEntry.messageFormat
    return fmt ~= nil
        and (fmt == SI_PLAYER_TO_PLAYER_INCOMING_GROUP_FINDER_APPLICATION
          or fmt == SI_PLAYER_TO_PLAYER_INCOMING_GROUP_FINDER_APPLICATION_CHAMPION)
end

local function findApplicationNote(incomingEntry)
    local wanted = clean(incomingEntry.displayName)
    if wanted == "" then return nil end

    local id, guard = GetNextGroupListingApplicationCharacterId(nil), 0
    while id and guard < 200 do
        guard = guard + 1
        local displayName = GetGroupListingApplicationInfoByCharacterId(id)
        if clean(displayName) == wanted then
            local note = GetGroupListingApplicationNoteByCharacterId(id)
            if note and note ~= "" then return note end
            return nil
        end
        id = GetNextGroupListingApplicationCharacterId(id)
    end

    for _, entry in pairs(History.pending) do
        if entry.displayName == wanted and entry.note and entry.note ~= "" then
            return entry.note
        end
    end
    return nil
end

local function getPromptNoteLabel(p2p)
    if PromptNote.label then return PromptNote.label end

    local bg = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "PromptNoteBG", p2p.container, CT_BACKDROP)
    bg:SetCenterColor(0, 0, 0, 0.5)
    bg:SetEdgeColor(0, 0, 0, 0.5)
    bg:SetEdgeTexture("KApplicationHistory/textures/centerscreen_floating_edge.dds", 256, 256, 8)
    bg:SetCenterTexture("KApplicationHistory/textures/centerscreen_floating_center.dds")
    bg:SetInsets(8, 8, -8, -8)
    bg:SetIntegralWrapping(true)
    bg:SetHidden(true)
    PromptNote.bg = bg

    local label = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "PromptNote", p2p.container, CT_LABEL)
    label:SetFont("ZoInteractionPrompt")
    label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetDimensions(860, 100)
    label:SetAnchor(TOP, p2p.actionArea, BOTTOM, 0, 12)
    label:SetHidden(true)

    PromptNote.label = label
    return label
end

local function hookApplicationPrompt()
    if not ZO_PostHook or not ZO_PreHook or not ZO_PlayerToPlayer then return end

    ZO_PreHook(ZO_PlayerToPlayer, "OnUpdate", function()
        if PromptNote.label then PromptNote.label:SetHidden(true) end
        if PromptNote.bg then PromptNote.bg:SetHidden(true) end
        return false
    end)

    ZO_PostHook(ZO_PlayerToPlayer, "TryShowingResponseLabel", function(self)
        if not History.sv or History.sv.showPromptNote == false then return end

        local incomingEntry = self.incomingQueue and self.incomingQueue[1]
        if not isGroupFinderPrompt(incomingEntry) then return end

        if PromptNote.cachedEntry ~= incomingEntry then
            PromptNote.cachedEntry = incomingEntry
            PromptNote.cachedText  = findApplicationNote(incomingEntry)
        end

        local text = PromptNote.cachedText
        if text then text = "::[ " .. text .. " ]::" end
        if not text then
            PromptNote.cachedEntry = nil
            text = "::[ no message ]::"
        end

        local label = getPromptNoteLabel(self)
        label:SetText(text)
        label:SetHidden(false)

        -- size the background to the text (+ padding) and center it behind the label
        local textW, textH = label:GetTextDimensions()
        local bg = PromptNote.bg
        bg:ClearAnchors()
        bg:SetDimensions(textW + 48, textH + 20)
        bg:SetAnchor(TOP, label, TOP, 0, -10)
        bg:SetHidden(false)
    end)
end

local function setupSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = ADDON_NAME .. "Panel"
    LAM:RegisterAddonPanel(panelName, {
        type                = "panel",
        name                = ADDON_NAME,
        displayName         = ADDON_NAME,
        author              = ADDON_AUTHOR,
        version             = ADDON_VERSION,
        registerForRefresh  = true,
        registerForDefaults = true,
    })

    local options = {
        {
            type = "checkbox",
            name = "Show Application History in the Group Finder",
            tooltip = "Show the APPLICATION HISTORY list inside the Group & Activity Finder. You can also use the icon at the top right of the Group Finder (it appears while you have a listing).",
            getFunc = function() return not History.sv.embeddedHidden end,
            setFunc = function(value) History.SetEmbeddedHidden(not value) end,
            default = true,
        },
        {
            type = "checkbox",
            name = "Show application message on the join prompt",
            tooltip = "Show the message the applicant typed under the \"has applied to join your group\" Accept / Decline prompt.",
            getFunc = function() return History.sv.showPromptNote ~= false end,
            setFunc = function(value) History.sv.showPromptNote = value end,
            default = true,
        },
    }
    for _, option in ipairs(Templates.GetLAMOptions()) do options[#options + 1] = option end

    LAM:RegisterOptionControls(panelName, options)
end

local function onHistoryCommand(arg)
    arg = (arg or ""):lower()
    if arg == "" or arg == "history" then
        History.ToggleEmbedded()
    elseif arg == "reset" then
        History.sv.histIcon = nil
        History.iconAnchorKey = nil
        History.UpdateIconLook()
    elseif arg == "debug" then
        debugEnabled = not debugEnabled
        d("[KAH] debug " .. (debugEnabled and "ON" or "OFF"))
    end
end

local function onTemplatesCommand(arg)
    arg = (arg or ""):lower()
    local sv = Templates.sv
    if arg == "last" then
        Templates.RecreateLast()
    elseif arg == "save" then
        Templates.SaveCurrent()
    elseif arg == "show" then
        Templates.TogglePanel()
    elseif arg == "immediate" then
        sv.createImmediately = not sv.createImmediately
        Templates.RefreshImmediateLabel()
    elseif arg == "invite" then
        sv.saveInviteCode = not sv.saveInviteCode
    elseif arg == "auto" then
        sv.autoSave = not sv.autoSave
    end
end

SLASH_COMMANDS["/kah"]                = onHistoryCommand
SLASH_COMMANDS["/applicationhistory"] = onHistoryCommand
SLASH_COMMANDS["/glt"]                = onTemplatesCommand

function KApplicationHistory_Toggle() History.ToggleEmbedded() end
function KAH:ToggleEmbedded()         History.ToggleEmbedded() end
function KAH:SetEmbeddedHidden(hidden) History.SetEmbeddedHidden(hidden) end
function KAH:Refresh()                History.Refresh() end
KAH.Tick = History.Tick

local lastHistoryTick = 0

local function onUpdate()
    Templates.OnTick()

    local now = GetFrameTimeMilliseconds()
    if now - lastHistoryTick >= HISTORY_TICK_MS then
        lastHistoryTick = now
        History.Tick()
    end
end

local function onAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NS_INIT, EVENT_ADD_ON_LOADED)

    History.sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, "Data", {
        history        = {},
        embeddedHidden = false,
        showPromptNote = true,
    })
    KAH.SV = History.sv
    importOldSavedVars(History.sv, "KApplicationHistory_SavedVars", "Data")

    History.GetIconRoot()
    setupSettingsMenu()
    Templates.Init()

    restoreOpenApplications()
    hookResolveApplication()
    hookApplicationPrompt()
    registerHistoryEvents()

    EVENT_MANAGER:RegisterForUpdate(NS_UPDATE, UPDATE_MS, onUpdate)
end

EVENT_MANAGER:RegisterForEvent(NS_INIT, EVENT_ADD_ON_LOADED, onAddonLoaded)
