AUI.Unit = {}

function AUI.Unit.IsGroupUnitTag(_unitTag)	
	if _unitTag then
		if _unitTag:match("^group(%d+)$") then
			return true
		end
	end
end

function AUI.Unit.IsBossUnitTag(_unitTag)	
	if _unitTag and _unitTag:match("^boss(%d+)$") then
		return true
	end
end
