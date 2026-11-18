-- Display only: never calls WW's SetPanelText, which also queues WW work.
WWDpadPendingHUD = {}
local H = WWDpadPendingHUD
local label, previousText, pendingText

function H.Clear()
    -- If WW has already written a newer status, keep that newer status.
    if label and type(label.GetText) == "function" and label:GetText() == pendingText then
        label:SetText(previousText or "")
    end
    label, previousText, pendingText = nil, nil, nil
end

function H.Show(plan)
    H.Clear()
    local control = WizardsWardrobePanelBottomLabel
    if not control or type(control.SetText) ~= "function" or type(control.GetText) ~= "function" then return end
    local name = plan.setupRef and plan.setupRef.name
    if type(name) ~= "string" or name == "" then name = "Setup " .. tostring(plan.index) end
    name = name:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    local ww = WizardsWardrobe
    local color = ww and ww.LOGTYPES and ww.LOGTYPES.INFO or "F8FF70"
    label, previousText = control, control:GetText()
    pendingText = "|c" .. color .. name .. " - ausstehend|r"
    control:SetText(pendingText)
end
