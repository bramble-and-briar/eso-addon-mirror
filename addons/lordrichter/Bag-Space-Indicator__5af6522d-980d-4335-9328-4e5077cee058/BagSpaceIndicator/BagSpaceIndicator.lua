----------------------------------------------------------------------------------------------------------------------------------------
--  BagSpaceIndicator
----------------------------------------------------------------------------------------------------------------------------------------
-- This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. 
-- The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. 
-- All rights reserved
--
-- You can read the full terms at https://account.elderscrollsonline.com/add-on-terms
----------------------------------------------------------------------------------------------------------------------------------------
local AddonInfo = {
    addon = "BagSpaceIndicator",
    version = "3.52.0",
    author = "Lord Richter",
    savename = "BagSpaceIndicatorVars"
}

----------------------------------------------------------------------------------------------------------------------------------------
-- Addon configuration
----------------------------------------------------------------------------------------------------------------------------------------

local BSI = {
    addonready = 0,
    debug = "Uninitialized",
    message = "",
    bankfree = "",
    invfree = "",
    configpanel = {},
    savedvariables = {},
}

local BSIUI = {
    windowmgr = GetWindowManager(),
    topwindow = nil,
    backdrop = nil,
    line1 = nil,
    line2 = nil,
    line3 = nil,
    label1 = nil,
    label2 = nil,
    label3 = nil,
    icon1 = nil,
    icon2 = nil,
    icon3 = nil,
    showWindowOverride = false,
    font = {
        pcmedium = "ZoFontGameMedium",
        pcsmall = "ZoFontGameSmall",
        conmedium = "ZoFontGamepad18",
        consmall = "ZoFontGamepad18"
    },
    color = {
        white = "|cffffff",
        red = "|cff0000",
        yellow = "|cffff00",
        gold = "|cffd700",
        gray = "|c7f7f7f",
        cream = "|cffffcc"
    },
    default = {
        pc = {
            offsetX = 0,
            offsetY = 20,
            scale = 1
        },
        console = {
            offsetX = 300,
            offsetY = 970,
            scale = 1.07
        }
    }
}

local GetBagSize = GetBagSize
local GetNumBagUsedSlots = GetNumBagUsedSlots
local GetNumBagFreeSlots = GetNumBagFreeSlots
local GetBagUseableSize = GetBagUseableSize
local GetCurrencyAmount = GetCurrencyAmount
local GetFrameTimeMilliseconds = GetFrameTimeMilliseconds
local FormatIntegerWithDigitGrouping = FormatIntegerWithDigitGrouping

local BAG_BACKPACK = BAG_BACKPACK
local BAG_BANK = BAG_BANK
local BAG_SUBSCRIBER_BANK = BAG_SUBSCRIBER_BANK
local guildbankid = BAG_GUILDBANK
local CURT_MONEY = CURT_MONEY
local CURRENCY_LOCATION_CHARACTER = CURRENCY_LOCATION_CHARACTER

----------------------------------------------------------------------------------------------------------------------------------------
-- Utility 
----------------------------------------------------------------------------------------------------------------------------------------

local template_bagdata = {
    bag = 0,
    maximum = 0,
    used = 0,
    available = 0
}

local function initializeTable(template)
    local t2 = {}
    local k, v
    for k, v in pairs(template) do
        t2[k] = v
    end
    return t2
end

----------------------------------------------------------------------------------------------------------------------------------------
-- UI handlers
----------------------------------------------------------------------------------------------------------------------------------------

function BSIUpdate()
    if BSI.updated then
        BSI.updated = 0
    end
end

local function HideCheck()
    if ZO_CompassFrame and BagSpaceIndicatorFloat then
        BagSpaceIndicatorFloat:SetHidden(ZO_CompassFrame:IsHidden())
    end
end

-- save the window position if they move it
local function OnMoveStop(self)
    BSI.savedvariables.offsetX = self:GetLeft()
    BSI.savedvariables.offsetY = self:GetTop()
end

----------------------------------------------------------------------------------------------------------------------------------------
-- Bag Space Window
----------------------------------------------------------------------------------------------------------------------------------------

local function CalculateDefaultUIValues()
    BSIUI.screenwidth = GuiRoot:GetWidth()
    BSIUI.screenheight = GuiRoot:GetHeight()
    BSIUI.screenscale = BSIUI.screenwidth / 1920

    BSIUI.default.backgroundalpha = 0.8

    -- PC location is 20% from left, 
    BSIUI.default.pc.offsetX = BSIUI.screenwidth * 0.2
    BSIUI.default.pc.offsetY = 20

    -- console location is bottom between bounty and skills
    BSIUI.default.console.offsetX = BSIUI.screenwidth * 0.15
    BSIUI.default.console.offsetY = BSIUI.screenheight - (BSIUI.screenheight * 0.1)

end

-- -------------------------------------------------------------------------------------------------------------------------------------

local function ResetUIValues()
    CalculateDefaultUIValues()
    BSI.savedvariables.scale = IsConsoleUI() and BSIUI.screenscale * BSIUI.default.console.scale or BSIUI.screenscale
end

-- -------------------------------------------------------------------------------------------------------------------------------------

local function InitFloatingWindow()
    -- create the floating information window
    local windowcfg
    local infoboxmargin = 24
    local labelheight = 25
    local labelwidth = 80
    local iconwidth = labelheight * 0.75
    local iconheight = labelheight * 0.75
    local linegap = 5
    local linespace = 2
    local linewidth = labelwidth + iconwidth + linegap
    local scale = BSI.savedvariables.scale

    BSIUI.topwindow = BSIUI.windowmgr:CreateTopLevelWindow("BagSpaceIndicatorFloat")
    windowcfg = BSIUI.topwindow
    windowcfg:SetClampedToScreen(true)
    windowcfg:SetMouseEnabled(true)
    windowcfg:SetResizeToFitDescendents(true)
    windowcfg:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, BSI.savedvariables.offsetX, BSI.savedvariables.offsetY)
    windowcfg:SetHidden(false)
    windowcfg:SetMovable(true)
    windowcfg:SetScale(scale)
    windowcfg:SetAlpha(1.0)
    windowcfg:SetHandler("OnMoveStop", OnMoveStop)
    windowcfg:SetDrawLayer(DL_CONTROLS)
    windowcfg:SetDrawLevel(0)


    BSIUI.backdrop = BSIUI.windowmgr:CreateControl("BagSpaceIndicatorFloatBG", BSIUI.topwindow, CT_BACKDROP)
    windowcfg = BSIUI.backdrop
    windowcfg:SetHidden(false)
    windowcfg:SetClampedToScreen(false)
    windowcfg:SetAnchor(TOPLEFT, BSIUI.topwindow, TOPLEFT, 0, 0)
    windowcfg:SetResizeToFitDescendents(true)
    windowcfg:SetResizeToFitPadding(32, 16)
    --windowcfg:SetDimensionConstraints(linewidth+infoboxmargin*2,(labelheight+linespace)*3+infoboxmargin)
    windowcfg:SetInsets(16, 16, -16, -16)
    --windowcfg:SetScale(scale)
    windowcfg:SetEdgeTexture("EsoUI/Art/ChatWindow/chat_BG_edge.dds", 256, 256, 16)
    windowcfg:SetCenterTexture("EsoUI/Art/ChatWindow/chat_BG_center.dds")
    windowcfg:SetAlpha(BSI.savedvariables.backgroundalpha)


    BSIUI.infobox = BSIUI.windowmgr:CreateControl("BagSpaceIndicatorFloatBox", BSIUI.backdrop, CT_CONTROL)
    windowcfg = BSIUI.infobox
    windowcfg:SetAnchor(TOPLEFT, BSIUI.backdrop, TOPLEFT, infoboxmargin, infoboxmargin / 2)
    windowcfg:SetResizeToFitDescendents(true)


    -- gold
    BSIUI.line1 = BSIUI.windowmgr:CreateControl("BagSpaceIndicatorFloatLine1", BSIUI.infobox, CT_CONTROL)
    windowcfg = BSIUI.line1
    windowcfg:SetAnchor(TOPLEFT, BSIUI.infobox, TOPLEFT, 0, 0)
    windowcfg:SetDimensions(linewidth, labelheight)
    windowcfg:SetResizeToFitDescendents(true)

    BSIUI.icon1 = BSIUI.windowmgr:CreateControl("BagSpaceIndicatorFloatIcon1", BSIUI.line1, CT_TEXTURE)
    windowcfg = BSIUI.icon1
    windowcfg:SetDimensions(iconwidth, iconheight)
    --windowcfg:SetScale(scale)
    windowcfg:SetAnchor(LEFT, BSIUI.line1, LEFT, 0, labelheight * .1)
    windowcfg:SetTexture("/esoui/art/currency/currency_gold.dds")

    BSIUI.label1 = BSIUI.windowmgr:CreateControl("BagSpaceIndicatorFloatLabel1", BSIUI.line1, CT_LABEL)
    windowcfg = BSIUI.label1
    windowcfg:SetColor(0.8, 0.8, 0.8, 1)
    windowcfg:SetFont(IsConsoleUI() and BSIUI.font.conmedium or BSIUI.font.pcmedium)
    windowcfg:SetWrapMode(TEX_MODE_CLAMP)
    windowcfg:SetText("")
    windowcfg:SetAnchor(LEFT, BSIUI.icon1, RIGHT, linegap, 1)
    --windowcfg:SetScale(scale)
    windowcfg:SetDimensions(labelwidth, labelheight)

    -- bags
    BSIUI.line2 = BSIUI.windowmgr:CreateControl("BagSpaceIndicatorFloatLine2", BSIUI.infobox, CT_CONTROL)
    windowcfg = BSIUI.line2
    --windowcfg:SetAnchor(TOPLEFT, BSIUI.infobox, TOPLEFT, 0, labelheight)
    windowcfg:SetAnchor(TOPLEFT, BSIUI.line1, BOTTOMLEFT, 0, linespace)
    windowcfg:SetDimensions(linewidth, labelheight)
    windowcfg:SetResizeToFitDescendents(true)

    BSIUI.icon2 = BSIUI.windowmgr:CreateControl("BagSpaceIndicatorFloatIcon2", BSIUI.line2, CT_TEXTURE)
    windowcfg = BSIUI.icon2
    windowcfg:SetDimensions(iconwidth, iconheight)
    windowcfg:SetAnchor(LEFT, BSIUI.line2, LEFT, 0, 0)
    --windowcfg:SetScale(scale)
    windowcfg:SetTexture("/esoui/art/tooltips/icon_bag.dds")

    BSIUI.label2 = BSIUI.windowmgr:CreateControl("BagSpaceIndicatorFloatLabel2", BSIUI.line2, CT_LABEL)
    windowcfg = BSIUI.label2
    windowcfg:SetColor(0.8, 0.8, 0.8, 1)
    windowcfg:SetFont(IsConsoleUI() and BSIUI.font.conmedium or BSIUI.font.pcmedium)
    windowcfg:SetWrapMode(TEX_MODE_CLAMP)
    windowcfg:SetText("")
    windowcfg:SetAnchor(LEFT, BSIUI.icon2, RIGHT, linegap, 1)
    --windowcfg:SetScale(scale)
    windowcfg:SetDimensions(labelwidth, labelheight)

    --bank
    BSIUI.line3 = BSIUI.windowmgr:CreateControl("BagSpaceIndicatorFloatLine3", BSIUI.infobox, CT_CONTROL)
    windowcfg = BSIUI.line3
    --windowcfg:SetAnchor(TOPLEFT, BSIUI.infobox, TOPLEFT, 0, (labelheight*2))
    windowcfg:SetAnchor(TOPLEFT, BSIUI.line2, BOTTOMLEFT, 0, linespace)
    windowcfg:SetDimensions(linewidth, labelheight)
    windowcfg:SetResizeToFitDescendents(true)

    BSIUI.icon3 = BSIUI.windowmgr:CreateControl("BagSpaceIndicatorFloatIcon3", BSIUI.line3, CT_TEXTURE)
    windowcfg = BSIUI.icon3
    windowcfg:SetDimensions(iconwidth, iconheight)
    windowcfg:SetAnchor(LEFT, BSIUI.line3, LEFT, 0, 0)
    --windowcfg:SetScale(scale)
    windowcfg:SetTexture("/esoui/art/tooltips/icon_bank.dds")

    BSIUI.label3 = BSIUI.windowmgr:CreateControl("BagSpaceIndicatorFloatLabel3", BSIUI.line3, CT_LABEL)
    windowcfg = BSIUI.label3
    windowcfg:SetColor(0.8, 0.8, 0.8, 1)
    windowcfg:SetFont(IsConsoleUI() and BSIUI.font.conmedium or BSIUI.font.pcmedium)
    windowcfg:SetWrapMode(TEX_MODE_CLAMP)
    windowcfg:SetText("")
    windowcfg:SetAnchor(LEFT, BSIUI.icon3, RIGHT, linegap, 1)
    --windowcfg:SetScale(scale)
    windowcfg:SetDimensions(labelwidth, labelheight)

    BSIUI.fragment = ZO_SimpleSceneFragment:New(BagSpaceIndicatorFloat)
    SCENE_MANAGER:GetScene("hud"):AddFragment(BSIUI.fragment)
    SCENE_MANAGER:GetScene("hudui"):AddFragment(BSIUI.fragment)

end

local function RescaleFloatingWindow()
    local scale = BSI.savedvariables.scale
    BagSpaceIndicatorFloat:SetScale(scale)
end

local function ShowFloatingWindow()
    if (BSIUI.showWindowOverride) then
        return
    end
    BSIUI.topwindow:SetDrawLayer(DL_OVERLAY)
    BSIUI.settingScene = SCENE_MANAGER:GetCurrentScene()
    BSIUI.showWindowOverride = true;
    BSIUI.settingScene:AddFragment(BSIUI.fragment)
    BSIUI.fragment:Refresh()
end

local function HideFloatingWindow()
    if (not BSIUI.showWindowOverride or not BSIUI.settingScene) then
        return
    end
    BSIUI.topwindow:SetDrawLayer(DL_CONTROLS)
    BSIUI.showWindowOverride = false;
    BSIUI.settingScene:RemoveFragment(BSIUI.fragment)
    BSIUI.fragment:Refresh()
    BSIUI.settingScene = nil
end


----------------------------------------------------------------------------------------------------------------------------------------
-- Configuration Panel
----------------------------------------------------------------------------------------------------------------------------------------

local function InitConfigPanel()

    if not LibHarvensAddonSettings then
        return
    end

    BSI.configpanel.options = {
        allowDefaults = true,
        allowRefresh = true,
        defaultsFunction = ResetUIValues
    }

    BSI.configpanel.settings = LibHarvensAddonSettings:AddAddon("Bag Space Indicator", BSI.configpanel.options)
    if not BSI.configpanel.settings then
        return
    end

    BSI.configpanel.settings.version = "3.52.0"

    BSI.configpanel.disabled = false;

    BSI.configpanel.showWindow = false;

    BSI.configpanel.scaleValue = BSI.savedvariables.scale * 100

    BSI.configpanel.opacityValue = BSI.savedvariables.backgroundalpha * 100

    BSI.configpanel.locationX = zo_floor(BSI.savedvariables.offsetX)

    BSI.configpanel.locationY = zo_floor(BSI.savedvariables.offsetY)

    BSI.configpanel.viewWindow = {
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Show Bag Space Window",
        tooltip = "Show the bag space window. The window may appear behind other windows.",
        setFunction = function(value)
            if value then
                BSI.configpanel.showWindow = true
                ShowFloatingWindow()
            else
                BSI.configpanel.showWindow = false
                HideFloatingWindow()
            end
        end,
        getFunction = function()
            return BSI.configpanel.showWindow
        end,
        default = BSI.configpanel.showWindow,
        disable = function()
            return BSI.configpanel.disabled
        end
    }

    BSI.configpanel.backgroundSlider = {
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Background opacity",
        tooltip = "Set how transparent the window background is",
        setFunction = function(value)
            BSI.configpanel.opacityValue = value
            BSI.savedvariables.backgroundalpha = value / 100
            BSIUI.backdrop:SetAlpha(BSI.savedvariables.backgroundalpha)

        end,
        getFunction = function()
            return BSI.configpanel.opacityValue
        end,
        default = BSIUI.default.backgroundalpha * 100,
        min = 10,
        max = 100,
        step = 5,
        unit = "%",
        format = "%d",
        disable = function()
            return BSI.configpanel.disabled
        end
    }

    BSI.configpanel.scaleSlider = {
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Scale",
        tooltip = "Set the scale for the bag space window",
        setFunction = function(value)
            BSI.configpanel.scaleValue = value
            BSI.savedvariables.scale = value / 100
            RescaleFloatingWindow()
        end,
        getFunction = function()
            return BSI.configpanel.scaleValue
        end,
        default = IsConsoleUI() and BSIUI.default.console.scale * 100 or BSIUI.default.pc.scale * 100,
        min = 80,
        max = IsConsoleUI() and 130 or 120,
        step = 1,
        unit = "%",
        format = "%d",
        disable = function()
            return BSI.configpanel.disabled
        end
    }

    BSI.configpanel.locationXSlider = {
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Horizontal location",
        tooltip = "Set the left-right location of the window",
        setFunction = function(value)
            BSI.configpanel.locationX = value
            BSI.savedvariables.offsetX = value
            BSIUI.topwindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, BSI.savedvariables.offsetX, BSI.savedvariables.offsetY)
        end,
        getFunction = function()
            return BSI.configpanel.locationX
        end,
        default = IsConsoleUI() and BSIUI.default.console.offsetX or BSIUI.default.pc.offsetX,
        min = 1,
        max = BSIUI.screenwidth,
        step = 2,
        unit = "",
        format = "%d",
        disable = function()
            return BSI.configpanel.disabled
        end
    }

    BSI.configpanel.locationYSlider = {
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Vertical location",
        tooltip = "Set the top-bottom location of the window",
        setFunction = function(value)
            BSI.configpanel.locationY = value
            BSI.savedvariables.offsetY = value
            BSIUI.topwindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, BSI.savedvariables.offsetX, BSI.savedvariables.offsetY)
        end,
        getFunction = function()
            return BSI.configpanel.locationY
        end,
        default = IsConsoleUI() and BSIUI.default.console.offsetY or BSIUI.default.pc.offsetY,
        min = 1,
        max = BSIUI.screenheight,
        step = 2,
        unit = "",
        format = "%d",
        disable = function()
            return BSI.configpanel.disabled
        end
    }


    BSI.configpanel.settings:AddSetting(BSI.configpanel.viewWindow)
    --BSI.configpanel.settings:AddSetting(BSI.configpanel.backgroundSlider)
    BSI.configpanel.settings:AddSetting(BSI.configpanel.scaleSlider)
    if IsConsoleUI() then
        BSI.configpanel.settings:AddSetting(BSI.configpanel.locationXSlider)
        BSI.configpanel.settings:AddSetting(BSI.configpanel.locationYSlider)
    end


end

-- ---------------------------------------------------------------------------
-- Get the current gold and free space
-- ---------------------------------------------------------------------------
local function UpdateBSIData()
    -- h5. CurrencyType
    --   * CURT_MONEY

    -- h5. CurrencyLocation
    --   * CURRENCY_LOCATION_ACCOUNT
    --   * CURRENCY_LOCATION_BANK
    --   * CURRENCY_LOCATION_CHARACTER
    --   * CURRENCY_LOCATION_GUILD_BANK

    -- h5. Bag
    --   * BAG_BACKPACK
    --   * BAG_BANK
    --   * BAG_BUYBACK
    --   * BAG_GUILDBANK
    --   * BAG_SUBSCRIBER_BANK
    --   * BAG_VIRTUAL
    --   * BAG_WORN

    local gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
    local goldfmt = FormatIntegerWithDigitGrouping(gold, ",", 3);

    -- normal bag
    BSI.normal = initializeTable(template_bagdata)
    BSI.normal.bag = BAG_BACKPACK
    BSI.normal.maximum = GetBagSize(BAG_BACKPACK)
    BSI.normal.used = GetNumBagUsedSlots(BAG_BACKPACK)
    BSI.normal.available = GetNumBagFreeSlots(BAG_BACKPACK)
    BSI.normal.usable = GetBagUseableSize(BAG_BACKPACK)

    -- normal bank
    BSI.bank = initializeTable(template_bagdata)
    BSI.bank.bag = BAG_BANK
    BSI.bank.maximum = GetBagSize(BAG_BANK)
    BSI.bank.used = GetNumBagUsedSlots(BAG_BANK)
    BSI.bank.usable = GetBagUseableSize(BAG_BANK)
    BSI.bank.available = BSI.bank.usable - BSI.bank.used

    -- subscriber bank
    BSI.subscriber = initializeTable(template_bagdata)
    BSI.subscriber.bag = BAG_SUBSCRIBER_BANK
    BSI.subscriber.maximum = GetBagSize(BAG_SUBSCRIBER_BANK)
    BSI.subscriber.used = GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
    BSI.subscriber.usable = GetBagUseableSize(BAG_SUBSCRIBER_BANK)
    BSI.subscriber.available = BSI.subscriber.usable - BSI.subscriber.used

    -- total bank
    local bankmax = BSI.bank.maximum + BSI.subscriber.usable
    local bankused = BSI.bank.used + BSI.subscriber.used

    -- default text colors
    local banksizewarning = BSIUI.color.white
    local guildsizewarning = BSIUI.color.white
    local bagsizewarning = BSIUI.color.white

    -- new text colors based on free space remaining
    if (BSI.normal.used == BSI.normal.maximum) then
        bagsizewarning = BSIUI.color.red
    elseif (BSI.normal.used > (BSI.normal.maximum - 5)) then
        bagsizewarning = BSIUI.color.yellow
    end

    if (bankused >= bankmax) then
        banksizewarning = BSIUI.color.red
    elseif (bankused > (bankmax - 5)) then
        banksizewarning = BSIUI.color.yellow
    end

    -- text for the bank/inventory dialog
    local backpack = BSIUI.color.cream .. "Backpack: " .. bagsizewarning .. BSI.normal.used .. " / " .. BSI.normal.maximum .. BSIUI.color.cream
    local playerbank = ",  Bank: " .. banksizewarning .. bankused .. " / " .. bankmax .. BSIUI.color.cream

    -- text for the floating window
    local goldline = BSIUI.color.gold .. goldfmt .. "g"
    local bagline = bagsizewarning .. BSI.normal.used .. " / " .. BSI.normal.maximum
    local bankline = banksizewarning .. bankused .. " / " .. bankmax

    -- save detailed information
    BSI.message = backpack .. playerbank
    BSI.bankfree = backpack .. playerbank
    BSI.invfree = backpack
    BSI.goldamount = gold

    -- save values displayed in floating window
    BSI.floatgold = goldline
    BSI.floatbag = bagline
    BSI.floatbank = bankline

    BSI.updated = 1
end

-- ---------------------------------------------------------------------------
-- Update the labels in the floating UI box
-- ---------------------------------------------------------------------------
local function PostBagInformation()
    UpdateBSIData()

    -- adjust font for rich people
    if (BSI.goldamount < 100000000) then
        BagSpaceIndicatorFloatLabel1:SetFont(IsConsoleUI() and BSIUI.font.conmedium or BSIUI.font.pcmedium)
    else
        BagSpaceIndicatorFloatLabel1:SetFont(IsConsoleUI() and BSIUI.font.consmall or BSIUI.font.pcsmall)
    end

    BagSpaceIndicatorFloatLabel1:SetText(BSI.floatgold)
    BagSpaceIndicatorFloatLabel2:SetText(BSI.floatbag)
    BagSpaceIndicatorFloatLabel3:SetText(BSI.floatbank)

    BSI.updated = 0
end

----------------------------------------------------------------------------------------------------------------------------------------
-- Event handlers
----------------------------------------------------------------------------------------------------------------------------------------

local function BSIOpenBankEvent(eventCode)
    if (BSI.addonready == 0) then
        return
    end
    PostBagInformation()
end

local function BSICloseBankEvent(eventCode)
    if (BSI.addonready == 0) then
        return
    end
    PostBagInformation()
end

local function BSIInventoryEvent(bagId, slotId, isNewItem, itemSoundCategory, updateReason)
    if (BSI.addonready == 0) then
        return
    end
    PostBagInformation()
end

local function BSIItemEvent(eventCode, eventData)
    if (BSI.addonready == 0) then
        return
    end
    PostBagInformation()
end

local function BSIMoneyEvent(eventCode, eventData)
    if (BSI.addonready == 0) then
        return
    end
    PostBagInformation()
end

----------------------------------------------------------------------------------------------------------------------------------------
-- Addon Init
----------------------------------------------------------------------------------------------------------------------------------------

local function LoadAddon(eventCode, addOnName)
    if (addOnName == AddonInfo.addon) then
        BSI.normal = initializeTable(template_bagdata)
        BSI.bank = initializeTable(template_bagdata)
        BSI.subscriber = initializeTable(template_bagdata)

        CalculateDefaultUIValues()

        BSI.savedvariables = ZO_SavedVars:NewCharacterNameSettings(AddonInfo.savename, 1, nil, (IsConsoleUI() and BSIUI.default.console or BSIUI.default.pc))

        -- initialize location
        if not BSI.savedvariables.offsetX then
            BSI.savedvariables.offsetX = IsConsoleUI() and BSIUI.default.console.offsetX or BSIUI.default.pc.offsetX
        end

        if not BSI.savedvariables.offsetY then
            BSI.savedvariables.offsetY = IsConsoleUI() and BSIUI.default.console.offsetY or BSIUI.default.pc.offsetY
        end

        if not BSI.savedvariables.scale then
            BSI.savedvariables.scale = IsConsoleUI() and BSIUI.screenscale * 1.07 or BSIUI.screenscale
        end

        if not BSI.savedvariables.backgroundalpha then
            BSI.savedvariables.backgroundalpha = BSIUI.default.backgroundalpha
        end

        BSI.savedvariables.addonversion = AddonInfo.version

        -- delete old data
        if BSI.savedvariables.ishidden then
            BSI.savedvariables.ishidden = nil
        end

        if BSI.savedvariables.displaywindow then
            BSI.savedvariables.displaywindow = nil
        end

        if LibNorthCastle then
            LibNorthCastle:Register(AddonInfo.addon, AddonInfo.version)
        end

        InitFloatingWindow()
        InitConfigPanel()

        EVENT_MANAGER:UnregisterForEvent(AddonInfo.addon, EVENT_ADD_ON_LOADED)

        BSI.addonready = 1

        PostBagInformation()

    end
end

EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_ADD_ON_LOADED, LoadAddon)

-- every 100ms check to see if window needs to be hidden
--EVENT_MANAGER:RegisterForUpdate("BSIHideCheck", 100, HideCheck)

-- every 110ms check to see if the window needs to be updated
--EVENT_MANAGER:RegisterForUpdate("BSIUpdateCheck", 110, BSIUpdate)

-- intercept gold, bank, and inventory related events
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_OPEN_STORE, BSIOpenBankEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_OPEN_BANK, BSIOpenBankEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_CLOSE_BANK, BSICloseBankEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_OPEN_GUILD_BANK, BSIOpenBankEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_CLOSE_GUILD_BANK, BSICloseBankEvent)

EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_INVENTORY_BAG_CAPACITY_CHANGED, BSIItemEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, BSIInventoryEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_INVENTORY_BOUGHT_BAG_SPACE, BSIItemEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_INVENTORY_ITEM_DESTROYED, BSIItemEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_INVENTORY_ITEM_USED, BSIItemEvent)

EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_MONEY_UPDATE, BSIMoneyEvent)

EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_INVENTORY_BANK_CAPACITY_CHANGED, BSIItemEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_INVENTORY_BOUGHT_BANK_SPACE, BSIItemEvent)

EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_STABLE_INTERACT_END, BSIItemEvent)

EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_GUILD_BANKED_MONEY_UPDATE, BSIOpenBankEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_GUILD_BANK_UPDATED_QUANTITY, BSIOpenBankEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_GUILD_BANK_ITEMS_READY, BSIOpenBankEvent)
EVENT_MANAGER:RegisterForEvent(AddonInfo.addon, EVENT_GUILD_BANK_SELECTED, BSIOpenBankEvent)
