AUI.Minimap.Theme = {}
												
local gMiniMapThemes = {}		
local g_isInit = false

function AUI.Minimap.Theme.Add(internName, displayName, themeData)
	if not AUI.Minimap.IsLoaded() or not internName or not displayName or not themeData then
		return
	end
	
	themeData.displayName = displayName
	
	table.insert(gMiniMapThemes, {[internName] = themeData})
end

function AUI.Minimap.Theme.GetNameList()
	local names = {}

	for _index, tableData in pairs(gMiniMapThemes) do	
		for _internName, data in pairs(tableData) do	
			if data.displayName then
				table.insert(names, {[_internName] = data.displayName})
			end
		end
	end
	
	return names
end

function AUI.Minimap.Theme.GetAll()
	if not AUI.Minimap.IsLoaded() then
		return nil
	end

	return gMiniMapThemes
end

function AUI.Minimap.Theme.GetActive()
	if not AUI.Minimap.IsLoaded() then
		return nil
	end

	local currentTheme = AUI.Table.GetValue(gMiniMapThemes, AUI.Settings.Minimap.theme)

	if currentTheme == nil then
		currentTheme = AUI.Table.GetValue(gMiniMapThemes, "default")	
	end
		
	return currentTheme
end

function AUI.Minimap.Theme.Load()
	if g_isInit then
		return
	end

	AUI.Minimap.UI.Update()	
	
	g_isInit = true
end