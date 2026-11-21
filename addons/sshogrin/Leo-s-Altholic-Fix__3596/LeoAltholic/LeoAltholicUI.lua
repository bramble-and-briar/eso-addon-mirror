
LeoAltholic.hidden = true
LeoAltholic.listingInventoryFor = 0

function LeoAltholic:OnWindowMoveStop()
    LeoAltholic.globalData.position = {
        left = LeoAltholicWindow:GetLeft(),
        top = LeoAltholicWindow:GetTop()
    }
end

function LeoAltholicUI:OnHide(control, hidden)
    if hidden then LeoAltholic.HideUI() end
end

function LeoAltholicUI:OnShow(control, hidden)
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
    LeoAltholicInventoryWindow:SetDrawTier(DT_MEDIUM)
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
    for _,panel in ipairs(LeoAltholic.panelList) do
        control = WINDOW_MANAGER:GetControlByName('LeoAltholicWindow' .. panel .. 'Panel')
        control:SetHidden(true)
    end
    control = WINDOW_MANAGER:GetControlByName("LeoAltholicWindow" .. tab .. "Panel")
    control:SetHidden(false)
end

function LeoAltholicUI.InitPanels()
    LeoAltholicUI.bioList = LeoAltholicBioList:New(LeoAltholicWindowBioPanelListScroll)
    LeoAltholicUI.statsList = LeoAltholicStatsList:New(LeoAltholicWindowStatsPanelListScroll)
    LeoAltholicUI.championList = LeoAltholicChampionList:New(LeoAltholicWindowChampionPanelListScroll)
    LeoAltholicUI.skillsList = LeoAltholicSkillsList:New(LeoAltholicWindowSkillsPanelListScroll)
    LeoAltholicUI.skills2List = LeoAltholicSkills2List:New(LeoAltholicWindowSkills2PanelListScroll)
    LeoAltholicUI.writsList = LeoAltholicWritsList:New(LeoAltholicWindowWritsPanelListScroll)
    LeoAltholicUI.invList = LeoAltholicInventoryList:New(LeoAltholicWindowInventoryPanelListScroll)
    LeoAltholicUI.researchList = LeoAltholicResearchList:New(LeoAltholicWindowResearchPanelListScroll)

    LeoAltholic.GetCharacters(true)

    local lists = {
        LeoAltholicUI.bioList,
        LeoAltholicUI.statsList,
        LeoAltholicUI.championList,
        LeoAltholicUI.skillsList,
        LeoAltholicUI.skills2List,
        LeoAltholicUI.writsList,
        LeoAltholicUI.invList,
        LeoAltholicUI.researchList,
    }
    for _, listObj in ipairs(lists) do
        if listObj then
            listObj.currentSortKey = "queueIndex"
            listObj.currentSortOrder = ZO_SORT_ORDER_UP
            listObj:RefreshData()
        end
    end

    LeoAltholicUI.InitTrackedPanel()
end

