local this = InventoryCompanion
local layout = {}
this.PanelLayout = layout

local panels, order, positions, drag
local activeKey, activeProfile, ready, geometry
local sceneWindows = {
    { "inventory", "Layout_InventoryScene", "ZO_PlayerInventory" },
    { "bank", "Layout_BankScene", "ZO_PlayerBank" },
    { "houseBank", "Layout_HouseBankScene", "ZO_HouseBank" },
    { "guildBank", "Layout_GuildBankScene", "ZO_GuildBank" },
    { "furnitureVault", "Layout_FurnitureVaultScene", "ZO_FurnitureVault" },
    { "store", "Layout_MerchantScene", "ZO_PlayerInventory" },
    { "store_keyboard", "Layout_MerchantScene", "ZO_PlayerInventory" },
    { "fence_keyboard", "Layout_FenceScene", "ZO_PlayerInventory" },
}
local relatedWindows = {
    Layout_InventoryScene = { "ZO_PlayerInventory", "ZO_Character", "ZO_CharacterWindowStats",
        "ZO_PlayerProgress", "ZO_MainMenuCategoryBar" },
    Layout_BankScene = { "ZO_PlayerBank", "ZO_PlayerInventory", "ZO_PlayerBankMenu" },
    Layout_HouseBankScene = { "ZO_HouseBank", "ZO_PlayerInventory", "ZO_HouseBankMenu" },
    Layout_GuildBankScene = { "ZO_GuildBank", "ZO_PlayerInventory", "ZO_GuildBankMenu" },
    Layout_FurnitureVaultScene = { "ZO_FurnitureVault", "ZO_PlayerInventory", "ZO_FurnitureVaultMenu" },
    Layout_MerchantScene = { "ZO_PlayerInventory", "ZO_StoreWindow", "ZO_BuyBack",
        "ZO_RepairWindow", "ZO_StoreWindowMenu", "ZO_StorePanelTabContainer" },
    Layout_FenceScene = { "ZO_PlayerInventory", "ZO_Fence_Keyboard_WindowMenu" },
    Layout_SettingsScene = { "LAMAddonSettingsWindow", "ZO_OptionsWindow", "ZO_AddOns", "ZO_GameMenu_InGame" },
}
local rightBackdropWindows = {
    Layout_InventoryScene = "ZO_PlayerInventory",
    Layout_BankScene = "ZO_PlayerBank",
    Layout_HouseBankScene = "ZO_HouseBank",
    Layout_GuildBankScene = "ZO_GuildBank",
    Layout_FurnitureVaultScene = "ZO_FurnitureVault",
    Layout_MerchantScene = "ZO_PlayerInventory",
    Layout_FenceScene = "ZO_PlayerInventory",
}
local NORMAL = "Layout_NoScene"
local SNAP_DISTANCE = 12
local SNAP_GAP = 5
local SETTINGS_RIGHT_CLEARANCE = 8

local function CopyPosition(position)
    return { offsetX = position.offsetX, offsetY = position.offsetY }
end

local function Rectangle(control, position)
    return { x = position.offsetX, y = position.offsetY,
        width = control:GetWidth(), height = control:GetHeight() }
end

local function Intersects(a, b, padding)
    return a.x < b.x + b.width + padding and a.x + a.width + padding > b.x
        and a.y < b.y + b.height + padding and a.y + a.height + padding > b.y
end

local function Clamp(value, size, maximum)
    return math.max(0, math.min(value, math.max(0, maximum - size)))
end

-- Pure geometry entry point, also used by the isolated placement tests.
function layout.PlaceDisplaced(displaced, window, zos, retained, width, height)
    local obstacles = {}
    for _, rect in ipairs(zos) do obstacles[#obstacles + 1] = rect end
    for _, rect in ipairs(retained) do obstacles[#obstacles + 1] = rect end
    local function TrySide(right)
        local result, cursor = {}, math.max(0, window.y)
        for _, panel in ipairs(displaced) do
            local x = right and window.x + window.width + 5 or window.x - 5 - panel.width
            local y = cursor
            if x < 0 or x + panel.width > width then return nil end
            while true do
                local nextY = y
                local rect = { x = x, y = y, width = panel.width, height = panel.height }
                for _, obstacle in ipairs(obstacles) do
                    if Intersects(rect, obstacle, 5) then
                        nextY = math.max(nextY, obstacle.y + obstacle.height + 5)
                    end
                end
                if nextY == y then break end
                y = nextY
            end
            if y + panel.height > height then return nil end
            result[panel.key] = { offsetX = x, offsetY = y }
            cursor = y + panel.height + 5
        end
        return result
    end
    local result = TrySide(true) or TrySide(false)
    if result then return result end
    local groupWidth, groupHeight = 0, 0
    for index, panel in ipairs(displaced) do
        groupWidth = math.max(groupWidth, (index - 1) * 20 + panel.width)
        groupHeight = math.max(groupHeight, (index - 1) * 20 + panel.height)
    end
    local candidates = {
        { window.x + window.width + 5, window.y },
        { window.x - 5 - groupWidth, window.y },
        { width - groupWidth, 0 }, { 0, 0 },
        { width - groupWidth, height - groupHeight }, { 0, height - groupHeight },
    }
    local first, firstZosClear
    for _, candidate in ipairs(candidates) do
        local baseX = Clamp(candidate[1], groupWidth, width)
        local baseY = Clamp(candidate[2], groupHeight, height)
        local clear = true
        result = {}
        for index, panel in ipairs(displaced) do
            local x = Clamp(baseX + (index - 1) * 20, panel.width, width)
            local y = Clamp(baseY + (index - 1) * 20, panel.height, height)
            result[panel.key] = { offsetX = x, offsetY = y }
            local rect = { x = x, y = y, width = panel.width, height = panel.height }
            for _, obstacle in ipairs(zos) do
                if Intersects(rect, obstacle, 5) then clear = false end
            end
        end
        first = first or result
        if clear then
            firstZosClear = firstZosClear or result
            for _, panel in ipairs(displaced) do
                local position = result[panel.key]
                local bounds = { x = position.offsetX, y = position.offsetY, width = panel.width, height = panel.height }
                for _, obstacle in ipairs(retained) do
                    if Intersects(bounds, obstacle, 5) then clear = false end
                end
            end
        end
        if clear then return result end
    end
    return firstZosClear or first
end

function layout.Initialize()
    panels, order, positions, drag = {}, {}, {}, nil
    activeKey, activeProfile, ready = NORMAL, this.GetSettingsProfile(), false
    geometry = nil
end

function layout.IsNormalContext()
    return activeKey == NORMAL
end

function layout.RegisterPanel(key, control)
    if panels[key] then
        assert(panels[key] == control, "Panel registered with a different control: " .. key)
        return
    end
    panels[key] = control
    order[#order + 1] = key
    positions[key] = CopyPosition(this.GetPanelLayout(key, NORMAL))
    control:SetHandler("OnMoveStart", function() layout.OnMoveStart(key) end)
    control:SetHandler("OnMoveStop", function() layout.OnMoveStop(key) end)
    layout.ApplyPanelPosition(key)
end

function layout.ApplyPanelPosition(key)
    local control, position = panels[key], positions[key]
    if control:GetLeft() == position.offsetX and control:GetTop() == position.offsetY then return end
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, position.offsetX, position.offsetY)
end

local function NormalVisible(key)
    if key == "Tracker" then return this.GetPanelSettings(key).showTrackedItemsPanel end
    if key == "Currency" then
        return this.HasVisibleCurrencyResources() or this.HasVisibleCapacityResources()
    end
    if not this.GetProgressBarSettings(key).showBar then return false end
    for _, resource in ipairs(this.GetProgressBarResources()) do
        if resource.key == key then return this.GetProgressBarResourceValues(resource) ~= nil end
    end
    return false
end

local function ResolveContext()
    local editor, window = this.IsEditorWindowOpen()
    if editor then return "Layout_EditorScene", window end
    -- This feature deliberately does not repair or extend gamepad scene handling.
    if IsInGamepadPreferredMode() then return NORMAL end
    if this.state.isCurrencySettingsOpen and SCENE_MANAGER:IsShowing("gameMenuInGame") then
        for _, name in ipairs(relatedWindows.Layout_SettingsScene) do
            local control = _G[name]
            if control and not control:IsHidden() then return "Layout_SettingsScene", control end
        end
    end
    for _, entry in ipairs(sceneWindows) do
        if SCENE_MANAGER:IsShowing(entry[1]) then
            for _, name in ipairs(relatedWindows[entry[2]] or { entry[3] }) do
                local control = _G[name]
                if control and not control:IsHidden() then return entry[2], control end
            end
        end
    end
    return NORMAL
end

local function CollectObstacles(key, window)
    local obstacles = {}
    local rightBackdropWindow = rightBackdropWindows[key]
    local function Add(control)
        local rect = Rectangle(control, { offsetX = control:GetLeft(), offsetY = control:GetTop() })
        if rightBackdropWindow and (control == _G[rightBackdropWindow] or control == ZO_PlayerInventory) then
            local background, texture = ZO_SharedRightPanelBackground, ZO_SharedRightPanelBackgroundLeft
            if background and not background:IsHidden() and texture and not texture:IsHidden() then
                -- Use the backdrop's left edge, not its vertically padded texture bounds.
                local left = math.min(rect.x, texture:GetLeft())
                rect.width = rect.width + rect.x - left
                rect.x = left
            end
        end
        if key == "Layout_SettingsScene" and control == LAMAddonSettingsWindow then
            rect.width = rect.width + SETTINGS_RIGHT_CLEARANCE
        end
        rect.control = control
        obstacles[#obstacles + 1] = rect
        return rect
    end
    Add(window)
    if relatedWindows[key] then
        for _, name in ipairs(relatedWindows[key]) do
            local control = _G[name]
            if control and control ~= window and not control:IsHidden() then
                Add(control)
            end
        end
    end
    -- Addon settings use inline controls, not the full-width scene footer.
    if key ~= "Layout_SettingsScene" and not IsInGamepadPreferredMode() then
        local strip = ZO_KeybindStripControl
        local backdrop, texture = ZO_KeybindStripMungeBackground, ZO_KeybindStripMungeBackgroundTexture
        local footer
        if strip and not strip:IsHidden() then footer = Add(strip) end
        if backdrop and not backdrop:IsHidden() and texture and not texture:IsHidden() then
            -- The texture extends above the keybind row and its background container.
            if not footer then footer = Add(backdrop) end
            local top = math.min(footer.y, texture:GetTop())
            footer.height = footer.height + footer.y - top
            footer.y = top
        end
        if footer then footer.isFooter = true end
    end
    return obstacles
end

local function SnapDrop(key, position)
    local context, window = ResolveContext()
    if context ~= activeKey then return position end
    local obstacles = window and CollectObstacles(context, window) or {}
    local rect = Rectangle(panels[key], position)
    local width, height = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    local targets, overlaps = {}, {}
    for _, other in ipairs(order) do
        local control = panels[other]
        if other ~= key and not control:IsHidden() then
            local target = Rectangle(control, { offsetX = control:GetLeft(), offsetY = control:GetTop() })
            targets[#targets + 1] = target
            if Intersects(rect, target, 0) then overlaps[#overlaps + 1] = target end
        end
    end
    local clearingOverlap = #overlaps > 0
    local best, bestPriority, bestDistance = position, 0, math.huge
    local function Consider(dx, dy, priority)
        local distance = dx * dx + dy * dy
        if (distance == 0 and priority == 1)
            or (not clearingOverlap and distance > SNAP_DISTANCE ^ 2) or priority < bestPriority
            or (priority == bestPriority and distance >= bestDistance) then return end
        local candidate = { x = rect.x + dx, y = rect.y + dy, width = rect.width, height = rect.height }
        if candidate.x < 0 or candidate.y < 0 or candidate.x + rect.width > width
            or candidate.y + rect.height > height then return end
        for _, obstacle in ipairs(obstacles) do
            if Intersects(candidate, obstacle, 0) then return end
        end
        for _, target in ipairs(targets) do
            if Intersects(candidate, target, 0) then return end
        end
        best = distance == 0 and position or { offsetX = candidate.x, offsetY = candidate.y }
        bestPriority, bestDistance = priority, distance
    end
    for _, target in ipairs(clearingOverlap and overlaps or targets) do
        local x, y = target.x, target.y
        local right, bottom = x + target.width, y + target.height
        local dockX = { x - SNAP_GAP - rect.width - rect.x, right + SNAP_GAP - rect.x }
        local dockY = { y - SNAP_GAP - rect.height - rect.y, bottom + SNAP_GAP - rect.y }
        if clearingOverlap then
            -- For an overlapping drop, choose the shortest clear move, without realigning the other axis.
            for _, dx in ipairs(dockX) do Consider(dx, 0, 1) end
            for _, dy in ipairs(dockY) do Consider(0, dy, 1) end
        else
            local alignX = { x - rect.x, right - rect.x - rect.width }
            local alignY = { y - rect.y, bottom - rect.y - rect.height }
            local gapX = math.max(x - rect.x - rect.width, rect.x - right, 0)
            local gapY = math.max(y - rect.y - rect.height, rect.y - bottom, 0)
            if gapY <= SNAP_DISTANCE then
                for _, dx in ipairs(alignX) do Consider(dx, 0, 1) end
            end
            if gapX <= SNAP_DISTANCE then
                for _, dy in ipairs(alignY) do Consider(0, dy, 1) end
            end
            for _, dx in ipairs(dockX) do
                if gapY == 0 then Consider(dx, 0, 2) end
                for _, dy in ipairs(alignY) do Consider(dx, dy, 3) end
            end
            for _, dy in ipairs(dockY) do
                if gapX == 0 then Consider(0, dy, 2) end
                for _, dx in ipairs(alignX) do Consider(dx, dy, 3) end
            end
        end
    end
    return best
end

local function CaptureGeometry(obstacles)
    local snapshot = { GuiRoot:GetWidth(), GuiRoot:GetHeight() }
    for _, rect in ipairs(obstacles) do
        for _, value in ipairs({ rect.control, rect.x, rect.y, rect.width, rect.height }) do
            snapshot[#snapshot + 1] = value
        end
    end
    for _, key in ipairs(order) do
        if NormalVisible(key) then
            for _, value in ipairs({ key, panels[key]:GetWidth(), panels[key]:GetHeight() }) do
                snapshot[#snapshot + 1] = value
            end
        end
    end
    return snapshot
end

local function GeometryChanged(snapshot)
    if geometry == nil or #geometry ~= #snapshot then return true end
    for index, value in ipairs(snapshot) do
        if geometry[index] ~= value then return true end
    end
    return false
end

local function CorrectPositions(obstacles, onlyKey)
    local retained, displaced = {}, {}
    local width, height = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    local footer
    for _, obstacle in ipairs(obstacles) do
        if obstacle.isFooter then footer = obstacle end
    end
    -- The keyboard keybind strip spans the bottom of GuiRoot, including between its labels.
    if footer then height = math.min(height, footer.y) end
    if onlyKey then
        for _, key in ipairs(order) do
            if key ~= onlyKey and NormalVisible(key) then
                retained[#retained + 1] = Rectangle(panels[key], positions[key])
            end
        end
    end
    for _, panelKey in ipairs(order) do
        if (onlyKey == nil or panelKey == onlyKey) and NormalVisible(panelKey) then
            local rect = Rectangle(panels[panelKey], positions[panelKey])
            local blocked = rect.x < 0 or rect.y < 0
                or rect.x + rect.width > width or rect.y + rect.height > height
            for _, obstacle in ipairs(obstacles) do
                if Intersects(rect, obstacle, 0) then blocked = true end
            end
            if not blocked then
                retained[#retained + 1] = rect
            else
                rect.key = panelKey
                displaced[#displaced + 1] = rect
            end
        end
    end
    if footer then
        local remaining = {}
        for _, rect in ipairs(displaced) do
            local y = height - rect.height - SNAP_GAP
            local candidate = { x = rect.x, y = y, width = rect.width, height = rect.height }
            local clear = Intersects(rect, footer, 0) and y >= 0
                and rect.x >= 0 and rect.x + rect.width <= width
            if clear then
                for _, obstacle in ipairs(obstacles) do
                    if Intersects(candidate, obstacle, SNAP_GAP) then clear = false; break end
                end
            end
            if clear then
                for _, panel in ipairs(retained) do
                    if Intersects(candidate, panel, SNAP_GAP) then clear = false; break end
                end
            end
            if clear then
                positions[rect.key] = { offsetX = rect.x, offsetY = y }
                retained[#retained + 1] = candidate
            else
                remaining[#remaining + 1] = rect
            end
        end
        displaced = remaining
    end
    if #displaced > 0 then
        local placed = layout.PlaceDisplaced(displaced, obstacles[1], obstacles, retained, width, height)
        for panelKey, position in pairs(placed) do positions[panelKey] = position end
    end
    for _, panelKey in ipairs(order) do layout.ApplyPanelPosition(panelKey) end
end

function layout.EnterContext(key, window)
    if drag then
        local canceled = drag
        drag = nil
        canceled.control:StopMoving()
    end
    activeKey, activeProfile = key, this.GetSettingsProfile()
    local ranked = { "Tracker", "Currency" }
    for _, resource in ipairs(this.GetProgressBarResources()) do ranked[#ranked + 1] = resource.key end
    order = {}
    for _, panelKey in ipairs(ranked) do
        if panels[panelKey] then order[#order + 1] = panelKey end
    end
    for _, panelKey in ipairs(order) do
        local saved
        if key ~= NORMAL then saved = this.GetPanelLayout(panelKey, key, GetCurrentCharacterId()) end
        positions[panelKey] = CopyPosition(saved or this.GetPanelLayout(panelKey, NORMAL))
    end
    geometry = nil
    if key ~= NORMAL then
        local obstacles = CollectObstacles(key, window)
        CorrectPositions(obstacles)
        geometry = CaptureGeometry(obstacles)
    else
        for _, panelKey in ipairs(order) do layout.ApplyPanelPosition(panelKey) end
    end
end

function layout.UpdateVisibility()
    if not ready then return end
    local inCutscene = ZO_CompassFrame and ZO_CompassFrame:IsHidden()
    local supported = activeKey ~= NORMAL
    local gamepad = IsInGamepadPreferredMode()
    local otherSettings = not this.state.isCurrencySettingsOpen and SCENE_MANAGER:IsShowing("gameMenuInGame")
    -- Keep observing input mode while the currency settings preview can appear.
    local needsTicker = this.state.isCurrencySettingsOpen == true
    for _, key in ipairs(order) do
        local visible = NormalVisible(key)
        needsTicker = needsTicker or visible
        local exception = supported
        if gamepad then
            exception = key == "Tracker" and
                (this.IsEditorWindowOpen() or this.Utils.IsItemInteractionActive())
            if key == "Currency" and this.state.isCurrencySettingsOpen then visible, exception = true, true end
        end
        panels[key]:SetHidden(not (visible and not otherSettings and (not inCutscene or exception)))
    end
    this.SetVisibilityTickerNeeded(needsTicker)
end

function layout.UpdateContext()
    if not ready then return end
    local key, window = ResolveContext()
    if key ~= activeKey or this.GetSettingsProfile() ~= activeProfile then
        layout.EnterContext(key, window)
    elseif key ~= NORMAL and not drag then
        local obstacles = CollectObstacles(key, window)
        local snapshot = CaptureGeometry(obstacles)
        if GeometryChanged(snapshot) then
            CorrectPositions(obstacles)
            geometry = snapshot
        end
    end
    layout.UpdateVisibility()
end

function layout.CompleteInitialization()
    ready = true
    local key, window = ResolveContext()
    layout.EnterContext(key, window)
    layout.UpdateVisibility()
end

function layout.OnProfileChanged()
    if not ready then return end
    local key, window = ResolveContext()
    layout.EnterContext(key, window)
    layout.UpdateVisibility()
end

function layout.OnMoveStart(key)
    drag = { key = key, control = panels[key], profile = this.GetSettingsProfile(), layout = activeKey }
end

function layout.OnMoveStop(key)
    -- StopMoving during a context change cancels a user drag before restoring.
    if not drag then return end
    assert(drag.key == key and drag.profile == this.GetSettingsProfile() and drag.layout == activeKey,
        "Panel drag context changed")
    local control = panels[key]
    local dropped = { offsetX = control:GetLeft(), offsetY = control:GetTop() }
    local position = not IsShiftKeyDown() and SnapDrop(key, dropped) or dropped
    this.SavePanelLayout(key, activeKey, GetCurrentCharacterId(), position.offsetX, position.offsetY)
    positions[key] = position
    drag = nil
    if position ~= dropped then layout.ApplyPanelPosition(key) end
end

function layout.ResetPanelPosition(key)
    this.ResetPanelLayouts(key)
    positions[key] = CopyPosition(this.GetPanelLayout(key, NORMAL))
    local context, window = ResolveContext()
    if context ~= NORMAL then
        CorrectPositions(CollectObstacles(context, window), key)
    end
    layout.ApplyPanelPosition(key)
end
