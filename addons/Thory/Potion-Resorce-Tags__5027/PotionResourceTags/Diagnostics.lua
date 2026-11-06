local PRT = PotionResourceTags
PRT.Diagnostics = { pages = {}, page = 1, registeredCommands = {} }
local Diagnostics = PRT.Diagnostics

function Diagnostics.Close()
    if Diagnostics.window then
        Diagnostics.edit:LoseFocus()
        SCENE_MANAGER:HideTopLevel(Diagnostics.window)
    end
end

local function Pack(...)
    return { n = select("#", ...), ... }
end

-- Missing APIs and call errors are recorded, never replaced with guessed values.
local function Read(apiName, ...)
    local fn = _G[apiName]
    if type(fn) ~= "function" then
        return nil, "unavailable: " .. apiName
    end
    local ok, result = pcall(function(...) return Pack(fn(...)) end, ...)
    if not ok then
        return nil, "error: " .. apiName .. ": " .. tostring(result)
    end
    return result
end

local function Value(value)
    if value == nil then
        return "<not-acquired>"
    elseif type(value) == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end

local function AppendRead(lines, apiName, names, ...)
    local result, problem = Read(apiName, ...)
    if not result then
        lines[#lines + 1] = apiName .. "=<not-acquired; " .. problem .. ">"
        return
    end
    for i, name in ipairs(names) do
        lines[#lines + 1] = apiName .. "." .. name .. "=" .. Value(result[i])
    end
end

local ON_USE_NAMES = { "hasAbility", "header", "description", "cooldownMs", "hasScaling",
    "minLevel", "maxLevel", "isChampionPoints", "remainingCooldownMs" }
local TRAIT_NAMES = { "hasAbility", "description", "cooldownMs", "hasScaling",
    "minLevel", "maxLevel", "isChampionPoints" }

local function Header(source)
    local lines = { "Potion Resource Tags diagnostic v3", "source=" .. source,
        "classification=" .. PRT.CLASSIFICATION_STATUS,
        "classificationTextDependency=none; descriptions are diagnostic only",
        "inspectedSourceAPI=" .. PRT.SOURCE_API_VERSION }
    AppendRead(lines, "GetAPIVersion", { "apiVersion" })
    return lines
end

function Diagnostics.Describe(link, source)
    local lines = Header(source)
    -- This is literal text in an edit box, not a chat-rendered hyperlink.
    lines[#lines + 1] = "fullLink=" .. (link or "<not-acquired>")
    local marker, reason = PRT.Classifier.Classify(link)
    lines[#lines + 1] = "classificationResult=" .. (marker or "none")
    lines[#lines + 1] = "classificationReason=" .. reason
    if not link or link == "" then
        lines[#lines + 1] = "item=<not-acquired: empty slot or link>"
        return table.concat(lines, "\n")
    end
    AppendRead(lines, "GetItemLinkName", { "name" }, link)
    AppendRead(lines, "GetItemLinkItemId", { "itemId" }, link)
    local itemId = Read("GetItemLinkItemId", link)
    if itemId and type(itemId[1]) == "number" then
        -- Only the base potion trait, not the full crafted effect combination.
        AppendRead(lines, "GetTraitIdFromBasePotion", { "baseTraitId" }, itemId[1])
    else
        lines[#lines + 1] = "GetTraitIdFromBasePotion=<not-acquired: itemId unavailable>"
    end
    AppendRead(lines, "GetItemLinkIcon", { "icon" }, link)
    AppendRead(lines, "GetItemLinkItemType", { "itemType", "specializedItemType" }, link)

    local parsed = PRT.Classifier.ParseLink(link)
    if parsed then
        lines[#lines + 1] = "itemPayload=" .. parsed.payload
        lines[#lines + 1] = "fieldCount=" .. #parsed.fields
        for i, field in ipairs(parsed.fields) do
            lines[#lines + 1] = "field[" .. i .. "]=" .. field
        end
    else
        lines[#lines + 1] = "itemPayload=<not-acquired: unrecognized link format>"
    end

    lines[#lines + 1] = "effectFieldIndex=21"
    lines[#lines + 1] = "effectValueRaw=" .. Value(parsed and parsed.fields[21])
    local effects, decodeReason = PRT.Classifier.DecodeEffects(link)
    lines[#lines + 1] = "effectDecodeReason=" .. (decodeReason or "decoded")
    if effects then
        lines[#lines + 1] = "effectBytesLowToHigh=" .. table.concat(effects.bytes, ",")
        lines[#lines + 1] = "effectContainsID3=" .. tostring(effects.magicka)
        lines[#lines + 1] = "effectContainsID5=" .. tostring(effects.stamina)
        lines[#lines + 1] = "effectHasHighBit=" .. tostring(effects.hasHighBit)
    end
    lines[#lines + 1] = "effectHighBitPolicy=reject bytes >=128; meaning unverified; no masking"

    AppendRead(lines, "GetItemLinkOnUseAbilityId", { "abilityId" }, link)
    AppendRead(lines, "GetItemLinkOnUseAbilityInfo", ON_USE_NAMES, link)
    local maxTraits, problem = Read("GetMaxTraits")
    if maxTraits and type(maxTraits[1]) == "number" then
        lines[#lines + 1] = "GetMaxTraits=" .. maxTraits[1]
        for i = 1, maxTraits[1] do
            lines[#lines + 1] = "traitIndex=" .. i
            AppendRead(lines, "GetItemLinkTraitOnUseAbilityInfo", TRAIT_NAMES, link, i)
        end
    else
        lines[#lines + 1] = "traitDescriptions=<not-acquired: " .. (problem or "invalid GetMaxTraits result") .. ">"
    end
    lines[#lines + 1] = "traitAbilityIds=<not-acquired: inspected API exposes no per-trait ability ID>"
    return table.concat(lines, "\n")
end

local function MakeButton(parent, suffix, text, x, callback)
    local button = WINDOW_MANAGER:CreateControlFromVirtual("PotionResourceTags_Diagnostic" .. suffix,
        parent, "ZO_DefaultButton")
    button:SetDimensions(115, 30)
    button:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, x, -12)
    button:SetText(text)
    button:SetHandler("OnClicked", callback)
    return button
end

local function EnsureWindow()
    if Diagnostics.window then
        return
    end
    local window = WINDOW_MANAGER:CreateTopLevelWindow("PotionResourceTags_DiagnosticWindow")
    Diagnostics.window = window
    window:SetDimensions(780, 580)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetHidden(true)
    SCENE_MANAGER:RegisterTopLevel(window, true)

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual("PotionResourceTags_DiagnosticBackdrop",
        window, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(window)
    local title = WINDOW_MANAGER:CreateControl("PotionResourceTags_DiagnosticTitle", window, CT_LABEL)
    Diagnostics.title = title
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 16, 10)
    title:SetFont("ZoFontGameOutline")

    local edit = WINDOW_MANAGER:CreateControl("PotionResourceTags_DiagnosticText", window, CT_EDITBOX)
    Diagnostics.edit = edit
    edit:SetAnchor(TOPLEFT, window, TOPLEFT, 16, 42)
    edit:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -16, -60)
    edit:SetFont("ZoFontGame")
    edit:SetColor(1, 1, 1, 1)
    edit:SetMultiLine(true)
    edit:SetAllowMarkupType(ALLOW_MARKUP_TYPE_NONE)
    edit:SetMouseEnabled(true)
    edit:SetEditEnabled(false)
    edit:SetCopyEnabled(true)
    edit:SetSelectAllOnFocus(true)
    window:SetHandler("OnHide", function() edit:LoseFocus() end)
    edit:SetHandler("OnMouseWheel", function(control, delta)
        control:SetTopLineIndex(math.max(1, control:GetTopLineIndex() - delta * 3))
    end)
    edit:SetHandler("OnEscape", Diagnostics.Close)
    MakeButton(window, "Previous", "Previous", 12, function() Diagnostics.ShowPage(Diagnostics.page - 1) end)
    MakeButton(window, "Next", "Next", 134, function() Diagnostics.ShowPage(Diagnostics.page + 1) end)
    MakeButton(window, "Select", "Select all", 256, function() edit:TakeFocus() edit:SelectAll() end)
    MakeButton(window, "Close", "Close", 644, Diagnostics.Close)
end

function Diagnostics.ShowPage(index)
    if #Diagnostics.pages == 0 then
        return
    end
    EnsureWindow()
    Diagnostics.page = math.max(1, math.min(index, #Diagnostics.pages))
    local report = Diagnostics.pages[Diagnostics.page]
    Diagnostics.title:SetText(string.format("Potion Resource Tags %d/%d  -  Select all, Ctrl+C",
        Diagnostics.page, #Diagnostics.pages))
    Diagnostics.edit:SetMaxInputChars(#report + 1)
    Diagnostics.edit:SetText(report)
    Diagnostics.edit:SetCursorPosition(0)
    Diagnostics.edit:SetTopLineIndex(1)
    SCENE_MANAGER:ShowTopLevel(Diagnostics.window)
end

local function ShowReports(pages)
    Diagnostics.pages = pages
    Diagnostics.ShowPage(1)
end

function Diagnostics.ScanBackpack()
    local size, problem = Read("GetBagSize", BAG_BACKPACK)
    if not size or type(size[1]) ~= "number" then
        ShowReports({ table.concat(Header("backpack scan failed"), "\n") .. "\n"
            .. (problem or "invalid bag size") })
        return
    end
    local pages = {}
    for slot = 0, size[1] - 1 do
        local result, linkProblem = Read("GetItemLink", BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
        local link = result and result[1]
        if link and link ~= "" then
            local itemType, typeProblem = Read("GetItemLinkItemType", link)
            if itemType and itemType[1] == ITEMTYPE_POTION then
                pages[#pages + 1] = Diagnostics.Describe(link, "BAG_BACKPACK slot=" .. slot)
            elseif not itemType then
                pages[#pages + 1] = "slot=" .. slot .. "\n" .. typeProblem
            end
        elseif linkProblem then
            pages[#pages + 1] = "slot=" .. slot .. "\n" .. linkProblem
        end
    end
    if #pages == 0 then
        pages[1] = table.concat(Header("BAG_BACKPACK: no potions found"), "\n")
    end
    ShowReports(pages)
end

local function ShowStatus()
    local lines = Header("status")
    lines[#lines + 1] = "diagnosticCommands=" .. table.concat(Diagnostics.registeredCommands, ", ")
    lines[#lines + 1] = "classificationScope=potion type + common icon + field[21] recovery IDs 3/5"
    lines[#lines + 1] = "classificationTargetIcon=" .. PRT.TARGET_ICON
    lines[#lines + 1] = "classificationExclusions=both/neither recovery IDs, invalid link/value, zero value, high-bit bytes"
    lines[#lines + 1] = "classificationLinkPolicy=21 fields; value 1..16777215; zero bytes allowed at any position"
    for _, name in ipairs(PRT.Hooks.installed) do
        lines[#lines + 1] = "hookInstalled=" .. name
    end
    for _, name in ipairs(PRT.Hooks.missing) do
        lines[#lines + 1] = "hookMissing=" .. name
    end
    ShowReports({ table.concat(lines, "\n") })
end

function Diagnostics.Command(text)
    local command, argument = text:match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "scan" then
        Diagnostics.ScanBackpack()
    elseif command == "status" then
        ShowStatus()
    elseif command == "show" then
        Diagnostics.ShowPage(Diagnostics.page)
    elseif command == "next" then
        Diagnostics.ShowPage(Diagnostics.page + 1)
    elseif command == "prev" then
        Diagnostics.ShowPage(Diagnostics.page - 1)
    elseif command == "close" then
        Diagnostics.Close()
    elseif command == "slot" or command == "quickslot" then
        local slot = argument:match("^%d+$") and tonumber(argument)
        local maxSlot = ACTION_BAR_UTILITY_BAR_SIZE
        if command == "slot" then
            local size, problem = Read("GetBagSize", BAG_BACKPACK)
            if not size or type(size[1]) ~= "number" then
                ShowReports({ "GetBagSize=<not-acquired: " .. (problem or "invalid result") .. ">" })
                return
            end
            maxSlot = size[1] - 1
        end
        local minSlot = command == "slot" and 0 or 1
        if not slot or not maxSlot or slot < minSlot or slot > maxSlot then
            d("Potion Resource Tags: invalid slot number")
            return
        end
        local result, problem
        if command == "slot" then
            result, problem = Read("GetItemLink", BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
        else
            result, problem = Read("GetSlotItemLink", slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        end
        local report = Diagnostics.Describe(result and result[1], command .. "=" .. slot)
        if problem then
            report = report .. "\n" .. problem
        end
        ShowReports({ report })
    else
        d("Potion Resource Tags: common potion icon + link recovery IDs 3/5; both/unknown/high-bit bytes excluded. /potionresourcetags scan | slot N | quickslot N | status | show | next | prev | close (/prt if available)")
    end
end

function Diagnostics.Initialize()
    Diagnostics.registeredCommands = {}
    for _, command in ipairs({ "/potionresourcetags", "/prt" }) do
        if SLASH_COMMANDS[command] == nil then
            SLASH_COMMANDS[command] = Diagnostics.Command
        end
        if SLASH_COMMANDS[command] == Diagnostics.Command then
            Diagnostics.registeredCommands[#Diagnostics.registeredCommands + 1] = command
        else
            d("Potion Resource Tags: " .. command .. " already in use; existing command preserved.")
        end
    end
    if SLASH_COMMANDS["/prt"] ~= Diagnostics.Command then
        local command = Diagnostics.registeredCommands[1]
        d(command and ("Potion Resource Tags diagnostics: " .. command)
            or "Potion Resource Tags: no diagnostic command alias available.")
    end
end
