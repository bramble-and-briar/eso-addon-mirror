local ADDON_NAME = "KwibusRandomThings"
local ADDON_VERSION = "1.4.6"

local EM = EVENT_MANAGER

-- Global umbrella table (modules attach to this)
KwibusRandomThings = KwibusRandomThings or {
    name = ADDON_NAME,
    version = ADDON_VERSION,
    sv = nil,
    modules = {},
}
local KRT = KwibusRandomThings

-- Helpers (shared)
function KRT.Clamp01(x) return zo_clamp(tonumber(x) or 0, 0, 1) end

function KRT.RGBToHex(r, g, b)
    r = KRT.Clamp01(r); g = KRT.Clamp01(g); b = KRT.Clamp01(b)
    local R = zo_floor(r * 255 + 0.5)
    local G = zo_floor(g * 255 + 0.5)
    local B = zo_floor(b * 255 + 0.5)
    return string.format("|c%02X%02X%02X", R, G, B)
end

function KRT.IsNonEmptyString(s) return type(s) == "string" and s ~= "" end
function KRT.EnsureTable(v) return (type(v) == "table") and v or {} end

function KRT.DeepMergeDefaults(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) == "table" then
                KRT.DeepMergeDefaults(target[k], v)
            elseif target[k] == nil then
                target[k] = ZO_DeepTableCopy(v)
            end
        else
            if target[k] == nil then target[k] = v end
        end
    end
end

-- PERFORMANCE FIX: Static dual-queue executor prevents inline closure allocations, table allocations, and batches debounces
local _debounceQueue = {}
local _processingQueue = {}
local _isDebounceScheduled = false

local function ProcessDebounceQueue()
    _isDebounceScheduled = false
    _debounceQueue, _processingQueue = _processingQueue, _debounceQueue
    for key, fn in pairs(_processingQueue) do
        if type(fn) == "function" then
            fn()
        end
    end
    ZO_ClearTable(_processingQueue)
end

function KRT.DebounceNextFrame(key, fn)
    _debounceQueue[key] = fn
    if not _isDebounceScheduled then
        _isDebounceScheduled = true
        zo_callLater(ProcessDebounceQueue, 0)
    end
end

-- Shared SavedVariables accessor
function KRT.GetModuleSV(id, defaults)
    if not (KRT.sv and id) then return defaults or {} end
    if type(KRT.sv[id]) ~= "table" then
        KRT.sv[id] = defaults and ZO_DeepTableCopy(defaults) or {}
    end
    return KRT.sv[id]
end

-- Shared UI Overlay Helpers
function KRT.ApplyCenterAnchor(control, sv, defaultOffsetY)
    if not (control and sv) then return end
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, sv.offsetX or 0, sv.offsetY or (defaultOffsetY or 0))
end

function KRT.EnableDragging(ui, label, sv, enable, applyAnchorFn, onDisabledFn)
    if not (ui and label and sv) then return end

    ui:SetMouseEnabled(false)
    ui:SetMovable(true)
    ui:SetClampedToScreen(true)
    ui:SetDrawTier(DT_HIGH)
    ui:SetDrawLayer(DL_OVERLAY)

    if enable then
        ui:SetHidden(false)
        label:SetMouseEnabled(true)

        label:SetHandler("OnMouseDown", function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then ui:StartMoving() end
        end)

        label:SetHandler("OnMouseUp", function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then ui:StopMovingOrResizing() end
        end)

        ui:SetHandler("OnMoveStop", function(control)
            local rootCx, rootCy = GuiRoot:GetCenter()
            local ux, uy = control:GetCenter()
            sv.offsetX = zo_round(ux - rootCx)
            sv.offsetY = zo_round(uy - rootCy)
            if applyAnchorFn then applyAnchorFn() end
        end)
    else
        label:SetMouseEnabled(false)
        label:SetHandler("OnMouseDown", nil)
        label:SetHandler("OnMouseUp", nil)
        ui:SetHandler("OnMoveStop", nil)
        if onDisabledFn then onDisabledFn() end
    end
end

function KRT.ResizeTextHitbox(debounceKey, win, label, scale, minW, minH)
    KRT.DebounceNextFrame(debounceKey, function()
        local tries = 0
        local function Resize()
            tries = tries + 1
            local w = (label:GetTextWidth() or 0) * scale + 24
            local h = (label:GetTextHeight() or 0) * scale + 24
            if (w <= 26 or h <= 26) and tries < 6 then
                zo_callLater(Resize, 0)
                return
            end
            if w < (minW or 60) then w = (minW or 60) end
            if h < (minH or 30) then h = (minH or 30) end
            label:SetDimensions(w / scale, h / scale)
            win:SetDimensions(w, h)
        end
        Resize()
    end)
end

-- Shared Zone Data
KRT.TRIAL_ZONES = {
    [638] = true,  -- Aetherian Archive
    [639] = true,  -- Hel Ra Citadel
    [643] = true,  -- Sanctum Ophidia
    [725] = true,  -- Maw of Lorkhaj
    [975] = true,  -- Halls of Fabrication
    [1000] = true, -- Asylum Sanctorium
    [1051] = true, -- Cloudrest
    [1121] = true, -- Sunspire
    [1196] = true, -- Kyne's Aegis
    [1263] = true, -- Rockgrove
    [1344] = true, -- Dreadsail Reef
    [1420] = true, -- Sanity's Edge
    [1478] = true, -- Lucent Citadel
    [1548] = true, -- Ossein Cage
}

KRT.ARENA_ZONES = {
    [636] = true,  -- Dragonstar Arena
    [677] = true,  -- Maelstrom Arena
    [1082] = true, -- Blackrose Prison
    [1227] = true, -- Vateshran Hollows
}

-- Module registry
function KRT:RegisterModule(moduleTable)
    if type(moduleTable) ~= "table" then return end
    if not moduleTable.id then return end
    table.insert(self.modules, moduleTable)
end

local function BuildUnifiedSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "kwibus random things",
        displayName = "kwibus random things |caaaaaav" .. ADDON_VERSION .. "|r",
        author = "|ce6202dKwiebe-Kwibus|r",
        version = ADDON_VERSION,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local moduleList = {}
    local moduleMap = {}
    local options = {}

    local function StripColorCodes(str)
        if type(str) ~= "string" then return "" end
        return str:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    end

    -- Collect all module submenus
    for _, mod in ipairs(KRT.modules) do
        if mod.id and mod.GetLAMSubmenu then
            local sub = mod:GetLAMSubmenu()
            if sub and sub.controls then
                local clean = StripColorCodes(sub.name or mod.id)
                if clean == "" then clean = mod.id:upper() end
                -- Use full clean module name by default, allowing optional tabName override
                local tabLabel = mod.tabName or mod.shortName or clean

                local item = {
                    id = mod.id,
                    mod = mod,
                    cleanName = clean,
                    tabName = tabLabel,
                    displayName = sub.name or ("|cFFD700" .. clean .. "|r"),
                    submenuData = sub,
                }
                table.insert(moduleList, item)
                moduleMap[mod.id] = item

                -- Give submenu a unique global reference so we can grab the created control
                sub.reference = "KRT_Submenu_" .. mod.id
                table.insert(options, sub)
            end
        end
    end

    if #moduleList == 0 then return end

    -- Determine initial active tab
    local activeModuleId = moduleList[1].id
    if KRT.sv and KRT.sv.lastActiveModule and moduleMap[KRT.sv.lastActiveModule] then
        activeModuleId = KRT.sv.lastActiveModule
    end

    local panelControl = nil
    local tabBar = nil
    local tabButtons = {}
    local submenus = {}
    local isInitialized = false

    local function GetHeaderBottomY(panel)
        local bottom = 54
        if panel and panel.info and panel.info.GetBottom and panel.GetTop then
            local b = panel.info:GetBottom() - panel:GetTop()
            if b and b > 20 then
                bottom = b
            end
        end
        return bottom + 8
    end

    local function LayoutTabs()
        if not tabBar or not panelControl then return end
        local totalWidth = tabBar:GetWidth()
        if totalWidth <= 0 then
            totalWidth = panelControl:GetWidth() - 24
        end
        if totalWidth <= 0 then
            totalWidth = 750
        end

        local topOffsetY = GetHeaderBottomY(panelControl)
        tabBar:ClearAnchors()
        tabBar:SetAnchor(TOPLEFT, panelControl, TOPLEFT, 0, topOffsetY)
        tabBar:SetAnchor(TOPRIGHT, panelControl, TOPRIGHT, -14, topOffsetY)

        local count = #moduleList
        local maxPerRow = 4
        local numRows = zo_ceil(count / maxPerRow)
        if numRows < 1 then numRows = 1 end
        local itemsPerRow = zo_ceil(count / numRows)

        local spacingX = 4
        local spacingY = 4
        local btnHeight = 22
        local totalBarHeight = numRows * btnHeight + (numRows - 1) * spacingY
        tabBar:SetHeight(totalBarHeight)

        for i, btn in ipairs(tabButtons) do
            local row = zo_floor((i - 1) / itemsPerRow)
            local col = (i - 1) % itemsPerRow

            local startIdx = row * itemsPerRow + 1
            local endIdx = zo_min((row + 1) * itemsPerRow, count)
            local rowCount = endIdx - startIdx + 1
            local w = zo_floor((totalWidth - (rowCount - 1) * spacingX) / rowCount)

            btn:ClearAnchors()
            local offsetX = col * (w + spacingX)
            local offsetY = row * (btnHeight + spacingY)
            btn:SetAnchor(TOPLEFT, tabBar, TOPLEFT, offsetX, offsetY)
            btn:SetDimensions(w, btnHeight)
        end

        -- Keep scroll container positioned below the tab bar
        if panelControl.container then
            panelControl.container:ClearAnchors()
            panelControl.container:SetAnchor(TOPLEFT, tabBar, BOTTOMLEFT, 0, 8)
            panelControl.container:SetAnchor(BOTTOMRIGHT, panelControl, BOTTOMRIGHT, -3, -3)
        end
    end

    local function SwitchToModule(targetId)
        if not targetId or not moduleMap[targetId] then return end
        activeModuleId = targetId
        if KRT.sv then
            KRT.sv.lastActiveModule = targetId
        end

        -- Update tab buttons appearance
        for i, item in ipairs(moduleList) do
            local btn = tabButtons[i]
            if btn then
                local isCurrent = (item.id == activeModuleId)
                if isCurrent then
                    btn:SetText("|cFFD700[ " .. item.tabName .. " ]|r")
                else
                    btn:SetText("|cCCCCCC" .. item.tabName .. "|r")
                end
            end
        end

        -- Switch module submenus visibility and anchor to top of scroll
        for _, item in ipairs(moduleList) do
            local subCtrl = submenus[item.id]
            if subCtrl then
                if item.id == activeModuleId then
                    subCtrl:SetHidden(false)
                    subCtrl.open = true
                    if subCtrl.scroll then
                        subCtrl.scroll:SetResizeToFitDescendents(true)
                        subCtrl.scroll:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_XY)
                        subCtrl.scroll:SetResizeToFitPadding(5, 20)
                    end
                    subCtrl:ClearAnchors()
                    subCtrl:SetAnchor(TOPLEFT, panelControl.scroll, TOPLEFT, 0, 0)
                    subCtrl:SetAnchor(TOPRIGHT, panelControl.scroll, TOPRIGHT, 0, 0)
                else
                    subCtrl:SetHidden(true)
                    subCtrl.open = false
                    if subCtrl.scroll then
                        subCtrl.scroll:SetResizeToFitDescendents(false)
                        subCtrl.scroll:SetHeight(0)
                    end
                end
            end
        end

        -- Reset scroll position so new tab starts at top
        if panelControl and panelControl.container then
            if ZO_Scroll_ResetToTop then
                ZO_Scroll_ResetToTop(panelControl.container)
            elseif panelControl.container.ResetToTop then
                panelControl.container:ResetToTop()
            end
        end
    end

    local function InitializeTabBar(panel)
        if isInitialized or not panel then return end
        isInitialized = true

        local wm = WINDOW_MANAGER

        -- Create compact pinned tab bar directly on panel (outside scroll container)
        tabBar = wm:CreateControl("KRT_SettingsTabBar", panel, CT_CONTROL)
        local topOffsetY = GetHeaderBottomY(panel)
        tabBar:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, topOffsetY)
        tabBar:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -14, topOffsetY)
        tabBar:SetHeight(74)

        -- Re-anchor scroll container below the pinned tab bar
        if panel.container then
            panel.container:ClearAnchors()
            panel.container:SetAnchor(TOPLEFT, tabBar, BOTTOMLEFT, 0, 8)
            panel.container:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -3, -3)
        end

        -- Create compact tab buttons
        tabButtons = {}
        for _, item in ipairs(moduleList) do
            local btn = wm:CreateControlFromVirtual("KRT_TabBtn_" .. item.id, tabBar, "ZO_DefaultButton")
            btn:SetFont("ZoFontGameSmall")
            local isCurrent = (item.id == activeModuleId)
            btn:SetText(isCurrent and ("|cFFD700[ " .. item.tabName .. " ]|r") or ("|cCCCCCC" .. item.tabName .. "|r"))
            btn.data = { tooltipText = "Switch to " .. item.cleanName .. " settings" }
            btn:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
            btn:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
            btn:SetHandler("OnClicked", function()
                PlaySound(SOUNDS.TAB_CLICK)
                SwitchToModule(item.id)
            end)
            table.insert(tabButtons, btn)
        end

        tabBar:SetHandler("OnRectChanged", LayoutTabs)
        panel:SetHandler("OnRectChanged", LayoutTabs)
        LayoutTabs()
    end

    panelControl = LAM:RegisterAddonPanel(ADDON_NAME .. "_Panel", panelData)

    -- Hook submenu creation so non-active modules start hidden the exact microsecond they are built
    local origCreateSubmenu = LAMCreateControl.submenu
    LAMCreateControl.submenu = function(parent, submenuData, controlName)
        local subCtrl = origCreateSubmenu(parent, submenuData, controlName)
        local ref = controlName or (submenuData and submenuData.reference)
        if ref and ref:find("^KRT_Submenu_") then
            local modId = ref:gsub("^KRT_Submenu_", "")
            submenus[modId] = subCtrl

            if subCtrl.arrow then subCtrl.arrow:SetHidden(true) end
            if subCtrl.btmToggle then subCtrl.btmToggle:SetHidden(true) end
            if subCtrl.label then subCtrl.label:SetHandler("OnMouseUp", nil) end
            if subCtrl.icon then subCtrl.icon:SetHandler("OnMouseUp", nil) end

            if modId == activeModuleId then
                subCtrl:SetHidden(false)
                subCtrl.open = true
                if subCtrl.scroll then
                    subCtrl.scroll:SetResizeToFitDescendents(true)
                    subCtrl.scroll:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_XY)
                    subCtrl.scroll:SetResizeToFitPadding(5, 20)
                end
                subCtrl:ClearAnchors()
                subCtrl:SetAnchor(TOPLEFT, panelControl.scroll, TOPLEFT, 0, 0)
                subCtrl:SetAnchor(TOPRIGHT, panelControl.scroll, TOPRIGHT, 0, 0)
            else
                subCtrl:SetHidden(true)
                subCtrl.open = false
                if subCtrl.scroll then
                    subCtrl.scroll:SetResizeToFitDescendents(false)
                    subCtrl.scroll:SetHeight(0)
                end
            end
        end
        return subCtrl
    end

    -- Create tab bar immediately so it is rendered instantly with zero waiting
    InitializeTabBar(panelControl)

    LAM:RegisterOptionControls(ADDON_NAME .. "_Panel", options)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(openedPanel)
        if openedPanel == panelControl then
            LayoutTabs()
            SwitchToModule(activeModuleId)
        end
    end)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- IMPORTANT: pass empty defaults so ZO_SavedVars doesn't do nested merging for us
    KRT.sv = ZO_SavedVars:NewAccountWide("KwibusRandomThingsSV", 1, nil, {}, GetWorldName())

    -- Create/merge SV per module, then init module
    for _, mod in ipairs(KRT.modules) do
        local id = mod.id
        local defaults = mod.defaults
        if id and type(defaults) == "table" then
            if type(KRT.sv[id]) ~= "table" then
                KRT.sv[id] = ZO_DeepTableCopy(defaults)
            else
                KRT.DeepMergeDefaults(KRT.sv[id], defaults)
            end
        end

        if mod.Initialize then
            mod:Initialize()
        end
    end

    BuildUnifiedSettings()
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
