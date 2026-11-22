local function compareNames(n1, n2)
	if n1:sub(1, 3) == 'The' then
		n1 = n1:sub(5)
	end
	if n2:sub(1, 3) == 'The' then
		n2 = n2:sub(5)
	end
	
	return n1 < n2
end

table.sort(ZO_ACTIVITY_FINDER_ROOT_MANAGER.sortedLocationsData[2], function(a, b) return compareNames(a.rawName, b.rawName) end)
table.sort(ZO_ACTIVITY_FINDER_ROOT_MANAGER.sortedLocationsData[3], function(a, b) return compareNames(a.rawName, b.rawName) end)
ZO_ACTIVITY_FINDER_ROOT_MANAGER:UpdateLocationData()
