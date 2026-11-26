local A = AntiquityAtlas

function A.InitJournalButton()
    if A.journalButton then return end
    local journal = ANTIQUITY_JOURNAL_KEYBOARD
    -- The journal object can exist before its deferred controls are initialized.
    if not journal or not journal.contents or not journal.contentsCategories then
        if not A.journalInitHooked and ZO_AntiquityJournal_Keyboard
            and type(ZO_AntiquityJournal_Keyboard.InitializeControls) == "function" then
            A.journalInitHooked = true
            ZO_PostHook(ZO_AntiquityJournal_Keyboard, "InitializeControls", function()
                A.InitJournalButton()
            end)
        end
        return
    end
    local contents = journal.contents
    local search = contents:GetNamedChild("Search")
    if not search then return end
    local categories = journal.contentsCategories
    local control = WINDOW_MANAGER:CreateControlFromVirtual("AntiquityAtlasJournalButton", contents, "ZO_DefaultButton")
    control:SetAnchor(TOPLEFT, search, BOTTOMLEFT, 0, 8)
    control:SetDimensions(240, 32)
    control:SetFont("$(BOLD_FONT)|20|soft-shadow-thin")
    control:SetText("|cFFD66BAntiquity Atlas|r")
    control:SetHandler("OnClicked", function()
        if not A.window then return end
        A.Refresh()
        SCENE_MANAGER:ShowTopLevel(A.window)
    end)

    local background = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    background:SetAnchorFill()
    background:SetCenterColor(0.28, 0.16, 0.025, 0.95)
    background:SetEdgeColor(1, 0.72, 0.2, 1)
    background:SetEdgeTexture(nil, 1, 1, 2)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetMouseEnabled(false)
    control:SetHandler("OnMouseEnter", function()
        background:SetCenterColor(0.45, 0.27, 0.04, 1)
    end)
    control:SetHandler("OnMouseExit", function()
        background:SetCenterColor(0.28, 0.16, 0.025, 0.95)
    end)

    -- Reserve a row in the left column; keep the native scroll area's bottom.
    categories:ClearAnchors()
    categories:SetAnchor(TOPLEFT, control, BOTTOMLEFT, -43, 8)
    categories:SetAnchor(BOTTOMLEFT, contents, BOTTOMLEFT, -34, 0)
    A.journalButton = control
    EVENT_MANAGER:UnregisterForEvent("AntiquityAtlasJournalButton", EVENT_PLAYER_ACTIVATED)
end

EVENT_MANAGER:RegisterForEvent("AntiquityAtlasJournalButton", EVENT_PLAYER_ACTIVATED, function()
    A.InitJournalButton()
end)
