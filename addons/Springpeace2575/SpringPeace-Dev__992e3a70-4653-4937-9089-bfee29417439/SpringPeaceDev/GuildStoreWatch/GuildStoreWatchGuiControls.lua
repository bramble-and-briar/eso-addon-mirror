-----------------------------------------------------------
-- Author: SpringPeace2575 | Version: 0.9.0
-- GUI Visuals helpers for GuildStoreWatch add-on
-----------------------------------------------------------

GuildStoreWatchGuiControls = GuildStoreWatchGuiControls or {}
local GSWGuiControls = GuildStoreWatchGuiControls

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

function GSWGuiControls.SetPaneVisuals(leftActive, centerActive)
    ApplyBackdrop(GSWMenuRootHeaderArea, false)
    ApplyBackdrop(GSWMenuRootLeftPaneBg, leftActive)
    ApplyBackdrop(GSWMenuRootCenterPaneBg, centerActive)
    ApplyBackdrop(GSWMenuRootRightPaneBg, false)
end



-------------
-- Controls
-------------

function GSWGuiControls.GetRoot()
    return GSWMenuRoot
end

function GSWGuiControls.GetLeftPaneList()
    return GSWMenuRootLeftPaneBgList
end

function GSWGuiControls.GetCenterPaneList()
    return GSWMenuRootCenterPaneBgList
end

function GSWGuiControls.GetDetails()
    return {
        GSWMenuRootRightPaneBgDetail1,
        GSWMenuRootRightPaneBgDetail2,
        GSWMenuRootRightPaneBgDetail3,
        GSWMenuRootRightPaneBgDetail4,
        GSWMenuRootRightPaneBgDetail5,
        GSWMenuRootRightPaneBgDetail6,
        GSWMenuRootRightPaneBgDetail7,
        GSWMenuRootRightPaneBgDetail8,
        GSWMenuRootRightPaneBgDetail9,
        GSWMenuRootRightPaneBgDetail10,
        GSWMenuRootRightPaneBgDetail11,
        GSWMenuRootRightPaneBgDetail12,
        GSWMenuRootRightPaneBgDetail13,
        GSWMenuRootRightPaneBgDetail14,
        GSWMenuRootRightPaneBgDetail15,
        GSWMenuRootRightPaneBgDetail16,
        GSWMenuRootRightPaneBgDetail17,
        GSWMenuRootRightPaneBgDetail18,
        GSWMenuRootRightPaneBgDetail19,
        GSWMenuRootRightPaneBgDetail20,
    }
end

function GSWGuiControls.UpdateHeader(viewMode, matching, stored, matchingGold, storedGold, page, totalPages)
    if GSWMenuRootHeaderAreaTitle then
        GSWMenuRootHeaderAreaTitle:SetText("Guild Store Watch")
    end
    if GSWMenuRootHeaderAreaSubtitle then
        GSWMenuRootHeaderAreaSubtitle:SetText(string.format("Stored: %d (%s)   Matching: %d (%s)   Page: %d/%d   View: %s", stored, SPFLibUtils.FormatGoldAmount(storedGold), matching, SPFLibUtils.FormatGoldAmount(matchingGold), page, totalPages, viewMode))
    end
    if GSWMenuRootCenterPaneBgCount then
        GSWMenuRootCenterPaneBgCount:SetText(string.format("%d / %d", matching, stored))
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

local function ApplyLabelStyle(label, selected, isSecondary)
    if not label then return end
    if label.SetFont then
        label:SetFont(isSecondary and "ZoFontGamepad22" or "ZoFontGamepad27")
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

function GSWGuiControls.FilterEntrySetup(control, data, selected, selectedDuringRebuild, enabled, active)
    local label = GetEntryControlPart(control, "label", "Label")
    local bg = GetEntryControlPart(control, "bg", "Bg") or GetEntryControlPart(control, "selectionHighlight", "SelectionHighlight")

    if label and label.SetText then
        label:SetText(GetEntryText(data))
        ApplyLabelStyle(label, selected, false)
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

function GSWGuiControls.ResultEntrySetup(control, data, selected, selectedDuringRebuild, enabled, active)
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
        nameLabel:SetText(data.itemData.itemLink or "")
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
        priceLabel:SetText(data and data.priceText or "")
        if priceLabel.ClearAnchors then
            priceLabel:ClearAnchors()
            priceLabel:SetAnchor(TOPLEFT, control, TOPLEFT, 498, 24)
        end
        if priceLabel.SetFont then
            priceLabel:SetFont("ZoFontGamepad27")
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
        zoneLabel:SetText(data and data.zoneText or "")
        ApplyLabelStyle(zoneLabel, selected, true)
    end

    if traderGuildLabel and traderGuildLabel.SetText then
        traderGuildLabel:SetText(data and data.traderGuildText or "")
        ApplyLabelStyle(traderGuildLabel, selected, true)
    end

    if collectibleIcon then
        if collectibleIcon.ClearAnchors then
            collectibleIcon:ClearAnchors()
            collectibleIcon:SetAnchor(TOPLEFT, control, TOPLEFT, 14, 24)
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
            if collectibleIcon.SetAlpha then collectibleIcon:SetAlpha(0) end
        end
    end

    if itemIcon then
        if itemIcon.ClearAnchors then
            itemIcon:ClearAnchors()
            itemIcon:SetAnchor(TOPLEFT, control, TOPLEFT, 60, 24)
        end
        if data and data.itemData and data.itemData.itemLink then
            if itemIcon.SetTexture then
                itemIcon:SetTexture(GetItemLinkIcon(data.itemData.itemLink))
            end
        end
    end

    if control and control.SetAlpha then
        control:SetAlpha(1)
    end
end

local function parseSearchTextMap(searchText)
    local map = {}

    if not searchText or searchText == "" then
        return map
    end

    for part in string.gmatch(searchText, "([^|]+)") do
        local key, value = string.match(part, "^%s*([^:]+)%s*:%s*(.-)%s*$")
        if key and value then
            map[key] = value
        end
    end

    return map
end

function GSWGuiControls.RefreshDetailPanel(row, showExtraItemData)
    local details = GSWGuiControls.GetDetails()

    local lines = {}
    if row then
        local itemData = row.itemData or {}
        local learnText = row.isUncollected and "Yes" or "No"
        local motifInfo = SPFLibMotif.GetCachedMotifChapterInfo(itemData.itemLink)
        if motifInfo then
            learnText = learnText..string.format("    Have: %d / %d", motifInfo.unlocked or 0, motifInfo.total)
        end
        local page = row.page + 1 -- page is index from zero
        local searchMap = parseSearchTextMap(row.searchText)
        lines = {
            SPFLibUtils.SafeText(itemData.itemLink),
            string.format("Missing: %s", learnText),
            "",
            string.format("Unit price: %s    Total: %s", SPFLibUtils.FormatGoldAmount(itemData.purchasePricePerUnit or itemData.purchasePrice or 0), SPFLibUtils.FormatGoldAmount(itemData.purchasePrice or 0)),
            string.format("Stack: %s", SPFLibUtils.SafeText(itemData.stackCount or 1)),
            "",
            string.format("Zone: %s", SPFLibUtils.SafeText(row.traderZone)),
            string.format("Trader: %s", SPFLibUtils.SafeText(row.traderName)),
            string.format("Guild: %s", SPFLibUtils.SafeText(row.guildName)),
            string.format("Seller: %s", SPFLibUtils.SafeText(itemData.sellerName)),
            string.format("Last seen: %s", SPFLibUtils.FormatRelativeAgo(row.savedAt)),
            "",
        }
        table.insert(lines, string.format("Search:"))
        for key, value in pairs(searchMap) do
            table.insert(lines, string.format("    %s: %s", SPFLibUtils.SafeText(key), SPFLibUtils.SafeText(value)))
        end
        table.insert(lines, string.format("    Page: %s", SPFLibUtils.SafeText(page)))

        if showExtraItemData then
            --[[ local extraLines = SPFLibItemInfo.BuildExtraItemDataLines(row)
            if #extraLines > 0 then
                lines = {
                    SPFLibUtils.SafeText(itemData.itemLink),
                }
                table.insert(lines, "")
                table.insert(lines, "Additional itemData - #"..tostring(#extraLines))
                for _, extraLine in ipairs(extraLines) do
                    table.insert(lines, extraLine)
                end
            end ]]
            lines = {
                SPFLibUtils.SafeText(itemData.itemLink),
                "",
                -- string.format("Saved: %s", SPFLibUtils.FormatAbsoluteTimestamp(row.savedAt)),
                -- string.format("Search: %s", SPFLibUtils.SafeText(row.searchText)),
                -- string.format("Page: %s", SPFLibUtils.SafeText(page)),
                -- TODO: maybe some more info when available
            }
            local extraLines = SPFLibItemInfo.BuildExtendedDebugLines(itemData)
            for _, extraLine in ipairs(extraLines) do
                table.insert(lines, extraLine)
            end
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
            details[i]:SetText(lines[i] or "")
        end
    end
end
