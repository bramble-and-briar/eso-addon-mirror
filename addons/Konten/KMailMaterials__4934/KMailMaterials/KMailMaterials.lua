KMailMaterials = KMailMaterials or {}
local KMM = KMailMaterials

local ADDON = "KMailMaterials"
local SV = nil
local MAX_ATT = MAIL_MAX_ATTACHED_ITEMS or 6

local SHOW_DEBUG_OPTION = false
local running = false
local currentRecipient = nil
local settingsPanel = nil
local sent = 0
local pendingBatch = nil
local currentMode = nil
local updateButtons = function() end

local NAME_KEYWORDS = {
    "design", "diagram", "formula", "blueprint", "pattern",
    "praxis", "motif", "style", "recipe", "unidentified"
}

local function say(msg)
    if SV and SV.showMessages == false then return end
    d("|c66ccff[KMailMaterials]|r " .. msg)
end

local function debugPrint(msg)
    if SHOW_DEBUG_OPTION and SV and SV.debug then
        d("|cffcc00[KMailMaterials DEBUG]|r " .. msg)
    end
end

local function alert(msg)
    say(msg)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, msg)
end

local function isMaterial(bagId, slotIndex)
    local f1, f2, f3, f4 = GetItemFilterTypeInfo(bagId, slotIndex)
    return f1 == ITEMFILTERTYPE_CRAFTING or f2 == ITEMFILTERTYPE_CRAFTING
        or f3 == ITEMFILTERTYPE_CRAFTING or f4 == ITEMFILTERTYPE_CRAFTING
end

local function nameMatches(bagId, slotIndex)
    local name = zo_strformat("<<1>>", GetItemName(bagId, slotIndex))
    if not name or name == "" then return false end
    name = zo_strlower(name)
    for _, kw in ipairs(NAME_KEYWORDS) do
        if string.find(name, kw, 1, true) then return true end
    end
    return false
end

local DEFAULT_SUBJECTS = {
    materials = "Materials",
    recipes   = "Recipes",
}

local MODES = {
    materials = { svKey = "subjectMaterials", label = "materials", match = isMaterial },
    recipes   = { svKey = "subjectRecipes",   label = "recipes/plans/styles", match = nameMatches },
}

local MAX_SUBJECT = MAIL_MAX_SUBJECT_CHARACTERS or 50

local function getSubject(modeKey)
    local mode = MODES[modeKey]
    local s = SV and SV[mode.svKey] or ""
    s = zo_strtrim(s)
    if s == "" then s = DEFAULT_SUBJECTS[modeKey] end
    return zo_strsub(s, 1, MAX_SUBJECT)
end

local function isSelf(name)
    return name ~= nil and zo_strlower(name) == zo_strlower(GetDisplayName())
end

local function collectCandidates(limit, matchFn)
    local list = {}
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if #list >= limit then break end
        if GetSlotStackSize(BAG_BACKPACK, slotIndex) > 0
            and matchFn(BAG_BACKPACK, slotIndex)
            and CanQueueItemAttachment(BAG_BACKPACK, slotIndex, 1) then
            list[#list + 1] = { bag = BAG_BACKPACK, slot = slotIndex }
        end
    end
    return list
end

local function getRecipient()
    local r = SV and SV.recipient or ""
    r = zo_strtrim(r)
    if r == "" then return nil end
    if r:sub(1, 1) ~= "@" then r = "@" .. r end
    return r
end

local function fillTo(recipient)
    if ZO_MailSendToField and ZO_MailSendToField.SetText then
        ZO_MailSendToField:SetText(recipient)
    end
end

local function stop(reason)
    running = false
    currentMode = nil
    updateButtons()
    if reason then say(reason) end
end

local function sendBatch(recipient)
    if not running then return end

    ClearQueuedMail()

    local mode = MODES[currentMode]
    local cands = collectCandidates(MAX_ATT, mode.match)

    if #cands == 0 then
        if sent > 0 then
            stop(string.format("Done. %d mail(s) sent.", sent))
        else
            stop("No " .. mode.label .. " to send.")
        end
        return
    end

    pendingBatch = {}
    for i, c in ipairs(cands) do
        local link = GetItemLink(c.bag, c.slot)
        pendingBatch[#pendingBatch + 1] = {
            name    = zo_strformat("<<1>>", GetItemName(c.bag, c.slot)),
            count   = GetSlotStackSize(c.bag, c.slot),
            quality = GetItemLinkQuality(link),
            icon    = GetItemInfo(c.bag, c.slot),
            link    = link,
        }
        debugPrint(string.format(
            "Attach #%d: %s",
            i,
            tostring(GetItemName(c.bag, c.slot))
        ))
        QueueItemAttachment(c.bag, c.slot, i)
    end

    zo_callLater(function()
        if not running then return end
        fillTo(recipient)
        SendMail(recipient, getSubject(currentMode), "")
    end, 400)
end

function KMM.Start(modeKey)
    if running then return end
    modeKey = MODES[modeKey] and modeKey or "materials"

    if SCENE_MANAGER:GetCurrentSceneName() ~= "mailSend" then
        say("Open the mail window (Send tab) first.")
        return
    end

    local recipient = getRecipient()

    if not recipient then
        local msg = "Set the recipient in Settings > Addons > KMailMaterials."
        alert(msg)

        local LAM = LibAddonMenu2
        if LAM and LAM.OpenToPanel and settingsPanel then
            zo_callLater(function()
                LAM:OpenToPanel(settingsPanel)
            end, 100)
        end
        return
    end

    if isSelf(recipient) then
        alert("The recipient is your own account (" .. recipient .. "). ESO does not allow sending mail to yourself.")
        return
    end

    running = true
    currentMode = modeKey
    sent = 0
    currentRecipient = recipient
    updateButtons()

    fillTo(recipient)
    say("Sending " .. MODES[modeKey].label .. " to " .. recipient .. "...")

    sendBatch(recipient)
end

function KMM.Stop()
    stop("Cancelled.")
end

local MAX_LOG = 500
local ICON_SIZE = 40
local ICON_TEXTURE      = "EsoUI/Art/MainMenu/menuBar_mail_up.dds"
local ICON_TEXTURE_OVER = "EsoUI/Art/MainMenu/menuBar_mail_over.dds"
local ICON_SCENES = { hud = true, hudui = true }

local LOG_ROWS, LOG_ROW_H = 12, 26
local LOG_W, LOG_HEAD, LOG_FOOT = 760, 52, 30
local COL_TIME,  COL_TIME_W   = 0,   170
local COL_ICON,  ICON_PX      = 180, 22
local COL_ITEM,  COL_ITEM_W   = 210, 270
local COL_QTY,   COL_QTY_W    = 490, 60
local COL_TARGET, COL_TARGET_W = 570, 170

local logView = nil
local enteredUIMode = false
local clearArmed = false
local clearToken = 0

local function logList()
    return SV and SV.log or {}
end

local function iconSV()
    SV.icon = SV.icon or { x = 200, y = 200, locked = false, enabled = true }
    return SV.icon
end

local function showRowTooltip(row)
    ClearTooltip(ItemTooltip)
    if row.link and row.link ~= "" then
        InitializeTooltip(ItemTooltip, row, LEFT, 10, 0, RIGHT)
        ItemTooltip:SetLink(row.link)
    end
end

local function refreshLog()
    local view = logView
    if not view then return end

    local list = logList()
    local total = #list
    local maxOffset = math.max(0, total - LOG_ROWS)
    if view.offset > maxOffset then view.offset = maxOffset end
    if view.offset < 0 then view.offset = 0 end

    view.title:SetText(string.format("::[KMailMaterials]:: Sent items (%d)", total))

    for i, row in ipairs(view.rows) do
        local e = list[view.offset + i]
        if e then
            row:SetHidden(false)
            row.link = e.link
            row.time:SetText(os.date("%d/%m/%Y %H:%M:%S", e.time or 0))
            local icon = e.icon
            if (not icon or icon == "") and e.link then icon = GetItemLinkIcon(e.link) end
            if icon and icon ~= "" then
                row.icon:SetTexture(icon)
                row.icon:SetHidden(false)
            else
                row.icon:SetHidden(true)
            end
            row.item:SetText(e.name or "?")
            local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, e.quality or ITEM_QUALITY_NORMAL)
            row.item:SetColor(r or 1, g or 1, b or 1, 1)
            row.qty:SetText(tostring(e.count or 1))
            row.target:SetText(e.target or "?")
            if MouseIsOver(row) then showRowTooltip(row) end
        else
            row.link = nil
            row:SetHidden(true)
        end
    end

    if total == 0 then
        view.footer:SetText("Nothing sent yet.")
    else
        view.footer:SetText(string.format("::[KMailMaterials]:: %d-%d of %d   -   mouse wheel to scroll",
            view.offset + 1, math.min(view.offset + LOG_ROWS, total), total))
    end
end

local function resetClearLabel()
    clearArmed = false
    clearToken = clearToken + 1
    if logView then
        logView.clearLabel:SetText("[ Clear history ]")
        logView.clearLabel:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    end
end

local function armClear()
    clearArmed = true
    clearToken = clearToken + 1
    local token = clearToken
    logView.clearLabel:SetText("[ CONFIRM ]")
    logView.clearLabel:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
    zo_callLater(function()
        if clearToken == token then resetClearLabel() end
    end, 4000)
end

local function clearLog()
    ZO_ClearNumericallyIndexedTable(SV.log)
    if logView then logView.offset = 0 end
    refreshLog()
end

local function createLogView()
    local wm = WINDOW_MANAGER
    local view = { offset = 0, rows = {} }
    local W = LOG_W

    local win = wm:CreateTopLevelWindow("KMailMaterialsWindow")
    win:SetDimensions(W, LOG_HEAD + LOG_ROWS * LOG_ROW_H + LOG_FOOT)
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_MEDIUM)
    win:SetDrawLevel(0)
    win:SetHandler("OnMouseWheel", function(_, delta)
        view.offset = view.offset - delta
        refreshLog()
    end)

    local pos = SV.position or { x = 400, y = 200 }
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    win:SetHandler("OnMoveStop", function()
        SV.position = { x = win:GetLeft(), y = win:GetTop() }
    end)

    local bg = wm:CreateControl("KMailMaterialsWindow_BG", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0, 0, 0, 0.75)
    bg:SetEdgeColor(1, 1, 1, 0.3)

    local title = wm:CreateControl("KMailMaterialsWindow_Title", win, CT_LABEL)
    title:SetFont("ZoFontWinH5")
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 10)
    title:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    view.title = title

    local function header(text, x, w, align)
        local lbl = wm:CreateControl("KMailMaterialsWindow_Col" .. text, win, CT_LABEL)
        lbl:SetFont("ZoFontGameSmall")
        lbl:SetText(text)
        lbl:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        lbl:SetDimensions(w, 20)
        lbl:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
        lbl:SetAnchor(TOPLEFT, win, TOPLEFT, 10 + x, 30)
    end
    header("TIME", COL_TIME, COL_TIME_W)
    header("ITEM", COL_ITEM, COL_ITEM_W)
    header("QTY", COL_QTY, COL_QTY_W, TEXT_ALIGN_RIGHT)
    header("TO", COL_TARGET, COL_TARGET_W)

    local close = wm:CreateControl("KMailMaterialsWindow_Close", win, CT_LABEL)
    close:SetFont("ZoFontWinH4")
    close:SetText("X")
    close:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    close:SetDimensions(24, 24)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -8, 8)
    close:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    close:SetMouseEnabled(true)
    close:SetHandler("OnMouseEnter", function() close:SetColor(ZO_SELECTED_TEXT:UnpackRGBA()) end)
    close:SetHandler("OnMouseExit",  function() close:SetColor(ZO_NORMAL_TEXT:UnpackRGBA()) end)
    close:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then KMM.ToggleLog() end
    end)

    local clear = wm:CreateControl("KMailMaterialsWindow_Clear", win, CT_LABEL)
    clear:SetFont("ZoFontGameSmall")
    clear:SetText("[ Clear history ]")
    clear:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    clear:SetDimensions(190, 20)
    clear:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    clear:SetAnchor(TOPRIGHT, close, TOPLEFT, -10, 3)
    clear:SetMouseEnabled(true)
    clear:SetHandler("OnMouseEnter", function() if not clearArmed then clear:SetColor(ZO_SELECTED_TEXT:UnpackRGBA()) end end)
    clear:SetHandler("OnMouseExit",  function() if not clearArmed then clear:SetColor(ZO_NORMAL_TEXT:UnpackRGBA()) end end)
    clear:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if clearArmed then
            resetClearLabel()
            clearLog()
        else
            armClear()
        end
    end)
    view.clearLabel = clear

    local function cell(row, suffix, x, w, align, color)
        local lbl = wm:CreateControl(row:GetName() .. suffix, row, CT_LABEL)
        lbl:SetFont("ZoFontGame")
        lbl:SetDimensions(w, LOG_ROW_H)
        lbl:SetAnchor(LEFT, row, LEFT, x, 0)
        lbl:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
        lbl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        lbl:SetColor(unpack(color))
        return lbl
    end

    for i = 1, LOG_ROWS do
        local row = wm:CreateControl("KMailMaterialsWindow_Row" .. i, win, CT_CONTROL)
        row:SetDimensions(W - 20, LOG_ROW_H)
        row:SetAnchor(TOPLEFT, win, TOPLEFT, 10, LOG_HEAD + (i - 1) * LOG_ROW_H)
        row:SetMouseEnabled(true)

        local hl = wm:CreateControl(row:GetName() .. "_HL", row, CT_BACKDROP)
        hl:SetAnchorFill(row)
        hl:SetCenterColor(1, 1, 1, 0.08)
        hl:SetEdgeColor(0, 0, 0, 0)
        hl:SetHidden(true)

        row:SetHandler("OnMouseEnter", function()
            hl:SetHidden(false)
            showRowTooltip(row)
        end)
        row:SetHandler("OnMouseExit", function()
            hl:SetHidden(true)
            ClearTooltip(ItemTooltip)
        end)
        row:SetHandler("OnMouseWheel", function(_, delta)
            view.offset = view.offset - delta
            refreshLog()
        end)

        row.time   = cell(row, "_Time",   COL_TIME,   COL_TIME_W,   TEXT_ALIGN_LEFT,  { 0.46, 0.74, 0.77, 1 })
        local ico = wm:CreateControl(row:GetName() .. "_Icon", row, CT_TEXTURE)
        ico:SetDimensions(ICON_PX, ICON_PX)
        ico:SetAnchor(LEFT, row, LEFT, COL_ICON, 0)
        row.icon = ico

        row.item   = cell(row, "_Item",   COL_ITEM,   COL_ITEM_W,   TEXT_ALIGN_LEFT,  { 1, 1, 1, 1 })
        row.qty    = cell(row, "_Qty",    COL_QTY,    COL_QTY_W,    TEXT_ALIGN_RIGHT, { 1, 1, 1, 1 })
        row.target = cell(row, "_Target", COL_TARGET, COL_TARGET_W, TEXT_ALIGN_LEFT,  { 0.46, 0.74, 0.77, 1 })

        view.rows[i] = row
    end

    local footer = wm:CreateControl("KMailMaterialsWindow_Footer", win, CT_LABEL)
    footer:SetFont("ZoFontGameSmall")
    footer:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
    footer:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 12, -8)
    view.footer = footer

    view.window = win
    logView = view
end

function KMM.ToggleLog()
    if not SV then return end
    if not logView then createLogView() end
    local win = logView.window

    if not win:IsHidden() then
        ClearTooltip(ItemTooltip)
        win:SetHidden(true)
        if enteredUIMode then
            enteredUIMode = false
            SCENE_MANAGER:SetInUIMode(false)
        end
        return
    end

    local alreadyUI = SCENE_MANAGER.IsInUIMode and SCENE_MANAGER:IsInUIMode()
    if not alreadyUI then
        enteredUIMode = true
        SCENE_MANAGER:SetInUIMode(true)
    end

    win:SetHidden(false)
    refreshLog()
end

local function logBatch()
    if not pendingBatch then return end
    local ts = GetTimeStamp()
    for i = #pendingBatch, 1, -1 do
        local p = pendingBatch[i]
        table.insert(SV.log, 1, {
            time    = ts,
            name    = p.name,
            count   = p.count,
            quality = p.quality,
            icon    = p.icon,
            link    = p.link,
            target  = currentRecipient,
        })
    end
    pendingBatch = nil
    while #SV.log > MAX_LOG do table.remove(SV.log) end
    refreshLog()
end

local function updateIconLockVisual()
    local win = KMM.iconWin
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
        "KMailMaterials\nLeft-click: open/close\nRight-click: lock/unlock position (%s)\nDrag to move%s",
        state, iconSV().locked and " (unlock first)" or ""))
end

local function createIcon()
    if KMM.iconWin then return end
    local wm = WINDOW_MANAGER
    local sv = iconSV()

    local win = wm:CreateTopLevelWindow("KMailMaterialsIcon")
    win:SetDimensions(ICON_SIZE, ICON_SIZE)
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_MEDIUM)
    win:SetDrawLevel(0)
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x or 200, sv.y or 200)

    local bg = wm:CreateControl("KMailMaterialsIcon_BG", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0, 0, 0, 0.55)
    bg:SetEdgeColor(1, 0.85, 0.3, 0.9)
    bg:SetEdgeTexture("", 1, 1, 1)
    win.bg = bg

    local tex = wm:CreateControl("KMailMaterialsIcon_Tex", win, CT_TEXTURE)
    tex:SetTexture(ICON_TEXTURE)
    tex:SetDimensions(ICON_SIZE - 6, ICON_SIZE - 6)
    tex:SetAnchor(CENTER, win, CENTER, 0, 0)

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
            if not moved then KMM.ToggleLog() end
        elseif button == MOUSE_BUTTON_INDEX_RIGHT then
            local s = iconSV()
            s.locked = not s.locked
            updateIconLockVisual()
            showIconTooltip(ctrl)
        end
    end)

    KMM.iconWin = win
    updateIconLockVisual()
end

local function updateIconVisibility()
    local win = KMM.iconWin
    if not win or not SV then return end
    local show = iconSV().enabled ~= false
        and ICON_SCENES[(SCENE_MANAGER:GetCurrentSceneName() or ""):lower()] == true
    if show and win:IsHidden() then
        win:SetHidden(false)
    elseif not show and not win:IsHidden() then
        win:SetHidden(true)
        ClearTooltip(InformationTooltip)
    end
end

local function onSendSuccess()
    if not running then return end

    logBatch()

    sent = sent + 1

    if SV.oneMailPerClick then
        stop("Mail sent. Click again to send the next one.")
        return
    end

    zo_callLater(function()
        sendBatch(currentRecipient)
    end, 600)
end

local function onSendFailed(_, reason)
    if not running then return end
    pendingBatch = nil
    stop("Send failed (code " .. tostring(reason) .. "). Stopped.")
end

local BTN_SIZE = 64
local BTN_GAP = 0
local ICON_PATH = "EsoUI/Art/Inventory/inventory_tabIcon_%s_%s.dds"

local BUTTONS = {
    {
        key = "materials", name = "KMailMaterialsButtonMats", icon = "crafting",
        tip = "AutoSend:\nAll Materials from Materials tab",
    },
    {
        key = "recipes", name = "KMailMaterialsButtonRecipes", icon = "consumables",
        tip = "AutoSend:\nDesign, Diagram, Formula, Blueprint, Pattern,\nPraxis, Motif, Style, Recipes, unidentified box",
    },
}

local buttonControls = {}

updateButtons = function()
    for _, b in ipairs(BUTTONS) do
        local ctrl = buttonControls[b.key]
        if ctrl then
            local active = running and currentMode == b.key
            ctrl:SetNormalTexture(string.format(ICON_PATH, b.icon, active and "down" or "up"))
        end
    end
end

local function createButtons()
    for i, b in ipairs(BUTTONS) do
        local btn = WINDOW_MANAGER:CreateControl(b.name, ZO_MailSend, CT_BUTTON)
        btn:SetDimensions(BTN_SIZE, BTN_SIZE)
        btn:SetAnchor(BOTTOMLEFT, ZO_MailSend, BOTTOMLEFT, (i - 1) * (BTN_SIZE + BTN_GAP) + (i == 1 and 6 or 0), 80)
        btn:SetNormalTexture(string.format(ICON_PATH, b.icon, "up"))
        btn:SetMouseOverTexture(string.format(ICON_PATH, b.icon, "over"))
        btn:SetPressedTexture(string.format(ICON_PATH, b.icon, "down"))

        btn:SetHandler("OnClicked", function()
            if running then
                KMM.Stop()
            else
                KMM.Start(b.key)
            end
        end)
        btn:SetHandler("OnMouseEnter", function(ctrl)
            InitializeTooltip(InformationTooltip, ctrl, TOP, 0, -5)
            local tip = running and (currentMode == b.key) and "Click to cancel" or b.tip
            SetTooltipText(InformationTooltip, tip)
        end)
        btn:SetHandler("OnMouseExit", function()
            ClearTooltip(InformationTooltip)
        end)

        buttonControls[b.key] = btn
    end
end

local OLD_SV_KEYS = { "recipient", "subjectMaterials", "subjectRecipes", "showMessages", "debug", "log", "position", "icon" }

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, val in pairs(v) do t[k] = deepCopy(val) end
    return t
end

local function migrateOldSV()
    local root = KMailMaterialsSV
    local acc = root and root[GetDisplayName()]
    local old = acc and acc["$AccountWide"]
    if type(old) ~= "table" or old.svMigrated then return end

    local src = old
    if old.recipient == nil and type(old.Default) == "table" then src = old.Default end

    local found = false
    for _, key in ipairs(OLD_SV_KEYS) do
        if src[key] ~= nil then
            SV[key] = deepCopy(src[key])
            src[key] = nil
            found = true
        end
    end
    if found then
        old.svMigrated = true
        debugPrint("Old saved variables migrated to " .. GetWorldName())
    end
end

local function onLoaded(_, name)
    if name ~= ADDON then return end

    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    local defaults = {
        recipient          = "",
        subjectMaterials   = DEFAULT_SUBJECTS.materials,
        subjectRecipes     = DEFAULT_SUBJECTS.recipes,
        showMessages       = true,
        oneMailPerClick    = false,
        debug              = false,
    }

    SV = ZO_SavedVars:NewAccountWide("KMailMaterialsSV", 1, GetWorldName(), defaults)
    migrateOldSV()

    if SV.recipient == nil then SV.recipient = "" end
    if SV.showMessages == nil then SV.showMessages = true end
    if SV.debug == nil then SV.debug = false end
    if SV.oneMailPerClick == nil then SV.oneMailPerClick = false end
    SV.log = SV.log or {}
    SV.position = SV.position or { x = 400, y = 200 }
    SV.icon = SV.icon or { x = 200, y = 200, locked = false, enabled = true }
    if SV.icon.enabled == nil then SV.icon.enabled = true end

    local LAM = LibAddonMenu2

    if LAM then
        settingsPanel = LAM:RegisterAddonPanel("KMailMaterialsPanel", {
            type = "panel",
            name = "KMailMaterials",
            displayName = "KMailMaterials",
            author = "|cFF9B15@Konten|r",
            version = "1.0.4",
        })

        local options = {
            {
                type = "description",
                text = "Account name (e.g. @AccountName) that will receive the materials.",
            },
            {
                type = "editbox",
                name = "Recipient",
                tooltip = "Account that receives the mails. Required before sending. Saved per account, so each of your accounts can have a different recipient.",
                getFunc = function()
                    return SV.recipient
                end,
                setFunc = function(value)
                    SV.recipient = zo_strtrim(value or "")
                end,
                isMultiline = false,
                width = "full",
                default = "",
            },
            {
                type = "editbox",
                name = "Materials mail subject",
                tooltip = "Subject of the mails sent with the Materials button. Leave empty to use \"Materials\".",
                getFunc = function()
                    return SV.subjectMaterials
                end,
                setFunc = function(value)
                    SV.subjectMaterials = zo_strsub(zo_strtrim(value or ""), 1, MAX_SUBJECT)
                end,
                isMultiline = false,
                width = "full",
                default = DEFAULT_SUBJECTS.materials,
            },
            {
                type = "editbox",
                name = "Consumables mail subject",
                tooltip = "Subject of the mails sent with the Consumables button. Leave empty to use \"Recipes\".",
                getFunc = function()
                    return SV.subjectRecipes
                end,
                setFunc = function(value)
                    SV.subjectRecipes = zo_strsub(zo_strtrim(value or ""), 1, MAX_SUBJECT)
                end,
                isMultiline = false,
                width = "full",
                default = DEFAULT_SUBJECTS.recipes,
            },
            {
                type = "checkbox",
                name = "Show chat messages",
                tooltip = "Show KMailMaterials status messages in the chat window. On-screen alerts for problems are always shown.",
                getFunc = function()
                    return SV.showMessages
                end,
                setFunc = function(value)
                    SV.showMessages = value
                end,
                default = true,
            },
            {
                type = "checkbox",
                name = "One mail per click",
                tooltip = "Sends only one mail (up to 6 attachments) per click instead of continuing automatically until nothing is left to send.",
                getFunc = function()
                    return SV.oneMailPerClick
                end,
                setFunc = function(value)
                    SV.oneMailPerClick = value
                end,
                default = false,
            },
            {
                type = "checkbox",
                name = "Show HUD icon",
                tooltip = "Show the small movable icon that opens the sent materials log. Right-click the icon to lock/unlock its position.",
                getFunc = function()
                    return iconSV().enabled ~= false
                end,
                setFunc = function(value)
                    iconSV().enabled = value
                    updateIconVisibility()
                end,
                default = true,
            },
        }

        if SHOW_DEBUG_OPTION then
            options[#options + 1] = {
                type = "checkbox",
                name = "Debug mode",
                tooltip = "Print debug info in chat: the items attached to each mail.",
                getFunc = function()
                    return SV.debug
                end,
                setFunc = function(value)
                    SV.debug = value
                end,
                default = false,
            }
        end

        LAM:RegisterOptionControls("KMailMaterialsPanel", options)
    end

    EVENT_MANAGER:RegisterForEvent(
        ADDON,
        EVENT_MAIL_SEND_SUCCESS,
        onSendSuccess
    )

    EVENT_MANAGER:RegisterForEvent(
        ADDON,
        EVENT_MAIL_SEND_FAILED,
        onSendFailed
    )

    EVENT_MANAGER:RegisterForEvent(
        ADDON,
        EVENT_MAIL_CLOSE_MAILBOX,
        function()
            running = false
            currentMode = nil
            pendingBatch = nil
            updateButtons()
        end
    )

    createButtons()
    createIcon()

    local function onSceneStateChange(_, newState)
        if newState == SCENE_SHOWN or newState == SCENE_HIDDEN then
            zo_callLater(updateIconVisibility, 50)
        end
    end
    if HUD_SCENE then HUD_SCENE:RegisterCallback("StateChange", onSceneStateChange) end
    if HUD_UI_SCENE then HUD_UI_SCENE:RegisterCallback("StateChange", onSceneStateChange) end
    updateIconVisibility()

    SLASH_COMMANDS["/sendmats"] = function()
        KMM.Start("materials")
    end

    SLASH_COMMANDS["/sendrecipes"] = function()
        KMM.Start("recipes")
    end

    SLASH_COMMANDS["/matslog"] = function()
        KMM.ToggleLog()
    end

    SLASH_COMMANDS["/stopmats"] = function()
        KMM.Stop()
    end
end

EVENT_MANAGER:RegisterForEvent(
    ADDON,
    EVENT_ADD_ON_LOADED,
    onLoaded
)