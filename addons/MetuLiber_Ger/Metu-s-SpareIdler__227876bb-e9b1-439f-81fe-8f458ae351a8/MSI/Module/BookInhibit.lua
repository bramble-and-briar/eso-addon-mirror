-- BookInhibit.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']

--******************************************************--
-- Hides the book by showing the 'hudui' or 'inventory'
local function InhibitBook(eventCode, bookTitle, body)
	if not MSI.SVars.IsBookInhibit then return end
    if MSI.isPaused then return end
	MSI.ApplyRightScene(SCENE_MANAGER:GetCurrentScene():GetName())
	MSI.Print("c", zo_strformat(GetString(MSI_MOD_BOOK_INHIBITER_TITLE), MSI.Colorize(bookTitle)))
	end
local function InhibitBookOptionState()
	MSI.Print("c", zo_strformat(GetString(MSI_MOD_BOOK_INHIBITER_STATE), (MSI.SVars.IsBookInhibit and GetString(MSI_ADDON_ENABLED) or GetString(MSI_ADDON_DISABLED))))
	MSI.ShowCenterMsg(2468, [[icon_info.dds]], zo_strformat(GetString(MSI_MOD_BOOK_INHIBITER_STATE), (MSI.SVars.IsBookInhibit and GetString(MSI_ADDON_ENABLED) or GetString(MSI_ADDON_DISABLED))))
end
function MSI.MSIBook()
	MSI.SVars.IsBookInhibit = (not MSI.SVars.IsBookInhibit)
	InhibitBookOptionState()
end

--***********--
-- Book Inhibiter
function MSI.InitModBookInhibit()
	local function UnRegModuleEvents()
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."InhibitBook", EVENT_SHOW_BOOK)
	end
	local function RegModuleEvents()
		UnRegModuleEvents()
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."InhibitBook", EVENT_SHOW_BOOK, InhibitBook)
	end
	if MSI.SVars.IsBookInhibit and MSI.SVars.IsMSIActive then
		RegModuleEvents()
		--MSI.Print("d", "Modul enabled!! BookInhibit Event registered")
	elseif not MSI.SVars.IsBookInhibit or not MSI.SVars.IsMSIActive then
		UnRegModuleEvents()
		--MSI.Print("d", "Modul disabled!! BookInhibit Event unregistered")
	else
		UnRegModuleEvents()
		--MSI.Print("d", "MSI |c8B0000not|r Active!! BookInhibit Event unregistered")
	end
end
--eof