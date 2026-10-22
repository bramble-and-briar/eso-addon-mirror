CraftingDailyNotificationSavedVariables = {}

if not CraftingDailyNotificationSavedVariables._globalLastCleanupTimestamp then
    CraftingDailyNotificationSavedVariables._globalLastCleanupTimestamp = os.time(os.date("!*t")) - 3600 * 24 * 7 
end

CraftingDailyNotification = {}
local CraftingDailyNotification = CraftingDailyNotification
local LAM = LibAddonMenu2 

local COLOR_YELLOW = "|cFFD700"
local COLOR_GREEN  = "|c00FF00"
local COLOR_WHITE  = "|cFFFFFF"
local COLOR_RED    = "|cFF0000"

local gameLanguage = GetCVar("language.2")
local languageMap = {
    ["en"] = "en", ["ru"] = "ru", ["fr"] = "fr",
    ["es"] = "es", ["jp"] = "jp", ["de"] = "de",
}
local LANGUAGE = languageMap[gameLanguage] or "en" 

local L = {
    ["ru"] = {
        SI_CRAFTINGDAILYNOTIF_ALCHEMY = "|t60:60:/esoui/art/icons/skilllinexp_alchemy.dds|t         |c00FF00Алхимия|r",
        SI_CRAFTINGDAILYNOTIF_BLACKSMITHING = "|t60:60:/esoui/art/icons/antiquities_ayleid_blacksmithing_station_anvil.dds|t         |cb5bfbbКузнечное дело|r",
        SI_CRAFTINGDAILYNOTIF_ENCHANTING = "|t60:60:/esoui/art/icons/housing_sys_str_drufsrune002.dds|t         |cFF7276Зачарование|r",
        SI_CRAFTINGDAILYNOTIF_CLOTHING = "|t60:60:/esoui/art/icons/justice_stolen_clothing_001.dds|t         |cffddcaПортняжное дело|r",
        SI_CRAFTINGDAILYNOTIF_PROVISIONING = "|t60:60:/esoui/art/icons/justice_stolen_food_001.dds|t         |cFFFFFFСнабжение|r",
        SI_CRAFTINGDAILYNOTIF_WOODWORKING = "|t60:60:/esoui/art/icons/crafting_woodworking_rough_ruby_ash.dds|t         |cD2691EСтолярное дело|r",
        SI_CRAFTINGDAILYNOTIF_JEWELRYCRAFTING = "|t60:60:/esoui/art/icons/antiquities_ornate_necklace_5.dds|t         |c1E90FFЮвелирное дело|r",
        SI_CRAFTINGDAILYNOTIF_SKILL_TOOLTIP = "|cff0000Данная настройка только на текущего персонажа!!! Настройте остальных отдельно!|r",
        SI_CRAFTINGDAILYNOTIF_SETTINGS = "|c98fb98Настройки|r",
        SI_CRAFTINGDAILYNOTIF_CRAFTINGS = "|cADD8E6Активные Ремёсла|r",
        SI_CRAFTINGDAILYNOTIF_NOTE = "|c98fb98Отключите отсутствующие ремёсла. Лимит изменится автоматически (7/7 по умолчанию).|r",
        SI_CRAFTINGDAILYNOTIF_CHAT = "|cADD8E6Отправка сообщений в чат|r",
        SI_CRAFTINGDAILYNOTIF_CHAT_N = "|cADD8E6Сообщения в чат. На весь аккаунт.|r",
        SI_CRAFTINGDAILYNOTIF_DELETE = "|cADD8E6Период автоудаления истории|r",
        SI_CRAFTINGDAILYNOTIF_DELETE_N = "|cADD8E6Через сколько дней неактивности записи будут удаляться.|r",
        SI_CRAFTINGDAILYNOTIF_HISTORY = "|c00FF00ИСТОРИЯ ПЕРСОНАЖЕЙ:|r",
        SI_CRAFTINGDAILYNOTIF_INFO = "|cFF0000ВНИМАНИЕ!!!|r Зайдите на каждого персонажа для получения полной истории!",
        SI_CRAFTINGDAILYNOTIF_AUTOCLEANUP = "|cFFD700[Crafting Daily]|r Авточистка: удалено %d устаревших записей.",
        SI_CRAFTINGDAILYNOTIF_ALL_COMPLETED = "Текущий герой: |c00FF00%d/%d (%d%%)|r Выполнили на аккаунте: |c00FF00%d/%d|r",
        SI_CRAFTINGDAILYNOTIF_PROGRESS_REPORT = "|cFFFFFFПрогресс персонажей: %s%d|r|cFFFFFF/%s%d|r: %s",

    },
    ["en"] = {
        SI_CRAFTINGDAILYNOTIF_ALCHEMY = "|t60:60:/esoui/art/icons/skilllinexp_alchemy.dds|t         |c00FF00Alchemy|r",
        SI_CRAFTINGDAILYNOTIF_BLACKSMITHING = "|t60:60:/esoui/art/icons/antiquities_ayleid_blacksmithing_station_anvil.dds|t         |cb5bfbbBlacksmithing|r",
        SI_CRAFTINGDAILYNOTIF_ENCHANTING = "|t60:60:/esoui/art/icons/housing_sys_str_drufsrune002.dds|t         |cFF7276Enchanting|r",
        SI_CRAFTINGDAILYNOTIF_CLOTHING = "|t60:60:/esoui/art/icons/justice_stolen_clothing_001.dds|t         |cffddcaClothing|r",
        SI_CRAFTINGDAILYNOTIF_PROVISIONING = "|t60:60:/esoui/art/icons/justice_stolen_food_001.dds|t         |cFFFFFFProvisioning|r",
        SI_CRAFTINGDAILYNOTIF_WOODWORKING = "|t60:60:/esoui/art/icons/crafting_woodworking_rough_ruby_ash.dds|t         |cD2691EWoodworking|r",
        SI_CRAFTINGDAILYNOTIF_JEWELRYCRAFTING = "|t60:60:/esoui/art/icons/antiquities_ornate_necklace_5.dds|t         |c1E90FFJewelry Crafting|r",
        SI_CRAFTINGDAILYNOTIF_SKILL_TOOLTIP = "|cff0000This setting is for the current character only!!!|r",
        SI_CRAFTINGDAILYNOTIF_SETTINGS = "|c98fb98Settings|r",
        SI_CRAFTINGDAILYNOTIF_CRAFTINGS = "|cADD8E6Active Crafts|r",
        SI_CRAFTINGDAILYNOTIF_NOTE = "|c98fb98Disable crafts that your character does not have. Default is 7/7.|r",
        SI_CRAFTINGDAILYNOTIF_CHAT = "|cADD8E6Sending messages to chat|r",
        SI_CRAFTINGDAILYNOTIF_CHAT_N = "|cADD8E6Enable or disable chat notifications for the entire account.|r",
        SI_CRAFTINGDAILYNOTIF_DELETE = "|cADD8E6History auto-delete period|r",
        SI_CRAFTINGDAILYNOTIF_DELETE_N = "|cADD8E6Days of inactivity before records are wiped.|r",
        SI_CRAFTINGDAILYNOTIF_HISTORY = "|c00FF00CHARACTER HISTORY:|r",
        SI_CRAFTINGDAILYNOTIF_INFO = "|cFF0000WARNING!!!|r Log in once on each character to sync the history layout!",
        SI_CRAFTINGDAILYNOTIF_AUTOCLEANUP = "|cFFD700[Crafting Daily]|r Auto-cleanup: deleted %d old records.",
        SI_CRAFTINGDAILYNOTIF_ALL_COMPLETED = "Current Character: |c00FF00%d/%d (%d%%)|r Account Completed: |c00FF00%d/%d|r",
        SI_CRAFTINGDAILYNOTIF_PROGRESS_REPORT = "|cFFFFFFCharacter progress: %s%d|r|cFFFFFF/%s%d|r: %s",

    }
}
L["fr"] = {
    SI_CRAFTINGDAILYNOTIF_ALCHEMY = "|t60:60:/esoui/art/icons/skilllinexp_alchemy.dds|t         |c00FF00Alchimie|r",
    SI_CRAFTINGDAILYNOTIF_BLACKSMITHING = "|t60:60:/esoui/art/icons/antiquities_ayleid_blacksmithing_station_anvil.dds|t         |cb5bfbbForge|r",
    SI_CRAFTINGDAILYNOTIF_ENCHANTING = "|t60:60:/esoui/art/icons/housing_sys_str_drufsrune002.dds|t         |cFF7276Enchantement|r",
    SI_CRAFTINGDAILYNOTIF_CLOTHING = "|t60:60:/esoui/art/icons/justice_stolen_clothing_001.dds|t         |cffddcaCouture|r",
    SI_CRAFTINGDAILYNOTIF_PROVISIONING = "|t60:60:/esoui/art/icons/justice_stolen_food_001.dds|t         |cFFFFFFApprovisionnement|r",
    SI_CRAFTINGDAILYNOTIF_WOODWORKING = "|t60:60:/esoui/art/icons/crafting_woodworking_rough_ruby_ash.dds|t         |cD2691EMenuiserie|r",
    SI_CRAFTINGDAILYNOTIF_JEWELRYCRAFTING = "|t60:60:/esoui/art/icons/antiquities_ornate_necklace_5.dds|t         |c1E90FFJoaillerie|r",
    SI_CRAFTINGDAILYNOTIF_SKILL_TOOLTIP = "|cff0000Ce réglage s'applique uniquement au personnage actuel !!!|r",
    SI_CRAFTINGDAILYNOTIF_SETTINGS = "|c98fb98Réglages|r",
    SI_CRAFTINGDAILYNOTIF_CRAFTINGS = "|cADD8E6Métiers Actifs|r",
    SI_CRAFTINGDAILYNOTIF_NOTE = "|c98fb98Désactivez les métiers non possédés. La limite s'adapte (7/7 par défaut).|r",
    SI_CRAFTINGDAILYNOTIF_CHAT = "|cADD8E6Envoi de messages dans le chat|r",
    SI_CRAFTINGDAILYNOTIF_CHAT_N = "|cADD8E6Activer/Désactiver les messages pour tout le compte.|r",
    SI_CRAFTINGDAILYNOTIF_DELETE = "|cADD8E6Période d'auto-suppression|r",
    SI_CRAFTINGDAILYNOTIF_DELETE_N = "|cADD8E6Nombre de jours avant suppression des données inactives.|r",
    SI_CRAFTINGDAILYNOTIF_HISTORY = "|c00FF00HISTORIQUE DES PERSONNAGES:|r",
    SI_CRAFTINGDAILYNOTIF_INFO = "|cFF0000ATTENTION!!!|r Connectez-vous sur chaque perso pour actualiser l'historique.",
    SI_CRAFTINGDAILYNOTIF_AUTOCLEANUP = "|cFFD700[Crafting Daily]|r Nettoyage automatique : %d entrées supprimées.",
    SI_CRAFTINGDAILYNOTIF_ALL_COMPLETED = "Perso Actuel: |c00FF00%d/%d (%d%%)|r Compte validé: |c00FF00%d/%d|r",
   SI_CRAFTINGDAILYNOTIF_PROGRESS_REPORT = "|cFFFFFFProgression des personnages : %s%d|r|cFFFFFF/%s%d|r: %s",
}
L["es"] = {
    SI_CRAFTINGDAILYNOTIF_ALCHEMY = "|t60:60:/esoui/art/icons/skilllinexp_alchemy.dds|t         |c00FF00Alquimia|r",
    SI_CRAFTINGDAILYNOTIF_BLACKSMITHING = "|t60:60:/esoui/art/icons/antiquities_ayleid_blacksmithing_station_anvil.dds|t         |cb5bfbbHerrería|r",
    SI_CRAFTINGDAILYNOTIF_ENCHANTING = "|t60:60:/esoui/art/icons/housing_sys_str_drufsrune002.dds|t         |cFF7276Encantamiento|r",
    SI_CRAFTINGDAILYNOTIF_CLOTHING = "|t60:60:/esoui/art/icons/justice_stolen_clothing_001.dds|t         |cffddcaSastrería|r",
    SI_CRAFTINGDAILYNOTIF_PROVISIONING = "|t60:60:/esoui/art/icons/justice_stolen_food_001.dds|t         |cFFFFFFAbastecimiento|r",
    SI_CRAFTINGDAILYNOTIF_WOODWORKING = "|t60:60:/esoui/art/icons/crafting_woodworking_rough_ruby_ash.dds|t         |cD2691ECarpintería|r",
    SI_CRAFTINGDAILYNOTIF_JEWELRYCRAFTING = "|t60:60:/esoui/art/icons/antiquities_ornate_necklace_5.dds|t         |c1E90FFArtículos de Joyería|r",
    SI_CRAFTINGDAILYNOTIF_SKILL_TOOLTIP = "|cff0000¡Esta configuración es solo para el personaje actual!|r",
    SI_CRAFTINGDAILYNOTIF_SETTINGS = "|c98fb98Configuraciones|r",
    SI_CRAFTINGDAILYNOTIF_CRAFTINGS = "|cADD8E6Oficios Activos|r",
    SI_CRAFTINGDAILYNOTIF_NOTE = "|c98fb98Desactiva los oficios que no tengas. Límite automático (7/7 por defecto).|r",
    SI_CRAFTINGDAILYNOTIF_CHAT = "|cADD8E6Envío de mensajes al chat|r",
    SI_CRAFTINGDAILYNOTIF_CHAT_N = "|c00FF00Esta configuración es para toda la cuenta.|r",
    SI_CRAFTINGDAILYNOTIF_DELETE = "|cADD8E6Período de autoborrado|r",
    SI_CRAFTINGDAILYNOTIF_DELETE_N = "|c00FF00Días de inactividad antes de borrar registros.|r",
    SI_CRAFTINGDAILYNOTIF_HISTORY = "|c00FF00HISTORIAL DE PERSONAJES:|r",
    SI_CRAFTINGDAILYNOTIF_INFO = "|cFF0000¡ATENCIÓN!!!|r Inicia sesión con cada personaje para guardar su historial.",
    SI_CRAFTINGDAILYNOTIF_AUTOCLEANUP = "|cFFD700[Crafting Daily]|r Limpieza: eliminados %d registros antiguos.",
    SI_CRAFTINGDAILYNOTIF_ALL_COMPLETED = "Personaje actual: |c00FF00%d/%d (%d%%)|r Cuenta: |c00FF00%d/%d|r",
    SI_CRAFTINGDAILYNOTIF_PROGRESS_REPORT = "|cFFFFFFProgreso de personajes: %s%d|r|cFFFFFF/%s%d|r: %s",
}
L["jp"] = {
    SI_CRAFTINGDAILYNOTIF_ALCHEMY = "|t60:60:/esoui/art/icons/skilllinexp_alchemy.dds|t         |c00FF00錬金術|r",
    SI_CRAFTINGDAILYNOTIF_BLACKSMITHING = "|t60:60:/esoui/art/icons/antiquities_ayleid_blacksmithing_station_anvil.dds|t         |cb5bfbb鍛冶|r",
    SI_CRAFTINGDAILYNOTIF_ENCHANTING = "|t60:60:/esoui/art/icons/housing_sys_str_drufsrune002.dds|t         |cFF7276付呪|r",
    SI_CRAFTINGDAILYNOTIF_CLOTHING = "|t60:60:/esoui/art/icons/justice_stolen_clothing_001.dds|t         |cffddca裁縫|r",
    SI_CRAFTINGDAILYNOTIF_PROVISIONING = "|t60:60:/esoui/art/icons/justice_stolen_food_001.dds|t         |cFFFFFF調理|r",
    SI_CRAFTINGDAILYNOTIF_WOODWORKING = "|t60:60:/esoui/art/icons/crafting_woodworking_rough_ruby_ash.dds|t         |cD2691E木工|r",
    SI_CRAFTINGDAILYNOTIF_JEWELRYCRAFTING = "|t60:60:/esoui/art/icons/antiquities_ornate_necklace_5.dds|t         |c1E90FF宝飾|r",
    SI_CRAFTINGDAILYNOTIF_SKILL_TOOLTIP = "|cff0000この設定は現在のキャラクターにのみ適用されます。|r",
    SI_CRAFTINGDAILYNOTIF_SETTINGS = "|c98fb98設定|r",
    SI_CRAFTINGDAILYNOTIF_CRAFTINGS = "|cADD8E6アクティブなクラフト|r",
    SI_CRAFTINGDAILYNOTIF_NOTE = "|c98fb98未修得のクラフトを無効にしてください。上限は自動調整されます。|r",
    SI_CRAFTINGDAILYNOTIF_CHAT = "|cADD8E6チャットへのメッセージ送信|r",
    SI_CRAFTINGDAILYNOTIF_CHAT_N = "|c00FF00この設定はアカウント全体に適用されます。|r",
    SI_CRAFTINGDAILYNOTIF_DELETE = "|cADD8E6履歴の自動削除期間|r",
    SI_CRAFTINGDAILYNOTIF_DELETE_N = "|c00FF00何日後に古い記録を自動削除するか指定します。|r",
    SI_CRAFTINGDAILYNOTIF_HISTORY = "|c00FF00キャラクター履歴:|r",
    SI_CRAFTINGDAILYNOTIF_INFO = "|cFF0000注意!!!|r 同期のため、全キャラに一度ログインしてください！",
    SI_CRAFTINGDAILYNOTIF_AUTOCLEANUP = "|cFFD700[Crafting Daily]|r クリーンアップ：古い記録を%d件削除しました。",
    SI_CRAFTINGDAILYNOTIF_ALL_COMPLETED = "現在のキャラ: |c00FF00%d/%d (%d%%)|r アカウント完了数: |c00FF00%d/%d|r",
SI_CRAFTINGDAILYNOTIF_PROGRESS_REPORT = "|cFFFFFFキャラクターの進捗状況: %s%d|r|cFFFFFF/%s%d|r: %s",
}
L["de"] = {
    SI_CRAFTINGDAILYNOTIF_ALCHEMY = "|t60:60:/esoui/art/icons/skilllinexp_alchemy.dds|t         |c00FF00Alchemie|r",
    SI_CRAFTINGDAILYNOTIF_BLACKSMITHING = "|t60:60:/esoui/art/icons/antiquities_ayleid_blacksmithing_station_anvil.dds|t         |cb5bfbbSchmiedekunst|r",
    SI_CRAFTINGDAILYNOTIF_ENCHANTING = "|t60:60:/esoui/art/icons/housing_sys_str_drufsrune002.dds|t         |cFF7276Verzauberung|r",
    SI_CRAFTINGDAILYNOTIF_CLOTHING = "|t60:60:/esoui/art/icons/justice_stolen_clothing_001.dds|t         |cffddcaSchneiderei|r",
    SI_CRAFTINGDAILYNOTIF_PROVISIONING = "|t60:60:/esoui/art/icons/justice_stolen_food_001.dds|t         |cFFFFFFVersorgung|r",
    SI_CRAFTINGDAILYNOTIF_WOODWORKING = "|t60:60:/esoui/art/icons/crafting_woodworking_rough_ruby_ash.dds|t         |cD2691ETischlerei|r",
    SI_CRAFTINGDAILYNOTIF_JEWELRYCRAFTING = "|t60:60:/esoui/art/icons/antiquities_ornate_necklace_5.dds|t         |c1E90FFJuwelierkunst|r",
    SI_CRAFTINGDAILYNOTIF_SKILL_TOOLTIP = "|cff0000Diese Einstellung gilt nur für den aktuellen Charakter!!!|r",
    SI_CRAFTINGDAILYNOTIF_SETTINGS = "|c98fb98Einstellungen|r",
    SI_CRAFTINGDAILYNOTIF_CRAFTINGS = "|cADD8E6Aktive Handwerke|r",
    SI_CRAFTINGDAILYNOTIF_NOTE = "|c98fb98Deaktivieren Sie Handwerke ohne Freischaltung. Limit passt sich an (7/7 Standard).|r",
    SI_CRAFTINGDAILYNOTIF_CHAT = "|cADD8E6Nachrichten senden im Chat|r",
    SI_CRAFTINGDAILYNOTIF_CHAT_N = "|c00FF00Diese Einstellung gilt für das gesamte Konto.|r",
    SI_CRAFTINGDAILYNOTIF_DELETE = "|cADD8E6Zeitraum für Auto-Löschung|r",
    SI_CRAFTINGDAILYNOTIF_DELETE_N = "|c00FF00Inaktive Tage bis Datensätze gelöscht werden.|r",
    SI_CRAFTINGDAILYNOTIF_HISTORY = "|c00FF00CHARAKTER-HISTORIE:|r",
    SI_CRAFTINGDAILYNOTIF_INFO = "|cFF0000ACHTUNG!!!|r Loggen Sie sich bei allen Charakteren ein zum Synchronisieren.",
    SI_CRAFTINGDAILYNOTIF_AUTOCLEANUP = "|cFFD700[Crafting Daily]|r Bereinigung: %d alte Einträge gelöscht.",
    SI_CRAFTINGDAILYNOTIF_ALL_COMPLETED = "Charakter: |c00FF00%d/%d (%d%%)|r Konto-Fortschritt: |c00FF00%d/%d|r",
    SI_CRAFTINGDAILYNOTIF_PROGRESS_REPORT = "|cFFFFFFFortschritt der Charaktere: %s%d|r|cFFFFFF/%s%d|r: %s",
}

CraftingDailyNotification.lastProgressMessage = nil
CraftingDailyNotification.allCompletedReported = false
CraftingDailyNotification.CRAFTING_SKILLS = {
    { name = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_ALCHEMY, enabled = true },
    { name = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_ENCHANTING, enabled = true },
    { name = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_BLACKSMITHING, enabled = true },
    { name = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_CLOTHING, enabled = true },
    { name = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_PROVISIONING, enabled = true },
    { name = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_WOODWORKING, enabled = true },
    { name = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_JEWELRYCRAFTING, enabled = true }
}

-- FIX: Raw IDs are loaded dynamically to circumvent line 170 blank parameter symbol crashes
local TRACKED_ITEM_IDS = {}
local itemRawIDs = {
    57851, 58131, 58503, 58504, 58505, 58506, 58507, 58508, 58509, 71234, 121298,
    58519, 58520, 58521, 58522, 58523, 58524, 58525, 58526, 58527, 71233, 121297,
    147607, 147608, 147609, 147610, 147611, 147612, 147613, 147614, 147615, 147616,
    58528, 58529, 58530, 58531, 58532, 58533, 58534, 59735, 59736, 71236, 121300,
    59705, 59706, 59707, 59708, 59709, 59710, 71238, 121302, 59714, 59715, 59716,
    59717, 59718, 59719, 59720, 59721, 59723, 59724, 59725, 71237, 121301, 58510,
    58511, 58512, 58513, 58514, 58515, 58516, 58517, 58518, 71235, 121299, 138801,
    138802, 138803, 138804, 138805
}
for i = 1, #itemRawIDs do TRACKED_ITEM_IDS[itemRawIDs[i]] = true end

function CraftingDailyNotification:CraftingDaily_CheckAllAccounts()
    local todayTimestamp = os.time(os.date("!*t"))
    CraftingDailyNotificationSavedVariables._globalLastCleanupTimestamp = todayTimestamp
    for accountKey, accountData in pairs(CraftingDailyNotificationSavedVariables) do
        if type(accountKey) == "string" and type(accountData) == "table" and accountKey:sub(1,1) == "@" then
            local cleanupDays = accountData.settings and accountData.settings.accountCleanupDays or 300
            local thresholdTimestamp = todayTimestamp - cleanupDays * 86400
            local removedCount = 0
            for charName, charData in pairs(accountData) do
                if charName ~= "settings" and type(charData) == "table" and charData.lastActivityDateTS then
                    if charData.lastActivityDateTS < CraftingDailyNotificationSavedVariables._globalLastCleanupTimestamp then
                        if charData.lastActivityDateTS < thresholdTimestamp then
                            CraftingDailyNotificationSavedVariables[accountKey][charName] = nil
                            removedCount = removedCount + 1
                        end
                    end
                end
            end
            if accountData.settings and accountData.settings.enableChatMessages and removedCount > 0 then
                d(string.format(L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_AUTOCLEANUP, removedCount))
            end
        end
    end
end
function CraftingDailyNotification:Initialize()
    self:InitializeSavedVariables()
    self:CreateSettings()
    self:RegisterEvents()
    self:CraftingDaily_CheckAllAccounts()
end

local function CustomGetDateString(timestamp)
    return os.date("%d.%m.%Y", timestamp)
end

function CraftingDailyNotification:InitializeSavedVariables()
    local currentCharName = GetUnitName("player")
    local currentAccount = "" .. GetDisplayName()
    local today = CustomGetDateString(os.time())
    
    if not CraftingDailyNotificationSavedVariables[currentAccount] then
        CraftingDailyNotificationSavedVariables[currentAccount] = {}
    end
    
    local charTable = CraftingDailyNotificationSavedVariables[currentAccount][currentCharName]
    if not charTable then
        charTable = { lastActivityDateTS = os.time(), todayCount = 0, isCompletedForToday = false, craftingSkills = {} }
        CraftingDailyNotificationSavedVariables[currentAccount][currentCharName] = charTable
    else
        if not charTable.lastActivityDateTS then charTable.lastActivityDateTS = os.time() end
    end
    
    if not CraftingDailyNotificationSavedVariables[currentAccount].settings then
        CraftingDailyNotificationSavedVariables[currentAccount].settings = { enableChatMessages = true, accountCleanupDays = 300 }
    end
    
    if not charTable.craftingSkills then charTable.craftingSkills = {} end
    for _, skill in ipairs(self.CRAFTING_SKILLS) do
        if charTable.craftingSkills[skill.name] == nil then charTable.craftingSkills[skill.name] = skill.enabled end
    end
    
    self:ResetAllCharactersForNewDay(currentAccount)
    if CustomGetDateString(charTable.lastActivityDateTS) ~= today then
        charTable.lastActivityDateTS = os.time()
        charTable.todayCount = 0
        charTable.isCompletedForToday = false
    end
    zo_callLater(function() self:SendAccountProgressReport(currentAccount) end, 500)
    self:SaveData()
end

function CraftingDailyNotification:ResetAllCharactersForNewDay(accountKey)
    local today = CustomGetDateString(os.time())
    if CraftingDailyNotificationSavedVariables[accountKey] then
        for charName, charData in pairs(CraftingDailyNotificationSavedVariables[accountKey]) do
            if type(charData) == "table" and charName ~= "settings" and charData.lastActivityDateTS then
                if CustomGetDateString(charData.lastActivityDateTS) ~= today then
                    charData.todayCount = 0
                    charData.isCompletedForToday = false
                end
            end
        end
    end
    if CraftingDailyNotificationSavedVariables._globalNotifyDate ~= today then
        CraftingDailyNotification.allCompletedReported = false
        CraftingDailyNotificationSavedVariables._globalNotifyDate = today
        self:SaveData()
    end
end

function CraftingDailyNotification:ScanInventoryForInitialCount(_, dateKey)
    local currentCount = 0
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if TRACKED_ITEM_IDS[GetItemId(BAG_BACKPACK, slotIndex)] then currentCount = currentCount + GetSlotStackSize(BAG_BACKPACK, slotIndex) end
    end
    for slotIndex = 0, GetBagSize(BAG_BANK) - 1 do
        if TRACKED_ITEM_IDS[GetItemId(BAG_BANK, slotIndex)] then currentCount = currentCount + GetSlotStackSize(BAG_BANK, slotIndex) end
    end
    return currentCount
end

function CraftingDailyNotification:OnItemAdded(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
    local charName, accountName = GetUnitName("player"), "" .. GetDisplayName()
    local data = CraftingDailyNotificationSavedVariables[accountName][charName]
    if not data or not data.todayCount or not TRACKED_ITEM_IDS[GetItemId(bagId, slotIndex)] then return end
    data.todayCount = data.todayCount + stackCountChange
    zo_callLater(function() self:CheckAndSendCompletionStatus(data.todayCount, accountName) end, 200)
    self:SaveData()
    zo_callLater(function() self:SendAccountProgressReport(accountName) end, 500)
end

function CraftingDailyNotification:GetActiveSkillLimit()
    local count, charName, accountName = 0, GetUnitName("player"), "" .. GetDisplayName()
    local charSkills = CraftingDailyNotificationSavedVariables[accountName][charName].craftingSkills
    for i = 1, #self.CRAFTING_SKILLS do
        if charSkills[self.CRAFTING_SKILLS[i].name] == true then count = count + 1 end
    end
    return count
end

function CraftingDailyNotification:CheckAndSendCompletionStatus(currentCount, accountName)
    local charName = GetUnitName("player")
    local data = CraftingDailyNotificationSavedVariables[accountName][charName]
    if not data then return end
    local limit = self:GetActiveSkillLimit()
    if currentCount >= limit and not data.isCompletedForToday then
        data.isCompletedForToday = true
        local accountKey, totalChars, completedChars = "" .. GetDisplayName(), 0, 0
        local threshold = CraftingDailyNotificationSavedVariables[accountKey].settings.accountCleanupDays
        for cName, cData in pairs(CraftingDailyNotificationSavedVariables[accountKey]) do
            if type(cData) == "table" and cName ~= "settings" and cData.lastActivityDateTS then
                if (os.time() - cData.lastActivityDateTS) / 86400 <= threshold then
                    totalChars = totalChars + 1
                    local personalLimit = 0
                    for _, skill in ipairs(self.CRAFTING_SKILLS) do
                        if cData.craftingSkills[skill.name] == true then personalLimit = personalLimit + 1 end
                    end
                    if personalLimit > 0 and cData.todayCount >= personalLimit then completedChars = completedChars + 1 end
                end
            end
        end
        CHAT_SYSTEM:AddMessage(string.format(L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_ALL_COMPLETED, currentCount, limit, math.floor((currentCount / limit) * 100), completedChars, totalChars))
        zo_callLater(function() self:SendAccountProgressReport(accountKey) end, 500)
    end
end

--[[
function CraftingDailyNotification:SendAccountProgressReport(accountKey)
    if CraftingDailyNotification.allCompletedReported or not CraftingDailyNotificationSavedVariables[accountKey] then return end
    local totalChars, completedChars, incompleteChars = 0, 0, {}
    local threshold = CraftingDailyNotificationSavedVariables[accountKey].settings.accountCleanupDays
    for charName, data in pairs(CraftingDailyNotificationSavedVariables[accountKey]) do
        if type(data) == "table" and charName ~= "settings" and data.lastActivityDateTS then
            if (os.time() - data.lastActivityDateTS) / 86400 <= threshold then
                totalChars = totalChars + 1
                local personalLimit = 0
                for _, skill in ipairs(self.CRAFTING_SKILLS) do
                    if data.craftingSkills and data.craftingSkills[skill.name] == true then personalLimit = personalLimit + 1 end
                end
                if personalLimit > 0 then
                    if data.todayCount < personalLimit then
                        table.insert(incompleteChars, string.format("%s%s|r (%d/%d)", COLOR_RED, charName, data.todayCount, personalLimit))
                    else completedChars = completedChars + 1 end
                end
            end
        end
    end
    if totalChars == 0 then return end
    if #incompleteChars > 0 then
        local currentStatus = string.format("%d/%d", completedChars, totalChars)
        if CraftingDailyNotification.lastProgressMessage ~= currentStatus then
            if CraftingDailyNotificationSavedVariables[accountKey].settings.enableChatMessages then
                CHAT_SYSTEM:AddMessage(string.format(L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_PROGRESS_REPORT, COLOR_GREEN, completedChars, COLOR_YELLOW, totalChars, table.concat(incompleteChars, ", ")))
            end
            CraftingDailyNotification.lastProgressMessage = currentStatus
        end
    else
        CraftingDailyNotification.allCompletedReported = true
        CraftingDailyNotification.lastProgressMessage = nil
        self:SaveData()
    end
end
--]]

function CraftingDailyNotification:SendAccountProgressReport(accountKey)
    if CraftingDailyNotification.allCompletedReported or not CraftingDailyNotificationSavedVariables[accountKey] then return end
    local totalChars, completedChars, incompleteChars = 0, 0, {}
    local threshold = CraftingDailyNotificationSavedVariables[accountKey].settings.accountCleanupDays
    for charName, data in pairs(CraftingDailyNotificationSavedVariables[accountKey]) do
        if type(data) == "table" and charName ~= "settings" and data.lastActivityDateTS then
            if (os.time() - data.lastActivityDateTS) / 86400 <= threshold then
                totalChars = totalChars + 1
                local personalLimit = 0
                for _, skill in ipairs(self.CRAFTING_SKILLS) do
                    if data.craftingSkills and data.craftingSkills[skill.name] == true then personalLimit = personalLimit + 1 end
                end
                if personalLimit > 0 then
                    if data.todayCount < personalLimit then
                        -- FIX: Explicitly closed charName strings cleanly to prevent trailing hex bleeding
                        table.insert(incompleteChars, string.format("%s%s|r (%d/%d)", COLOR_RED, charName, data.todayCount, personalLimit))
                    else completedChars = completedChars + 1 end
                end
            end
        end
    end
    if totalChars == 0 then return end
    if #incompleteChars > 0 then
        local currentStatus = string.format("%d/%d", completedChars, totalChars)
        if CraftingDailyNotification.lastProgressMessage ~= currentStatus then
            if CraftingDailyNotificationSavedVariables[accountKey].settings.enableChatMessages then
                local incompleteList = table.concat(incompleteChars, ", ")
                -- FIX: De-nested token maps to force proper color tags into the localized strings
                local baseString = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_PROGRESS_REPORT
                CHAT_SYSTEM:AddMessage(string.format(baseString, COLOR_GREEN, completedChars, COLOR_YELLOW, totalChars, incompleteList))
            end
            CraftingDailyNotification.lastProgressMessage = currentStatus
        end
    else
        CraftingDailyNotification.allCompletedReported = true
        CraftingDailyNotification.lastProgressMessage = nil
        self:SaveData()
    end
end



function CraftingDailyNotification:GetCharacterHistorySummary()
    local lines, sortableData, accountName = {""}, {}, "" .. GetDisplayName()
    if not CraftingDailyNotificationSavedVariables[accountName] then return "\nНет данных." end
    local threshold = os.time() - (CraftingDailyNotificationSavedVariables[accountName].settings.accountCleanupDays or 300) * 86400
    for charName, data in pairs(CraftingDailyNotificationSavedVariables[accountName]) do
        if charName ~= "settings" and type(data) == "table" and data.lastActivityDateTS and data.lastActivityDateTS >= threshold then
            local limit = 0
            if data.craftingSkills then
                for _, skill in ipairs(self.CRAFTING_SKILLS) do
                    if data.craftingSkills[skill.name] == true then limit = limit + 1 end
                end
            end
            if limit > 0 then
                local color = data.todayCount < limit and COLOR_RED or (data.todayCount == 0 and COLOR_WHITE or COLOR_GREEN)
                local dateStr = CustomGetDateString(data.lastActivityDateTS)
                local d, m, y = string.match(dateStr or "", "(%d+)%.(%d+)%.(%d+)")
                table.insert(sortableData, {
                    text = string.format("%s [%s.%s/%s] - %s%d/%d|r", charName, d or "00", m or "00", y or "00", color, data.todayCount, limit),
                    timestamp = data.lastActivityDateTS
                })
            end
        end
    end
    table.sort(sortableData, function(a, b) return a.timestamp > b.timestamp end)
    for i = 1, #sortableData do table.insert(lines, sortableData[i].text) end
    return #lines > 1 and table.concat(lines, "\n") or "\nНет данных."
end

function CraftingDailyNotification:CreateSettings()
    local panelData = { type = "panel", name = "|c98fb98Crafting Daily Notification|r", author = "|c00FF00Eswagrom|r", version = "|cff80801.0|r", registerForRefresh = true }
    LAM:RegisterAddonPanel("CraftingDailyNotification_Panel", panelData)
    local mainControls = {
        { type = "header", name = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_CRAFTINGS, width = "full" },
        { type = "description", text = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_NOTE },
        { type = "header", width = "full" }
    }
    for _, skill in ipairs(self.CRAFTING_SKILLS) do
        table.insert(mainControls, {
            type = "checkbox", name = skill.name, tooltip = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_SKILL_TOOLTIP,
            getFunc = function()
                local charName, accountName = GetUnitName("player"), "" .. GetDisplayName()
                return (CraftingDailyNotificationSavedVariables[accountName] and CraftingDailyNotificationSavedVariables[accountName][charName] and CraftingDailyNotificationSavedVariables[accountName][charName].craftingSkills) and CraftingDailyNotificationSavedVariables[accountName][charName].craftingSkills[skill.name] or true
            end,
            setFunc = function(value)
                local charName, accountName = GetUnitName("player"), "" .. GetDisplayName()
                if not CraftingDailyNotificationSavedVariables[accountName][charName].craftingSkills then CraftingDailyNotificationSavedVariables[accountName][charName].craftingSkills = {} end
                CraftingDailyNotificationSavedVariables[accountName][charName].craftingSkills[skill.name] = value
                self:SendAccountProgressReport(accountName)
            end,
            default = true, width = "half"
        })
    end
    table.insert(mainControls, { type = "header", width = "full" })
    table.insert(mainControls, {
        type = "checkbox", name = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_CHAT, tooltip = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_CHAT_N,
        getFunc = function()
            local accountName = "" .. GetDisplayName()
            return CraftingDailyNotificationSavedVariables[accountName] and CraftingDailyNotificationSavedVariables[accountName].settings and CraftingDailyNotificationSavedVariables[accountName].settings.enableChatMessages or true
        end,
        setFunc = function(value)
            local accountName = "" .. GetDisplayName()
            CraftingDailyNotificationSavedVariables[accountName].settings.enableChatMessages = value
            CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", "CraftingDailyNotification_Panel")
        end,
        default = true, width = "full"
    })
    table.insert(mainControls, {
        type = "slider", name = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_DELETE, tooltip = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_DELETE_N,
        min = 2, max = 360, step = 1, decimals = 0,
        getFunc = function()
            local accountName = "" .. GetDisplayName()
            return CraftingDailyNotificationSavedVariables[accountName] and CraftingDailyNotificationSavedVariables[accountName].settings and CraftingDailyNotificationSavedVariables[accountName].settings.accountCleanupDays or 300
        end,
        setFunc = function(value)
            local accountName = "" .. GetDisplayName()
            CraftingDailyNotificationSavedVariables[accountName].settings.accountCleanupDays = value
            local cleanupThreshold = os.time() - (value * 86400)
            local removedCount = 0
            for savedCharName, data in pairs(CraftingDailyNotificationSavedVariables[accountName]) do
                if savedCharName ~= "settings" and type(data) == "table" and data.lastActivityDateTS and data.lastActivityDateTS < cleanupThreshold then
                    CraftingDailyNotificationSavedVariables[accountName][savedCharName] = nil
                    removedCount = removedCount + 1
                end
            end
            if CraftingDailyNotificationSavedVariables[accountName].settings.enableChatMessages and removedCount > 0 then d(string.format(L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_AUTOCLEANUP, removedCount)) end
            CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", "CraftingDailyNotification_Panel")
        end,
        default = 300, width = "full"
    })
    local optionsData = {
        { type = "submenu", name = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_SETTINGS, controls = mainControls },
        { type = "description", title = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_HISTORY },
        { type = "description", text = self:GetCharacterHistorySummary() },
        { type = "header", color = COLOR_WHITE, width = "full" },
        { type = "description", title = L[LANGUAGE].SI_CRAFTINGDAILYNOTIF_INFO }
    }
    LAM:RegisterOptionControls("CraftingDailyNotification_Panel", optionsData)
end

function CraftingDailyNotification:RegisterEvents()
    EVENT_MANAGER:UnregisterForEvent("CraftingDailyNotification", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:RegisterForEvent("CraftingDailyNotification", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(...) self:OnItemAdded(...) end)
    EVENT_MANAGER:RegisterForEvent("CraftingDailyNotification", EVENT_GAMEPLAY_DAY_TIME_CHANGED, function() self:CraftingDaily_CheckAllAccounts() end)
    EVENT_MANAGER:RegisterForEvent("CraftingDailyNotification", EVENT_PLAYER_ACTIVATED, function(...) self:InitializeSavedVariables(...) end)
    EVENT_MANAGER:UnregisterForEvent("CraftingDailyNotification", EVENT_LOGOUT_REQUESTED)
    EVENT_MANAGER:RegisterForEvent("CraftingDailyNotification", EVENT_LOGOUT_REQUESTED, function(...) self:SaveData() end)
    EVENT_MANAGER:RegisterForEvent("CraftingDailyNotification", EVENT_ADD_ON_RELOADED, function(name) if name == "CraftingDailyNotification" then self:SaveData() end end)
end

function CraftingDailyNotification:SaveData()
    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", "CraftingDailyNotification_Panel")
end

local function OnAddonLoaded(event, addonName)
    if addonName == "CraftingDailyNotification" then
        CraftingDailyNotification:Initialize()
        CraftingDailyNotification:CraftingDaily_CheckAllAccounts()
    end
end
EVENT_MANAGER:RegisterForEvent("CraftingDailyNotification", EVENT_ADD_ON_LOADED, OnAddonLoaded)
