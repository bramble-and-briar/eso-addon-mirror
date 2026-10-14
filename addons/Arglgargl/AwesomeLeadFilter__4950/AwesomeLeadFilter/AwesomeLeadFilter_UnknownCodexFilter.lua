local AGS = AwesomeGuildStore
local LootLog = LootLog

local MultiChoiceFilterBase = AGS.class.MultiChoiceFilterBase

-- remark: normally from local FILTER_ID = AGS.data.FILTER_ID
local FILTER_ID_UCF = 120
local SUB_CATEGORY_ID = AGS.data.SUB_CATEGORY_ID


local UnknownCodexFilter = MultiChoiceFilterBase:Subclass()
AGS.class.UnknownCodexFilter = UnknownCodexFilter

function UnknownCodexFilter:New(...)
    return MultiChoiceFilterBase.New(self,...)
end

function UnknownCodexFilter:Initialize()

  local filterIcons = {}
  filterIcons[1] = {
    id = "never",
    label = "Never Dug Out",
    icon = "EsoUI/Art/Campaign/overview_indexIcon_bonus_%s.dds",
  }
  filterIcons[2] = {
    id = "missing",
    label = "Missing Entries",
    icon = "EsoUI/Art/Journal/journal_tabIcon_loreLibrary_%s.dds",
  }

  MultiChoiceFilterBase.Initialize(self, FILTER_ID_UCF, AGS.class.FilterBase.GROUP_LOCAL, ("Codex Knowledge"), filterIcons )

  self:SetEnabledSubcategories({
    [SUB_CATEGORY_ID.CONSUMABLE_TROPHY] = true,
  })

end

function UnknownCodexFilter:FilterLocalResult(itemLink)

  	local antiquityId = LootLog.GetAntiquityIdFromItem(itemLink.itemLink)
  	-- don't show non leads, if filter is active
  	if antiquityId == 0 then
	  return false
	end

    local valueNever = self.valueById['never']
    local selectionNever = self.localSelection[valueNever]

    local valueMissing = self.valueById['missing']
    local selectionMissing = self.localSelection[valueMissing]

  	local numAquired = GetNumAntiquityLoreEntriesAcquired(antiquityId)
  	local numEntries = GetNumAntiquityLoreEntries(antiquityId)

    -- consider active leads as already acquired
	local leadInProgressAdd
    if DoesAntiquityHaveLead(antiquityId) then 
    	numAquired = numAquired+1 
    end

    if selectionNever then
      return numAquired == 0
    end
    
    if selectionMissing then
      if numAquired < numEntries then
	    return true
	  else
	    return false
	  end
    end

	d("something is wrong")
end

function ALF.initAGS()
  AGS:RegisterFilter(UnknownCodexFilter:New())
  AGS:RegisterFilterFragment(AGS.class.MultiButtonFilterFragment:New(FILTER_ID_UCF))
end