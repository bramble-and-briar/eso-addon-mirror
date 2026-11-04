--[[
    PvPTargetInfo_ProcCD.lua  (v2.1.0 新規)

    UI④ Self Proc CD: 自分の装備セットProc発動後、再発動可能になるまでの
    残り時間を縦並びで表示する。

    ■ 仕組み(Srendarrの仕組みを調べて独自実装。コード・データ表は複写していない)
      1. 装備セットの自動判別 … 装備スロットを走査しGetItemLinkSetInfoでセット名を得る。
         装備変更時(EVENT_INVENTORY_SINGLE_SLOT_UPDATE等)にだけ再取得する(常時走査しない)。
      2. Proc発動の検知 … UI③と同じ「自分のバフをGetUnitBuffInfoで走査する方式」
         (UI③でPS5実機動作の実績あり)で、Procバフの出現/開始時刻の更新を検知する。
         EVENT_EFFECT_CHANGED等のイベントはPS5で届かない報告(PCL診断)があるため頼らない。
      3. 内部CDの追跡 … 発動時刻 + ICD秒数 = 終了時刻。発動検知(2)とCD追跡(3)は別管理。
         CD中の再検知は再起動しない(ICD中は発動しない前提)。
      4. ICD秒数の出所(上のA/B/C区分):
         - ユーザー登録(/pti cd add): 実測値。status=VERIFIED
         - ProcCDDataの定義表: 確認済みの値だけ
         - TOOLTIP: セット効果の説明文に「once every N seconds / N秒に1回」等が1種類だけ
           書かれている場合に限り、その値を採用(PS5実機未検証)
         - どれも無い場合は表示しない(推測しない)
      5. Procバフの特定 … ① AbilityId一致(定義表/ユーザー登録) ② バフ名=装備中セット名の一致。
         どちらでも特定できないProc(バフが付かないダメージ型など)は検知できないため表示しない。

    ■ 軽量化
      パネルON中だけ100msの1本のTickを動かす(バフ走査は200msごと、表示更新は変化時のみSetText)。
      パネルOFFまたはアドオンOFFの間は、Tick・イベントを全て解除する。
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo
PTI.ProcCD = PTI.ProcCD or {}
local CD = PTI.ProcCD

local TICK_MS = 100
local SCAN_EVERY = 2 -- 100ms x 2 = 200msごとにバフ走査
local READY_TEXT = "READY"

-- 標準配色(固定。設定では変更しない)
local COLOR_WHITE  = { 0.949, 0.949, 0.949, 1 } -- #F2F2F2 パネルタイトル・セット名
local COLOR_YELLOW = { 1.000, 0.761, 0.278, 1 } -- #FFC247 CD残り秒数
local COLOR_GREEN  = { 0.333, 0.839, 0.545, 1 } -- #55D68B READY

local running = false
local equippedDirty = true
local tickCount = 0
local lastHasContent = nil

local equippedSets = {} -- 正規化セット名 -> { name, cd(説明文から。無ければnil) }
local entryById = {}    -- AbilityId -> { key, name, cd, status }
local entryByName = {}  -- 正規化名 -> 定義表の項目(cd未確認も含む)
local states = {}       -- key -> { name, cd, startAt, endAt, ready }
local presentPrev, presentNow = {}, {}
local list, listCount = {}, 0

local function NormName(text)
    if type(text) ~= "string" or text == "" then return "" end
    return zo_strlower(zo_strformat("<<t:1>>", text))
end

--------------------------------------------------------------------------
-- 説明文からのICD読み取り(TOOLTIP)。PS5実機・日本語クライアントでの文言は未検証。
-- 「once every N seconds」「N秒に1回」型だけを採用する(持続時間・ティック間隔と混同しない)
--------------------------------------------------------------------------
local function ParseCooldownText(text)
    if type(text) ~= "string" or text == "" then return nil end
    local s = zo_strlower(text)
    local v = s:match("once every ([%d%.]+) seconds?")
        or s:match("once per ([%d%.]+) seconds?")
        or s:match("([%d%.]+)%s*秒に%s*1%s*回")
        or s:match("([%d%.]+)%s*秒に%s*1%s*度")
        or s:match("([%d%.]+)%s*秒に%s*一%s*度")
    local n = tonumber(v)
    if n and n > 0 and n <= 120 then return n end
    return nil
end

local function ParseSetCooldown(itemLink, numBonuses)
    if not GetItemLinkSetBonusInfo or type(numBonuses) ~= "number" then return nil end
    local found, count = nil, 0
    for i = 1, numBonuses do
        local ok, _, desc = pcall(GetItemLinkSetBonusInfo, itemLink, true, i)
        if ok then
            local n = ParseCooldownText(desc)
            if n then
                if found ~= n then count = count + 1 end
                found = n
            end
        end
    end
    -- 複数の異なる秒数が書かれている(複数効果のセット)場合は曖昧なので採用しない
    if count == 1 then return found end
    return nil
end

--------------------------------------------------------------------------
-- 定義の索引(定義表 + ユーザー登録)
--------------------------------------------------------------------------
local function RebuildIndex()
    ZO_ClearTable(entryById)
    ZO_ClearTable(entryByName)
    local data = PTI.CDData and PTI.CDData.entries or {}
    for _, e in ipairs(data) do
        for _, nm in ipairs(e.names or {}) do
            entryByName[NormName(nm)] = e
        end
        if type(e.cd) == "number" and e.cd > 0 then
            for _, id in ipairs(e.ids or {}) do
                entryById[id] = { key = "d:" .. e.key, name = nil, cd = e.cd, status = e.status }
            end
        end
    end
    local user = PTI.sv and PTI.sv.cd and PTI.sv.cd.user or {}
    for id, u in pairs(user) do
        local n = tonumber(id)
        if n and type(u) == "table" and type(u.cd) == "number" and u.cd > 0 then
            entryById[n] = { key = "u:" .. n, name = u.name, cd = u.cd, status = "VERIFIED" }
        end
    end
end

--------------------------------------------------------------------------
-- 装備セットの判別(装備変更時のみ)
--------------------------------------------------------------------------
local function RescanEquipped()
    equippedDirty = false
    ZO_ClearTable(equippedSets)
    local size = GetBagSize(BAG_WORN) or 0
    for slot = 0, size - 1 do
        local link = GetItemLink(BAG_WORN, slot)
        if link and link ~= "" then
            local hasSet, setName, numBonuses = GetItemLinkSetInfo(link, true)
            if hasSet and type(setName) == "string" and setName ~= "" then
                local k = NormName(setName)
                if not equippedSets[k] then
                    equippedSets[k] = { name = zo_strformat("<<t:1>>", setName), cd = ParseSetCooldown(link, numBonuses) }
                end
            end
        end
    end
    -- 外したセットの名前照合行は消す(AbilityId登録分は残す)
    for key, st in pairs(states) do
        if st.byName and not equippedSets[st.byName] then states[key] = nil end
    end
end

--------------------------------------------------------------------------
-- バフ -> Proc特定
-- 戻り値: key, cd, 表示名, 名前照合ならその正規化名
--------------------------------------------------------------------------
local function Resolve(buffName, abilityId)
    local e = entryById[abilityId]
    if e then return e.key, e.cd, e.name or buffName, nil end

    local nm = NormName(buffName)
    local set = equippedSets[nm]
    if set then
        local def = entryByName[nm]
        local cd = (def and type(def.cd) == "number" and def.cd > 0) and def.cd or set.cd
        if cd then return "n:" .. nm, cd, buffName, nm end
    end
    return nil
end

local function OnProc(key, name, cd, byName, startTime, now)
    local st = states[key]
    if st and now < st.endAt then return end -- CD中の再検知は再起動しない
    local startAt = startTime
    if type(startAt) ~= "number" or startAt <= 0 or startAt > now then startAt = now end
    if now - startAt >= cd then return end -- 既にCD経過済みの古いバフ(ログイン時等)は対象外
    if not st then st = {}; states[key] = st end
    st.name, st.cd, st.byName = name, cd, byName
    st.startAt, st.endAt, st.ready = startAt, startAt + cd, false
end

local function ScanBuffs(now)
    ZO_ClearTable(presentNow)
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local buffName, startTime, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if type(buffName) == "string" and buffName ~= "" then
            local key, cd, shown, byName = Resolve(buffName, abilityId)
            if key and not presentNow[key] then
                local stamp = (type(startTime) == "number") and startTime or now
                presentNow[key] = stamp
                local prev = presentPrev[key]
                -- 新規出現、またはバフの開始時刻が更新された(再発動)時だけProcとして扱う
                if prev == nil or zo_abs(stamp - prev) > 0.05 then
                    OnProc(key, shown or buffName, cd, byName, stamp, now)
                end
            end
        end
    end
    presentPrev, presentNow = presentNow, presentPrev
end

--------------------------------------------------------------------------
-- 表示
--------------------------------------------------------------------------
local function SortList(a, b)
    if a.ready ~= b.ready then return not a.ready end
    if not a.ready then return a.remain < b.remain end
    return a.name < b.name
end

local function SetRow(row, name, timeText, isReady)
    local mode = isReady and 2 or 1
    if row.cdMode ~= mode or not row.cdInit then
        row.nameLabel:SetFont(PTI.UI.RowFont("cd"))
        row.timeLabel:SetFont(PTI.UI.RowFont("cd"))
        PTI.UI.ApplyOutline(row.nameLabel)
        PTI.UI.ApplyOutline(row.timeLabel)
        row.nameLabel:SetColor(COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3], 1)
        local c = isReady and COLOR_GREEN or COLOR_YELLOW
        row.timeLabel:SetColor(c[1], c[2], c[3], 1)
        row.cdMode, row.cdInit = mode, true
    end
    if row.cdName ~= name then row.nameLabel:SetText(name); row.cdName = name end
    if row.cdTime ~= timeText then row.timeLabel:SetText(timeText); row.cdTime = timeText end
end

local function Render(now)
    local sv = PTI.sv.cdUI
    local maxRows = sv.maxRows or 6
    local showReady = PTI.sv.cd.showReady ~= false
    local index = 0

    if PTI.sv.previewMode then
        -- 位置確認用サンプル(実際のCD値ではない)
        local samples = {
            { "サンプルA", "12.4", false }, { "サンプルB", "5.8", false }, { "サンプルC", READY_TEXT, true },
        }
        for _, s in ipairs(samples) do
            if index < maxRows then
                index = index + 1
                SetRow(PTI.UI.AcquireRow("cd", index), s[1], s[2], s[3])
            end
        end
    else
        listCount = 0
        for key, st in pairs(states) do
            local remain = st.endAt - now
            if remain <= 0 then st.ready = true end
            if st.ready and not showReady then
                states[key] = nil
            else
                listCount = listCount + 1
                local item = list[listCount]
                if not item then item = {}; list[listCount] = item end
                item.name, item.ready, item.remain = st.name, st.ready, remain
            end
        end
        for i = listCount + 1, #list do list[i] = nil end
        if listCount > 1 then table.sort(list, SortList) end
        for i = 1, listCount do
            if index < maxRows then
                index = index + 1
                local item = list[i]
                local row = PTI.UI.AcquireRow("cd", index)
                if item.ready then
                    SetRow(row, item.name, READY_TEXT, true)
                else
                    SetRow(row, item.name, string.format("%.1f", item.remain), false)
                end
            end
        end
    end

    PTI.UI.ReleaseUnusedRows("cd", index + 1)
    local has = index > 0
    PTI.UI.cdHasContent = has
    if has ~= lastHasContent then
        lastHasContent = has
        PTI.UI.SetWindowVisible("cd")
    end
end

local function OnTick()
    local now = GetGameTimeSeconds()
    if equippedDirty then RescanEquipped() end
    tickCount = tickCount + 1
    if tickCount % SCAN_EVERY == 0 and not PTI.sv.previewMode then ScanBuffs(now) end
    if listCount > 0 or next(states) ~= nil or PTI.sv.previewMode or lastHasContent then
        Render(now)
    end
end

local function OnEquipEvent()
    equippedDirty = true
end

--------------------------------------------------------------------------
-- 開始・停止(パネルOFF/アドオンOFFの間は全て解除して負荷ゼロにする)
--------------------------------------------------------------------------
local EVT = PTI.name .. "CD"

local function Start()
    if running then return end
    running = true
    RebuildIndex()
    equippedDirty = true
    tickCount = 0
    lastHasContent = nil
    EVENT_MANAGER:RegisterForEvent(EVT .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnEquipEvent)
    EVENT_MANAGER:AddFilterForEvent(EVT .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    EVENT_MANAGER:RegisterForEvent(EVT .. "Act", EVENT_PLAYER_ACTIVATED, OnEquipEvent)
    if EVENT_ARMORY_BUILD_RESTORE_RESPONSE then -- 存在未確認のため有る時だけ登録
        EVENT_MANAGER:RegisterForEvent(EVT .. "Armory", EVENT_ARMORY_BUILD_RESTORE_RESPONSE, OnEquipEvent)
    end
    EVENT_MANAGER:RegisterForUpdate(EVT .. "Tick", TICK_MS, OnTick)
end

local function Stop()
    if not running then return end
    running = false
    EVENT_MANAGER:UnregisterForUpdate(EVT .. "Tick")
    EVENT_MANAGER:UnregisterForEvent(EVT .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVT .. "Act", EVENT_PLAYER_ACTIVATED)
    if EVENT_ARMORY_BUILD_RESTORE_RESPONSE then
        EVENT_MANAGER:UnregisterForEvent(EVT .. "Armory", EVENT_ARMORY_BUILD_RESTORE_RESPONSE)
    end
    ZO_ClearTable(states)
    ZO_ClearTable(presentPrev)
    ZO_ClearTable(presentNow)
    listCount = 0
    lastHasContent = false
    PTI.UI.cdHasContent = false
    if PTI.UI.GetWindow("cd") then PTI.UI.ReleaseUnusedRows("cd", 1) end
end

-- 全体ON/OFFとUI④のON/OFFから現在の状態へ合わせる(何度呼んでも安全)
function CD.Sync()
    local sv = PTI.sv
    local want = sv and sv.enabled and sv.cdUI and sv.cdUI.enabled ~= false
    if want then Start() else Stop() end
end

function CD.Initialize()
    CD.Sync()
end

--------------------------------------------------------------------------
-- チャットコマンド /pti cd ...
--------------------------------------------------------------------------
local TAG = "|c55CCFF[PvPTargetInfo]|r "

local function SourceLabel(nm, set)
    local def = entryByName[nm]
    if def and type(def.cd) == "number" and def.cd > 0 then
        return string.format("%.1f秒 [%s]", def.cd, def.status or "DOCUMENTED")
    end
    if set.cd then return string.format("%.1f秒 [TOOLTIP・実機未検証]", set.cd) end
    return "ICD未確認(UNKNOWN)のため表示しません"
end

function CD.HandleCommand(rest)
    rest = rest or ""
    local sub, args = rest:match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()

    if sub == "on" or sub == "off" then
        PTI.sv.cdUI.enabled = (sub == "on")
        CD.Sync()
        PTI.UI.RefreshVisibility()
        d(TAG .. "UI④(Proc CD): " .. sub:upper())
    elseif sub == "sets" then
        RescanEquipped()
        local n = 0
        for nm, set in pairs(equippedSets) do
            n = n + 1
            d(TAG .. string.format(" - %s : %s", set.name, SourceLabel(nm, set)))
        end
        if n == 0 then d(TAG .. "装備中のセットが見つかりません。") end
    elseif sub == "text" then
        -- ICD読み取りに使うセット説明文の確認用(文言が合わない時の調査に使う)
        local size = GetBagSize(BAG_WORN) or 0
        local seen = {}
        for slot = 0, size - 1 do
            local link = GetItemLink(BAG_WORN, slot)
            if link and link ~= "" then
                local hasSet, setName, numBonuses = GetItemLinkSetInfo(link, true)
                if hasSet and not seen[setName] and GetItemLinkSetBonusInfo then
                    seen[setName] = true
                    for i = 1, (numBonuses or 0) do
                        local ok, _, desc = pcall(GetItemLinkSetBonusInfo, link, true, i)
                        -- 画面1枚に収めるため、秒数(「秒」/second)を含む説明だけ出す
                        if ok and type(desc) == "string" then
                            -- 「秒」/secondを含む文(。または.区切り)だけを出す(長い説明文でも1画面に収める)
                            for sentence in desc:gmatch("[^。]+。?") do
                                if sentence:find("秒") or zo_strlower(sentence):find("second") then
                                    d(TAG .. string.format("%s #%d: %s", zo_strformat("<<t:1>>", setName), i, sentence:sub(1, 150)))
                                end
                            end
                        end
                    end
                end
            end
        end
    elseif sub == "add" then
        local idStr, secStr, name = args:match("^(%d+)%s+([%d%.]+)%s*(.-)$")
        local id, sec = tonumber(idStr), tonumber(secStr)
        if id and sec and sec > 0 and sec <= 300 then
            PTI.sv.cd.user[id] = { cd = sec, name = (name ~= "" and name) or nil }
            RebuildIndex()
            d(TAG .. string.format("Proc CDを登録: AbilityId %d = %.1f秒 (実測値として扱います)", id, sec))
        else
            d(TAG .. "例: /pti cd add 12345 8 セット名  (AbilityId・ICD秒数・表示名(省略可)。ICDは実際に測った秒数)")
        end
    elseif sub == "del" then
        local id = tonumber(args)
        if id and PTI.sv.cd.user[id] then
            PTI.sv.cd.user[id] = nil
            RebuildIndex()
            d(TAG .. "削除しました: " .. id)
        else
            d(TAG .. "例: /pti cd del 12345")
        end
    elseif sub == "list" then
        local n = 0
        for id, u in pairs(PTI.sv.cd.user) do
            n = n + 1
            d(TAG .. string.format(" - [登録] %s / AbilityId %s / %.1f秒", tostring(u.name or GetAbilityName(tonumber(id)) or "?"), tostring(id), u.cd or 0))
        end
        for _, e in ipairs(PTI.CDData and PTI.CDData.entries or {}) do
            n = n + 1
            local cdText = (type(e.cd) == "number") and string.format("%.1f秒", e.cd) or "未確認"
            d(TAG .. string.format(" - [定義表] %s / %s [%s]", e.names and e.names[1] or e.key, cdText, e.status or "UNKNOWN"))
        end
        if n == 0 then d(TAG .. "登録はありません。") end
    elseif sub == "reset" then
        ZO_ClearTable(states)
        d(TAG .. "表示中のProc CDをリセットしました。")
    else
        d(TAG .. "/pti cd on||off  - UI④(Proc CD)のON/OFF")
        d(TAG .. "/pti cd sets     - 装備中セットごとのICDの出所を確認")
        d(TAG .. "/pti cd text     - ICD読み取りに使うセット説明文を表示(読み取りが合わない時の調査用)")
        d(TAG .. "/pti cd add <AbilityId> <秒> [名前] / del <AbilityId> / list - 実測したICDの登録")
        d(TAG .. "/pti cd reset    - 表示中のCDをリセット")
    end
end
