-- Finder.lua – DungeonFinderPlus
DungeonFinderPlus = DungeonFinderPlus or {}
local DFP = DungeonFinderPlus
local L   = (DFP.i18n and DFP.i18n.L) or function(k) return k end

DFP.Finder = DFP.Finder or {}

-- ──────────────────────────────────────────────────────────────
-- State / SavedVariables
-- ──────────────────────────────────────────────────────────────
local LIST
local DATA        = {}
local SELECTION   = {}
local ROW_MODE    = {}
local SEARCH_TEXT = ""

local function SV()
    DFP.sv = DFP.sv or {
        queueVeteran = false,
        autoconfirm  = true,
    }
    return DFP.sv
end

-- LibSets holen
local function GetLibSets()
    return rawget(_G, "LibSets")
end

-- ──────────────────────────────────────────────────────────────
-- KeybindStrip: E = Autoconfirm an/aus
-- ──────────────────────────────────────────────────────────────
local _dfpKeybindGroup
local _dfpKeybindActive = false

function DFP.Finder:ActivateKeybinds()
    if not KEYBIND_STRIP then return end

    if not _dfpKeybindGroup then
        _dfpKeybindGroup = {
            alignment = KEYBIND_STRIP_ALIGN_CENTER,
            {
                name = function()
                    local label = L("opt_autoconfirm")
                    local state = SV().autoconfirm and L("state_on") or L("state_off")
                    return string.format("%s: %s", label, state)
                end,
                keybind = "UI_SHORTCUT_PRIMARY", -- E
                callback = function()
                    SV().autoconfirm = not SV().autoconfirm
                    if KEYBIND_STRIP and _dfpKeybindGroup then
                        KEYBIND_STRIP:UpdateKeybindButtonGroup(_dfpKeybindGroup)
                    end
                end,
            },
        }
    end

    if _dfpKeybindActive then return end
    KEYBIND_STRIP:AddKeybindButtonGroup(_dfpKeybindGroup)
    _dfpKeybindActive = true
end

function DFP.Finder:DeactivateKeybinds()
    if KEYBIND_STRIP and _dfpKeybindGroup and _dfpKeybindActive then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(_dfpKeybindGroup)
        _dfpKeybindActive = false
    end
end

-- ──────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────
local function latinFold(s)
    if not s then return "" end
    s = s:gsub("Ä","Ae"):gsub("Ö","Oe"):gsub("Ü","Ue")
         :gsub("ä","ae"):gsub("ö","oe"):gsub("ü","ue"):gsub("ß","ss")
    s = s
        :gsub("[ÁÀÂÃÅĀĂĄ]","A"):gsub("[áàâãåāăą]","a")
        :gsub("[ÉÈÊËĒĔĖĘĚ]","E"):gsub("[éèêëēĕėęě]","e")
        :gsub("[ÍÌÎÏĪĬĮİ]","I"):gsub("[íìîïīĭįı]","i")
        :gsub("[ÓÒÔÕØŌŎŐ]","O"):gsub("[óòôõøōŏő]","o")
        :gsub("[ÚÙÛÜŪŬŮŰŲ]","U"):gsub("[úùûüūŭůűų]","u")
    return s
end

local function norm(s)
    if not s then return "" end
    s = s:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    s = latinFold(s):gsub("—","-"):gsub("–","-")
    s = s:gsub("%b()", ""):gsub("[%[%]]","")
    s = s:gsub("[%s%-:]+([IVXivx]+)$", " %1")
    s = s:gsub("%s+", " ")
    return zo_strlower(zo_strtrim(s))
end

local function SetFooterStatus(key)
    if DFP_WindowFooterStatus then
        DFP_WindowFooterStatus:SetText(L(key))
    end
end

local function IsFourPlayerActivity(id)
    if not id or not GetActivityInfo then return false end
    local _, _, _, _, _, _, minGroupSize = GetActivityInfo(id)
    return minGroupSize == 4
end

local function isVisibleDungeon(entry)
    return IsFourPlayerActivity(entry.actN) or IsFourPlayerActivity(entry.actV)
end

-- Flamechasers-Pledge-Check (bevorzugt Activity-ID-Treffer)
local function isRowPledge(row)
    if not row then return false end
    local pledges = DFP.Pledges
    if not pledges then return false end

    -- 1. Sicherster Check über die LFG Activity-IDs (Normal oder Vet)
    local actMap = pledges.activeActivities
    if actMap then
        if row.actN and actMap[row.actN] then return true end
        if row.actV and actMap[row.actV] then return true end
    end

    -- 2. Fallback über den Flamechasers-Key (Name ohne Satz-/Leerzeichen)
    local keyMap = pledges.active
    if keyMap and row.name then
        local k = zo_strformat("<<C:1>>", row.name):lower():gsub("[%p%s%c]+", "")
        if keyMap[k] then return true end
    end

    return false
end

-- ──────────────────────────────────────────────────────────────
-- Achievements
-- ──────────────────────────────────────────────────────────────
local function formatAchievementDate(ts)
    if not ts then return nil end
    if GetDateStringFromTimestamp then
        return GetDateStringFromTimestamp(ts)
    end
    return tostring(ts)
end

local function achInfo(id)
    if not id or not GetAchievementInfo then return nil end

    local name, _, _, _, completed = GetAchievementInfo(id)
    if not name or name == "" then return nil end

    name = zo_strformat(SI_UNIT_NAME, name)

    local dateText
    if completed and GetAchievementTimestamp and GetDateStringFromTimestamp then
        local ts = GetAchievementTimestamp(id)
        if ts and ts > 0 then
            dateText = GetDateStringFromTimestamp(ts)
        end
    end

    return {
        id       = id,
        name     = name,
        done     = completed and true or false,
        dateText = dateText,
    }
end

local function getAchievementStatsForRow(row)
    if not row then return nil end
    if not (row.actN or row.actV) then return nil end

    local data = DFP.GetDungeonAchievementsForActivity
        and DFP.GetDungeonAchievementsForActivity(row.actN, row.actV)
    
    if not data then return nil end

    return {
        normal = achInfo(data.normal),
        vet    = achInfo(data.vet),
        hm     = achInfo(data.hm),
        tt     = achInfo(data.tt),
        nd     = achInfo(data.nd),
        tri    = achInfo(data.tri),
        motif  = achInfo(data.motif),
    }
end

-- ──────────────────────────────────────────────────────────────
-- Sets über LibSets 
-- ──────────────────────────────────────────────────────────────
local function getSetsForActivity(activityId)
    local LS = GetLibSets()
    if not (LS and activityId and GetActivityZoneId) then
        return nil
    end

    local zoneId = GetActivityZoneId(activityId)
    if not zoneId or zoneId == 0 then
        return nil
    end

    local setIdsByZone = LS.GetSetIdsByDropZone and LS.GetSetIdsByDropZone(zoneId)
    if type(setIdsByZone) ~= "table" then
        return nil
    end

    local out = {}
    for setId, _ in pairs(setIdsByZone) do
        local name = LS.GetSetName and LS.GetSetName(setId)
        if name and name ~= "" then
            local isMonster = LS.IsMonsterSet and LS.IsMonsterSet(setId)
            if isMonster then
                name = "|cCC66FF" .. name .. "|r"
            end
            out[#out+1] = name
        end
    end

    if #out == 0 then
        return nil
    end

    table.sort(out)
    return out
end

local function rowMatchesSearch(row, q)
    if q == "" then
        return true
    end

    -- 1) Dungeon-Name
    if row.name and norm(row.name):find(q, 1, true) then
        return true
    end

    -- 2) Sets über LibSets
    local LS = GetLibSets()
    if not LS then
        return false
    end

    local function setsContain(activityId)
        if not activityId then return false end
        local sets = getSetsForActivity(activityId)
        if not sets then return false end

        for _, setName in ipairs(sets) do
            if norm(setName):find(q, 1, true) then
                return true
            end
        end
        return false
    end

    if setsContain(row.actN) or setsContain(row.actV) then
        return true
    end

    return false
end

-- ──────────────────────────────────────────────────────────────
-- Tooltips
-- ──────────────────────────────────────────────────────────────
local function buildTooltipText(row)
    if not row then return "" end
    local lines = {}

    -- Titel
    lines[#lines+1] = "|cFFD700" .. (row.name or "?") .. "|r"

    ----------------------------------------------------------------
    -- PLEDGE HEUTE?
    ----------------------------------------------------------------
    if row.isPledge then
        lines[#lines+1] = "|cFFFF00" .. L("tt_pledge_today") .. "|r"
    end

    ----------------------------------------------------------------
    -- Achievements
    ----------------------------------------------------------------
    local stats = getAchievementStatsForRow(row)
    if stats then
        lines[#lines+1] = ""
        lines[#lines+1] = "|cA5FF7C" .. L("tt_stats_header") .. "|r"

        local function addAchLine(label, info)
            if not info or not info.name then return end
            
            local icon = info.done 
                and "|t16:16:esoui/art/buttons/accept_up.dds|t"
                or  "|t16:16:esoui/art/buttons/decline_up.dds|t"
            
            local color = info.done and "|cCCFFCC" or "|cFFCCCC"
            local dateStr = ""
            if info.done and info.dateText then
                dateStr = " |c888888(" .. info.dateText .. ")|r"
            end
            
            lines[#lines+1] = string.format("%s %s: %s%s%s|r", 
                icon, label, color, info.name, dateStr
            )
        end

        if stats.normal then addAchLine(L("tt_ach_normal"), stats.normal) end
        if stats.vet    then addAchLine(L("tt_ach_vet"), stats.vet) end
        if stats.hm     then addAchLine(L("tt_ach_hm"), stats.hm) end
        if stats.tt     then addAchLine(L("tt_ach_speed"), stats.tt) end
        if stats.nd     then addAchLine(L("tt_ach_nodeath"), stats.nd) end
        if stats.tri    then addAchLine(L("tt_ach_tri"), stats.tri) end
        if stats.motif  then addAchLine(L("tt_ach_motif"), stats.motif) end
    end

    ----------------------------------------------------------------
    -- Sets
    ----------------------------------------------------------------
    local LS = GetLibSets()
    if LS then
        local normalSets = getSetsForActivity(row.actN)
        local vetSets    = getSetsForActivity(row.actV)

        if normalSets or vetSets then
            lines[#lines+1] = ""
            lines[#lines+1] = "|cA5FF7C" .. L("tt_sets_header") .. "|r"

            if normalSets then
                lines[#lines+1] = "|cCCCCCC" .. L("tt_sets_normal") .. "|r"
                for _, name in ipairs(normalSets) do
                    local color = "|cFFFFFF"
                    if name:find("Schulter") or name:find("Kopf") or name:find("Shoulder") or name:find("Head") then
                        color = "|cA020F0"
                    end
                    lines[#lines+1] = "  - " .. color .. name .. "|r"
                end
            end

            if vetSets and (not normalSets or #vetSets ~= #normalSets) then
                lines[#lines+1] = "|cCCCCCC" .. L("tt_sets_vet") .. "|r"
                for _, name in ipairs(vetSets) do
                    local color = "|cFFFFFF"
                    if name:find("Schulter") or name:find("Kopf") or name:find("Shoulder") or name:find("Head") then
                        color = "|cA020F0"
                    end
                    lines[#lines+1] = "  - " .. color .. name .. "|r"
                end
            end
        end
    end

    return table.concat(lines, "\n")
end

function DFP.Finder:OnRowMouseEnter(control)
    if not control or not InformationTooltip then return end
    local row = control.data
    if not row then return end

    InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, 0, TOPRIGHT)
    InformationTooltip:ClearLines()
    InformationTooltip:AddLine(buildTooltipText(row))
end

function DFP.Finder:OnRowMouseExit(control)
    if InformationTooltip then
        ClearTooltip(InformationTooltip)
    end
end

-- ──────────────────────────────────────────────────────────────
-- Datenaufbau
-- ──────────────────────────────────────────────────────────────
function DFP.Finder:RebuildData()
    DATA, SELECTION = {}, SELECTION or {}

    if not DFP.Dungeons or type(DFP.Dungeons.Iter) ~= "function" then
        SetFooterStatus("status_api_missing")
        return
    end

    for key, e in DFP.Dungeons:Iter() do
        if key and e and (e.normalId or e.vetId) then
            local name = e.pretty or key
            local entry = {
                key      = key,
                name     = name,
                actN     = e.normalId,
                actV     = e.vetId,
                isDLC    = e.isDLC and true or false,
                isPledge = false,
            }
            entry.isPledge = isRowPledge(entry)

            if isVisibleDungeon(entry) then
                DATA[#DATA+1] = entry
            end
        end
    end

    table.sort(DATA, function(a, b)
        if a.isPledge ~= b.isPledge then
            return a.isPledge
        end
        return (a.name or a.key) < (b.name or b.key)
    end)

    SetFooterStatus("status_ready")
end

function DFP.Finder:QuickPledgeUpdate()
    if not DATA or #DATA == 0 then return end

    for _, row in ipairs(DATA) do
        row.isPledge = isRowPledge(row)
    end

    table.sort(DATA, function(a, b)
        if a.isPledge ~= b.isPledge then
            return a.isPledge
        end
        return (a.name or a.key) < (b.name or b.key)
    end)

    local t, q = {}, SEARCH_TEXT
    for _, row in ipairs(DATA) do
        if rowMatchesSearch(row, q) then
            t[#t+1] = row
        end
    end

    if LIST then
        local dataList = ZO_ScrollList_GetDataList(LIST)
        ZO_ScrollList_Clear(LIST)
        for _, row in ipairs(t) do
            table.insert(dataList, ZO_ScrollList_CreateDataEntry(1, row))
        end
        ZO_ScrollList_Commit(LIST)
    end
end

-- ──────────────────────────────────────────────────────────────
-- UI-Liste / Suche
-- ──────────────────────────────────────────────────────────────
local function refreshList()
    if not LIST then return end

    local t, q = {}, SEARCH_TEXT
    for _, row in ipairs(DATA) do
        if rowMatchesSearch(row, q) then
            t[#t+1] = row
        end
    end

    local dataList = ZO_ScrollList_GetDataList(LIST)
    ZO_ScrollList_Clear(LIST)
    for _, row in ipairs(t) do
        table.insert(dataList, ZO_ScrollList_CreateDataEntry(1, row))
    end
    ZO_ScrollList_Commit(LIST)

    if DFP_WindowFooterStatus then
        DFP_WindowFooterStatus:SetText(string.format("%d / %d", #t, #DATA))
    end
end

function DFP.Finder:OnSearchChanged()
    if DFP_WindowSearchRowSearchBackdropEdit then
        SEARCH_TEXT = norm(DFP_WindowSearchRowSearchBackdropEdit:GetText() or "")
        SV().lastSearch = SEARCH_TEXT
    else
        SEARCH_TEXT = ""
    end
    refreshList()
end

-- Hook für XML
function DungeonFinderPlus.OnSearchTextChanged()
    if DFP and DFP.Finder and DFP.Finder.OnSearchChanged then
        DFP.Finder:OnSearchChanged()
    end
end

-- ──────────────────────────────────────────────────────────────
-- Auto-Confirm (Ready-Check)
-- ──────────────────────────────────────────────────────────────
local _autoHooked = false

local function onActivityFinderStatus(status)
    if not SV().autoconfirm then return end
    if status == ACTIVITY_FINDER_STATUS_READY_CHECK then
        AcceptLFGReadyCheckNotification()
    end
end

function DFP.Finder:SetupAutoConfirm()
    if _autoHooked then return end
    if ZO_ACTIVITY_FINDER_ROOT_MANAGER and ZO_ACTIVITY_FINDER_ROOT_MANAGER.RegisterCallback then
        ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnActivityFinderStatusUpdate", onActivityFinderStatus)
    end
    _autoHooked = true
end

-- ──────────────────────────────────────────────────────────────
-- Init
-- ──────────────────────────────────────────────────────────────
function DFP.Finder:EnsureInit()
    if LIST then return end

    LIST = DFP_WindowListScroll
    if not LIST then
        SetFooterStatus("status_api_missing")
        return
    end

    DFP.Dungeons = DFP.Dungeons or {}

    if type(DFP.Dungeons.Rebuild) ~= "function" then
        DFP.Dungeons.Rebuild = function() end
    end
    if type(DFP.Dungeons.Iter) ~= "function" then
        DFP.Dungeons.Iter = function()
            return function() return nil end
        end
    end

    DFP.Dungeons:Rebuild()

    ZO_ScrollList_Clear(LIST)
    ZO_ScrollList_AddDataType(LIST, 1, "DungeonFinderPlus_Row", 32, function(row, d)
        -- Für Tooltip
        row.data = d

        local check = row:GetNamedChild("Check")
        local nameL = row:GetNamedChild("Name")
        local typeL = row:GetNamedChild("Type")
        local btnN  = row:GetNamedChild("ModeNormal")
        local btnV  = row:GetNamedChild("ModeVet")

        -- Auswahl-Checkbox
        ZO_CheckButton_SetCheckState(check, SELECTION[d.key] or false)
        ZO_CheckButton_SetToggleFunction(check, function(_, state)
            SELECTION[d.key] = state and true or false
        end)

        -- Name (Pledges gelb)
        nameL:SetText(d.isPledge and ("|cFFFF00" .. d.name .. "|r") or d.name)

        -- Typ (DLC/Base)
        typeL:SetText(d.isDLC and L("label_type_dlc") or L("label_type_base"))

        -- Vet/Normal Buttons 
        local mode = ROW_MODE[d.key]
        if type(mode) ~= "table" then
            local wantVet
            if type(mode) == "boolean" then
                wantVet = mode
            else
                wantVet = SV().queueVeteran or false
            end
            mode = {
                n = not wantVet,
                v = wantVet,
            }
            ROW_MODE[d.key] = mode
        end

        local function refreshButtons()
            local tN, tV = L("btn_mode_normal"), L("btn_mode_vet")
            if mode.n then
                btnN:SetText("|cA5FF7C" .. tN .. "|r")
            else
                btnN:SetText(tN)
            end
            if mode.v then
                btnV:SetText("|cA5FF7C" .. tV .. "|r")
            else
                btnV:SetText(tV)
            end
        end

        btnN:SetHandler("OnClicked", function()
            mode.n = not mode.n
            if not mode.n and not mode.v then
                mode.n = true
            end
            refreshButtons()
        end)

        btnV:SetHandler("OnClicked", function()
            mode.v = not mode.v
            if not mode.n and not mode.v then
                mode.v = true
            end
            refreshButtons()
        end)

        refreshButtons()
    end)

    ZO_ScrollList_EnableHighlight(LIST, "ZO_ThinListHighlight")

    -- Labels / Buttons lokalisieren
    if DFP_WindowToolbarTitle                 then DFP_WindowToolbarTitle:SetText(L("title")) end
    if DFP_WindowToolbarClose                 then DFP_WindowToolbarClose:SetText(L("btn_close")) end
    if DFP_WindowSearchRowButtonsBtnSelectAll then DFP_WindowSearchRowButtonsBtnSelectAll:SetText(L("btn_select_all")) end
    if DFP_WindowSearchRowButtonsBtnClearSel  then DFP_WindowSearchRowButtonsBtnClearSel:SetText(L("btn_clear_sel")) end
    if DFP_WindowSearchRowButtonsBtnAllNormal then DFP_WindowSearchRowButtonsBtnAllNormal:SetText(L("btn_all_normal")) end
    if DFP_WindowSearchRowButtonsBtnAllVet    then DFP_WindowSearchRowButtonsBtnAllVet:SetText(L("btn_all_vet")) end
    if DFP_WindowFooterQueueBtn               then DFP_WindowFooterQueueBtn:SetText(L("btn_queue_selection")) end
    if DFP_WindowFooterStatus                 then DFP_WindowFooterStatus:SetText(L("status_ready")) end
    if DFP_WindowToolbarAuthor                then DFP_WindowToolbarAuthor:SetText(L("label_author", "@LugenKrebs")) end

    self:SetupAutoConfirm()
end

-- ──────────────────────────────────────────────────────────────
-- Buttons / Aktionen
-- ──────────────────────────────────────────────────────────────
function DFP.Finder:SelectAll(v)
    for _, row in ipairs(DATA) do
        SELECTION[row.key] = v and true or false
    end
    refreshList()
end

function DFP.Finder:BtnSelectAll()
    self:SelectAll(true)
end

function DFP.Finder:BtnClearSelection()
    self:SelectAll(false)
end

function DFP.Finder:SetAllModes(vet)
    for _, row in ipairs(DATA) do
        local mode = ROW_MODE[row.key]
        if type(mode) ~= "table" then mode = {} end
        mode.n = not vet
        mode.v = vet
        ROW_MODE[row.key] = mode
    end
    refreshList()
end

function DFP.Finder:BtnAllNormal()
    self:SetAllModes(false)
end

function DFP.Finder:BtnAllVet()
    self:SetAllModes(true)
end

function DFP.Finder:SetSearchText(txt)
    if DFP_WindowSearchRowSearchBackdropEdit then
        DFP_WindowSearchRowSearchBackdropEdit:SetText(txt or "")
    end
    self:OnSearchChanged()
end

-- ──────────────────────────────────────────────────────────────
-- Queue
-- ──────────────────────────────────────────────────────────────
local function queueActivities(ids, wantVetPreference)
    if type(ClearGroupFinderSearch) ~= "function"
        or type(AddActivityFinderSpecificSearchEntry) ~= "function"
        or type(StartGroupFinderSearch) ~= "function" then
        d("[DFP] Queue API missing: require ClearGroupFinderSearch, AddActivityFinderSpecificSearchEntry, StartGroupFinderSearch.")
        return
    end

    if wantVetPreference ~= nil and type(SetVeteranDifficulty) == "function" then
        SetVeteranDifficulty(wantVetPreference and true or false)
    end

    ClearGroupFinderSearch()
    for _, id in ipairs(ids) do
        AddActivityFinderSpecificSearchEntry(id)
    end
    StartGroupFinderSearch()
end

function DFP.Finder:QueueSelection()
    local ids, any = {}, false

    for _, row in ipairs(DATA) do
        if SELECTION[row.key] then
            any = true

            local mode = ROW_MODE[row.key]
            if type(mode) ~= "table" then
                local wantVet = (mode == true) or (mode == nil and (SV().queueVeteran and true or false))
                mode = { n = not wantVet, v = wantVet }
                ROW_MODE[row.key] = mode
            end

            local addedForRow = false

            -- Normal
            if mode.n ~= false and row.actN then
                ids[#ids+1] = row.actN
                addedForRow = true
            end

            -- Vet
            if mode.v and row.actV then
                ids[#ids+1] = row.actV
                addedForRow = true
            end

            if not addedForRow then
                if mode.v and not row.actV then
                    d("|cFF4444[DFP]|r '" .. (row.name or row.key or "?") .. "' no vet id found.")
                elseif (mode.n ~= false) and not row.actN then
                    d("|cFF4444[DFP]|r '" .. (row.name or row.key or "?") .. "' no normal id found.")
                end
            end
        end
    end

    if not any or #ids == 0 then
        SetFooterStatus("status_no_ids")
        return
    end

    queueActivities(ids, nil)
    SetFooterStatus("status_queue_started")
end

function DFP.Finder:Open()
    if DFP.ShowWindow then
        DFP.ShowWindow()
    end
end