local ADDON = "KMailMaterials"
local SV = nil
local MAX_ATT     = MAIL_MAX_ATTACHED_ITEMS or 6
local MAX_SUBJECT = MAIL_MAX_SUBJECT_CHARACTERS or 50
local running          = false
local currentMode      = nil
local currentRecipient = nil
local sent             = 0
local buttonControls   = {}
local ICON_PATH = "EsoUI/Art/Inventory/inventory_tabIcon_%s_%s.dds"
local NAME_KEYWORDS = {"design", "diagram", "formula", "blueprint", "pattern",    "praxis", "motif", "style", "recipe", "unidentified"}

local function say(msg)
    if SV and SV.showMessages == false then return end
    d("|c66ccff[KMailMaterials]|r " .. msg)
end

local function alert(msg)
    say(msg)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, msg)
end

local function isMaterial(bagId, slotIndex)
    local f1, f2, f3, f4 = GetItemFilterTypeInfo(bagId, slotIndex)
    return f1 == ITEMFILTERTYPE_CRAFTING or f2 == ITEMFILTERTYPE_CRAFTING or f3 == ITEMFILTERTYPE_CRAFTING or f4 == ITEMFILTERTYPE_CRAFTING
end

local function nameMatches(bagId, slotIndex)
    local name = zo_strlower(zo_strformat("<<1>>", GetItemName(bagId, slotIndex)))
    if name == "" then return false end
    for _, kw in ipairs(NAME_KEYWORDS) do
        if string.find(name, kw, 1, true) then return true end
    end
    return false
end

local MODES = {
    materials = {
        subject = "Materials",
        label = "materials", match = isMaterial,
        button = "KMailMaterialsButtonMats", icon = "crafting",
        tip = "AutoSend:\nAll Materials from Materials tab\nRight-click: options",
    },
    recipes = {
        subject = "Recipes",
        label = "recipes/plans/styles", match = nameMatches,
        button = "KMailMaterialsButtonRecipes", icon = "consumables",
        tip = "AutoSend:\nDesign, Diagram, Formula, Blueprint, Pattern,\nPraxis, Motif, Style, Recipes, unidentified box\nRight-click: options",
    },
}
local MODE_ORDER = { "materials", "recipes" }

local function getRecipient()
    local r = zo_strtrim(SV.recipient or "")
    if r == "" then return nil end
    if r:sub(1, 1) ~= "@" then r = "@" .. r end
    return r
end

local function isSelf(name)
    return zo_strlower(name) == zo_strlower(GetDisplayName())
end

local function fillTo(recipient)
    if ZO_MailSendToField and ZO_MailSendToField.SetText then
        ZO_MailSendToField:SetText(recipient)
    end
end

local function collectCandidates(limit, matchFn)
    local list = {}
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if #list >= limit then break end
        if GetSlotStackSize(BAG_BACKPACK, slotIndex) > 0
            and matchFn(BAG_BACKPACK, slotIndex)
            and CanQueueItemAttachment(BAG_BACKPACK, slotIndex, 1) then
            list[#list + 1] = slotIndex
        end
    end
    return list
end

local function updateButtons()
    for key, ctrl in pairs(buttonControls) do
        local active = running and currentMode == key
        ctrl:SetNormalTexture(string.format(ICON_PATH, MODES[key].icon, active and "down" or "up"))
    end
end

local function stop(reason)
    running = false
    currentMode = nil
    updateButtons()
    if reason then say(reason) end
end

local function sendBatch()
    if not running then return end
    ClearQueuedMail()
    local mode = MODES[currentMode]
    local slots = collectCandidates(MAX_ATT, mode.match)
    if #slots == 0 then
        if sent > 0 then
            stop(string.format("Done. %d mail(s) sent.", sent))
        else
            stop("No " .. mode.label .. " to send.")
        end
        return
    end

    for i, slotIndex in ipairs(slots) do
        QueueItemAttachment(BAG_BACKPACK, slotIndex, i)
    end

    zo_callLater(function()
        if not running then return end
        fillTo(currentRecipient)
        SendMail(currentRecipient, MODES[currentMode].subject, "")
    end, 400)
end

local function onSendSuccess()
    if not running then return end
    sent = sent + 1
    zo_callLater(sendBatch, 600)
end

local function onSendFailed(_, reason)
    if not running then return end
    stop("Send failed (code " .. tostring(reason) .. "). Stopped.")
end

local start

local function askRecipient(modeKey)
    local current = getRecipient() or "none"
    ZO_Dialogs_ShowDialog("KMAILMATERIALS_RECIPIENT", { modeKey = modeKey }, { mainTextParams = { current } })
end

function start(modeKey)
    if running then return end
    if SCENE_MANAGER:GetCurrentSceneName() ~= "mailSend" then
        say("Open the mail window (Send tab) first.")
        return
    end

    local recipient = getRecipient()
    if not recipient or isSelf(recipient) then
        askRecipient(modeKey)
        return
    end

    running = true
    currentMode = modeKey
    currentRecipient = recipient
    sent = 0
    updateButtons()
    say("Sending " .. MODES[modeKey].label .. " to " .. recipient .. "...")
    sendBatch()
end

local function registerDialog()
    ZO_Dialogs_RegisterCustomDialog("KMAILMATERIALS_RECIPIENT", {
        title = { text = "KMailMaterials" },
        mainText = { text = "Account that will receive the mails (e.g. @AccountName).\nCurrent: <<1>>" },
        editBox = { defaultText = "@AccountName" },
        buttons = {
            {
                requiresTextInput = true,
                text = SI_DIALOG_ACCEPT,
                callback = function(dialog)
                    local r = zo_strtrim(ZO_Dialogs_GetEditBoxText(dialog) or "")
                    if r == "" then return end
                    if r:sub(1, 1) ~= "@" then r = "@" .. r end
                    if isSelf(r) then alert("That is your own account. ESO does not allow sending mail to yourself.") return end
                    SV.recipient = r
                    local modeKey = dialog.data and dialog.data.modeKey
                    if modeKey then start(modeKey) end
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })
end

local BTN_SIZE = 64

local function showContextMenu(anchor)
    ClearMenu()
    AddMenuItem("Change TO: " .. (getRecipient() or "not set"), function()
        askRecipient(nil)
    end)
    AddMenuItem("Chat messages: " .. (SV.showMessages and "ON (click to disable)" or "OFF (click to enable)"), function()
        SV.showMessages = not SV.showMessages
        d("|c66ccff[KMailMaterials]|r Chat messages " .. (SV.showMessages and "enabled." or "disabled."))
    end)
    ShowMenu(anchor)
end

local function createButtons()
    for i, key in ipairs(MODE_ORDER) do
        local mode = MODES[key]
        local btn = WINDOW_MANAGER:CreateControl(mode.button, ZO_MailSend, CT_BUTTON)
        btn:SetDimensions(BTN_SIZE, BTN_SIZE)
        btn:SetAnchor(BOTTOMLEFT, ZO_MailSend, BOTTOMLEFT, (i - 1) * BTN_SIZE + (i == 1 and 6 or 0), 80)
        btn:SetNormalTexture(string.format(ICON_PATH, mode.icon, "up"))
        btn:SetMouseOverTexture(string.format(ICON_PATH, mode.icon, "over"))
        btn:SetPressedTexture(string.format(ICON_PATH, mode.icon, "down"))

        btn:EnableMouseButton(MOUSE_BUTTON_INDEX_RIGHT, true)
        btn:SetHandler("OnClicked", function(_, button)
            if button == MOUSE_BUTTON_INDEX_RIGHT then
                if not running then showContextMenu(btn) end
            elseif running then
                stop("Cancelled.")
            else
                start(key)
            end
        end)
        btn:SetHandler("OnMouseEnter", function(ctrl)
            InitializeTooltip(InformationTooltip, ctrl, TOP, 0, -5)
            local tip = (running and currentMode == key) and "Click to cancel" or mode.tip
            SetTooltipText(InformationTooltip, tip)
        end)
        btn:SetHandler("OnMouseExit", function()
            ClearTooltip(InformationTooltip)
        end)

        buttonControls[key] = btn
    end
end

local function onLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    SV = ZO_SavedVars:NewAccountWide("KMailMaterialsSV", 1, GetWorldName(), {recipient    = "", showMessages = true })
    registerDialog()
    createButtons()
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_MAIL_SEND_SUCCESS, onSendSuccess)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_MAIL_SEND_FAILED, onSendFailed)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_MAIL_CLOSE_MAILBOX, function() stop() end)
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, onLoaded)
