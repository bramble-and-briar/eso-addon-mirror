local ADDON = "GrilloCraftBank"
local DIALOG = "GRILLO_CRAFT_BANK_CONFIRM"
local materialGroups = {
    { key = "base", label = "Materiales de nivel inicial", ids = { 5413, 811, 794, 803, 135138 } },
    { key = "champion", label = "Materiales de CP 150-160", ids = { 64489, 64504, 64506, 135146 } },
    { key = "rubyAsh", label = "Fresno rubí lijado (CP 150-160)", ids = { 64502 } },
    { key = "provisioning", label = "Ingredientes de cocina" },
    { key = "alchemy", label = "Reactivos y solventes de alquimia" },
    { key = "potency", label = "Runas de potencia de rango 1" },
    { key = "essence", label = "Runas de esencia" },
    { key = "aspect", label = "Runas de aspecto moradas y doradas" },
    { key = "epic", label = "Mejoras moradas" },
    { key = "legendary", label = "Mejoras doradas" },
}
local groupById = {}
local defaultSettings = { reserveIndex = 1 }
for _, group in ipairs(materialGroups) do
    defaultSettings[group.key] = true
    for _, id in ipairs(group.ids or {}) do
        groupById[id] = group.key
    end
end

local reserves = { false, 5000, 10000, 25000, 50000, 100000, 0 }
local settings, scene, bankKeybind
local keybindAttached = false
local session = 0
local busy, uncertain = false, false
local notice

local function InPersonalBank()
    return scene and scene:IsShowing() and IsBankOpen() and GetBankingBag() == BAG_BANK
        and not IsGuildBankOpen()
end

local function Report(message)
    notice = message
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Grillo Craft Bank: " .. message)
end

local function RefreshKeybind()
    if keybindAttached then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(bankKeybind)
    end
end

local function Stack(bag, slot)
    local count = GetSlotStackSize(bag, slot)
    if count == 0 then return nil end
    local id = GetItemUniqueId(bag, slot)
    return { count = count, link = GetItemLink(bag, slot), uid = id and Id64ToString(id) }
end

local function SameStack(a, b)
    if not a or not b then return a == b end
    return a.count == b.count and a.link == b.link and a.uid == b.uid
end

local function CraftingGroup(slot)
    local itemType = GetItemType(BAG_BACKPACK, slot)
    if itemType == ITEMTYPE_INGREDIENT then
        return "provisioning"
    elseif itemType == ITEMTYPE_REAGENT or itemType == ITEMTYPE_POTION_BASE or itemType == ITEMTYPE_POISON_BASE then
        return "alchemy"
    elseif itemType == ITEMTYPE_ENCHANTING_RUNE_POTENCY then
        local _, _, _, rank = GetItemCraftingInfo(BAG_BACKPACK, slot)
        if rank == 1 then return "potency" end
    elseif itemType == ITEMTYPE_ENCHANTING_RUNE_ESSENCE then
        return "essence"
    elseif itemType == ITEMTYPE_ENCHANTING_RUNE_ASPECT then
        local quality = GetItemDisplayQuality(BAG_BACKPACK, slot)
        if quality == ITEM_DISPLAY_QUALITY_ARTIFACT or quality == ITEM_DISPLAY_QUALITY_LEGENDARY then
            return "aspect"
        end
    elseif itemType == ITEMTYPE_BLACKSMITHING_BOOSTER or itemType == ITEMTYPE_CLOTHIER_BOOSTER
        or itemType == ITEMTYPE_WOODWORKING_BOOSTER or itemType == ITEMTYPE_JEWELRYCRAFTING_BOOSTER then
        local quality = GetItemDisplayQuality(BAG_BACKPACK, slot)
        if quality == ITEM_DISPLAY_QUALITY_ARTIFACT then
            return "epic"
        elseif quality == ITEM_DISPLAY_QUALITY_LEGENDARY then
            return "legendary"
        end
    end
end

local function MaterialId(slot)
    if not HasItemInSlot(BAG_BACKPACK, slot) or IsItemStolen(BAG_BACKPACK, slot)
        or IsItemPlayerLocked(BAG_BACKPACK, slot) then return nil end
    local id = GetItemId(BAG_BACKPACK, slot)
    local group = groupById[id] or CraftingGroup(slot)
    if group and settings[group] then return id, group end
end

local function ScanMaterials()
    local queue, totals = {}, {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local id, group = MaterialId(slot)
        if id then
            local stack = Stack(BAG_BACKPACK, slot)
            if stack then
                queue[#queue + 1] = { slot = slot, id = id, stack = stack }
                totals[group] = (totals[group] or 0) + stack.count
            end
        end
    end
    return queue, totals
end

local function Destination(stack)
    local empty
    for slot = 0, GetBagSize(BAG_BANK) - 1 do
        local count, maximum = GetSlotStackSize(BAG_BANK, slot)
        if count == 0 then
            empty = empty or slot
        elseif count < maximum and GetItemLink(BAG_BANK, slot) == stack.link then
            return slot, math.min(maximum - count, stack.count)
        end
    end
    return empty, stack.count
end

local function Invoker(name)
    if IsPrivateFunction(name) then return nil end
    if IsProtectedFunction(name) then
        if type(CallSecureProtected) ~= "function" then return nil end
        return function(...)
            return CallSecureProtected(name, ...)
        end
    end
    if type(_G[name]) == "function" then return _G[name] end
end

local function Wallet(location)
    return GetCurrencyAmount(CURT_MONEY, location)
end

local function GoldPlan(reserve)
    if reserve == false then return 0, 0 end
    local excess = math.max(0, Wallet(CURRENCY_LOCATION_CHARACTER) - reserve)
    local maximum = GetMaxCurrencyTransfer(CURT_MONEY, CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_BANK)
    return excess, math.min(excess, maximum)
end

local function Finish(message, unconfirmed)
    busy = false
    uncertain = unconfirmed or false
    RefreshKeybind()
    Report(message)
end

-- A request is counted only after the inventory or currency state confirms it.
local function Await(token, check, advance, timeout)
    local started = GetFrameTimeMilliseconds()
    local function Poll()
        if token ~= session or not InPersonalBank() then return end
        if check() then
            advance()
        elseif GetFrameTimeMilliseconds() - started >= 4500 then
            Finish(timeout, true)
        else
            zo_callLater(Poll, 120)
        end
    end
    zo_callLater(Poll, 120)
end

local function Deposit(plan)
    if plan.session ~= session or not InPersonalBank() or busy or uncertain then return end
    busy = true
    RefreshKeybind()

    local move = Invoker("RequestMoveItem")
    local transfer = Invoker("TransferCurrency")
    local goldMoved, materialsMoved = 0, 0
    local cursor = 1
    local reasons = {}

    local function NextMaterial()
        if plan.session ~= session or not InPersonalBank() then return end
        if move then
            while cursor <= #plan.queue do
                local entry = plan.queue[cursor]
                if entry.id == MaterialId(entry.slot)
                    and SameStack(entry.stack, Stack(BAG_BACKPACK, entry.slot)) then
                    local target, amount = Destination(entry.stack)
                    if target then
                        local bankCount = GetSlotStackSize(BAG_BANK, target)
                        local ok, accepted = pcall(move, BAG_BACKPACK, entry.slot, BAG_BANK, target, amount)
                        if not ok or accepted == false then
                            reasons[#reasons + 1] = "Traslado rechazado por ESO."
                            break
                        end

                        local remaining = entry.stack.count - amount
                        Await(plan.session, function()
                            local source = Stack(BAG_BACKPACK, entry.slot)
                            local bank = Stack(BAG_BANK, target)
                            local sourceMatches = (remaining == 0 and source == nil)
                                or (source and source.count == remaining
                                    and source.uid == entry.stack.uid and source.link == entry.stack.link)
                            return sourceMatches and bank and bank.count == bankCount + amount
                                and bank.link == entry.stack.link
                        end, function()
                            materialsMoved = materialsMoved + amount
                            if remaining == 0 then
                                cursor = cursor + 1
                            else
                                entry.stack.count = remaining
                            end
                            NextMaterial()
                        end, "Movimiento sin confirmar. Abre Grillo para revisar los materiales pendientes.")
                        return
                    end
                    if not reasons.full then
                        reasons.full = true
                        reasons[#reasons + 1] = "Banco sin espacio para algunos materiales."
                    end
                end
                cursor = cursor + 1
            end
        elseif #plan.queue > 0 then
            reasons[#reasons + 1] = "Traslado de materiales no disponible."
        end
        local pending = ScanMaterials()
        if #pending > 0 then reasons[#reasons + 1] = "Consulta Grillo para el depósito manual." end
        local summary = string.format("Confirmado: %d materiales y %d de oro.", materialsMoved, goldMoved)
        Finish(summary .. " " .. table.concat(reasons, " "))
    end

    if plan.gold > 0 then
        local _, currentGold = GoldPlan(plan.reserve)
        local amount = math.min(plan.gold, currentGold)
        if transfer and amount > 0 then
            local character = Wallet(CURRENCY_LOCATION_CHARACTER)
            local bank = Wallet(CURRENCY_LOCATION_BANK)
            local ok, accepted = pcall(transfer, CURT_MONEY, amount, CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_BANK)
            if ok and accepted ~= false then
                Await(plan.session, function()
                    return Wallet(CURRENCY_LOCATION_CHARACTER) == character - amount
                        and Wallet(CURRENCY_LOCATION_BANK) == bank + amount
                end, function()
                    goldMoved = amount
                    NextMaterial()
                end, "Oro sin confirmar. Revisa el saldo y los materiales desde el menú del banco.")
                return
            end
            reasons[#reasons + 1] = "ESO rechazó el oro. Usa Depositar moneda."
        elseif not transfer then
            reasons[#reasons + 1] = "Para el oro, usa Depositar moneda."
        end
    end
    NextMaterial()
end

local function ShowPlan()
    if not InPersonalBank() or busy then return end
    local queue, totals = ScanMaterials()
    local reserve = reserves[settings.reserveIndex]
    local excess, gold = GoldPlan(reserve)
    local lines = {}
    if notice then lines[#lines + 1] = notice end
    for _, group in ipairs(materialGroups) do
        local count = totals[group.key]
        if count then lines[#lines + 1] = string.format("%s x %d", group.label, count) end
    end
    if #queue == 0 then lines[#lines + 1] = "Sin materiales seleccionados en la mochila." end
    if reserve == false then
        lines[#lines + 1] = "Depósito de oro desactivado."
    else
        lines[#lines + 1] = string.format("Reserva: %d | Oro a depositar: %d", reserve, gold)
        if gold < excess then lines[#lines + 1] = "El banco limita la cantidad de oro transferible." end
    end
    if uncertain then
        lines[#lines + 1] = "Revisa el saldo. Puedes terminar desde el menú normal del banco."
    end
    ZO_Dialogs_ShowGamepadDialog(DIALOG, {
        session = session, queue = queue, reserve = reserve, gold = gold,
        text = table.concat(lines, "\n"),
    })
end

bankKeybind = {
    alignment = KEYBIND_STRIP_ALIGN_RIGHT,
    {
        name = "Grillo Craft Bank",
        keybind = "UI_SHORTCUT_QUATERNARY",
        visible = function() return InPersonalBank() and not busy end,
        callback = ShowPlan,
    },
}

local function ResetSession()
    session = session + 1
    busy, uncertain, notice = false, false, nil
end

local function RegisterSettings()
    local library = LibHarvensAddonSettings
    if not library then return end
    local panel = library:AddAddon("Grillo Craft Bank")
    if not panel then return end
    for _, group in ipairs(materialGroups) do
        local key = group.key
        panel:AddSetting({
            type = library.ST_CHECKBOX,
            label = group.label,
            getFunction = function() return settings[key] end,
            setFunction = function(enabled) settings[key] = enabled end,
        })
    end

    local options, indexByName = {}, {}
    for index, reserve in ipairs(reserves) do
        local name = reserve == false and "Desactivado" or string.format("%d de oro", reserve)
        options[index] = { name = name, data = index }
        indexByName[name] = index
    end
    panel:AddSetting({
        type = library.ST_DROPDOWN,
        label = "Reserva de oro",
        tooltip = "Solo se deposita el oro que excede la reserva. Con 0 se ofrece depositar todo el saldo transferible.",
        items = options,
        getFunction = function() return options[settings.reserveIndex].name end,
        setFunction = function(_, name)
            local index = indexByName[name]
            if index then settings.reserveIndex = index end
        end,
    })
end

local function SetupBank(_, addonName)
    if addonName ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    settings = ZO_SavedVars:NewCharacterIdSettings("GrilloCraftBankSavedVars", 1, nil, defaultSettings)
    if reserves[settings.reserveIndex] == nil then settings.reserveIndex = 1 end
    RegisterSettings()

    scene = SCENE_MANAGER:GetScene("gamepad_banking")
    if not scene then return end

    ZO_Dialogs_RegisterCustomDialog(DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Grillo Craft Bank" },
        mainText = { text = function(dialog) return dialog.data.text end },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = "Depositar",
                enabled = function(dialog)
                    return not uncertain and (dialog.data.gold > 0 or #dialog.data.queue > 0)
                end,
                callback = function(dialog) Deposit(dialog.data) end,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = "Cambiar reserva",
                callback = function(dialog)
                    if dialog.data.session == session and InPersonalBank() then
                        settings.reserveIndex = settings.reserveIndex % #reserves + 1
                        local reserve = reserves[settings.reserveIndex]
                        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,
                            reserve == false and "Grillo: oro desactivado."
                                or string.format("Grillo: reserva de %d de oro.", reserve))
                    end
                end,
            },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL },
        },
    })

    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWN then
            KEYBIND_STRIP:AddKeybindButtonGroup(bankKeybind)
            keybindAttached = true
        elseif newState == SCENE_HIDING then
            keybindAttached = false
            KEYBIND_STRIP:RemoveKeybindButtonGroup(bankKeybind)
            ResetSession()
        end
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_OPEN_BANK, function()
        ResetSession()
        RefreshKeybind()
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_CLOSE_BANK, ResetSession)
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, SetupBank)

