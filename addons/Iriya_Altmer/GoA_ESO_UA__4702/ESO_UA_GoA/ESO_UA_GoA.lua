local ESO_UA_GoA = {}
ESO_UA_GoA.name  = "ESO_UA_GoA"
ESO_UA_GoA.version = "1.07"
ESO_UA_GoA.langString = nil
ESO_UA_GoA.positionning = false
ESO_UA_GoA.Flags = { "en", "ua" }

ESO_UA_GoA.defaults = {
	Enable	= true,
	anchor	= {BOTTOMRIGHT, BOTTOMRIGHT, 0, 7},
	Flags = {
		["en"]	= true,
		["ua"]	= true,
	}
}
ESO_UA_GoA.settings = ESO_UA_GoA.defaults

local confirmDialog = {
    title = { text = zo_iconFormat("ESO_UA_GoA/images/".."es.dds", 24, 24).." ESO_UA_GoA "..zo_iconFormat("ESO_UA_GoA/images/".."es.dds", 24, 24)},
    mainText = { text = "Безмежно дякуємо за встановлення «EsoUA»!\n\nУвімкнути локалізацію можна за допомогою прапорців, натисніть на кнопку «ESC», у правому нижньому куті вашого екрана мають з’явитись два прапорці з вибором мови (англійська, українська).\n\nКлацніть на прапорець, і приємної гри!\n\n— GoA" },
    buttons = {
        { text = SI_DIALOG_ACCEPT, callback = functionToCall},
    }
}
ZO_Dialogs_RegisterCustomDialog("ADDON_DIALOG", confirmDialog )

if GetCVar("IgnorePatcherLanguageSetting") == "0" then
	ZO_Dialogs_ShowDialog("ADDON_DIALOG")
end

function ESO_UA_GoA_ChangeLanguage(lang)
	if lang ~= GetCVar("language.2") then
	  if lang == "en" then
		SetCVar("IgnorePatcherLanguageSetting", 0)
	  else
		SetCVar("IgnorePatcherLanguageSetting", 1)
	  end
	  SetCVar("language.2", lang)
	end
  end


function ESO_UA_GoA:RefreshUI()
	local flagControl
	local count = 0
	local flagTexture
	for _, flagCode in pairs(ESO_UA_GoA.Flags) do
		flagTexture = "ESO_UA_GoA/images/"..flagCode..".dds"
		flagControl = GetControl("ESO_UA_GoA_FlagControl_"..tostring(flagCode))
		if flagControl == nil then
			flagControl = CreateControlFromVirtual("ESO_UA_GoA_FlagControl_", ESO_UA_GoAUI, "ESO_UA_GoA_FlagControl", tostring(flagCode))
			if flagControl:GetHandler("OnMouseDown") == nil then flagControl:SetHandler("OnMouseDown", function() ESO_UA_GoA_ChangeLanguage(flagCode) end) end
			GetControl("ESO_UA_GoA_FlagControl_"..flagCode.."Texture"):SetTexture(flagTexture)
		end
		if ESO_UA_GoA.settings.Flags[flagCode] then
			flagControl:ClearAnchors()
			flagControl:SetAnchor(LEFT, ESO_UA_GoAUI, LEFT, 14 +count*34, 0)
			count = count +1
		end
		flagControl:SetMouseEnabled(true)
		flagControl:SetHidden(not ESO_UA_GoA.settings.Flags[flagCode])
	end
	ESO_UA_GoAUI:SetDimensions(25 +count*34, 50)
	ESO_UA_GoAUI:SetMouseEnabled(true)

end

function ESO_UA_GoA_Selected()
	if ESO_UA_GoAUI == nil then return end
	if ESO_UA_GoAUI.GetSelected then
		local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = ESO_UA_GoAUI:GetSelected()
		if isValidAnchor then
			ESO_UA_GoA.settings.anchor = { point, relativePoint, offsetX, offsetY }
		end
	elseif ESO_UA_GoAUI.GetAnchor then
		local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = ESO_UA_GoAUI:GetAnchor(0)
		if isValidAnchor then
			ESO_UA_GoA.settings.anchor = { point, relativePoint, offsetX, offsetY }
		end
	end
end

function ESO_UA_GoA:OnInit(eventCode, addOnName)
	ESO_UA_GoA.langString = GetCVar("language.2")
	ESO_UA_GoA.settings = ZO_SavedVars:NewAccountWide("ESO_UA_GoA_settings", 1, nil, ESO_UA_GoA.defaults)

	for _, flagCode in pairs(ESO_UA_GoA.Flags) do
		ZO_CreateStringId("SI_BINDING_NAME_"..string.upper(flagCode), string.upper(flagCode))
	end

	ESO_UA_GoA:RefreshUI()
	ESO_UA_GoAUI:ClearAnchors()
	ESO_UA_GoAUI:SetAnchor(ESO_UA_GoA.settings.anchor[1], GuiRoot, ESO_UA_GoA.settings.anchor[2], ESO_UA_GoA.settings.anchor[3], ESO_UA_GoA.settings.anchor[4])
	ESO_UA_GoA:registerEvents(true)

	EVENT_MANAGER:UnregisterForEvent(ESO_UA_GoA.name, EVENT_ADD_ON_LOADED)
end

function ESO_UA_GoA:registerEvents(state)
	if state then
		EVENT_MANAGER:RegisterForEvent(ESO_UA_GoA.name, EVENT_RETICLE_HIDDEN_UPDATE, function(eventCode, hidden) if ESO_UA_GoA.settings.Enable then ESO_UA_GoAUI:SetHidden(not hidden) end end)
	else
		EVENT_MANAGER:UnregisterForEvent(ESO_UA_GoA.name, EVENT_RETICLE_HIDDEN_UPDATE)
	end
end

EVENT_MANAGER:RegisterForEvent(ESO_UA_GoA.name, EVENT_ADD_ON_LOADED , function(_event, _name) ESO_UA_GoA:OnInit(_event, _name) end)

-- Фікс: "Скриня" -> "Тулуб" лише для назв слота броні (не для скринь-контейнерів у світі,
-- бо ті беруть назву з окремого джерела і цей override їх не зачіпає)
SafeAddString(SI_EQUIPSLOT2, "Тулуб", 0)
SafeAddString(SI_EQUIPTYPE3, "Тулуб", 0)
SafeAddString(SI_OUTFITSLOT1, "Тулуб", 0)
SafeAddString(SI_GAMEPADITEMCATEGORY6, "Тулуб", 0)
SafeAddString(SI_GAMEPADITEMCATEGORY43, "Тулуб супутника", 0)