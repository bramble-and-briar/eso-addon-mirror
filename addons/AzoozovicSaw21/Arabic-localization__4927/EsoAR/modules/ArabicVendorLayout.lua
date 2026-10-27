-- Target the vendor quantity control and priced item rows only.
local R = ESO_ARABIC_TEXT
local function Active() return R and R.IsActive() and IsInGamepadPreferredMode() end
local function Quantity(container)
    if not Active() then return end
    local spinner = container:GetNamedChild("Spinner")
    local display = spinner and spinner:GetNamedChild("Display")
    if not display then return end
    local scale = GetUIGlobalScale()
    -- Reserve room for the entire stack, not just the current digit count.
    local text = display:GetText() or ""
    local digits = math.max(display:GetStringWidth(text), display:GetStringWidth("1000")) / scale
    spinner:SetWidth(digits + 56)
    display:SetMaxLineCount(1)
    -- Keep native row height and price position; give arrows a wider numeric field.
    spinner:ClearAnchors()
    spinner:SetAnchor(CENTER, container, CENTER, -20, 0)
    local price = container:GetNamedChild("Price")
    if price then price:SetFont("ZoFontGamepad34") end

end
local function ItemRow(_, control)
    if not Active() then return end
    local label = control:GetNamedChild("Label")
    local price = control:GetNamedChild("Price")
    local spacer = control:GetNamedChild("RootSpacer")
    if not label or not price or not spacer then return end
    -- Price remains in its native right column; smaller numerals free name space.
    price:SetFont("ZoFontGamepad27")
    local width = label:GetWidth()
    if width <= 40 then return end
    local refresh = R.BindLabel(label, {flow=true, autoWidth=false, width=width,
        size=26, minimum=26, align=TEXT_ALIGN_RIGHT, reflowVisual=true})
    if refresh then refresh() end
end
if SecurePostHook then
    if ZO_GamepadQuantitySpinner then
        SecurePostHook(ZO_GamepadQuantitySpinner, "SetValue", Quantity)
        SecurePostHook(ZO_GamepadQuantitySpinner, "OnValueChanged", Quantity)
        SecurePostHook(ZO_GamepadQuantitySpinner, "AttachAndShowSpinner", Quantity)
    end
    if ZO_GamepadStoreListComponent then
        SecurePostHook(ZO_GamepadStoreListComponent, "SetupStoreItem", ItemRow)
    end
end
