local HCS = HazeCharswap

local win
local rowPool
local profileDropdown

local SCROLL_TEMPLATE_NAME = "HazeCharswap_RowTemplate"

-- daten für die liste

local function BuildDisplayList()
    local invItems, bankItems = HCS.GetMarkedItemsByLocation()

    local foundIds = {}
    local rows = {}

    for _, it in ipairs(invItems) do
        foundIds[it.idStr] = true
        table.insert(rows, {
            idStr       = it.idStr,
            name        = it.name,
            icon        = it.icon,
            itemLink    = it.itemLink,
            stackCount  = it.stackCount,
            location    = GetString(HAZECS_UI_INV),
            locationKey = 1,
            bagId       = it.bagId,
            slotIndex   = it.slotIndex,
        })
    end

    for _, it in ipairs(bankItems) do
        foundIds[it.idStr] = true
        table.insert(rows, {
            idStr       = it.idStr,
            name        = it.name,
            icon        = it.icon,
            itemLink    = it.itemLink,
            stackCount  = it.stackCount,
            location    = GetString(HAZECS_UI_BANK),
            locationKey = 2,
            bagId       = it.bagId,
            slotIndex   = it.slotIndex,
        })
    end

    local profile = HCS.sv.profiles and HCS.sv.profiles[HCS.sv.activeProfile]
    if profile and profile.items then
        for idStr, data in pairs(profile.items) do
            if not foundIds[idStr] then
                table.insert(rows, {
                    idStr       = idStr,
                    name        = data.name or "?",
                    icon        = data.icon,
                    itemLink    = data.itemLink,
                    stackCount  = 0,
                    location    = GetString(HAZECS_UI_ELSEWHERE),
                    locationKey = 3,
                })
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.locationKey ~= b.locationKey then
            return a.locationKey < b.locationKey
        end
        return (a.name or "") < (b.name or "")
    end)

    return rows
end

-- zeilen

local function SetupRow(rowControl, data)
    local icon     = rowControl:GetNamedChild("Icon")
    local name     = rowControl:GetNamedChild("Name")
    local location = rowControl:GetNamedChild("Location")
    local stack    = rowControl:GetNamedChild("Stack")

    if HCS.sv.showIcons and data.icon then
        icon:SetTexture(data.icon)
        icon:SetHidden(false)
        name:ClearAnchors()
        name:SetAnchor(LEFT, rowControl, LEFT, 44, 0)
    else
        icon:SetHidden(true)
        name:ClearAnchors()
        name:SetAnchor(LEFT, rowControl, LEFT, 10, 0)
    end

    local displayName = (data.itemLink and data.itemLink ~= "") and data.itemLink or (data.name or "?")
    name:SetText(displayName)

    location:SetText(data.location or "")
    if data.locationKey == 1 then
        local c = HCS.sv.bagColor or { 0.6, 1.0, 0.6 }
        location:SetColor(c[1], c[2], c[3], 1.0)
    elseif data.locationKey == 2 then
        local c = HCS.sv.bankColor or { 0.6, 0.8, 1.0 }
        location:SetColor(c[1], c[2], c[3], 1.0)
    else
        location:SetColor(0.7, 0.7, 0.7, 1.0)
    end

    if data.stackCount and data.stackCount > 0 then
        stack:SetText("x" .. data.stackCount)
    else
        stack:SetText("")
    end

    rowControl.data = data
end

local function ClearRows()
    if rowPool then
        rowPool:ReleaseAllObjects()
    end
end

local function RenderList()
    if not win then return end

    ClearRows()

    local rows = BuildDisplayList()

    local emptyHint = win:GetNamedChild("EmptyHint")
    emptyHint:SetHidden(#rows > 0)

    local countLabel = win:GetNamedChild("Count")
    if countLabel then
        countLabel:SetText(zo_strformat(GetString(HAZECS_UI_COUNT), #rows))
    end

    local container = win:GetNamedChild("ScrollContainer")
    local scroll    = container:GetNamedChild("ScrollChild") or container

    local y = 4
    for _, data in ipairs(rows) do
        local row = rowPool:AcquireObject()
        row:ClearAnchors()
        row:SetParent(scroll)
        row:SetAnchor(TOPLEFT,  scroll, TOPLEFT,  0,   y)
        row:SetAnchor(TOPRIGHT, scroll, TOPRIGHT, -16, y)
        row:SetHidden(false)
        SetupRow(row, data)
        y = y + 38
    end

    if scroll and scroll.SetHeight then
        scroll:SetHeight(math.max(y + 4, 1))
    end
end

-- profil-dropdown

function HCS.UI_RefreshProfileDropdown()
    if not profileDropdown then return end

    profileDropdown:ClearItems()

    for _, n in ipairs(HCS.GetProfileNames()) do
        local entry = profileDropdown:CreateItemEntry(n, function()
            HCS.SwitchProfile(n)
        end)
        profileDropdown:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
    end

    profileDropdown:UpdateItems()
    profileDropdown:SetSelectedItemText(HCS.GetActiveProfileName())
end

-- fenster

function HCS.UI_Refresh()
    if not win or win:IsHidden() then return end
    RenderList()
    HCS.UI_UpdateBankButtons()
end

function HCS.UI_UpdateBankButtons()
    if not win then return end

    local depositBtn  = win:GetNamedChild("Deposit")
    local withdrawBtn = win:GetNamedChild("Withdraw")
    local statusLbl   = win:GetNamedChild("BankStatus")

    if HCS.atBank then
        depositBtn:SetEnabled(true)
        withdrawBtn:SetEnabled(true)
        statusLbl:SetText("")
        statusLbl:SetHidden(true)
    else
        depositBtn:SetEnabled(false)
        withdrawBtn:SetEnabled(false)
        statusLbl:SetText(GetString(HAZECS_UI_NEEDS_BANK))
        statusLbl:SetHidden(false)
    end
end

function HCS.UI_Show()
    if not win then return end
    win:SetHidden(false)
    HCS.sv.uiHidden = false
    HCS.UI_RefreshProfileDropdown()
    HCS.UI_Refresh()
end

function HCS.UI_Hide()
    if not win then return end
    win:SetHidden(true)
    HCS.sv.uiHidden = true
end

function HCS.UI_Toggle()
    if not win then return end
    if win:IsHidden() then
        HCS.UI_Show()
    else
        HCS.UI_Hide()
    end
end

function HCS.UI_OnMoveStop(self)
    HCS.sv.uiLeft = self:GetLeft()
    HCS.sv.uiTop  = self:GetTop()
end

function HCS.UI_OnClearClicked()
    ZO_Dialogs_ShowDialog("HAZECS_CONFIRM_CLEAR")
end

function HCS.UI_OnRowRemoveClicked(rowControl)
    if rowControl and rowControl.data then
        HCS.UnmarkByUniqueId(rowControl.data.idStr)
    end
end

function HCS.UI_RowMouseEnter(rowControl)
    if not rowControl or not rowControl.data then return end
    local hl = rowControl:GetNamedChild("Highlight")
    if hl then hl:SetHidden(false) end
    if rowControl.data.bagId and rowControl.data.slotIndex then
        InitializeTooltip(ItemTooltip, rowControl, RIGHT, -10, 0, LEFT)
        ItemTooltip:SetBagItem(rowControl.data.bagId, rowControl.data.slotIndex)
    elseif rowControl.data.itemLink and rowControl.data.itemLink ~= "" then
        InitializeTooltip(ItemTooltip, rowControl, RIGHT, -10, 0, LEFT)
        ItemTooltip:SetLink(rowControl.data.itemLink)
    end
end

function HCS.UI_RowMouseExit(rowControl)
    local hl = rowControl:GetNamedChild("Highlight")
    if hl then hl:SetHidden(true) end
    ClearTooltip(ItemTooltip)
end

-- profil-buttons

function HCS.UI_OnProfileNewClicked()
    ZO_Dialogs_ShowDialog("HAZECS_NEW_PROFILE")
end

function HCS.UI_OnProfileRenameClicked()
    ZO_Dialogs_ShowDialog("HAZECS_RENAME_PROFILE", { oldName = HCS.GetActiveProfileName() })
end

function HCS.UI_OnProfileDeleteClicked()
    local active = HCS.GetActiveProfileName()
    ZO_Dialogs_ShowDialog("HAZECS_DELETE_PROFILE", { name = active },
        { mainTextParams = { active } })
end

-- dialoge

local function CreateDialogs()
    ZO_Dialogs_RegisterCustomDialog("HAZECS_CONFIRM_CLEAR", {
        title    = { text = GetString(HAZECS_UI_CLEAR) },
        mainText = { text = GetString(HAZECS_CONFIRM_CLEAR_TEXT) },
        buttons  = {
            [1] = {
                text     = SI_DIALOG_CONFIRM,
                callback = function() HCS.ClearList() end,
            },
            [2] = { text = SI_DIALOG_CANCEL },
        },
    })

    ZO_Dialogs_RegisterCustomDialog("HAZECS_NEW_PROFILE", {
        title    = { text = GetString(HAZECS_DIALOG_NEW_TITLE) },
        mainText = { text = GetString(HAZECS_DIALOG_NEW_TEXT) },
        editBox  = { defaultText = "" },
        buttons  = {
            [1] = {
                text     = SI_DIALOG_ACCEPT,
                callback = function(dialog)
                    HCS.CreateProfile(ZO_Dialogs_GetEditBoxText(dialog) or "")
                end,
            },
            [2] = { text = SI_DIALOG_CANCEL },
        },
    })

    ZO_Dialogs_RegisterCustomDialog("HAZECS_RENAME_PROFILE", {
        title    = { text = GetString(HAZECS_DIALOG_RENAME_TITLE) },
        mainText = { text = GetString(HAZECS_DIALOG_RENAME_TEXT) },
        editBox  = { defaultText = "" },
        setup = function(dialog, data)
            ZO_Dialogs_DefaultSetup(dialog, data)
            if dialog.editBox and data and data.oldName then
                dialog.editBox:SetText(data.oldName)
            end
        end,
        buttons  = {
            [1] = {
                text     = SI_DIALOG_ACCEPT,
                callback = function(dialog)
                    local newName = ZO_Dialogs_GetEditBoxText(dialog)
                    local data = dialog.data or {}
                    HCS.RenameProfile(data.oldName or HCS.GetActiveProfileName(), newName or "")
                end,
            },
            [2] = { text = SI_DIALOG_CANCEL },
        },
    })

    ZO_Dialogs_RegisterCustomDialog("HAZECS_DELETE_PROFILE", {
        title    = { text = GetString(HAZECS_UI_PROFILE_DELETE) },
        mainText = { text = GetString(HAZECS_CONFIRM_DELETE_TEXT) },
        buttons  = {
            [1] = {
                text     = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    local data = dialog.data or {}
                    if data.name then HCS.DeleteProfile(data.name) end
                end,
            },
            [2] = { text = SI_DIALOG_CANCEL },
        },
    })
end

-- init

-- gewählte farben aufs fenster anwenden
function HCS.UI_ApplyColors()
    if not win then return end
    local title = win:GetNamedChild("Title")
    if title then
        local c = HCS.sv.accentColor or { 1.0, 0.843, 0.0 }
        title:SetColor(c[1], c[2], c[3], 1.0)
    end
    if not win:IsHidden() then HCS.UI_Refresh() end
end

function HCS.UI_Initialize()
    win = HazeCharswapWindow
    if not win then return end

    win:GetNamedChild("Title"):SetText(GetString(HAZECS_UI_TITLE))
    win:GetNamedChild("Deposit"):SetText(GetString(HAZECS_UI_DEPOSIT))
    win:GetNamedChild("Withdraw"):SetText(GetString(HAZECS_UI_WITHDRAW))
    win:GetNamedChild("Refresh"):SetText(GetString(HAZECS_UI_REFRESH))
    win:GetNamedChild("Clear"):SetText(GetString(HAZECS_UI_CLEAR))
    win:GetNamedChild("EmptyHint"):SetText(GetString(HAZECS_UI_NO_ITEMS))
    win:GetNamedChild("ProfileLabel"):SetText(GetString(HAZECS_UI_PROFILE_LABEL))
    win:GetNamedChild("ProfileNew"):SetText(GetString(HAZECS_UI_PROFILE_NEW))
    win:GetNamedChild("ProfileRename"):SetText(GetString(HAZECS_UI_PROFILE_RENAME))
    win:GetNamedChild("ProfileDelete"):SetText(GetString(HAZECS_UI_PROFILE_DELETE))

    local countLabel = win:GetNamedChild("Count")
    if countLabel then
        local total = 0
        local profile = HCS.sv.profiles and HCS.sv.profiles[HCS.sv.activeProfile]
        if profile and profile.items then
            for _ in pairs(profile.items) do total = total + 1 end
        end
        countLabel:SetText(zo_strformat(GetString(HAZECS_UI_COUNT), total))
    end

    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, HCS.sv.uiLeft or 400, HCS.sv.uiTop or 200)

    profileDropdown = ZO_ComboBox_ObjectFromContainer(win:GetNamedChild("ProfileDropdown"))
    profileDropdown:SetSortsItems(false)
    HCS.UI_RefreshProfileDropdown()

    local container    = win:GetNamedChild("ScrollContainer")
    local scrollParent = container:GetNamedChild("ScrollChild") or container

    rowPool = ZO_ObjectPool:New(
        function(pool)
            return CreateControlFromVirtual(
                "HazeCharswapRow",
                scrollParent,
                SCROLL_TEMPLATE_NAME,
                pool:GetNextControlId()
            )
        end,
        function(control)
            control:SetHidden(true)
            control:ClearAnchors()
            control.data = nil
        end
    )

    CreateDialogs()

    HCS.UI_ApplyColors()

    if HCS.sv.uiHidden then
        win:SetHidden(true)
    else
        win:SetHidden(false)
        HCS.UI_Refresh()
    end

    HCS.UI_UpdateBankButtons()
end
