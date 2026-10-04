local R = Relais
local BANK_DIALOG = "RELAIS_BANK_GAMEPAD"
local ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds"
local TIMEOUT_MS = 15000

local function UID(bag, slot)
    return Id64ToString(GetItemUniqueId(bag, slot))
end

local function Find(bag, uid)
    for slot = 0, GetBagSize(bag) - 1 do
        if UID(bag, slot) == uid then return { bag = bag, slot = slot } end
    end
end

local function BankingBags()
    if not IsBankOpen() then return nil, "Ouvre ta banque personnelle pour utiliser cette action." end
    local bag = GetBankingBag()
    if bag ~= BAG_BANK and bag ~= BAG_SUBSCRIBER_BANK then
        return nil, "Cette action utilise la banque personnelle, pas un coffre de maison ou de guilde."
    end
    local bags = { BAG_BANK }
    -- Native banking allows withdrawal of existing subscriber-bank items after subscription expiry.
    if BAG_SUBSCRIBER_BANK then bags[#bags + 1] = BAG_SUBSCRIBER_BANK end
    return bags
end

local function DepositBags()
    local bags = { BAG_BANK }
    if BAG_SUBSCRIBER_BANK and IsESOPlusSubscriber() then bags[#bags + 1] = BAG_SUBSCRIBER_BANK end
    return bags
end

local function FindBank(bags, uid)
    for _, bag in ipairs(bags) do
        local item = Find(bag, uid)
        if item then return item end
    end
end

local function EmptyDestination(bags, source)
    for _, bag in ipairs(bags) do
        local slot = FindFirstEmptySlotInBag(bag)
        if slot ~= nil and DoesBagHaveSpaceFor(bag, source.bag, source.slot) then return bag, slot end
    end
end

local function Status(message, id)
    R.statusMessage, R.statusProfileId = message, id
    if R.bankKeybindGroup then KEYBIND_STRIP:UpdateKeybindButtonGroup(R.bankKeybindGroup) end
    R:RefreshUI()
end

local function Finish(message, failed)
    local transfer = R.bankTransfer
    R.bankTransfer = nil
    if failed and R.db.settings.automatic then
        R.db.settings.automatic = false
        R:SavedDataChanged()
    end
    Status(message, transfer and transfer.id)
    R:Notify(message)
end

function R:CancelBankTransfer()
    if not self.bankTransfer then return false end
    self.bankTransfer.cancelled = true
    if not self.bankTransfer.operation then Finish("Transfert bancaire arrêté. Les pièces déjà déplacées restent à leur place.")
    else Status("Arrêt demandé : attente de la pièce déjà envoyée à la banque.", self.bankTransfer.id) end
    return true
end

function R:StartBankTransfer(id, direction)
    local profile = self.db.profiles[id]
    if not profile or type(profile.gear) ~= "table" then self:Notify("Équipement enregistré introuvable."); return false end
    if direction ~= "withdraw" and direction ~= "deposit" then return false end
    if self.bankTransfer or self.engine:IsBusy() then self:Notify("Attends la fin de l'action en cours."); return false end
    if not IsPlayerActivated() or IsUnitDeadOrReincarnating("player") or IsUnitInCombat("player") then
        self:Notify("Utilise la banque hors combat, avec le personnage vivant."); return false
    end
    local banks, problem = BankingBags()
    if not banks then self:Notify(problem); return false end
    local depositBags = DepositBags()
    local uids, seen, missing = {}, {}, {}
    for _, saved in pairs(profile.gear) do
        if type(saved) ~= "table" or type(saved.uid) ~= "string" then self:Notify("Équipement sauvegardé invalide."); return false end
        if saved.uid ~= "0" and not seen[saved.uid] then
            seen[saved.uid] = true
            local carried = Find(BAG_BACKPACK, saved.uid)
            local worn = Find(BAG_WORN, saved.uid)
            local banked = FindBank(banks, saved.uid)
            if direction == "withdraw" then
                if not carried and not worn then
                    if banked then uids[#uids + 1] = saved.uid else missing[#missing + 1] = saved.name or "Pièce inconnue" end
                end
            elseif carried then
                if IsItemStolen(carried.bag, carried.slot) then
                    self:Notify("Une pièce volée ne peut pas être déposée en banque."); return false
                end
                if not EmptyDestination(depositBags, carried) then
                    self:Notify("La banque n'accepte plus de dépôt. Libère de la place avant de réessayer."); return false
                end
                uids[#uids + 1] = saved.uid
            end
        end
    end
    if #missing > 0 then self:Notify("Pièces absentes du sac et de la banque : " .. tostring(#missing) .. ". Vérifie ce setup."); return false end
    if #uids == 0 then
        self:Notify(direction == "withdraw" and "Les pièces sont déjà dans le sac ou équipées." or "Aucune pièce de ce setup dans le sac. Les pièces portées restent équipées.")
        return false
    end
    table.sort(uids)
    local free = direction == "withdraw" and GetNumBagFreeSlots(BAG_BACKPACK) or 0
    if direction == "deposit" then for _, bag in ipairs(depositBags) do free = free + GetNumBagFreeSlots(bag) end end
    if free < #uids then self:Notify("Libère " .. tostring(#uids) .. " places dans " .. (direction == "withdraw" and "ton sac." or "ta banque.")); return false end
    self:SuppressAutomationForContext()
    self.bankTransfer = { id = id, direction = direction, uids = uids, index = 1, banks = banks, bank = GetBankingBag() }
    Status("Transfert bancaire préparé : " .. tostring(#uids) .. " pièces.", id)
    return true
end

function R:TickBankTransfer()
    local transfer = self.bankTransfer
    if not transfer then return end
    local now = GetGameTimeMilliseconds()
    local operation = transfer.operation
    if operation then
        if Find(operation.bag, operation.uid) then
            operation.confirmedAt = operation.confirmedAt or now
            if now - operation.confirmedAt < 300 then return end
            transfer.operation = nil
            transfer.index = transfer.index + 1
            if transfer.cancelled then Finish("Transfert bancaire arrêté. Les pièces déjà déplacées restent à leur place."); return end
        else
            operation.confirmedAt = nil
            if now - operation.startedAt >= TIMEOUT_MS then
                Finish("Transfert non confirmé. Vérifie les pièces dans ton sac et ta banque avant de réessayer.", true)
            end
            return
        end
    end
    local banks = BankingBags()
    if transfer.cancelled or not banks or GetBankingBag() ~= transfer.bank then
        Finish("Transfert arrêté : la banque a été fermée ou changée."); return
    end
    if not IsPlayerActivated() or IsUnitDeadOrReincarnating("player") or IsUnitInCombat("player") then
        Finish("Transfert arrêté : le personnage n'est plus disponible."); return
    end
    local uid = transfer.uids[transfer.index]
    if not uid then
        for _, savedUid in ipairs(transfer.uids) do
            local present = transfer.direction == "withdraw" and (Find(BAG_BACKPACK, savedUid) or Find(BAG_WORN, savedUid))
                or (transfer.direction == "deposit" and FindBank(banks, savedUid))
            if not present then
                Finish("Une pièce a changé de place pendant le transfert. Vérifie ce setup avant de réessayer.", true); return
            end
        end
        Finish("Transfert bancaire terminé et vérifié."); return
    end
    local source = transfer.direction == "withdraw" and FindBank(banks, uid) or Find(BAG_BACKPACK, uid)
    local destBags = transfer.direction == "withdraw" and { BAG_BACKPACK } or DepositBags()
    if not source then
        local alreadyThere = transfer.direction == "withdraw" and (Find(BAG_BACKPACK, uid) or Find(BAG_WORN, uid)) or FindBank(banks, uid)
        if alreadyThere then transfer.index = transfer.index + 1; return end
        Finish("Une pièce a changé de place. Transfert arrêté ; vérifie ce setup.", true); return
    end
    if transfer.direction == "deposit" and IsItemStolen(source.bag, source.slot) then
        Finish("Transfert arrêté : une pièce ne peut pas être déposée.", true); return
    end
    local bag, slot = EmptyDestination(destBags, source)
    if not bag then Finish("Transfert arrêté : plus de place disponible.", true); return end
    -- Store the in-flight request before dispatch: even a thrown callback may follow an accepted request.
    transfer.operation = { uid = uid, bag = bag, startedAt = now }
    local ok = pcall(CallSecureProtected, "RequestMoveItem", source.bag, source.slot, bag, slot, 1)
    if not ok then transfer.cancelled = true end
    Status("Transfert bancaire : " .. tostring(transfer.index) .. " / " .. tostring(#transfer.uids) .. ".", transfer.id)
end

function R:ShowBankDialog(id)
    if ZO_Dialogs_IsShowingDialog() then self:Notify("Ferme la fenêtre actuelle puis réessaie."); return false end
    local banks, problem = BankingBags()
    if not banks then self:Notify(problem); return false end
    if self.bankTransfer or self.engine:IsBusy() then self:Notify("Attends la fin de l'action en cours."); return false end
    if id and not self.db.profiles[id] then return false end
    ZO_Dialogs_ShowGamepadDialog(BANK_DIALOG, { profileId = id })
    return true
end

function R:InitializeExtras()
    ZO_Dialogs_RegisterCustomDialog(BANK_DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = "Setup Assist — Banque" },
        mainText = { text = "Retirer les pièces d'un setup, ou déposer seulement celles présentes dans le sac. Les pièces équipées restent en place." },
        setup = function(dialog)
            local rows = {}
            for _, id in ipairs(self.db.order) do
                local profile = self.db.profiles[id]
                if profile and (not dialog.data.profileId or dialog.data.profileId == id) then
                    for _, action in ipairs({ { "withdraw", "Retirer : " }, { "deposit", "Déposer depuis le sac : " } }) do
                        local savedId, direction = id, action[1]
                        local data = ZO_GamepadEntryData:New(action[2] .. profile.name, ICON)
                        data.setup = ZO_SharedGamepadEntry_OnSetup
                        data.callback = function() self:StartBankTransfer(savedId, direction) end
                        rows[#rows + 1] = { template = "ZO_GamepadMenuEntryTemplate", entryData = data }
                    end
                end
            end
            if #rows == 0 then
                local data = ZO_GamepadEntryData:New("Enregistre d'abord un setup dans le manager.", ICON)
                data.setup = ZO_SharedGamepadEntry_OnSetup
                data:SetEnabled(false)
                rows[1] = { template = "ZO_GamepadMenuEntryTemplate", entryData = data }
            end
            dialog.info.parametricList = rows
            dialog:setupFunc()
        end,
        parametricList = {},
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = "Choisir", enabled = function(dialog)
                local data = dialog.entryList:GetTargetData()
                return data and data.callback ~= nil and data:IsEnabled() and not self.bankTransfer and not self.engine:IsBusy()
            end, callback = function(dialog)
                local data = dialog.entryList:GetTargetData()
                if data and data:IsEnabled() and data.callback and not self.bankTransfer and not self.engine:IsBusy() then data.callback() end
            end },
            { keybind = "DIALOG_NEGATIVE", text = "Retour" },
        },
    })
    local bankingScene = GAMEPAD_BANKING_SCENE
    if bankingScene then
        local group = { alignment = KEYBIND_STRIP_ALIGN_LEFT, {
            name = function() return self.bankTransfer and "Annuler le transfert" or "Setup Assist" end,
            keybind = "UI_SHORTCUT_QUINARY",
            callback = function()
                if self.bankTransfer then self:CancelBankTransfer() else self:ShowBankDialog() end
            end,
            visible = function()
                local bag = GetBankingBag()
                return IsBankOpen() and (bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK) and not self.engine:IsBusy()
            end,
        } }
        self.bankKeybindGroup = group
        bankingScene:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_SHOWN then KEYBIND_STRIP:AddKeybindButtonGroup(group)
            elseif state == SCENE_HIDDEN then KEYBIND_STRIP:RemoveKeybindButtonGroup(group) end
        end)
    end
    EVENT_MANAGER:RegisterForUpdate("RelaisBank", 150, function()
        if not self.bankTransfer then return end
        local ok = pcall(self.TickBankTransfer, self)
        if not ok then
            local transfer = self.bankTransfer
            -- Finishing clears the transfer before refreshing its screen; never revive it after a display failure.
            if not transfer then return end
            transfer.cancelled = true
            local operation = transfer.operation
            if not operation then Finish("Transfert interrompu. Vérifie les pièces dans le sac et la banque.", true)
            elseif GetGameTimeMilliseconds() - operation.startedAt >= TIMEOUT_MS then Finish("Transfert non confirmé. Vérifie les pièces avant de réessayer.", true) end
        end
    end)
    self:InitializeRadialShortcuts()
end

function R:InitializeRadialShortcuts()
    local library = LibRadialMenu
    if not library or type(library.RegisterAddon) ~= "function" or type(library.RegisterEntry) ~= "function" then return false end
    local function Register(name, id, callback, description)
        return pcall(library.RegisterEntry, library, self.name, name, id, ICON, callback, description)
    end
    if not pcall(library.RegisterAddon, library, self.name, self.displayName) then return false end
    local opened = Register("Ouvrir Setup Assist", "open", function() self:ShowUI() end, "Ouvrir le gestionnaire de setups.")
    Register("Charger le setup sélectionné", "load", function()
        local id = self.selectedProfileId
        if not id or not self.db.profiles[id] then self:Notify("Sélectionne d'abord un setup dans le manager."); return end
        self:EquipSetup(id)
    end, "Charger le dernier setup sélectionné dans le manager, hors combat.")
    Register("Arrêter le changement", "stop", function() self:CancelRequest() end, "Arrêter les prochaines étapes du changement en cours.")
    Register("Mettre l'automatique en pause", "pause", function()
        if self.db.settings.automatic then self:ToggleAutomatic() else self:Notify("Les changements automatiques sont déjà désactivés.") end
    end, "Désactiver les règles automatiques jusqu'à leur réactivation dans le manager.")
    self.radialAvailable = opened == true
    return self.radialAvailable
end
