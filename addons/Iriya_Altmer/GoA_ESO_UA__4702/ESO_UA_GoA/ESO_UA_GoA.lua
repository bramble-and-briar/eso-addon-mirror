ESO_UA_GoA = {}
local ESO_UA_GoA = ESO_UA_GoA
ESO_UA_GoA.name  = "ESO_UA_GoA"
ESO_UA_GoA.version = "1.08"
ESO_UA_GoA.langString = nil
ESO_UA_GoA.positionning = false
ESO_UA_GoA.Flags = { "en", "ua" }

ESO_UA_GoA.defaults = {
	Enable	= true,
	welcomeHidden = false,
	autoApplied = false,
	anchor	= {BOTTOMRIGHT, BOTTOMRIGHT, 0, 7},
	Flags = {
		["en"]	= true,
		["ua"]	= true,
	}
}
ESO_UA_GoA.settings = ESO_UA_GoA.defaults

function ESO_UA_GoA.ChangeLanguage(lang)
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
			if flagControl:GetHandler("OnMouseDown") == nil then flagControl:SetHandler("OnMouseDown", function() ESO_UA_GoA.ChangeLanguage(flagCode) end) end
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

function ESO_UA_GoA.Selected()
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

ESO_UA_GoA.welcomeText = "Дякуємо, що обираєте українську!\n\nЛаскаво просимо до світу The Elder Scrolls українською мовою!\n\nЦей українізатор та інші доповнення від Guards of Amber створюються з любов'ю до Тамріелю, української мови та нашої спільноти. Ми раді, що разом із вами робимо світ ESO доступнішим і ближчим українською.\n\nОкрема подяка гравцям на консолях!\n\nДякуємо всім, хто користується нашими доповненнями та підтримує проєкти GoA, навіть попри особливості й обмеження консольних платформ. Ваша увага та підтримка для нас особливо цінні!\n\nКілька слів про встановлення\n\nНе хвилюйтеся про додаткові налаштування чи ручне створення таблиць для Tamriel Trade Centre. Для наших доповнень усе максимально просто: встановили потрібний аддон - і можна користуватися! Жодних зайвих маніпуляцій із таблицями чи додатковою генерацією.\n\nХочете підтримати розвиток проєкту?\n\nПереклад, розробка та підтримка доповнень потребують чимало часу й зусиль. Якщо вам подобається наша робота, будемо щиро вдячні за добровільну підтримку.\n\nКожен внесок - це ще один крок до повноцінного українського Тамріелю!\n\nПідтримати проєкт на Monobank:\nhttps://send.monobank.ua/jar/6jgXQDVFzN\n\nПриєднатися до нашої спільноти в Discord:\nhttps://discord.gg/cVNYKrTmej\n\nУ Discord ви можете спілкуватися з іншими українськими гравцями, повідомляти про помилки перекладу, пропонувати покращення та стежити за новинами й оновленнями наших доповнень.\n\nДякуємо, що ви з нами!\n\nGuards of Amber\nЗа український Тамріель!"

function ESO_UA_GoA.BuildWelcome()
	local wm = WINDOW_MANAGER
	local win = wm:CreateTopLevelWindow("ESO_UA_GoA_Welcome")
	win:SetDimensions(820, 640)
	win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
	win:SetMouseEnabled(true)
	win:SetDrawTier(DT_HIGH)
	win:SetDrawLayer(DL_OVERLAY)
	win:SetHidden(true)
	win:SetHandler("OnMouseUp", function(_, b, up) if up and b == MOUSE_BUTTON_INDEX_RIGHT then ESO_UA_GoA.CloseWelcome() end end)

	local bg = wm:CreateControl("ESO_UA_GoA_WelcomeBg", win, CT_BACKDROP)
	bg:SetAnchorFill(win)
	bg:SetCenterColor(0, 0, 0, 0.92)
	bg:SetEdgeColor(0.77, 0.69, 0.48, 1)
	bg:SetEdgeTexture("", 1, 1, 2)

	local title = wm:CreateControl("ESO_UA_GoA_WelcomeTitle", win, CT_LABEL)
	title:SetFont("ZoFontWinH2")
	title:SetText("GoA_ESO_UA")
	title:SetAnchor(TOP, win, TOP, 0, 14)

	local qr = wm:CreateControl("ESO_UA_GoA_WelcomeQR", win, CT_TEXTURE)
	qr:SetDimensions(170, 170)
	qr:SetTexture("ESO_UA_GoA/images/qr.dds")
	qr:SetAnchor(TOPRIGHT, win, TOPRIGHT, -24, 64)

	local cap = wm:CreateControl("ESO_UA_GoA_WelcomeQRCaption", win, CT_LABEL)
	cap:SetFont("ZoFontGameSmall")
	cap:SetText("Monobank")
	cap:SetAnchor(TOP, qr, BOTTOM, 0, 4)

	local scroll = wm:CreateControlFromVirtual("ESO_UA_GoA_WelcomeScroll", win, "ZO_ScrollContainer")
	scroll:SetAnchor(TOPLEFT, win, TOPLEFT, 24, 64)
	scroll:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -216, -70)
	local child = scroll:GetNamedChild("ScrollChild")
	local label = wm:CreateControl("ESO_UA_GoA_WelcomeText", child, CT_LABEL)
	label:SetFont("ZoFontGame")
	label:SetWidth(540)
	label:SetAnchor(TOPLEFT, child, TOPLEFT, 0, 0)
	label:SetText(ESO_UA_GoA.welcomeText)

	local btn = wm:CreateControlFromVirtual("ESO_UA_GoA_WelcomeClose", win, "ZO_DefaultButton")
	btn:SetDimensions(200, 28)
	btn:SetText("Закрити")
	btn:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -24, -18)
	btn:SetMouseEnabled(true)
	btn:SetHandler("OnClicked", function() ESO_UA_GoA.CloseWelcome() end)
	btn:SetHandler("OnMouseUp", function(_, b, up) if up and b == MOUSE_BUTTON_INDEX_LEFT then ESO_UA_GoA.CloseWelcome() end end)

	local chk = wm:CreateControlFromVirtual("ESO_UA_GoA_WelcomeCheck", win, "ZO_CheckButton")
	chk:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 24, -24)
	local chkLabel = wm:CreateControl("ESO_UA_GoA_WelcomeCheckLabel", win, CT_LABEL)
	chkLabel:SetFont("ZoFontGame")
	chkLabel:SetText("Більше не показувати")
	chkLabel:SetAnchor(LEFT, chk, RIGHT, 8, 0)
	return win
end

function ESO_UA_GoA.SetQRShown(show)
	local q = ESO_UA_GoA_QRWin
	if q == nil then
		if not show then return end
		q = WINDOW_MANAGER:CreateTopLevelWindow("ESO_UA_GoA_QRWin")
		q:SetDimensions(440, 500)
		q:SetAnchor(CENTER, GuiRoot, CENTER, 480, -40)
		q:SetDrawTier(DT_HIGH)
		q:SetDrawLayer(DL_OVERLAY)
		local bg = WINDOW_MANAGER:CreateControl("ESO_UA_GoA_QRWinBg", q, CT_BACKDROP)
		bg:SetAnchorFill(q)
		bg:SetCenterColor(0, 0, 0, 0.92)
		bg:SetEdgeColor(0.77, 0.69, 0.48, 1)
		bg:SetEdgeTexture("", 1, 1, 2)
		local t = WINDOW_MANAGER:CreateControl("ESO_UA_GoA_QRWinTex", q, CT_TEXTURE)
		t:SetDimensions(400, 400)
		t:SetTexture("ESO_UA_GoA/images/qr.dds")
		t:SetAnchor(TOP, q, TOP, 0, 20)
		local l = WINDOW_MANAGER:CreateControl("ESO_UA_GoA_QRWinLabel", q, CT_LABEL)
		l:SetFont("ZoFontGameBold")
		l:SetText("Підтримати проєкт - Monobank")
		l:SetAnchor(TOP, t, BOTTOM, 0, 14)
	end
	q:SetHidden(not show)
end

function ESO_UA_GoA.ShowNativeDialog()
	if not ESO_UA_GoA.dialogRegistered then
		ZO_Dialogs_RegisterCustomDialog("ESO_UA_GOA_WELCOME", {
			gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
			canQueue = true,
			noChoiceCallback = function() ESO_UA_GoA.SetQRShown(false) end,
			finishedCallback = function() ESO_UA_GoA.SetQRShown(false) end,
			title = { text = "GoA_ESO_UA" },
			mainText = { text = ESO_UA_GoA.welcomeText },
			buttons = {
				{ text = "Закрити", keybind = "DIALOG_PRIMARY", callback = function() ESO_UA_GoA.SetQRShown(false) end },
				{ text = "Більше не показувати", keybind = "DIALOG_NEGATIVE", callback = function() ESO_UA_GoA.settings.welcomeHidden = true ESO_UA_GoA.SetQRShown(false) end },
			},
		})
		ESO_UA_GoA.dialogRegistered = true
	end
	ESO_UA_GoA.SetQRShown(true)
	ZO_Dialogs_ShowPlatformDialog("ESO_UA_GOA_WELCOME")
end

function ESO_UA_GoA.ShowWelcome()
	if IsInGamepadPreferredMode() then
		ESO_UA_GoA.ShowNativeDialog()
		return
	end
	local win = ESO_UA_GoA_Welcome or ESO_UA_GoA.BuildWelcome()
	ZO_CheckButton_SetCheckState(ESO_UA_GoA_WelcomeCheck, false)
	win:SetHidden(false)
	ESO_UA_GoA.welcomeOpen = true
	SCENE_MANAGER:SetInUIMode(true)
end

function ESO_UA_GoA.CloseWelcome()
	if ESO_UA_GoA_Welcome == nil or not ESO_UA_GoA.welcomeOpen then return end
	ESO_UA_GoA.welcomeOpen = false
	if ZO_CheckButton_IsChecked(ESO_UA_GoA_WelcomeCheck) then
		ESO_UA_GoA.settings.welcomeHidden = true
	end
	ESO_UA_GoA_Welcome:SetHidden(true)
	SCENE_MANAGER:SetInUIMode(false)
end

function ESO_UA_GoA.OnPlayerActivated()
	EVENT_MANAGER:UnregisterForEvent(ESO_UA_GoA.name .. "_Welcome", EVENT_PLAYER_ACTIVATED)
	if not ESO_UA_GoA.settings.welcomeHidden then
		zo_callLater(ESO_UA_GoA.ShowWelcome, 3000)
	end
end

function ESO_UA_GoA:OnInit(eventCode, addOnName)
	ESO_UA_GoA.langString = GetCVar("language.2")
	ESO_UA_GoA.settings = ZO_SavedVars:NewAccountWide("ESO_UA_GoA_settings", 1, nil, ESO_UA_GoA.defaults)

	for _, flagCode in pairs(ESO_UA_GoA.Flags) do
		ZO_CreateStringId("SI_BINDING_NAME_"..string.upper(flagCode), string.upper(flagCode))
	end

	ESO_UA_GoA:RefreshUI()
	-- Автоматичне вмикання української при першому запуску (для консолей без прапорців)
	if not ESO_UA_GoA.settings.autoApplied then
		ESO_UA_GoA.settings.autoApplied = true
		if GetCVar("language.2") ~= "ua" then
			ESO_UA_GoA.ChangeLanguage("ua")
			zo_callLater(function() ReloadUI("ingame") end, 1500)
		end
	end
	ESO_UA_GoAUI:ClearAnchors()
	ESO_UA_GoAUI:SetAnchor(ESO_UA_GoA.settings.anchor[1], GuiRoot, ESO_UA_GoA.settings.anchor[2], ESO_UA_GoA.settings.anchor[3], ESO_UA_GoA.settings.anchor[4])
	ESO_UA_GoA:registerEvents(true)
	EVENT_MANAGER:RegisterForEvent(ESO_UA_GoA.name .. "_Welcome", EVENT_PLAYER_ACTIVATED, ESO_UA_GoA.OnPlayerActivated)

	EVENT_MANAGER:UnregisterForEvent(ESO_UA_GoA.name, EVENT_ADD_ON_LOADED)
end

function ESO_UA_GoA:registerEvents(state)
	if state then
		EVENT_MANAGER:RegisterForEvent(ESO_UA_GoA.name, EVENT_RETICLE_HIDDEN_UPDATE, function(eventCode, hidden) if ESO_UA_GoA.settings.Enable then ESO_UA_GoAUI:SetHidden(not hidden) end end)
	else
		EVENT_MANAGER:UnregisterForEvent(ESO_UA_GoA.name, EVENT_RETICLE_HIDDEN_UPDATE)
	end
end

SLASH_COMMANDS["/goa"] = ESO_UA_GoA.ShowWelcome

EVENT_MANAGER:RegisterForEvent(ESO_UA_GoA.name, EVENT_ADD_ON_LOADED , function(_event, _name) if _name == ESO_UA_GoA.name then ESO_UA_GoA:OnInit(_event, _name) end end)

-- Фікс: "Скриня" -> "Тулуб" лише для назв слота броні (не для скринь-контейнерів у світі,
-- бо ті беруть назву з окремого джерела і цей override їх не зачіпає)
SafeAddString(SI_EQUIPSLOT2, "Тулуб", 0)
SafeAddString(SI_EQUIPTYPE3, "Тулуб", 0)
SafeAddString(SI_OUTFITSLOT1, "Тулуб", 0)
SafeAddString(SI_GAMEPADITEMCATEGORY6, "Тулуб", 0)
SafeAddString(SI_GAMEPADITEMCATEGORY43, "Тулуб супутника", 0)