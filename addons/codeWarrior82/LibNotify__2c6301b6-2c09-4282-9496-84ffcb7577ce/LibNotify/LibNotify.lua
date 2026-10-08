local appName = "LibNotify"
local notifyInProgress = false
local colourStartup
local colourSet
local notify1 = false
local notify2 = false
local notify3 = false
local notify4 = false
local abilityIdStore1 = 0
local abilityIdStore2 = 0
local abilityIdStore3 = 0
local abilityIdStore4 = 0
local messageStore1 = ""
local messageStore2 = ""
local messageStore3 = ""
local messageStore4 = ""

LibNotify = {}

LibNotify.savedVariables = {}

LibNotify.defaults = {
playSound = true,
showIcon = true,
textColor = { 0, 1, 0, 1 },
type = "Scrolling",
sound = "DUEL_START",
yAxisBox = 200,
xAxisBox = 1050,
yAxisStatic = 500,
xAxisStatic = 1050,
}

LibNotify.notificationType = {
"Scrolling",
"Static",
}

LibNotify.addons = {
["advancingYokedaTracker"] = true,
["aeriesCryTracker"] = true,
["archdruidTracker"] = true,
["darkConvergenceTracker"] = true,
["essenceThiefTracker"] = true,
["feedingFrenzyTracker"] = true,
["FrenziedMomentumTracker"] = true,
["gorethiefTracker"] = true,
["mechAcuityTracker"] = true,
["rallyingCryTracker"] = true,
["riposteTracker"] = true,
["rushOfAgonyTracker"] = true,
["turningTideTracker"] = true,
["wardTracker"] = true,
["warHornTracker"] = true,
["warmaskTracker"] = true,
["wretchedVitalityTracker"] = true,
["atronachTracker"] = true
}

LibNotify.samples = {
    options = {
        "ACTIVE_SKILL_MORPH_CHOSEN",--
        "SKILL_PURCHASED",--
        "ABILITY_SYNERGY_READY",--
        "ANTIQUITIES_FANFARE_FAILURE",--
        "AVA_GATE_CLOSED",--
        "AVA_GATE_OPENED",--
        "BATTLEGROUND_MATCH_LOST",--
        "BATTLEGROUND_MATCH_WON",--
        "BATTLEGROUND_MEDAL_RECEIVED",--
        "BLACKSMITH_IMPROVE_TOOLTIP_GLOW_SUCCESS",--
        "CHAMPION_POINT_GAINED",--
        "DISPLAY_ANNOUNCEMENT",--
        "DUEL_START",--
        "DUEL_WON",--
        "ELDER_SCROLL_CAPTURED_BY_ALDMERI",--
        "EMPEROR_ABDICATED",--
        "EMPEROR_CORONATED_ALDMERI",--
        "GROUP_ELECTION_REQUESTED",--
        "GROUP_ELECTION_RESULT_WON",--
        "JUSTICE_PICKPOCKET_BONUS",--
        "JUSTICE_STATE_CHANGED",--
        "OBJECTIVE_COMPLETED",--

    },
    names = {
        "Skill Morph Chosen",
        "Skill Purchased",
        "Ability Synergy Ready",
        "Antiquities Failure",
        "AVA Gate Closed",
        "AVA Gate Opened",
        "BG Lost",
        "BG Won",
        "BG Medal Awarded",
        "Blacksmith Success",
        "Champion Point Gained",
        "Display Announcement",
        "Duel Start",
        "Duel Won",
        "Elder Scroll Captured",
        "Emperor Abdicated",
        "Emperor Coronated",
        "Group Vote Request",
        "Group Vote Passed",
        "Pickpocket Bonus",
        "Justice State Changed",
        "Objective Completed",
    },
}

LibNotify.sets = {
    setList = {}, --format: [setId] = totalPieces
}

LibNotify.allGearSlots = {
    0,  -- head
    2,  -- chest
    3,  -- shoulders
    6,  -- waist
    16, -- hands
    8,  -- legs
    9,  -- feet
    1,  -- neck
    11, -- ring1
    12, -- ring2
    4,  --front bar 1
    5,  --front bar 2
    20, --back bar 1
    21, --back bar 2
}

LibNotify.TWO_HANDED_WEAPONS = {
    [WEAPONTYPE_TWO_HANDED_AXE]    = true,
    [WEAPONTYPE_TWO_HANDED_HAMMER] = true,
    [WEAPONTYPE_TWO_HANDED_SWORD]  = true,
    [WEAPONTYPE_BOW]               = true,
    [WEAPONTYPE_FIRE_STAFF]        = true,
    [WEAPONTYPE_FROST_STAFF]       = true,
    [WEAPONTYPE_LIGHTNING_STAFF]   = true,
    [WEAPONTYPE_HEALING_STAFF]     = true,
}

--print message to chat box
local function printMessage(msg)
	local chat = LibChatMessage(appName, "MA")
	chat:Print(msg)
end

-------------------------------------------start check sets

--check add-on validity
local function isAddonValid(name)
    return LibNotify.addons[name]
end

--check what sets are equiped and store results
local function checkCurrentSets()
    --reset for a clean scan
    LibNotify.sets.setList = {}

    for _, slotIndex in ipairs(LibNotify.allGearSlots) do
        local itemLink = GetItemLink(BAG_WORN, slotIndex)

        if itemLink ~= "" then
            local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)

            if hasSet and setId then
                local weight = 1

                --account for 2-handed weapons on front or back bar main-hand slot
                if slotIndex == 4 or slotIndex == 20 then
                    local weaponType = GetItemWeaponType(BAG_WORN, slotIndex)
                    if weaponType and LibNotify.TWO_HANDED_WEAPONS[weaponType] then
                        weight = 2
                    end
                end

                --add to total piece count
                LibNotify.sets.setList[setId] = (LibNotify.sets.setList[setId] or 0) + weight
            end
        end
    end
end

--catch callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)

    checkCurrentSets()
    --2 seconds after sets are checked check for specific set
end

--enable callbacks when an item is equiped or unequiped
local function enableCallbacksGear()
    EVENT_MANAGER:RegisterForEvent("callback", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onEquipmentChanged)
    EVENT_MANAGER:AddFilterForEvent("callback", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
end

--run set check verification when another add-on calls
function LibNotify.getSet(addonName, setId, setCount)

    --if not listed add-on tries to access notify service, quit
    if not isAddonValid(addonName) then printMessage("Restricted Access") return end

    if (LibNotify.sets.setList[setId] or 0) >= setCount then
        return true
    else
        return false
    end
end

-------------------------------------------end check sets

-------------------------------------------start notifications

--play sound effect
local function doSound(audio)
    PlaySound(SOUNDS[audio])
end

--display static notify
local function displayMessageStatic(message)
    libNotifyNotifyStatic:SetText(message)
    zo_callLater(function () libNotifyNotifyStatic:SetText("") notifyInProgress = false if notify1 or notify2 or notify3 or notify4 then LibNotify.doDisplayQue() end end, 1700)
end

--display scrolling notify
local function displayMessageScrolling(message)
    libNotifyBoxNotify6:SetText(message)
    zo_callLater(function () libNotifyBoxNotify6:SetText("") libNotifyBoxNotify5:SetText(message) end, 200)
    zo_callLater(function () libNotifyBoxNotify5:SetText("") libNotifyBoxNotify4:SetText(message) end, 400)
    zo_callLater(function () libNotifyBoxNotify4:SetText("") libNotifyBoxNotify3:SetText(message) end, 600)
    zo_callLater(function () libNotifyBoxNotify3:SetText("") libNotifyBoxNotify2:SetText(message) end, 800)
    zo_callLater(function () libNotifyBoxNotify2:SetText("") libNotifyBoxNotify1:SetText(message) end, 1000)
    zo_callLater(function () libNotifyBoxNotify1:SetText("") notifyInProgress = false zo_callLater(function () if notify1 or notify2 or notify3 or notify4 then LibNotify.doDisplayQue() end end, 200) end, 1700)
end

--display notification function
local function doDisplay()

    notifyInProgress = true

    local picPath
    local iconText
    local abilityIDfinal
    local messageFinal

    if notify1 then
        notify1 = false
        --load first variables
        abilityIDfinal = abilityIdStore1
        messageFinal = messageStore1
    elseif notify2 then
        notify2 = false
        --load second variables
        abilityIDfinal = abilityIdStore2
        messageFinal = messageStore2
    elseif notify3 then
        notify3 = false
        --load third variables
        abilityIDfinal = abilityIdStore3
        messageFinal = messageStore3
    elseif notify4 then
        notify4 = false
        --load fourth variables
        abilityIDfinal = abilityIdStore4
        messageFinal = messageStore4
    end

    --show ability icon at start of notification text or not
    if LibNotify.savedVariables.showIcon then
        picPath = GetAbilityIcon(abilityIDfinal)
        iconText = zo_iconTextFormat(picPath, 50, 50, messageFinal)
    else
        iconText = messageFinal
    end

    --if play sound
    if LibNotify.savedVariables.playSound then doSound(LibNotify.savedVariables.sound) end

    --decide scrolling or static then display notification
    if LibNotify.savedVariables.type == "Scrolling" then
        displayMessageScrolling(iconText)
    elseif LibNotify.savedVariables.type == "Static" then
        displayMessageStatic(iconText)
    end
end

--notification que
function LibNotify.doDisplayQue()

    if not notifyInProgress and notify1 or not notifyInProgress and notify2 or not notifyInProgress and notify3 or not notifyInProgress and notify4 then
        doDisplay()
    else
        zo_callLater(function () LibNotify.doDisplayQue() end, 500)
    end
end

--run notification process when another add-on calls
function LibNotify.notifyForAddonPlease(addonName, abilityID, message)

    --if not listed add-on tries to access notify service, quit
    if not isAddonValid(addonName) then printMessage("Restricted Access") return end

    if not notify1 then
        notify1 = true
        --save first variables
        abilityIdStore1 = abilityID
        messageStore1 = message
    elseif not notify2 then
        notify2 = true
        --save second variables
        abilityIdStore2 = abilityID
        messageStore2 = message
    elseif not notify3 then
        notify3 = true
        --save third variables
        abilityIdStore3 = abilityID
        messageStore3 = message
    elseif not notify4 then
        notify4 = true
        --save fourth variables
        abilityIdStore4 = abilityID
        messageStore4 = message
    end

    --display the message
    LibNotify.doDisplayQue()
end

--when finished moving around screen in options
local function setupTextSlotsBlankStatic()
    libNotifyNotifyStatic:SetText("")
end

--when moving around screen in options
local function setupTextSlotsExampleStatic()
    libNotifyNotifyStatic:SetText("example notify")
end

--when finished moving around screen in options
local function setupTextSlotsBlankBox()
    libNotifyBoxNotify1:SetText("")
    libNotifyBoxNotify2:SetText("")
    libNotifyBoxNotify3:SetText("")
    libNotifyBoxNotify4:SetText("")
    libNotifyBoxNotify5:SetText("")
    libNotifyBoxNotify6:SetText("")
end

--when moving around screen in options
local function setupTextSlotsExampleBox()
    libNotifyBoxNotify1:SetText("End here")
    libNotifyBoxNotify2:SetText("example notify")
    libNotifyBoxNotify3:SetText("example notify")
    libNotifyBoxNotify4:SetText("example notify")
    libNotifyBoxNotify5:SetText("example notify")
    libNotifyBoxNotify6:SetText("Start here")
end

--change scrolling anchor to move text around the screen in options
local function setAnchorBox(x, y)  
    setupTextSlotsExampleBox()
	zo_callLater(function () setupTextSlotsBlankBox() end, 2000)
    libNotifyBox:ClearAnchors()
    libNotifyBox:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change static anchor to move text around the screen in options
local function setAnchorStatic(x, y)  
    setupTextSlotsExampleStatic()
	zo_callLater(function () setupTextSlotsBlankStatic() end, 2000)
    libNotify:ClearAnchors()
    libNotify:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--when add-on first starts
local function setupTextSlots()
    libNotifyBox:SetMovable(true)

    libNotifyBoxNotify1:SetColor(0, 255, 0, 255)
    libNotifyBoxNotify1:SetFont("$(GAMEPAD_LIGHT_FONT)|$(GP_54)|soft-shadow-thick")
    libNotifyBoxNotify1:SetText("")

    libNotifyBoxNotify2:SetColor(0, 255, 0, 255)
    libNotifyBoxNotify2:SetFont("$(GAMEPAD_LIGHT_FONT)|$(GP_54)|soft-shadow-thick")
    libNotifyBoxNotify2:SetText("")

    libNotifyBoxNotify3:SetColor(0, 255, 0, 255)
    libNotifyBoxNotify3:SetFont("$(GAMEPAD_LIGHT_FONT)|$(GP_54)|soft-shadow-thick")
    libNotifyBoxNotify3:SetText("")

    libNotifyBoxNotify4:SetColor(0, 255, 0, 255)
    libNotifyBoxNotify4:SetFont("$(GAMEPAD_LIGHT_FONT)|$(GP_54)|soft-shadow-thick")
    libNotifyBoxNotify4:SetText("")

    libNotifyBoxNotify5:SetColor(0, 255, 0, 255)
    libNotifyBoxNotify5:SetFont("$(GAMEPAD_LIGHT_FONT)|$(GP_54)|soft-shadow-thick")
    libNotifyBoxNotify5:SetText("")

    libNotifyBoxNotify6:SetColor(0, 255, 0, 255)
    libNotifyBoxNotify6:SetFont("$(GAMEPAD_LIGHT_FONT)|$(GP_54)|soft-shadow-thick")
    libNotifyBoxNotify6:SetText("")

    --static notify
    libNotify:SetMovable(true)

    libNotifyNotifyStatic:SetColor(colourStartup:UnpackRGBA())
    libNotifyNotifyStatic:SetFont("$(GAMEPAD_LIGHT_FONT)|$(GP_54)|soft-shadow-thick")
    libNotifyNotifyStatic:SetText("")
end

--set anchors for scrolling notification at start up
local function setAnchorStartupBox(x, y)  
    libNotifyBox:ClearAnchors()
    libNotifyBox:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--set anchors for static notification at start up
local function setAnchorStartupStatic(x, y)  
    libNotify:ClearAnchors()
    libNotify:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

-------------------------------------------end notifications

--setup options menu
local function createOptions()

    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "LibNotify",
        displayName = "LibNotify",
        author = "codewarrior82",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            title = "Add-On Settings",
            width = "full",
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Notification Type",
            tooltip = "Choose between a static notification and a scrolling notification.",
            choices = LibNotify.notificationType,
            getFunc = function() return LibNotify.savedVariables.type end,
            setFunc = function(var) LibNotify.savedVariables.type = var end,
        },
        {
            type = "slider",
            name = "Scrolling x Position",
            tooltip = "Adjust the left and right position of the on screen Scrolling notification.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return LibNotify.savedVariables.xAxisBox
            end,
            setFunc = function(value)
                LibNotify.savedVariables.xAxisBox = value
                setAnchorBox(LibNotify.savedVariables.xAxisBox, LibNotify.savedVariables.yAxisBox)
            end,
            default = LibNotify.defaults.xAxisBox,
        },
        {
            type = "slider",
            name = "Scrolling y Position",
            tooltip = "Adjust the left and right position of the on screen Scrolling notification.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return LibNotify.savedVariables.yAxisBox
            end,
            setFunc = function(value)
                LibNotify.savedVariables.yAxisBox = value
                setAnchorBox(LibNotify.savedVariables.xAxisBox, LibNotify.savedVariables.yAxisBox)
            end,
            default = LibNotify.defaults.yAxisBox,
        },
        {
            type = "slider",
            name = "Static x Position",
            tooltip = "Adjust the left and right position of the on screen Static notification.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return LibNotify.savedVariables.xAxisStatic
            end,
            setFunc = function(value)
                LibNotify.savedVariables.xAxisStatic = value
                setAnchorStatic(LibNotify.savedVariables.xAxisStatic, LibNotify.savedVariables.yAxisStatic)
            end,
            default = LibNotify.defaults.xAxisStatic,
        },
        {
            type = "slider",
            name = "Static y Position",
            tooltip = "Adjust the left and right position of the on screen Static notification.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return LibNotify.savedVariables.yAxisStatic
            end,
            setFunc = function(value)
                LibNotify.savedVariables.yAxisStatic = value
                setAnchorStatic(LibNotify.savedVariables.xAxisStatic, LibNotify.savedVariables.yAxisStatic)
            end,
            default = LibNotify.defaults.yAxisStatic,
        },
        {
            type = "colorpicker",
            name = "Text colour",
            tooltip = "Change the colour of the notification text.",
            default = ZO_ColorDef:New(unpack(LibNotify.defaults.textColor)),
            getFunc = function ()
                return unpack(LibNotify.savedVariables.textColor)
            end,
            setFunc = function (r, g, b, a)
                LibNotify.savedVariables.textColor = { r, g, b, a }
                colourSet = ZO_ColorDef:New(unpack(LibNotify.savedVariables.textColor))
                libNotifyNotifyStatic:SetColor(colourSet:UnpackRGBA())
            end,
        },
        {
            type = "button",
            name = "Test Colour",
            tooltip = "Show a short notification with the new colour you have set.",
            func = function()
                libNotifyNotifyStatic:SetText("Notification")
                zo_callLater(function () libNotifyNotifyStatic:SetText("") end, 2000)
             end,
        },
        {
            type = "checkbox",
            name = "Show Icon",
            tooltip = "Shows the icon of the buff that you are being notified about at the start of the notification.",
            getFunc = function()
                return LibNotify.savedVariables.showIcon
            end,
            setFunc = function(value)
                LibNotify.savedVariables.showIcon = value
            end,
            default = LibNotify.defaults.showIcon,
        },
        {
            type = "checkbox",
            name = "Play Sound",
            tooltip = "Plays audio when the notification starts.",
            getFunc = function()
                return LibNotify.savedVariables.playSound
            end,
            setFunc = function(value)
                LibNotify.savedVariables.playSound = value
            end,
            default = LibNotify.defaults.playSound,
        },
        {
            type = "dropdown",
            name = "Sound Type",
            tooltip = "Choose the audio sample to play at the start of each notification.",
            choices = LibNotify.samples.names,
            choicesValues = LibNotify.samples.options,
            getFunc = function() return LibNotify.savedVariables.sound end,
            setFunc = function(value) LibNotify.savedVariables.sound = value end,
            sort = "name-up",
            width = "full",
            scrollable = true,
        },
        {
            type = "button",
            name = "Test Sound",
            tooltip = "Play audio with the sound you have set.",
            func = function()
                doSound(LibNotify.savedVariables.sound)
             end,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("LibNotify", panelData)
    LAM:RegisterOptionControls("LibNotify", optionsData)
end

--add-on loaded
local function libLoaded(event, name)
    --if add-on loaded was not this add-on quit
    if name ~= appName then return end
    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)
    --load saved variables
    LibNotify.savedVariables = ZO_SavedVars:NewCharacterIdSettings("libNotifyAddonVars", 1, "Settings", LibNotify.defaults, GetUnitName("player"))
    --load saved var colour for text
    colourStartup = ZO_ColorDef:New(unpack(LibNotify.savedVariables.textColor))

    --set anchor points of notification locations from saved vars at start up
    setAnchorStartupBox(LibNotify.savedVariables.xAxisBox, LibNotify.savedVariables.yAxisBox)
    setAnchorStartupStatic(LibNotify.savedVariables.xAxisStatic, LibNotify.savedVariables.yAxisStatic)
    --setup each text slot
    setupTextSlots()
    --setup options menu
    createOptions()
    --register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()
    --check what sets are currently equiped
    checkCurrentSets()
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, libLoaded)


--example of message from other addon, 
--LibNotify.notifyForAddonPlease(appName, abilityID, "message here")

--example of message from other addon,
--LibNotify.getSet(appName, setId, setCount)