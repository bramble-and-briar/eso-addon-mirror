local LeoAltholic = LeoAltholic
LeoAltholic.hidden = true
LeoAltholic.listingInventoryFor = 0

function LeoAltholic:OnWindowMoveStop()
    LeoAltholic.globalData.position = {
        left = LeoAltholicWindow:GetLeft(),
        top = LeoAltholicWindow:GetTop()
    }
end

function LeoAltholic.UI:OnHide(control, hidden)
    if hidden then LeoAltholic.HideUI() end
end

function LeoAltholic.UI:OnShow(control, hidden)
    if not hidden then LeoAltholic.ShowUI() end
end

function LeoAltholic:isHidden()
    return LeoAltholic.hidden
end

function LeoAltholic.RestorePosition()
    local position = LeoAltholic.globalData.position or { left = 200; top = 200; }
    local left = position.left
    local top = position.top

    LeoAltholicWindow:ClearAnchors()
    LeoAltholicWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    LeoAltholicWindow:SetDrawLayer(DL_OVERLAY)
    LeoAltholicWindow:SetDrawTier(DT_MEDIUM)
end

function LeoAltholic.ChangeInventoryUI(bagId)
    LeoAltholic.ShowInventoryUI(LeoAltholic.listingInventoryFor, bagId)
end

function LeoAltholic.ShowInventoryUI(charName, bagId)
    LeoAltholic.listingInventoryFor = charName
    SCENE_MANAGER:ShowTopLevel(LeoAltholicInventoryWindow)
    LeoAltholicInventoryWindow:SetDrawLayer(DL_OVERLAY)
    LeoAltholicInventoryWindow:SetDrawTier(DT_HIGH)
    LeoAltholicInventoryWindow:SetDrawLevel(10)
    local header = WINDOW_MANAGER:GetControlByName("LeoAltholicInventoryWindowTitle")
    local char
    if charName ~= nil then
        char = LeoAltholic.GetCharByName(charName)
        header:SetText(GetString(SI_MAIN_MENU_INVENTORY))
    else
        header:SetText(GetString(SI_CURRENCYLOCATION1))
    end
    local sc = WINDOW_MANAGER:GetControlByName("LeoAltholicInventoryWindowListScrollChild")
    sc:SetHidden(false)

    local i = 1
    for x = 1, sc:GetNumChildren() do
        sc:GetChild(x):SetHidden(true)
    end
    for _, item in pairs(LeoAltholic.GetItems(char, bagId)) do
        local row = WINDOW_MANAGER:GetControlByName("LeoAltholicInventoryWindowRow" .. i)
        if not row then
            row = CreateControlFromVirtual("LeoAltholicInventoryWindowRow" .. i, sc, "LeoAltholicInventoryTemplate")
        end
        local texture = row:GetNamedChild("Icon")
        local label = row:GetNamedChild("Item")
        texture:SetHidden(false)
        label:SetHidden(false)
        texture:SetTexture(GetItemLinkIcon(item.link))
        local qty = row:GetNamedChild("Qty")
        if item.count > 1 then
            qty:SetText(item.count)
            qty:SetHidden(false)
        else
            qty:SetText(0)
            qty:SetHidden(true)
        end
        label:SetText(item.link)
        label:SetHandler("OnMouseEnter",
                function(self)
                    InitializeTooltip(LeoAltholicItemToolTip, LeoAltholicInventoryWindow, TOPLEFT, -450, 50, TOPLEFT)
                    LeoAltholicItemToolTip:SetLink(item.link)
                end
        )
        label:SetHandler("OnMouseExit",
                function(self)
                    ClearTooltip(LeoAltholicItemToolTip)
                end
        )
        row:SetAnchor(TOPLEFT, sc, TOPLEFT, 2, (i - 1) * 30)
        row:SetHidden(false)
        i = i + 1
    end
    sc:SetHeight(i * 30)
end

function LeoAltholic.HideInventoryUI()
    SCENE_MANAGER:HideTopLevel(LeoAltholicInventoryWindow)
end

function LeoAltholic.CloseUI()
    SCENE_MANAGER:HideTopLevel(LeoAltholicWindow)
    SCENE_MANAGER:HideTopLevel(LeoAltholicInventoryWindow)
end

function LeoAltholic.ShowUI()
    LeoAltholic.hidden = false;
    LeoAltholic.ShowTab(LeoAltholic.globalData.activeTab or "Bio")
end

function LeoAltholic.HideUI()
    LeoAltholic.hidden = true;
    LeoAltholic.HideInventoryUI()
end

function LeoAltholic.ToggleUI()
    SCENE_MANAGER:ToggleTopLevel(LeoAltholicWindow)
end

function LeoAltholic.ShowTab(tab)
    LeoAltholic.globalData.activeTab = tab
    LeoAltholicWindowTitle:SetText(LeoAltholic.displayName .. " v" .. LeoAltholic.version .. " - " .. tab)
    local control
    for _, panel in ipairs(LeoAltholic.panelList) do
        control = WINDOW_MANAGER:GetControlByName('LeoAltholicWindow' .. panel .. 'Panel')
        control:SetHidden(true)
    end
    control = WINDOW_MANAGER:GetControlByName("LeoAltholicWindow" .. tab .. "Panel")
    control:SetHidden(false)

    -- Refresh the corresponding list whenever the tab is shown
    local tabLists = {
        Bio = LeoAltholic.UI.bioList,
        Stats = LeoAltholic.UI.statsList,
        Champion = LeoAltholic.UI.championList,
        Skills = LeoAltholic.UI.skillsList,
        Skills2 = LeoAltholic.UI.skills2List,
        Writs = LeoAltholic.UI.writsList,
        Inventory = LeoAltholic.UI.invList,
        Research = LeoAltholic.UI.researchList,
    }
    if tabLists[tab] then
        tabLists[tab]:RefreshData()
    end
end

function LeoAltholic.UI.InitPanels()
    LeoAltholic.UI.bioList = LeoAltholic.BioList:New(LeoAltholicWindowBioPanelListScroll)
    LeoAltholic.UI.statsList = LeoAltholic.StatsList:New(LeoAltholicWindowStatsPanelListScroll)
    LeoAltholic.UI.championList = LeoAltholic.ChampionList:New(LeoAltholicWindowChampionPanelListScroll)
    LeoAltholic.UI.skillsList = LeoAltholic.SkillsList:New(LeoAltholicWindowSkillsPanelListScroll)
    LeoAltholic.UI.skills2List = LeoAltholic.Skills2List:New(LeoAltholicWindowSkills2PanelListScroll)
    LeoAltholic.UI.writsList = LeoAltholic.WritsList:New(LeoAltholicWindowWritsPanelListScroll)
    LeoAltholic.UI.invList = LeoAltholic.InventoryList:New(LeoAltholicWindowInventoryPanelListScroll)
    LeoAltholic.UI.researchList = LeoAltholic.ResearchList:New(LeoAltholicWindowResearchPanelListScroll)

    LeoAltholic.GetCharacters(true)

    local lists = {
        LeoAltholic.UI.bioList,
        LeoAltholic.UI.statsList,
        LeoAltholic.UI.championList,
        LeoAltholic.UI.skillsList,
        LeoAltholic.UI.skills2List,
        LeoAltholic.UI.writsList,
        LeoAltholic.UI.invList,
        LeoAltholic.UI.researchList,
    }
    for _, listObj in ipairs(lists) do
        if listObj then
            listObj.currentSortKey = "queueIndex"
            listObj.currentSortOrder = ZO_SORT_ORDER_UP
            listObj:RefreshData()
        end
    end

    LeoAltholic.UI.InitTrackedPanel()
end

