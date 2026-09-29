-- OCCP.lua : CP BIS Guide + one-click Champion Point profile apply.
-- Open with the "Champion points" button (top-left) or /cpbis

local ADDON_NAME = "OneClickChampionPoints"
OCCP = OCCP or {}
local C = OCCP

local defaults = { x = 300, y = 120, mode = "PVE", role = nil, classId = nil, docked = true, launcherX = 16, launcherY = 14, launcherHidden = false, scale = 1 }

local COLOR = {
    warfare = "7FB2E5",
    fitness = "FF6B5A",
    craft   = "8FD17F",
    active  = "FF9A4D",
    idle    = "8F7D76",
    title   = "F2E6DE",
    text    = "E6D8D0",
    edge    = "59606B",
    panel   = "17191F",
}

-- Dropdown order, A to Z: Arcanist, Dragonknight, Necromancer, Nightblade, Sorcerer, Templar, Warden
local CLASS_ORDER = { 117, 1, 5, 3, 2, 6, 4 }
local CLASS_NAME = {
    [1] = "Dragonknight", [2] = "Sorcerer", [3] = "Nightblade", [4] = "Warden",
    [5] = "Necromancer", [6] = "Templar", [117] = "Arcanist",
}

local ROLE_NAME = { MAG = "Magicka", STAM = "Stamina", HEAL = "Healer", TANK = "Tank" }
local PVE_ONLY_ROLE = { HEAL = true, TANK = true }

-- ESO's own group-finder role icons.
local ROLE_ICON = {
    DD   = "EsoUI/Art/LFG/LFG_icon_dps.dds",
    TANK = "EsoUI/Art/LFG/LFG_icon_tank.dds",
    HEAL = "EsoUI/Art/LFG/LFG_icon_healer.dds",
}
local ROLE_ICON_SIZE = 22
local MAGICKA_COLOR, STAMINA_COLOR = "5AA9FF", "6FD36F"

local WIN_W, WIN_H = 700, 736
local LOGO_TEXTURE = "OneClickChampionPoints/Textures/logo.dds"
local TITLE_LOGO_SIZE = 56     -- matches the two title lines ("ONE CLICK" + "Champion Points")
local LAUNCHER_LOGO_SIZE = 26  -- fits the 32 px launcher with a little air
local ICON_W, ICON_H = 84, 42   -- tree logo above each column (cosmetic)
local COL_W, COL_GAP = 210, 16
local ui = {}

-- Passives block layout
local PASSIVE_TREES = { "warfare", "fitness", "craft" }
local PASSIVE_NAME_W = 84      -- width of the "Warfare / Fitness / Craft" column
local PASSIVE_ROW_GAP = 8      -- extra space between the three tree rows
local PASSIVE_WRAP_CHARS = 72  -- wrap long lists between entries, never inside one

local function DetectRole()
    if GetPlayerStat(STAT_STAMINA_MAX) > GetPlayerStat(STAT_MAGICKA_MAX) then return "STAM" end
    return "MAG"
end

local function GetBuild(classId, mode, role)
    local base = C.Data[mode] and C.Data[mode][role]
    if not base then return nil end
    local ov = C.ClassOverrides and C.ClassOverrides[classId]
    ov = ov and ov[mode] and ov[mode][role]
    if not ov then return base end
    local merged = {}
    for k, v in pairs(base) do merged[k] = v end
    for k, v in pairs(ov) do merged[k] = v end
    merged.classSpecific = true
    return merged
end

local function SlotText(list, color)
    local lines = {}
    for i, s in ipairs(list or {}) do
        lines[#lines + 1] = string.format("|c%s%d.|r  %s", color, i, s)
    end
    return table.concat(lines, "\n")
end

local function HexToRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function MakeLabel(name, parent, font, width, height)
    local l = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    l:SetFont(font)
    l:SetDimensions(width, height)
    local r, g, b = HexToRGB(COLOR.text)
    l:SetColor(r, g, b, 1)
    return l
end

local function MakeLine(name, parent, width, height, hex, alpha)
    local t = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    local r, g, b = HexToRGB(hex)
    t:SetColor(r, g, b, alpha or 1)
    t:SetDimensions(width, height)
    return t
end

-- Rounded shapes: one circle texture drawn 3-slice (left half, a stretched centre
-- column, right half), so the ends stay perfectly round at any width.
-- "outset" grows the shape past the parent on every side (used for the glow).
local PILL_TEXTURE = {
    fill = "OneClickChampionPoints/Textures/pill_fill.dds",
    edge = "OneClickChampionPoints/Textures/pill_edge.dds",
    glow = "OneClickChampionPoints/Textures/pill_glow.dds",
}

local function MakePill(name, parent, texture, height, outset, drawLevel)
    outset = outset or 0
    local h = height + outset * 2
    local parts = {}
    local function Part(suffix, u1, u2)
        local t = WINDOW_MANAGER:CreateControl(name .. suffix, parent, CT_TEXTURE)
        t:SetTexture(texture)
        t:SetTextureCoords(u1, u2, 0, 1)
        t:SetDrawLevel(drawLevel or 0)
        t:SetMouseEnabled(false)
        parts[#parts + 1] = t
        return t
    end
    local left = Part("L", 0, 0.5)
    left:SetDimensions(h / 2, h)
    left:SetAnchor(LEFT, parent, LEFT, -outset, 0)
    local right = Part("R", 0.5, 1)
    right:SetDimensions(h / 2, h)
    right:SetAnchor(RIGHT, parent, RIGHT, outset, 0)
    local mid = Part("M", 0.49, 0.51)
    mid:SetAnchor(TOPLEFT, left, TOPRIGHT, 0, 0)
    mid:SetAnchor(BOTTOMRIGHT, right, BOTTOMLEFT, 0, 0)

    local pill = {}
    function pill:SetColor(r, g, b, a)
        for _, t in ipairs(parts) do t:SetColor(r, g, b, a) end
    end
    function pill:SetHidden(hidden)
        for _, t in ipairs(parts) do t:SetHidden(hidden) end
    end
    return pill
end

local function MakeTab(name, parent, text, onClick, width)
    width = width or 70
    local l = MakeLabel(name, parent, "ZoFontGameBold", width, 24)
    l:SetText(text)
    l:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    l:SetMouseEnabled(true)
    l:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then onClick() end
    end)
    local u = MakeLine(name .. "U", l, width, 2, COLOR.active)
    u:SetAnchor(BOTTOMLEFT, l, BOTTOMLEFT, 0, 3)
    l.underline = u
    return l
end

-- Small role icon above a tab; clicking it does the same as clicking the tab.
local function AddTabIcon(tab, name, texture)
    local icon = WINDOW_MANAGER:CreateControl(name, tab, CT_TEXTURE)
    icon:SetTexture(texture)
    icon:SetDimensions(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
    icon:SetAnchor(BOTTOM, tab, TOP, 0, -1)
    icon:SetMouseEnabled(true)
    icon:SetHandler("OnMouseUp", tab:GetHandler("OnMouseUp"))
    tab.icon = icon
end

-- Tabs with their own color (Magicka / Stamina) stay in that color and dim when
-- inactive; the others use the orange active / grey idle colors.
local function SetTabState(tab, active)
    local r, g, b, a
    if tab.color then
        r, g, b = HexToRGB(tab.color)
        a = active and 1 or 0.5
    else
        r, g, b = HexToRGB(active and COLOR.active or COLOR.idle)
        a = 1
    end
    tab:SetColor(r, g, b, a)
    tab.underline:SetColor(r, g, b, 1)
    tab.underline:SetHidden(not active)
    if tab.icon then tab.icon:SetColor(1, 1, 1, active and 1 or 0.45) end
end

-- Apply button: green with a check and the setup name when ready; grey with a
-- padlock and the reason when not.
local APPLY_READY = { bg = "123018", edge = "6FD36F", text = "9BF09B" }
local APPLY_IDLE  = { bg = "1B1C20", edge = "4A4640", text = "8F7D76" }
local APPLY_MESSAGE_SECONDS = 10
local APPLY_GOLD = "F2C66D"

-- Turn Apply.GetState's all-caps status into a short line that fits the button.
local function ShortReason(text)
    text = text or ""
    if text:find("REDISTRIBUTE", 1, true) then return "Redistribute points first" end
    if text:find("VIEW ONLY", 1, true) then return "Pick your own class" end
    if text:find("COMBAT", 1, true) then return "Leave combat first" end
    local secs = text:match("WAIT (%d+)")
    if secs then return "Wait " .. secs .. " seconds" end
    if text:find("APPLYING", 1, true) then return "Applying…" end
    if text:find("NOT READY", 1, true) then return "Not ready yet" end
    if text:find("applied successfully", 1, true) or text:find("Applied!", 1, true) then return "Applied!" end
    -- Longer messages (errors) are shown in full under the CP totals.
    if text ~= text:upper() then return "See the message on the left" end
    text = text:sub(1, 1) .. text:sub(2):lower()
    if #text > 28 then text = text:sub(1, 27) .. "…" end
    return text
end

local function SelectedSetupName()
    local sv = C.sv
    if not sv or not sv.classId then return "" end
    return string.format("%s %s %s", CLASS_NAME[sv.classId] or "?", ROLE_NAME[sv.role] or sv.role or "",
        sv.mode == "PVP" and "PvP" or "PvE")
end

local function SetApplyButtonState(ready, reason)
    local button = ui.applyButton
    if not button then return end
    button:SetEnabled(ready)
    ui.applyButtonEnabled = ready
    local look = ready and APPLY_READY or APPLY_IDLE
    local r, g, b = HexToRGB(look.bg)
    button.bg.fill:SetColor(r, g, b, 0.95)
    r, g, b = HexToRGB(look.edge)
    button.bg.edge:SetColor(r, g, b, 1)
    button.bg.glow:SetColor(r, g, b, 0.5)
    button.bg.glow:SetHidden(not ready)
    r, g, b = HexToRGB(look.text)
    button.main:SetColor(r, g, b, 1)
    button.sub:SetColor(r, g, b, 0.85)
    button.icon:SetTexture(ready and "OneClickChampionPoints/Textures/check.dds" or "OneClickChampionPoints/Textures/lock.dds")
    button.icon:SetColor(r, g, b, 1)
    button.sub:SetText(ready and SelectedSetupName() or ShortReason(reason))

    -- Redistributing costs gold: show it next to APPLY so nobody is surprised.
    local cost = 0
    if ready and CHAMPION_DATA_MANAGER and CHAMPION_DATA_MANAGER:IsRespecNeeded() and GetChampionRespecCost then
        cost = GetChampionRespecCost() or 0
    end
    ui.applyCost = cost
    if cost > 0 then
        button.main:SetText(string.format("APPLY  |c%s%s|r |t16:16:EsoUI/Art/currency/currency_gold.dds|t",
            APPLY_GOLD, ZO_CommaDelimitNumber(cost)))
    else
        button.main:SetText("APPLY")
    end
    -- keep icon + text centered together
    button.top:SetWidth(16 + 6 + button.main:GetTextWidth())
end

-- Result messages (applied / errors) show under the CP totals for a few seconds;
-- the button itself always shows the current state.
function C.SetApplyStatus(text, good, buttonEnabled)
    if not ui.applyStatus then return end
    ui.applyStatus:SetText(text or "")
    local color = good and COLOR.craft or COLOR.fitness
    local r, g, b = HexToRGB(color)
    ui.applyStatus:SetColor(r, g, b, 1)
    ui.applyMessageUntil = (GetFrameTimeSeconds and GetFrameTimeSeconds() or 0) + APPLY_MESSAGE_SECONDS
    SetApplyButtonState(buttonEnabled == true and good == true, text)
end

local function WrapPassiveLine(text, maxChars)
    if type(text) ~= "string" or text == "" then return "-" end
    maxChars = maxChars or 82
    local tokens = {}
    for token in string.gmatch(text, "[^,]+") do
        token = token:gsub("^%s+", ""):gsub("%s+$", "")
        if token ~= "" then tokens[#tokens + 1] = token end
    end
    local lines, current = {}, ""
    for _, token in ipairs(tokens) do
        local candidate = current == "" and token or (current .. ", " .. token)
        if current ~= "" and #candidate > maxChars then
            lines[#lines + 1] = current .. ","
            current = token
        else
            current = candidate
        end
    end
    if current ~= "" then lines[#lines + 1] = current end
    return table.concat(lines, "\n")
end

local function FormatNumber(n)
    n = tonumber(n) or 0
    return ZO_CommaDelimitNumber(math.floor(n))
end

function C.RefreshPointPools()
    if not C.Apply or not ui.cpPools then return end
    local pools = C.Apply.GetTreePointPools()
    local total = C.Apply.GetTotalCP()
    -- Short enough to stay left of the Apply button (whether points are free is
    -- shown on the button itself).
    ui.cpPools:SetText(string.format(
        "|c%sTOTAL CP %s|r     |c%sWARFARE %s|r     |c%sFITNESS %s|r     |c%sCRAFT %s|r",
        COLOR.active, FormatNumber(total),
        COLOR.warfare, FormatNumber(pools.warfare.total),
        COLOR.fitness, FormatNumber(pools.fitness.total),
        COLOR.craft, FormatNumber(pools.craft.total)))
end

function C.RefreshApplyState()
    if not ui.applyStatus or not C.Apply then return end
    local ready, status = C.Apply.GetState(C.sv and C.sv.classId)
    SetApplyButtonState(ready, status)
    local now = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
    if ui.applyMessageUntil and now > ui.applyMessageUntil then
        ui.applyStatus:SetText("")
        ui.applyMessageUntil = nil
    end
    C.RefreshPointPools()
end

-- Window size: everything lives in ui.content (WIN_W wide, unscaled units), which
-- is scaled as a whole. Dragging an edge or corner of the window changes that
-- scale; the window frame is then snapped to the scaled content.
local SCALE_MIN, SCALE_MAX = 0.6, 1.5

local function SnapWindowToContent()
    if not ui.win then return end
    local s = ui.scale or 1
    ui.win:SetDimensions(math.floor(WIN_W * s + 0.5), math.floor((ui.contentH or WIN_H) * s + 0.5))
end

-- Never let the window grow taller than the screen: the screen clamp would then
-- pin it to the top edge and it could not be moved freely.
local function ApplyScale(s)
    local maxS = SCALE_MAX
    local screenH = GuiRoot:GetHeight()
    if ui.contentH and screenH and screenH > 0 then
        maxS = zo_min(maxS, (screenH - 20) / ui.contentH)
    end
    s = zo_clamp(s or 1, SCALE_MIN, zo_max(SCALE_MIN, maxS))
    ui.scale = s
    if ui.content then ui.content:SetScale(s) end
end

-- Pin the window to a screen position (not to the launcher) and remember it.
local function PinWindowAt(x, y)
    local sv = C.sv
    sv.x, sv.y = x, y
    sv.docked = false
    ui.win:ClearAnchors()
    ui.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

-- Grow the content when the (wrapped) passive lists push the footer past WIN_H.
-- Label heights only settle after ESO's next layout pass, so measure then
-- (and undo the open animation's and the size scale so the numbers are in content units).
local FOOTER_BOTTOM_PAD = 18

local function MeasureAndFit()
    if not ui.content or not ui.footer then return end
    local top, footTop = ui.content:GetTop(), ui.footer:GetTop()
    if not top or not footTop or footTop <= top then return end
    local scale = (ui.win:GetScale() or 1) * (ui.content:GetScale() or 1)
    if scale <= 0 then scale = 1 end
    local needed = (footTop - top) / scale + ui.footer:GetTextHeight() + FOOTER_BOTTOM_PAD
    ui.contentH = zo_max(WIN_H, zo_ceil(needed))
    ui.content:SetHeight(ui.contentH)
    if not ui.resizing then
        ApplyScale(ui.scale)   -- a taller page may need a smaller scale to fit the screen
        SnapWindowToContent()
    end
end

local function FitWindowHeight()
    MeasureAndFit()
    zo_callLater(MeasureAndFit, 0)
end

function C.Refresh()
    local sv = C.sv
    if not sv or not sv.classId or not sv.mode or not sv.role then return end

    -- Healer / Tank have no PvP setups; fall back to the character's damage role there.
    if sv.mode == "PVP" and PVE_ONLY_ROLE[sv.role] then sv.role = DetectRole() end

    local build = GetBuild(sv.classId, sv.mode, sv.role)
    if not build then return end

    SetTabState(ui.tabPvE, sv.mode == "PVE")
    SetTabState(ui.tabPvP, sv.mode == "PVP")
    local isDD = not PVE_ONLY_ROLE[sv.role]
    SetTabState(ui.tabDD, isDD)
    SetTabState(ui.tabTank, sv.role == "TANK")
    SetTabState(ui.tabHeal, sv.role == "HEAL")
    -- Magicka / Stamina only belong to DD.
    ui.tabMag:SetHidden(not isDD)
    ui.tabStam:SetHidden(not isDD)
    SetTabState(ui.tabMag, sv.role == "MAG")
    SetTabState(ui.tabStam, sv.role == "STAM")

    -- Show exactly what Apply will slot in this game (stars that can't go on the
    -- Champion bar are already swapped for the next best one).
    local slots = C.Apply and C.Apply.GetSlotNames and C.Apply.GetSlotNames(build) or build
    ui.warfareBody:SetText(SlotText(slots.warfare, COLOR.warfare))
    ui.fitnessBody:SetText(SlotText(slots.fitness, COLOR.fitness))
    ui.craftBody:SetText(SlotText(slots.craft, COLOR.craft))

    -- Passives: one row per tree, label on the left, points wrapped in their own column.
    local p = build.passives or {}
    for _, tree in ipairs(PASSIVE_TREES) do
        local text = type(p[tree]) == "string" and WrapPassiveLine(p[tree], PASSIVE_WRAP_CHARS) or "-"
        ui.passiveRows[tree]:SetText(text)
    end

    local roleName = ROLE_NAME[sv.role] or sv.role
    -- Footer: "Sources" and "Tip" rows, laid out like the passives rows.
    local names = {}
    for _, name in ipairs(build.sources or {}) do
        names[#names + 1] = string.format("|c%s%s|r", COLOR.text, name)
    end
    local sources = #names > 0 and table.concat(names, string.format("|c%s,|r   ", COLOR.idle)) or "-"
    if build.verified == false then sources = "|cFF8844[!] Unverified|r   " .. sources end
    ui.footSources:SetText(sources)
    local hasTip = build.note and build.note ~= ""
    ui.footTip:SetText(hasTip and build.note or "")
    ui.footTipName:SetHidden(not hasTip)
    ui.footer = hasTip and ui.footTip or ui.footSources   -- lowest row, for the height fit
    FitWindowHeight()

    local selected = CLASS_NAME[sv.classId] .. " " .. roleName .. " " .. (sv.mode == "PVE" and "PvE" or "PvP")
    if sv.classId ~= ui.myClassId then
        selected = selected .. "  |cFF9A4D[VIEW ONLY]|r"
    end
    ui.selectedBuildName:SetText(selected)
    C.RefreshApplyState()
end

local function Column(prefix, parent, title, color, iconFile)
    local line = MakeLine(prefix .. "Line", parent, COL_W, 2, color)
    if iconFile then
        local icon = WINDOW_MANAGER:CreateControl(prefix .. "Icon", parent, CT_TEXTURE)
        icon:SetTexture("OneClickChampionPoints/Textures/" .. iconFile)
        icon:SetDimensions(ICON_W, ICON_H)
        icon:SetAnchor(BOTTOMLEFT, line, TOPLEFT, 0, -3)
        icon:SetMouseEnabled(false)
    end
    local header = MakeLabel(prefix .. "Head", parent, "ZoFontGameBold", COL_W, 22)
    header:SetText(string.format("|c%s%s|r", color, title))
    header:SetAnchor(TOPLEFT, line, BOTTOMLEFT, 2, 4)
    local body = MakeLabel(prefix .. "Body", parent, "ZoFontGame", COL_W - 4, 96)
    body:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 2)
    return line, body
end

local function CreateClassDropdown(win, anchorTo)
    local dd = WINDOW_MANAGER:CreateControlFromVirtual("OCCP_ClassDD", win, "ZO_ComboBox")
    dd:SetDimensions(200, 28)
    dd:SetAnchor(TOPLEFT, anchorTo, BOTTOMLEFT, 0, 12)

    local combo = ZO_ComboBox_ObjectFromContainer(dd)
    combo:SetSortsItems(false)
    combo:SetFont("ZoFontGameBold")

    local selectedIndex = 1
    for i, id in ipairs(CLASS_ORDER) do
        local label = CLASS_NAME[id] .. ((id == ui.myClassId) and "  (you)" or "")
        local entry = combo:CreateItemEntry(label, function()
            C.sv.classId = id
            C.Refresh()
        end)
        combo:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
        if id == C.sv.classId then selectedIndex = i end
    end
    combo:UpdateItems()
    combo:SelectItemByIndex(selectedIndex, true)

    ui.dd, ui.combo = dd, combo
    return dd
end

local function CreateApplyButton(win)
    -- Two lines: [icon] APPLY, and under it the setup name (ready) or the reason (not ready).
    local button = WINDOW_MANAGER:CreateControl("OCCP_ApplyButton", win, CT_BUTTON)
    button:SetDimensions(190, 46)
    button:SetMouseEnabled(true)
    button:SetDrawLevel(50)

    -- Full pill (same round textures as the launcher); soft green glow while ready.
    local glow = MakePill("OCCP_ApplyGlow", button, PILL_TEXTURE.glow, 46, 6, 0)
    local fill = MakePill("OCCP_ApplyFill", button, PILL_TEXTURE.fill, 46, 0, 1)
    local edge = MakePill("OCCP_ApplyEdge", button, PILL_TEXTURE.edge, 46, 0, 2)
    local bg = { glow = glow, fill = fill, edge = edge }

    -- icon + "APPLY" centered together on the top line
    local top = WINDOW_MANAGER:CreateControl("OCCP_ApplyTop", button, CT_CONTROL)
    top:SetDimensions(84, 22)
    top:SetAnchor(TOP, button, TOP, 0, 4)
    local icon = WINDOW_MANAGER:CreateControl("OCCP_ApplyIcon", top, CT_TEXTURE)
    icon:SetDimensions(16, 16)
    icon:SetAnchor(LEFT, top, LEFT, 0, 0)
    -- wide enough for "APPLY  3,000 [gold]"; the container is sized to the text for centering
    local main = MakeLabel("OCCP_ApplyMain", top, "$(BOLD_FONT)|17|soft-shadow-thin", 160, 22)
    main:SetText("APPLY")
    main:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    main:SetAnchor(LEFT, icon, RIGHT, 6, 0)

    local sub = MakeLabel("OCCP_ApplySub", button, "$(MEDIUM_FONT)|13|soft-shadow-thin", 182, 16)
    sub:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    sub:SetAnchor(BOTTOM, button, BOTTOM, 0, -4)
    -- text and icon above the pill layers (glow 0, fill 1, edge 2)
    icon:SetDrawLevel(5)
    main:SetDrawLevel(5)
    sub:SetDrawLevel(5)

    button:SetHandler("OnMouseEnter", function(self)
        if ui.applyCost and ui.applyCost > 0 then
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -8, TOP)
            SetTooltipText(InformationTooltip, string.format(
                "Applying costs %s gold.\nThis is ESO's own fee for redistributing Champion Points.",
                ZO_CommaDelimitNumber(ui.applyCost)))
        end
        if ui.applyButtonEnabled then
            self:SetScale(1.03)
            local r, g, b = HexToRGB(APPLY_READY.bg)
            fill:SetColor(r * 1.4, g * 1.4, b * 1.4, 1)
            glow:SetColor(0.44, 0.83, 0.44, 0.85)
        end
    end)
    button:SetHandler("OnMouseExit", function(self)
        ClearTooltip(InformationTooltip)
        self:SetScale(1.0)
        if ui.applyButtonEnabled then
            local r, g, b = HexToRGB(APPLY_READY.bg)
            fill:SetColor(r, g, b, 0.95)
            glow:SetColor(0.44, 0.83, 0.44, 0.5)
        end
    end)
    button:SetHandler("OnMouseUp", function(self, mouseButton, upInside)
        if mouseButton ~= MOUSE_BUTTON_INDEX_LEFT or not upInside then return end

        local selectedClassId = C.sv and C.sv.classId
        local ready, stateText = C.Apply.GetState(selectedClassId)
        if not ready then
            C.SetApplyStatus(stateText, false, stateText:find("VIEW ONLY", 1, true) == nil)
            return
        end

        local sv = C.sv
        local build = GetBuild(sv.classId, sv.mode, sv.role)
        local roleName = ROLE_NAME[sv.role] or sv.role
        local modeName = sv.mode == "PVE" and "PvE" or "PvP"
        C.Apply.ApplyBuild(build, CLASS_NAME[sv.classId] .. " " .. roleName .. " " .. modeName)
    end)

    button.bg, button.icon, button.main, button.sub, button.top = bg, icon, main, sub, top
    ui.applyButton = button
    return button
end


-- ---------------------------------------------------------------------------
-- Launcher button (top-left) + open/close animation. Cosmetic only.
-- ---------------------------------------------------------------------------
local LAUNCHER_TEXT_NORMAL = "C5C29E"   -- ESO's default beige UI text
local LAUNCHER_TEXT_HOVER  = "FFFFFF"   -- ESO's highlight text
local LAUNCHER_BG_ALPHA, LAUNCHER_BG_ALPHA_HOVER = 0.82, 0.95
local LAUNCHER_FILL = "0C0C0E"
local LAUNCHER_EDGE, LAUNCHER_EDGE_HOVER = "C9A45C", "F2C66D"

local function SetLauncherTextColor(hovered)
    if not ui.launcherText then return end
    local hex = ui.isOpen and COLOR.active or (hovered and LAUNCHER_TEXT_HOVER or LAUNCHER_TEXT_NORMAL)
    local r, g, b = HexToRGB(hex)
    ui.launcherText:SetColor(r, g, b, 1)
end

-- Launcher text "CP 1,076" and the ready dot (green = this character's points
-- are reset and a setup can be applied, grey otherwise).
function C.RefreshLauncher()
    if not ui.launcherText or not C.Apply then return end
    local total = C.Apply.GetTotalCP()
    ui.launcherText:SetText(total > 0 and ("CP " .. FormatNumber(total)) or "CP")
    local ready = C.Apply.GetState(GetUnitClassId("player"))
    ui.launcherReady = ready
    local r, g, b = HexToRGB(ready and "6FD36F" or COLOR.idle)
    ui.launcherDot:SetColor(r, g, b, ready and 1 or 0.7)
end

local function CreateLauncher()
    local launcher = WINDOW_MANAGER:CreateTopLevelWindow("OCCP_Launcher")
    launcher:SetDimensions(150, 32)
    launcher:ClearAnchors()
    launcher:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, C.sv.launcherX or 16, C.sv.launcherY or 14)
    launcher:SetClampedToScreen(true)
    launcher:SetMouseEnabled(true)
    launcher:SetMovable(true)

    -- Gold pill: dark fill, thin gold line, soft gold glow on hover.
    local glow = MakePill("OCCP_LauncherGlow", launcher, PILL_TEXTURE.glow, 32, 5, 0)
    local fill = MakePill("OCCP_LauncherFill", launcher, PILL_TEXTURE.fill, 32, 0, 1)
    local edge = MakePill("OCCP_LauncherEdge", launcher, PILL_TEXTURE.edge, 32, 0, 2)
    local function SetPillHover(hovered)
        local r, g, b = HexToRGB(LAUNCHER_FILL)
        fill:SetColor(r, g, b, hovered and LAUNCHER_BG_ALPHA_HOVER or LAUNCHER_BG_ALPHA)
        r, g, b = HexToRGB(hovered and LAUNCHER_EDGE_HOVER or LAUNCHER_EDGE)
        edge:SetColor(r, g, b, 1)
        r, g, b = HexToRGB(LAUNCHER_EDGE_HOVER)
        glow:SetColor(r, g, b, 0.6)
        glow:SetHidden(not hovered)
    end
    SetPillHover(false)

    -- Logo, total CP, and a dot that turns green when the points are reset and
    -- a setup can be applied.
    local logo = WINDOW_MANAGER:CreateControl("OCCP_LauncherLogo", launcher, CT_TEXTURE)
    logo:SetTexture(LOGO_TEXTURE)
    logo:SetDimensions(LAUNCHER_LOGO_SIZE, LAUNCHER_LOGO_SIZE)
    logo:SetAnchor(LEFT, launcher, LEFT, 6, 0)
    logo:SetDrawLevel(5)
    logo:SetMouseEnabled(false)

    local text = WINDOW_MANAGER:CreateControl("OCCP_LauncherText", launcher, CT_LABEL)
    text:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
    text:SetText("CP")
    text:SetDimensions(90, 32)
    text:SetAnchor(LEFT, logo, RIGHT, 6, 0)
    text:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    text:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    text:SetDrawLevel(5)
    text:SetMouseEnabled(false)
    ui.launcherText = text

    local dot = WINDOW_MANAGER:CreateControl("OCCP_LauncherDot", launcher, CT_TEXTURE)
    dot:SetTexture("OneClickChampionPoints/Textures/dot.dds")
    dot:SetDimensions(9, 9)
    dot:SetAnchor(RIGHT, launcher, RIGHT, -28, 0)
    dot:SetDrawLevel(5)
    dot:SetMouseEnabled(false)
    ui.launcherDot = dot
    C.RefreshLauncher()

    launcher:SetHandler("OnMouseEnter", function(self)
        SetPillHover(true)
        SetLauncherTextColor(true)
        InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 4, BOTTOMLEFT)
        SetTooltipText(InformationTooltip, "One Click Champion Points")
        if ui.launcherReady then
            InformationTooltip:AddLine("Green dot: your points are free. Open and click Apply.", "ZoFontGameSmall")
        else
            InformationTooltip:AddLine("Grey dot: your points are spent.", "ZoFontGameSmall")
            InformationTooltip:AddLine("Press Redistribute in the Champion screen first,\nthen the dot turns green and you can apply.", "ZoFontGameSmall")
        end
        InformationTooltip:AddLine("Click: open / collapse  ·  Drag: move", "ZoFontGameSmall")
    end)
    launcher:SetHandler("OnMouseExit", function()
        SetPillHover(false)
        SetLauncherTextColor(false)
        ClearTooltip(InformationTooltip)
    end)
    -- Drag to move; a short click (no movement) opens / collapses.
    launcher:SetHandler("OnMouseDown", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            ui.pressX, ui.pressY = self:GetLeft(), self:GetTop()
        end
    end)
    launcher:SetHandler("OnMoveStart", function()
        ClearTooltip(InformationTooltip)
    end)
    launcher:SetHandler("OnMoveStop", function(self)
        C.sv.launcherX, C.sv.launcherY = self:GetLeft(), self:GetTop()
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, C.sv.launcherX, C.sv.launcherY)
        -- moving the button brings the window along under it
        C.sv.docked = true
        if C.PlaceWindow then C.PlaceWindow() end
    end)
    launcher:SetHandler("OnMouseUp", function(self, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local moved = ui.pressX and (math.abs(self:GetLeft() - ui.pressX) > 3 or math.abs(self:GetTop() - ui.pressY) > 3)
        ui.pressX, ui.pressY = nil, nil
        if upInside and not moved then C.Toggle() end
    end)

    -- Small "x" in the top-right corner: hides the button (bring it back with /cpbis button).
    local close = MakeLabel("OCCP_LauncherClose", launcher, "$(BOLD_FONT)|14|soft-shadow-thin", 16, 16)
    close:SetText("x")
    close:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    close:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    close:SetAnchor(RIGHT, launcher, RIGHT, -8, 0)   -- inside the round end
    close:SetDrawLevel(6)
    close:SetMouseEnabled(true)
    local cr, cg, cb = HexToRGB(COLOR.idle)
    close:SetColor(cr, cg, cb, 1)
    close:SetHandler("OnMouseEnter", function(self)
        local r, g, b = HexToRGB(COLOR.active)
        self:SetColor(r, g, b, 1)
        InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 4, BOTTOMLEFT)
        SetTooltipText(InformationTooltip, "Hide this button\nType /cpbis to show it again")
    end)
    close:SetHandler("OnMouseExit", function(self)
        self:SetColor(cr, cg, cb, 1)
        ClearTooltip(InformationTooltip)
    end)
    close:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            ClearTooltip(InformationTooltip)
            C.SetLauncherShown(false)
            d("|cFF9A4DOne Click CP:|r button hidden. Type |cFFFFFF/cpbis|r to show it again.")
        end
    end)

    -- Show the launcher on the normal HUD (and HUD with cursor), hide it in menus like ESO's own HUD elements.
    if ZO_HUDFadeSceneFragment and HUD_SCENE and HUD_UI_SCENE then
        ui.launcherFragment = ZO_HUDFadeSceneFragment:New(launcher)
        ui.launcherAttached = false
    end

    ui.launcher = launcher
    SetLauncherTextColor(false)
    C.SetLauncherShown(not C.sv.launcherHidden)
end

-- Show or hide the launcher button and remember the choice.
function C.SetLauncherShown(show)
    local launcher, fragment = ui.launcher, ui.launcherFragment
    if not launcher then return end
    C.sv.launcherHidden = not show
    if fragment and ui.launcherAttached ~= show then
        -- The HUD fragment controls visibility while it is attached, so attach/detach it.
        ui.launcherAttached = show
        if show then
            HUD_SCENE:AddFragment(fragment)
            HUD_UI_SCENE:AddFragment(fragment)
        else
            HUD_SCENE:RemoveFragment(fragment)
            HUD_UI_SCENE:RemoveFragment(fragment)
        end
    end
    launcher:SetHidden(not show or (fragment ~= nil and not (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing())))
end

-- Window sits right under the launcher unless the player dragged it somewhere else.
function C.PlaceWindow()
    local win, sv = ui.win, C.sv
    if not win or not sv then return end
    win:ClearAnchors()
    if sv.docked ~= false and ui.launcher then
        win:SetAnchor(TOPLEFT, ui.launcher, BOTTOMLEFT, 0, 6)
    else
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x, sv.y)
    end
end

local function CreateOpenAnimation(win)
    if not ANIMATION_MANAGER then return end
    local timeline = ANIMATION_MANAGER:CreateTimeline()

    local fade = timeline:InsertAnimation(ANIMATION_ALPHA, win)
    fade:SetAlphaValues(0, 1)
    fade:SetDuration(180)

    local grow = timeline:InsertAnimation(ANIMATION_SCALE, win)
    grow:SetScaleValues(0.92, 1)
    grow:SetDuration(220)

    if ZO_EaseOutCubic then
        fade:SetEasingFunction(ZO_EaseOutCubic)
        grow:SetEasingFunction(ZO_EaseOutCubic)
    end

    timeline:SetHandler("OnStop", function()
        if not ui.isOpen then win:SetHidden(true) end
    end)
    ui.openAnim = timeline
end

local function CreateUI()
    local sv = C.sv
    ui.myClassId = GetUnitClassId("player")

    -- The frame: movable, and resizable from every edge and corner (ESO shows the
    -- double-arrow cursor there). Resizing scales the content instead of re-flowing it.
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("OCCP_Window")
    frame:SetDimensions(WIN_W, WIN_H)
    frame:SetClampedToScreen(true)
    -- Draw above HUD elements like the minimap and quest tracker, so they don't show through.
    frame:SetDrawTier(DT_HIGH)
    frame:SetMovable(true)
    frame:SetMouseEnabled(true)
    frame:SetHidden(true)
    frame:SetResizeHandleSize(8)
    frame:SetDimensionConstraints(WIN_W * SCALE_MIN, 150, WIN_W * SCALE_MAX, 3000)
    frame:SetHandler("OnMoveStop", function(self)
        PinWindowAt(self:GetLeft(), self:GetTop())
    end)
    frame:SetHandler("OnResizeStart", function(self)
        ui.resizing = true
        ui.resizeW, ui.resizeH, ui.resizeS = self:GetWidth(), self:GetHeight(), ui.scale or 1
        ui.resizeL, ui.resizeT = self:GetLeft(), self:GetTop()
        -- follow the edge live: whichever side moved most sets the new scale
        self:SetHandler("OnUpdate", function()
            local rw = self:GetWidth() / ui.resizeW
            local rh = self:GetHeight() / ui.resizeH
            local r = (math.abs(rw - 1) >= math.abs(rh - 1)) and rw or rh
            ApplyScale(ui.resizeS * r)
        end)
    end)
    frame:SetHandler("OnResizeStop", function(self)
        self:SetHandler("OnUpdate", nil)
        ui.resizing = false
        ApplyScale(ui.scale)
        sv.scale = ui.scale

        -- Snap the frame to the scaled content, keeping the corner opposite the
        -- dragged edge where it is (so dragging the left/top edge doesn't jump).
        local movedL = math.abs(self:GetLeft() - ui.resizeL) > 0.5
        local movedT = math.abs(self:GetTop() - ui.resizeT) > 0.5
        local right, bottom = self:GetRight(), self:GetBottom()
        local left, top = self:GetLeft(), self:GetTop()
        SnapWindowToContent()
        if movedL or movedT or sv.docked == false then
            local x = movedL and (right - self:GetWidth()) or left
            local y = movedT and (bottom - self:GetHeight()) or top
            PinWindowAt(x, y)
        else
            C.PlaceWindow()
        end
    end)
    ui.win = frame

    CreateLauncher()
    C.PlaceWindow()
    CreateOpenAnimation(frame)

    local bg = WINDOW_MANAGER:CreateControl("OCCP_BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.04, 0.045, 0.06, 0.90)
    bg:SetEdgeColor(0.30, 0.32, 0.36, 0.80)
    bg:SetEdgeTexture("", 1, 1, 1)

    -- Everything else goes in the scaled content container.
    local win = WINDOW_MANAGER:CreateControl("OCCP_Content", frame, CT_CONTROL)
    win:SetDimensions(WIN_W, WIN_H)
    win:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    ui.content = win
    ui.contentH = WIN_H
    ApplyScale(sv.scale)
    SnapWindowToContent()

    -- Title: logo, then "ONE CLICK" small in the accent color above "Champion Points"
    -- in ESO's book font. The logo is as tall as both text lines together.
    local logo = WINDOW_MANAGER:CreateControl("OCCP_TitleLogo", win, CT_TEXTURE)
    logo:SetTexture(LOGO_TEXTURE)
    logo:SetDimensions(TITLE_LOGO_SIZE, TITLE_LOGO_SIZE)
    logo:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 6)

    local kicker = MakeLabel("OCCP_TitleKicker", win, "$(BOLD_FONT)|14|soft-shadow-thin", 300, 16)
    kicker:SetText("O N E   C L I C K")
    local kr, kg, kb = HexToRGB(COLOR.active)
    kicker:SetColor(kr, kg, kb, 1)
    kicker:SetAnchor(TOPLEFT, logo, TOPRIGHT, 8, 4)

    local title = MakeLabel("OCCP_Title", win, "$(ANTIQUE_FONT)|34|soft-shadow-thick", 500, 36)
    title:SetText("Champion Points")
    local tr, tg, tb = HexToRGB(COLOR.title)
    title:SetColor(tr, tg, tb, 1)
    title:SetAnchor(TOPLEFT, kicker, BOTTOMLEFT, -2, -2)

    local minimize = MakeLabel("OCCP_Minimize", win, "$(BOLD_FONT)|28|soft-shadow-thin", 30, 30)
    minimize:SetText("-")
    minimize:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    minimize:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    minimize:SetAnchor(TOPRIGHT, win, TOPRIGHT, -12, 10)
    minimize:SetMouseEnabled(true)
    local ir, ig, ib = HexToRGB(COLOR.idle)
    minimize:SetColor(ir, ig, ib, 1)
    minimize:SetHandler("OnMouseEnter", function(self)
        local r, g, b = HexToRGB(COLOR.active)
        self:SetColor(r, g, b, 1)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
        SetTooltipText(InformationTooltip, "Minimize")
    end)
    minimize:SetHandler("OnMouseExit", function(self)
        self:SetColor(ir, ig, ib, 1)
        ClearTooltip(InformationTooltip)
    end)
    minimize:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then C.Toggle(false) end
    end)

    local titleLine = MakeLine("OCCP_TitleLine", win, WIN_W - 40, 1, COLOR.edge, 0.65)
    titleLine:SetAnchor(TOPLEFT, win, TOPLEFT, 20, TITLE_LOGO_SIZE + 14)

    local dd = CreateClassDropdown(win, titleLine)

    -- Role categories with icons, left to right: DD, Tank, Healer (right-aligned).
    -- Healer / Tank are PvE-only, so picking one also switches to PvE.
    local function PickPvERole(role) sv.role = role; sv.mode = "PVE"; C.Refresh() end
    local function PickDDRole(role) sv.role = role; sv.ddRole = role; C.Refresh() end

    local catY = 14 + ROLE_ICON_SIZE + 2
    ui.tabHeal = MakeTab("OCCP_TabHeal", win, "Healer", function() PickPvERole("HEAL") end, 70)
    ui.tabHeal:SetAnchor(TOPRIGHT, titleLine, BOTTOMRIGHT, 0, catY)
    AddTabIcon(ui.tabHeal, "OCCP_TabHealIcon", ROLE_ICON.HEAL)
    ui.tabTank = MakeTab("OCCP_TabTank", win, "Tank", function() PickPvERole("TANK") end, 70)
    ui.tabTank:SetAnchor(RIGHT, ui.tabHeal, LEFT, -6, 0)
    AddTabIcon(ui.tabTank, "OCCP_TabTankIcon", ROLE_ICON.TANK)
    ui.tabDD = MakeTab("OCCP_TabDD", win, "DD", function()
        if PVE_ONLY_ROLE[sv.role] then PickDDRole(sv.ddRole or DetectRole()) end
    end, 70)
    ui.tabDD:SetAnchor(RIGHT, ui.tabTank, LEFT, -6, 0)
    AddTabIcon(ui.tabDD, "OCCP_TabDDIcon", ROLE_ICON.DD)

    -- Magicka / Stamina only show while DD is picked (anchored above Apply, below).
    ui.tabMag = MakeTab("OCCP_TabMag", win, "Magicka", function() PickDDRole("MAG") end, 80)
    ui.tabMag.color = MAGICKA_COLOR
    ui.tabStam = MakeTab("OCCP_TabStam", win, "Stamina", function() PickDDRole("STAM") end, 80)
    ui.tabStam.color = STAMINA_COLOR

    ui.tabPvE = MakeTab("OCCP_TabPvE", win, "PvE", function() sv.mode = "PVE"; C.Refresh() end, 64)
    ui.tabPvE:SetAnchor(TOPLEFT, dd, BOTTOMLEFT, 0, 12)
    ui.tabPvP = MakeTab("OCCP_TabPvP", win, "PvP", function() sv.mode = "PVP"; C.Refresh() end, 64)
    ui.tabPvP:SetAnchor(LEFT, ui.tabPvE, RIGHT, 6, 0)

    CreateApplyButton(win)
    ui.applyButton:SetAnchor(TOPRIGHT, titleLine, BOTTOMRIGHT, 0, 106)
    -- Magicka / Stamina sit centered right above the Apply button (clear of its glow).
    ui.tabMag:SetAnchor(BOTTOMRIGHT, ui.applyButton, TOP, -3, -10)
    ui.tabStam:SetAnchor(BOTTOMLEFT, ui.applyButton, TOP, 3, -10)

    ui.selectedBuildName = MakeLabel("OCCP_SelectedBuild", win, "ZoFontGameBold", 390, 22)
    ui.selectedBuildName:SetAnchor(TOPLEFT, ui.tabPvE, BOTTOMLEFT, 0, 8)
    local ar, ag, ab = HexToRGB(COLOR.title)
    ui.selectedBuildName:SetColor(ar, ag, ab, 1)

    -- Left column stops before the Apply button (190 wide + a 16 px gap).
    local LEFT_INFO_W = WIN_W - 40 - 190 - 16
    ui.cpPools = MakeLabel("OCCP_CPPools", win, "ZoFontGameSmall", LEFT_INFO_W, 28)
    ui.cpPools:SetAnchor(TOPLEFT, ui.selectedBuildName, BOTTOMLEFT, 0, 2)

    ui.applyStatus = MakeLabel("OCCP_ApplyStatus", win, "ZoFontGameSmall", LEFT_INFO_W, 22)
    ui.applyStatus:SetAnchor(TOPLEFT, ui.cpPools, BOTTOMLEFT, 0, 0)

    local divider = MakeLine("OCCP_Div", win, WIN_W - 40, 1, COLOR.edge, 0.5)
    divider:SetAnchor(TOPLEFT, ui.applyStatus, BOTTOMLEFT, 0, 7)

    local wLine, wBody = Column("OCCP_W", win, "WARFARE", COLOR.warfare, "warfare.dds")
    wLine:SetAnchor(TOPLEFT, divider, BOTTOMLEFT, 0, 12 + ICON_H + 3)
    local fLine, fBody = Column("OCCP_F", win, "FITNESS", COLOR.fitness, "fitness.dds")
    fLine:SetAnchor(TOPLEFT, wLine, TOPRIGHT, COL_GAP, 0)
    local cLine, cBody = Column("OCCP_C", win, "CRAFT", COLOR.craft, "craft.dds")
    cLine:SetAnchor(TOPLEFT, fLine, TOPRIGHT, COL_GAP, 0)
    ui.warfareBody, ui.fitnessBody, ui.craftBody = wBody, fBody, cBody

    -- Passives block: header, then a row per tree with a fixed-width name column
    -- so wrapped lines stay indented under their own tree.
    local passHeader = MakeLabel("OCCP_PassHeader", win, "ZoFontGameBold", WIN_W - 40, 24)
    passHeader:SetText(string.format("|c%sPassives (suggested points)|r", COLOR.active))
    passHeader:SetAnchor(TOPLEFT, wBody, BOTTOMLEFT, -2, 14)

    ui.passiveRows = {}
    local prevBody
    for i, tree in ipairs(PASSIVE_TREES) do
        local key = tree:sub(1, 1):upper() .. tree:sub(2)
        local name = MakeLabel("OCCP_PassName" .. key, win, "ZoFontGame", PASSIVE_NAME_W, 24)
        name:SetText(string.format("|c%s%s|r", COLOR[tree], key))
        if prevBody then
            -- start under the previous row's (possibly wrapped) text, back in the name column
            name:SetAnchor(TOPLEFT, prevBody, BOTTOMLEFT, -PASSIVE_NAME_W, PASSIVE_ROW_GAP)
        else
            name:SetAnchor(TOPLEFT, passHeader, BOTTOMLEFT, 0, 4)
        end

        local body = WINDOW_MANAGER:CreateControl("OCCP_PassBody" .. key, win, CT_LABEL)
        body:SetFont("ZoFontGame")
        body:SetWidth(WIN_W - 40 - PASSIVE_NAME_W)   -- width only: height grows with the text
        local r, g, b = HexToRGB(COLOR.text)
        body:SetColor(r, g, b, 1)
        body:SetAnchor(TOPLEFT, name, TOPRIGHT, 0, 0)

        ui.passiveRows[tree] = body
        prevBody = body
    end

    -- Footer: thin line, then "Sources" and "Tip" rows in the same name column as the passives.
    local footLine = MakeLine("OCCP_FootLine", win, WIN_W - 40, 1, COLOR.edge, 0.5)
    footLine:SetAnchor(TOPLEFT, prevBody, BOTTOMLEFT, -PASSIVE_NAME_W, 14)

    local function FootRow(key, title, color, anchorTo, offsetX, offsetY)
        local name = MakeLabel("OCCP_Foot" .. key .. "Name", win, "ZoFontGameSmall", PASSIVE_NAME_W, 20)
        name:SetText(title)
        local r, g, b = HexToRGB(color)
        name:SetColor(r, g, b, 1)
        name:SetAnchor(TOPLEFT, anchorTo, BOTTOMLEFT, offsetX, offsetY)
        local body = WINDOW_MANAGER:CreateControl("OCCP_Foot" .. key, win, CT_LABEL)
        body:SetFont("ZoFontGameSmall")
        body:SetWidth(WIN_W - 40 - PASSIVE_NAME_W)
        local tr, tg, tb = HexToRGB(COLOR.text)
        body:SetColor(tr, tg, tb, 1)
        body:SetAnchor(TOPLEFT, name, TOPRIGHT, 0, 0)
        return name, body
    end
    local _, sourcesBody = FootRow("Sources", "Sources", COLOR.idle, footLine, 0, 8)
    local tipName, tipBody = FootRow("Tip", "Tip", COLOR.active, sourcesBody, -PASSIVE_NAME_W, 4)
    ui.footSources, ui.footTip, ui.footTipName = sourcesBody, tipBody, tipName
    ui.footer = tipBody

    SetApplyButtonState(false)
end

function C.Toggle(show)
    if not ui.win then return end
    if show == nil then show = not ui.isOpen end
    if show == (ui.isOpen == true) then return end
    ui.isOpen = show
    SetLauncherTextColor(false)

    if show then
        C.PlaceWindow()
        ui.win:SetHidden(false)
        C.Refresh()
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "ApplyState", 500, function()
            if ui.win:IsHidden() then return end
            C.RefreshApplyState()
        end)
        SetGameCameraUIMode(true)
        if ui.openAnim then
            if ui.openAnim:IsPlaying() then ui.openAnim:PlayForward() else ui.openAnim:PlayFromStart() end
        else
            ui.win:SetAlpha(1)
        end
    else
        EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "ApplyState")
        if ui.combo and ui.combo.HideDropdown then ui.combo:HideDropdown() end
        if ui.openAnim then
            if ui.openAnim:IsPlaying() then ui.openAnim:PlayBackward() else ui.openAnim:PlayFromEnd() end
        else
            ui.win:SetHidden(true)
        end
    end
end

-- /cpbis        brings the "Champion points" button back if it was hidden with its x;
--               otherwise opens / collapses the window.
-- /cpbis check  compares your Champion Points with the selected setup (your own class).
SLASH_COMMANDS["/cpbis"] = function(args)
    if args and args:lower():find("check", 1, true) then
        local sv = C.sv
        local classId = GetUnitClassId("player")
        local role = sv.role
        if sv.mode == "PVP" and PVE_ONLY_ROLE[role] then role = DetectRole() end
        local build = GetBuild(classId, sv.mode, role)
        if not build then return end
        local label = string.format("%s %s %s", CLASS_NAME[classId] or "?", ROLE_NAME[role] or role,
            sv.mode == "PVP" and "PvP" or "PvE")
        for _, line in ipairs(C.Apply.CheckBuild(build, label)) do d(line) end
        return
    end
    if C.sv and C.sv.launcherHidden then
        C.SetLauncherShown(true)
        d("|cFF9A4DOne Click CP:|r button shown.")
    else
        C.Toggle()
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    C.sv = ZO_SavedVars:NewAccountWide("OCCP_SV", 1, nil, defaults)
    C.sv.classId = C.sv.classId or GetUnitClassId("player")
    C.sv.role = C.sv.role or DetectRole()
    C.sv.mode = C.sv.mode or "PVE"

    C.Apply.Initialize()
    CreateUI()
    C.Refresh()

    -- Keep the launcher's CP total and ready dot current (cheap check, only while it is visible).
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Launcher", 2000, function()
        if ui.launcher and not ui.launcher:IsHidden() then C.RefreshLauncher() end
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

-- Up to 1.0.0 this addon lived in a folder called "CPBIS". If that old copy is
-- still installed and enabled, both would run side by side: tell the player once.
local function WarnAboutOldFolder()
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "OldFolder", EVENT_PLAYER_ACTIVATED)
    local manager = GetAddOnManager and GetAddOnManager()
    if not manager then return end
    for i = 1, manager:GetNumAddOns() do
        local name, _, _, _, enabled = manager:GetAddOnInfo(i)
        if name == "CPBIS" and enabled then
            d("|cFF9A4DOne Click CP:|r the old |cFFFFFFCPBIS|r folder is still installed. "
                .. "Please delete AddOns\\CPBIS (the addon now lives in AddOns\\OneClickChampionPoints).")
            return
        end
    end
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "OldFolder", EVENT_PLAYER_ACTIVATED, WarnAboutOldFolder)
