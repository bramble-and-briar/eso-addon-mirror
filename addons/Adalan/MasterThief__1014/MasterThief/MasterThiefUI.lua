-- MasterThiefUI.lua
-- UI module for MasterThief addon

if not MasterThief then
    MasterThief = {}
end

-- Local reference for performance
local MT = MasterThief

----------------------------------------
-- Scroll List Functions
----------------------------------------
local ROW_TYPE_ID = 1

local function CreateScrollList(scrollData)
    local scrollList = WINDOW_MANAGER:CreateControlFromVirtual(scrollData.name, scrollData.parent, "ZO_ScrollList")
    scrollList:SetDimensions(scrollData.width, scrollData.height)
    ZO_ScrollList_AddDataType(scrollList, ROW_TYPE_ID, scrollData.rowTemplate or "ZO_SelectableLabel", scrollData.rowHeight, scrollData.setupCallback)
    return scrollList
end

local function UpdateScrollList(scrollList, dataTable)
    local dataList = ZO_ScrollList_GetDataList(scrollList)
    ZO_ScrollList_Clear(scrollList)
    for _, dataItem in ipairs(dataTable) do
        local entry = ZO_ScrollList_CreateDataEntry(ROW_TYPE_ID, dataItem)
        table.insert(dataList, entry)
    end
    ZO_ScrollList_Commit(scrollList)
end
														   
function MasterThief.SetupDataRow(rowControl, data, scrollList)
    rowControl:SetText(data[1])
    rowControl:SetFont("ZoFontGame")

    -- Event for mouse clicks
    rowControl:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside then
            if button == 2 then -- Delete with right mouse button
                if MasterThief:removeFromList(data[1]) then 
                    d(data[1]..GetString(MT_MISC_LOOTLIST_DELETE)) 
                    MasterThief:RefreshLootlistWindow()
                end
            end	
        end
    end)
    
    rowControl:SetHandler("OnMouseEnter", function(self)
        if not data or not data[1] then return end
        InitializeTooltip(ItemTooltip, self, RIGHT, -5, 0)
        ItemTooltip:SetLink(data[1])
    end)
    
    rowControl:SetHandler("OnMouseExit", function()
        ClearTooltip(ItemTooltip)
    end)
end

function MasterThief:CreateLootlistWindow()
    if self.lootlistWindow then return end

    local win = WINDOW_MANAGER:CreateTopLevelWindow("MasterThiefLootlistWindow")
    win:SetDimensions(700, 600)
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetAnchor(CENTER, GuiRoot, CENTER)

    -- Background
    local bg = WINDOW_MANAGER:CreateControl(nil, win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    ApplyTemplateToControl(bg, "ZO_DefaultBackdrop")

    -- Title
    local title = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
    title:SetFont("$(PROSE_ANTIQUE_FONT)|30|soft-shadow-thin")
    title:SetText("MasterThief")
    title:SetAnchor(TOP, win, TOP, 0, 10)

    -- Close
    local close = WINDOW_MANAGER:CreateControl(nil, win, CT_BUTTON)
    close:SetDimensions(32, 32)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, 2, 5)
    close:SetNormalTexture("EsoUI/Art/Buttons/closebutton_up.dds")
    close:SetPressedTexture("EsoUI/Art/Buttons/closebutton_down.dds")
    close:SetMouseOverTexture("EsoUI/Art/Buttons/closebutton_mouseover.dds")
    close:SetHandler("OnClicked", function()
        win:SetHidden(true)
    end)

    self.lootlistWindow = win

    -- Panels
    self:CreatePanels(win)
    self:CreateNavButtons(win)

    -- Default view: loot list
    self:ShowLootPanel()
end

function MasterThief:CreatePanels(win)
    -- Loot panel
    local lootPanel = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    lootPanel:SetAnchor(TOPLEFT, win, TOPLEFT, 10, 88)
    lootPanel:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -10, -60)
    lootPanel:SetHidden(false)

    -- CREATE scrollList HERE if doesn't exist
    if not scrollList then
        
        local scrollData = {
            name = "MT_ScrollListData",
            parent = lootPanel,
            width = 480,
            height = 500,
            rowHeight = 30,
            setupCallback = MasterThief.SetupDataRow,
        }
        
        scrollList = CreateScrollList(scrollData)
        scrollList:SetAnchor(TOPLEFT, lootPanel, TOPLEFT, 5, 5)
        scrollList:SetAnchor(BOTTOMRIGHT, lootPanel, BOTTOMRIGHT, -5, -35)
        
        if scrollListData and #scrollListData > 0 then
            UpdateScrollList(scrollList, scrollListData)
            d("[MasterThief] Loaded " .. #scrollListData .. " items into scrollList")
        end
    else
        scrollList:SetParent(lootPanel)
        scrollList:ClearAnchors()
        scrollList:SetAnchor(TOPLEFT, lootPanel, TOPLEFT, 5, 5)
        scrollList:SetAnchor(BOTTOMRIGHT, lootPanel, BOTTOMRIGHT, -5, -35)
    end

    self.lootPanel = lootPanel
    
    -- Counter
    local counter = WINDOW_MANAGER:CreateControl(nil, lootPanel, CT_LABEL)
    counter:SetFont("$(PROSE_ANTIQUE_FONT)|18")
    counter:SetAnchor(BOTTOMLEFT, lootPanel, BOTTOMLEFT, 5, -5)
    counter:SetText("Total: " .. self:countItemsOnLootlist())
    self.lootlistCounter = counter

    -- Stats panel
    local statsPanel = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    statsPanel:SetAnchorFill(lootPanel)
    statsPanel:SetHidden(true)
    self.statsPanel = statsPanel
    
    -- CREATE STATS SUB-PANELS
    
    -- Session Stats Panel
    local sessionStatsPanel = WINDOW_MANAGER:CreateControl(nil, statsPanel, CT_CONTROL)
    sessionStatsPanel:SetAnchor(TOPLEFT, statsPanel, TOPLEFT, 10, 5)
    sessionStatsPanel:SetAnchor(BOTTOMRIGHT, statsPanel, BOTTOMRIGHT, -10, -10)
    sessionStatsPanel:SetHidden(false)  -- Show by default
    self.sessionStatsPanel = sessionStatsPanel
    
    -- Lifetime Stats Panel
    local lifetimeStatsPanel = WINDOW_MANAGER:CreateControl(nil, statsPanel, CT_CONTROL)
    lifetimeStatsPanel:SetAnchor(TOPLEFT, statsPanel, TOPLEFT, 10, 5)
    lifetimeStatsPanel:SetAnchor(BOTTOMRIGHT, statsPanel, BOTTOMRIGHT, -10, -10)
    lifetimeStatsPanel:SetHidden(true)  -- Hidden by default
    self.lifetimeStatsPanel = lifetimeStatsPanel
    
    -- Create the actual stats displays
    self:CreateSessionStatsDisplay(sessionStatsPanel)
    self:CreateLifetimeStatsDisplay(lifetimeStatsPanel)
end

function MasterThief:CreateNavButtons(win)
    local buttonWidth = 120
    local buttonHeight = 30

    local function MakeButton(parent, label, offsetX, offsetY, anchorPoint)
        local btn = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
        btn:SetDimensions(buttonWidth, buttonHeight)
        btn:SetAnchor(anchorPoint, parent, anchorPoint, offsetX, offsetY)
		
		-- Background with ESO gold border
        local bg = WINDOW_MANAGER:CreateControl(nil, btn, CT_BACKDROP)
        bg:SetAnchorFill(btn)
        ApplyTemplateToControl(bg, "ZO_DefaultBackdrop")

        local text = WINDOW_MANAGER:CreateControl(nil, btn, CT_LABEL)
        text:SetFont("$(PROSE_ANTIQUE_FONT)|20")
        text:SetText(label)
        text:SetDimensions(buttonWidth, buttonHeight)
        text:SetAnchor(CENTER, btn, CENTER, 0, 0)
        text:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        text:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        btn.label = text
        return btn
    end

    -- TOP: Session and Lifetime buttons (always visible, switch stats sub-tab)
    local sessionBtn = MakeButton(win, "Session", -70, 55, TOP)
    sessionBtn.label:SetColor(0.7, 0.7, 0.7, 1)  -- start inactive; ShowLootPanel sets final state
    sessionBtn:SetHandler("OnClicked", function()
        self:ShowStatsPanel("session")
    end)
    self.sessionStatsTabButton = sessionBtn
    
    local lifetimeBtn = MakeButton(win, "Lifetime", 70, 55, TOP)
    lifetimeBtn.label:SetColor(0.7, 0.7, 0.7, 1)  -- Start as inactive (gray)
    lifetimeBtn:SetHandler("OnClicked", function()
        self:ShowStatsPanel("lifetime")
    end)
    self.lifetimeStatsTabButton = lifetimeBtn

    -- BOTTOM: single centered Loot List button
    local lootBtn = MakeButton(win, "Loot List", 0, -10, BOTTOM)
    lootBtn.label:SetColor(1, 0.85, 0, 1)  -- start active (gold) since loot panel is default
    lootBtn:SetHandler("OnClicked", function()
        self:ShowLootPanel()
    end)
    self.lootListTabButton = lootBtn
end

-- Show the loot list panel; top buttons go gray, loot button goes gold
function MasterThief:ShowLootPanel()
    self.lootPanel:SetHidden(false)
    self.statsPanel:SetHidden(true)

    self.lootListTabButton.label:SetColor(1, 0.85, 0, 1)
    self.sessionStatsTabButton.label:SetColor(0.7, 0.7, 0.7, 1)
    self.lifetimeStatsTabButton.label:SetColor(0.7, 0.7, 0.7, 1)

    self:RefreshLootlistWindow()
end

-- Show the stats panel and select a sub-tab; loot button goes gray, chosen stat button goes gold
function MasterThief:ShowStatsPanel(subTab)
    self.lootPanel:SetHidden(true)
    self.statsPanel:SetHidden(false)

    self.lootListTabButton.label:SetColor(0.7, 0.7, 0.7, 1)
	
    if subTab == "session" then
        self.sessionStatsPanel:SetHidden(false)
        self.lifetimeStatsPanel:SetHidden(true)
        
        self.sessionStatsTabButton.label:SetColor(1, 0.85, 0, 1)  -- Active - gold
        self.lifetimeStatsTabButton.label:SetColor(0.7, 0.7, 0.7, 1)  -- Inactive - gray
        self:UpdateSessionStatsDisplay()
    else
        self.sessionStatsPanel:SetHidden(true)
        self.lifetimeStatsPanel:SetHidden(false)
        
        self.sessionStatsTabButton.label:SetColor(0.7, 0.7, 0.7, 1)  -- Inactive - gray
        self.lifetimeStatsTabButton.label:SetColor(1, 0.85, 0, 1)  -- Active - gold
        self:UpdateLifetimeStatsDisplay()
    end
end

function MasterThief:CreateSessionStatsDisplay(panel)
    local yOffset = 10
    local leftCol = 10
    local leftValueCol = 240
    local rightCol = 360
    local rightValueCol = 590
    local labelHeight = 25
    
    -- Title
    local title = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    title:SetFont("$(PROSE_ANTIQUE_FONT)|24")
    title:SetText(GetString(MT_STATS_SESSION_HEADER))
    title:SetColor(1, 0.8, 0, 1)
    yOffset = yOffset + 35
    
    -- Helper function to create stat rows
    local function CreateStatRow(text, valueControlName, useRightColumn)
        local xCol = useRightColumn and rightCol or leftCol
        local xValueCol = useRightColumn and rightValueCol or leftValueCol
        
        local label = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
        label:SetAnchor(TOPLEFT, panel, TOPLEFT, xCol, yOffset)
        label:SetFont("ZoFontGame")
        label:SetText(text)
        
        local value = WINDOW_MANAGER:CreateControl(valueControlName, panel, CT_LABEL)
        value:SetAnchor(TOPLEFT, panel, TOPLEFT, xValueCol, yOffset)
        value:SetFont("ZoFontGame")
        value:SetText("0")
        value:SetColor(0.8, 0.8, 0.8, 1)
        
        yOffset = yOffset + labelHeight
        return value
    end
    
    -- Create stat labels and value controls
    -- Reset yOffset for first column
   local leftColY = yOffset
   local rightColY = yOffset
    
    self.sessionStatsLabels = {
        -- LEFT COLUMN - Looting Stats
        itemsLooted = CreateStatRow(GetString(MT_STATS_ITEMS_LOOTED), "MT_SessionStat_ItemsLooted", false),
        itemsSkipped = CreateStatRow(GetString(MT_STATS_ITEMS_SKIPPED), "MT_SessionStat_ItemsSkipped", false),
        motifsLooted = CreateStatRow(GetString(MT_STATS_MOTIFS_LOOTED), "MT_SessionStat_Motifs", false),
        recipesLooted = CreateStatRow(GetString(MT_STATS_RECIPES_LOOTED), "MT_SessionStat_Recipes", false),
        furnishingPlansLooted = CreateStatRow(GetString(MT_STATS_FURNISHING_PLANS), "MT_SessionStat_Plans", false),
        furnishingsLooted = CreateStatRow(GetString(MT_STATS_FURNISHINGS), "MT_SessionStat_Furnishings", false),
        hiddenWalletsLooted = CreateStatRow(GetString(MT_STATS_HIDDEN_WALLETS), "MT_SessionStat_Wallets", false),
        researchPortfoliosLooted = CreateStatRow(GetString(MT_STATS_RESEARCH_PORTFOLIOS), "MT_SessionStat_Portfolios", false),
		edictsLooted = CreateStatRow(GetString(MT_STATS_EDICTS), "MT_SessionStat_Edicts", false),
    }
    
    -- Reset yOffset for second column
    leftColY = yOffset  -- Save where left column ended
    yOffset = rightColY  -- Reset to start of right column
    
    local moreLabels = {
        -- RIGHT COLUMN - Justice Stats
		successfulPickpockets = CreateStatRow(GetString(MT_STATS_PICKPOCKETS), "MT_SessionStat_Pickpockets", true),
        safeboxesLockpicked = CreateStatRow(GetString(MT_STATS_SAFEBOXES), "MT_SessionStat_Safeboxes", true),
        doorsLockpicked = CreateStatRow(GetString(MT_STATS_DOORS), "MT_SessionStat_Doors", true),
		lockpickBreaksPrevented = CreateStatRow(GetString(MT_STATS_LOCKPICK_BREAKS_PREVENTED), "MT_SessionStat_LockpickBreaks", true),
		bladeOfWoeKills = CreateStatRow(GetString(MT_STATS_BOW_KILLS), "MT_SessionStat_BoW", true),
        deathsByGuards = CreateStatRow(GetString(MT_STATS_GUARD_DEATHS), "MT_SessionStat_Guards", true),
        totalFencedGold = CreateStatRow(GetString(MT_STATS_GOLD_FENCED), "MT_SessionStat_Fenced", true),
        goldSpentLaundering = CreateStatRow(GetString(MT_STATS_GOLD_LAUNDERED), "MT_SessionStat_Laundered", true),
        highestBounty = CreateStatRow(GetString(MT_STATS_HIGHEST_BOUNTY), "MT_SessionStat_Bounty", true),
    }
	
	rightColY = yOffset  -- Save where right column ended
    
    -- Merge the two tables
    for k, v in pairs(moreLabels) do
        self.sessionStatsLabels[k] = v
    end
    
    -- Use the taller column for subsequent elements
    yOffset = math.max(leftColY, rightColY)
    
    yOffset = yOffset + 15
    
    -- Highest value item
    local highestLabel = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
    highestLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    highestLabel:SetFont("ZoFontGame")
    highestLabel:SetText(GetString(MT_STATS_HIGHEST_VALUE))
    
    local highestValue = WINDOW_MANAGER:CreateControl("MT_SessionStat_Highest", panel, CT_LABEL)
    highestValue:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset + labelHeight)
    highestValue:SetFont("ZoFontGame")
    highestValue:SetText("None")
    highestValue:SetColor(0.8, 0.8, 0.8, 1)
    self.sessionStatsLabels.highestValue = highestValue
    
    yOffset = yOffset + labelHeight * 2 + 20
    
    -- Reset button
    local resetBtn = WINDOW_MANAGER:CreateControl(nil, panel, CT_BUTTON)
    resetBtn:SetDimensions(150, 30)
    resetBtn:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    
    -- Background with border
    local resetBg = WINDOW_MANAGER:CreateControl(nil, resetBtn, CT_BACKDROP)
    resetBg:SetAnchorFill(resetBtn)
    ApplyTemplateToControl(resetBg, "ZO_DefaultBackdrop")
    
    -- Label
    local resetLabel = WINDOW_MANAGER:CreateControl(nil, resetBtn, CT_LABEL)
    resetLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
    resetLabel:SetText(GetString(MT_STATS_RESET_SESSION))
    resetLabel:SetAnchor(CENTER)
    resetLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    resetLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    resetLabel:SetColor(1, 0.85, 0, 1)
    
    resetBtn:SetHandler("OnClicked", function()
        self:ResetSessionStats()
    end)
end

function MasterThief:CreateLifetimeStatsDisplay(panel)
    local leftCol = 10
    local leftValueCol = 240
    local rightCol = 360
    local rightValueCol = 590
    local labelHeight = 25
    
    -- Title
    local yOffset = 10
    local title = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    title:SetFont("$(PROSE_ANTIQUE_FONT)|24")
    title:SetText(GetString(MT_STATS_LIFETIME_HEADER))
    title:SetColor(1, 0.8, 0, 1)
    yOffset = yOffset + 35
    
    -- Separate Y positions for each column
    local leftColY = yOffset
    local rightColY = yOffset
    
    -- Helper function to create stat rows
    local function CreateStatRow(text, valueControlName, useRightColumn)
        local xCol = useRightColumn and rightCol or leftCol
        local xValueCol = useRightColumn and rightValueCol or leftValueCol
        
        -- Use the appropriate column's Y position
        local currentY = useRightColumn and rightColY or leftColY
        
        local label = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
        label:SetAnchor(TOPLEFT, panel, TOPLEFT, xCol, currentY)
        label:SetFont("ZoFontGame")
        label:SetText(text)
        
        local value = WINDOW_MANAGER:CreateControl(valueControlName, panel, CT_LABEL)
        value:SetAnchor(TOPLEFT, panel, TOPLEFT, xValueCol, currentY)
        value:SetFont("ZoFontGame")
        value:SetText("0")
        value:SetColor(0.8, 0.8, 0.8, 1)
        
        -- Increment the appropriate column's Y position
        if useRightColumn then
            rightColY = rightColY + labelHeight
        else
            leftColY = leftColY + labelHeight
        end
        
        return value
    end
    
    -- Reset yOffset for first column
    local firstColY = yOffset
    
    self.lifetimeStatsLabels = {
        -- LEFT COLUMN - Looting Stats
        itemsLooted = CreateStatRow(GetString(MT_STATS_ITEMS_LOOTED), "MT_LifetimeStat_ItemsLooted", false),
        itemsSkipped = CreateStatRow(GetString(MT_STATS_ITEMS_SKIPPED), "MT_LifetimeStat_ItemsSkipped", false),
        motifsLooted = CreateStatRow(GetString(MT_STATS_MOTIFS_LOOTED), "MT_LifetimeStat_Motifs", false),
        recipesLooted = CreateStatRow(GetString(MT_STATS_RECIPES_LOOTED), "MT_LifetimeStat_Recipes", false),
        furnishingPlansLooted = CreateStatRow(GetString(MT_STATS_FURNISHING_PLANS), "MT_LifetimeStat_Plans", false),
        furnishingsLooted = CreateStatRow(GetString(MT_STATS_FURNISHINGS), "MT_LifetimeStat_Furnishings", false),
        hiddenWalletsLooted = CreateStatRow(GetString(MT_STATS_HIDDEN_WALLETS), "MT_LifetimeStat_Wallets", false),
        researchPortfoliosLooted = CreateStatRow(GetString(MT_STATS_RESEARCH_PORTFOLIOS), "MT_LifetimeStat_Portfolios", false),
		edictsLooted = CreateStatRow(GetString(MT_STATS_EDICTS), "MT_LifetimeStat_Edicts", false),
    }
    
    -- Reset yOffset for second column
    yOffset = firstColY
    
    local moreLabels = {
        -- RIGHT COLUMN - Justice Stats
		successfulPickpockets = CreateStatRow(GetString(MT_STATS_PICKPOCKETS), "MT_LifetimeStat_Pickpockets", true),
        safeboxesLockpicked = CreateStatRow(GetString(MT_STATS_SAFEBOXES), "MT_LifetimeStat_Safeboxes", true),
        doorsLockpicked = CreateStatRow(GetString(MT_STATS_DOORS), "MT_LifetimeStat_Doors", true),
		lockpickBreaksPrevented = CreateStatRow(GetString(MT_STATS_LOCKPICK_BREAKS_PREVENTED), "MT_LifetimeStat_LockpickBreaks", true),
		bladeOfWoeKills = CreateStatRow(GetString(MT_STATS_BOW_KILLS), "MT_LifetimeStat_BoW", true),
        deathsByGuards = CreateStatRow(GetString(MT_STATS_GUARD_DEATHS), "MT_LifetimeStat_Guards", true),
		thievesTrovesLooted = CreateStatRow(GetString(MT_STATS_TROVES), "MT_LifetimeStat_Troves", true),
        totalFencedGold = CreateStatRow(GetString(MT_STATS_GOLD_FENCED), "MT_LifetimeStat_Fenced", true),
        goldSpentLaundering = CreateStatRow(GetString(MT_STATS_GOLD_LAUNDERED), "MT_LifetimeStat_Laundered", true),
        highestBounty = CreateStatRow(GetString(MT_STATS_HIGHEST_BOUNTY), "MT_LifetimeStat_Bounty", true),
		paidBountyTotal = CreateStatRow(GetString(MT_STATS_LIFETIME_BOUNTY_PAID), "MT_LifetimeStat_Paid", true),
    }
    
    -- Merge the two tables
    for k, v in pairs(moreLabels) do
        self.lifetimeStatsLabels[k] = v
    end
    
    -- Use the taller column for subsequent elements
    yOffset = math.max(leftColY, rightColY)
    
    yOffset = yOffset + 15
    
    -- Highest value item
    local highestLabel = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
    highestLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    highestLabel:SetFont("ZoFontGame")
    highestLabel:SetText(GetString(MT_STATS_HIGHEST_VALUE))
    
    local highestValue = WINDOW_MANAGER:CreateControl("MT_LifetimeStat_Highest", panel, CT_LABEL)
    highestValue:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset + labelHeight)
    highestValue:SetFont("ZoFontGame")
    highestValue:SetText("None")
    highestValue:SetColor(0.8, 0.8, 0.8, 1)
    self.lifetimeStatsLabels.highestValue = highestValue
    
    yOffset = yOffset + labelHeight * 2 + 20
    
    -- Reset button (with confirmation)
    local resetBtn = WINDOW_MANAGER:CreateControl(nil, panel, CT_BUTTON)
    resetBtn:SetDimensions(150, 30)
    resetBtn:SetAnchor(TOPLEFT, panel, TOPLEFT, leftCol, yOffset)
    
    -- Background with border
    local resetBg = WINDOW_MANAGER:CreateControl(nil, resetBtn, CT_BACKDROP)
    resetBg:SetAnchorFill(resetBtn)
    ApplyTemplateToControl(resetBg, "ZO_DefaultBackdrop")
 
    -- Label
    local resetLabel = WINDOW_MANAGER:CreateControl(nil, resetBtn, CT_LABEL)
    resetLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
    resetLabel:SetText(GetString(MT_STATS_RESET_LIFETIME))
    resetLabel:SetAnchor(CENTER)
resetLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    resetLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    resetLabel:SetColor(1, 0.85, 0, 1)
    
    resetBtn:SetHandler("OnClicked", function()
        -- Show confirmation dialog
        ZO_Dialogs_ShowDialog("MT_CONFIRM_RESET_LIFETIME")
    end)
end

local TAB_INACTIVE_BG = { 0.15, 0.15, 0.15, 0.9 }
local TAB_ACTIVE_BG   = { 0.22, 0.24, 0.25, 0.95 }

local TAB_GLOW_COLOR  = { 0.45, 0.65, 0.70, 1 } -- muted teal-silver

function MasterThief:RefreshLootlistWindow()
    if not scrollList then return end

    -- Rebuild data from saved vars
    scrollListData = {}
    for _, obj in ipairs(self.SavedVarsLoots.Worthful or {}) do
        table.insert(scrollListData, { obj[1] })
    end

    -- Update scroll list
    UpdateScrollList(scrollList, scrollListData)

    -- Update counter
    if self.lootlistCounter then
        self.lootlistCounter:SetText(
            "Total: " .. self:countItemsOnLootlist()
        )
    end
end

function MasterThief:UpdateSessionStatsDisplay()
    if not self.sessionStatsLabels then return end
    
    local stats = MasterThief.SessionStats
    
    self.sessionStatsLabels.itemsLooted:SetText(tostring(stats.itemsLooted))
    self.sessionStatsLabels.itemsSkipped:SetText(tostring(stats.itemsSkipped))
    self.sessionStatsLabels.motifsLooted:SetText(tostring(stats.motifsLooted))
    self.sessionStatsLabels.recipesLooted:SetText(tostring(stats.recipesLooted))
    self.sessionStatsLabels.furnishingPlansLooted:SetText(tostring(stats.furnishingPlansLooted))
    self.sessionStatsLabels.furnishingsLooted:SetText(tostring(stats.furnishingsLooted))
    self.sessionStatsLabels.hiddenWalletsLooted:SetText(tostring(stats.hiddenWalletsLooted or 0))
    self.sessionStatsLabels.researchPortfoliosLooted:SetText(tostring(stats.researchPortfoliosLooted or 0))
	self.sessionStatsLabels.edictsLooted:SetText(tostring(stats.edictsLooted or 0))
	self.sessionStatsLabels.safeboxesLockpicked:SetText(tostring(MasterThief.SessionStats.safeboxesLockpicked or 0))
	self.sessionStatsLabels.doorsLockpicked:SetText(tostring(MasterThief.SessionStats.doorsLockpicked or 0))
	self.sessionStatsLabels.lockpickBreaksPrevented:SetText(tostring(MasterThief.SessionStats.lockpickBreaksPrevented or 0))
	self.sessionStatsLabels.deathsByGuards:SetText(tostring(MasterThief.SessionStats.deathsByGuards or 0))
	self.sessionStatsLabels.totalFencedGold:SetText(tostring(MasterThief.SessionStats.totalFencedGold or 0) .. "g")
	self.sessionStatsLabels.goldSpentLaundering:SetText(tostring(MasterThief.SessionStats.goldSpentLaundering or 0) .. "g")
	self.sessionStatsLabels.highestBounty:SetText(tostring(MasterThief.SessionStats.highestBounty or 0) .. "g")
	self.sessionStatsLabels.bladeOfWoeKills:SetText(tostring(MasterThief.SessionStats.bladeOfWoeKills or 0))
	self.sessionStatsLabels.successfulPickpockets:SetText(tostring(MasterThief.SessionStats.successfulPickpockets or 0))
    
    if stats.highestValueItemLooted.value > 0 then
        self.sessionStatsLabels.highestValue:SetText(
            stats.highestValueItemLooted.link .. " (" .. stats.highestValueItemLooted.value .. "g)"
        )
    else
        self.sessionStatsLabels.highestValue:SetText("None")
    end
end

function MasterThief:UpdateLifetimeStatsDisplay()
    if not self.lifetimeStatsLabels then return end
    
    local stats = MasterThief.SavedVarsLifetimeStats
    
    self.lifetimeStatsLabels.itemsLooted:SetText(tostring(stats.itemsLooted))
    self.lifetimeStatsLabels.itemsSkipped:SetText(tostring(stats.itemsSkipped))
    self.lifetimeStatsLabels.motifsLooted:SetText(tostring(stats.motifsLooted))
    self.lifetimeStatsLabels.recipesLooted:SetText(tostring(stats.recipesLooted))
    self.lifetimeStatsLabels.furnishingPlansLooted:SetText(tostring(stats.furnishingPlansLooted))
    self.lifetimeStatsLabels.furnishingsLooted:SetText(tostring(stats.furnishingsLooted))
    self.lifetimeStatsLabels.hiddenWalletsLooted:SetText(tostring(stats.hiddenWalletsLooted or 0))
    self.lifetimeStatsLabels.researchPortfoliosLooted:SetText(tostring(stats.researchPortfoliosLooted or 0))
	self.lifetimeStatsLabels.safeboxesLockpicked:SetText(tostring(stats.safeboxesLockpicked or 0))
	self.lifetimeStatsLabels.doorsLockpicked:SetText(tostring(stats.doorsLockpicked or 0))
	self.lifetimeStatsLabels.lockpickBreaksPrevented:SetText(tostring(stats.lockpickBreaksPrevented or 0))
	self.lifetimeStatsLabels.edictsLooted:SetText(tostring(stats.edictsLooted or 0))
	self.lifetimeStatsLabels.thievesTrovesLooted:SetText(tostring(stats.thievesTrovesLooted or 0))
	self.lifetimeStatsLabels.deathsByGuards:SetText(tostring(stats.deathsByGuards or 0))
	self.lifetimeStatsLabels.totalFencedGold:SetText(tostring(stats.totalFencedGold or 0) .. "g")
	self.lifetimeStatsLabels.goldSpentLaundering:SetText(tostring(stats.goldSpentLaundering or 0) .. "g")
	self.lifetimeStatsLabels.highestBounty:SetText(tostring(stats.highestBounty or 0) .. "g")
	self.lifetimeStatsLabels.successfulPickpockets:SetText(tostring(stats.successfulPickpockets or 0))
	self.lifetimeStatsLabels.bladeOfWoeKills:SetText(tostring(stats.bladeOfWoeKills or 0))
	self.lifetimeStatsLabels.paidBountyTotal:SetText(tostring(stats.paidBountyTotal or 0) .. "g")

    if stats.highestValueItemLooted and stats.highestValueItemLooted.value > 0 then
        self.lifetimeStatsLabels.highestValue:SetText(
            stats.highestValueItemLooted.link .. " (" .. stats.highestValueItemLooted.value .. "g)"
        )
    else
        self.lifetimeStatsLabels.highestValue:SetText("None")
    end
end

function MasterThief:ToggleLootlistWindow()
    if not self.lootlistWindow then
        self:CreateLootlistWindow()
    end
    
    local win = self.lootlistWindow
    local isHidden = win:IsHidden()
    
    win:SetHidden(not isHidden)

        -- Refresh the appropriate panel based on which is visible
        if self.statsPanel and not self.statsPanel:IsHidden() then
            -- Stats panel is active, refresh it
            self:UpdateSessionStatsDisplay()
            self:UpdateLifetimeStatsDisplay()
        elseif self.lootPanel and not self.lootPanel:IsHidden() then
            -- Loot panel is active, refresh loot list
            self:RefreshLootlistWindow()
        end
end

----------------------------------------
-- Create On-Screen Message Box
----------------------------------------
function MasterThief:CreateMessageBox()
	-- Only create once - prevents duplicate control errors on reload/zone change
	if ctlMasterThief then 
		return 
	end
	local msgBox = WINDOW_MANAGER:CreateTopLevelWindow("ctlMasterThief")
	msgBox:SetDimensions(1800, 50)
	msgBox:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
	msgBox:SetMouseEnabled(true)
	msgBox:SetMovable(true)
	msgBox:SetClampedToScreen(true)
	msgBox:SetHandler("OnMoveStop", function() MasterThief.WinMoveStop() end)
	
	local label = WINDOW_MANAGER:CreateControl("ctlMasterThiefLabel", msgBox, CT_LABEL)
	label:SetDimensions(1800, 50)
	label:SetAnchor(LEFT, msgBox, LEFT, 0, 0)
	label:SetFont("ZoFontWinH1")
	label:SetColor(1, 0.8, 0.67, 1)
	label:SetText("")
	label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	label:SetVerticalAlignment(TEXT_ALIGN_TOP)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	
	_G["ctlMasterThief"] = msgBox
	_G["ctlMasterThiefLabel"] = label
end