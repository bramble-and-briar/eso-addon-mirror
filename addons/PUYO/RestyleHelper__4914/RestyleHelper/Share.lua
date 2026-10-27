local RH = RestyleHelper
local L = RH.L

-- 実機で、投稿時259文字のリンクは正常、272文字のリンクは表示が崩れた。
-- 崩れを避けるため、これを超えるリンクは投稿しない
local CHAT_MAX_BYTES = 260
local NAME_MAX_CHARS = 20

---------------------------------------------------------------------------
-- 36進数
---------------------------------------------------------------------------
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

local function To36(n)
    n = math.floor(tonumber(n) or 0)
    if n <= 0 then return "0" end
    local t = {}
    while n > 0 do
        local r = n % 36
        table.insert(t, 1, DIGITS:sub(r + 1, r + 1))
        n = math.floor(n / 36)
    end
    return table.concat(t)
end

local function From36(s)
    return tonumber(s, 36)
end

RH.To36, RH.From36 = To36, From36

---------------------------------------------------------------------------
-- 名前の整形（区切り文字を除去、UTF-8で最大 NAME_MAX_CHARS 文字）
---------------------------------------------------------------------------
-- 文字の判定は byte() の数値、コピーは sub() だけで行う(パターン・string.char は使わない)
local BAD_BYTES = {}
for _, c in ipairs({ 124, 58, 91, 93, 96, 42, 95, 126, 92 }) do BAD_BYTES[c] = true end   -- | : [ ] ` * _ ~ \

function RH.SanitizeName(name)
    name = tostring(name or "")
    local out, count, started = {}, 0, false
    local lastSpace = 0
    for i = 1, #name do
        local c = name:byte(i)
        local piece = name:sub(i, i)
        if c >= 128 and c < 192 then
            -- UTF-8 の続きのバイト: 直前の文字にくっつける
            if started and #out > 0 and count <= NAME_MAX_CHARS then out[#out] = out[#out] .. piece end
        elseif c == 32 or (c > 32 and c ~= 127 and not BAD_BYTES[c]) then
            if not (c == 32 and not started) then
                count = count + 1
                if count > NAME_MAX_CHARS then break end
                out[#out + 1] = piece
                started = true
            end
        end
    end
    -- 末尾の空白を除く
    while #out > 0 and out[#out] == " " do out[#out] = nil end
    return table.concat(out)
end

---------------------------------------------------------------------------
-- エンコード / デコード
-- body = "slot.id.mat.p.s.a-slot.id.mat.p.s.a-..."（各値36進数）
-- 区切りに "." を使うのは Discord 等で "_" が斜体化されて消えるのを防ぐため（旧形式 "_" も読み込み可）
---------------------------------------------------------------------------
function RH.EncodeEntries(entries, compact)
    local parts = {}
    for _, e in ipairs(entries) do
        if compact and (e.p or 0) == 0 and (e.s or 0) == 0 and (e.a or 0) == 0 then
            -- 染料なしは省略形(スロット.ID.素材)。チャットリンクを短くするため
            parts[#parts + 1] = table.concat({ To36(e.slot), To36(e.id), To36(e.mat) }, ".")
        else
            parts[#parts + 1] = table.concat({ To36(e.slot), To36(e.id), To36(e.mat), To36(e.p), To36(e.s), To36(e.a) }, ".")
        end
    end
    return table.concat(parts, "-")
end

function RH.DecodeBody(body)
    if type(body) ~= "string" or body == "" or #body > 2000 then return nil end
    if body:find("[^%w_%-%.]") then return nil end
    local entries = {}
    for chunk in body:gmatch("[^%-]+") do
        local f = {}
        for v in chunk:gmatch("[^_%.]+") do f[#f + 1] = From36(v) end
        if #f == 3 then f[4], f[5], f[6] = 0, 0, 0 end   -- 省略形(染料なし)
        if #f ~= 6 then return nil end
        for i = 1, 6 do if not f[i] then return nil end end
        entries[#entries + 1] = { slot = f[1], id = f[2], mat = f[3], p = f[4], s = f[5], a = f[6] }
        if #entries > 40 then return nil end
    end
    if #entries == 0 then return nil end
    return entries
end

function RH.MakeShareString(name, body)
    return string.format("%s:%s:%s", RH.SHARE_TAG, RH.SanitizeName(name), body)
end

-- Discord 等ゲーム外向け: 内容の一覧 + コードブロック
-- メッセージ全体をそのまま貼り付けても読み込めます
function RH.FormatForExternal(name, body, entries)
    name = RH.SanitizeName(name)
    entries = entries or RH.DecodeBody(body) or {}
    local lines = {}
    lines[#lines + 1] = string.format(L.EXT_HEADER, name ~= "" and name or L.EXT_NONAME)
    for _, e in ipairs(entries) do
        local dyes = {}
        for _, id in ipairs({ e.p, e.s, e.a }) do dyes[#dyes + 1] = RH.GetDyeName(id) end
        lines[#lines + 1] = string.format(L.EXT_LINE, RH.GetSlotName(e.slot),
            RH.GetCollectibleDisplayName(e.id), table.concat(dyes, " / "))
    end
    lines[#lines + 1] = L.EXT_HOWTO
    lines[#lines + 1] = "```" .. RH.MakeShareString(name, body) .. "```"
    return table.concat(lines, "\n")
end

function RH.MakeChatLink(name, body)
    local text = RH.SanitizeName(name)
    if ZO_LinkHandler_CreateLink then
        return ZO_LinkHandler_CreateLink(text, nil, RH.LINK_TYPE, body)
    end
    return string.format("|H1:%s:%s|h[%s]|h", RH.LINK_TYPE, body, text)
end

-- 文字列 / チャットリンク / 本体のみ のいずれも受け付ける
-- 戻り値: name, body, entries
function RH.ParseShareText(text)
    text = tostring(text or ""):gsub("[\r\n`]", " ")
    local name, body = text:match(RH.SHARE_TAG .. ":([^:]*):([%w_%-%.]+)")
    if not body then
        body, name = text:match("|H%d:" .. RH.LINK_TYPE .. ":([%w_%-%.]+)|h%[(.-)%]|h")
    end
    if not body then
        body = text:match("^%s*([%w_%-%.]+)%s*$")
        name = ""
    end
    local entries = body and RH.DecodeBody(body)
    if not entries then return nil end
    return RH.SanitizeName(name), body, entries
end

---------------------------------------------------------------------------
-- 現在の衣装 → エントリー
---------------------------------------------------------------------------
function RH.CaptureCurrent()
    local om = RH.RequireManipulator()
    if not om then return nil end
    local entries = {}
    for _, slot in ipairs(RH.allSlots) do
        local sm = RH.GetSlotManip(om, slot)
        if sm then
            local st = RH.GetSlotState(sm)
            if st.id ~= 0 or st.p ~= 0 or st.s ~= 0 or st.a ~= 0 then
                entries[#entries + 1] = { slot = slot, id = st.id, mat = st.mat or RH.DEFAULT_MATERIAL, p = st.p, s = st.s, a = st.a }
            end
        end
    end
    return entries
end

function RH.ExportCurrent(name)
    local entries = RH.CaptureCurrent()
    if not entries then return nil end
    local body = RH.EncodeEntries(entries)
    return RH.FormatForExternal(name, body, entries), body
end

---------------------------------------------------------------------------
-- エントリー → 衣装に反映（保留状態。確定は服飾台の「適用」）
---------------------------------------------------------------------------
function RH.ApplyEntries(entries, name)
    local om = RH.RequireManipulator()
    if not om then return end
    local _, knownDyes = RH.GetKnownDyes()
    RH.PushUndo(om)

    local applied, missingStyles, missingDyes = 0, {}, 0
    local states = {}
    for _, e in ipairs(entries) do
        if RH.isValidSlot[e.slot] then
            local sm = RH.GetSlotManip(om, e.slot)
            if sm then
                local cur = RH.GetSlotState(sm)
                local touched = false
                if e.id == 0 then
                    RH.SetSlotStyle(sm, 0, RH.DEFAULT_MATERIAL)
                    touched = true
                    states[e.slot] = nil
                elseif RH.IsUsable(e.id) or RH.GetStyleSetIsHidden(e.id) then
                    RH.SetSlotStyle(sm, e.id, e.mat)
                    touched = true
                    states[e.slot] = "ok"
                else
                    missingStyles[#missingStyles + 1] = RH.GetCollectibleDisplayName(e.id)
                    states[e.slot] = "missing"
                end

                local dyes = { e.p, e.s, e.a }
                local curDyes = { cur.p, cur.s, cur.a }
                for i = 1, 3 do
                    if dyes[i] ~= 0 and not knownDyes[dyes[i]] then
                        dyes[i] = curDyes[i]
                        missingDyes = missingDyes + 1
                    end
                end
                RH.SetSlotDyes(sm, dyes[1], dyes[2], dyes[3])
                if touched then applied = applied + 1 end
            end
        end
    end

    if RH.SetCoverage then RH.SetCoverage((name and name ~= "") and name or "?", states) end

    -- 読み込み結果(特に「未所持でスキップした」通知)は、チャット表示オフでも必ず出す
    RH.forceMsg = RH.sv.shareMessages ~= false
    RH.Msg(L.MSG_PRESET_APPLIED, (name and name ~= "") and name or "?", applied)
    if #missingStyles > 0 then RH.Msg(L.MSG_PRESET_MISS, table.concat(missingStyles, ", ")) end
    if missingDyes > 0 then RH.Msg(L.MSG_PRESET_DYE_MISS, missingDyes) end
    RH.forceMsg = false
end

-- 内容確認: リンクをクリックしたときと同じパネルを表示する
function RH.InspectEntries(entries, name)
    RH.ShowLinkView(RH.SanitizeName(name), RH.EncodeEntries(entries), entries)
end

---------------------------------------------------------------------------
-- プリセット
---------------------------------------------------------------------------
function RH.SavePreset(name, body)
    local raw = tostring(name or "")
    name = RH.SanitizeName(raw)
    if name == "" then
        -- 診断: 入力欄の中身(長さと先頭バイト)を表示
        local hex = {}
        for i = 1, math.min(#raw, 12) do hex[#hex + 1] = string.format("%02X", raw:byte(i)) end
        RH.forceMsg = true
        RH.Msg("name field: length=%d bytes=%s -> default name used (v2)", #raw, table.concat(hex, " "))
        RH.forceMsg = false
        -- 整形で空になった場合の保険: 区切り文字だけ除いて、入力された名前をそのまま使う
        local fb = raw:gsub("[|:]", "")
        if #fb > 0 then name = fb:sub(1, 60) end
    end
    if name == "" then name = string.format(L.DEFAULT_PRESET_NAME, #RH.sv.presets + 1) end
    -- 同名は上書き
    for _, p in ipairs(RH.sv.presets) do
        if p.name == name then
            p.body, p.time = body, GetTimeStamp()
            RH.Msg(L.MSG_PRESET_SAVED, name)
            return
        end
    end
    table.insert(RH.sv.presets, { name = name, body = body, time = GetTimeStamp() })
    RH.Msg(L.MSG_PRESET_SAVED, name)
end

function RH.OverwritePreset(index, body)
    local p = RH.sv.presets[index]
    if not p then return false end
    p.body, p.time = body, GetTimeStamp()
    RH.Msg(L.MSG_PRESET_OVERWRITTEN, p.name)
    return true
end

function RH.DeletePreset(index)
    local p = RH.sv.presets[index]
    if not p then return end
    table.remove(RH.sv.presets, index)
    RH.Msg(L.MSG_PRESET_DELETED, p.name)
end

---------------------------------------------------------------------------
-- チャット共有
---------------------------------------------------------------------------
function RH.PostToChat(name, body)
    if not RH.linkRegistered then
        RH.forceMsg = true
        RH.Msg(L.MSG_LINK_NEEDS_LIB)
        RH.forceMsg = false
        return false
    end
    local allEntries = RH.DecodeBody(body) or {}
    -- 染料なしの部位を省略形にして短くする
    local link = RH.MakeChatLink(name, RH.EncodeEntries(allEntries, true))
    if #link > CHAT_MAX_BYTES then
        -- それでも長ければ、武器の部位を除く
        local armorOnly = {}
        for _, e in ipairs(allEntries) do
            if RH.isArmor[e.slot] then armorOnly[#armorOnly + 1] = e end
        end
        if #armorOnly > 0 and #armorOnly < #allEntries then
            local short = RH.MakeChatLink(name, RH.EncodeEntries(armorOnly, true))
            if #short <= CHAT_MAX_BYTES then
                link = short
                RH.forceMsg = true
                RH.Msg(L.MSG_LINK_WEAPONS_DROPPED)
                RH.forceMsg = false
            end
        end
    end
    if #link > CHAT_MAX_BYTES then
        RH.forceMsg = true
        RH.Msg(L.MSG_LINK_TOO_LONG)
        RH.forceMsg = false
        return false
    end
    if CHAT_SYSTEM and CHAT_SYSTEM.textEntry and CHAT_SYSTEM.textEntry.InsertLink then
        CHAT_SYSTEM.textEntry:InsertLink(link)
    elseif StartChatInput then
        StartChatInput(link)
    end
    return true
end

-- クリックされたリンク: 左クリックで内容を表示するパネルを開く
local function OnLinkClicked(rawLink, button, linkText, linkStyle, linkType, dataString)
    if linkType ~= RH.LINK_TYPE then return end
    if button == MOUSE_BUTTON_INDEX_LEFT then
        local entries = RH.DecodeBody(dataString)
        if not entries then
            RH.forceMsg = true; RH.Msg(L.MSG_LINK_BAD); RH.forceMsg = false
            return true
        end
        local name = tostring(linkText or "")
        if string.sub(name, 1, 1) == "[" then name = string.sub(name, 2) end
        if string.sub(name, -1) == "]" then name = string.sub(name, 1, -2) end
        RH.ShowLinkView(RH.SanitizeName(name), dataString, entries)
    elseif button == MOUSE_BUTTON_INDEX_RIGHT then
        ClearMenu()
        AddMenuItem(GetString(SI_ITEM_ACTION_LINK_TO_CHAT), function()
            if CHAT_SYSTEM and CHAT_SYSTEM.textEntry then CHAT_SYSTEM.textEntry:InsertLink(rawLink) end
        end, MENU_ADD_OPTION_LABEL)
        ShowMenu(nil, 2, MENU_TYPE_COMBO_BOX)
    end
    return true
end

-- チャットリンクの種類を登録(LibChatMessage が必要。受信側でもリンクとして扱われる)
function RH.InitShare()
    RH.linkRegistered = false
    if not (LibChatMessage and LibChatMessage.RegisterCustomChatLink and LINK_HANDLER) then return end
    LibChatMessage:RegisterCustomChatLink(RH.LINK_TYPE, function(linkStyle, linkType, data, displayText)
        return ZO_LinkHandler_CreateLinkWithoutBrackets(displayText, nil, RH.LINK_TYPE, data)
    end)
    LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, OnLinkClicked)
    LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT, OnLinkClicked)
    RH.linkRegistered = true
end
