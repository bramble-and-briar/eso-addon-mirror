-- A compact in-game test, opened only when the player types /artest.
local R = ESO_ARABIC_TEXT
local panel, labels
local function show()
    if GetCVar("Language.2") ~= "ar" then d("Select Arabic with /ar first."); return end
    if panel and not panel:IsHidden() then panel:SetHidden(true); return end
    if not panel then
        panel = WINDOW_MANAGER:CreateTopLevelWindow("ESOArabicTestPanel")
        panel:SetDimensions(820, 650)
        panel:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        panel:SetMouseEnabled(true)
        panel:SetMovable(true)
        panel:SetClampedToScreen(true)
        local bg = WINDOW_MANAGER:CreateControl(nil, panel, CT_BACKDROP)
        bg:SetAnchorFill(panel)
        bg:SetCenterColor(0.025, 0.035, 0.055, 0.98)
        bg:SetEdgeColor(0.7, 0.6, 0.3, 1)
        local close = WINDOW_MANAGER:CreateControl(nil, panel, CT_BUTTON)
        close:SetDimensions(44, 40)
        close:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, 8)
        close:SetFont("EsoAR/fonts/ArabicUIBold.slug|28")
        close:SetText("X")
        close:SetNormalFontColor(1, 1, 1, 1)
        close:SetHandler("OnClicked", function() panel:SetHidden(true) end)
        labels = {}
        for i = 1, 7 do
            local c = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
            c:SetFont("EsoAR/fonts/ArabicUI.slug|26")
            c:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            labels[i] = c
            R.Manage(c)
        end
    end
    local gp = IsInGamepadPreferredMode()
    local samples = {
        "اختبار التعريب 1.3.2 — " .. (gp and "يد التحكم" or "الكيبورد"),
        "بالسلاح — السلاح — العالم — علامتنا — الاحتمالات",
        "لا — إلا — ألا — للاعب — اللاعبون — الله",
        "الضرر 4855، النسبة 48.6%، الساعة 12:34، المكونات (13)",
        "تحدث مع Calanwe Larethil في سكايريم الغربية.",
        "الوصفة: أمبروزيا بسيجيك، الجزء الثالث",
        "سؤال جيد! كنت خياطا متدربا في المدينة الإمبراطورية، لكن سيدي العجوز الغاضب لم يكن ينوي التقاعد.\n\nانضممت إلى قطار الإمداد في الفيلق السابع. لسنوات، كان إصلاح درع الدفء يصقل إتقانه.\n\nدعني أضع علامة على خريطتك. الروابط المتآكلة للقدر تشير إلى روستوال، وأطلال إلينغلين، وأوستومير.\n\nصديقي بيراغون عرض منزله في سكينغراد. لنلتقي هناك عندما ننتهي.",
    }
    local y = 24
    for i, logical in ipairs(samples) do
        local label = labels[i]
        local text = R.ShapeLogical(logical)
        -- Exercise the native grammar parser too; direct SetText alone cannot
        -- reproduce the lam-alef corruption fixed in ArabicFormatting.
        if i == 2 or i == 3 then text = zo_strformat("<<t:1>>", text) end
        label:SetWidth(750)
        label:SetText(text)
        label:ClearAnchors()
        label:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -28, y)
        label:SetColor(0.95, 0.94, 0.86, 1)
        if i == 1 then label:SetFont("EsoAR/fonts/ArabicUIBold.slug|28"); label:SetColor(1, 0.82, 0.35, 1) end
        if i == 6 then label:SetColor(0.72, 0.3, 1, 1) end
        R.ProcessControl(label, {managed = true, text = text, width = 750, size = 26, flow = true, force = true})
        y = y + label:GetTextHeight() + 17
    end
    panel:SetHeight(y + 16)
    panel:SetHidden(false)
end
SLASH_COMMANDS["/artest"] = show
