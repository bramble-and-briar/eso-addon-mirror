-- Align the compose form without moving panes or changing editable text.
local R = ESO_ARABIC_TEXT
local function AlignCompose(self)
    if not R or not R.IsActive() then return end
    local view = self.mailView
    if not view then return end
    local width = view:GetWidth()
    if width <= 0 then return end
    -- Keep the native left anchors: the fields are anchored below these labels.
    for _, name in ipairs({"AddressLabel", "SubjectLabel", "BodyLabel"}) do
        local label = view:GetNamedChild(name)
        if label then
            label:SetWidth(width)
            label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
    end
    local box = view.attachmentsBox
    if box then
        local moneyLabel = box:GetNamedChild("MoneyLabel")
        moneyLabel:ClearAnchors()
        moneyLabel:SetAnchor(TOPRIGHT, box, TOPRIGHT)
        moneyLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        for _, name in ipairs({"Money", "NoMoney"}) do
            local value = box:GetNamedChild(name)
            value:ClearAnchors()
            value:SetAnchor(TOPRIGHT, moneyLabel, BOTTOMRIGHT, 0, 3)
            value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
        local attachments = box:GetNamedChild("AttachmentsLabel")
        attachments:ClearAnchors()
        attachments:SetAnchor(TOPLEFT, box, TOPLEFT)
        local slotCount = #(view.attachmentSlots or {})
        -- Native slots are 55 wide with 8 spacing, starting at the label's left.
        attachments:SetWidth(math.max(1, slotCount) * (55 + 8))
        attachments:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        -- Slots retain their native chain starting at AttachmentsBase below this label.
    end
    for _, name in ipairs({"addressEdit", "subjectEdit"}) do
        local field = view[name]
        local edit = field and field.edit
        if edit and not edit.esoArabicPlaceholder then
            local hint = edit:GetDefaultText()
            if hint and hint ~= "" then
                local overlay = WINDOW_MANAGER:CreateControl(nil, field, CT_LABEL)
                overlay:SetAnchor(TOPLEFT, edit, TOPLEFT)
                overlay:SetAnchor(BOTTOMRIGHT, edit, BOTTOMRIGHT)
                overlay:SetFont(edit:GetFont())
                overlay:SetColor(0, 0, 0, 1)
                overlay:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                overlay:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                overlay:SetMouseEnabled(false)
                overlay:SetText(hint)
                edit.esoArabicPlaceholder = overlay
                edit:SetDefaultText("")
                local function Refresh()
                    overlay:SetHidden(not R.IsActive() or edit:GetText() ~= "")
                end
                ZO_PostHookHandler(edit, "OnTextChanged", Refresh)
                Refresh()
            end
        end
    end

end
if ZO_MailSend_Gamepad and SecurePostHook then
    SecurePostHook(ZO_MailSend_Gamepad, "OnShowing", AlignCompose)
    SecurePostHook(ZO_MailSend_Gamepad, "InitializeControls", AlignCompose)
end
