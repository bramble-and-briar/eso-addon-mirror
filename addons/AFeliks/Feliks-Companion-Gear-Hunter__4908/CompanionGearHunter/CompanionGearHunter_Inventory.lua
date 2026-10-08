CompanionGearHunter = CompanionGearHunter or {}
local CompanionGearHunter = CompanionGearHunter -- local reference, faster than repeated _G lookups

-- Flags companion gear in every item list with a small companion-icon badge
-- over the item's own icon: green for a wishlist match, yellow for a quality upgrade
-- (wanted wins if an item is both). One badge mechanism for every list, the
-- technique LootLog's trade-list flagging uses (read from its
-- LootLogTrade.lua): a CT_TEXTURE child of the row's item-icon button,
-- drawn above the row. Rows are pooled and reused,
-- so the badge is created lazily the first time a row needs one and only
-- hidden afterward - never destroyed - and every refresh re-evaluates it
-- (including with an empty link, to hide a stale badge).
--
-- Where each list triggers a refresh:
-- * Backpack, bank, house bank, guild bank: every one of these row setups
--   ends by calling the real global ZO_UpdateStatusControlIcons(row, slotData)
--   (confirmed against esoui/esoui's inventory.lua), which is pre-hooked below
--   purely as a "this row was just (re)drawn" signal. Nothing is added to
--   the game's own status-icon column.
-- * Guild store results and trade slots have their own hooks, further down.
local MARKER_ICON = CompanionGearHunter.Data.MARKER_ICON
local BADGE_NAME = "CompanionGearHunterMatchBadge"

local function ApplyBadgeLook(badge, kind)
    local r, g, b = CompanionGearHunter.Data.GetMarkerColor(kind)
    badge:SetTexture(MARKER_ICON)
    badge:SetColor(r, g, b, 1)
end

local function FlagRowIcon(rowControl, itemLink)
    local kind = CompanionGearHunter.Data.GetMatchKind(itemLink)
    -- Parented to the row's icon Button (falling back to the row itself for
    -- controls with no such child, e.g. mail attachment slots), not to the
    -- row: on hover the game scales that Button up, and a badge that's the
    -- Button's own child stays glued to its corner through the animation
    -- (what LootLog's marker does), while one merely anchored to it from the
    -- row left a gap.
    local iconButton = rowControl:GetNamedChild("Button") or rowControl
    local badge = iconButton:GetNamedChild(BADGE_NAME)
    if badge == nil then
        if kind == nil then
            return
        end
        badge = WINDOW_MANAGER:CreateControl(iconButton:GetName() .. BADGE_NAME, iconButton, CT_TEXTURE)
        badge:SetDimensions(40, 40)
        -- Inherits the Button's scale (the default) so the badge grows and
        -- moves with the icon during the hover animation instead of staying
        -- put while the icon moves under it.
        badge:SetDrawTier(DT_HIGH)
        badge:SetAnchor(TOPLEFT, iconButton, TOPLEFT, -12, -6)
    end
    if kind == nil then
        badge:SetHidden(true)
    else
        ApplyBadgeLook(badge, kind)
        badge:SetHidden(false)
    end
end

local function OnUpdateStatusControlIcons(inventorySlot, slotData)
    -- Quest items and a couple of other list types reuse this same global
    -- but have no bagId/slotIndex pair to look an item link up from.
    if slotData.bagId == nil or slotData.slotIndex == nil then
        FlagRowIcon(inventorySlot, nil)
        return
    end
    FlagRowIcon(inventorySlot, GetItemLink(slotData.bagId, slotData.slotIndex))
end

-- Returning nothing (falsy) tells ZO_PreHook to still run the original
-- afterward - see esoui/esoui's zo_hook.lua.
ZO_PreHook("ZO_UpdateStatusControlIcons", OnUpdateStatusControlIcons)

-- Tooltip line naming which companion(s)/slot(s) the badge is for - added
-- to the item's own tooltip (not a separate hover on the badge itself).
--
-- This turned out to need two different kinds of hook, confirmed by
-- testing live against a real third-party addon (Inventory Insight):
--
-- 1. `ZO_Tooltip:LayoutItem` - the shared Lua function every "Specific
--    Layout Function" bottoms out in (LayoutBagItem -> LayoutItemWithStackCount
--    -> LayoutItem; itemtooltips.lua's own section comment confirms there's
--    a whole family: LayoutBagItem, LayoutTradingHouseItem, etc). Covers the
--    base game's own bag/bank/house-bank windows. `ZO_Tooltip` is a real
--    global class table (`zo_tooltip.lua`: `ZO_Tooltip = {}`), so hooking
--    it once covers every tooltip instance that goes through this path.
-- 2. `SetLink(itemLink)` / `SetBagItem(bagId, slotIndex, displayFlags)` -
--    real, separately-documented native methods (ESOUIDocumentation.txt;
--    no Lua definition exists for either, unlike LayoutItem) on the
--    tooltip control itself. Confirmed necessary because Inventory
--    Insight's own list showed the badge from the inventory hook above,
--    but never triggered the LayoutItem hook - it (and, going by the
--    genuine price lines from TTC/Master Merchant visible in that same
--    tooltip, likely those addons too) populates through this native path
--    instead, which doesn't call into Lua's LayoutItem at all. Hooked on
--    the 3 real global keyboard-mode tooltip instances
--    (`ItemTooltip`/`PopupTooltip`/`InformationTooltip`, confirmed in
--    tooltip.xml) since a native method has to be hooked per control
--    instance, not once on a shared class the way LayoutItem's Lua-side
--    inheritance allows.
--
-- Both paths call the same AppendMatchInfo. First version used the same
-- AcquireSection -> AddLine -> AddSection pattern the game's own
-- AddFlavorText/AddPrioritySellText use - but that threw a real Lua error
-- ("function expected instead of nil", confirmed from a real in-game
-- error log) when reached through the native SetBagItem path, while
-- several other addons hooked onto that exact same call (TamrielTradeCentre,
-- WritWorthy, CraftStore - all visible in that same error's stack trace,
-- running without issue right next to the crash) clearly don't hit this.
-- AcquireSection's internal section-pooling apparently isn't set up the
-- same way when reached via the native path as it is via the Lua
-- LayoutItem path AddFlavorText normally runs inside of. Switched to the
-- simpler, separately-documented native `AddLine(text, font, r, g, b, ...)`
-- method directly on the tooltip control - no section object involved,
-- and (going by TTC/WritWorthy/CraftStore surviving the same call) the
-- one third-party addons actually rely on for exactly this.
local SLOT_LABELS = {}
for _, slotDef in ipairs(CompanionGearHunter.Data.SLOTS) do
    SLOT_LABELS[slotDef.key] = slotDef.label
end

local function WithPrefix(text)
    local prefix = CompanionGearHunter.Data.GetTooltipPrefix()
    if prefix == "" then
        return text
    end
    return prefix .. " " .. text
end

local function AppendMatchInfo(tooltipSelf, itemLink)
    if not CompanionGearHunter.Data then
        return
    end

    local matches = CompanionGearHunter.Data.FindWishlistMatches(itemLink)
    if #matches > 0 then
        local lines = {}
        local seen = {}
        for _, match in ipairs(matches) do
            local companionName = zo_strformat("<<1>>", GetCompanionName(match.companionId))
            local slotLabel = SLOT_LABELS[match.slotKey] or match.slotKey
            local dedupeKey = match.companionId .. ":" .. slotLabel
            if not seen[dedupeKey] then
                seen[dedupeKey] = true
                table.insert(lines, WithPrefix(string.format("Wanted for %s (%s)", companionName, slotLabel)))
            end
        end
        tooltipSelf:AddLine(table.concat(lines, "\n"), "ZoFontGameShadow", CompanionGearHunter.Data.GetMarkerColor("wanted"))
    end

    -- Softer, separate signal: a quality upgrade over what a companion
    -- currently has equipped in a slot nobody's actively hunting for - a
    -- suggestion, not a confirmed wishlist match, so it gets a yellow badge
    -- instead of green. Deliberately excludes any slot that already showed
    -- up above, since FindUpgradeOpportunities itself skips "Find"-enabled
    -- slots.
    local upgrades = CompanionGearHunter.Data.FindUpgradeOpportunities(itemLink)
    if #upgrades > 0 then
        local lines = {}
        local seen = {}
        for _, upgrade in ipairs(upgrades) do
            local companionName = zo_strformat("<<1>>", GetCompanionName(upgrade.companionId))
            local slotLabel = SLOT_LABELS[upgrade.slotKey] or upgrade.slotKey
            local dedupeKey = upgrade.companionId .. ":" .. slotLabel
            if not seen[dedupeKey] then
                seen[dedupeKey] = true
                table.insert(lines, WithPrefix(string.format("Upgrade for %s (%s)", companionName, slotLabel)))
            end
        end
        tooltipSelf:AddLine(table.concat(lines, "\n"), "ZoFontGameShadow", CompanionGearHunter.Data.GetMarkerColor("upgrade"))
    end
end

ZO_PostHook(ZO_Tooltip, "LayoutItem", function(tooltipSelf, itemLink)
    AppendMatchInfo(tooltipSelf, itemLink)
end)

local function OnSetLink(tooltipSelf, link)
    AppendMatchInfo(tooltipSelf, link)
end

local function OnSetBagItem(tooltipSelf, bagId, slotIndex)
    AppendMatchInfo(tooltipSelf, GetItemLink(bagId, slotIndex))
end

-- Guild store search results and the trade window each populate their tooltip
-- through their own native method (inventoryslot.lua's
-- SLOT_TYPE_TRADING_HOUSE_ITEM_RESULT and SLOT_TYPE_TRADE_* handlers), so
-- the bag/link hooks above never see them. (Their badges are installed
-- separately, in InstallRowBadgeHooks below.)
local function OnSetTradingHouseItem(tooltipSelf, tradingHouseIndex)
    AppendMatchInfo(tooltipSelf, GetTradingHouseSearchResultItemLink(tradingHouseIndex))
end

local function OnSetTradeItem(tooltipSelf, who, tradeIndex)
    AppendMatchInfo(tooltipSelf, GetTradeItemLink(who, tradeIndex, LINK_STYLE_DEFAULT))
end

local function OnSetAttachedMailItem(tooltipSelf, mailId, attachSlot)
    AppendMatchInfo(tooltipSelf, GetAttachedItemLink(mailId, attachSlot, LINK_STYLE_DEFAULT))
end

for _, tooltipControl in ipairs({ ItemTooltip, PopupTooltip, InformationTooltip }) do
    if tooltipControl then
        ZO_PostHook(tooltipControl, "SetLink", OnSetLink)
        ZO_PostHook(tooltipControl, "SetBagItem", OnSetBagItem)
        ZO_PostHook(tooltipControl, "SetTradingHouseItem", OnSetTradingHouseItem)
        ZO_PostHook(tooltipControl, "SetTradeItem", OnSetTradeItem)
        ZO_PostHook(tooltipControl, "SetAttachedMailItem", OnSetAttachedMailItem)
    end
end

-- Redraws the item rows currently on screen, so a changed marker color or
-- the upgrades toggle shows immediately instead of the next time each row
-- happens to be refreshed. Each row's setup runs through the hooks above.
local BADGE_LIST_NAMES = {
    "ZO_PlayerInventoryList",
    "ZO_PlayerBankBackpack",
    "ZO_HouseBankBackpack",
    "ZO_GuildBankBackpack",
    "ZO_TradingHouseBrowseItemsRightPaneSearchResults",
}

function CompanionGearHunter.RefreshListBadges()
    for _, listName in ipairs(BADGE_LIST_NAMES) do
        local list = _G[listName]
        if list then
            pcall(ZO_ScrollList_RefreshVisible, list)
        end
    end
end

-- TRADING_HOUSE and TRADE are created by the base UI; the guild store's
-- results list only exists once the store has been opened, so its list hook
-- is installed on first open (same constraint LootLog works around).
local function InstallRowBadgeHooks()
    if TRADE then
        ZO_PostHook(TRADE, "InitializeSlot", function(tradeSelf, who, index)
            local slot = tradeSelf.Columns[who][index]
            if slot and slot.Control then
                FlagRowIcon(slot.Control, GetTradeItemLink(who, index, LINK_STYLE_DEFAULT))
            end
        end)
        ZO_PostHook(TRADE, "ResetSlot", function(tradeSelf, who, index)
            local slot = tradeSelf.Columns[who][index]
            if slot and slot.Control then
                FlagRowIcon(slot.Control, nil)
            end
        end)
    end

    -- Attachments on an opened mail. Outgoing mail isn't hooked - those are
    -- items being sent away, not found.
    if MAIL_INBOX then
        ZO_PostHook(MAIL_INBOX, "RefreshAttachmentSlots", function(inboxSelf)
            local mailData = inboxSelf:GetMailData(inboxSelf.mailId, inboxSelf.isMailFromGuild)
            if mailData == nil then
                return
            end
            for i = 1, mailData.numAttachments do
                FlagRowIcon(inboxSelf.attachmentSlots[i], GetAttachedItemLink(inboxSelf.mailId, i, LINK_STYLE_DEFAULT))
            end
        end)
    end

    if TRADING_HOUSE then
        local hooked = false
        ZO_PostHook(TRADING_HOUSE, "OpenTradingHouse", function()
            if hooked then
                return
            end
            local resultsList = ZO_TradingHouseBrowseItemsRightPaneSearchResults
            local dataType = resultsList and ZO_ScrollList_GetDataTypeTable(resultsList, 1)
            if dataType == nil then
                return
            end
            hooked = true
            ZO_PostHook(dataType, "setupCallback", function(rowControl, data)
                FlagRowIcon(rowControl, GetTradingHouseSearchResultItemLink(data.slotIndex))
            end)
        end)
    end
end

local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent("CompanionGearHunter_Inventory", EVENT_PLAYER_ACTIVATED)
    InstallRowBadgeHooks()
end

EVENT_MANAGER:RegisterForEvent("CompanionGearHunter_Inventory", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
