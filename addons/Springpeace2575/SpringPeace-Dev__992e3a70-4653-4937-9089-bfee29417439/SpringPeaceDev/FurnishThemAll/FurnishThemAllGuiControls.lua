-----------------------------------------------------------
-- Author: SpringPeace2575 | Version: 0.9.0
-- GUI Visuals helpers for FurnishThemAllGui add-on
-----------------------------------------------------------

FurnishThemAllGuiControls = FurnishThemAllGuiControls or {}
local FTAGuiControls = FurnishThemAllGuiControls

----------
-- Panes
----------

--[[local inactiveCenter = {0.04, 0.04, 0.05, 0.94}
local inactiveEdge = {0.16, 0.16, 0.18, 0.98}
local activeCenter = {0.06, 0.07, 0.08, 0.96}
local activeEdge = {0.30, 0.32, 0.36, 1.00} ]]
local inactiveCenter = {0.025, 0.025, 0.03, 0.96}
local inactiveEdge = {0.12, 0.12, 0.14, 0.98}
local activeCenter = {0.045, 0.05, 0.06, 0.97}
local activeEdge = {0.26, 0.28, 0.32, 1.00}

local function ApplyBackdrop(control, isActive)
    if not control then return end
    local center = isActive and activeCenter or inactiveCenter
    local edge = isActive and activeEdge or inactiveEdge
    if control.SetCenterColor then
        control:SetCenterColor(center[1], center[2], center[3], center[4])
    end
    if control.SetEdgeColor then
        control:SetEdgeColor(edge[1], edge[2], edge[3], edge[4])
    end
end

function FTAGuiControls.SetPaneVisuals(leftActive, centerActive)
    ApplyBackdrop(FTAMenuRootHeaderArea, false)
    ApplyBackdrop(FTAMenuRootLeftPaneBg, leftActive)
    ApplyBackdrop(FTAMenuRootCenterPaneBg, centerActive)
    ApplyBackdrop(FTAMenuRootRightPaneBg, false)
end



-------------
-- Controls
-------------

function FTAGuiControls.GetRoot()
    return FTAMenuRoot
end

function FTAGuiControls.GetLeftPaneList()
    return FTAMenuRootLeftPaneBgList
end

function FTAGuiControls.GetCenterPaneList()
    return FTAMenuRootCenterPaneBgList
end

function FTAGuiControls.GetDetails()
    return {
        FTAMenuRootRightPaneBgDetail1,
        FTAMenuRootRightPaneBgDetail2,
        FTAMenuRootRightPaneBgDetail3,
        FTAMenuRootRightPaneBgDetail4,
        FTAMenuRootRightPaneBgDetail5,
        FTAMenuRootRightPaneBgDetail6,
        FTAMenuRootRightPaneBgDetail7,
        FTAMenuRootRightPaneBgDetail8,
        FTAMenuRootRightPaneBgDetail9,
        FTAMenuRootRightPaneBgDetail10,
        FTAMenuRootRightPaneBgDetail11,
        FTAMenuRootRightPaneBgDetail12,
        FTAMenuRootRightPaneBgDetail13,
        FTAMenuRootRightPaneBgDetail14,
        FTAMenuRootRightPaneBgDetail15,
        FTAMenuRootRightPaneBgDetail16,
        FTAMenuRootRightPaneBgDetail17,
        FTAMenuRootRightPaneBgDetail18,
        FTAMenuRootRightPaneBgDetail19,
        FTAMenuRootRightPaneBgDetail20,
    }
end

local function getPercent(value, max)
    if max == 0 then
        return 0
    end

    return math.floor((value / max) * 100 + 0.5)
end

function FTAGuiControls.UpdateHeader(matching, total, collectedMatching, collectedTotal, page, totalPages, neededTradeBars)
    if FTAMenuRootHeaderAreaTitle then
        FTAMenuRootHeaderAreaTitle:SetText("Furnish Them All")
    end
    if FTAMenuRootHeaderAreaSubtitle then
        local neededTradeBarsInfo = ""
        if neededTradeBars and neededTradeBars > 0 then
            neededTradeBarsInfo = string.format("Needed Trade Bars by results: %d", neededTradeBars)
        end
        FTAMenuRootHeaderAreaSubtitle:SetText(string.format(
            "Page: %d / %d    Matching: %d / %d    Collected Matching: %d / %d (%d%%)    Collected Total: %d / %d (%d%%)            %s",
            page, totalPages,
            matching, total,
            collectedMatching, matching, getPercent(collectedMatching, matching),
            collectedTotal, total, getPercent(collectedTotal, total),
            neededTradeBarsInfo
        ))
    end
    if FTAMenuRootCenterPaneBgCount then
        FTAMenuRootCenterPaneBgCount:SetText(string.format("%d / %d", matching, total))
    end
end

local function GetEntryControlPart(control, fieldName, childName)
    if not control then return nil end
    local part = control[fieldName]
    if part then return part end
    if control.GetNamedChild then
        part = control:GetNamedChild(childName)
        if part then return part end
    end
    return nil
end

local function GetEntryText(data)
    if not data then return "" end
    if data.GetText then
        local ok, value = pcall(function() return data:GetText() end)
        if ok and value ~= nil then return tostring(value) end
    end
    if data.text ~= nil then return tostring(data.text) end
    return tostring(data)
end

local function ApplyLabelStyle(label, selected, isSecondary, size2, size3, size4)
    if not label then return end
    if label.SetFont then
        if size4 then
            label:SetFont(isSecondary and "ZoFontGamepad18" or "ZoFontGamepad20")
        elseif size3 then
            label:SetFont(isSecondary and "ZoFontGamepad18" or "ZoFontGamepad22")
        elseif size2 then
            label:SetFont(isSecondary and "ZoFontGamepad20" or "ZoFontGamepad25")
        else
            label:SetFont(isSecondary and "ZoFontGamepad22" or "ZoFontGamepad27")
        end
    end
    if label.SetColor then
        if selected then
            label:SetColor(1, 0.93, 0.76, 1)
        elseif isSecondary then
            label:SetColor(0.78, 0.82, 0.88, 0.95)
        else
            label:SetColor(0.94, 0.96, 0.98, 1)
        end
    end
    if label.SetWrapMode then
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
end

local weights = {
    ["i"]=0.55, ["l"]=0.55, ["I"]=0.6, ["t"]=0.65, ["r"]=0.65, ["f"]=0.65, ["j"]=0.65,
    [" "]=0.5, ["."]=0.4, [","]=0.4, [":"]=0.45, [";"]=0.45, ["'"]=0.35, ["-"]=0.65,
    ["("]=1.1, [")"]=1.1, ["a"]=1.1, ["n"]=1.15,
    ["m"]=1.25, ["w"]=1.25, ["M"]=1.45, ["W"]=1.45,
    ["A"]=1.35, ["B"]=1.3, ["C"]=1.3, ["D"]=1.3, ["G"]=1.3, ["N"]=1.3, ["O"]=1.3, ["P"]=1.25, ["Q"]=1.3, ["R"]=1.3, ["V"]=1.3, ["Y"]=1.3,
    ["0"]=1.2, ["1"]=0.85, ["2"]=1.2, ["3"]=1.2, ["4"]=1.2, ["5"]=1.2, ["6"]=1.2, ["7"]=1.2, ["8"]=1.2, ["9"]=1.2,
}

local function weightedLenFast(s)
    local len = 0
    for i = 1, #s do
        local c = s:sub(i, i)
        len = len + (weights[c] or 1)
    end
    return len
end

function FTAGuiControls.FilterEntrySetup(control, data, selected, selectedDuringRebuild, enabled, active)
    local label = GetEntryControlPart(control, "label", "Label")
    local bg = GetEntryControlPart(control, "bg", "Bg") or GetEntryControlPart(control, "selectionHighlight", "SelectionHighlight")

    if label and label.SetText then
        local text = GetEntryText(data)
        local textLen = weightedLenFast(text)
        label:SetText(text)
        ApplyLabelStyle(label, selected, false, textLen > 32, textLen > 36, textLen > 40)
    end

    if bg then
        if bg.SetCenterColor then
            if selected then
                bg:SetCenterColor(0.22, 0.28, 0.36, 0.95)
            else
                bg:SetCenterColor(0.11, 0.12, 0.14, 0.70)
            end
        end
        if bg.SetEdgeColor then
            if selected then
                bg:SetEdgeColor(0.58, 0.62, 0.70, 1.00)
            else
                bg:SetEdgeColor(0.22, 0.24, 0.28, 0.85)
            end
        end
        if bg.SetHidden then
            bg:SetHidden(false)
        end
    end

    if control and control.SetAlpha then
        control:SetAlpha(1)
    end
end

function FTAGuiControls.ResultEntrySetup(control, data, selected, selectedDuringRebuild, enabled, active)
    local bg = GetEntryControlPart(control, "bg", "Bg") or GetEntryControlPart(control, "selectionHighlight", "SelectionHighlight")
    if bg then
        if bg.SetCenterColor then
            if selected then
                bg:SetCenterColor(0.22, 0.28, 0.36, 0.95)
            else
                bg:SetCenterColor(0.11, 0.12, 0.14, 0.70)
            end
        end
        if bg.SetEdgeColor then
            if selected then
                bg:SetEdgeColor(0.58, 0.62, 0.70, 1.00)
            else
                bg:SetEdgeColor(0.22, 0.24, 0.28, 0.85)
            end
        end
        if bg.SetHidden then
            bg:SetHidden(false)
        end
    end

    local nameLabel = GetEntryControlPart(control, "label", "Label")
    local nameLabelTest = GetEntryControlPart(control, "name", "Name")
    local priceLabel = GetEntryControlPart(control, "priceLabel", "PriceLabel")
    local zoneLabel = GetEntryControlPart(control, "zoneLabel", "ZoneLabel")
    local traderGuildLabel = GetEntryControlPart(control, "traderGuildLabel", "TraderGuildLabel")
    local collectibleIcon = GetEntryControlPart(control, "collectibleIcon", "CollectibleIcon")
    local itemIcon = GetEntryControlPart(control, "itemIcon", "ItemIcon")

    if nameLabel and nameLabel.SetText then
        nameLabel:SetText(data.furnishingText or "")
    end

--[[     if nameLabel and nameLabel.SetText then
        nameLabel:SetText(data.itemData.formattedName or "")
        -- ApplyLabelStyle(nameLabel, selected, false)
        local displayQuality = data.itemData.displayQuality or data.itemData.quality
        nameLabel:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, displayQuality))
    end ]]

    if nameLabelTest and nameLabelTest.SetText and data and data.itemData then
         -- nameLabelTest:SetText(data.itemData.formattedName) -- stored itemData.formattedName already
        -- nameLabelTest:SetText(ZO_TradingHouse_GetItemDataFormattedName(data.itemData))
        -- ApplyLabelStyle(nameLabel, selected, false)
        -- local displayQuality = data.itemData.displayQuality or data.itemData.quality
        -- nameLabelTest:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, displayQuality))
    end

    if priceLabel and priceLabel.SetText then
        priceLabel:SetText(data and data.furnishingId or "")
        if priceLabel.ClearAnchors then
            -- priceLabel:ClearAnchors()
            -- priceLabel:SetAnchor(TOPLEFT, control, TOPLEFT, 498, 24)
        end
        if priceLabel.SetFont then
            -- priceLabel:SetFont("ZoFontGamepad27")
        end
        if priceLabel.SetColor then
            if selected then
                priceLabel:SetColor(1, 0.93, 0.76, 1)
            else
                priceLabel:SetColor(0.98, 0.88, 0.56, 1)
            end
        end
    end

    if zoneLabel and zoneLabel.SetText then
        zoneLabel:SetText(data and data.typeText or "")
        ApplyLabelStyle(zoneLabel, selected, true)
    end

    if traderGuildLabel and traderGuildLabel.SetText then
        traderGuildLabel:SetText(data and data.categorySubcategoryText or "")
        ApplyLabelStyle(traderGuildLabel, selected, true)
    end

    if collectibleIcon then
        if collectibleIcon.ClearAnchors then
            -- collectibleIcon:ClearAnchors()
            -- collectibleIcon:SetAnchor(TOPLEFT, control, TOPLEFT, 14, 24)
        end
        if data and data.showLearnIcon then
            if collectibleIcon.SetHidden then collectibleIcon:SetHidden(false) end
            if collectibleIcon.SetTexture then
                collectibleIcon:SetTexture("EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_can_learn.dds")
            end
            if collectibleIcon.SetColor then
                if ZO_SUCCEEDED_TEXT and ZO_SUCCEEDED_TEXT.UnpackRGBA then
                    collectibleIcon:SetColor(ZO_SUCCEEDED_TEXT:UnpackRGBA())
                else
                    collectibleIcon:SetColor(0.2, 0.85, 0.2, 1)
                end
            end
            if collectibleIcon.SetAlpha then collectibleIcon:SetAlpha(1) end
        else
            if collectibleIcon.SetTexture then collectibleIcon:SetTexture(nil) end
            if collectibleIcon.SetHidden then collectibleIcon:SetHidden(true) end
            if collectibleIcon.SetAlpha then collectibleIcon:SetAlpha(0) end
        end
    end

    if itemIcon then
        if itemIcon.ClearAnchors then
            -- itemIcon:ClearAnchors()
            -- itemIcon:SetAnchor(TOPLEFT, control, TOPLEFT, 60, 24)
        end
        if data and data.itemId and data.showItemIcon then
            local itemLink = string.format("|H0:item:%d:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", data.itemId)
            local icon = GetItemLinkIcon(itemLink)
            if icon and icon ~= "" then
                if itemIcon.SetHidden then itemIcon:SetHidden(false) end
                if itemIcon.SetTexture then itemIcon:SetTexture(icon) end
                if itemIcon.SetAlpha then itemIcon:SetAlpha(1) end
            else
                if itemIcon.SetTexture then itemIcon:SetTexture(nil) end
                if itemIcon.SetHidden then itemIcon:SetHidden(true) end
                if itemIcon.SetAlpha then itemIcon:SetAlpha(0) end
            end
        else
            if itemIcon.SetTexture then itemIcon:SetTexture(nil) end
            if itemIcon.SetHidden then itemIcon:SetHidden(true) end
            if itemIcon.SetAlpha then itemIcon:SetAlpha(0) end
        end
    end

    if control and control.SetAlpha then
        control:SetAlpha(1)
    end
end

local function SetMultilineText(label, text, width)
    if width then
        label:SetWidth(width)
    end
    label:SetHeight(1000)

    label:SetText(text or "-")

    local height = label:GetTextHeight()
    label:SetHeight(height + 2)
end

function FTAGuiControls.GetItemTagLines(itemLink)
    local lines = {}

    local numItemTags = GetItemLinkNumItemTags(itemLink)
    if numItemTags > 0 then
        local itemTagStrings = {}
        for i = 1, numItemTags do
            local itemTagDescription, itemTagCategory = GetItemLinkItemTagInfo(itemLink, i)
            if itemTagDescription ~= "" then
                if not itemTagStrings[itemTagCategory] then
                    itemTagStrings[itemTagCategory] = {}
                end
                table.insert(itemTagStrings[itemTagCategory], zo_strformat(SI_TOOLTIP_ITEM_TAG_FORMATER, itemTagDescription)) 
            end
        end
        for i = TAG_CATEGORY_MIN_VALUE, TAG_CATEGORY_MAX_VALUE do
            if itemTagStrings[i] then
                local categoryName = GetString("SI_ITEMTAGCATEGORY", i)
                table.sort(itemTagStrings[i])
                local categoryTagStrings = table.concat(itemTagStrings[i], GetString(SI_LIST_COMMA_SEPARATOR))
                if categoryName ~= "" then
                    table.insert(lines, string.format("%s: %s", categoryName, categoryTagStrings))
                else
                    table.insert(lines, string.format("%s", categoryTagStrings))
                end
            end
        end
    end

    return lines
end

function FTAGuiControls.RefreshDetailPanel(row, showExtraItemData)
    local details = FTAGuiControls.GetDetails()

    local lines = {}
    if row then
        local itemLink = string.format("|H0:item:%d:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", row.itemId)
        local flavorText = GetItemLinkFlavorText(itemLink)
        lines = {
            SPFLibUtils.SafeText(row.furnishingName),
            "",
            -- string.format("|t%d:%d:%s|t", 96, 96, iconFile or ""),
            -- "",

            SPFLibUtils.SafeText(flavorText),
            "",
        }

        for _, line in ipairs(FTAGuiControls.GetItemTagLines(itemLink)) do
            table.insert(lines, line)
        end

        table.insert(lines, string.format("Furnishing ID: %s", SPFLibUtils.SafeText(row.furnishingId)))
        table.insert(lines, string.format("Item ID: %s", SPFLibUtils.SafeText(row.itemId)))
        table.insert(lines, "")
        table.insert(lines, string.format("Source: %s", row.sources))
        table.insert(lines, string.format("Group: %s", row.groups))

        if row.tags and #row.tags > 0 then
            table.insert(lines, string.format("Tag: %s", row.tags))
        end

        if row.tradeBars and row.tradeBars > 0 then table.insert(lines, string.format("Trade Bars: %s", SPFLibUtils.FormatAmount(row.tradeBars))) end
        if row.quality then table.insert(lines, string.format("Quality: %s", SPFLibUtils.SafeText(row.quality))) end
        if row.theme then table.insert(lines, string.format("Theme: %s", SPFLibUtils.SafeText(row.theme))) end
        if row.info then
            table.insert(lines, "")
            table.insert(lines, SPFLibUtils.SafeText(row.info))
        end

        if showExtraItemData then
            -- TODO: don't know if there are any next additional information by type/category obtainable somehow
            -- local learnText = row.isUncollected and "Yes" or "No"
            lines = {
                SPFLibUtils.SafeText(row.furnishingName),
                "",
                -- string.format("Missing: %s", learnText),
                -- string.format("Type: %s", SPFLibUtils.SafeText(row.typeName)),
                -- string.format("Category: %s", SPFLibUtils.SafeText(row.categoryName)),
                -- string.format("SubCategory: %s", SPFLibUtils.SafeText(row.subcategoryName)),
                -- string.format("Furnishing ID: %s", SPFLibUtils.SafeText(row.furnishingId)),
                -- "",
            }
            for _, inventory in ipairs(row.inventories) do
                table.insert(lines, string.format("%s: %s", SPFLibUtils.SafeText(inventory.name), SPFLibUtils.SafeText(inventory.count)))
            end
            -- table.insert(lines, string.format("V2: %s", SPFLibUtils.SafeText(description)))
            -- table.insert(lines, string.format("V3: %s", SPFLibUtils.SafeText(iconFile)))
            -- table.insert(lines, string.format("V4: %s", SPFLibUtils.SafeText(lockedIconFile)))
            -- table.insert(lines, string.format("V6: %s", SPFLibUtils.SafeText(purchasable)))
            -- table.insert(lines, string.format("V7: %s", SPFLibUtils.SafeText(isActive)))
            -- table.insert(lines, string.format("V8: %s", SPFLibUtils.SafeText(categoryTypeId)))
            -- table.insert(lines, string.format("V9: %s", SPFLibUtils.SafeText(howToObtain)))
        end
    else
        lines = {
            "No result selected",
            "",
            "Use Left / Right Shoulder to switch between Filters and Results.",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
        }
    end

    for i = 1, #details do
        if details[i] then
            -- details[i]:SetText(lines[i] or "")
            SetMultilineText(details[i], lines[i] or "")
        end
    end
end
