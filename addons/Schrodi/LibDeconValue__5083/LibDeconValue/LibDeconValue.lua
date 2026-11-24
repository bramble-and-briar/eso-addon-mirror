LibDeconValue = LibDeconValue or { }
local LibDeconValue = LibDeconValue

function LibDeconValue:GetDeconValue(itemLink, minMatPrice)
	local expectation = LibDeconValue:FindDeconstructionExpectation(itemLink, LibDeconValue.Analysis.ItemSaleValue, minMatPrice)
	if expectation then return expectation.value or 0 end
	return 0
end

function LibDeconValue:GetVendorValue(itemLink)
	return LibDeconValue.Analysis.ItemVendorValue(itemLink) or 0
end