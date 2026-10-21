local RH = RestyleHelper
local L = RH.L

local function UnlockedPool(slot, armorType, favSet)
    local idx = RH.GetStyleIndex()
    local out = {}
    for _, id in ipairs(idx.bySlot[slot] or {}) do
        if RH.IsUsable(id) and (not favSet or RH.IsFavoriteMatch(id, favSet)) then
            if not armorType or not RH.isArmor[slot] or idx.info[id].weight == armorType then
                out[#out + 1] = id
            end
        end
    end
    return out
end

-- 解放済みの胴体ピースに存在する防具の重さから1つ選ぶ
local function PickArmorType()
    local idx = RH.GetStyleIndex()
    local seen, types = {}, {}
    local chest = OUTFIT_SLOT_CHEST
    for _, id in ipairs(idx.bySlot[chest] or {}) do
        local at = idx.info[id].weight
        if at and at ~= 0 and not seen[at] and RH.IsUsable(id) then
            seen[at] = true
            types[#types + 1] = at
        end
    end
    return RH.Pick(types)
end

-- テーマ(スタイル)の選び方:
--   ・対象部位を1つ以上(最低でも2部位。対象が1部位のときは1部位)カバーできるスタイルを候補にする
--   ・そろっているスタイルほど選ばれやすいよう、そろった部位数の2乗で重みづけして抽選
--   ・最小部位数(themeMinSlots、既定5)以上の部位をカバーできるスタイルだけを候補にする
--     (ロックなどで対象部位がそれより少ないときは、対象部位すべてを必要数とする)
-- カバーできない部位は変更せず、そのまま残す(または非表示オプションに従う)。
local function PickThemeStyle(styleSlots, favSet, minSlots)
    local idx = RH.GetStyleIndex()
    local counts, maxCount = {}, 0
    for styleId, bySlot in pairs(idx.byStyle) do
        if not favSet or favSet[styleId] then
            local c = 0
            for _, slot in ipairs(styleSlots) do
                for _, id in ipairs(bySlot[slot] or {}) do
                    if RH.IsUsable(id) then c = c + 1 break end
                end
            end
            if c > 0 then
                counts[styleId] = c
                if c > maxCount then maxCount = c end
            end
        end
    end
    if maxCount == 0 then return nil end

    local need = math.max(1, math.min(tonumber(minSlots) or 5, #styleSlots))
    local pool, total = {}, 0
    for styleId, c in pairs(counts) do
        if c >= need then
            local w = c * c
            pool[#pool + 1] = { styleId = styleId, w = w }
            total = total + w
        end
    end
    if #pool == 0 then return nil end -- 最小部位数に満たないスタイルは対象外
    local r = math.random() * total
    for _, e in ipairs(pool) do
        r = r - e.w
        if r <= 0 then return e.styleId end
    end
    return pool[#pool] and pool[#pool].styleId
end

-- 重複なしで染料を配るディーラー（使い切ったら補充）
local function Shuffled(list)
    local t = {}
    for i = 1, #list do t[i] = list[i] end
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- 3色パレット: 必須色を優先して入れ(最大3色)、残りはプールから重複しないように選ぶ
local function BuildPalette(dyes, required)
    local pal, used = {}, {}
    for _, id in ipairs(Shuffled(required or {})) do
        if #pal < 3 then pal[#pal + 1] = id; used[id] = true end
    end
    local tries = 0
    while #pal < 3 and tries < 200 do
        tries = tries + 1
        local id = RH.Pick(dyes)
        if id and not used[id] then pal[#pal + 1] = id; used[id] = true end
        if #used >= #dyes then break end
    end
    while #pal < 3 do pal[#pal + 1] = RH.Pick(dyes) end
    return Shuffled(pal)
end

local function NewDyeDealer(dyes, required)
    local deck = {}
    local first = true
    local isReq = {}
    for _, id in ipairs(required or {}) do isReq[id] = true end
    local function refill()
        local rest = {}
        for i = 1, #dyes do
            if not (first and isReq[dyes[i]]) then rest[#rest + 1] = dyes[i] end
        end
        deck = Shuffled(rest)
        if first then
            -- 必須色を最初に配る(末尾から取り出されるので末尾に積む)
            for _, id in ipairs(Shuffled(required or {})) do deck[#deck + 1] = id end
            first = false
        end
    end
    return function()
        if #deck == 0 then refill() end
        return table.remove(deck)
    end
end

-- mode: "all" | "style" | "dye" | "theme" | "chaos"
function RH.Randomize(mode)
    mode = mode or "all"
    local om = RH.RequireManipulator()
    if not om then return end
    local sv = RH.sv

    local targets = {}
    for _, s in ipairs(RH.armorSlots) do targets[#targets + 1] = s end
    if sv.weaponStyle or sv.weaponDye then
        for _, s in ipairs(RH.weaponSlots) do targets[#targets + 1] = s end
    end

    local doStyle = (mode == "all" or mode == "style" or mode == "theme")
    -- テーマ統一はスタイルだけを変更し、色には触れない
    local doDye   = (mode == "all" or mode == "dye" or mode == "chaos")

    local dyes, required = RH.GetPoolDyes()
    if doDye and #dyes == 0 then
        RH.Msg(L.MSG_NO_DYES)
        doDye = false
    end

    -- 色: パレット(全身共通の3色)
    local palette, dealer
    if doDye and mode == "chaos" then
        -- 全パーツ・全チャンネルで異なる色
        dealer = NewDyeDealer(dyes, required)
    elseif doDye then
        palette = BuildPalette(dyes, required)
    end

    -- スタイル: 重さ統一 / テーマ
    local armorType
    if doStyle and sv.unifyWeight then armorType = PickArmorType() end

    -- お気に入り限定（お気に入りが無ければ通常どおり全スタイル）
    local favSet
    if doStyle and sv.favoritesOnly and RH.HasFavorites() then
        favSet = RH.GetFavoriteStyleSet()
    end

    local themeStyleId, themeArmorType
    if mode == "theme" then
        local styleSlots = {}
        for _, s in ipairs(targets) do
            if not sv.locks[s] and (RH.isArmor[s] or sv.weaponStyle) then styleSlots[#styleSlots + 1] = s end
        end
        -- 部位数の判定は防具スロットだけで数える
        local coverSlots = {}
        for _, s in ipairs(styleSlots) do
            if RH.isArmor[s] then coverSlots[#coverSlots + 1] = s end
        end
        if #coverSlots == 0 then coverSlots = styleSlots end
        themeStyleId = (favSet and PickThemeStyle(coverSlots, favSet, sv.themeMinSlots))
                       or PickThemeStyle(coverSlots, nil, sv.themeMinSlots)
        if not themeStyleId then
            RH.forceMsg = true
            RH.Msg(L.MSG_THEME_NONE)
            RH.forceMsg = false
            return
        end
        themeArmorType = armorType
        if not themeArmorType then
            -- テーマ内で胴体ピースの重さを基準にする
            local chestId = RH.FindInStyle(themeStyleId, OUTFIT_SLOT_CHEST)
            if chestId then themeArmorType = RH.GetStyleIndex().info[chestId].weight end
        end
    end

    RH.PushUndo(om)

    local styleCount, dyeCount = 0, 0
    local themeStates = {}
    for _, slot in ipairs(targets) do
        local sm = RH.GetSlotManip(om, slot)
        if sm then
            local locked = sv.locks[slot]

            local weaponOff = not RH.isArmor[slot]
            if doStyle and not locked and not (weaponOff and not sv.weaponStyle) then
                local id
                if themeStyleId then
                    local sub
                    id, sub = RH.FindInStyle(themeStyleId, slot, themeArmorType)
                    if id then
                        themeStates[slot] = sub and "sub" or "ok"
                    elseif RH.isArmor[slot] then
                        -- 揃わない部位: オプションで非表示、そうでなければ現状維持
                        themeStates[slot] = RH.HandleMissingSlot(sm, slot)
                    end
                else
                    local pool = UnlockedPool(slot, armorType, favSet)
                    if #pool == 0 and favSet then pool = UnlockedPool(slot, nil, favSet) end
                    if #pool == 0 then pool = UnlockedPool(slot, armorType) end
                    if #pool == 0 and armorType then pool = UnlockedPool(slot, nil) end
                    id = RH.Pick(pool)
                end
                if id then
                    RH.SetSlotStyle(sm, id, RH.DEFAULT_MATERIAL)
                    styleCount = styleCount + 1
                end
            end

            if doDye and not (locked and sv.lockDyes) and not (weaponOff and not sv.weaponDye) then
                if dealer then
                    RH.SetSlotDyes(sm, dealer(), dealer(), dealer())
                elseif palette then
                    RH.SetSlotDyes(sm, palette[1], palette[2], palette[3])
                else
                    RH.SetSlotDyes(sm, RH.Pick(dyes), RH.Pick(dyes), RH.Pick(dyes))
                end
                dyeCount = dyeCount + 1
            end
        end
    end

    if themeStyleId then
        RH.Msg(L.MSG_THEME, RH.GetStyleName(themeStyleId))
        RH.SetCoverage(RH.GetStyleName(themeStyleId), themeStates)
        local miss = {}
        for _, slot in ipairs(RH.armorSlots) do
            if themeStates[slot] == "missing" or themeStates[slot] == "hidden" then
                miss[#miss + 1] = RH.GetSlotName(slot)
            end
        end
        if #miss > 0 then RH.Msg(L.MSG_THEME_INCOMPLETE, table.concat(miss, ", ")) end
    end
    RH.Msg(L.MSG_RANDOM_DONE, styleCount, dyeCount)
end

---------------------------------------------------------------------------
-- 配色シャッフル: 使っている色は変えず、メイン/サブ/アクセントの位置だけ入れ替える
---------------------------------------------------------------------------
-- 3チャンネルの並べ替え(恒等を除く)
local PERMUTATIONS = {
    { 1, 3, 2 }, { 2, 1, 3 }, { 2, 3, 1 }, { 3, 1, 2 }, { 3, 2, 1 },
}

-- 全体の並べ替え perm を、染色できるチャンネル D だけに絞った並べ替えにする
-- (染色できないチャンネルの色が染色できるチャンネルに混ざらないようにする)
local function InducedPerm(perm, D)
    if #D == 3 then return perm end
    local vals = {}
    for _, i in ipairs(D) do vals[#vals + 1] = { idx = i, v = perm[i] } end
    table.sort(vals, function(x, y) return x.v < y.v end)
    -- 順位 → D 内の位置
    local rank = {}
    for r, e in ipairs(vals) do rank[e.idx] = D[r] end
    local out = {}
    for _, i in ipairs(D) do out[i] = rank[i] end
    return out
end

-- 染色できるチャンネルだけを並べ替えた結果(3値)を返す。変化が無ければ nil
local function ApplyPerm(dyes, perm, D)
    local ip = InducedPerm(perm, D)
    local out, changed = { dyes[1], dyes[2], dyes[3] }, false
    for _, i in ipairs(D) do
        out[i] = dyes[ip[i]]
        if out[i] ~= dyes[i] then changed = true end
    end
    if changed then return out end
    return nil
end

function RH.ShuffleDyeOrder()
    local om = RH.RequireManipulator()
    if not om then return end
    local sv = RH.sv

    local targets = {}
    for _, s in ipairs(RH.armorSlots) do targets[#targets + 1] = s end
    if sv.weaponDye then
        for _, s in ipairs(RH.weaponSlots) do targets[#targets + 1] = s end
    end

    -- 対象スロットの現在の配色(染色できるチャンネルのみ)を集める
    local work, singles, colors, seenColor, refTriple = {}, {}, {}, {}, nil
    for _, slot in ipairs(targets) do
        if not (sv.locks[slot] and sv.lockDyes) then
            local sm = RH.GetSlotManip(om, slot)
            if sm then
                local st = RH.GetSlotState(sm)
                local dyes = { st.p, st.s, st.a }
                local ok = RH.GetDyeable(sm)
                local D = {}
                for i = 1, 3 do if ok[i] then D[#D + 1] = i end end
                if #D >= 2 then
                    local w = { sm = sm, dyes = dyes, D = D }
                    local any = false
                    for _, perm in ipairs(PERMUTATIONS) do
                        if ApplyPerm(dyes, perm, D) then any = true break end
                    end
                    if any then work[#work + 1] = w end
                    -- 基準パレット: 各チャンネルの色は、そのチャンネルを染められる最初のパーツの色を採用
                    refTriple = refTriple or { 0, 0, 0 }
                    for _, i in ipairs(D) do
                        if refTriple[i] == 0 and dyes[i] and dyes[i] ~= 0 then refTriple[i] = dyes[i] end
                    end
                    for _, i in ipairs(D) do
                        local v = dyes[i]
                        if v and v ~= 0 and not seenColor[v] then seenColor[v] = true; colors[#colors + 1] = v end
                    end
                elseif #D == 1 then
                    refTriple = refTriple or { 0, 0, 0 }
                    if refTriple[D[1]] == 0 and dyes[D[1]] and dyes[D[1]] ~= 0 then refTriple[D[1]] = dyes[D[1]] end
                    singles[#singles + 1] = { sm = sm, i = D[1], cur = dyes[D[1]] }
                end
            end
        end
    end
    if #work == 0 and #singles == 0 then
        RH.Msg(L.MSG_ORDER_NONE)
        return
    end

    -- 全身共通モード: 全部位に同じ並べ替えを使う(少なくとも1部位が変わるもの)
    local shared
    if not sv.orderPerSlot then
        local candidates = {}
        for _, perm in ipairs(PERMUTATIONS) do
            for _, w in ipairs(work) do
                if ApplyPerm(w.dyes, perm, w.D) then candidates[#candidates + 1] = perm break end
            end
        end
        shared = RH.Pick(candidates)
    end

    RH.PushUndo(om)
    local count = 0

    -- 染められるチャンネルが1つだけのパーツ: 全身で使っている色のどれかに入れ替える
    for _, sg in ipairs(singles) do
        local color
        if shared and refTriple then
            local ip = shared[sg.i]
            color = refTriple[ip]
        end
        if (not color or color == 0 or color == sg.cur) and #colors > 0 then
            local options = {}
            for _, v in ipairs(colors) do
                if v ~= sg.cur then options[#options + 1] = v end
            end
            color = RH.Pick(options)
        end
        if color and color ~= 0 and color ~= sg.cur then
            local cur = RH.GetSlotState(sg.sm)
            local t = { cur.p, cur.s, cur.a }
            t[sg.i] = color
            RH.SetSlotDyes(sg.sm, t[1], t[2], t[3])
            count = count + 1
        end
    end

    for _, w in ipairs(work) do
        local out
        if shared then
            if #w.D < 3 and refTriple then
                -- 一部のチャンネルしか染められない部位: 全身の配色(基準パレット)を同じ並べ替えで当てはめる
                -- (染められないチャンネルに残った見えない色を使わない)
                local o, changed = { w.dyes[1], w.dyes[2], w.dyes[3] }, false
                for _, i in ipairs(w.D) do
                    local v = refTriple[shared[i]]
                    if v and v ~= 0 then
                        o[i] = v
                        if v ~= w.dyes[i] then changed = true end
                    end
                end
                if changed then out = o else out = ApplyPerm(w.dyes, shared, w.D) end
            else
                out = ApplyPerm(w.dyes, shared, w.D)
            end
        else
            local options = {}
            for _, p in ipairs(PERMUTATIONS) do
                local o = ApplyPerm(w.dyes, p, w.D)
                if o then options[#options + 1] = o end
            end
            out = RH.Pick(options)
        end
        if out then
            RH.SetSlotDyes(w.sm, out[1], out[2], out[3])
            count = count + 1
        end
    end
    RH.Msg(L.MSG_ORDER_DONE, count)
end
