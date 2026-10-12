local QTI = QuestTrackerImproved

function QTI.GetHouseTrackerControls()
	local tracker = HOUSE_INFORMATION_TRACKER
	return tracker.container:GetNamedChild("Header"),
		   tracker.container:GetNamedChild("SubLabel"),
		   tracker.container:GetNamedChild("Population"),
		   tracker.container:GetNamedChild("Tags")
end

function QTI.BuildHouseStrings(self)
	local housingEditorState = HOUSING_EDITOR_STATE

	local houseName = housingEditorState:GetHouseName()
	self:SetHeaderText(zo_strformat("<<1>>", houseName))

	local sublabelParts = {}

	if IsCurrentHouseListed() then
		local houseNickname = GetCurrentHouseTourListingNickname()
		if not (houseNickname and houseNickname ~= "") then
			local houseCollectibleId = GetCurrentHouseTourListingCollectibleId()
			local houseCollectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(houseCollectibleId)
			houseNickname = houseCollectibleData and houseCollectibleData:GetDefaultNickname() or nil
		end
		if houseNickname then
			table.insert(sublabelParts, string.format("%q", houseNickname))
		end
	end

	if not housingEditorState:IsLocalPlayerHouseOwner() then
		local ownerName = housingEditorState:GetOwnerName()
		if ownerName and ownerName ~= "" then
			table.insert(sublabelParts, zo_strformat("<<1>>", ownerName))
		end
	end

	local sublabelText = table.concat(sublabelParts, "\n")
	self:SetSubLabelText(sublabelText)
	self.subLabel:SetHidden(sublabelText == "")

	local population = housingEditorState:GetPopulation()
	local maxPopulation = housingEditorState:GetMaxPopulation()
	self.populationLabel:SetText(string.format("%d / %d", population, maxPopulation))

	self:RefreshListingTags(true)
end

function QTI.ApplyHouseStyle()
	local header, subLabel, population, tags = QTI.GetHouseTrackerControls()

	header:SetFont(QTI.GetFont(
		QTI.SV.houseHeaderFont,
		QTI.SV.houseHeaderSize,
		QTI.SV.houseHeaderStyle))
	QTI.ApplyControlColor(header, QTI.SV.houseHeaderColor)

	subLabel:SetFont(QTI.GetFont(
		QTI.SV.houseSubLabelFont,
		QTI.SV.houseSubLabelSize,
		QTI.SV.houseSubLabelStyle))
	QTI.ApplyControlColor(subLabel, QTI.SV.houseSubLabelColor)

	population:SetFont(QTI.GetFont(
		QTI.SV.housePopulationFont,
		QTI.SV.housePopulationSize,
		QTI.SV.housePopulationStyle))
	QTI.ApplyControlColor(population, QTI.SV.housePopulationColor)

	tags:SetFont(QTI.GetFont(
		QTI.SV.houseTagsFont,
		QTI.SV.houseTagsSize,
		QTI.SV.houseTagsStyle))
	QTI.ApplyControlColor(tags, QTI.SV.houseTagsColor)
end

function QTI.ApplyHouseWidth()
	local tracker = HOUSE_INFORMATION_TRACKER
	local width = QTI.SV.houseWidth
	local header, subLabel, population, tags = QTI.GetHouseTrackerControls()

	tracker.container:SetWidth(width)
	header:SetWidth(width)
	subLabel:SetWidth(width)
	population:SetWidth(width)
	tags:SetWidth(width)
end

function QTI.HouseTrackerUpdate(self)
	local housingEditorState = HOUSING_EDITOR_STATE
	local houseInstance = housingEditorState:IsHouseInstance()
	self:GetFragment():SetHiddenForReason("NonHouseZone", not houseInstance, DEFAULT_HUD_DURATION, DEFAULT_HUD_DURATION)
	if not houseInstance then
		return
	end

	QTI.BuildHouseStrings(self)

	if self.currentStyle then
		self:RefreshAnchors()
	end

	ZO_HUDTracker_Base.Update(self)
end

function QTI.HookHouseTracker()
	ZO_PreHook(ZO_HouseInformationTracker, "Update", function(self)
		QTI.HouseTrackerUpdate(self)
		return true
	end)

	ZO_PostHook(ZO_HouseInformationTracker, "ApplyPlatformStyle", function(self)
		QTI.ApplyHouseStyle()
		QTI.ApplyHouseWidth()
	end)

	QTI.ApplyHouseStyle()
	QTI.ApplyHouseWidth()
end

function QTI.ResizeHousePanel()
	QTI.ApplyHouseWidth()
end