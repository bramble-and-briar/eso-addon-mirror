local SET_COFFERS = {
	[226944] = 12, -- Torc of Tonal Constancy Antiquities Coffer
}

function LootLog.GetAntiquitySetIdFromItem( item )
	if (type(item) == "string") then
		item = GetItemLinkItemId(item)
	end
	return SET_COFFERS[item or 0] or 0
end
