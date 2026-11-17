local O, P = OneCraft, OneCraft.Equipment
local W = WINDOW_MANAGER
local function setName(id)
    local entry = P.Engine.Sets()[id]
    return id == 0 and P.words.none or entry and entry[1] or "?"
end

local function label(parent, text, x, y, width, font)
    local c = W:CreateControl(nil, parent, CT_LABEL)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(width, 32)
    c:SetFont(font or "ZoFontGame")
    c:SetText(text)
    return c
end

local function button(parent, text, x, y, width, callback)
    local c = W:CreateControlFromVirtual(nil, parent, "ZO_DefaultButton")
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(width, 32)
    c:SetText(text)
    c:SetHandler("OnClicked", callback)
    return c
end

local function hint(control, getText, above)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function(c)
        if above then InitializeTooltip(InformationTooltip, c, BOTTOM, 0, -8, TOP)
        else InitializeTooltip(InformationTooltip, c, RIGHT) end
        SetTooltipText(InformationTooltip, getText())
    end)
    control:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
end

function P.ItemLink(item)
    if not item or not P.ValidItem(item) then return nil end
    local kind = P.types[item.type]
    local ids = item.enchant and O.Enchanting.RecipeEngine.RuneIds(P.GlyphSelection(item)) or {}
    return P.client:getItemLinkFromParticulars(kind.pattern, item.cp, item.level, item.style,
        item.trait + 1, kind.station, item.set, item.quality, ids[1], ids[2], ids[3])
end

local function clearItemTooltip()
    ClearTooltip(ItemTooltip)
end

local function showItemTooltip(control, item)
    local link = P.ItemLink(item)
    if link then
        InitializeTooltip(ItemTooltip, control, LEFT, 8, 0, RIGHT)
        ItemTooltip:SetLink(link)
    end
end

function P.ShowSetTooltip(control, id)
    clearItemTooltip()
    ClearTooltip(InformationTooltip)
    if id == 0 then return end
    local item = P.Copy(P.draft)
    item.type, item.set, item.trait, item.enchant = "Chest" .. ARMORTYPE_HEAVY, id, 0, false
    local link = P.ItemLink(item)
    if link then showItemTooltip(control, item); return end
    -- Native set bonuses remain available even for newly added item ID ranges.
    local _, _, count = GetItemSetInfo(id)
    local lines = {setName(id)}
    for i = 1, count do
        local _, description = GetItemSetBonusInfo(id, i)
        lines[#lines + 1] = description
    end
    InitializeTooltip(InformationTooltip, control, LEFT, 8, 0, RIGHT)
    SetTooltipText(InformationTooltip, table.concat(lines, "\n\n"))
end

local function report(ok, reason)
    P.status = ok and nil or reason
    P.RefreshUI()
end

function P.Select(key)
    key = P.OccupiedSlot(key)
    if P.draft then P.saved.last = P.Copy(P.draft) end
    P.selected, P.draft = key, P.Copy(P.saved.items[key] or P.DefaultItem(key))
    P.status = nil
    P.RefreshUI()
end

function P.FieldEntries(field)
    local entries, item = {}, P.draft
    local function add(value, name) entries[#entries + 1] = {value = value, name = name} end
    if field == "type" then
        for _, kind in ipairs(P.TypesForSlot(P.selected)) do add(kind.key, kind.name) end
    elseif field == "set" then
        add(0, P.words.none)
        local sets = {}
        for id, data in pairs(P.Engine.Sets()) do
            if id ~= 0 then sets[#sets + 1] = {value = id, name = data[1]} end
        end
        table.sort(sets, function(a, b) return a.name < b.name end)
        for _, entry in ipairs(sets) do entries[#entries + 1] = entry end
    elseif field == "quality" then
        for i = 1, 5 do add(i, GetString("SI_ITEMQUALITY", i)) end
    elseif field == "style" then
        if P.types[item.type].category == "jewelry" then
            add(item.style, P.Text("Не требуется", "Not required"))
        else
            for i = 1, GetNumValidItemStyles() do
                local id = GetValidItemStyleId(i)
                if id > 0 then add(id, GetItemStyleName(id)) end
            end
        end
    elseif field == "level" then
        add("L1", "1")
        for level = 4, 50, 2 do add("L" .. level, tostring(level)) end
        for level = 10, 160, 10 do add("C" .. level, string.format(O.Enchanting.text.cpFormat, level)) end
    elseif field == "enchant" then
        add(false, P.words.noEnchant)
        for _, effect in ipairs(O.Enchanting.effectList) do
            if effect.equipment == P.types[item.type].category then
                add(effect.key, O.Enchanting.RecipeEngine.EffectName(effect))
            end
        end
    elseif field == "trait" then
        add(0, GetString("SI_ITEMTRAITTYPE", 0))
        local kind = P.types[item.type]
        local filter = kind.category == "weapon" and SMITHING_FILTER_TYPE_WEAPONS or
            kind.category == "jewelry" and SMITHING_FILTER_TYPE_JEWELRY or SMITHING_FILTER_TYPE_ARMOR
        for i = 1, GetNumSmithingTraitItems() do
            local trait = GetSmithingTraitItemInfo(i)
            if trait and trait ~= 0 and ZO_CraftingUtils_GetSmithingFilterFromTrait(trait) == filter then
                add(trait, GetString("SI_ITEMTRAITTYPE", trait))
            end
        end
    end
    return entries
end

function P.ChooseField(field, value)
    if P.rebuilding then return end
    if field == "level" then
        P.draft.cp, P.draft.level = value:sub(1, 1) == "C", tonumber(value:sub(2))
    elseif field == "type" then
        local previous = P.types[P.draft.type]
        P.draft.type = value
        -- Traits from a different equipment family cannot be carried over.
        if previous.category ~= P.types[value].category then P.draft.trait, P.draft.enchant = 0, false end
    else P.draft[field] = value end
    P.saved.last = P.Copy(P.draft)
    P.RefreshUI()
end

function P.RefreshUI()
    if not P.visible then return end
    P.rebuilding = true
    for _, key in ipairs(P.slotOrder) do
        local control, item = P.controls[key], P.SlotItem(key)
        local link = P.ItemLink(item)
        control.icon:SetTexture(link and GetItemLinkIcon(link) or control.emptyIcon)
        control.icon:SetAlpha(1)
        control.selected:SetHidden(P.selected ~= P.OccupiedSlot(key))
    end
    for _, field in ipairs(P.fields) do
        local combo = P.combos[field]
        combo:ClearItems()
        local selectedValue = field == "level" and ((P.draft.cp and "C" or "L") .. P.draft.level) or P.draft[field]
        for _, data in ipairs(P.FieldEntries(field)) do
            local value = data.value
            local entry = combo:CreateItemEntry(data.name, function() P.ChooseField(field, value) end)
            if field == "set" then
                entry.onEnter = function(c) P.ShowSetTooltip(c, value) end
                entry.onExit = function() clearItemTooltip(); ClearTooltip(InformationTooltip) end
            end
            combo:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
            if value == selectedValue then combo:SetSelectedItem(data.name) end
        end
        combo:UpdateItems()
    end
    P.materialRows = P.materialRows or {}
    local materials = P.Materials()
    for i, data in ipairs(materials) do
        local row = P.materialRows[i]
        if not row then
            row = label(P.materialChild, "", 0, (i - 1) * 38, 320, "ZoFontGameSmall")
            hint(row, function() return row.link end)
            P.materialRows[i] = row
        end
        row.link = data.link
        row:SetText(string.format("|t24:24:%s|t %s   %d / %d", data.icon, data.name, data.need, data.have))
        row:SetColor(data.have < data.need and 1 or 0.85, data.have < data.need and 0.22 or 0.85,
            data.have < data.need and 0.22 or 0.85, 1)
        row:SetHidden(false)
    end
    for i = #materials + 1, #P.materialRows do P.materialRows[i]:SetHidden(true) end
    P.materialChild:SetHeight(math.max(1, #materials * 38))
    local batch = P.saved.batch
    P.queueLabel:SetText(batch and string.format(P.words.queued, batch.completed, batch.total) or "")
    P.statusLabel:SetText(P.status or (P.HasQueue() and P.words.waiting or ""))
    P.submitButton:SetEnabled(not P.HasQueue() and not ZO_CraftingUtils_IsPerformingCraftProcess())
    P.cancelButton:SetEnabled(P.HasQueue() and not ZO_CraftingUtils_IsPerformingCraftProcess())
    P.clearButton:SetEnabled(not P.client.active and not ZO_CraftingUtils_IsPerformingCraftProcess())
    P.clearButton:SetEnabled(not P.client.active and not ZO_CraftingUtils_IsPerformingCraftProcess())
    P.rebuilding = false
end

local function createSlot(key, parent, native, x, y)
    -- Reuse the native slot art and exact native anchors, with planner-only
    -- handlers. Never bind these controls to BAG_WORN or native item movement.
    local c = W:CreateControlFromVirtual("OneCraftEquipmentSlot" .. key, parent,
        P.slots[key].weapon and "ZO_InventoryWeaponSlot" or "ZO_InventoryEquippedSlot")
    c.oneCraftSlot = key
    c:ClearAnchors()
    if native then c:SetAnchor(TOPLEFT, native, TOPLEFT, 0, 0)
    else c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y) end
    c:SetDimensions(44, 44)
    c.icon = c:GetNamedChild("Icon")
    c.emptyIcon = native and ZO_Character_GetEmptyEquipSlotTexture(P.slotIds[key]) or O.noneTexture
    c.selected = W:CreateControl(nil, c, CT_TEXTURE)
    c.selected:SetAnchorFill()
    c.selected:SetTexture("EsoUI/Art/ActionBar/actionBar_mouseOver.dds")
    c.selected:SetColor(1, 1, 1, 1)
    c:SetHandler("OnMouseDown", function(_, mouseButton)
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT then P.pressed = key end
    end)
    c:SetHandler("OnDragStart", function()
        clearItemTooltip()
        if P.SlotItem(key) then P.dragging = P.OccupiedSlot(key) end
    end)
    c:SetHandler("OnDragStop", function() end)
    c:SetHandler("OnReceiveDrag", function() end)
    c:SetHandler("OnClicked", nil)
    c:SetHandler("OnMouseDoubleClick", nil)
    c:SetHandler("OnMouseUp", function(_, mouseButton, inside)
        if mouseButton ~= MOUSE_BUTTON_INDEX_LEFT or not inside then return end
        clearItemTooltip()
        local source = P.dragging or P.pressed
        P.dragging, P.pressed = nil, nil
        if source and source ~= key then
            local ok, reason = P.Move(source, key)
            if ok then P.Select(key) else report(ok, reason) end
        else P.Select(key) end
    end)
    c:SetMouseEnabled(true)
    c:SetHandler("OnMouseEnter", function()
        clearItemTooltip()
        showItemTooltip(c, P.SlotItem(key))
    end)
    c:SetHandler("OnMouseExit", clearItemTooltip)
    P.controls[key] = c
end

function P.Show()
    if IsInGamepadPreferredMode() then return end
    if P.inventoryScene and P.inventoryScene:IsShowing() then
        P.inventoryTabs:SelectFragment(P.tabId)
    elseif P.stationOpen then
        CRAFT_ADVISOR_WINDOW.tabs:SelectFragment(P.tabId)
    end
end

local function hidePlanner()
    P.visible, P.dragging, P.pressed = false, nil, nil
    if P.root then P.root:SetHidden(true) end
    ClearTooltip(InformationTooltip)
    clearItemTooltip()
end

function P.Hide()
    if P.visible then
        if P.inventoryScene and P.inventoryScene:IsShowing() then
            P.inventoryTabs:SelectFragment(SI_CHARACTER_EQUIP_TITLE)
        elseif P.stationOpen and not IsInGamepadPreferredMode() then
            CRAFT_ADVISOR_WINDOW.tabs:SelectFragment(SI_CHARACTER_EQUIP_TITLE)
        end
    end
    hidePlanner()
end

function P.RefreshStationTab()
    if CRAFT_ADVISOR_WINDOW then
        local bar = CRAFT_ADVISOR_WINDOW.tabBar
        -- ESO lays this bar out right to left. Keep existing button controls
        -- and other addons' tabs intact; move only our entry after the writ.
        local buttons = bar.m_object and bar.m_object.m_buttons
        if buttons then
            local plannerIndex, writIndex
            for i, entry in ipairs(buttons) do
                if entry[3] == P.tabId then plannerIndex = i end
                if entry[3] == SI_CRAFT_ADVISOR_WRITS_TITLE then writIndex = i end
            end
            if plannerIndex and writIndex and plannerIndex ~= writIndex + 1 then
                local planner = table.remove(buttons, plannerIndex)
                if plannerIndex < writIndex then writIndex = writIndex - 1 end
                table.insert(buttons, writIndex + 1, planner)
            end
        end
        ZO_MenuBar_UpdateButtons(bar)
    end
    if P.stationButton then
        P.stationButton:SetHidden(not P.stationOpen or IsInGamepadPreferredMode())
    end
end

function P.CreateInventoryTabs()
    local scene = SCENE_MANAGER:GetScene("inventory")
    P.inventoryScene = scene
    local bar = W:CreateTopLevelWindow("OneCraftEquipmentInventoryTabs")
    bar:SetAnchor(TOPLEFT, ZO_Character, TOPLEFT, 10, 0)
    bar:SetDimensions(220, 51)
    bar:SetHidden(true)
    -- Native character windows can move above ordinary top-level controls.
    -- Keep this bar above both dolls, including after hover/click changes.
    bar:SetDrawTier(DT_HIGH)
    bar:SetDrawLevel(1)
    local menu = W:CreateControlFromVirtual("OneCraftEquipmentInventoryMenu", bar, "ZO_MenuBarTemplate")
    menu:SetAnchor(TOPLEFT, bar, TOPLEFT, 0, 0)
    local title = W:CreateControl("OneCraftEquipmentInventoryMenuLabel", menu, CT_LABEL)
    title:SetExcludeFromResizeToFitExtents(true)
    title:SetAnchor(LEFT, menu, RIGHT, 15, 0)
    title:SetFont("ZoFontHeader3")
    title:SetDrawTier(DT_HIGH)
    title:SetDrawLevel(10)
    title:SetMouseEnabled(false)
    ZO_MenuBar_SetData(menu, {
        buttonTemplate = "ZO_MenuBarTooltipButton", normalSize = 51, downSize = 64,
        buttonPadding = 15, animationDuration = 180,
    })
    local tabs = ZO_SceneFragmentBar:New(menu)
    P.inventoryTabs = tabs
    local function tabData(texture)
        return {normal = texture .. "up.dds", pressed = texture .. "down.dds",
            highlight = texture .. "over.dds", disabled = texture .. "disabled.dds",
            alwaysShowTooltip = true}
    end
    -- The inventory scene normally owns these fragments directly. Move its
    -- equipment content into a tab group; the bar replaces the old header.
    scene:RemoveFragment(CHARACTER_WINDOW_FRAGMENT)
    scene:RemoveFragment(CHARACTER_WINDOW_HEADER_FRAGMENT)
    scene:RemoveFragment(CHARACTER_WINDOW_STATS_FRAGMENT)
    tabs:Add(SI_CHARACTER_EQUIP_TITLE, {CHARACTER_WINDOW_FRAGMENT, CHARACTER_WINDOW_STATS_FRAGMENT},
        tabData("EsoUI/Art/WritAdvisor/advisor_tabIcon_equip_"))
    tabs:Add(P.tabId, {P.fragment}, tabData("EsoUI/Art/Crafting/smithing_tabIcon_creation_"))
    P.inventoryEquipmentButton = ZO_MenuBar_GetButtonControl(menu, SI_CHARACTER_EQUIP_TITLE)
    P.inventoryPlannerButton = ZO_MenuBar_GetButtonControl(menu, P.tabId)
    scene:AddFragment(ZO_SimpleSceneFragment:New(bar))
    scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            bar:BringWindowToTop()
            tabs:SelectFragment(SI_CHARACTER_EQUIP_TITLE)
        elseif state == SCENE_HIDING then
            tabs:Clear()
            hidePlanner()
        end
    end)
    if scene:IsShowing() then tabs:SelectFragment(SI_CHARACTER_EQUIP_TITLE) end
end

function P.CreateUI()
    local root = W:CreateTopLevelWindow("OneCraftEquipmentPlanner")
    P.root = root
    -- Start below the native tab bar and cover only the planner's content.
    root:SetAnchor(TOPLEFT, ZO_Character, TOPLEFT, 0, 70)
    root:SetDimensions(1050, 667)
    root:SetDrawTier(DT_HIGH)
    root:SetMouseEnabled(true)
    root:SetHidden(true)
    local origin = W:CreateControl(nil, root, CT_CONTROL)
    -- All doll parts remain at exactly the keyboard character sheet positions.
    origin:SetAnchor(TOPLEFT, ZO_Character, TOPLEFT, 0, 0)
    origin:SetDimensions(1050, 737)
    P.silhouette = W:CreateControl(nil, root, CT_TEXTURE)
    P.silhouette:SetAnchor(TOPLEFT, ZO_CharacterPaperDoll, TOPLEFT, 0, 0)
    P.silhouette:SetDimensions(64, 256)
    P.controls = {}
    for _, key in ipairs(P.slotOrder) do
        if not P.slots[key].extra then createSlot(key, root, _G["ZO_CharacterEquipmentSlots" .. key]) end
    end
    local function divider(name, y, text)
        local c = W:CreateControlFromVirtual(name, origin, "ZO_CharacterSheetDivider")
        c:SetAnchor(TOPLEFT, origin, TOPLEFT, 0, y)
        c:GetNamedChild("Text"):SetText(text)
    end
    local apparelDivider = W:CreateControl(nil, origin, CT_TEXTURE)
    apparelDivider:SetAnchor(TOPLEFT, origin, TOPLEFT, 0, 63)
    apparelDivider:SetDimensions(256, 4)
    apparelDivider:SetTexture("EsoUI/Art/CharacterWindow/characterWindow_leftSide_divider.dds")
    local apparel = label(origin, "", 14, 72, 220, "ZoFontHeader")
    apparel:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    P.apparelLabel = apparel
    divider("OneCraftEquipmentAccessoriesSection", 314, GetString("SI_EQUIPSLOTVISUALCATEGORY", EQUIP_SLOT_VISUAL_CATEGORY_ACCESSORIES))
    divider("OneCraftEquipmentWeaponsSection", 400, GetString("SI_EQUIPSLOTVISUALCATEGORY", EQUIP_SLOT_VISUAL_CATEGORY_WEAPONS))
    divider("OneCraftEquipmentExtrasSection", 535, P.words.extras)
    -- Keep the native non-craftable slots in their normal positions.
    P.decorations = {}
    for _, data in ipairs({{"Costume", EQUIP_SLOT_COSTUME}, {"Poison", EQUIP_SLOT_POISON}, {"BackupPoison", EQUIP_SLOT_BACKUP_POISON}}) do
        local native = _G["ZO_CharacterEquipmentSlots" .. data[1]]
        local c = W:CreateControlFromVirtual("OneCraftEquipmentDecoration" .. data[1], root,
            data[1] == "Costume" and "ZO_InventoryEquippedSlot" or "ZO_InventoryWeaponSlot")
        c:SetAnchor(TOPLEFT, native, TOPLEFT, 0, 0)
        c:GetNamedChild("Icon"):SetTexture(ZO_Character_GetEmptyEquipSlotTexture(data[2]))
        c:SetMouseEnabled(false)
        P.decorations[data[1]] = c
    end
    local swap = W:CreateControlFromVirtual("OneCraftEquipmentWeaponSwap", root, "ZO_WeaponSwapLeft")
    swap:SetAnchor(TOPLEFT, ZO_CharacterWeaponSwap, TOPLEFT, 0, 0)
    swap:SetHandler("OnMouseDown", nil)
    swap:SetHandler("OnClicked", nil)
    swap:SetMouseEnabled(false)
    local extras = W:CreateControl(nil, origin, CT_CONTROL)
    extras:SetAnchor(TOPLEFT, origin, TOPLEFT, 10, 566)
    extras:SetDimensions(228, 94)
    for i = 1, P.extraCount do createSlot("extra" .. i, extras, nil, ((i - 1) % 5) * 46, math.floor((i - 1) / 5) * 50) end
    local panel = W:CreateControl("OneCraftEquipmentEditorPanel", origin, CT_CONTROL)
    panel:SetAnchor(TOPLEFT, origin, TOPLEFT, 242, 78)
    panel:SetDimensions(810, 658)
    -- Use ESO's side-panel background with soft falloff, not a tooltip frame.
    local background = W:CreateControlFromVirtual("OneCraftEquipmentEditorBackground", panel, "ZO_PanelBackground")
    -- Match the doll's actual background texture, including the panel's
    -- 64px top/bottom falloff and its 16px left inset.
    local dollBackground = ZO_SharedThinLeftPanelBackground:GetNamedChild("Left")
    background:ClearAnchors()
    background:SetAnchor(TOPLEFT, dollBackground, TOPRIGHT, 16, 64)
    background:SetAnchor(BOTTOMRIGHT, dollBackground, BOTTOMRIGHT, 810, -64)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetAlpha(0.8)
    local function panelDivider(name, x, y, width)
        local c = W:CreateControlFromVirtual(name, panel, "ZO_DynamicHorizontalDivider")
        c:SetAnchor(TOPLEFT, panel, TOPLEFT, x, y)
        c:SetWidth(width)
    end
    P.fields, P.combos = {"set", "type", "level", "style", "trait", "enchant", "quality"}, {}
    local editor = W:CreateControl(nil, panel, CT_CONTROL)
    editor:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, 14)
    editor:SetDimensions(410, 466)
    for i, field in ipairs(P.fields) do
        local fieldLabel = label(editor, P.words[field], 0, (i - 1) * 52 + 4, 130, "ZoFontHeader")
        fieldLabel:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
        panelDivider("OneCraftEquipmentDivider" .. field, 8, 58 + (i - 1) * 52, 405)
        local control = W:CreateControlFromVirtual("OneCraftEquipmentField" .. field, editor, "ZO_ComboBox")
        control:SetAnchor(TOPLEFT, editor, TOPLEFT, 130, (i - 1) * 52)
        control:SetDimensions(275, 32)
        local combo = ZO_ComboBox_ObjectFromContainer(control)
        combo:SetSortsItems(false)
        P.combos[field] = combo
        if field == "set" then
            hint(control, function() return setName(P.draft.set) end)
            control:SetHandler("OnMouseEnter", function(c) P.ShowSetTooltip(c, P.draft.set) end)
            control:SetHandler("OnMouseExit", function() clearItemTooltip(); ClearTooltip(InformationTooltip) end)
        end
    end
    button(editor, P.words.apply, 0, 434, 195, function() report(P.Apply(P.selected, P.draft)) end)
    button(editor, P.words.remove, 210, 434, 195, function()
        P.saved.items[P.selected] = nil
        P.Select(P.selected)
    end)
    local materialHeader = label(panel, P.words.materials, 458, 16, 340, "ZoFontWinH3")
    materialHeader:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    panelDivider("OneCraftEquipmentMaterialsDivider", 458, 50, 340)
    panelDivider("OneCraftEquipmentActionsDivider", 8, 432, 790)
    local scroll = W:CreateControlFromVirtual("OneCraftEquipmentMaterials", panel, "ZO_ScrollContainer")
    scroll:SetAnchor(TOPLEFT, panel, TOPLEFT, 458, 64)
    scroll:SetDimensions(340, 335)
    P.materialChild = scroll:GetNamedChild("ScrollChild")
    P.materialChild:SetWidth(320)
    P.queueLabel = label(panel, "", 458, 404, 340, "ZoFontWinH3")
    P.submitButton = button(panel, P.words.submit, 458, 448, 340, function() report(P.Submit()) end)
    P.cancelButton = button(panel, P.words.cancel, 458, 491, 340, function() report(P.Cancel()) end)
    P.clearButton = button(panel, P.words.clear, 458, 534, 340, function() report(P.ClearAll()) end)
    P.statusLabel = label(panel, "", 458, 574, 340, "ZoFontGame")
    P.statusLabel:SetHeight(85)

    -- The native fragment bar removes the equipped/writ fragment group when
    -- selecting this tab, and restores it when selecting another section.
    local advisor = CRAFT_ADVISOR_WINDOW
    -- A child's tier cannot lift it above another top-level window. Raise
    -- the advisor window itself above the planner's foreground/background.
    advisor.control:SetDrawTier(DT_HIGH)
    advisor.control:SetDrawLevel(2)
    local tabTitle = advisor.tabBar:GetNamedChild("Label")
    tabTitle:SetDrawTier(DT_HIGH)
    tabTitle:SetDrawLevel(10)
    ZO_CreateStringId("SI_ONECRAFT_EQUIPMENT_PLANNER", "OneCraft — " .. P.words.title)
    P.tabId = SI_ONECRAFT_EQUIPMENT_PLANNER
    P.fragment = ZO_SimpleSceneFragment:New(root)
    P.fragment:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_FRAGMENT_SHOWING then
            P.visible = true
            P.silhouette:SetTexture(GetUnitSilhouetteTexture("player"))
            local apparelText = IsEquipSlotVisualCategoryHidden(EQUIP_SLOT_VISUAL_CATEGORY_APPAREL, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
                and GetString(SI_CHARACTER_EQUIP_APPAREL_HIDDEN)
                or GetString("SI_EQUIPSLOTVISUALCATEGORY", EQUIP_SLOT_VISUAL_CATEGORY_APPAREL)
            P.apparelLabel:SetText(apparelText)
            P.Select(P.selected or "Chest")
        elseif state == SCENE_FRAGMENT_HIDING or state == SCENE_FRAGMENT_HIDDEN then
            hidePlanner()
        end
    end)
    local layoutEquipment = advisor.equipmentData.existingCallback or advisor.equipmentData.callback
    local texture = "EsoUI/Art/Crafting/smithing_tabIcon_creation_"
    advisor.tabs:Add(P.tabId, {P.fragment, THIN_LEFT_PANEL_BG_FRAGMENT}, {
        normal = texture .. "up.dds", pressed = texture .. "down.dds",
        highlight = texture .. "over.dds", disabled = texture .. "disabled.dds",
        -- The advisor already belongs to crafting scenes. Its layout can run
        -- before the station-interact event updates our stationOpen flag.
        visible = function() return not IsInGamepadPreferredMode() end,
        alwaysShowTooltip = true,
        CustomTooltipFunction = function(tooltip)
            InitializeTooltip(tooltip, P.stationButton, BOTTOM, 0, -8, TOP)
            SetTooltipText(tooltip, GetString(P.tabId))
        end,
        callback = layoutEquipment,
    })
    P.stationButton = ZO_MenuBar_GetButtonControl(advisor.tabBar, P.tabId)
    ZO_PostHook(advisor, "OnShowing", P.RefreshStationTab)
    ZO_PostHook(advisor, "OnHidden", hidePlanner)
    P.CreateInventoryTabs()
    EVENT_MANAGER:RegisterForEvent("OneCraftEquipmentDrop", EVENT_GLOBAL_MOUSE_UP, function(_, mouseButton)
        if mouseButton ~= MOUSE_BUTTON_INDEX_LEFT or not P.visible then return end
        local source = P.dragging
        P.dragging, P.pressed = nil, nil
        if not source then return end
        local target = W:GetMouseOverControl()
        while target and not target.oneCraftSlot do target = target:GetParent() end
        if target and target.oneCraftSlot ~= source then
            local ok, reason = P.Move(source, target.oneCraftSlot)
            if ok then P.Select(target.oneCraftSlot) else report(ok, reason) end
        end
    end)
end
