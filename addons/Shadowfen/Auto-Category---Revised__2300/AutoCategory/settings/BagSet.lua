local AC = AutoCategory
local SF = LibSFUtils

local L = GetString
local CVT = AutoCategory.CVT

local logDebug = AutoCategory.logDebug
local logWouldDebug = AutoCategory.logWouldDebug

--cache data for dropdown: 
AutoCategory.cache.bags_cvt.choices = {
	L(SI_AC_BAGTYPE_SHOWNAME_BACKPACK),
	L(SI_AC_BAGTYPE_SHOWNAME_BANK),
	L(SI_AC_BAGTYPE_SHOWNAME_GUILDBANK),
	L(SI_AC_BAGTYPE_SHOWNAME_CRAFTBAG),
	L(SI_AC_BAGTYPE_SHOWNAME_CRAFTSTATION),
	L(SI_AC_BAGTYPE_SHOWNAME_HOUSEBANK),
	L(SI_AC_BAGTYPE_SHOWNAME_FURNVAULT),
	L(SI_AC_BAGTYPE_SHOWNAME_VENGEANCE),
}
AutoCategory.cache.bags_cvt.choicesValues = {
	AC_BAG_TYPE_BACKPACK,
	AC_BAG_TYPE_BANK,
	AC_BAG_TYPE_GUILDBANK,
	AC_BAG_TYPE_CRAFTBAG,
	AC_BAG_TYPE_CRAFTSTATION,
	AC_BAG_TYPE_HOUSEBANK,
	AC_BAG_TYPE_FURNVAULT,
	AC_BAG_TYPE_VENGEANCE,
}
AutoCategory.cache.bags_cvt.choicesTooltips = {
	L(SI_AC_BAGTYPE_TOOLTIP_BACKPACK),
	L(SI_AC_BAGTYPE_TOOLTIP_BANK),
	L(SI_AC_BAGTYPE_TOOLTIP_GUILDBANK),
	L(SI_AC_BAGTYPE_TOOLTIP_CRAFTBAG),
	L(SI_AC_BAGTYPE_TOOLTIP_CRAFTSTATION),
	L(SI_AC_BAGTYPE_TOOLTIP_HOUSEBANK),
	L(SI_AC_BAGTYPE_TOOLTIP_FURNVAULT),
	L(SI_AC_BAGTYPE_TOOLTIP_VENGEANCE),

}


-- local to this screen
local BagSet_SelectBag_LAM = AC.BaseDD:New("AC_DROPDOWN_EDITBAG_BAG", AC_BAG_TYPE_BACKPACK, CVT.USE_VALUES + CVT.USE_TOOLTIPS)
local BagSet_HideOther_LAM = AC.BaseUI:New("AC_CHECKBOX_HIDEOTHER")	-- checkbox

local BagSet_SelectRule_LAM = AC.BaseDD:New("AC_DROPDOWN_EDITBAG_RULE", nil, CVT.USE_VALUES + CVT.USE_TOOLTIPS)
AC_UI.BagSet_SelectRule_LAM = BagSet_SelectRule_LAM

local BagSet_ShowRule_LAM = AC.BaseDD:New("AC_DROPDOWN_SHOWBAG_RULE", nil, CVT.USE_VALUES + CVT.USE_TOOLTIPS)
AC_UI.BagSet_ShowRule_LAM = BagSet_ShowRule_LAM

-- local to this screen
local BagSet_RunPriority_LAM = AC.BaseUI:New()		-- slider
local BagSet_ShowPriority_LAM = AC.BaseUI:New()		-- slider
local BagSet_ShowCatOrder_LAM = AC.BaseUI:New()	-- button
local BagSet_HideCat_LAM = AC.BaseUI:New()		-- checkbox
local BagSet_EditCat_LAM = AC.BaseUI:New()	-- button
local BagSet_RemoveCat_LAM = AC.BaseUI:New()	-- button
AC_UI.BagSet_RemoveCat_LAM = BagSet_RemoveCat_LAM -- make accessible to DisplayOrderWin
AC_UI.BagSet_EditCat_LAM = BagSet_EditCat_LAM -- make accessible to DisplayOrderWin

local AddCat_SelectTag_LAM = AC.BaseDD:New("AC_DROPDOWN_ADDCATEGORY_TAG")	-- only uses choices
AC_UI.AddCat_SelectTag_LAM = AddCat_SelectTag_LAM

local AddCat_SelectRule_LAM = AC.BaseDD:New("AC_DROPDOWN_ADDCATEGORY_RULE",nil ,CVT.USE_TOOLTIPS) -- uses choicesTooltips
AC_UI.AddCat_SelectRule_LAM = AddCat_SelectRule_LAM

-- local to this screen
local AddCat_EditRule_LAM = AC.BaseUI:New()	-- button
local AddCat_BagAdd_LAM = AC.BaseUI:New()	-- button
local ImpExp_ExportAll_LAM = AC.BaseUI:New()	-- button
local ImpExp_ImportBag_LAM = AC.BaseDD:New("AC_DROPDOWN_IMPORTBAG_BAG", nil, CVT.USE_VALUES + CVT.USE_TOOLTIPS)
local ImpExp_Import_LAM = AC.BaseUI:New()	-- button


AC_UI.BagSet = {}

local currentBagRule = nil
local currentRule = nil
local emptyValueTbl = {}        -- for CVT select() to select first

local function CatSet_DisplayRule(rule)
	AC_UI.CatSet_SelectTag_LAM:refresh()

	AC_UI.CatSet.setRule(rule)		-- sets tag and name

	currentRule = rule
	AC_UI.checkCurrentRule()
end

local function getCurrentBagId()
	return BagSet_SelectBag_LAM:getValue()
end
AutoCategory.getCurrentBagId = getCurrentBagId   -- make available

-- returns the current bagSetting table (or nil if the bag was not found)
-- if parameter bagId is nil then get the current bagId from BagSet
-- bagSetting table = {isOtherHidden, {rules{name, runpriority, showpriority, isHidden}} }
local function getBagSettings(bagId)
	if not bagId then bagId = getCurrentBagId() end
	local saved = AutoCategory.saved
	if saved and saved.bags then
		return saved.bags[bagId]	-- still might be nil
	end
	return nil
end



-- customization of BaseDD for BagSet_SelectBag_LAM
-- ------------------------------------------------
--[[ BagSet Select Bag Dropdown Control (AC_DROPDOWN_SELECTBAG).
    
    Dropdown control that displays the list of all bags
    available in the system. Allows users to select the active bag for configuration,
    rule viewing, priority adjustment, and other bag-specific operations.
    
    The dropdown is populated from the `saved.bags` table and dynamically updated
    when bags are added/removed. Maintains a mapping between bag IDs and their
    human-readable names for display purposes.
    
    @field controlName string  "AC_DROPDOWN_SELECTBAG"
    @field cvt         table   Choice Value Table (CVT.USE_TOOLTIPS enabled)
    @field refresh     function Reloads the dropdown from saved.bags
    @field assign      function LAM inherited: sets the CVT data source
    @field select      function LAM inherited: selects a specific value/index
    @field getValue    function LAM inherited: returns current selected bag ID
    @field setValue    function LAM inherited: programmatically set selection
    @field updateControl function LAM inherited: redraw the dropdown UI
    @field size        function Returns number of bag options
    
    Note   
		The dropdown is automatically refreshed when:
		- A new bag is detected (e.g., when player enters a bag container)
		- The saved.bags table is modified (export/import operations)
		- Menu is opened (initial population)
		- AC.cacheBagInitialize() is called
--]]

BagSet_SelectBag_LAM.defaultVal = AC_BAG_TYPE_BACKPACK

-- refresh the selection value of the cvt lists for BagSet_SelectBag_LAM from the 
-- current contents of the cache.bags_cvt list.
function BagSet_SelectBag_LAM:refresh()
	if self:getValue() == nil then
		self:select(AutoCategory.cache.bags_cvt.choicesValues)
	end
end

function BagSet_SelectBag_LAM:getValue()
	return self.cvt.indexValue
end

function BagSet_SelectBag_LAM:setValue(value)
	if value == self:getValue() then
		-- nothing to do because no change
		return
	end

	local bs = getBagSettings(value)
	if not bs then return end

	-- value will always be a valid cvt value, so we don't need to check CVT lists first
	self.cvt.indexValue = value
	-- we don't need to add/remove for the CVT as those lists are static

	BagSet_HideOther_LAM:setValue(SF.nilDefault(bs.isUngroupedHidden, false))

	-- manage related control values
	AC_UI.RefreshDropdownData()

	BagSet_SelectRule_LAM:clearIndex()
	BagSet_SelectRule_LAM:refresh()

	--reset add rule's selection, since all data will be changed.
	AddCat_SelectRule_LAM:clearIndex()
	AddCat_SelectRule_LAM:refresh()

	AC_UI.RefreshControls()
	AC_UI.BagSet_RefreshOrder()

end

function BagSet_SelectBag_LAM:controlDef()
	-- Bag     - AC_DROPDOWN_EDITBAG_BAG
	return
		{
			type = "dropdown",
			name = SI_AC_MENU_BS_DROPDOWN_BAG,
			scrollable = false,
			tooltip = L(SI_AC_MENU_BS_DROPDOWN_BAG_TOOLTIP),
			choices         = self.cvt.choices,
			choicesValues   = self.cvt.choicesValues,
			choicesTooltips = self.cvt.choicesTooltips,

			getFunc = function() return self:getValue() end,
			setFunc = function(value) self:setValue(value) end,
			default = AC_BAG_TYPE_BACKPACK,
			width = "half",
			reference = self:getControlName(),
		}
end
-- -------------------------------------------------------

-- customization of BaseUI for BagSet_HideOther_LAM checkbox
-- -------------------------------------------------------
--[[ BagSet Hide Other Rules Button Control (AC_BUTTON_HIDEOTHER).
    
    Button/checkbox control that toggles whether only
    rules for the currently selected bag are shown, or all rules from all
    bags are visible in the BagSet dropdown. When enabled, filters the
    BagSet_SelectRule dropdown to display only rules assigned to the active
    bag; when disabled, shows all available rules regardless of bag assignment.
    
    This is useful when managing large rule sets across multiple bags, as it
    reduces clutter by hiding unrelated rules that aren't assigned to the
    current bag being configured.
    
    @field controlName     string    "AC_BUTTON_HIDEOTHER"
    @field type            string    "button" or "checkbox" (depending on LAM version)
    @field name            string    Localized label text ("Hide Other Bags' Rules")
    @field tooltip         string    Tooltip explaining the toggle behavior
    @field func            function  Callback executed on click/change
    @field disabled        function  Returns true if bag has no rules (optional)
    @field width           string    "half" or "full" (toggle width)
    
    Note   
		When enabled (hiding other bags):
		- BagSet_SelectRule dropdown only shows rules from current bag
		- Rules from other bags are filtered out of the list
		- Makes it easier to focus on current bag's configuration
		- Does NOT delete or hide rules - just filters the dropdown view
--]]

function BagSet_HideOther_LAM:getValue()
	local bs = getBagSettings()
	if not bs then
		-- no such bag
		return false
	end
	return bs.isUngroupedHidden
end

function BagSet_HideOther_LAM:setValue(value)
	local bs = getBagSettings()
	if not bs then return false end

	if value == false then 
		value = nil
	end
	bs.isUngroupedHidden = value

end

function BagSet_HideOther_LAM:controlDef()
	-- Hide ungrouped in bag Checkbox
	return
		{
			type = "checkbox",
			name = SI_AC_MENU_BS_CHECKBOX_UNGROUPED_CATEGORY_HIDDEN,
			tooltip = SI_AC_MENU_BS_CHECKBOX_UNGROUPED_CATEGORY_HIDDEN_TOOLTIP,
			getFunc = function() return self:getValue() end,
			setFunc = function(value) self:setValue(value) end,
			default = false,
			width = "half",
			reference = self:getControlName(),
		}
end
-- -------------------------------------------------------

-- customization of BaseUI for BagSet_HideCat_LAM checkbox
-- -------------------------------------------------------
--[[ BagSet Hide Category Checkbox Control (AC_CHECKBOX_HIDE_CATEGORY).
    
    Checkbox control that toggles whether a selected
    rule/category should be hidden from the display order list. When enabled,
    the rule remains in the bag's rules list but won't be shown in the item
    categorization display or applied during gameplay.
    
    This is useful for rules that should be kept for reference or future use
    without actively applying them during gameplay. Hidden rules retain their
    priorities, tags, and definitions - they're simply excluded from automatic
    categorization until re-enabled.
    
    @field controlName     string    "AC_CHECKBOX_HIDE_CATEGORY"
    @field type            string    "checkbox"
    @field name            string    Localized checkbox label text
    @field tooltip         string    Tooltip explaining the hide behavior
    @field getFunc         function  Delegates to getValue()
    @field setFunc         function  Delegates to setValue()
    @field disabled        function  Returns true if no rule selected or dropdown empty
    @field default         boolean   false (checkbox unchecked by default)
    @field width           string    "half" (checkbox takes half menu width)
    
    Note   
		When enabled (checked/hidden):
		- Rule remains in bag's rules list
		- Rule is excluded from display order
		- Rule is not applied during gameplay categorization
		- Rule retains all settings (priority, tag, definition)
		- Rule can be re-enabled at any time by unchecking
    
    Warning 
		Hidden rules are NOT deleted. They persist in the saved.bags
		table and will be reloaded on addon restart. Use RemoveCat_LAM
		to permanently delete rules.
--]]

function BagSet_HideCat_LAM:getValue()
	local bag = getCurrentBagId()
	local ruleNm = currentBagRule or BagSet_SelectRule_LAM:getValue()
	if bag and ruleNm and AutoCategory.cache.entriesByName[bag][ruleNm] then
		return AutoCategory.cache.entriesByName[bag][ruleNm].isHidden or false
	end
	return 0
end

function BagSet_HideCat_LAM:setValue(value)
	local bag = getCurrentBagId()
	local ruleNm = currentBagRule or BagSet_SelectRule_LAM:getValue()
	if AutoCategory.cache.entriesByName[bag][ruleNm] then
		local isHidden = AutoCategory.cache.entriesByName[bag][ruleNm].isHidden or false
		if isHidden ~= value then
			if not value then value = nil end

			AutoCategory.cache.entriesByName[bag][ruleNm].isHidden = value
			AutoCategory.cacheBagInitialize()
			AC_UI.RefreshDropdownData()
			BagSet_SelectRule_LAM:setValue(ruleNm)
			BagSet_ShowRule_LAM:refresh(bag)
			AC_UI.RefreshControls()
			AC_UI.BagSet_RefreshOrder()
		end
	end
end

function BagSet_HideCat_LAM:controlDef()
	-- Hide Category Checkbox
	return
		{
			type = "checkbox",
			name = SI_AC_MENU_BS_CHECKBOX_CATEGORY_HIDDEN,
			tooltip = SI_AC_MENU_BS_CHECKBOX_CATEGORY_HIDDEN_TOOLTIP,
			getFunc = function()	return self:getValue() end,
			setFunc = function(value)  self:setValue(value) end,
			disabled = function()
				if BagSet_SelectRule_LAM:getValue() == nil then
					return true
				end
				if BagSet_SelectRule_LAM:size() == 0 then
					return true
				end
				return false
			end,
			default = false,
			width = "half",
		}
end
-- -------------------------------------------------------

-- customization of BaseDD for BagSet_SelectRule_LAM
-- ------------------------------------------------
--[[ BagSet Select Rule Dropdown Control (AC_DROPDOWN_EDITBAG_RULE).
    
    Dropdown control that displays the list of all rules
    assigned to the currently selected bag. Allows users to select a specific
    rule for viewing/editing priority settings, hiding/showing, removal, or
    other bag-specific operations.
    
    The dropdown is populated from the `cache.entriesByBag[bagId]` list and
    dynamically updated when bags are modified. Maintains synchronization
    with priority sliders and other rule-dependent UI controls.
    
    @field controlName string  "AC_DROPDOWN_EDITBAG_RULE"
    @field cvt         table   Choice Value Table (USE_VALUES + USE_TOOLTIPS)
    @field refresh     function Reloads CVT from cache.entriesByBag
    @field setValue    function Sets selection and triggers dependent updates
    @field assign      function LAM inherited: sets the CVT data source
    @field select      function LAM inherited: selects a specific value/index
    @field getValue    function LAM inherited: returns current selected rule name
    @field updateControl function LAM inherited: redraw the dropdown UI
    @field size        function Returns number of rule options
    
    Note   
		The dropdown is automatically refreshed when:
		- User selects a different bag (BagSet_SelectBag_LAM changes)
		- A rule is added/removed from the bag (BagSet_Remove/Add operations)
		- Cache is invalidated (cacheBagInitialize() called)
		- Menu is opened (initial population)
    
    Warning 
		Selection change triggers cascading updates:
		- Priority sliders are updated
		- Display Window is notified
		- All other controls are refreshed
		- currentBagRule global is set
		
		Use setValue() for programmatic changes to ensure full sync.
--]]

-- refresh the contents of the cvt lists for BagSet_SelectRule_LAM from the 
-- current contents of the cache.entriesByBag[bagId] list.
function BagSet_SelectRule_LAM:refresh(bagId)
	local currentBag = bagId or getCurrentBagId()
	local ndx = BagSet_SelectRule_LAM:getValue()

	logDebug("[BagSet] SelectRule:refresh: Updating cvt lists for BagSet_SelectRule for bag ", currentBag)
	do
		-- dropdown lists for Edit Bag Rules selection (AC_DROPDOWN_EDITBAG_BAG)
		local dataCurrentRules_EditBag = CVT:New(self.controlName,nil, CVT.USE_VALUES + CVT.USE_TOOLTIPS)
		if currentBag and AutoCategory.cache.entriesByBag[currentBag] then
			logDebug("[BagSet] SelectRule:refresh: Getting rules for bag ", currentBag)
			dataCurrentRules_EditBag:assign(AutoCategory.cache.entriesByBag[currentBag])
		end
		self:assign(dataCurrentRules_EditBag)
	end
	if not ndx then 
		self:select(emptyValueTbl)
	else
		self:select(ndx)
	end
	self:setValue(self:getValue())
	logDebug("[BagSet] SelectRule:refresh: Done updating cvt lists for BagSet_SelectRule for bag ", currentBag)
end

-- set the selection of the BagSet_SelectRule_LAM field
function BagSet_SelectRule_LAM:setValue(val)
	if not val then return end
	
	self:select(val)
	currentBagRule = val
	local bagrule = AutoCategory.cache.entriesByName[getCurrentBagId()][val]
	if bagrule and bagrule.runpriority then
		if bagrule.showpriority == nil then
			bagrule.showpriority = bagrule.runpriority
		end
		BagSet_RunPriority_LAM:setValue(bagrule.runpriority)
		BagSet_ShowPriority_LAM:setValue(bagrule.showpriority)

		AC_UI.RefreshControls()
		AutoCategory.dspWin:SelectItem(AutoCategory.dspWin, getCurrentBagId(), bagrule.name)
	end
end

function BagSet_SelectRule_LAM:controlDef()
	-- Rule name   - AC_DROPDOWN_EDITBAG_RULE
	return
		{
			type = "dropdown",
			name = SI_AC_MENU_BS_DROPDOWN_CATEGORIES,
			tooltip = "",
			scrollable = true,
			choices         = self.cvt.choices,
			choicesValues   = self.cvt.choicesValues,
			choicesTooltips = self.cvt.choicesTooltips,

			getFunc = function() return self:getValue() end,
			setFunc = function(value) self:setValue(value) end,
			disabled = function() return self:size() == 0 end,
			width = "half",
			reference = self:getControlName(),
		}
end
-- ----------------------------------------------------------
-- customization of BaseDD for BagSet_ShowRule_LAM
-- ------------------------------------------------
--[[ BagSet Select Rule Dropdown Control (AC_DROPDOWN_EDITBAG_RULE).
    
    Dropdown control that displays the list of all rules
    assigned to the currently selected bag. Allows users to select a specific
    rule for viewing/editing priority settings, hiding/showing, removal, or
    other bag-specific operations.
    
    The dropdown is populated from the `cache.entriesByBag[bagId]` list and
    dynamically updated when bags are modified. Maintains synchronization
    with priority sliders and other rule-dependent UI controls.
    
    @field controlName string  "AC_DROPDOWN_EDITBAG_RULE"
    @field cvt         table   Choice Value Table (USE_VALUES + USE_TOOLTIPS)
    @field refresh     function Reloads CVT from cache.entriesByBag
    @field setValue    function Sets selection and triggers dependent updates
    @field assign      function LAM inherited: sets the CVT data source
    @field select      function LAM inherited: selects a specific value/index
    @field getValue    function LAM inherited: returns current selected rule name
    @field updateControl function LAM inherited: redraw the dropdown UI
    @field size        function Returns number of rule options
    
    Note   
		The dropdown is automatically refreshed when:
		- User selects a different bag (BagSet_SelectBag_LAM changes)
		- A rule is added/removed from the bag (BagSet_Remove/Add operations)
		- Cache is invalidated (cacheBagInitialize() called)
		- Menu is opened (initial population)
    
    Warning 
		Selection change triggers cascading updates:
		- Priority sliders are updated
		- Display Window is notified
		- All other controls are refreshed
		- currentBagRule global is set
		
		Use setValue() for programmatic changes to ensure full sync.
--]]

-- refresh the contents of the cvt lists for BagSet_ShowRule_LAM from the 
-- current contents of the cache.entriesByBag[bagId] list.
function BagSet_ShowRule_LAM:refresh(bagId)
	local currentBag = bagId or getCurrentBagId()
	local ndx = BagSet_SelectRule_LAM:getValue()

	do
		-- dropdown lists for Edit Bag Rules selection (AC_DROPDOWN_EDITBAG_BAG)
		local dataCurrentRules_EditBag = CVT:New(self.controlName,nil, CVT.USE_VALUES + CVT.USE_TOOLTIPS)
		if currentBag and AutoCategory.cache.entriesByBag[currentBag] then
			dataCurrentRules_EditBag:assign(AutoCategory.cache.entriesByBag[currentBag])
		end
		self:assign(dataCurrentRules_EditBag)
	end
	if not ndx then 
		self:select(emptyValueTbl)
	else
		self:select(ndx)
	end
	self:setValue(self:getValue())
end

-- set the selection of the BagSet_ShowRule_LAM field
function BagSet_ShowRule_LAM:setValue(val)
	if not val then return end
	
	self:select(val)
	currentBagRule = val
	local bagrule = AutoCategory.cache.entriesByName[getCurrentBagId()][val]
	if bagrule and bagrule.runpriority then
		currentBagRule = bagrule
		if bagrule.showpriority == nil then
			bagrule.showpriority = bagrule.runpriority
		end
		BagSet_RunPriority_LAM:setValue(bagrule.runpriority)
		BagSet_ShowPriority_LAM:setValue(bagrule.showpriority)
		
	end
end

function BagSet_ShowRule_LAM:controlDef()
	-- Rule name   - AC_DROPDOWN_EDITBAG_RULE
	return
		{
			type = "dropdown",
			name = SI_AC_MENU_BS_SHOWDROPDOWN_CATEGORIES,
			tooltip = "",
			scrollable = true,
			choices         = self.cvt.choices,
			choicesValues   = self.cvt.choicesValues,
			choicesTooltips = self.cvt.choicesTooltips,

			getFunc = function() return self:getValue() end,
			setFunc = function(value) self:setValue(value) end,
			disabled = function() return false end, --self:size() == 0 end,
			width = "half",
			reference = self:getControlName(),
		}
end
-- ----------------------------------------------------------

-- customization of BaseUI for BagSet_RunPriority_LAM
-- ------------------------------------------------
--[[ BagSet Run Priority Slider Control (AC_SLIDER_RUN_PRIORITY).
    
    Slider control that adjusts the run priority value
    for the currently selected rule. The run priority determines the order
    in which rules are evaluated during gameplay categorization - higher
    priority rules are checked first.
    
    When the slider is adjusted, the value is immediately saved to the cache
    and persisted to the saved variables. This affects the rule's evaluation
    order without requiring manual save or refresh operations.
    
    @field controlName  string  "AC_SLIDER_RUN_PRIORITY"
    @field type         string  "slider"
    @field name         string  Localized slider label text
    @field tooltip      string  Tooltip explaining the priority behavior
    @field minValue     number  Minimum priority value (typically 0)
    @field maxValue     number  Maximum priority value (typically 100)
    @field step         number  Increment step (typically 1)
    @field default      number  Default priority if not set
    @field getFunc      function  Delegates to getValue()
    @field setFunc      function  Delegates to setValue()
    @field disabled     function  Returns true if no rule selected
    @field width        string  "half" (slider takes half menu width)
    
    Note   
		When adjusted:
		- Value is saved to `cache.entriesByName[bag][rule].runpriority`
		- Cache is automatically synchronized with saved.bags
		- Display Window may be refreshed to show priority changes
		- No confirmation dialog is shown (immediate save)
--]]

BagSet_RunPriority_LAM.maxVal = 1000
BagSet_RunPriority_LAM.minVal = 2

function BagSet_RunPriority_LAM:getValue()
	local bag = getCurrentBagId()
	local bagrule = currentBagRule --BagSet_SelectRule_LAM:getValue()
	if bag and bagrule and AutoCategory.cache.entriesByName[bag][bagrule] then
		return AutoCategory.cache.entriesByName[bag][bagrule].runpriority
	end
	return self.minVal
end

function BagSet_RunPriority_LAM:setValue(value)

	if value > self.maxVal then
		value = self.maxVal
	end
	if value < self.minVal then
		value = self.minVal
	end
	local bag = getCurrentBagId()
	local ruleName = currentBagRule or BagSet_SelectRule_LAM:getValue()
	if ruleName == nil then return end

	local bagrule = AutoCategory.cache.entriesByName[bag][ruleName]
	if bagrule then
		if bagrule.runpriority == value then return end
		bagrule.runpriority = value
		AutoCategory.cacheInitialize()
		AC_UI.CatSet_SelectRule_LAM:setValue(ruleName)
		BagSet_SelectRule_LAM:setValue(ruleName)
		BagSet_SelectRule_LAM:refresh()
		BagSet_ShowRule_LAM:refresh(bag)
		AC_UI.RefreshControls()
		AC_UI.BagSet_RefreshOrder()
	end
end

function BagSet_RunPriority_LAM:controlDef()
	-- RunPriority Slider
	return
		{
			type = "slider",
			name = SI_AC_MENU_BS_SLIDER_CATEGORY_RUNPRIORITY,
			tooltip = SI_AC_MENU_BS_SLIDER_CATEGORY_RUNPRIORITY_TOOLTIP,
			min = self.minVal,
			max = self.maxVal,
			getFunc = function() return self:getValue() end,
			setFunc = function(value) self:setValue(value) end,
			disabled = function()
				if BagSet_SelectRule_LAM:getValue() == nil then
					return true
				end
				if BagSet_SelectRule_LAM:size() == 0 then
					return true
				end
				return false
			end,
			default = BagSet_RunPriority_LAM.minVal,
			width = "half",
		}
end
-- ------------------------------------------------

-- customization of BaseUI for BagSet_ShowPriority_LAM
-- ------------------------------------------------
--[[ BagSet Show Priority Slider Control (AC_SLIDER_SHOW_PRIORITY).
    
    Slider control that adjusts the show priority value
    for the currently selected rule. The show priority determines the display
    order and visibility hierarchy when items are categorized - higher priority
    categories appear earlier/more prominently in the display window.
    
    Unlike run priority (which uses 0-100 range), show priority uses a wider
    range of 2-1000, allowing finer granularity in display ordering. When the
    slider is adjusted, the value is immediately saved to the cache and triggers
    extensive UI refreshes to update display order lists.
    
    @field controlName  string  "AC_SLIDER_SHOW_PRIORITY"
    @field type         string  "slider"
    @field name         string  Localized slider label text
    @field tooltip      string  Tooltip explaining the priority behavior
    @field minVal       number  Minimum priority value (2)
    @field maxVal       number  Maximum priority value (1000)
    @field default      number  Default priority if not set (0)
    @field getFunc      function  Delegates to getValue()
    @field setFunc      function  Delegates to setValue()
    @field disabled     function  Returns true if no rule selected
    @field width        string  "half" (slider takes half menu width)
    
    Note   
		When adjusted:
		- Value is saved to `cache.entriesByName[bag][rule].showpriority`
		- Extensive cascade refresh is triggered (unlike run priority)
		- Display Window is refreshed via BagSet_RefreshOrder
		- No confirmation dialog is shown (immediate save)
    
    Warning 
		SHOW PRIORITY TRIGGERS MORE REFRESHES THAN RUN PRIORITY:
		- Calls AC.UI.CatSet_SelectRule_LAM:setValue()
		- Calls BagSet_SelectRule_LAM:setValue() AND refresh()
		- Calls BagSet_ShowRule_LAM:refresh()
		- Calls AC_UI.RefreshControls()
		- Calls AC_UI.BagSet_RefreshOrder()
            
		This can cause noticeable lag with many rules. Consider batching
		priority changes if adjusting multiple rules at once.
--]]

BagSet_ShowPriority_LAM.maxVal = 1000
BagSet_ShowPriority_LAM.minVal = 2

function BagSet_ShowPriority_LAM:getValue()
	local bag = getCurrentBagId()
	local bagrule = currentBagRule
	if bag and bagrule and AutoCategory.cache.entriesByName[bag][bagrule] then
		return AutoCategory.cache.entriesByName[bag][bagrule].showpriority
	end
	return self.minVal
end

function BagSet_ShowPriority_LAM:setValue(value)

	if value > self.maxVal then
		value = self.maxVal
	end
	if value < self.minVal then
		value = self.minVal
	end
	local bag = getCurrentBagId()
	local ruleName = currentBagRule or BagSet_SelectRule_LAM:getValue()
	if ruleName == nil then return end
	local bagrule = AutoCategory.cache.entriesByName[bag][ruleName]

	if bagrule then
		if bagrule.showpriority == value then return end
		
		bagrule.showpriority = value
		AutoCategory.cacheInitialize()
		AC_UI.CatSet_SelectRule_LAM:setValue(ruleName)
		BagSet_SelectRule_LAM:setValue(ruleName)
		BagSet_SelectRule_LAM:refresh()
		BagSet_ShowRule_LAM:refresh(bag)
		AC_UI.RefreshControls()
	end
	AC_UI.BagSet_RefreshOrder()
end

function BagSet_ShowPriority_LAM:controlDef()
	-- ShowPriority Slider
	return
		{
			type = "slider",
			name = SI_AC_MENU_BS_SLIDER_CATEGORY_SHOWPRIORITY,
			tooltip = SI_AC_MENU_BS_SLIDER_CATEGORY_SHOWPRIORITY_TOOLTIP,
			min = self.minVal,
			max = self.maxVal,
			getFunc = function() return self:getValue() end,
			setFunc = function(value) self:setValue(value) end,
			disabled = function()
				if BagSet_SelectRule_LAM:getValue() == nil then
					return true
				end
				if BagSet_SelectRule_LAM:size() == 0 then
					return true
				end
				return false
			end,
			default = BagSet_ShowPriority_LAM.minVal,
			width = "half",
		}
end
-- ------------------------------------------------
-- customization of BaseUI for BagSet_ShowCatOrder_LAM Button
-- ------------------------------------------------
--[[ BagSet Show Category Order Button Control (AC_BUTTON_SHOW_ORDER).
    
    Button control that displays the Display Window
    and refreshes the category order list. When clicked, initializes the
    cache for the current bag, updates the rule display controls, and makes
    the categorization display window visible at the top of the UI stack.
    
    This is the primary action button for viewing how items will be
    categorized in-game. It bridges the menu configuration UI with the
    actual display window that users see during gameplay.
    
    @field controlName string  "AC_BUTTON_SHOW_ORDER"
    @field type        string  "button"
    @field name        string  Localized button label text
    @field tooltip     string  Tooltip explaining the display function
    @field func        function  Callback executed on click
    @field disabled    function  Returns true if show priority is nil
    @field width       string  "half" (button takes half menu width)
    
    Note   
		When clicked:
		- Cache is initialized for current bag
		- Display window is shown and brought to front
		- All dependent controls are refreshed
		- Current rule selection is preserved
    
    Warning 
		The button's disabled state depends on `BagSet_ShowPriority_LAM:getValue()`
		returning a non-nil value, which may cause it to be disabled when
		a valid rule is selected but showpriority hasn't been explicitly set.
		This dependency should be reviewed for correctness.
--]]

function BagSet_ShowCatOrder_LAM:execute()
	-- load the window with the current order
	local bagId = getCurrentBagId()
	AutoCategory.cacheInitBag(bagId)
	BagSet_ShowRule_LAM:refresh(bagId)
	AC_UI.BagSet_RefreshOrder()
	BagSet_SelectRule_LAM:setValue(BagSet_SelectRule_LAM:getValue())

	-- display the window
	AutoCategory.dspWin:SetHidden(false)
	AutoCategory.dspWin:BringWindowToTop()	-- doesn't work if window is hidden
end

function BagSet_ShowCatOrder_LAM:controlDef()
	return
		{
			type = "button",
			name = SI_AC_MENU_BS_BUTTON_SHOW,
			tooltip = SI_AC_MENU_BS_BUTTON_SHOW_TOOLTIP,
			func = function() self:execute() end,
			disabled = function()
				-- Check if rule is selected, not priority value
				local ruleName = BagSet_SelectRule_LAM:getValue()
				if not ruleName then return true end
				
				local bagId = getCurrentBagId()
				if not bagId then return true end
				
				return false
			end,
			width = "half",
		}
end
-- ----------------------------------------------------------

-- customization of BaseUI for BagSet_EditCat_LAM Button
-- ------------------------------------------------
--[[ BagSet Edit Category Button Control (AC_BUTTON_EDIT_CATEGORY).
    
    Button control that opens the Category Settings
    editor for the currently selected rule in the Bag Setting section.
    Retrieves the rule definition from the master catalog (RulesW), loads
    it into the Category Settings UI controls, and navigates from the
    Bag Setting submenu to the Category Setting submenu for editing.
    
    When clicked, validates the selected rule exists in the master catalog
    before proceeding. If the rule doesn't exist, the button silently exits
    without error (though the disabled predicate should prevent this case).
    
    @field controlName string  "AC_BUTTON_EDIT_CATEGORY"
    @field type        string  "button"
    @field name        string  Localized button label text
    @field tooltip     string  Tooltip explaining the edit function
    @field func        function  Callback executed on click
    @field disabled    function  Returns true if no rule selected or dropdown empty
    @field width       string  "half" (button takes half menu width)
    
    Note   
		When clicked:
		- Retrieves rule from master catalog via GetRuleByName()
		- Loads rule into Category Settings controls (CatSet_DisplayRule)
		- Navigates from Bag Setting to Category Setting submenu
		- Sets currentBagRule context for subsequent operations
--]]

function BagSet_EditCat_LAM:execute()
	local ruleName = currentBagRule or BagSet_SelectRule_LAM:getValue()
	local rule = AutoCategory.GetRuleByName(ruleName)
	if rule then
		CatSet_DisplayRule(rule)
		AC_UI.ToggleSubmenu("AC_SUBMENU_BAG_SETTING", false)
		AC_UI.ToggleSubmenu("AC_SUBMENU_CATEGORY_SETTING", true)
	end
end

function BagSet_EditCat_LAM:controlDef()
	return
		{
			type = "button",
			name = SI_AC_MENU_BS_BUTTON_EDIT,
			tooltip = SI_AC_MENU_BS_BUTTON_EDIT_TOOLTIP,
			func = function() self:execute() end,
			disabled = function()
				return BagSet_SelectRule_LAM:size() == 0 or BagSet_SelectRule_LAM:getValue() == nil
			end,
			width = "half",
		}
end
-- ----------------------------------------------------------

-- customization of BaseUI for BagSet_RemoveCat_LAM Button
-- ----------------------------------------------------------
--[[ BagSet Remove Category from Bag Button Control (AC_BUTTON_REMOVE_CATEGORY).
    
    Button control that removes a selected rule from
    the current bag. When clicked, finds the rule entry in the bag's rules
    list and deletes it, then performs extensive UI refreshes to update
    all dependent dropdowns, caches, and display windows.
    
    This is a destructive operation that permanently removes the rule
    association from the bag. The rule definition itself remains in the
    master catalog (RulesW), but the bag-specific configuration (priority,
    visibility settings) is lost.
    
    @field controlName string  "AC_BUTTON_REMOVE_CATEGORY"
    @field type        string  "button"
    @field name        string  Localized button label text
    @field tooltip     string  Tooltip explaining the removal function
    @field func        function  Callback executed on click
    @field disabled    function  Returns true if dropdown is empty
    @field width       string  "half" (button takes half menu width)
    
    Warning 
		THIS OPERATION IS IRREVERSIBLE without prior backup:
		- The rule is permanently removed from the bag
		- Bag-specific settings (priority, showpriority) are lost
		- The master catalog rule remains unchanged
		- No confirmation dialog is shown by default
    
    Note   
		The button's disabled state only checks if the dropdown has
		entries (size == 0), NOT if a specific rule is selected.
		This may allow clicking when no rule is selected, causing
		errors during removal. This should be reviewed for correctness.
--]]

function BagSet_RemoveCat_LAM:execute()
	local bagId = getCurrentBagId()
	if not bagId then 
        logDebug("[Remove] No bag selected")
        return 
    end

	local ruleName = currentBagRule or BagSet_SelectRule_LAM:getValue()
    if not ruleName then 
        logDebug("[Remove] No rule selected")
        return 
    end

	local savedbag = AutoCategory.saved.bags[bagId]
	logDebug("[BagSet] Removing rule name ", ruleName)
	for i = 1, #savedbag.rules do
		local bagEntry = savedbag.rules[i]
		if bagEntry.name == ruleName then
			logDebug("[BagSet] Found it! - ", ruleName)
			table.remove(savedbag.rules, i)
			break
		end
	end
	BagSet_SelectRule_LAM.cvt:removeItemChoiceValue(ruleName)
	if BagSet_SelectRule_LAM:getValue() == nil and BagSet_SelectRule_LAM:size() > 0 then
		BagSet_SelectRule_LAM:select(emptyValueTbl) 	-- select first
	end

	AutoCategory.cacheBagInitialize()
	BagSet_SelectRule_LAM:refresh()
	AddCat_SelectRule_LAM:refresh()
	BagSet_ShowRule_LAM:refresh(bagId)
	AC_UI.RefreshControls()
	AC_UI.BagSet_RefreshOrder()
end

function BagSet_RemoveCat_LAM:controlDef()
	-- Remove Category from Bag Button
	return
		{
			type = "button",
			name = SI_AC_MENU_BS_BUTTON_REMOVE,
			tooltip = SI_AC_MENU_BS_BUTTON_REMOVE_TOOLTIP,
			func = function() self:execute() end,
			disabled = function()
				-- Check BOTH dropdown size AND rule selection
				if BagSet_SelectRule_LAM:size() == 0 then return true end
				if BagSet_SelectRule_LAM:getValue() == nil then return true end
				return false
			end,
			width = "half",
		}

end


-- ----------------------------------------------------------

-- customization of BaseDD for AddCat_SelectTag_LAM
-- ----------------------------------------------------------
--[[ AddCategory Select Tag Dropdown Control (AC_DROPDOWN_SELECTTAG).
    
    DDropdown control that displays the list of all tags
    (rule groups/categories) defined in the AutoCategory system. Allows users
    to select a specific tag group to filter rules when adding a category to
    a bag. Acts as the parent filter for `AddCat_SelectRule_LAM`.
    
    When changed, triggers a cascade of updates that filters the available
    rules dropdown to show only rules belonging to the selected tag group.
    Also clears any cached indices to force full re-filtering.
    
    @field controlName string  "AC_DROPDOWN_SELECTTAG"
    @field type        string  "dropdown"
    @field name        string  Localized dropdown label text
    @field cvt         table   Choice Value Table (auto-populated from RulesW.tags)
    @field sort        string  "name-up" (alphabetical ascending)
    @field scrollable  boolean true (dropdown supports scrolling)

    @field refresh     function Reloads CVT from RulesW.tags
    @field setValue    function Sets tag and filters dependent rule dropdown
    @field assign      function LAM inherited: sets the CVT data source
    @field select      function LAM inherited: selects a specific value/index
    @field getValue    function LAM inherited: returns current selected tag
    @field updateControl function LAM inherited: redraw the dropdown UI
    @field size        function Returns number of tag options
    
    Note   
		When a tag is selected:
		- Clears rule dropdown index cache
		- Filters available rules via `AddCat_SelectRule_LAM.filterRules()`
		- Refreshes rule dropdown CVT
		- Updates rule dropdown UI
		
		The dropdown is automatically populated from `AutoCategory.RulesW.tags`
		list on initialization. No manual refresh needed unless tags change.
--]]

-- refresh the selection value of the cvt lists for AddCat_SelectTag_LAM from the 
-- current contents of the RulesW.tags list.
function AC_UI.AddCat_SelectTag_LAM:refresh()
	if self:getValue() == nil or self:getValue() == "" then
		self:select(AutoCategory.RulesW.tags)
	end
end

function AC_UI.AddCat_SelectTag_LAM:setValue(value)
	local oldvalue = self:getValue()
	if oldvalue == value then return end

	self.cvt.indexValue = value

	AddCat_SelectTag_LAM:updateControl()
	AddCat_SelectRule_LAM:clearIndex()
	AddCat_SelectRule_LAM:assignNE(AddCat_SelectRule_LAM.filterRules(getCurrentBagId(),value))
	AddCat_SelectRule_LAM:refresh()
	AddCat_SelectRule_LAM:updateControl()
end

function AC_UI.AddCat_SelectTag_LAM:controlDef()
	return
		{
			type = "dropdown",
			name = SI_AC_MENU_AC_DROPDOWN_TAG,
			scrollable = true,
			choices = self.cvt.choices,
			sort = "name-up",

			getFunc = function()
				return self:getValue()
			end,
			setFunc = function(value) self:setValue(value) end,
			width = "half",
			disabled = function() return self.cvt:size() == 0 end,
			reference = self:getControlName(),
		}
end
-- ----------------------------------------------------------

-- customization of BaseDD for AddCat_SelectRule_LAM
-- ----------------------------------------------------------
--[[ AddCategory Rule Selector Dropdown Control (AC_DROPDOWN_ADDCATEGORY_RULE).
    
    Dropdown control that displays the list of available
    rules for selection when adding a category to a bag. Dynamically filters
    rules based on the currently selected tag (via AddCat_SelectTag_LAM) and
    excludes rules already present in the active bag.
    
    The control is populated with rules from the currently selected tag group,
    excluding any rules that are already assigned to the current bag. Uses
    CVT (Choice Value Tooltip object) for selection state management and tooltip display.
 
	Note   The dropdown is automatically refreshed when:
		- User selects a different tag (AddCat_SelectTag_LAM changes)
		- Current bag changes (BagSet_SelectBag_LAM changes)
		- Rules are added/removed from the bag (BagSet remove/add operations)
		- Menu is opened (initial population)

    @field controlName string  "AC_DROPDOWN_ADDCATEGORY_RULE"
    @field cvt           table  Choice Value Table (CVT.USE_TOOLTIPS enabled)
    @field refresh       function Reloads the dropdown from current tag/bag context
    @field filterRules   function Static method to filter rules by tag (returns CVT)
    @field assign        function LAM inherited: sets the CVT data source
    @field select        function LAM inherited: selects a specific value/index
    @field getValue      function LAM inherited: returns current selected value
    @field setValue      function LAM inherited: programmatically set selection
    @field updateControl function LAM inherited: redraw the dropdown UI
    @field size          function Returns number of available rule options
    
--]]
-- returns a CVT of all of the known rules of a tag (group) that are not already in the bag
-- will return empty CVT if no rules match the filter
local ACSR_badCVT = CVT:New(AddCat_SelectRule_LAM:getControlName(), nil, CVT.USE_TOOLTIPS)

function AC_UI.AddCat_SelectRule_LAM.filterRules(bagId, tag)
	local cache = AutoCategory.cache
	if not bagId or not tag then return ACSR_badCVT end
	if not cache.entriesByName[bagId] then
		cache.entriesByName[bagId] = {}
	end

    logDebug("[BagSet] AddCat_SelectRule running filterRules for bag ", bagId, " tag ", tag)
	-- filter out already-in-use rules from the "add category" list for bag rules
	local dataCurrentRules_AddCategory = CVT:New(AddCat_SelectRule_LAM:getControlName(), nil, CVT.USE_TOOLTIPS)
	if not AutoCategory.RulesW.tagGroups[tag] then
		-- no rules available for tag
        logDebug("[BagSet] AddCat_SelectRule no rules available")
		return dataCurrentRules_AddCategory
	end

	-- Get tag group (with nil guard)
	local tagGroup = AutoCategory.RulesW and AutoCategory.RulesW.tagGroups and 
	                 AutoCategory.RulesW.tagGroups[tag]
	if not tagGroup then
		logDebug("[AddCat] filterRules: no tagGroup for tag ", tag)
		return ACSR_badCVT
	end

	-- Filter rules: collect those not already in bag
	local bagEntries = cache.entriesByName[bagId]
	local countAdded = 0
	local totalCount = tagGroup:size()
	logDebug("[BagSet] filterRules:  # entries for tag ", totalCount)
	for i = 1, totalCount do
		local ruleName = tagGroup.choices[i]
		if ruleName and bagEntries[ruleName] == nil then
			--add the rule if not in bag
            logDebug("[BagSet] filterRules:  Adding ", ruleName)
			dataCurrentRules_AddCategory:append(ruleName, nil, tagGroup.choicesTooltips[i])
			countAdded = countAdded + 1
		end
	end

	-- Single summary log when debugging
	logDebug("[AddCat] filterRules: bag=" ,bagId, " tag=", tag, 
			" total=", totalCount, " added=", countAdded)

	return dataCurrentRules_AddCategory
end

-- refresh the selection value of the cvt lists for AddCat_SelectRule_LAM from the 
-- output of the filterRules().
function AC_UI.AddCat_SelectRule_LAM:refresh()
	local currentBag = getCurrentBagId()
	do
		-- dropdown lists for Adding Rules to Bag selection (AC_DROPDOWN_ADDCATEGORY_RULE)
		local latag = AddCat_SelectTag_LAM:getValue()
		local dataCurrentRules_AddCategory = AddCat_SelectRule_LAM.filterRules(currentBag, latag)
		if dataCurrentRules_AddCategory then
			AddCat_SelectRule_LAM:assignNE(dataCurrentRules_AddCategory)
			AddCat_SelectRule_LAM:select()
		end
	end

end

function AC_UI.AddCat_SelectRule_LAM:setValue(value)
	self:select(value)
end

function AC_UI.AddCat_SelectRule_LAM:controlDef()
	-- Categories currently unused dropdown - AC_DROPDOWN_ADDCATEGORY_RULE
	return
		{
			type = "dropdown",
			name = SI_AC_MENU_AC_DROPDOWN_CATEGORY,
			scrollable = true,
			choices = self.cvt.choices,
			choicesTooltips = self.cvt.choicesTooltips,
			sort = "name-up",

			getFunc = function() return self:getValue() end,
			setFunc = function(value) self:setValue(value) end,
			disabled = function() return self:size() == 0 end,
			width = "half",
			reference = self:getControlName(),
		}

end
-- ----------------------------------------------------------

-- customization of BaseUI for AddCat_EditRule_LAM button
-- ----------------------------------------------------------
--[[ AddCategory Edit Rule Button Control (AC_BUTTON_EDITRULE).
    
    Button control that opens the Category Settings
    editor for the currently selected rule in the Add Category section.
    
    When clicked, loads the selected rule's data into the Category Settings
    UI controls and navigates from the Add Category submenu to the Category
    Settings submenu. Provides quick access to edit rule definitions, tags,
    and properties without manually finding the rule in the category list.
    
    @field controlName     string    "AC_BUTTON_EDITRULE"
    @field type            string    "button"
    @field name            string    Localized button label text
    @field tooltip         string    Tooltip text explaining button function
    @field func            function  Callback executed on click
    @field disabled        function  Returns true if no rule is selected
    @field width           string    "half" (button takes half menu width)
    
    Note   
		The button is disabled when:
		- No rule is selected in AddCat_SelectRule_LAM
		- The selected rule does not exist in RulesW
		- The selected rule is predefined (non-editable)
--]]

function AddCat_EditRule_LAM:execute()
	local ruleName = AddCat_SelectRule_LAM:getValue()
	local rule = AutoCategory.GetRuleByName(ruleName)
	if not rule then return end

	CatSet_DisplayRule(rule)
	AC_UI.RefreshDropdownData()
	currentRule = rule
	AC_UI.CatSet_SelectTag_LAM:setValue(rule.tag)
	AC_UI.CatSet_SelectTag_LAM:refresh()

	AC_UI.checkCurrentRule()
	AC_UI.RefreshDropdownData()
	AC_UI.CatSet_SelectRule_LAM:setValue(rule.name)
	AC_UI.CatSet_SelectRule_LAM:refresh()

	AC_UI.ToggleSubmenu("AC_SUBMENU_BAG_SETTING", false)
	AC_UI.ToggleSubmenu("AC_SUBMENU_CATEGORY_SETTING", true)
end

function AddCat_EditRule_LAM:controlDef()
                -- Edit Rule Category Button
	return
		{
			type = "button",
			name = SI_AC_MENU_AC_BUTTON_EDIT,
			tooltip = SI_AC_MENU_AC_BUTTON_EDIT_TOOLTIP,
			func = function()	self:execute() end,
			disabled = function() return AddCat_SelectRule_LAM:size() == 0 end,
			width = "half",
		}

end
-- ----------------------------------------------------------

-- -------------------------------------------------------
--[[ AddCategory Add to Bag Button Control (AC_BUTTON_ADDTOBAG).
    
    Button control that adds the currently selected rule
    from the Add Category dropdown to the active bag. Creates a new bag rule
    entry with default runpriority and showpriority values, then refreshes
    all related dropdowns to reflect the updated bag contents.
    
    When clicked, validates the selected rule exists in the master catalog
    and is not already assigned to the current bag. If validation passes,
    delegates to BagSet_Service to perform the actual add operation, then
    updates UI controls to reflect the change.
    
    @field controlName     string    "AC_BUTTON_ADDTOBAG"
    @field type            string    "button"
    @field name            string    Localized button label text
    @field tooltip         string    Tooltip text explaining button function
    @field func            function  Callback executed on click
    @field disabled        function  Returns true if no rule selected or duplicate
    @field width           string    "half" (button takes half menu width)
    @field isDangerous     boolean   false (non-destructive operation)
    
    Note   
		The button is disabled when:
		- No rule is selected in AddCat_SelectRule_LAM
		- The selected rule is already in the current bag
		- The current bag is nil/invalid
		- The RulesW catalog is not initialized
--]]

function AddCat_BagAdd_LAM:execute()
	local bagId = getCurrentBagId()
	local ruleName = AddCat_SelectRule_LAM:getValue()
	if AutoCategory.cache.entriesByName[bagId][ruleName] then return end

	local saved = AutoCategory.saved
	local entry = AutoCategory.CreateBagRule(ruleName)
    if entry then
        saved.bags[bagId].rules[#saved.bags[bagId].rules+1] = entry
        currentBagRule = entry.name
        AutoCategory.cacheBagInitialize()

        BagSet_SelectRule_LAM:select(ruleName)
        BagSet_RunPriority_LAM:setValue(entry.runpriority)
        BagSet_ShowPriority_LAM:setValue(entry.showpriority)
        AddCat_SelectRule_LAM.cvt:removeItemChoiceValue(ruleName)

        AddCat_SelectRule_LAM:refresh()
        AddCat_SelectRule_LAM:updateControl()

        BagSet_SelectRule_LAM:refresh()
        BagSet_SelectRule_LAM:updateControl()

        AddCat_SelectRule_LAM:updateControl()
        BagSet_ShowRule_LAM:refresh(bagId)
        AC_UI.BagSet_RefreshOrder()
    end
end

function AddCat_BagAdd_LAM:controlDef()
	-- Add to Bag Button
	return
		{
			type = "button",
			name = SI_AC_MENU_AC_BUTTON_ADD,
			tooltip = SI_AC_MENU_AC_BUTTON_ADD_TOOLTIP,
			func = function()  self:execute() end,
			disabled = function() return AddCat_SelectRule_LAM:size() == 0 end,
			width = "half",
		}
end
-- -------------------------------------------------------

local function copyBagToBag(srcBagId, destBagId)
	AutoCategory.saved.bags[destBagId] = SF.deepCopy( AutoCategory.saved.bags[srcBagId] )
end

-- customization of BaseUI for ImpExp_ExportAll_LAM button
-- -------------------------------------------------------
--[[ Import/Export Export All to Bags Button Control (AC_BUTTON_EXPORTALL).
    
    Button control that exports the currently selected
    bag's settings to all other bags in the system. Copies the entire bag
    configuration (rules, priorities, hidden status) from the active bag
    to every other bag, effectively making all bags identical.
    
    When clicked, performs a deep copy operation via BagSet_Service to replicate
    the current bag's settings across all bags. Invalidates caches after export
    and refreshes all UI controls to reflect the changes.
    
    @field controlName     string    "AC_BUTTON_EXPORTALL"
    @field type            string    "button"
    @field name            string    Localized button label text
    @field tooltip         string    Tooltip text explaining button function
    @field func            function  Callback executed on click
    @field disabled        function  Returns true if no bag selected
    @field width           string    "full" (button spans full menu width)
    @field isDangerous     boolean   true (destructive operation - overwrites bags)
    
    Note   
		The button is disabled when:
		- No bag is selected (getCurrentBagId returns nil)
		- Source bag has no settings
		- There are no other bags to export to (only one bag exists)
		- BagSet_Service is not initialized
    
    Warning 
		THIS OPERATION IS IRREVERSIBLE without prior backup. All settings
		in target bags will be overwritten with the source bag's settings.
		Consider using bag backup/import features before bulk export.
--]]

function ImpExp_ExportAll_LAM:execute()
	local selectedBag = getCurrentBagId()
    AutoCategory.foreachBag(function(bagId)
        if bagId ~= selectedBag then
			copyBagToBag(selectedBag, bagId)
		end
    end)

	BagSet_SelectRule_LAM:clearIndex()
	--reset add rule's selection, since all data will be changed.
	AddCat_SelectRule_LAM:clearIndex()

	AutoCategory.cacheInitialize()
	AC_UI.RefreshDropdownData()
	AC_UI.RefreshControls()
end

function ImpExp_ExportAll_LAM:controlDef()
	-- Export To All Bags Button
	return
		{
			type = "button",
			name = SI_AC_MENU_UBS_BUTTON_EXPORT_TO_ALL_BAGS,
			tooltip = SI_AC_MENU_UBS_BUTTON_EXPORT_TO_ALL_BAGS_TOOLTIP,
			func = function() self:execute() end,
			width = "full",
		}
end
-- -------------------------------------------------------


-- customization of BaseDD for ImpExp_ImportBag_LAM
-- -------------------------------------------------------
function ImpExp_ImportBag_LAM:setValue(value)
	self:select(value)
end

function ImpExp_ImportBag_LAM:controlDef()
	-- Import From Bag - AC_DROPDOWN_IMPORTBAG_BAG
	return
		{
			type = "dropdown",
			name = SI_AC_MENU_IBS_DROPDOWN_IMPORT_FROM_BAG,
			scrollable = false,
			tooltip = SI_AC_MENU_IBS_DROPDOWN_IMPORT_FROM_BAG_TOOLTIP,
			choices = self.cvt.choices,
			choicesValues = self.cvt.choicesValues,
			choicesTooltips = self.cvt.choicesTooltips,

			getFunc = function() return self:getValue() end,
			setFunc = function(value) 	self:setValue(value) end,
			default = AC_BAG_TYPE_BACKPACK,
			width = "half",
			reference = self:getControlName(),
		}

end
-- -------------------------------------------------------

-- customization of BaseUI for ImpExp_Import_LAM button
-- -------------------------------------------------------
function ImpExp_Import_LAM:execute()

	local bagId = getCurrentBagId()
	local srcBagId = ImpExp_ImportBag_LAM:getValue()
	copyBagToBag(srcBagId, bagId)

	BagSet_SelectRule_LAM:clearIndex()
	--reset add rule's selection, since all data will be changed.
	AddCat_SelectRule_LAM:clearIndex()

	AutoCategory.cacheInitialize()
	AC_UI.RefreshDropdownData()
	AC_UI.RefreshControls()
end

function ImpExp_Import_LAM:controlDef()
	-- Import Button
	return
		{
			type = "button",
			name = SI_AC_MENU_IBS_BUTTON_IMPORT,
			tooltip = SI_AC_MENU_IBS_BUTTON_IMPORT_TOOLTIP,
			func = function() self:execute() end,
			disabled = function()
				return getCurrentBagId() == ImpExp_ImportBag_LAM:getValue()
			end,
			width = "half",
		}
end
-- -------------------------------------------------------

function AC_UI.BagSet.controlDef()
	-- Bag Settings Section Submenu
	return {
		type = "submenu",
		name = SI_AC_MENU_SUBMENU_BAG_SETTING, -- or string id or function returning a string
		reference = "AC_SUBMENU_BAG_SETTING",
		controls = {
			-- Select bag
			BagSet_SelectBag_LAM:controlDef(),

			-- Hide ungrouped in bag Checkbox
			BagSet_HideOther_LAM:controlDef(),

			AC_UI.divider(),

			-- Rule name   - AC_DROPDOWN_EDITBAG_RULE
			BagSet_SelectRule_LAM:controlDef(),
			--BagSet_ShowRule_LAM:controlDef(),

			-- blank "pad" for Hide Category button
			{
				type = "custom",
				width = "half",
			},
			-- RunPriority Slider
			BagSet_RunPriority_LAM:controlDef(),

			-- ShowPriority Slider
			BagSet_ShowPriority_LAM:controlDef(),

			-- blank "pad" for Hide Category button
			{
				type = "custom",
				width = "half",
			},
			-- Show Category Display Order Window button
			BagSet_ShowCatOrder_LAM:controlDef(),


			-- Hide Category Checkbox
			BagSet_HideCat_LAM:controlDef(),
			-- blank "pad" for Hide Category button
			{
				type = "custom",
				width = "half",
			},

			-- Edit Category Button
			BagSet_EditCat_LAM:controlDef(),
			-- Remove Category from Bag Button
			BagSet_RemoveCat_LAM:controlDef(),

			-- Add Category to Bag Section
			AC_UI.header(SI_AC_MENU_HEADER_ADD_CATEGORY),
			-- Select Tag Dropdown - AC_DROPDOWN_ADDCATEGORY_TAG
			AC_UI.AddCat_SelectTag_LAM:controlDef(),
			-- Categories currently unused dropdown - AC_DROPDOWN_ADDCATEGORY_RULE
			AddCat_SelectRule_LAM:controlDef(),
			-- Edit Rule Category Button
			AddCat_EditRule_LAM:controlDef(),
			-- Add to Bag Button
			AddCat_BagAdd_LAM:controlDef(),

			AC_UI.divider(),
			-- Import/Export Bag Settings
			{
				type = "submenu",
				name = SI_AC_MENU_SUBMENU_IMPORT_EXPORT,
				reference = "SI_AC_MENU_SUBMENU_IMPORT_EXPORT",
				controls = {
					AC_UI.header(SI_AC_MENU_HEADER_UNIFY_BAG_SETTINGS),

					-- Export To All Bags Button
					ImpExp_ExportAll_LAM:controlDef(),
					AC_UI.header(SI_AC_MENU_HEADER_IMPORT_BAG_SETTING),

					-- Import From Bag - AC_DROPDOWN_IMPORTBAG_BAG
					ImpExp_ImportBag_LAM:controlDef(),

					-- Import Button
					ImpExp_Import_LAM:controlDef(),
				},
			},
			AC_UI.divider(),
			-- Need Help button
			{
				type = "button",
				name = SI_AC_MENU_AC_BUTTON_NEED_HELP,
				func = function() RequestOpenUnsafeURL("https://github.com/Shadowfen/AutoCategory/wiki/Tutorial") end,
				width = "full",
			},
		},
	}
end	

function AC_UI.BagSet_ResetPriority()
	local runprior = BagSet_RunPriority_LAM:getValue()
	BagSet_ShowPriority_LAM:setValue(runprior)
end

function AC_UI.BagSet_ResetAllPriority()
	local bagId = getCurrentBagId()
	if not bagId then return end
	local bag = AutoCategory.cache.entriesByBag[bagId].choicesValues
	local rulename, bagrule
	for k = 1, #bag do
		rulename = bag[k]
		bagrule = AutoCategory.GetBagRuleByName(bagId, rulename)
		if bagrule then 
			bagrule.showpriority = bagrule.runpriority
		end
	end
	AC_UI.BagSet.refresh()
end


function AC_UI.BagSet.clear()				
	BagSet_SelectBag_LAM:select(AC_BAG_TYPE_BACKPACK)
	BagSet_SelectRule_LAM:clearIndex()
	AC_UI.AddCat_SelectTag_LAM:clearIndex()
	AC_UI.AddCat_SelectRule_LAM:clearIndex()
end

function AC_UI.BagSet.refresh()
	-- refresh selections
	BagSet_SelectBag_LAM:refresh()
	AC_UI.AddCat_SelectTag_LAM:refresh()

	--refresh current dropdown rules
	BagSet_SelectRule_LAM:refresh()
	AC_UI.AddCat_SelectRule_LAM:refresh()
	
end

function AC_UI.BagSet_RefreshOrder()
	local bag = getCurrentBagId()
	local sbag = AutoCategory.cache.entriesByShowBag[bag]		-- CVT
	if sbag and sbag.choices then
		local win = AutoCategory.dspWin
    if win and win.AddItem then
      win:ClearList()
      for i = 1, #sbag.bagrules do
        win:AddItem(sbag.bagrules[i])
      end
      win:UpdateScrollList()
    end
	end
end

function AC_UI.BagSet.SelectRule(name)
	--BagSet_SelectRule_LAM:refresh()
	BagSet_SelectRule_LAM:setValue(name)
	BagSet_SelectRule_LAM:updateControl()
end

function AC_UI.BagSet.HideCategory(name)
	--BagSet_SelectRule_LAM:refresh()
	BagSet_SelectRule_LAM:setValue(name)
	BagSet_HideCat_LAM:setValue(true)

	BagSet_ShowRule_LAM:refresh()
	BagSet_SelectRule_LAM:updateControl()
	AC_UI.BagSet_RefreshOrder()
end

function AC_UI.BagSet_GetHideCatStatus(name)
	--BagSet_SelectRule_LAM:refresh()
	BagSet_SelectRule_LAM:setValue(name)
	local val = BagSet_HideCat_LAM:getValue()
	return val
end

function AC_UI.BagSet.ShowCategory(name)
	--BagSet_SelectRule_LAM:refresh()
	BagSet_SelectRule_LAM:setValue(name)
	BagSet_HideCat_LAM:setValue(false)
	BagSet_SelectRule_LAM:updateControl()
	BagSet_ShowRule_LAM:refresh()
	AC_UI.BagSet_RefreshOrder()
end

function AC_UI.BagSet.updateControls()
	BagSet_SelectRule_LAM:updateControl()

	AddCat_SelectTag_LAM:updateControl()
	AC_UI.AddCat_SelectRule_LAM:refresh()
	AddCat_SelectRule_LAM:updateControl()
end


function AC_UI.BagSet.Init()

    -- initialize tables
	BagSet_SelectBag_LAM:assign(AutoCategory.cache.bags_cvt)
	AC_UI.AddCat_SelectTag_LAM:assignNE(AutoCategory.RulesW.tags) --( { choices=AutoCategory.RulesW.tags } )

	BagSet_SelectBag_LAM:select(emptyValueTbl)

    -- AddCat_SelectRule_LAM will get populated by RefreshDropdownData()
	AddCat_SelectRule_LAM:clear()

	ImpExp_ImportBag_LAM:assign(AutoCategory.cache.bags_cvt)
end


