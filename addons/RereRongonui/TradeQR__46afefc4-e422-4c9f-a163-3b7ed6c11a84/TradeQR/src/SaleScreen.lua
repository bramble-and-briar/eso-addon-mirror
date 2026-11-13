-- Full-screen scene that shows the first pending record (sale or listing) as a QR code plus readable details.
-- Opens by itself when there are pending sales and the player is idle in the HUD
-- (no combat, no other menu open), so it never interrupts gameplay.
local SaleScreen = ZO_InitializingObject:Subclass()

local GAMEPAD_SCENE_NAME = "TradeQRGamepad"
local KEYBOARD_SCENE_NAME = "TradeQRKeyboard"
local AUTO_SHOW_UPDATE_NAME = "TradeQR_SaleScreen_AutoShow"

local WINDOW_WIDTH = 1200
local WINDOW_HEIGHT = 720
local QR_CANVAS_SIZE = 620
local PADDING = 40
-- luaqrcode error correction levels: 1 = L, 2 = M, 3 = Q, 4 = H. M survives TV glare well enough.
local QR_ERROR_CORRECTION = 2

function SaleScreen:Initialize(saleQueue, salePayload, savedVars)
    self.saleQueue = saleQueue
    self.salePayload = salePayload
    self.savedVars = savedVars
    self.snoozedUntilS = 0
    self.lastAnnouncedCount = saleQueue:GetCount()

    self:CreateControls()
    self:CreateKeybinds()
    self:CreateScenes()

    saleQueue:RegisterCallback("Changed", function() self:OnQueueChanged() end)
end

function SaleScreen:CreateControls()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("TradeQRScreen")
    window:SetDimensions(WINDOW_WIDTH, WINDOW_HEIGHT)
    window:SetAnchor(CENTER, GuiRoot, CENTER)
    window:SetHidden(true)
    self.window = window

    local backdrop = WINDOW_MANAGER:CreateControl("TradeQRScreenBackdrop", window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0, 0, 0, 0.9)
    backdrop:SetEdgeColor(0, 0, 0, 0)

    local qrCanvas = WINDOW_MANAGER:CreateControl("TradeQRScreenCanvas", window, CT_CONTROL)
    qrCanvas:SetDimensions(QR_CANVAS_SIZE, QR_CANVAS_SIZE)
    qrCanvas:SetAnchor(LEFT, window, LEFT, PADDING, 0)
    self.qrRenderer = TradeQR.QRRenderer:New(qrCanvas, QR_CANVAS_SIZE)

    self.titleLabel = self:CreateLabel("TradeQRScreenTitle", "ZoFontGamepad42")
    self.titleLabel:SetAnchor(TOPLEFT, qrCanvas, TOPRIGHT, PADDING, 0)

    self.counterLabel = self:CreateLabel("TradeQRScreenCounter", "ZoFontGamepad27")
    self.counterLabel:SetAnchor(TOPLEFT, self.titleLabel, BOTTOMLEFT, 0, 4)

    self.detailsLabel = self:CreateLabel("TradeQRScreenDetails", "ZoFontGamepad34")
    self.detailsLabel:SetAnchor(TOPLEFT, self.counterLabel, BOTTOMLEFT, 0, 24)
    self.detailsLabel:SetWidth(WINDOW_WIDTH - QR_CANVAS_SIZE - 3 * PADDING)

    self.hintLabel = self:CreateLabel("TradeQRScreenHint", "ZoFontGamepad27")
    self.hintLabel:SetAnchor(BOTTOMLEFT, qrCanvas, BOTTOMRIGHT, PADDING, 0)
    self.hintLabel:SetWidth(WINDOW_WIDTH - QR_CANVAS_SIZE - 3 * PADDING)
    self.hintLabel:SetText(GetString(TRADEQR_HINT))
end

function SaleScreen:CreateLabel(name, font)
    local label = WINDOW_MANAGER:CreateControl(name, self.window, CT_LABEL)
    label:SetFont(font)
    label:SetColor(1, 1, 1, 1)
    return label
end

function SaleScreen:CreateKeybinds()
    self.keybindDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = GetString(TRADEQR_KEYBIND_DONE),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function() self:OnDone() end,
        },
        {
            name = GetString(TRADEQR_KEYBIND_SKIP),
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function() return self.saleQueue:GetCount() > 1 end,
            callback = function() self:OnSkip() end,
        },
        {
            name = GetString(TRADEQR_KEYBIND_LATER),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function() self:OnLater() end,
        },
    }
end

function SaleScreen:CreateScenes()
    local fragment = ZO_SimpleSceneFragment:New(self.window)

    self.gamepadScene = self:CreateScene(GAMEPAD_SCENE_NAME, FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW, fragment)
    self.keyboardScene = self:CreateScene(KEYBOARD_SCENE_NAME, FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW, fragment)
end

function SaleScreen:CreateScene(sceneName, fragmentGroup, fragment)
    local scene = ZO_Scene:New(sceneName, SCENE_MANAGER)
    scene:AddFragmentGroup(fragmentGroup)
    scene:AddFragment(fragment)
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindDescriptor)
            self:Refresh()
        elseif newState == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindDescriptor)
        end
    end)
    return scene
end

function SaleScreen:GetSceneName()
    return IsInGamepadPreferredMode() and GAMEPAD_SCENE_NAME or KEYBOARD_SCENE_NAME
end

function SaleScreen:IsShowing()
    return SCENE_MANAGER:IsShowing(GAMEPAD_SCENE_NAME) or SCENE_MANAGER:IsShowing(KEYBOARD_SCENE_NAME)
end

function SaleScreen:Show()
    if self.saleQueue:GetCount() == 0 then
        d(GetString(TRADEQR_CHAT_NOTHING_PENDING))
        return
    end
    if not self:IsShowing() then
        SCENE_MANAGER:Push(self:GetSceneName())
    end
end

function SaleScreen:Hide()
    if self:IsShowing() then
        SCENE_MANAGER:Hide(self:GetSceneName())
    end
end

function SaleScreen:StartAutoShow()
    EVENT_MANAGER:RegisterForUpdate(AUTO_SHOW_UPDATE_NAME, TradeQR.autoShowCheckIntervalMs, function()
        self:TryAutoShow()
    end)
end

function SaleScreen:CanAutoShow()
    return self.saleQueue:GetCount() > 0
        and GetTimeStamp() >= self.snoozedUntilS
        and SCENE_MANAGER:IsShowing("hud")
        and not IsUnitInCombat("player")
        and not IsUnitDeadOrReincarnating("player")
end

function SaleScreen:TryAutoShow()
    if self:CanAutoShow() then
        self:Show()
    end
end

function SaleScreen:OnQueueChanged()
    local count = self.saleQueue:GetCount()
    if count > self.lastAnnouncedCount then
        d(zo_strformat(GetString(TRADEQR_CHAT_NEW_SALES), count - self.lastAnnouncedCount))
    end
    self.lastAnnouncedCount = count

    if self:IsShowing() then
        self:Refresh()
    end
end

function SaleScreen:OnDone()
    self.saleQueue:RemoveFirst()
    if self.saleQueue:GetCount() == 0 then
        self:Hide()
    end
end

function SaleScreen:OnSkip()
    self.saleQueue:MoveFirstToEnd()
end

function SaleScreen:OnLater()
    self.snoozedUntilS = GetTimeStamp() + self.savedVars.snoozeSeconds
    self:Hide()
end

function SaleScreen:Refresh()
    local sale = self.saleQueue:GetFirst()
    if not sale then
        return
    end

    self.titleLabel:SetText(self:GetTitleText(sale))
    self.counterLabel:SetText(zo_strformat(GetString(TRADEQR_COUNTER), 1, self.saleQueue:GetCount()))
    self.detailsLabel:SetText(self:BuildRecordDetailsText(sale))
    self:RenderQRCode(sale)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindDescriptor)
end

function SaleScreen:GetTitleText(record)
    if record.kind == TradeQR.RECORD_KIND_LISTING then
        return GetString(TRADEQR_SCREEN_TITLE_LISTING)
    elseif record.kind == TradeQR.RECORD_KIND_TRADER then
        return GetString(TRADEQR_SCREEN_TITLE_TRADER)
    end
    return GetString(TRADEQR_SCREEN_TITLE)
end

function SaleScreen:BuildRecordDetailsText(record)
    if record.kind == TradeQR.RECORD_KIND_LISTING then
        return self:BuildListingDetailsText(record)
    elseif record.kind == TradeQR.RECORD_KIND_TRADER then
        return self:BuildTraderDetailsText(record)
    end
    return self:BuildDetailsText(record)
end

function SaleScreen:BuildTraderDetailsText(trader)
    local lines = {
        string.format("%s: %s", GetString(TRADEQR_LABEL_GUILD), trader.guildName),
        string.format("%s: %s", GetString(TRADEQR_LABEL_TRADER), trader.traderName),
        string.format("%s: %s", GetString(TRADEQR_LABEL_WEEK_FROM), GetDateStringFromTimestamp(trader.weekStartS)),
        string.format("%s: %s", GetString(TRADEQR_LABEL_WEEK_TO), GetDateStringFromTimestamp(trader.weekEndS)),
    }
    return table.concat(lines, "\n")
end

function SaleScreen:BuildDetailsText(sale)
    local lines = {
        string.format("%s: %s", GetString(TRADEQR_LABEL_GUILD), sale.guildName),
        string.format("%s: %s", GetString(TRADEQR_LABEL_ITEM), sale.itemLink),
        string.format("%s: %d", GetString(TRADEQR_LABEL_QUANTITY), sale.quantity),
        string.format("%s: %s |t32:32:EsoUI/Art/currency/currency_gold.dds|t", GetString(TRADEQR_LABEL_PRICE), ZO_CommaDelimitNumber(sale.price)),
        string.format("%s: %s", GetString(TRADEQR_LABEL_BUYER), sale.buyer),
        string.format("%s: %s", GetString(TRADEQR_LABEL_DATE), GetDateStringFromTimestamp(sale.timestamp)),
    }
    return table.concat(lines, "\n")
end

function SaleScreen:BuildListingDetailsText(listing)
    local lines = {
        string.format("%s: %s", GetString(TRADEQR_LABEL_GUILD), listing.guildName),
        string.format("%s: %s", GetString(TRADEQR_LABEL_ITEM), listing.itemLink),
        string.format("%s: %d", GetString(TRADEQR_LABEL_QUANTITY), listing.quantity),
        string.format("%s: %s |t32:32:EsoUI/Art/currency/currency_gold.dds|t", GetString(TRADEQR_LABEL_PRICE), ZO_CommaDelimitNumber(listing.price)),
        string.format("%s: %s |t32:32:EsoUI/Art/currency/currency_gold.dds|t", GetString(TRADEQR_LABEL_LISTING_FEE), ZO_CommaDelimitNumber(listing.fee or 0)),
        string.format("%s: %s", GetString(TRADEQR_LABEL_DATE), GetDateStringFromTimestamp(listing.timestamp)),
    }
    return table.concat(lines, "\n")
end

function SaleScreen:RenderQRCode(sale)
    if self.renderedEventId == sale.eventId then
        return
    end
    local isEncoded, matrixOrError = TradeQR_QREncoder.qrcode(self.salePayload:Build(sale), QR_ERROR_CORRECTION)
    if not isEncoded then
        d(zo_strformat(GetString(TRADEQR_CHAT_QR_ERROR), tostring(matrixOrError)))
        return
    end
    self.qrRenderer:Render(matrixOrError)
    self.renderedEventId = sale.eventId
end

TradeQR.SaleScreen = SaleScreen
