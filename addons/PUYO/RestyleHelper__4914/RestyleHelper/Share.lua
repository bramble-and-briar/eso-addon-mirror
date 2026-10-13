local RH = RestyleHelper
local L = RH.L

local CHAT_MAX_BYTES = 350
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
function RH.SanitizeName(name)
    name = tostring(name or "")
    name = name:gsub("[|:%[%]%c`%*_~\\]", ""):gsub("^%s+", ""):gsub("%s+$", "")  -- Discord の装飾記号も除去
    local out, count = {}, 0
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > NAME_MAX_CHARS then break end
        out[#out + 1] = ch
    end
    return table.concat(out)
end

---------------------------------------------------------------------------
-- エンコード / デコード
-- body = "slot.id.mat.p.s.a-slot.id.mat.p.s.a-..."（各値36進数）
-- 区切りに "." を使うのは Discord 等で "_" が斜体化されて消えるのを防ぐため（旧形式 "_" も読み込み可）
---------------------------------------------------------------------------
function RH.EncodeEntries(entries)
    local parts = {}
    for _, e in ipairs(entries) do
        parts[#parts + 1] = table.concat({ To36(e.slot), To36(e.id), To36(e.mat), To36(e.p), To36(e.s), To36(e.a) }, ".")
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
    return string.format("|H1:%s:%s|h[%s]|h", RH.LINK_TYPE, body, RH.SanitizeName(name))
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
    for _, e in ipairs(entries) do
        if RH.isValidSlot[e.slot] then
            local sm = RH.GetSlotManip(om, e.slot)
            if sm then
                local cur = RH.GetSlotState(sm)
                local touched = false
                if e.id == 0 then
                    RH.SetSlotStyle(sm, 0, RH.DEFAULT_MATERIAL)
                    touched = true
                elseif RH.IsUnlocked(e.id) or RH.GetStyleSetIsHidden(e.id) then
                    RH.SetSlotStyle(sm, e.id, e.mat)
                    touched = true
                else
                    missingStyles[#missingStyles + 1] = RH.GetCollectibleDisplayName(e.id)
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

    -- 読み込み結果(特に「未所持でスキップした」通知)は、チャット表示オフでも必ず出す
    RH.forceMsg = RH.sv.shareMessages ~= false
    RH.Msg(L.MSG_PRESET_APPLIED, (name and name ~= "") and name or "?", applied)
    if #missingStyles > 0 then RH.Msg(L.MSG_PRESET_MISS, table.concat(missingStyles, ", ")) end
    if missingDyes > 0 then RH.Msg(L.MSG_PRESET_DYE_MISS, missingDyes) end
    RH.forceMsg = false
end

function RH.InspectEntries(entries, name)
    RH.forceMsg = RH.sv.shareMessages ~= false
    RH.Msg(L.MSG_INSPECT_HEADER, (name and name ~= "") and name or "?")
    for _, e in ipairs(entries) do
        local owned = (e.id == 0 or RH.IsUnlocked(e.id)) and "" or " |cFF6666" .. L.OWNED_NO .. "|r"
        RH.Msg("%s: %s%s / %s, %s, %s",
            RH.GetSlotName(e.slot), RH.GetCollectibleDisplayName(e.id), owned,
            RH.GetDyeName(e.p), RH.GetDyeName(e.s), RH.GetDyeName(e.a))
    end
    RH.forceMsg = false
end

---------------------------------------------------------------------------
-- プリセット
---------------------------------------------------------------------------
function RH.SavePreset(name, body)
    name = RH.SanitizeName(name)
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
    local link = RH.MakeChatLink(name, body)
    if #link > CHAT_MAX_BYTES then
        RH.Msg(L.MSG_LINK_TOO_LONG)
        return false
    end
    if StartChatInput then
        StartChatInput(link)
    elseif CHAT_SYSTEM and CHAT_SYSTEM.StartTextEntry then
        CHAT_SYSTEM:StartTextEntry(link)
    end
    return true
end

local lastLinkMs = 0

local function OnLinkEvent(link, button, text, color, linkType, body)
    if linkType ~= RH.LINK_TYPE then return end
    local name = RH.SanitizeName((text or ""):gsub("^%[", ""):gsub("%]$", ""))
    local now = GetFrameTimeMilliseconds()
    if now - lastLinkMs < 300 then return true end  -- CLICKED と MOUSE_UP の二重発火防止
    if button == MOUSE_BUTTON_INDEX_LEFT and RH.DecodeBody(body) then
        lastLinkMs = now
        RH.ShowShareWindow(true)
        RH.SetImportText(RH.MakeShareString(name, body), name)
        RH.Msg(L.MSG_LINK_RECEIVED, name)
    end
    return true
end

function RH.InitShare()
    if LINK_HANDLER then
        LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT, OnLinkEvent)
        LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, OnLinkEvent)
    end
end
