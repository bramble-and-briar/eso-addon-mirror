local O, A = OneCraft, OneCraft.Alchemy
local R = {}
A.RecipesUI = R

function R.SetOpen(open)
    R.popup:SetHidden(not open)
    R.arrowIcon:SetTexture("EsoUI/Art/Buttons/scrollbox_" .. (open and "down" or "up") .. "Arrow_up.dds")
    if open then R.popup:BringWindowToTop() end
end

function A.ChooseRecipe(key)
    if not A.active or A.IsBusy() then return false end
    -- Re-scan before accepting a popup row; bank stacks/locks can change meanwhile.
    A.ScanInventory()
    A.Resolve()
    for _, recipe in ipairs(A.matches) do
        if table.concat(recipe.ids, ":") == key then
            A.recipeKey, A.selected = key, recipe.ids
            A.CraftingIntegration.Apply()
            R.SetOpen(false)
            A.view:Refresh()
            return true
        end
    end
    A.CraftingIntegration.Apply()
    A.view:Refresh()
    return false
end

local function ingredientName(id)
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(A.ItemLink(id)))
end

function R.SetupRow(control, data)
    control:GetNamedChild("Selected"):SetHidden(data.key ~= A.recipeKey)
    control:GetNamedChild("Count"):SetText(string.format(O.text.crafts, data.maxCrafts))
    for i = 1, 3 do
        local id, icon, name = data.ids[i], control:GetNamedChild("Icon" .. i), control:GetNamedChild("Name" .. i)
        icon:SetHidden(not id)
        name:SetHidden(not id)
        if id then
            local item = A.inventory[id]
            local shade = item and item.count > 0 and 1 or 0.3
            icon:SetTexture(O.UI.Icon(A, id))
            icon:SetColor(shade, shade, shade, 1)
            name:SetText(ingredientName(id))
            name:SetAlpha(shade)
        end
    end
    control:SetHandler("OnMouseUp", function(_, button, inside)
        if inside and button == MOUSE_BUTTON_INDEX_LEFT then A.ChooseRecipe(data.key) end
    end)
    control:SetHandler("OnMouseEnter", function()
        control:GetNamedChild("Highlight"):SetAlpha(0.15)
        local names = {}
        for _, id in ipairs(data.ids) do names[#names + 1] = ingredientName(id) end
        InitializeTooltip(InformationTooltip, control, RIGHT)
        SetTooltipText(InformationTooltip, table.concat(names, " + "))
    end)
    control:SetHandler("OnMouseExit", function()
        control:GetNamedChild("Highlight"):SetAlpha(0)
        ClearTooltip(InformationTooltip)
    end)
end

function R.Rows()
    local rows, solvent = {}, A.SolventSelector.Item(A.level, A.kind)
    for _, recipe in ipairs(A.matches or {}) do
        local count = A.RecipeEngine.CraftCount(recipe.ids, A.inventory, solvent)
        if not A.SolventSelector.Available(A.level, A.kind) or
            (count > 0 and not A.CraftingIntegration.ExactResult(solvent, recipe.ids)) then count = 0 end
        rows[#rows + 1] = {ids = recipe.ids, key = table.concat(recipe.ids, ":"),
            maxCrafts = count}
    end
    table.sort(rows, function(a, b)
        if a.maxCrafts ~= b.maxCrafts then return a.maxCrafts > b.maxCrafts end
        if #a.ids ~= #b.ids then return #a.ids < #b.ids end
        return a.key < b.key
    end)
    return rows
end

function R.Refresh()
    if not A.view.visible then return end
    local count = #(A.matches or {})
    R.arrow:SetEnabled(count > 0 and not A.IsBusy())
    R.arrowIcon:SetAlpha(count > 0 and not A.IsBusy() and 1 or 0.3)
    if count == 0 then R.SetOpen(false) end
    if not R.popup:IsHidden() then
        ZO_ScrollList_Clear(R.list)
        local entries = ZO_ScrollList_GetDataList(R.list)
        for _, data in ipairs(R.Rows()) do
            entries[#entries + 1] = ZO_ScrollList_CreateDataEntry(1, data)
        end
        ZO_ScrollList_Commit(R.list)
        R.title:SetText(O.text.recipes .. " (" .. count .. ")")
    end
end

function R.Initialize()
    local view = A.view
    R.arrow = WINDOW_MANAGER:CreateControl("OneCraftRecipesArrow", view.nativeContainer, CT_BUTTON)
    R.arrow:SetDimensions(48, 48)
    R.arrow:SetAnchor(TOPRIGHT, view.nativeContainer, TOPRIGHT, -12, 12)
    R.arrow:SetHidden(true)
    R.arrowIcon = WINDOW_MANAGER:CreateControl(nil, R.arrow, CT_TEXTURE)
    R.arrowIcon:SetAnchorFill()
    R.arrow:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, RIGHT)
        SetTooltipText(InformationTooltip, O.text.recipeHint)
    end)
    R.arrow:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    R.arrow:SetHandler("OnClicked", function()
        if A.IsBusy() then return end
        if R.popup:IsHidden() then
            if #(A.matches or {}) > 0 then R.SetOpen(true); R.Refresh() end
        else R.SetOpen(false) end
    end)
    R.popup = WINDOW_MANAGER:CreateTopLevelWindow("OneCraftRecipesPopup")
    R.popup:SetDimensions(530, 448)
    R.popup:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    R.popup:SetDrawTier(DT_MEDIUM)
    R.popup:SetDrawLevel(ZO_MEDIUM_TIER_KEYBOARD_STANDARD_DIALOG - 100)
    R.popup:SetTopmost(false)
    R.popup:SetMouseEnabled(true)
    R.SetOpen(false)
    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual("OneCraftRecipesPopupBackdrop", R.popup, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill()
    R.title = WINDOW_MANAGER:CreateControl(nil, R.popup, CT_LABEL)
    R.title:SetFont("ZoFontWinH3")
    R.title:SetAnchor(TOPLEFT, R.popup, TOPLEFT, 16, 10)
    local close = WINDOW_MANAGER:CreateControl(nil, R.popup, CT_BUTTON)
    close:SetDimensions(36, 32)
    close:SetAnchor(TOPRIGHT, R.popup, TOPRIGHT, -8, 4)
    close:SetFont("ZoFontWinH2")
    close:SetText("×")
    close:SetHandler("OnClicked", function() R.SetOpen(false) end)
    R.list = WINDOW_MANAGER:CreateControlFromVirtual("OneCraftRecipesList", R.popup, "ZO_ScrollList")
    R.list:SetAnchor(TOPLEFT, R.popup, TOPLEFT, 12, 42)
    R.list:SetAnchor(BOTTOMRIGHT, R.popup, BOTTOMRIGHT, -12, -8)
    ZO_ScrollList_AddDataType(R.list, 1, "OneCraftRecipeRow", 96, R.SetupRow)
    local show, hide, refresh = view.Show, view.Hide, view.Refresh
    view.Show = function(self)
        show(self)
        R.arrow:SetHidden(false)
    end
    view.Hide = function(self)
        R.SetOpen(false)
        R.arrow:SetHidden(true)
        hide(self)
    end
    view.Refresh = function(self) refresh(self); R.Refresh() end
end
