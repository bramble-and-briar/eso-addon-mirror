TruePvPRatio = {
    name = "TruePvPRatio",
    version = "2.9",
    savedVars = nil,
    uiCreated = false,
    wasInPremadeGroup = false,
}

-- Textes de l'interface (en anglais)
ZO_CreateStringId("SI_BINDING_NAME_TRUE_PVP_RATIO_TOGGLE", "Toggle True PvP Ratio")
local L_GLOBAL_RATIO = "GLOBAL ACCOUNT RATIO: "
local L_TITLE = "TRUE PVP RATIO"

-- Couleurs officielles des alliances (Hex)
local ALLIANCE_COLORS = {
    [ALLIANCE_ALDMERI_DOMINION] = "d4aa15", -- Jaune
    [ALLIANCE_DAGGERFALL_COVENANT] = "135da8", -- Bleu
    [ALLIANCE_EBONHEART_PACT] = "a62828", -- Rouge
}

-- Couleurs et suffixes des classes
local CLASS_STYLES = {
    [1]   = { text = "DK",    color = "9c0000" }, -- Rouge sang
    [2]   = { text = "SORC",  color = "5d38a6" }, -- Mauve fonce
    [3]   = { text = "NB",    color = "404040" }, -- Gris fonce
    [4]   = { text = "WARD",  color = "00c997" }, -- Turquoise
    [5]   = { text = "NECRO", color = "9cffe8" }, -- Turquoise pale
    [6]   = { text = "TEMP",  color = "ffdc40" }, -- Jaune vif
    [117] = { text = "ARC",   color = "33FF00" }, -- Vert flash
}

local recentEvents = {}

local function GetRatio(k, d)
    if d == 0 then return (k > 0) and k or 0 end
    return k / d
end

local function FormatRatio(k, d)
    return string.format("%.2f", GetRatio(k, d))
end

local function GetDefaults()
    return {
        global = {
            kills = 0, deaths = 0, maxKillStreak = 0,
            alliances = {
                [ALLIANCE_ALDMERI_DOMINION] = {kills = 0, deaths = 0},
                [ALLIANCE_EBONHEART_PACT] = {kills = 0, deaths = 0},
                [ALLIANCE_DAGGERFALL_COVENANT] = {kills = 0, deaths = 0},
            }
        },
        characters = {}
    }
end

local function CleanupDeletedCharacters()
    local validChars = {}
    for i = 1, GetNumCharacters() do
        local name = zo_strformat("<<1>>", GetCharacterInfo(i))
        validChars[name] = true
    end

    for cName, _ in pairs(TruePvPRatio.savedVars.characters) do
        if not validChars[cName] then
            TruePvPRatio.savedVars.characters[cName] = nil
        end
    end
end

local function UpdatePremadeGroupStatus()
    if not IsActiveWorldBattleground() then
        TruePvPRatio.wasInPremadeGroup = (GetGroupSize() > 1)
    end
end

-- Detection de la zone PvP actuelle
local function GetCurrentPvPZone()
    if IsActiveWorldBattleground() then
        return "BG"
    end
    
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    if zoneId == 181 then
        return "CYR"
    elseif zoneId == 584 or zoneId == 643 then
        return "IC"
    end
    
    return "OTHER"
end

local function AddKill(zone, enemyAlliance)
    local charName = zo_strformat("<<1>>", GetUnitName("player"))
    local sv = TruePvPRatio.savedVars
    local charData = sv and sv.characters and sv.characters[charName]
    if not charData then return end

    sv.global.kills = sv.global.kills + 1
    
    if zone == "CYR" or zone == "IC" then
        if sv.global.alliances[enemyAlliance] then
            sv.global.alliances[enemyAlliance].kills = sv.global.alliances[enemyAlliance].kills + 1
        end
    end

    charData.kills = charData.kills + 1
    charData.currentKillStreak = (charData.currentKillStreak or 0) + 1
    if charData.currentKillStreak > (charData.maxKillStreak or 0) then charData.maxKillStreak = charData.currentKillStreak end
    if charData.currentKillStreak > (sv.global.maxKillStreak or 0) then sv.global.maxKillStreak = charData.currentKillStreak end

    if zone == "CYR" then
        charData.cyrodiil.kills = charData.cyrodiil.kills + 1
    elseif zone == "IC" then
        charData.ic.kills = charData.ic.kills + 1
    elseif zone == "BG" then
        if TruePvPRatio.wasInPremadeGroup then
            charData.bgGroup.kills = charData.bgGroup.kills + 1
        else
            charData.bgSolo.kills = charData.bgSolo.kills + 1
        end
    end
end

local function AddDeath(zone, enemyAlliance)
    local charName = zo_strformat("<<1>>", GetUnitName("player"))
    local sv = TruePvPRatio.savedVars
    local charData = sv and sv.characters and sv.characters[charName]
    if not charData then return end

    sv.global.deaths = sv.global.deaths + 1
    
    if zone == "CYR" or zone == "IC" then
        if sv.global.alliances[enemyAlliance] then
            sv.global.alliances[enemyAlliance].deaths = sv.global.alliances[enemyAlliance].deaths + 1
        end
    end

    charData.deaths = charData.deaths + 1
    charData.currentKillStreak = 0

    if zone == "CYR" then
        charData.cyrodiil.deaths = charData.cyrodiil.deaths + 1
    elseif zone == "IC" then
        charData.ic.deaths = charData.ic.deaths + 1
    elseif zone == "BG" then
        if TruePvPRatio.wasInPremadeGroup then
            charData.bgGroup.deaths = charData.bgGroup.deaths + 1
        else
            charData.bgSolo.deaths = charData.bgSolo.deaths + 1
        end
    end
end

local function OnPvPKillFeedDeath(eventCode, killLocation, killerDisplayName, killerCharName, killerAlliance, killerRank, victimDisplayName, victimCharName, victimAlliance, victimRank)
    local zone = GetCurrentPvPZone()
    if zone == "OTHER" then return end

    local myAccount = GetUnitDisplayName("player")
    local myCharName = zo_strformat("<<1>>", GetUnitName("player"))
    
    local killerFormatted = zo_strformat("<<1>>", killerCharName)
    local victimFormatted = zo_strformat("<<1>>", victimCharName)

    local isKiller = (killerDisplayName == myAccount and killerFormatted == myCharName)
    local isVictim = (victimDisplayName == myAccount and victimFormatted == myCharName)

    if not isKiller and not isVictim then return end

    local eventType = isKiller and "KILL" or "DEATH"
    local eventSignature = eventType .. "_" .. killerFormatted .. "_VS_" .. victimFormatted
    local currentTime = GetGameTimeMilliseconds()

    if recentEvents[eventSignature] and (currentTime - recentEvents[eventSignature]) < 2000 then
        return 
    end
    recentEvents[eventSignature] = currentTime

    if isKiller then
        AddKill(zone, victimAlliance)
    elseif isVictim then
        AddDeath(zone, killerAlliance)
    end
end

function TruePvPRatio:BuildUI()
    if self.uiCreated then return end

    local tlw = WINDOW_MANAGER:CreateTopLevelWindow("TruePvPRatio_UI")
    tlw:SetDimensions(GuiRoot:GetWidth(), GuiRoot:GetHeight())
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    tlw:SetHidden(true)
    self.uiWindow = tlw

    local bg = WINDOW_MANAGER:CreateControl("TruePvPRatio_UI_BG", tlw, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0, 0, 0, 0.95)
    bg:SetEdgeColor(0, 0, 0, 0)

    -- Titre principal
    local title = WINDOW_MANAGER:CreateControl("TruePvPRatio_UI_Title", tlw, CT_LABEL)
    title:SetFont("ZoFontGamepad42")
    title:SetAnchor(TOP, tlw, TOP, 0, 40)
    title:SetText(L_TITLE)
    title:SetColor(1, 1, 1, 1)

    -- Statistiques globales (Haut gauche)
    self.globalLabel = WINDOW_MANAGER:CreateControl("TruePvPRatio_UI_Global", tlw, CT_LABEL)
    self.globalLabel:SetFont("ZoFontGamepad34")
    self.globalLabel:SetAnchor(TOPLEFT, tlw, TOPLEFT, 40, 90)
    self.globalLabel:SetColor(1, 0.8, 0, 1)

    -- Tableau des alliances (Haut droite)
    local rightPanelX = -60
    local startY = 40
    
    local allianceTitle = WINDOW_MANAGER:CreateControl("TruePvPRatio_UI_Alliances_Title", tlw, CT_LABEL)
    allianceTitle:SetFont("ZoFontGamepad34")
    allianceTitle:SetAnchor(TOPRIGHT, tlw, TOPRIGHT, rightPanelX, startY)
    allianceTitle:SetText("Cyrodiil & IC\nKills/Deaths")
    allianceTitle:SetColor(0.7, 0.7, 0.7, 1)
    
    self.adLabel = WINDOW_MANAGER:CreateControl("TruePvPRatio_UI_AD", tlw, CT_LABEL)
    self.adLabel:SetFont("ZoFontGamepad27")
    self.adLabel:SetAnchor(TOPRIGHT, allianceTitle, BOTTOMRIGHT, 0, 10)
    self.adLabel:SetColor(0.83, 0.67, 0.08, 1) 
    
    self.dcLabel = WINDOW_MANAGER:CreateControl("TruePvPRatio_UI_DC", tlw, CT_LABEL)
    self.dcLabel:SetFont("ZoFontGamepad27")
    self.dcLabel:SetAnchor(TOPRIGHT, self.adLabel, BOTTOMRIGHT, 0, 8)
    self.dcLabel:SetColor(0.07, 0.36, 0.66, 1) 
    
    self.epLabel = WINDOW_MANAGER:CreateControl("TruePvPRatio_UI_EP", tlw, CT_LABEL)
    self.epLabel:SetFont("ZoFontGamepad27")
    self.epLabel:SetAnchor(TOPRIGHT, self.dcLabel, BOTTOMRIGHT, 0, 8)
    self.epLabel:SetColor(0.65, 0.16, 0.16, 1) 

    -- En-tetes du tableau (Releves a Y = 235)
    local function CreateHeader(name, text, offsetX, width, align)
        local lbl = WINDOW_MANAGER:CreateControl(name, tlw, CT_LABEL)
        lbl:SetFont("ZoFontGamepad22")
        lbl:SetColor(0.5, 0.5, 0.5, 1)
        lbl:SetAnchor(BOTTOMLEFT, tlw, TOPLEFT, offsetX, 235)
        lbl:SetDimensions(width, 35)
        lbl:SetHorizontalAlignment(align)
        lbl:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
        lbl:SetText(text)
        return lbl
    end

    CreateHeader("TruePvPRatio_H1", "Characters", 40, 240, TEXT_ALIGN_LEFT)
    CreateHeader("TruePvPRatio_H2", "Global", 280, 220, TEXT_ALIGN_CENTER)
    CreateHeader("TruePvPRatio_H3", "Cyrodiil", 500, 220, TEXT_ALIGN_CENTER)
    CreateHeader("TruePvPRatio_H4", "Imperial City", 720, 220, TEXT_ALIGN_CENTER)
    CreateHeader("TruePvPRatio_H5", "BG (Solo)", 940, 220, TEXT_ALIGN_CENTER)
    CreateHeader("TruePvPRatio_H6", "BG (Grp)", 1160, 220, TEXT_ALIGN_CENTER)

    -- Conteneur de la liste des personnages (Y = 245)
    self.tableContainer = WINDOW_MANAGER:CreateControl("TruePvPRatio_UI_TableContainer", tlw, CT_CONTROL)
    self.tableContainer:SetAnchor(TOPLEFT, tlw, TOPLEFT, 0, 245)
    self.tableContainer:SetAnchor(BOTTOMRIGHT, tlw, BOTTOMRIGHT, 0, -20)

    self.charRows = {}

    -- Scene Gamepad standard securisee
    self.scene = ZO_Scene:New("truePvPRatioGamepad", SCENE_MANAGER)
    self.scene:AddFragment(ZO_FadeSceneFragment:New(tlw))

    local keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_DIALOG_CLOSE),
            keybind = "UI_SHORTCUT_NEGATIVE", 
            callback = function() TruePvPRatio:ToggleUI() end,
        },
    }

    self.scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            self:UpdateUI()
            KEYBIND_STRIP:AddKeybindButtonGroup(keybindStripDescriptor)
        elseif newState == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindStripDescriptor)
        end
    end)

    self.uiCreated = true
end

function TruePvPRatio:UpdateUI()
    local sv = self.savedVars

    self.globalLabel:SetText(L_GLOBAL_RATIO .. FormatRatio(sv.global.kills, sv.global.deaths) .. "  (K "..sv.global.kills.." / D "..sv.global.deaths..") | Streak  " .. (sv.global.maxKillStreak or 0))

    local ad = sv.global.alliances[ALLIANCE_ALDMERI_DOMINION]
    local dc = sv.global.alliances[ALLIANCE_DAGGERFALL_COVENANT]
    local ep = sv.global.alliances[ALLIANCE_EBONHEART_PACT]
    
    self.adLabel:SetText("Aldmeri Dominion : " .. ad.kills .. " Kills / " .. ad.deaths .. " Deaths")
    self.dcLabel:SetText("Daggerfall Covenant : " .. dc.kills .. " Kills / " .. dc.deaths .. " Deaths")
    self.epLabel:SetText("Ebonheart Pact : " .. ep.kills .. " Kills / " .. ep.deaths .. " Deaths")

    local sortedChars = {}
    for name, data in pairs(sv.characters) do
        table.insert(sortedChars, {name = name, data = data, ratio = GetRatio(data.kills, data.deaths)})
    end

    -- Tri des personnages : Veterans (>= 1500 kills) en premier, puis par meilleur ratio
    table.sort(sortedChars, function(a, b) 
        local isAVeteran = (a.data.kills >= 1500)
        local isBVeteran = (b.data.kills >= 1500)
        if isAVeteran ~= isBVeteran then
            return isAVeteran
        end
        return a.ratio > b.ratio
    end)

    -- Hauteur calculee pour faire tenir exactement 15 personnages sans depasser de l'ecran
    local rowHeight = 52
    local fontName = "ZoFontGamepad20"

    for _, row in ipairs(self.charRows) do
        row.name:SetHidden(true)
        row.global:SetHidden(true)
        row.cyr:SetHidden(true)
        row.ic:SetHidden(true)
        row.bgSolo:SetHidden(true)
        row.bgGrp:SetHidden(true)
    end

    for i, charInfo in ipairs(sortedChars) do
        -- Strict maximum de 15 personnages a l'ecran
        if i > 15 then break end

        local row = self.charRows[i]
        local yOffset = (i - 1) * rowHeight

        if not row then
            row = {}
            row.name = WINDOW_MANAGER:CreateControl("TruePvPRatio_Row_"..i.."_Name", self.tableContainer, CT_LABEL)
            row.name:SetAnchor(TOPLEFT, self.tableContainer, TOPLEFT, 40, yOffset)
            row.name:SetDimensions(240, rowHeight)
            row.name:SetFont(fontName)
            row.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            row.name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            
            local function CreateStatCell(idx, x)
                local lbl = WINDOW_MANAGER:CreateControl("TruePvPRatio_Row_"..i.."_C"..idx, self.tableContainer, CT_LABEL)
                lbl:SetAnchor(TOPLEFT, self.tableContainer, TOPLEFT, x, yOffset)
                lbl:SetDimensions(220, rowHeight)
                lbl:SetFont(fontName)
                lbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                lbl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                return lbl
            end
            
            row.global = CreateStatCell(2, 280)
            row.cyr = CreateStatCell(3, 500)
            row.ic = CreateStatCell(4, 720)
            row.bgSolo = CreateStatCell(5, 940)
            row.bgGrp = CreateStatCell(6, 1160)
            
            table.insert(self.charRows, row)
        end
        
        local d = charInfo.data

        local nameColor = "FFFFFF"
        if d.alliance and ALLIANCE_COLORS[d.alliance] then
            nameColor = ALLIANCE_COLORS[d.alliance]
        end

        local classPrefix = ""
        if d.classId and CLASS_STYLES[d.classId] then
            local cStyle = CLASS_STYLES[d.classId]
            classPrefix = string.format("|c%s[%s]|r\n", cStyle.color, cStyle.text)
        end

        row.name:SetText(classPrefix .. "|c" .. nameColor .. charInfo.name .. "|r")

        -- Case globale (sur 2 lignes comme a l'origine)
        row.global:SetText(string.format("|cFFCC00K %d / D %d|r\n|cFFCC00Ratio %s | Streak %d|r", d.kills, d.deaths, FormatRatio(d.kills, d.deaths), d.maxKillStreak or 0))

        -- Fonction pour les modes specifiques avec tiret discret si vide
        local function FormatModeWithDash(k, deaths)
            if k == 0 and deaths == 0 then
                return "|c555555—|r"
            end
            return string.format("|cFFFFFFK %d / D %d|r\n|cAAAAAARatio %s|r", k, deaths, FormatRatio(k, deaths))
        end

        row.cyr:SetText(FormatModeWithDash(d.cyrodiil.kills, d.cyrodiil.deaths))
        row.ic:SetText(FormatModeWithDash(d.ic.kills, d.ic.deaths))
        row.bgSolo:SetText(FormatModeWithDash(d.bgSolo.kills, d.bgSolo.deaths))
        row.bgGrp:SetText(FormatModeWithDash(d.bgGroup.kills, d.bgGroup.deaths))

        row.name:SetHidden(false)
        row.global:SetHidden(false)
        row.cyr:SetHidden(false)
        row.ic:SetHidden(false)
        row.bgSolo:SetHidden(false)
        row.bgGrp:SetHidden(false)
    end
end

function TruePvPRatio:ToggleUI()
    if SCENE_MANAGER:IsShowing("truePvPRatioGamepad") then
        SCENE_MANAGER:Hide("truePvPRatioGamepad")
    else
        SCENE_MANAGER:Show("truePvPRatioGamepad")
    end
end

local isCampaignSceneActive = false
local isRefreshingKeybind = false
local campaignKeybindBtn = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    name = L_TITLE,
    keybind = "UI_SHORTCUT_TERTIARY", 
    callback = function() TruePvPRatio:ToggleUI() end,
}

local function RefreshCampaignKeybind()
    if isCampaignSceneActive and not isRefreshingKeybind then
        isRefreshingKeybind = true
        KEYBIND_STRIP:RemoveKeybindButton(campaignKeybindBtn)
        KEYBIND_STRIP:AddKeybindButton(campaignKeybindBtn)
        isRefreshingKeybind = false
    end
end

local function RegisterCampaignMenuKeybind()
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
        local name = scene:GetName()
        if name and string.find(string.lower(name), "campaign") and string.find(string.lower(name), "gamepad") then
            if newState == SCENE_SHOWING then
                isCampaignSceneActive = true
                RefreshCampaignKeybind()
            elseif newState == SCENE_HIDDEN then
                isCampaignSceneActive = false
                KEYBIND_STRIP:RemoveKeybindButton(campaignKeybindBtn)
            end
        end
    end)
    SecurePostHook(KEYBIND_STRIP, "AddKeybindButtonGroup", RefreshCampaignKeybind)
end

function TruePvPRatio:Initialize()
    self.savedVars = ZO_SavedVars:NewAccountWide("TruePvPRatio_Data", 1, nil, GetDefaults())
    
    CleanupDeletedCharacters()

    if not self.savedVars.global.maxKillStreak then
        self.savedVars.global.maxKillStreak = 0
    end

    for cName, cData in pairs(self.savedVars.characters) do
        cData.maxKillStreak = cData.maxKillStreak or 0
        cData.currentKillStreak = cData.currentKillStreak or 0
        
        if not cData.cyrodiil then cData.cyrodiil = {kills = 0, deaths = 0} end
        if not cData.ic then cData.ic = {kills = 0, deaths = 0} end
        if not cData.bgSolo then cData.bgSolo = {kills = 0, deaths = 0} end
        if not cData.bgGroup then cData.bgGroup = {kills = 0, deaths = 0} end
    end

    local charName = zo_strformat("<<1>>", GetUnitName("player"))
    local currentClassId = GetUnitClassId("player")
    local currentAlliance = GetUnitAlliance("player")

    if not self.savedVars.characters[charName] then
        self.savedVars.characters[charName] = {
            kills = 0, deaths = 0, maxKillStreak = 0, currentKillStreak = 0,
            cyrodiil = {kills = 0, deaths = 0},
            ic = {kills = 0, deaths = 0},
            bgSolo = {kills = 0, deaths = 0},
            bgGroup = {kills = 0, deaths = 0},
            classId = currentClassId,
            alliance = currentAlliance,
        }
    else
        self.savedVars.characters[charName].classId = currentClassId
        self.savedVars.characters[charName].alliance = currentAlliance
    end

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PVP_KILL_FEED_DEATH, OnPvPKillFeedDeath)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GROUP_UPDATE, UpdatePremadeGroupStatus)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GROUP_MEMBER_JOINED, UpdatePremadeGroupStatus)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GROUP_MEMBER_LEFT, UpdatePremadeGroupStatus)
    
    self:BuildUI()
    RegisterCampaignMenuKeybind()
end

local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= TruePvPRatio.name then return end
    EVENT_MANAGER:UnregisterForEvent(TruePvPRatio.name, EVENT_ADD_ON_LOADED)
    TruePvPRatio:Initialize()
end

EVENT_MANAGER:RegisterForEvent(TruePvPRatio.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)