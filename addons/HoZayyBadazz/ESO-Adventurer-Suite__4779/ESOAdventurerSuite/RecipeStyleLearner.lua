-- ESO Adventurer Suite
-- Floating Recipe & Style Learner (Turbo Mode)

local EPC = ESOProgressionCoach
EPC.RecipeStyleLearner = EPC.RecipeStyleLearner or {}
local R = EPC.RecipeStyleLearner
local wm = WINDOW_MANAGER

local PREFIX = "ESOAdventurerSuite_RecipeStyleLearner"
local BOOK_ICON = "EsoUI/Art/MainMenu/menubar_journal_up.dds"

-- v0.29.750: detect bound outfit-style pages by collectible category
-- v0.29.749: add Bound Style Page / collectible style-page support
-- v0.29.153: the learner stays at its normal 64x64 size in HUD Layout
-- Mode. A dedicated invisible drag handle covers the book only while layout
-- mode is active, so the very first left-click-and-hold starts moving it.
local NORMAL_W, NORMAL_H = 64, 64

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e,f = pcall(fn, ...)
    if not ok then return fallback end
    return a,b,c,d,e,f
end

local function num(v, fallback)
    v = tonumber(v)
    if v == nil then return fallback or 0 end
    return v
end

local function lower(v)
    return string.lower(tostring(v or ""))
end

local function notify(text, good)
    if EPC and type(EPC.Print) == "function" then EPC:Print(text) end
    if type(ZO_Alert) == "function" then
        pcall(ZO_Alert, good == false and UI_ALERT_CATEGORY_ERROR or UI_ALERT_CATEGORY_ALERT, nil, text)
    end
end

function R:EnsureSaved()
    EPC.saved = EPC.saved or {}
    if EPC.saved.recipeStyleLearnerEnabled == nil then EPC.saved.recipeStyleLearnerEnabled = true end
    if EPC.saved.recipeStyleLearnerIncludeBank == nil then EPC.saved.recipeStyleLearnerIncludeBank = true end
    if EPC.saved.recipeStyleLearnerSuppressPopups == nil then EPC.saved.recipeStyleLearnerSuppressPopups = true end
    if EPC.saved.recipeStyleLearnerLeft == nil then EPC.saved.recipeStyleLearnerLeft = -1 end
    if EPC.saved.recipeStyleLearnerTop == nil then EPC.saved.recipeStyleLearnerTop = -1 end
end

function R:IsSceneShowing(name)
    if not SCENE_MANAGER or type(SCENE_MANAGER.GetScene) ~= "function" then return false end
    local scene = SCENE_MANAGER:GetScene(name)
    if not scene then return false end
    if type(scene.IsShowing) == "function" then
        local ok, value = pcall(scene.IsShowing, scene)
        return ok and value == true
    end
    return false
end

function R:IsBankOpen()
    if type(GetInteractionType) == "function" and rawget(_G, "INTERACTION_BANK") ~= nil then
        local interaction = safe(GetInteractionType, nil)
        if interaction == INTERACTION_BANK then return true end
    end
    return self:IsSceneShowing("bank") or self:IsSceneShowing()
end

function R:IsInventoryOrBankShowing()
    return self:IsSceneShowing("inventory")
        or self:IsSceneShowing()
        or self:IsSceneShowing("bank")
        or self:IsSceneShowing()
        or self:IsBankOpen()
end

function R:RestorePosition()
    if not self.button or not GuiRoot then return end
    self:EnsureSaved()
    local x = num(EPC.saved.recipeStyleLearnerLeft, -1)
    local y = num(EPC.saved.recipeStyleLearnerTop, -1)
    self.button:ClearAnchors()
    self.button:SetDimensions(NORMAL_W, NORMAL_H)
    if x >= 0 and y >= 0 then
        self.button:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    else
        self.button:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -112, 245)
    end
end

function R:SavePosition029153()
    if not self.button or not EPC.saved then return end
    EPC.saved.recipeStyleLearnerLeft = math.max(0, num(self.button:GetLeft(), 0))
    EPC.saved.recipeStyleLearnerTop = math.max(0, num(self.button:GetTop(), 0))
end

function R:ResetPosition()
    self:EnsureSaved()
    EPC.saved.recipeStyleLearnerLeft = -1
    EPC.saved.recipeStyleLearnerTop = -1
    self:RestorePosition()
end

function R:GetStringForType(prefix, value)
    if type(GetString) == "function" then
        local ok, result = pcall(GetString, prefix, value)
        if ok and result then return tostring(result) end
    end
    return ""
end

function R:ClassifyLink(link)
    if not link or link == "" then return nil end
    local itemType = num(safe(GetItemLinkItemType, -1, link), -1)
    local specializedType = num(safe(GetItemLinkSpecializedItemType, -1, link), -1)

    local recipeType = rawget(_G, "ITEMTYPE_RECIPE")
    local motifType = rawget(_G, "ITEMTYPE_RACIAL_STYLE_MOTIF")
    if recipeType ~= nil and itemType == recipeType then return "RECIPE" end
    if motifType ~= nil and itemType == motifType then return "STYLE" end

    -- Modern ESO style pages are no longer always racial-style-motif items.
    -- Bound/event style pages can be ITEMTYPE_COLLECTIBLE, while some older
    -- ones are style-page containers. Detect the specialized style-page types
    -- directly so bound pages are included without pulling in unrelated
    -- collectibles/runeboxes.
    local collectibleStyle = rawget(_G, "SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE")
    local containerStyle = rawget(_G, "SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE")
    if collectibleStyle ~= nil and specializedType == collectibleStyle then return "STYLE_PAGE" end
    if containerStyle ~= nil and specializedType == containerStyle then return "STYLE_PAGE" end

    -- Some Bound Style Pages (including newer event/Archive pages) do not
    -- expose either specialized style-page constant on every API build. ESO
    -- still links them to the Outfit Style collectible they unlock. Use that
    -- relationship as the authoritative fallback instead of relying on the
    -- English item name or broad ITEMTYPE_COLLECTIBLE matching.
    if type(GetItemLinkContainerCollectibleId) == "function"
        and type(GetCollectibleCategoryType) == "function" then
        local collectibleId = num(safe(GetItemLinkContainerCollectibleId, 0, link), 0)
        local outfitCategory = rawget(_G, "COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE")
        if collectibleId > 0 and outfitCategory ~= nil then
            local categoryType = safe(GetCollectibleCategoryType, nil, collectibleId)
            if categoryType == outfitCategory then return "STYLE_PAGE" end
        end
    end

    return nil
end

function R:IsKnown(link, class)
    if class == "RECIPE" and type(IsItemLinkRecipeKnown) == "function" then
        local value = safe(IsItemLinkRecipeKnown, nil, link)
        if value ~= nil then return value == true end
    end

    if (class == "STYLE" or class == "STYLE_PAGE") and type(IsItemLinkBookKnown) == "function" then
        local value = safe(IsItemLinkBookKnown, nil, link)
        if value == true then return true end
    end

    -- Collectible / Bound Style Pages unlock a collectible rather than a motif
    -- book entry. This is the authoritative known check for those pages.
    if class == "STYLE_PAGE" and type(GetItemLinkContainerCollectibleId) == "function" then
        local collectibleId = num(safe(GetItemLinkContainerCollectibleId, 0, link), 0)
        if collectibleId > 0 then
            if type(IsCollectibleUnlocked) == "function" then
                local unlocked = safe(IsCollectibleUnlocked, nil, collectibleId)
                if unlocked ~= nil then return unlocked == true end
            end
            if type(IsCollectibleOwnedByDefId) == "function" then
                local owned = safe(IsCollectibleOwnedByDefId, nil, collectibleId)
                if owned ~= nil then return owned == true end
            end
        end
    end

    -- Fallback across both knowledge APIs. If either says known, do not consume it.
    if type(IsItemLinkRecipeKnown) == "function" and safe(IsItemLinkRecipeKnown, false, link) == true then return true end
    if type(IsItemLinkBookKnown) == "function" and safe(IsItemLinkBookKnown, false, link) == true then return true end
    return false
end

function R:GetUniqueId(bagId, slotIndex)
    if type(GetItemUniqueId) ~= "function" or type(Id64ToString) ~= "function" then return "" end
    local id = safe(GetItemUniqueId, nil, bagId, slotIndex)
    if not id then return "" end
    return tostring(safe(Id64ToString, "", id) or "")
end

function R:IsLocked(bagId, slotIndex)
    if type(IsItemPlayerLocked) == "function" and safe(IsItemPlayerLocked, false, bagId, slotIndex) == true then return true end
    return false
end

function R:ScanBag(bagId, out)
    if bagId == nil then return end
    local size = num(safe(GetBagSize, 0, bagId), 0)
    for slotIndex = 0, size - 1 do
        local link = tostring(safe(GetItemLink, "", bagId, slotIndex, LINK_STYLE_DEFAULT or 0) or "")
        if link ~= "" and not self:IsLocked(bagId, slotIndex) then
            local class = self:ClassifyLink(link)
            if class and not self:IsKnown(link, class) then
                out[#out + 1] = {
                    bagId = bagId,
                    slotIndex = slotIndex,
                    uniqueId = self:GetUniqueId(bagId, slotIndex),
                    link = link,
                    class = class,
                    name = tostring(safe(GetItemLinkName, "Unknown", link) or "Unknown"),
                }
            end
        end
    end
end

function R:BuildQueue()
    self:EnsureSaved()
    local out = {}
    self:ScanBag(BAG_BACKPACK, out)
    if EPC.saved.recipeStyleLearnerIncludeBank == true and self:IsBankOpen() then
        self:ScanBag(BAG_BANK, out)
        self:ScanBag(BAG_SUBSCRIBER_BANK, out)
    end
    return out
end

function R:FindEntry(entry)
    if not entry then return nil end
    local bags = { BAG_BACKPACK }
    if self:IsBankOpen() then
        bags[#bags + 1] = BAG_BANK
        bags[#bags + 1] = BAG_SUBSCRIBER_BANK
    end
    for _, bagId in ipairs(bags) do
        if bagId ~= nil then
            local size = num(safe(GetBagSize, 0, bagId), 0)
            for slotIndex = 0, size - 1 do
                if entry.uniqueId ~= "" and self:GetUniqueId(bagId, slotIndex) == entry.uniqueId then
                    return bagId, slotIndex
                end
            end
        end
    end
    return entry.bagId, entry.slotIndex
end

function R:FindEmptyBackpackSlot()
    if type(FindFirstEmptySlotInBag) == "function" then
        local slot = safe(FindFirstEmptySlotInBag, nil, BAG_BACKPACK)
        if slot ~= nil and num(slot, -1) >= 0 then return slot end
    end
    local size = num(safe(GetBagSize, 0, BAG_BACKPACK), 0)
    for slotIndex = 0, size - 1 do
        local link = tostring(safe(GetItemLink, "", BAG_BACKPACK, slotIndex, LINK_STYLE_DEFAULT or 0) or "")
        if link == "" then return slotIndex end
    end
    return nil
end

function R:UseBackpackItem(slotIndex)
    -- UseItem is protected/private from insecure addon code on current ESO.
    -- Never call it directly: one direct call taints the stack before the
    -- protected fallback can run. CallSecureProtected is the addon-safe path
    -- for usable inventory items while out of combat.
    if type(CallSecureProtected) ~= "function" then return false end
    if type(CanUseItem) == "function" then
        local usable = safe(CanUseItem, nil, BAG_BACKPACK, slotIndex)
        if usable == false then return false end
    end
    local ok, result = pcall(CallSecureProtected, "UseItem", BAG_BACKPACK, slotIndex)
    return ok and result ~= false
end

function R:BeginPopupSuppression()
    if not EPC.saved or EPC.saved.recipeStyleLearnerSuppressPopups ~= true or self.popupSuppressed then return end
    self.popupSuppressed = {}
    local controls = {
        rawget(_G, "ZO_AlertTextNotification"),
        rawget(_G, "ZO_CenterScreenAnnounce"),
        rawget(_G, "ZO_CenterScreenAnnounceControl"),
        rawget(_G, "CENTER_SCREEN_ANNOUNCE") and rawget(_G, "CENTER_SCREEN_ANNOUNCE").control or nil,
    }
    for _, control in ipairs(controls) do
        if control and type(control.SetHidden) == "function" then
            local hidden = type(control.IsHidden) == "function" and safe(control.IsHidden, false, control) == true or false
            self.popupSuppressed[#self.popupSuppressed + 1] = { control = control, hidden = hidden }
            pcall(control.SetHidden, control, true)
        end
    end
end

function R:EndPopupSuppression()
    if not self.popupSuppressed then return end
    for _, entry in ipairs(self.popupSuppressed) do
        if entry.control and type(entry.control.SetHidden) == "function" then
            pcall(entry.control.SetHidden, entry.control, entry.hidden == true)
        end
    end
    self.popupSuppressed = nil
end

function R:FinishTurbo()
    self.running = false
    self:EndPopupSuppression()
    local stats = self.stats or { attempted = 0, skipped = 0, bankMoved = 0 }
    notify(string.format("TURBO LEARNER finished: %d used%s%s.",
        stats.attempted or 0,
        (stats.bankMoved or 0) > 0 and string.format(" | %d moved from bank", stats.bankMoved) or "",
        (stats.skipped or 0) > 0 and string.format(" | %d skipped", stats.skipped) or ""),
        (stats.skipped or 0) == 0)
    self.queue = nil
    self.queueIndex = nil
    self:RefreshStatus()
end

function R:ProcessNext()
    if not self.running then return end
    local queue = self.queue or {}
    local index = num(self.queueIndex, 1)
    if index > #queue then self:FinishTurbo(); return end
    local entry = queue[index]
    self.queueIndex = index + 1

    local bagId, slotIndex = self:FindEntry(entry)
    local link = bagId ~= nil and tostring(safe(GetItemLink, "", bagId, slotIndex, LINK_STYLE_DEFAULT or 0) or "") or ""
    if link == "" or self:IsKnown(link, entry.class) then
        self.stats.skipped = (self.stats.skipped or 0) + 1
        if type(zo_callLater) == "function" then zo_callLater(function() self:ProcessNext() end, 60) else self:ProcessNext() end
        return
    end

    local function useFromBackpack(useSlot)
        if self:UseBackpackItem(useSlot) then
            self.stats.attempted = (self.stats.attempted or 0) + 1
        else
            self.stats.skipped = (self.stats.skipped or 0) + 1
        end
        if type(zo_callLater) == "function" then
            zo_callLater(function() self:ProcessNext() end, 340)
        else
            self:ProcessNext()
        end
    end

    if bagId == BAG_BACKPACK then
        useFromBackpack(slotIndex)
        return
    end

    if bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
        if not self:IsBankOpen() or type(RequestMoveItem) ~= "function" then
            self.stats.skipped = (self.stats.skipped or 0) + 1
            if type(zo_callLater) == "function" then zo_callLater(function() self:ProcessNext() end, 80) else self:ProcessNext() end
            return
        end
        local destination = self:FindEmptyBackpackSlot()
        if destination == nil then
            self.stats.skipped = (self.stats.skipped or 0) + 1
            notify("TURBO LEARNER: backpack is full; bank items cannot be learned until there is an empty slot.", false)
            if type(zo_callLater) == "function" then zo_callLater(function() self:ProcessNext() end, 80) else self:ProcessNext() end
            return
        end
        local ok, result = pcall(RequestMoveItem, bagId, slotIndex, BAG_BACKPACK, destination, 1)
        if not ok or result == false then
            self.stats.skipped = (self.stats.skipped or 0) + 1
            if type(zo_callLater) == "function" then zo_callLater(function() self:ProcessNext() end, 80) else self:ProcessNext() end
            return
        end
        self.stats.bankMoved = (self.stats.bankMoved or 0) + 1
        local tries = 0
        local function waitForMove()
            tries = tries + 1
            local movedBag, movedSlot = self:FindEntry(entry)
            if movedBag == BAG_BACKPACK and movedSlot ~= nil then
                useFromBackpack(movedSlot)
                return
            end
            if tries >= 8 then
                self.stats.skipped = (self.stats.skipped or 0) + 1
                if type(zo_callLater) == "function" then zo_callLater(function() self:ProcessNext() end, 80) else self:ProcessNext() end
                return
            end
            if type(zo_callLater) == "function" then zo_callLater(waitForMove, 120) else waitForMove() end
        end
        if type(zo_callLater) == "function" then zo_callLater(waitForMove, 120) else waitForMove() end
        return
    end

    self.stats.skipped = (self.stats.skipped or 0) + 1
    if type(zo_callLater) == "function" then zo_callLater(function() self:ProcessNext() end, 80) else self:ProcessNext() end
end

function R:StartTurbo()
    self:EnsureSaved()
    if self.running then
        notify("TURBO LEARNER is already running.", false)
        return
    end
    if EPC.saved.recipeStyleLearnerEnabled == false then
        notify("Recipe & Style Learner is disabled in Suite Settings.", false)
        return
    end
    if type(IsUnitInCombat) == "function" and safe(IsUnitInCombat, false, "player") == true then
        notify("TURBO LEARNER cannot use protected inventory items while you are in combat.", false)
        return
    end
    if not self:IsInventoryOrBankShowing() and not (self.IsLearnerSceneShowing and self:IsLearnerSceneShowing()) then
        notify("Open Turbo Learner from the top menu before learning items.", false)
        return
    end
    local queue = self:BuildQueue()
    if #queue == 0 then
        notify("TURBO LEARNER: no unknown recipes, furnishing plans, motifs, bound style pages, or style pages found here.", true)
        self:RefreshStatus()
        return
    end
    self.queue = queue
    self.queueIndex = 1
    self.stats = { attempted = 0, skipped = 0, bankMoved = 0 }
    self.running = true
    self:BeginPopupSuppression()
    notify(string.format("TURBO LEARNER: %d unknown item%s queued.", #queue, #queue == 1 and "" or "s"), true)
    self:RefreshStatus()
    self:ProcessNext()
end

local LEARNER_SCENE_NAME = "ESOAdventurerSuiteTurboLearner"
local LEARNER_DESCRIPTOR = "ESOAdventurerSuiteTurboLearner"
local PANEL_W, PANEL_H = 790, 700
local ROW_COUNT = 10

local function makeLearnerButton(parent, width, height, text)
    local b = wm:CreateControl(nil, parent, CT_BUTTON)
    b:SetDimensions(width, height)
    b:SetMouseEnabled(true)
    b:SetFont("ZoFontGameBold")
    b:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    b:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    b:SetText(text or "")

    local bg = wm:CreateControl(nil, b, CT_BACKDROP)
    bg:SetAnchorFill(b)
    bg:SetCenterColor(0.035, 0.052, 0.075, 0.98)
    bg:SetEdgeColor(0.26, 0.44, 0.58, 0.95)
    bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 1)
    b.easBg = bg

    b:SetHandler("OnMouseEnter", function(control)
        if control.easBg then control.easBg:SetCenterColor(0.075, 0.10, 0.14, 1) end
    end)
    b:SetHandler("OnMouseExit", function(control)
        if control.easBg then control.easBg:SetCenterColor(0.035, 0.052, 0.075, 0.98) end
    end)
    return b
end

local function getLinkQualityColor(link)
    local qf = rawget(_G, "GetItemLinkDisplayQuality") or rawget(_G, "GetItemLinkQuality")
    local q = type(qf) == "function" and safe(qf, nil, link) or nil
    local color = q ~= nil and safe(GetItemQualityColor, nil, q) or nil
    if color and color.UnpackRGBA then return color:UnpackRGBA() end
    return 0.34, 0.46, 0.58, 1
end

function R:IsLearnerSceneShowing()
    if not SCENE_MANAGER or type(SCENE_MANAGER.IsShowing) ~= "function" then return false end
    local ok, value = pcall(SCENE_MANAGER.IsShowing, SCENE_MANAGER, LEARNER_SCENE_NAME)
    return ok and value == true
end

function R:GetUnknownCount()
    return #self:BuildQueue()
end

function R:SetLayoutMode(_)
    -- v0.29.266: Turbo Learner is a top-menu page now, not a HUD overlay.
end

function R:RaiseForLayout()
end

function R:RefreshVisibility()
    -- Kept as a compatibility entry point for Suite Settings/Core. The learner
    -- no longer has a floating overlay to show/hide.
    if self.window and not self.window:IsHidden() then self:RefreshWindow() end
end

function R:RefreshStatus()
    if self.window and not self.window:IsHidden() then self:RefreshWindow() end
end

function R:CreateWindow()
    if self.window or not wm or not GuiRoot then return end

    local w = wm:CreateTopLevelWindow("EAS_TurboLearnerWindow")
    w:SetDimensions(PANEL_W, PANEL_H)
    w:SetAnchor(CENTER, GuiRoot, CENTER, 120, 0)
    w:SetClampedToScreen(true)
    w:SetMouseEnabled(true)
    w:SetMovable(false)
    if w.SetDrawTier and DT_HIGH then w:SetDrawTier(DT_HIGH) end
    if w.SetDrawLayer and DL_CONTROLS then w:SetDrawLayer(DL_CONTROLS) end
    w:SetDrawLevel(40)
    w:SetHidden(true)
    self.window = w

    local bg = wm:CreateControl(nil, w, CT_BACKDROP)
    bg:SetAnchorFill(w)
    bg:SetCenterColor(0.012, 0.020, 0.032, 0.985)
    bg:SetEdgeColor(0.22, 0.36, 0.48, 0.98)
    bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 2)

    local header = wm:CreateControl(nil, w, CT_BACKDROP)
    header:SetAnchor(TOPLEFT, w, TOPLEFT, 1, 1)
    header:SetAnchor(TOPRIGHT, w, TOPRIGHT, -1, 1)
    header:SetDimensions(0, 74)
    header:SetCenterColor(0.025, 0.050, 0.073, 0.99)
    header:SetEdgeColor(0, 0, 0, 0)

    local icon = wm:CreateControl(nil, header, CT_TEXTURE)
    icon:SetDimensions(46, 46)
    icon:SetAnchor(LEFT, header, LEFT, 18, 0)
    icon:SetTexture(BOOK_ICON)

    local title = wm:CreateControl(nil, header, CT_LABEL)
    title:SetFont("ZoFontWinH2")
    title:SetAnchor(TOPLEFT, header, TOPLEFT, 78, 11)
    title:SetDimensions(540, 31)
    title:SetColor(0.96, 0.86, 0.46, 1)
    title:SetText("TURBO RECIPE & STYLE LEARNER")

    local subtitle = wm:CreateControl(nil, header, CT_LABEL)
    subtitle:SetFont("ZoFontGame")
    subtitle:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, -2)
    subtitle:SetDimensions(590, 24)
    subtitle:SetColor(0.68, 0.78, 0.86, 1)
    subtitle:SetText("Review everything the Suite can learn before you press Learn All.")

    local close = makeLearnerButton(header, 42, 36, "X")
    close:SetAnchor(TOPRIGHT, header, TOPRIGHT, -14, 16)
    close:SetHandler("OnClicked", function() self:CloseWindow() end)

    local summary = wm:CreateControl(nil, w, CT_LABEL)
    summary:SetFont("ZoFontGameBold")
    summary:SetAnchor(TOPLEFT, w, TOPLEFT, 22, 91)
    summary:SetDimensions(500, 27)
    summary:SetColor(0.84, 0.90, 0.96, 1)
    self.summaryLabel = summary

    local status = wm:CreateControl(nil, w, CT_LABEL)
    status:SetFont("ZoFontGame")
    status:SetAnchor(TOPRIGHT, w, TOPRIGHT, -22, 91)
    status:SetDimensions(240, 27)
    status:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    status:SetColor(0.44, 0.88, 0.68, 1)
    self.statusLabel = status

    local divider = wm:CreateControl(nil, w, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, w, TOPLEFT, 22, 124)
    divider:SetAnchor(TOPRIGHT, w, TOPRIGHT, -22, 124)
    divider:SetHeight(1)
    divider:SetTexture("EsoUI/Art/Miscellaneous/white_1x1.dds")
    divider:SetColor(0.18, 0.28, 0.36, 0.95)

    self.rows = {}
    local firstY = 138
    for i = 1, ROW_COUNT do
        local row = wm:CreateControl(nil, w, CT_CONTROL)
        row:SetDimensions(PANEL_W - 44, 43)
        row:SetAnchor(TOPLEFT, w, TOPLEFT, 22, firstY + (i - 1) * 45)
        row:SetMouseEnabled(true)

        local rowBg = wm:CreateControl(nil, row, CT_BACKDROP)
        rowBg:SetAnchorFill(row)
        rowBg:SetCenterColor(i % 2 == 0 and 0.022 or 0.016, i % 2 == 0 and 0.035 or 0.028, i % 2 == 0 and 0.050 or 0.042, 0.98)
        rowBg:SetEdgeColor(0.08, 0.15, 0.21, 0.9)
        rowBg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 1)
        row.bg = rowBg

        local iconFrame = wm:CreateControl(nil, row, CT_BACKDROP)
        iconFrame:SetDimensions(36, 36)
        iconFrame:SetAnchor(LEFT, row, LEFT, 4, 0)
        iconFrame:SetCenterColor(0.02, 0.03, 0.04, 0.98)
        iconFrame:SetEdgeColor(0.34, 0.46, 0.58, 1)
        iconFrame:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds", 1, 1, 2)
        row.iconFrame = iconFrame

        local itemIcon = wm:CreateControl(nil, iconFrame, CT_TEXTURE)
        itemIcon:SetAnchor(TOPLEFT, iconFrame, TOPLEFT, 2, 2)
        itemIcon:SetAnchor(BOTTOMRIGHT, iconFrame, BOTTOMRIGHT, -2, -2)
        itemIcon:SetTexture("EsoUI/Art/Icons/icon_missing.dds")
        row.icon = itemIcon

        local nameLabel = wm:CreateControl(nil, row, CT_LABEL)
        nameLabel:SetFont("ZoFontGameBold")
        nameLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 50, 3)
        nameLabel:SetDimensions(485, 21)
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.nameLabel = nameLabel

        local detailLabel = wm:CreateControl(nil, row, CT_LABEL)
        detailLabel:SetFont("ZoFontGameSmall")
        detailLabel:SetAnchor(TOPLEFT, nameLabel, BOTTOMLEFT, 0, -2)
        detailLabel:SetDimensions(500, 17)
        detailLabel:SetColor(0.62, 0.73, 0.82, 1)
        row.detailLabel = detailLabel

        local stateLabel = wm:CreateControl(nil, row, CT_LABEL)
        stateLabel:SetFont("ZoFontGameBold")
        stateLabel:SetAnchor(RIGHT, row, RIGHT, -10, 0)
        stateLabel:SetDimensions(160, 30)
        stateLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        stateLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        stateLabel:SetColor(0.34, 0.90, 0.64, 1)
        stateLabel:SetText("READY TO LEARN")
        row.stateLabel = stateLabel

        row:SetHandler("OnMouseEnter", function(control)
            if control.bg then control.bg:SetCenterColor(0.055, 0.078, 0.10, 1) end
            local entry = control.entry
            if entry and ItemTooltip and type(InitializeTooltip) == "function" then
                InitializeTooltip(ItemTooltip, control, RIGHT, 6, 0, LEFT)
                if type(ItemTooltip.SetLink) == "function" then
                    pcall(ItemTooltip.SetLink, ItemTooltip, entry.link)
                elseif type(ItemTooltip.SetBagItem) == "function" then
                    pcall(ItemTooltip.SetBagItem, ItemTooltip, entry.bagId, entry.slotIndex)
                end
            end
        end)
        row:SetHandler("OnMouseExit", function(control)
            if control.bg then control.bg:SetCenterColor(0.018, 0.030, 0.044, 0.98) end
            if ItemTooltip and type(ClearTooltip) == "function" then pcall(ClearTooltip, ItemTooltip) end
        end)
        self.rows[i] = row
    end

    local prev = makeLearnerButton(w, 90, 34, "< PREV")
    prev:SetAnchor(BOTTOMLEFT, w, BOTTOMLEFT, 22, -68)
    prev:SetHandler("OnClicked", function()
        self.currentPage = math.max(1, num(self.currentPage, 1) - 1)
        self:RefreshWindow()
    end)
    self.prevButton = prev

    local page = wm:CreateControl(nil, w, CT_LABEL)
    page:SetDimensions(240, 34)
    page:SetAnchor(LEFT, prev, RIGHT, 10, 0)
    page:SetFont("ZoFontGame")
    page:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    page:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.pageLabel = page

    local nextButton = makeLearnerButton(w, 90, 34, "NEXT >")
    nextButton:SetAnchor(LEFT, page, RIGHT, 10, 0)
    nextButton:SetHandler("OnClicked", function()
        local pages = math.max(1, math.ceil(#(self.previewQueue or {}) / ROW_COUNT))
        self.currentPage = math.min(pages, num(self.currentPage, 1) + 1)
        self:RefreshWindow()
    end)
    self.nextButton = nextButton

    local refresh = makeLearnerButton(w, 110, 38, "REFRESH")
    refresh:SetAnchor(BOTTOMRIGHT, w, BOTTOMRIGHT, -192, -16)
    refresh:SetHandler("OnClicked", function() self:RefreshWindow(true) end)
    self.refreshButton = refresh

    local learn = makeLearnerButton(w, 154, 38, "LEARN ALL")
    learn:SetAnchor(BOTTOMRIGHT, w, BOTTOMRIGHT, -22, -16)
    learn.easBg:SetCenterColor(0.08, 0.20, 0.15, 0.98)
    learn.easBg:SetEdgeColor(0.26, 0.78, 0.54, 1)
    learn:SetHandler("OnClicked", function()
        if self.running then return end
        self:StartTurbo()
    end)
    self.learnButton = learn

    local help = wm:CreateControl(nil, w, CT_LABEL)
    help:SetFont("ZoFontGameSmall")
    help:SetAnchor(BOTTOMLEFT, w, BOTTOMLEFT, 22, -17)
    help:SetDimensions(360, 40)
    help:SetColor(0.58, 0.70, 0.80, 1)
    help:SetText("Backpack items are always scanned. Bank items are included only while a Bank is actually open and the setting is enabled.")

    self.currentPage = 1
end

function R:RefreshWindow(force)
    self:CreateWindow()
    if not self.window or self.window:IsHidden() then return end

    if not self.running or force == true then
        self.previewQueue = self:BuildQueue()
    end
    local queue = self.previewQueue or {}
    local pages = math.max(1, math.ceil(#queue / ROW_COUNT))
    self.currentPage = math.max(1, math.min(pages, num(self.currentPage, 1)))
    local startIndex = (self.currentPage - 1) * ROW_COUNT + 1

    for i, row in ipairs(self.rows or {}) do
        local entry = queue[startIndex + i - 1]
        row.entry = entry
        row:SetHidden(entry == nil)
        if entry then
            local icon = tostring(safe(GetItemLinkIcon, "", entry.link) or "")
            row.icon:SetTexture(icon ~= "" and icon or "EsoUI/Art/Icons/icon_missing.dds")
            row.nameLabel:SetText(zo_strformat("<<C:1>>", entry.name or "Unknown"))
            local bagText = entry.bagId == BAG_BACKPACK and "Backpack" or ((entry.bagId == BAG_BANK or entry.bagId == BAG_SUBSCRIBER_BANK) and "Bank" or "Inventory")
            local typeText
            if entry.class == "STYLE_PAGE" then
                typeText = "Bound / Collectible Style Page"
            elseif entry.class == "STYLE" then
                typeText = "Motif / Style"
            else
                typeText = "Recipe / Plan"
            end
            row.detailLabel:SetText(typeText .. "  •  " .. bagText)
            local r, g, b, a = getLinkQualityColor(entry.link)
            row.iconFrame:SetEdgeColor(r, g, b, a or 1)
            row.stateLabel:SetText("READY TO LEARN")
        end
    end

    if self.running then
        local total = #(self.queue or {})
        local done = math.max(0, math.min(total, num(self.queueIndex, 1) - 1))
        self.statusLabel:SetText(string.format("Learning %d / %d", done, total))
        self.statusLabel:SetColor(1.00, 0.72, 0.26, 1)
        self.learnButton:SetEnabled(false)
        self.learnButton:SetText("LEARNING...")
        self.refreshButton:SetEnabled(false)
    else
        self.statusLabel:SetText(#queue > 0 and "Ready" or "Nothing to learn")
        self.statusLabel:SetColor(#queue > 0 and 0.38 or 0.62, #queue > 0 and 0.90 or 0.72, #queue > 0 and 0.66 or 0.80, 1)
        self.learnButton:SetEnabled(#queue > 0)
        self.learnButton:SetText(#queue > 0 and ("LEARN ALL (" .. tostring(#queue) .. ")") or "LEARN ALL")
        self.refreshButton:SetEnabled(true)
    end

    self.summaryLabel:SetText(string.format("%d unknown item%s found", #queue, #queue == 1 and "" or "s"))
    self.pageLabel:SetText(string.format("Page %d of %d", self.currentPage, pages))
    self.prevButton:SetEnabled(self.currentPage > 1)
    self.nextButton:SetEnabled(self.currentPage < pages)
end

function R:OpenWindow()
    self:EnsureSaved()
    if EPC.saved.recipeStyleLearnerEnabled == false then
        notify("Turbo Recipe & Style Learner is disabled in Suite Settings.", false)
        return false
    end
    self:CreateWindow()
    if not self.window then return false end
    self.window:SetHidden(false)
    self.currentPage = 1
    self:RefreshWindow(true)
    return true
end

function R:CloseWindow()
    if self.running then
        self.running = false
        self.queue = nil
        self.queueIndex = nil
        self:EndPopupSuppression()
        notify("TURBO LEARNER cancelled.", false)
    end
    if self.window then self.window:SetHidden(true) end
    if ItemTooltip and type(ClearTooltip) == "function" then pcall(ClearTooltip, ItemTooltip) end

    -- v0.29.270: direct gameplay-hotkey launches own their temporary UI mode.
    -- Release it here too so the X button and the keybind both return to game.
    if self.directHotkeyOpen == true then
        self.directHotkeyOpen = false
        self.hotkeyOpenPending = false
        self:SetHotkeyActionLayer(false)
        if self.hotkeyOwnsUIMode == true then self:SetHotkeyUIMode(false) end
        self.hotkeyOwnsUIMode = false
    end

    if SCENE_MANAGER and type(SCENE_MANAGER.IsShowing) == "function" and SCENE_MANAGER:IsShowing(LEARNER_SCENE_NAME) then
        if type(SCENE_MANAGER.ShowBaseScene) == "function" then pcall(SCENE_MANAGER.ShowBaseScene, SCENE_MANAGER) end
    end
end

function R:SetHotkeyActionLayer(active)
    local layerName = "ESOAdventurerSuiteTurboLearnerLayer"
    if active then
        if self.hotkeyActionLayerPushed or type(PushActionLayerByName) ~= "function" then return end
        local ok = pcall(PushActionLayerByName, layerName)
        self.hotkeyActionLayerPushed = ok == true
    else
        if not self.hotkeyActionLayerPushed then return end
        if type(RemoveActionLayerByName) == "function" then pcall(RemoveActionLayerByName, layerName) end
        self.hotkeyActionLayerPushed = false
    end
end

function R:SetHotkeyUIMode(active)
    active = active == true
    if type(SetGameCameraUIMode) == "function" then pcall(SetGameCameraUIMode, active) end
    if SCENE_MANAGER and type(SCENE_MANAGER.SetInUIMode) == "function" then
        pcall(SCENE_MANAGER.SetInUIMode, SCENE_MANAGER, active)
    end
end

function R:ToggleMainMenuPage()
    self:EnsureSaved()

    -- v0.29.268: prevent the opening key-down from also reaching the inherited
    -- close action after the Turbo Learner scene enters UI mode.
    local now = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds()
        or (type(GetGameTimeMilliseconds) == "function" and GetGameTimeMilliseconds()) or 0
    if now > 0 and self.lastHotkeyToggleMs and (now - self.lastHotkeyToggleMs) < 220 then
        return true
    end
    self.lastHotkeyToggleMs = now

    if EPC.saved.recipeStyleLearnerEnabled == false then
        notify("Turbo Recipe & Style Learner is disabled in Suite Settings.", false)
        return false
    end
    if not self:RegisterMainMenuIcon() or not SCENE_MANAGER then
        notify("Turbo Learner top-menu page requires LibMainMenu-2.0.", false)
        return false
    end
    local showing = type(SCENE_MANAGER.IsShowing) == "function" and SCENE_MANAGER:IsShowing(LEARNER_SCENE_NAME)
    if showing then
        self:CloseWindow()
    elseif type(SCENE_MANAGER.Show) == "function" then
        SCENE_MANAGER:Show(LEARNER_SCENE_NAME)
    end
    return true
end

function ESOAdventurerSuite_ToggleTurboLearner()
    if EPC and EPC.RecipeStyleLearner and type(EPC.RecipeStyleLearner.ToggleMainMenuPage) == "function" then
        return EPC.RecipeStyleLearner:ToggleMainMenuPage()
    end
    return false
end

-- v0.29.270: gameplay hotkeys use a direct launcher. The same Turbo Learner
-- window is shown, but opening no longer depends on LibMainMenu selecting a
-- scene during the opening key-down. This guarantees a visible first press.
function R:OpenFromHotkey()
    self:EnsureSaved()
    if EPC.saved.recipeStyleLearnerEnabled == false then
        notify("Turbo Recipe & Style Learner is disabled in Suite Settings.", false)
        return true
    end

    -- Keep the two crafting tools mutually exclusive when switching directly
    -- between their hotkeys.
    local potion = EPC and EPC.AlchemyPotionMaker
    if potion and type(potion.CloseWindow) == "function" then
        local potionSceneShowing = false
        if SCENE_MANAGER and type(SCENE_MANAGER.IsShowing) == "function" then
            potionSceneShowing = safe(SCENE_MANAGER.IsShowing, false, SCENE_MANAGER, "ESOAdventurerSuitePotionMaker") == true
        end
        if potionSceneShowing or (potion.window and not potion.window:IsHidden()) then
            pcall(potion.CloseWindow, potion, true)
        end
    end

    self.hotkeyOpenPending = false
    self:SetHotkeyActionLayer(false)

    local alreadyInUIMode = type(IsGameCameraUIModeActive) == "function"
        and safe(IsGameCameraUIModeActive, false) == true
    self.hotkeyOwnsUIMode = not alreadyInUIMode
    self:SetHotkeyUIMode(true)
    self.directHotkeyOpen = true

    -- Show now; delay only the inherited close binding so this same physical
    -- key press cannot immediately close what it just opened.
    local opened = self:OpenWindow()
    if opened ~= true or not self.window or self.window:IsHidden() then
        self.directHotkeyOpen = false
        if self.hotkeyOwnsUIMode == true then self:SetHotkeyUIMode(false) end
        self.hotkeyOwnsUIMode = false
        return true
    end
    if self.window.BringWindowToTop then self.window:BringWindowToTop() end

    local function armCloseLayer()
        if R.directHotkeyOpen == true and R.window and not R.window:IsHidden() then
            R:SetHotkeyActionLayer(true)
        end
    end
    if type(zo_callLater) == "function" then zo_callLater(armCloseLayer, 120) else armCloseLayer() end
    return true
end

function R:CloseFromHotkey()
    self.hotkeyOpenPending = false
    self:CloseWindow()
    return true
end

function ESOAdventurerSuite_OpenTurboLearnerHotkey()
    if EPC and EPC.RecipeStyleLearner and type(EPC.RecipeStyleLearner.OpenFromHotkey) == "function" then
        return EPC.RecipeStyleLearner:OpenFromHotkey()
    end
    return true
end

function ESOAdventurerSuite_CloseTurboLearnerHotkey()
    if EPC and EPC.RecipeStyleLearner and type(EPC.RecipeStyleLearner.CloseFromHotkey) == "function" then
        return EPC.RecipeStyleLearner:CloseFromHotkey()
    end
    return true
end

function R:RegisterMainMenuIcon()
    if self.mainMenuRegistered then return true end
    local lmm = rawget(_G, "LibMainMenu2")
    if type(lmm) ~= "table" or type(lmm.AddMenuItem) ~= "function" then return false end
    if not SCENE_MANAGER or type(ZO_Scene) ~= "table" or type(ZO_Scene.New) ~= "function" then return false end
    if type(lmm.Init) == "function" then pcall(lmm.Init, lmm) end

    if type(ZO_CreateStringId) == "function" and rawget(_G, "SI_EAS_TURBO_LEARNER_MAIN_MENU") == nil then
        pcall(ZO_CreateStringId, "SI_EAS_TURBO_LEARNER_MAIN_MENU", "Turbo Learner")
    end
    local categoryName = rawget(_G, "SI_EAS_TURBO_LEARNER_MAIN_MENU") or rawget(_G, "SI_MAIN_MENU_JOURNAL")

    local scene = self.mainMenuScene
    if not scene then
        scene = ZO_Scene:New(LEARNER_SCENE_NAME, SCENE_MANAGER)
        self.mainMenuScene = scene
        if rawget(_G, "FRAGMENT_GROUP") and FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW and scene.AddFragmentGroup then
            pcall(scene.AddFragmentGroup, scene, FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
        end
        if rawget(_G, "RIGHT_PANEL_BG_FRAGMENT") and scene.AddFragment then
            pcall(scene.AddFragment, scene, RIGHT_PANEL_BG_FRAGMENT)
        end
        scene:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_SHOWING or state == SCENE_SHOWN then
                R:OpenWindow()
                if type(zo_callLater) == "function" then
                    zo_callLater(function()
                        if SCENE_MANAGER and type(SCENE_MANAGER.IsShowing) == "function"
                            and SCENE_MANAGER:IsShowing(LEARNER_SCENE_NAME) then
                            R:SetHotkeyActionLayer(true)
                        end
                    end, 90)
                else
                    R:SetHotkeyActionLayer(true)
                end
            elseif state == SCENE_HIDING or state == SCENE_HIDDEN then
                R:SetHotkeyActionLayer(false)
                if R.window then R.window:SetHidden(true) end
                if R.running then
                    R.running = false
                    R.queue = nil
                    R.queueIndex = nil
                    R:EndPopupSuppression()
                end
            end
        end)
    end

    local layoutInfo = {
        binding = "EAS_TURBO_LEARNER",
        categoryName = categoryName,
        callback = function()
            if SCENE_MANAGER:IsShowing(LEARNER_SCENE_NAME) then
                SCENE_MANAGER:ShowBaseScene()
            else
                SCENE_MANAGER:Show(LEARNER_SCENE_NAME)
            end
        end,
        visible = function()
            return not EPC.saved or EPC.saved.recipeStyleLearnerEnabled ~= false
        end,
        normal = "EsoUI/Art/MainMenu/menubar_journal_up.dds",
        pressed = "EsoUI/Art/MainMenu/menubar_journal_down.dds",
        highlight = "EsoUI/Art/MainMenu/menubar_journal_over.dds",
        disabled = "EsoUI/Art/MainMenu/menubar_journal_disabled.dds",
    }

    local ok = pcall(lmm.AddMenuItem, lmm, LEARNER_DESCRIPTOR, LEARNER_SCENE_NAME, layoutInfo, nil)
    if ok then self.mainMenuRegistered = true return true end
    return false
end

function R:OpenMainMenuPage()
    if self:RegisterMainMenuIcon() and SCENE_MANAGER and type(SCENE_MANAGER.Show) == "function" then
        SCENE_MANAGER:Show(LEARNER_SCENE_NAME)
        return true
    end
    notify("Turbo Learner top-menu icon requires LibMainMenu-2.0.", false)
    return false
end

function R:RegisterEvents()
    if self.eventsRegistered or not EVENT_MANAGER then return end
    self.eventsRegistered = true

    if rawget(_G, "EVENT_INVENTORY_SINGLE_SLOT_UPDATE") then
        EPC.Runtime:RegisterEvent("RecipeStyleLearner", "PreviewInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            if not self.window or self.window:IsHidden() then return end
            EPC.Runtime:UnregisterUpdate("RecipeStyleLearner", "PreviewDebounce")
            EPC.Runtime:RegisterUpdate("RecipeStyleLearner", "PreviewDebounce", 180, function()
                EPC.Runtime:UnregisterUpdate("RecipeStyleLearner", "PreviewDebounce")
                self:RefreshWindow(true)
            end)
        end)
    end
    if rawget(_G, "EVENT_OPEN_BANK") then
        EPC.Runtime:RegisterEvent("RecipeStyleLearner", "PreviewBankOpen", EVENT_OPEN_BANK, function() if self.window and not self.window:IsHidden() then self:RefreshWindow(true) end end)
    end
    if rawget(_G, "EVENT_CLOSE_BANK") then
        EPC.Runtime:RegisterEvent("RecipeStyleLearner", "PreviewBankClose", EVENT_CLOSE_BANK, function() if self.window and not self.window:IsHidden() then self:RefreshWindow(true) end end)
    end
end

function R:Initialize()
    self:EnsureSaved()
    self:RegisterEvents()
    self:CreateWindow()

    local attempts = 0
    local function tryMainMenu()
        attempts = attempts + 1
        if R:RegisterMainMenuIcon() or attempts >= 10 then return end
        if type(zo_callLater) == "function" then zo_callLater(tryMainMenu, 500) end
    end
    if type(zo_callLater) == "function" then zo_callLater(tryMainMenu, 300) else tryMainMenu() end
end
