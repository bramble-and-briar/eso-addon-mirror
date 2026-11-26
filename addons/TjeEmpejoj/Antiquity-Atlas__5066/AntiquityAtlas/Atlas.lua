local A = AntiquityAtlas
local W = WINDOW_MANAGER
local BODY_FONT = "ZoFontGame"
local BOLD_FONT = "ZoFontWinH4"
local SMALL_FONT = "ZoFontGameSmall"
local colors = { [0] = "AAAAAA", "79C870", "73B9ED", "BE8DF2", "E8C563", "ED9B65" }
local function colored(text, quality) return "|c" .. (colors[quality] or "FFFFFF") .. text .. "|r" end
local function panel(parent, x, y, width, height)
    local c = W:CreateControl(nil, parent, CT_BACKDROP)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(width, height)
    c:SetCenterColor(0.035, 0.032, 0.025, 0.96)
    c:SetEdgeColor(0.36, 0.33, 0.24, 0.8)
    c:SetEdgeTexture(nil, 1, 1, 1)
    c:SetMouseEnabled(false)
    return c
end
local function label(parent, text, x, y, width, font)
    local c = W:CreateControl(nil, parent, CT_LABEL)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetWidth(width)
    c:SetFont(font or BODY_FONT)
    c:SetMouseEnabled(false)
    c:SetText(text)
    return c
end
local function button(parent, text, x, y, width, callback)
    local c = W:CreateControlFromVirtual(nil, parent, "ZO_DefaultButton")
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(width, 30)
    c:SetFont(BOLD_FONT)
    c:SetText(text)
    c:SetHandler("OnClicked", callback)
    return c
end
local function icon(parent, x, y, size)
    local c = W:CreateControl(nil, parent, CT_TEXTURE)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(size, size)
    c:SetMouseEnabled(false)
    return c
end
local function dropdown(parent, name, x, y, width, options, selected, onChange)
    local control = W:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(width, 30)
    local combo = ZO_ComboBox_ObjectFromContainer(control)
    -- Virtual initialization caches the template width before SetDimensions.
    combo.m_containerWidth = width
    -- The native dropdown resolves its font through _G to measure entry widths.
    -- A custom font descriptor here produces a nil font object and clipped menus.
    combo:SetFont("ZoFontGame")
    combo:SetSelectedItemFont(SMALL_FONT)
    combo:SetSortsItems(false)
    for index, text in ipairs(options) do
        local value = index
        combo:AddItem(combo:CreateItemEntry(text, function() onChange(value, text) end))
    end
    combo:SetSelectedItem(options[selected or 1])
    return combo
end
function A.ApplyScale(value)
    local maximum = math.min(1.5, GuiRoot:GetWidth() / 1140, GuiRoot:GetHeight() / 750)
    local minimum = math.min(0.55, maximum)
    local scale = math.max(minimum, math.min(maximum, tonumber(value) or 1))
    A.settings.scale = scale
    A.window:SetScale(scale)
    if A.content then A.content:SetScale(scale); A.window:SetScale(1); A.window:SetDimensions(1120 * scale, 730 * scale) end
    if A.list then A.Render() end
end
function A.UpdateListPadding()
    -- Native scroll-list extents use GetHeight(), while row offsets are in the
    -- scaled parent's local units. Reserve the difference so the last row can
    -- clear the clipped viewport at enlarged UI scales.
    local height = A.list:GetHeight()
    local scale = A.list:GetScale()
    local padding = 16 + math.ceil(math.max(0, height - height / scale))
    ZO_ScrollList_UpdateDataTypeHeight(A.list, 2, padding)
end
function A.ShowPartTooltip(owner, part, group)
    if not part then return end
    A.HideRewardTooltip()
    A.tooltipTarget = owner
    InitializeTooltip(InformationTooltip, owner, TOPRIGHT, 8, 0, TOPLEFT)
    InformationTooltip:SetWidth(480)
    InformationTooltip:AddLine(colored(part.name, part.quality), BOLD_FONT)
    InformationTooltip:AddLine(A.PartStatus(part, group), BODY_FONT)
    local function section(title)
        ZO_Tooltip_AddDivider(InformationTooltip)
        InformationTooltip:AddLine(title, "ZoFontWinH4", 0.77, 0.72, 0.56)
    end
    local function body(text, font)
        InformationTooltip:AddLine(text, font or BODY_FONT, 0.9, 0.88, 0.82, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT)
    end
    section(A.L("Место получения"))
    body(A.DisplayName(part.findZone), BOLD_FONT)
    local sourceText = A.ExpandSourceText(part.source)
    body(sourceText)
    if part.id == 473 then
        body(A.SourceLabel("Ordinary sea adders along the coasts of High Isle and Summerset. No fixed spawn coordinates are bundled; left click chooses a region.", "Обычные морские змеи вдоль побережий Высокого острова и Саммерсета. Точные точки появления не записаны; ЛКМ позволяет выбрать регион."), SMALL_FONT)
    end
    local detail = A.SourceDetail(part)
    if detail and A.IsBossSource(part) then
        body(A.SourceLabel("Boss: ", "Босс: ") .. A.DisplayName(detail.boss))
    end
    local action=A.SourceModifierAction(part)
    local targets = A.ResolveSourceZones(part)
    for _, target in ipairs(targets) do
        local name = A.ZoneName(target.id)
        if not name or name == "" then name = target.name or tostring(target.id) end
        local kind = target.worldBoss and A.SourceLabel("World boss: ", "Мировой босс: ")
            or target.region and A.SourceLabel("Other sources in region: ", "Другие источники в регионе: ")
            or A.SourceLabel("Instance: ", "Подземелье: ")
        name = A.DisplayName(name)
        -- The source already describes the dungeon and its loot. Keep additional
        -- destinations and world-boss details, but do not repeat that instance.
        local mentioned = name ~= "" and A.Lower(sourceText):find(A.Lower(name), 1, true)
        if target.worldBoss or target.region or not mentioned then
            body(kind .. name)
        end
    end
    section(A.L("Область раскопок"))
    body(A.DisplayName(part.zone), BOLD_FONT)
    section(A.L("Управление"))
    body(A.SourceClickHint(part), SMALL_FONT)
    if action=="boss" then
        body(A.SourceLabel("Shift + left click: instance entrance or source map.", "Shift + ЛКМ: вход в подземелье или карта источника."), SMALL_FONT)
    end
end
function A.HideRewardTooltip()
    ClearTooltip(ItemTooltip)
    ClearTooltip(InformationTooltip)
    if ZO_Rewards_Shared_OnMouseExit and A.rewardTooltipOwner then
        ZO_Rewards_Shared_OnMouseExit(A.rewardTooltipOwner)
    end
    A.rewardTooltipOwner = nil
    A.tooltipTarget = nil
end
function A.ShowRewardTooltip(owner, group)
    A.HideRewardTooltip()
    if not group then return end
    A.rewardTooltipOwner = owner
    A.tooltipTarget = owner
    -- Let the game's item tooltip render stats, enchantment, trait and set bonuses.
    if group.link then
        InitializeTooltip(ItemTooltip, owner, TOPRIGHT, 8, 0, TOPLEFT)
        ItemTooltip:SetLink(group.link)
        return
    end
    local data = group.setId > 0
        and A.Method(ANTIQUITY_DATA_MANAGER, "GetAntiquitySetData", group.setId)
        or A.Method(ANTIQUITY_DATA_MANAGER, "GetAntiquityData", group.parts[1].id)
    if data and ZO_LayoutAntiquityRewardTooltip_Keyboard then
        ZO_LayoutAntiquityRewardTooltip_Keyboard(data, owner, RIGHT, LEFT)
    end
end
function A.TooltipExit(owner)
    zo_callLater(function()
        if A.tooltipTarget == owner and not MouseIsOver(owner) then A.HideRewardTooltip() end
    end, 1)
end
function A.BindRewardTooltip(control, getGroup, onClick)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function(self) A.ShowRewardTooltip(self, getGroup()) end)
    control:SetHandler("OnMouseExit", A.TooltipExit)
    if onClick then
        control:SetHandler("OnMouseUp", function(_, mouseButton)
            if mouseButton == MOUSE_BUTTON_INDEX_LEFT then onClick() end
        end)
    end
end
function A.Refresh()
    local rewards, message = A.Read()
    if not rewards then d(message); return end
    A.Render()
end
function A.PartRank(part, group)
    if part.have then return 1 end
    if part.current or (#group.parts == 1 and part.dug > 0) then return 3 end
    return 2
end
local sourceZones = {
    [101012] = { 1027, 1011 }, [101013] = { 101, 103 },
    [101014] = { 181, 584 }, [101015] = { 1207, 1160 },
    [101017] = { 1383, 1318 }, [101018] = { 1413, 1414 },
}
local HIGHLIGHT_PIN = "ANTIQUITY_ATLAS_SOURCE_PIN"
function A.FindSourcePOI(zoneId, part, target)
    local zi, pi = A.SourcePOIIndices(target)
    if not zi or not pi or type(GetPOIMapInfo) ~= "function" then return end
    local x, y, _, _, shown = GetPOIMapInfo(zi, pi)
    if shown and x and y and x > 0 and x < 1 and y > 0 and y < 1 then
        local name = A.Call(GetPOIInfo, zi, pi) or target.name
        return {name = name, x = x, y = y, kind = target.worldBoss and "boss" or "entrance"}
    end
end
function A.ClearSourceHighlight()
    A.sourceHighlight = nil
    EVENT_MANAGER:UnregisterForUpdate("AntiquityAtlasSourcePulse")
    if A.highlightRegistered then ZO_WorldMap_RefreshCustomPinsOfType(HIGHLIGHT_PIN) end
end
function A.InitSourceHighlight()
    if type(ZO_WorldMap_AddCustomPin) ~= "function" then return end
    ZO_WorldMap_AddCustomPin(HIGHLIGHT_PIN, function(manager)
        local target = A.sourceHighlight
        if target and target.visible and A.Call(GetCurrentMapId) == target.mapId then
            manager:CreatePin(_G[HIGHLIGHT_PIN], target.name, target.x, target.y)
        end
    end, nil, { level = 100, size = 48, texture = function()
        return A.sourceHighlight and A.sourceHighlight.icon or "/esoui/art/icons/icon_missing.dds"
    end })
    ZO_WorldMap_SetCustomPinEnabled(_G[HIGHLIGHT_PIN], true)
    A.highlightRegistered = true
end
function A.FindSourcePoint(zoneId, part, target)
    if target and target.boss then
        if A.Call(GetCurrentMapId) == target.mapId and A.MapTextureKey(A.Call(GetMapTileTexture, 1)) == target.key then
            return {name = target.name, x = target.x, y = target.y, kind = "boss"}
        end
        return
    end
    if not target or target.region or zoneId ~= target.parent then return end
    return A.FindSourcePOI(zoneId, part, target)
end
function A.HighlightSource(zoneId, part, target)
    A.ClearSourceHighlight()
    local poi = A.FindSourcePoint(zoneId, part, target)
    if not poi then
        if target and not target.region and A.InstanceMapZone(target) == target.id then
            d("Antiquity Atlas: " .. A.SourceLabel("instance map opened; entrance coordinates unavailable: ", "карта инстанса открыта; координаты входа отсутствуют: ") .. (target.name or ""))
        elseif target and not target.region then
            d("Antiquity Atlas: " .. A.SourceLabel("source map opened; entrance coordinates unavailable in the client: ", "карта источника открыта; координаты входа недоступны в клиенте: ") .. (target.name or ""))
        end
        return
    end
    if type(PingMap) == "function" and MAP_PIN_TYPE_PLAYER_WAYPOINT and MAP_TYPE_LOCATION_CENTERED then
        PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, poi.x, poi.y)
    end
    if type(ZO_WorldMap_PanToNormalizedPosition) == "function" then
        ZO_WorldMap_PanToNormalizedPosition(poi.x, poi.y)
    end
    if not A.highlightRegistered then return end
    poi.mapId, poi.icon, poi.visible = A.Call(GetCurrentMapId), part.icon, true
    A.sourceHighlight = poi
    local pulses = 0
    ZO_WorldMap_RefreshCustomPinsOfType(HIGHLIGHT_PIN)
    EVENT_MANAGER:RegisterForUpdate("AntiquityAtlasSourcePulse", 500, function()
        pulses = pulses + 1
        if pulses >= 24 or A.Call(GetCurrentMapId) ~= poi.mapId
            or SCENE_MANAGER:GetScene("worldMap"):GetState() ~= SCENE_SHOWN then
            A.ClearSourceHighlight()
            return
        end
        poi.visible = not poi.visible
        ZO_WorldMap_RefreshCustomPinsOfType(HIGHLIGHT_PIN)
    end)
    d("Antiquity Atlas: " .. A.SourceLabel(poi.kind == "boss" and "boss position: " or "source entrance marker: ", poi.kind == "boss" and "Позиция босса: " or "Маркер входа: ") .. poi.name)
end
function A.OpenZoneMap(zoneId, part, source, target)
    local mapIndex, mapId = A.ResolveZoneMap(zoneId)
    if target and (target.boss or target.resources) and target.mapId then mapIndex, mapId = nil, target.mapId end
    if not ((mapIndex and mapIndex > 0 and type(ZO_WorldMap_SetMapByIndex) == "function")
        or (mapId and mapId > 0 and type(SetMapToMapId) == "function")) then
        d(A.L("Antiquity Atlas: отдельная карта этой зоны недоступна. Источник: ") .. (part.findZone or ""))
        return
    end
    A.HideRewardTooltip()
    SCENE_MANAGER:HideTopLevel(A.window)
    A.mapRequest = (A.mapRequest or 0) + 1
    local request = A.mapRequest
    local scene = SCENE_MANAGER:GetScene("worldMap")
    local function applyMap()
        -- Wait until scene initialization (including player-map reset) has finished.
        zo_callLater(function()
            if request ~= A.mapRequest or scene:GetState() ~= SCENE_SHOWN then return end
            local result
            if mapIndex and mapIndex > 0 and type(ZO_WorldMap_SetMapByIndex) == "function" then
                result = ZO_WorldMap_SetMapByIndex(mapIndex)
            else
                result = SetMapToMapId(mapId)
                CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
            end
            if result == SET_MAP_RESULT_FAILED then
                d(A.L("Antiquity Atlas: не удалось открыть выбранную карту."))
                return
            end
            if source then
                -- Map/POI coordinates must be read after the new map has finished refreshing.
                zo_callLater(function()
                    if request == A.mapRequest and scene:GetState() == SCENE_SHOWN then
                        if target and target.resources then A.ShowResourcePoints(part) else A.HighlightSource(zoneId, part, target) end
                    end
                end, 150)
            end
            if not source then
                local data = A.Method(ANTIQUITY_DATA_MANAGER, "GetAntiquityData", part.id)
                if A.Method(data, "HasDiscoveredDigSites") and WORLD_MAP_MANAGER then
                    WORLD_MAP_MANAGER:ShowAntiquityOnMap(part.id)
                end
            end
        end, 50)
    end
    if A.mapSceneCallback then scene:UnregisterCallback("StateChange", A.mapSceneCallback) end
    if scene:GetState() == SCENE_SHOWN then
        applyMap()
    else
        local callback
        callback = function(_, state)
            if state == SCENE_SHOWN then
                scene:UnregisterCallback("StateChange", callback)
                A.mapSceneCallback = nil
                applyMap()
            end
        end
        A.mapSceneCallback = callback
        scene:RegisterCallback("StateChange", callback)
        ZO_WorldMap_ShowWorldMap()
    end
    SCENE_MANAGER:HideTopLevel(A.window)
end
function A.OpenPartMap(part, source, owner, entranceOnly)
    if not part then return end
    if source and A.IsResourceSource(part) then return A.OpenResourceMap(part,owner) end
    if source and not entranceOnly and A.IsBossSource(part) and A.OpenBossMap(part,owner) then return end
    A.ClearResourceOverlay()
    if source then
        if A.PendingInstanceSources[part.id] then
            d("Antiquity Atlas: exact instance data not yet available: " .. A.PendingInstanceSources[part.id])
            return
        end
        local targets = A.ResolveSourceZones(part)
        if #targets == 1 then
            A.OpenZoneMap(A.InstanceMapZone(targets[1]), part, true, targets[1])
            return
        elseif #targets > 1 then
            ClearMenu()
            for _, target in ipairs(targets) do
                local selected = target
                local name = A.ZoneName(selected.id)
                if not name or name == "" then name = selected.name or tostring(selected.id) end
                if selected.region then name = A.SourceLabel("Other sources: ", "Другие источники: ") .. name end
                AddMenuItem(zo_strformat("<<C:1>>", name), function() A.OpenZoneMap(A.InstanceMapZone(selected), part, true, selected) end)
            end
            ShowMenu(owner or A.window)
            return
        end
    end
    local zoneId = source and part.findZoneId or part.zoneId
    local zones = source and sourceZones[zoneId]
    if zones then
        ClearMenu()
        for _, id in ipairs(zones) do
            local selectedZone = id
            AddMenuItem(A.ZoneName(id), function()
                A.OpenZoneMap(selectedZone, part, true)
            end)
        end
        ShowMenu(owner or A.window)
    else
        A.OpenZoneMap(zoneId, part, source)
    end
end
function A.PaintCard(card, group)
    card.data = group
    local sortedParts = {}
    for _, part in ipairs(group.parts) do table.insert(sortedParts, part) end
    table.sort(sortedParts, function(a, b)
        local ar, br = A.PartRank(a, group), A.PartRank(b, group)
        if ar ~= br then return ar < br end
        return a.id < b.id
    end)
            card.image:SetTexture(group.icon)
            card.title:SetText(colored(group.name, group.quality))
            card.kind:SetText(group.kind .. A.L(" · Собрано: ") .. group.minimum)
            card.progress:SetText(string.format(A.L("Части: %d/%d\nЗацепок: %d"), #group.parts == 1 and (group.dug > 0 and 1 or 0) or group.current, #group.parts, group.have))
            for partIndex, slot in ipairs(card.parts) do
                local part = sortedParts[partIndex]
                slot.part = part
                slot:SetHidden(not part)
                if part then
                    slot.image:SetTexture(part.icon or group.icon)
                    local recovered = part.current or (#group.parts == 1 and part.dug > 0)
                    slot.image:SetAlpha((recovered or part.have) and 1 or 0.65)
                    if recovered then
                        slot.background:SetEdgeColor(0.4, 1, 0.55, 1)
                        slot.background:SetCenterColor(0.06, 0.22, 0.09, 1)
                        slot.status:SetText(part.have and A.L("|cA0FFAFВ+З|r") or A.L("|cA0FFAFВык.|r"))
                    elseif part.have then
                        slot.background:SetEdgeColor(0.3, 0.9, 1, 1)
                        slot.background:SetCenterColor(0.04, 0.18, 0.24, 1)
                        slot.status:SetText(A.L("|c86E8FFЕсть|r"))
                    else
                        slot.background:SetEdgeColor(0.65, 0.65, 0.65, 1)
                        slot.background:SetCenterColor(0.1, 0.1, 0.1, 1)
                        slot.status:SetText(A.L("|cDDDDDDНет|r"))
                    end
                end
            end
            card.background:SetCenterColor(group.key == A.selectedKey and 0.16 or 0.025, group.key == A.selectedKey and 0.14 or 0.023, group.key == A.selectedKey and 0.08 or 0.018, 0.94)
            card.background:SetEdgeColor(group.key == A.selectedKey and 0.80 or 0.30, group.key == A.selectedKey and 0.65 or 0.28, 0.20, 0.85)
end
function A.CreateCard(card)
        card:SetMouseEnabled(true)
        card.background = panel(card, 0, 0, 1048, 124)
        local function selectCard()
            if card.data then
                A.selectedKey = card.data.key
                A.Render()
            end
        end
        card:SetHandler("OnClicked", selectCard)
        card.rewardHit = W:CreateControl(nil, card, CT_BUTTON)
        card.rewardHit:SetAnchor(TOPLEFT, card, TOPLEFT, 10, 10)
        card.rewardHit:SetDimensions(58, 58)
        card.rewardHit:SetDrawLayer(DL_OVERLAY)
        card.image = icon(card.rewardHit, 0, 0, 58)
        card.title = label(card, "", 82, 7, 780, BOLD_FONT)
        card.title:SetHeight(24)
        card.title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        A.BindRewardTooltip(card.rewardHit, function() return card.data end, selectCard)
        A.BindRewardTooltip(card.title, function() return card.data end, selectCard)
        card.kind = label(card, "", 82, 31, 780, SMALL_FONT)
        card.progress = label(card, "", 884, 10, 154, SMALL_FONT)
        card.parts = {}
        local spacing = math.min(56, 956 / A.maxParts)
        local size = math.min(48, spacing - 6)
        for partIndex = 1, A.maxParts do
            local slot = W:CreateControl(nil, card, CT_BUTTON)
            slot:SetAnchor(TOPLEFT, card, TOPLEFT, 82 + (partIndex - 1) * spacing, 52)
            slot:SetDimensions(size, size + 22)
            slot.background = panel(slot, 0, 0, size, size)
            slot.image = icon(slot, 2, 2, size - 4)
            local badge = panel(slot, 0, size, size, 22)
            badge:SetCenterColor(0, 0, 0, 0.95)
            badge:SetEdgeColor(0, 0, 0, 0)
            slot.status = label(badge, "", 0, 1, size, SMALL_FONT)
            slot.status:SetHeight(22)
            slot.status:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            slot.status:SetDrawLayer(DL_OVERLAY)
            slot:SetMouseEnabled(true)
            local function enter() A.ShowPartTooltip(slot, slot.part, card.data) end
            local function click(_, mouseButton)
                if mouseButton == MOUSE_BUTTON_INDEX_LEFT and A.Call(IsShiftKeyDown) and A.IsResourceSource(slot.part) then
                    return A.OpenResourceMap(slot.part, slot)
                end
                A.OpenPartMap(slot.part, mouseButton ~= MOUSE_BUTTON_INDEX_RIGHT, slot,
                    mouseButton == MOUSE_BUTTON_INDEX_LEFT and A.Call(IsShiftKeyDown))
            end
            slot:EnableMouseButton(MOUSE_BUTTON_INDEX_RIGHT, true)
            slot:SetHandler("OnClicked", nil)
            slot.image:SetMouseEnabled(false)
            slot:SetDrawLayer(DL_OVERLAY)
            slot.image:SetHandler("OnMouseEnter", enter)
            slot.image:SetHandler("OnMouseExit", A.HideRewardTooltip)
            slot.image:SetHandler("OnMouseUp", click)
            slot:SetHandler("OnMouseUp", click)
            slot:SetClickSound(SOUNDS.DEFAULT_CLICK)
            slot:SetHandler("OnMouseEnter", function(self) A.ShowPartTooltip(self, self.part, card.data) end)
            slot:SetHandler("OnMouseExit", A.TooltipExit)
            table.insert(card.parts, slot)
        end

    table.insert(A.cards, card)
end
function A.Render(resetScroll)
    if not A.window then return end
    A.HideRewardTooltip()
    local entries = A.Filter(A.state)
    local selected
    local leads = 0
    for _, group in ipairs(entries) do
        leads = leads + group.have
        if group.key == A.selectedKey then selected = group end
    end
    selected = selected or entries[1]
    A.selectedKey = selected and selected.key
    A.Select(selected)
    A.pageLabel:SetText(string.format(A.L("Наград: %d   ·   Зацепок: %d"), #entries, leads))
    ZO_ScrollList_Clear(A.list)
    local dataList = ZO_ScrollList_GetDataList(A.list)
    for _, group in ipairs(entries) do
        table.insert(dataList, ZO_ScrollList_CreateDataEntry(1, group))
    end
    table.insert(dataList, ZO_ScrollList_CreateDataEntry(2, {}))
    A.UpdateListPadding()
    ZO_ScrollList_Commit(A.list)
    if resetScroll then ZO_ScrollList_ResetToTop(A.list) end
    A.empty:SetHidden(#entries > 0)
    for key, tab in pairs(A.tabs) do
        tab:SetText((key == A.state.tab and "|cE8C563" or "|cAAAAAA") .. tab.caption .. "|r")
    end
end
function A.Select(group)
    A.selectedKey, A.selected = group and group.key, group
    A.previewButton:SetEnabled(group ~= nil and A.CanPreview(group))
end
function A.CanPreview(group)
    return group and group.reward and A.Call(CanPreviewReward, group.reward) == true
end
function A.EndPreview()
    if A.previewObject then A.Method(A.previewObject, "EndCurrentPreview") end
    A.previewing = false
end
function A.Preview()
    local group = A.selected
    if not A.CanPreview(group) then return end
    A.previewReward = group.reward
    A.HideRewardTooltip()
    SCENE_MANAGER:HideTopLevel(A.window)
    SCENE_MANAGER:Show("antiquityAtlasPreview")
end
function A.Build()
    local c = W:CreateTopLevelWindow("AntiquityAtlasWindow")
    A.window = c
    c:SetDimensions(1120, 730)
    c:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    c:SetMouseEnabled(true)
    c:SetMovable(true)
    c:SetClampedToScreen(true)
    c:SetHidden(true)
    local frame = c
    frame:SetResizeHandleSize(12)
    frame:SetDimensionConstraints(784, 511, GuiRoot:GetWidth(), GuiRoot:GetHeight())
    c = W:CreateControl("AntiquityAtlasContent", frame, CT_CONTROL)
    c:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    c:SetDimensions(1120, 730)
    A.content = c
    frame:SetHandler("OnResizeStop", function()
        A.ApplyScale(math.min(frame:GetWidth() / 1120, frame:GetHeight() / 730))
    end)
    A.ApplyScale(A.settings.scale)
    panel(c, 0, 0, 1120, 730)
    label(c, "ANTIQUITY ATLAS", 24, 16, 550, "ZoFontWinH1")
    label(c, A.L("Награды · зацепки · мифики"), 26, 52, 550)
    button(c, A.L("Обновить"), 884, 23, 130, A.Refresh)
    button(c, "×", 1048, 23, 45, function() SCENE_MANAGER:ToggleTopLevel(A.window) end)
    A.tabs = {}
    local tabs = { { "owned", A.L("Мои зацепки") }, { "catalog", A.L("Все награды") }, { "mythics", A.L("Мифики") }, { "history", A.L("Выкопанное") } }
    for index, item in ipairs(tabs) do
        local key, caption = item[1], item[2]
        local tab = button(c, caption, 24 + (index - 1) * 270, 91, 260, function()
            A.state.tab, A.selectedKey = key, nil
            A.Render(true)
        end)
        tab.caption = caption
        A.tabs[key] = tab
    end
    label(c, A.L("ПОИСК"), 24, 140, 76, SMALL_FONT)
    panel(c, 108, 134, 988, 34)
    local search = W:CreateControl("AntiquityAtlasSearch", c, CT_EDITBOX)
    search:SetFont(BODY_FONT)
    search:SetMouseEnabled(true)
    search:SetEditEnabled(true)
    search:SetHandler("OnMouseDown", function(self) self:TakeFocus() end)
    search:SetHandler("OnMouseUp", function(self) self:TakeFocus() end)
    search:SetDrawLayer(DL_OVERLAY)
    A.search = search
    search:SetAnchor(TOPLEFT, c, TOPLEFT, 118, 138)
    search:SetDimensions(968, 26)
    search:SetMaxInputChars(180)
    search:SetHandler("OnTextChanged", function(self)
        A.state.query = self:GetText()
        A.Render(true)
    end)
    search:SetHandler("OnEscape", function(self) self:LoseFocus() end)
    local function change(key, value)
        A.state[key] = value
        A.Render(true)
    end
    dropdown(c, "AntiquityAtlasSort", 24, 178, 258,
        { A.L("По названию"), A.L("Редкость: по убыванию"), A.L("Срок зацепки"), A.L("Прогресс сборки") }, 2, function(i) change("sort", i) end)
    dropdown(c, "AntiquityAtlasQuality", 294, 178, 258,
        { A.L("Любая редкость"), A.L("Обычная"), A.L("Необычная"), A.L("Редкая"), A.L("Эпическая"), A.L("Легендарная"), A.L("Мифическая") }, 1, function(i) change("quality", i == 1 and -1 or i - 2) end)
    dropdown(c, "AntiquityAtlasStatus", 564, 178, 258,
        { A.L("Любой статус"), A.L("Есть зацепки"), A.L("Не выкопано"), A.L("Не собрано") }, 1, function(i) change("status", i) end)
    local kinds, seen = { A.L("Все типы") }, {}
    for _, group in ipairs(A.rewards) do
        if not seen[group.kind] then table.insert(kinds, group.kind); seen[group.kind] = true end
    end
    table.sort(kinds, function(a, b)
        if a == A.L("Все типы") then return b ~= a end
        if b == A.L("Все типы") then return false end
        return a < b
    end)
    dropdown(c, "AntiquityAtlasKind", 834, 178, 262, kinds, 1, function(_, text) change("kind", text) end)
    A.maxParts = 1
    for _, group in ipairs(A.rewards) do A.maxParts = math.max(A.maxParts, #group.parts) end
    A.cards = {}
    A.list = W:CreateControlFromVirtual("AntiquityAtlasRewardList", c, "ZO_ScrollList")
    A.list:SetAnchor(TOPLEFT, c, TOPLEFT, 24, 216)
    A.list:SetDimensions(1072, 426)
    ZO_ScrollList_AddDataType(A.list, 1, "AntiquityAtlasRewardRow", 130, function(control, group)
        if not control.parts then A.CreateCard(control) end
        A.PaintCard(control, group)
    end)
    ZO_ScrollList_AddDataType(A.list, 2, "AntiquityAtlasListPadding", 52, function() end)
    A.empty = label(c, A.L("Ничего не найдено. Измените поиск или фильтры."), 48, 300, 970)
    A.pageLabel = label(c, "", 24, 690, 680, SMALL_FONT)
    A.previewButton = button(c, A.L("Предпросмотр"), 792, 682, 280, A.Preview)
    label(c, A.L("|cA0FFAFВык.|r — выкопано   |c86E8FFЕсть|r — зацепка есть   |cDDDDDDНет|r — нужна зацепка"), 24, 650, 1030, SMALL_FONT)
    SCENE_MANAGER:RegisterTopLevel(A.window, false)
    A.window:SetHandler("OnHide", A.HideRewardTooltip)
    A.InitSourceHighlight()
    A.InitResourcePins()
    A.BuildPreview()
end
function A.BuildPreview()
    local control = W:CreateTopLevelWindow("AntiquityAtlasPreviewWindow")
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 24, 100)
    control:SetDimensions(360, 120)
    control:SetMouseEnabled(true)
    control:SetHidden(true)
    panel(control, 0, 0, 360, 120)
    label(control, A.L("Предпросмотр награды"), 16, 14, 330, "ZoFontWinH2")
    button(control, A.L("Вернуться в каталог"), 16, 66, 328, function() SCENE_MANAGER:HideCurrentScene() end)
    local scene = ZO_Scene:New("antiquityAtlasPreview", SCENE_MANAGER)
    scene:AddFragment(ZO_SimpleSceneFragment:New(control))
    scene:AddFragment(MOUSE_UI_MODE_FRAGMENT)
    if ZO_ItemPreviewOptionsFragment then
        scene:AddFragment(ZO_ItemPreviewOptionsFragment:New({ paddingLeft = 410, paddingRight = 30,
            dynamicFramingConsumedWidth = 410, dynamicFramingConsumedHeight = 80, forcePreparePreview = true }))
    end
    if ITEM_PREVIEW_KEYBOARD and ITEM_PREVIEW_KEYBOARD.GetFragment then
        scene:AddFragment(ITEM_PREVIEW_KEYBOARD:GetFragment())
    end
    scene:AddFragment(FRAME_PLAYER_FRAGMENT)
    scene:AddFragment(PREVIEW_KEYBIND_INTERCEPT_LAYER_FRAGMENT)
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWN then
            SCENE_MANAGER:HideTopLevel(A.window)
            local preview = SYSTEMS:GetObject("itemPreview")
            A.previewObject = preview
            preview:ClearPreviewCollection()
            preview:PreviewReward(A.previewReward)
            A.previewing = true
        elseif newState == SCENE_HIDING then
            A.EndPreview()
        elseif newState == SCENE_HIDDEN then
            SCENE_MANAGER:ShowTopLevel(A.window)
        end
    end)
end
function A.Toggle()
    if not A.window then return end
    if A.window:IsHidden() then A.Refresh() end
    SCENE_MANAGER:ToggleTopLevel(A.window)
end
local function loaded(_, name)
    if name ~= "AntiquityAtlas" then return end
    EVENT_MANAGER:UnregisterForEvent("AntiquityAtlas", EVENT_ADD_ON_LOADED)
    A.settings = ZO_SavedVars:NewAccountWide("AntiquityAtlasSavedVariables", 1, nil, { scale = 1 })
    A.state = { tab = "owned", query = "", quality = -1, status = 1, sort = 2, kind = A.L("Все типы") }
    local rewards, message = A.Read()
    if not rewards then d(message); return end
    A.Build()
    A.Render()
    A.InitJournalButton()
    SLASH_COMMANDS["/atlas"] = A.Toggle
    SLASH_COMMANDS["/atlascheck"] = A.AuditSources
    SLASH_COMMANDS["/antiquityatlas"] = A.Toggle
    ZO_CreateStringId("SI_BINDING_NAME_ANTIQUITY_ATLAS_TOGGLE", A.L("Открыть каталог древностей"))
    local function refresh()
        zo_callLater(function() if A.window and not A.window:IsHidden() then A.Refresh() end end, 150)
    end
    for _, event in ipairs({ "AntiquitiesUpdated", "SingleAntiquityUpdated", "SingleAntiquityLeadAcquired" }) do
        ANTIQUITY_DATA_MANAGER:RegisterCallback(event, refresh)
    end
end
EVENT_MANAGER:RegisterForEvent("AntiquityAtlas", EVENT_ADD_ON_LOADED, loaded)
