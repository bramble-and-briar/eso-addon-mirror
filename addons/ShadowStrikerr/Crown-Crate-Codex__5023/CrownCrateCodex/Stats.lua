local C = CrownCrateCodex
local Label, Button, Backdrop = C.UI.Label, C.UI.Button, C.UI.Backdrop

function C:OfficialReferenceContext()
    local crate=self.crateFilter and self.db.crates[self.crateFilter]
    if not crate then return true,C.L("General guidance; mixed crate types.") end
    local name=crate.catalogKey or string.lower(crate.name)
    if name:find("ouroboros",1,true) or name:find("preview",1,true) then return false,C.L("Special crate: no applicable reference.") end
    if GetCVar and GetCVar("Language.2")~="en" and not crate.catalogKey then
        return false,C.L("No verified reference for this crate.")
    end
    return true,C.L("General purchased-crate guidance.")
end

function C:CreateStatsPanel()
    local panel = WINDOW_MANAGER:CreateControl(nil, self.window, CT_CONTROL)
    panel:SetAnchor(TOPLEFT, self.window, TOPLEFT, 1240, 65)
    panel:SetDimensions(560,845)
    Backdrop(panel)
    self.statsPanel = panel
    Label(panel,nil,18,12,524,32,"ZoFontWinH2"):SetText("|cE7C877"..C.L("YOUR DROP RATES").."|r")
    local selectedBand=WINDOW_MANAGER:CreateControl(nil,panel,CT_CONTROL)
    selectedBand:SetAnchor(TOPLEFT,panel,TOPLEFT,12,48)
    selectedBand:SetDimensions(536,60)
    local selectedBackdrop=Backdrop(selectedBand,1)
    selectedBackdrop:SetCenterColor(0.035,0.12,0.18,1)
    selectedBackdrop:SetEdgeColor(0.41,0.84,1,0.8)
    self.scopeLabel = Label(panel,nil,18,52,404,28,"ZoFontGameBold")
    self.scopeLabel:SetMaxLineCount(1)
    self.scopeLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.scopeHint = Label(panel,nil,18,82,404,28)
    self.scopeButton = Button(panel,nil,"",12,112,376,function() self.sessionOnly=not self.sessionOnly; self:RefreshStats() end)
    self.scopeInfo=Button(panel,nil,"[i]",396,112,36,function() self:ShowTooltip(self.scopeInfo,self:ScopeHelp()) end)
    for _,control in ipairs({self.scopeButton,self.scopeInfo}) do
        control:SetHandler("OnMouseEnter",function(target) self:ShowTooltip(target,self:ScopeHelp()) end)
        control:SetHandler("OnMouseExit",function() self:HideTooltip() end)
    end
    self.importStatsButton = Button(panel,nil,"",12,144,376,function() self.db.settings.includeImported=not self.db.settings.includeImported; self:RefreshUI() end)
    self.importTierButton = Button(panel,nil,"",12,176,376,function() self.db.settings.includeImportedTiers=not self.db.settings.includeImportedTiers; self:RefreshUI() end)
    self.importStatsInfo=Button(panel,nil,"[i]",396,144,36,function() self:ShowTooltip(self.importStatsInfo,self:ImportHelp("rewards")) end)
    self.importTierInfo=Button(panel,nil,"[i]",396,176,36,function() self:ShowTooltip(self.importTierInfo,self:ImportHelp("tiers")) end)
    for _,entry in ipairs({{self.importStatsInfo,"rewards"},{self.importStatsButton,"rewards"},{self.importTierInfo,"tiers"},{self.importTierButton,"tiers"}}) do
        local control,kind=entry[1],entry[2]
        control:SetHandler("OnMouseEnter",function(target) self:ShowTooltip(target,self:ImportHelp(kind)) end)
        control:SetHandler("OnMouseExit",function() self:HideTooltip() end)
    end
    self.countLabel = Label(panel,nil,18,220,404,28)
    self.cardCountLabel = Label(panel,nil,18,248,404,28)
    self.coverageLabel = Label(panel,nil,18,286,404,28)
    self.tierCoverageLabel = Label(panel,nil,18,314,404,28)
    self.tierCoverageLabel:SetMouseEnabled(true)
    self.tierCoverageLabel:SetHandler("OnMouseEnter",function(control)
        local stats=self:Statistics(self.crateFilter,self.sessionOnly)
        self:ShowTooltip(control,string.format(C.L("%d fully classified of %d eligible openings.\n%d top-tier reward cards cannot yet be split reliably into Apex or Radiant Apex.\nUnresolved openings are excluded from rarity percentages instead of being assigned to the wrong group. Item and bonus rates still retain eligible openings."),stats.classifiedOpenings,stats.tierEligibleOpenings,stats.unresolvedApexCards))
    end)
    self.tierCoverageLabel:SetHandler("OnMouseExit",function() self:HideTooltip() end)
    Label(panel,nil,18,348,180,24,"ZoFontGameBold"):SetText(C.L("Rarity"))
    Label(panel,nil,202,348,102,24,"ZoFontGameBold"):SetText(C.L("Your rate"))
    Label(panel,nil,316,348,104,24,"ZoFontGameBold"):SetText(C.L("Openings"))
    self.officialHeader=Label(panel,nil,430,348,112,24,"ZoFontGameBold")
    self.officialHeader:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.officialHeader:SetText(C.L("Official*"))
    self.rateLabels = {}
    for index=1,7 do
        self.rateLabels[index] = {
            name=Label(panel,nil,18,376+(index-1)*28,180,28),
            percent=Label(panel,nil,202,376+(index-1)*28,102,28),
            count=Label(panel,nil,316,376+(index-1)*28,104,28),
        }
        if index<=5 then
            self.rateLabels[index].reference=Label(panel,nil,430,376+(index-1)*28,112,28)
            self.rateLabels[index].reference:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
    end
    self.apexReference=Label(panel,nil,430,516,112,28)
    self.apexReference:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.apexReference:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.apexReference:SetMaxLineCount(1)
    self.radiantReference=Label(panel,nil,430,544,112,28)
    self.radiantReference:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local bonusBand=WINDOW_MANAGER:CreateControl(nil,panel,CT_CONTROL)
    bonusBand:SetAnchor(TOPLEFT,panel,TOPLEFT,12,572)
    bonusBand:SetDimensions(536,32)
    local bonusBackdrop=Backdrop(bonusBand,1)
    bonusBackdrop:SetCenterColor(0.12,0.09,0.025,1)
    bonusBackdrop:SetEdgeColor(0.91,0.8,0.52,0.85)
    self.bonusLabel = Label(panel,nil,18,574,404,28)
    self.gemLabel = Label(panel,nil,18,602,404,28)
    self.gemLabel:SetMouseEnabled(true)
    self.gemLabel:SetHandler("OnMouseEnter",function(control)
        self:ShowTooltip(control,C.L("ESO automatically converts duplicate collectibles into Crown Gems.\nCodex records the gems reported when a crate is opened.\nCodex does not exchange items for you.\nManual Gem Extraction is separate and is not included here.\nOld Tracker history did not record duplicate-conversion gems.\nNot recorded means unknown, rather than zero."))
    end)
    self.gemLabel:SetHandler("OnMouseExit",function() self:HideTooltip() end)
    self.rewardRateLabel = Label(panel,nil,18,636,404,48,"ZoFontGameBold")
    self.rewardRateLabel:SetMaxLineCount(2)
    self.rewardRateLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.rewardPercentLabel = Label(panel,nil,18,688,404,28)
    self.rewardUnitsLabel = Label(panel,nil,18,716,404,28)
    self.collectionsButton = Button(panel,nil,C.L("Open in Collections"),18,748,404,function() self:OpenCollectible(self.selectedRewardData) end)
    self.referenceLabel = Label(panel,nil,18,786,404,22,"ZoFontGameSmall")
    self.referenceLabel:SetText(C.L("Hover for reference odds and limits"))
    self.referenceLabel:SetMouseEnabled(true)
    self.referenceLabel:SetHandler("OnMouseEnter",function(control)
        self:ShowTooltip(control,C.L("General purchased-crate reference: Common 98%, Fine 72%, Superior 86%, Epic 21%, Legendary 14%, Apex including Radiants 2%. Not per-card rates; not validated for every special crate. Unknown tiers are excluded from rarity percentages. Imported gems were not recorded. Personal samples do not predict the next reward."))
    end)
    self.referenceLabel:SetHandler("OnMouseExit",function() self:HideTooltip() end)
    self.officialNoteLabel=Label(panel,nil,18,816,524,28,"ZoFontGame")
    for _,control in ipairs({self.scopeLabel,self.scopeHint,self.countLabel,self.cardCountLabel,self.coverageLabel,self.tierCoverageLabel,self.bonusLabel,self.gemLabel,self.rewardRateLabel,self.rewardPercentLabel,self.rewardUnitsLabel,self.collectionsButton,self.referenceLabel}) do
        local _,height=control:GetDimensions()
        control:SetDimensions(524,height)
    end
    for _,control in ipairs({self.scopeButton,self.importStatsButton,self.importTierButton}) do
        control:SetDimensions(496,30)
        control:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    end
    for index,control in ipairs({self.scopeInfo,self.importStatsInfo,self.importTierInfo}) do
        control:ClearAnchors(); control:SetAnchor(TOPLEFT,panel,TOPLEFT,516,112+(index-1)*32)
    end
end

function C:RefreshStats()
    local stats = self:Statistics(self.crateFilter,self.sessionOnly)
    local lifetime,session = self:Statistics(self.crateFilter),self:Statistics(self.crateFilter,true)
    local crate = self.crateFilter and self.db.crates[self.crateFilter]
    local font = self.db.settings.displaySize=="Extra Large" and "$(MEDIUM_FONT)|22|soft-shadow-thin" or "ZoFontGame"
    local showReference=self.db.settings.showOfficialReference
    local applicable,referenceNote=self:OfficialReferenceContext()
    self.officialHeader:SetHidden(not showReference)
    self.apexReference:SetHidden(not showReference)
    self.radiantReference:SetHidden(not showReference)
    self.apexReference:SetText(applicable and C.L("2% total*") or "--")
    self.radiantReference:SetText(applicable and C.L("Included*") or "--")
    self.apexReference:SetFont(font)
    self.radiantReference:SetFont(font)
    self.referenceLabel:SetText(showReference and applicable and C.L("*Apex + Radiant: 2% combined.") or C.L("Hover for reference odds and data limits"))
    self.officialNoteLabel:SetText(referenceNote)
    self.scopeLabel:SetText("|c69D6FF"..(crate and crate.name or C.L("All crates combined")).."|r")
    self.scopeHint:SetText(crate and C.L("Rates for this crate type") or C.L("Select a crate for its own rates"))
    self.scopeButton:SetText(self.sessionOnly and C.L("SESSION selected  /  Lifetime") or C.L("LIFETIME selected  /  Session"))
    self.importStatsButton:SetText(C.L("Imported rewards in %: ")..(self.db.settings.includeImported and C.L("ON") or C.L("OFF")))
    self.importTierButton:SetText(C.L("Imported tiers in %: ")..(self.db.settings.includeImportedTiers and C.L("ON") or C.L("OFF")))
    self.countLabel:SetText(string.format(C.L("%d lifetime  /  %d this session"),lifetime.openings,session.openings))
    self.cardCountLabel:SetText(string.format(C.L("%d cards in selected scope"),stats.cards))
    self.coverageLabel:SetText(string.format(C.L("Imports: %d included  /  %d excluded"),stats.includedImported,stats.excludedImported))
    self.tierCoverageLabel:SetText(stats.includedImported>0 and not self.db.settings.includeImportedTiers and stats.tierEligibleOpenings==0
        and C.L("Imported tier rates are OFF") or string.format(C.L("Fully tier-classified: %d of %d openings"),stats.classifiedOpenings,stats.tierEligibleOpenings))
    for index,row in ipairs(self.rateLabels) do
        local n = stats.rarities[index] or 0
        row.name:SetText("|c"..C.rarityColors[index]..C.RarityName(index).."|r")
        row.percent:SetText(C.Percent(n,stats.classifiedOpenings))
        row.count:SetText(string.format("%d / %d",n,stats.classifiedOpenings))
        row.name:SetFont(font); row.percent:SetFont(font); row.count:SetFont(font)
        if row.reference then
            row.reference:SetHidden(not showReference)
            row.reference:SetText(applicable and (C.referenceRates[index].."%") or "--")
            row.reference:SetFont(font)
        end
    end
    self.bonusLabel:SetText(string.format(C.L("Fifth-card bonus: %s - %d of %d crates"),C.Percent(stats.bonusOpenings,stats.openings),stats.bonusOpenings,stats.openings))
    self.gemLabel:SetText(stats.gemKnownOpenings==0 and C.L("Duplicate gems: Not recorded [i]")
        or string.format(C.L("Duplicate gems: %d%s [i]"),stats.gems,stats.gemKnownOpenings<stats.openings and C.L(" (partial history)") or ""))
    local reward = self.selectedReward and stats.rewards[self.selectedReward]
    if reward then
        self.selectedRewardData = reward.reward
        self.rewardRateLabel:SetText(reward.reward.name)
        self.rewardPercentLabel:SetText(string.format(C.L("%s of openings  (%d / %d)"),C.Percent(reward.openings,stats.openings),reward.openings,stats.openings))
        self.rewardUnitsLabel:SetText(string.format(C.L("%d cards  /  %d units"),reward.cards,reward.units))
    else
        self.selectedRewardData = nil
        self.rewardRateLabel:SetText(C.L("Select a reward to see its rate"))
        self.rewardPercentLabel:SetText(C.L("Rates follow your import switches."))
        self.rewardUnitsLabel:SetText(C.L("History retains excluded imports."))
    end
    self.collectionsButton:SetHidden(not self.selectedRewardData or self.selectedRewardData.productType~=MARKET_PRODUCT_TYPE_COLLECTIBLE)
    for _,label in ipairs({self.scopeLabel,self.scopeHint,self.countLabel,self.cardCountLabel,self.coverageLabel,self.tierCoverageLabel,self.bonusLabel,self.gemLabel,self.rewardRateLabel,self.rewardPercentLabel,self.rewardUnitsLabel}) do label:SetFont(font) end
    if self.FitLocalizedLabel then
        for _,label in ipairs({self.scopeLabel,self.scopeHint,self.countLabel,self.cardCountLabel,self.coverageLabel,self.tierCoverageLabel,self.bonusLabel,self.gemLabel,self.rewardPercentLabel,self.rewardUnitsLabel,self.referenceLabel,self.officialNoteLabel,self.apexReference,self.radiantReference}) do self:FitLocalizedLabel(label) end
        for _,row in ipairs(self.rateLabels) do self:FitLocalizedLabel(row.name) end
    end
end
