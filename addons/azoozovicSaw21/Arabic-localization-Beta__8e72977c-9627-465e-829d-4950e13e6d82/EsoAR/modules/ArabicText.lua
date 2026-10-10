-- ESO Arabic 1.3: text stored in visual order for the game's LTR labels.
-- Markup is parsed before wrapping; tag payloads are never reversed or split.
ESO_ARABIC_TEXT = ESO_ARABIC_TEXT or {}
local R = ESO_ARABIC_TEXT
local concat, insert = table.concat, table.insert

function R.Char(cp)
    if cp < 128 then return string.char(cp) end
    if cp < 2048 then return string.char(192 + math.floor(cp / 64), 128 + cp % 64) end
    if cp < 65536 then return string.char(224 + math.floor(cp / 4096), 128 + math.floor(cp / 64) % 64, 128 + cp % 64) end
    return string.char(240 + math.floor(cp / 262144), 128 + math.floor(cp / 4096) % 64, 128 + math.floor(cp / 64) % 64, 128 + cp % 64)
end

local function nextChar(s, i)
    local a, b, c, d = string.byte(s, i, i + 3)
    if not a then return nil end
    if a < 128 then return a, i + 1 end
    if a < 224 and b then return (a - 192) * 64 + b - 128, i + 2 end
    if a < 240 and b and c then return (a - 224) * 4096 + (b - 128) * 64 + c - 128, i + 3 end
    if b and c and d then return (a - 240) * 262144 + (b - 128) * 4096 + (c - 128) * 64 + d - 128, i + 4 end
    return a, i + 1
end

local function isArabic(cp)
    return (cp >= 0x0600 and cp <= 0x06FF) or (cp >= 0x0750 and cp <= 0x077F)
        or (cp >= 0x08A0 and cp <= 0x08FF) or (cp >= 0xFB50 and cp <= 0xFDFF)
        or (cp >= 0xFE70 and cp <= 0xFEFC) or (cp >= 0xE700 and cp <= 0xE707)
end

function R.HasArabic(s)
    if type(s) ~= "string" then return false end
    -- ESO's pattern matcher does not reliably match ranges of incomplete
    -- UTF-8 bytes. Decode code points instead: this gate must work in-client,
    -- including strings consisting entirely of Arabic presentation forms.
    local i = 1
    while i <= #s do
        local cp, nextIndex = nextChar(s, i)
        if isArabic(cp) then return true end
        i = nextIndex
    end
    return false
end

function R.HasForms(s)
    if type(s) ~= "string" then return false end
    local i = 1
    while i <= #s do
        local cp, nextIndex = nextChar(s, i)
        if (cp >= 0xFB50 and cp <= 0xFDFF) or (cp >= 0xFE70 and cp <= 0xFEFC)
            or (cp >= 0xE700 and cp <= 0xE707) then return true end
        i = nextIndex
    end
    return false
end

local function isMark(cp)
    return (cp >= 0x064B and cp <= 0x065F) or cp == 0x0670
        or (cp >= 0x06D6 and cp <= 0x06ED)
end

function R.Clean(s)
    -- The binary translation contains literal JSON quote escapes in both
    -- orientations. Punctuation and ESO grammar/texture/link syntax stay intact.
    s = s:gsub("\\+\"", '"'):gsub("\"\\+", '"')
    s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
    s = s:gsub("%^[mMfFnNpPsS]+$", "")
    return s
end

-- Compose ONLY the already-shaped visual alef+lam pair, not the article al-.
local alefs = { [0xFE82] = 0xFEF5, [0xFE84] = 0xFEF7, [0xFE88] = 0xFEF9, [0xFE8E] = 0xFEFB }
function R.Compose(s)
    for a, lig in pairs(alefs) do
        s = s:gsub(R.Char(a) .. R.Char(0xFEDF), R.Char(lig))
        s = s:gsub(R.Char(a) .. R.Char(0xFEE0), R.Char(lig + 1))
    end
    return s
end

local function parse(s, out, inheritedColor, inheritedLink)
    local i, color, link = 1, inheritedColor, inheritedLink
    while i <= #s do
        -- Inspect only a short prefix for ordinary glyphs. Copying the entire
        -- remaining book once per character was quadratic in paragraph length.
        local rest = s:sub(i, i + 8)
        local tag = rest:match("^(|c%x%x%x%x%x%x)")
        if tag then
            color = tag; i = i + #tag
        elseif rest:sub(1, 2) == "|r" then
            color = nil; i = i + 2
        elseif rest:sub(1, 2) == "|H" then
            local h1 = s:find("|h", i + 2, true)
            local h2 = h1 and s:find("|h", h1 + 2, true)
            if h2 then
                parse(s:sub(h1 + 2, h2 - 1), out, color, s:sub(i, h1 + 1))
                i = h2 + 2
            else
                insert(out, { text = "|", cp = 124, color = color, link = link }); i = i + 1
            end
        else
            local atom
            if rest:sub(1, 2) == "|t" then
                local e = s:find("|t", i + 2, true)
                if e then atom = s:sub(i, e + 1) end
            elseif rest:sub(1, 2) == "<<" then
                -- Unresolved fields remain whole. Normally they are resolved
                -- by LocalizeString before reaching a label.
                atom = s:sub(i):match("^(<<.->>)")
            elseif rest:sub(1, 2) == "|u" then
                local e = s:find("|u", i + 2, true)
                if e then atom = s:sub(i, e + 1) end
            end
            if atom then
                insert(out, { text = atom, color = color, link = link, atom = true })
                i = i + #atom
            else
                local cp, ni = nextChar(s, i)
                local g = { text = s:sub(i, ni - 1), cp = cp, color = color, link = link, arabic = isArabic(cp) }
                g.space = cp == 32 or cp == 9
                g.newline = cp == 10
                if isMark(cp) and #out > 0 and not out[#out].space and not out[#out].newline then
                    out[#out].text = out[#out].text .. g.text
                else insert(out, g) end
                i = ni
            end
        end
    end
    return out
end
R.Parse = function(s) return parse(s, {}) end

function R.Emit(glyphs)
    local out, color, link = {}, nil, nil
    for _, g in ipairs(glyphs) do
        if link ~= g.link or color ~= g.color then
            if color then insert(out, "|r"); color = nil end
            if link ~= g.link then
                if link then insert(out, "|h") end
                link = g.link
                if link then insert(out, link) end
            end
            color = g.color
            if color then insert(out, color) end
        end
        insert(out, g.text)
    end
    if color then insert(out, "|r") end
    if link then insert(out, "|h") end
    return concat(out)
end

local mirror = { [40] = 41, [41] = 40, [91] = 93, [93] = 91, [123] = 125, [125] = 123, [60] = 62, [62] = 60 }
local function isLTR(g)
    if g.atom then return true end
    local cp = g.cp or 0
    return (cp >= 48 and cp <= 57) or (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122)
        or (cp >= 0x0660 and cp <= 0x0669)
end

function R.ShapeLogical(text)
    local gs = R.Parse(text)
    local forms = R.Forms or {}
    for i, g in ipairs(gs) do
        local f = forms[g.cp]
        if f then
            local p, n = gs[i - 1], gs[i + 1]
            local pf, nf = p and forms[p.cp], n and forms[n.cp]
            local previous = pf and pf[3] ~= 0 and f[2] ~= 0
            local following = nf and f[3] ~= 0 and nf[2] ~= 0
            local idx = previous and (following and 4 or 2) or (following and 3 or 1)
            local shaped = f[idx] ~= 0 and f[idx] or f[1]
            g.text = R.Char(shaped) .. g.text:sub(#R.Char(g.cp) + 1)
        end
    end
    local paras, para = {}, {}
    local function reverseParagraph()
        -- Preserve LTR runs (names, numbers, times and URLs) as units.
        local units, i = {}, 1
        while i <= #para do
            if isLTR(para[i]) then
                local j = i
                while j < #para do
                    local ng = para[j + 1]
                    if isLTR(ng) or (ng.cp and ng.text:match("^[-_.,:/%%+@#&$*]$")) then j = j + 1
                    elseif ng.space and para[j + 2] and isLTR(para[j + 2]) then j = j + 2
                    else break end
                end
                local run = {}; for k = i, j do insert(run, para[k]) end
                insert(units, run); i = j + 1
            else
                local g = para[i]
                if mirror[g.cp] then g.text = R.Char(mirror[g.cp]) end
                insert(units, {g}); i = i + 1
            end
        end
        local visual = {}
        for u = #units, 1, -1 do for _, g in ipairs(units[u]) do insert(visual, g) end end
        insert(paras, R.Compose(R.Emit(visual))); para = {}
    end
    for _, g in ipairs(gs) do
        if g.newline then reverseParagraph() else insert(para, g) end
    end
    reverseParagraph()
    return concat(paras, "\n")
end

function R.Prepare(s)
    if not R.HasArabic(s) then return s end
    s = R.Clean(s)
    if not R.HasForms(s) then s = R.ShapeLogical(s) end
    return R.Compose(s)
end

-- Native tooltip data contains visual RTL lines in reading order. A Lua
-- label with a different width must join those lines from right to left
-- before measuring again; replacing newlines with spaces reverses clauses.
function R.JoinVisualLines(text)
    local paragraphs = {}
    for paragraph in (text .. "\n\n"):gmatch("(.-)\n\n") do
        local lines = {}
        for line in paragraph:gmatch("[^\n]+") do table.insert(lines, 1, line) end
        table.insert(paragraphs, table.concat(lines, " "))
    end
    return table.concat(paragraphs, "\n\n")
end

local function joined(a, b)
    local out = {}
    for _, g in ipairs(a) do insert(out, g) end
    if #a > 0 and #b > 0 then
        insert(out, {text = " ", cp = 32, space = true,
            color = a[#a].color == b[1].color and b[1].color or nil,
            link = a[#a].link == b[1].link and b[1].link or nil})
    end
    for _, g in ipairs(b) do insert(out, g) end
    return out
end

local function splitWords(gs, width, measure)
    local words, word = {}, {}
    for _, g in ipairs(gs) do
        if g.space then
            if #word > 0 then insert(words, word); word = {} end
        else insert(word, g) end
    end
    if #word > 0 then insert(words, word) end
    -- A short parenthesized phrase is one visual unit. Splitting its words
    -- across RTL lines strands the opening/closing punctuation. Only keep
    -- balanced groups together when the entire group fits the available line.
    local kept, i = {}, 1
    while i <= #words do
        local depth, opened, finish = 0, false, nil
        for j = i, #words do
            for _, g in ipairs(words[j]) do
                if g.cp == 40 then depth = depth + 1; opened = true
                elseif g.cp == 41 then depth = depth - 1 end
            end
            if depth < 0 or not opened then break end
            if depth == 0 then finish = j; break end
        end
        local group = words[i]
        if finish and finish > i then
            for j = i + 1, finish do group = joined(group, words[j]) end
            if measure(R.Emit(group)) <= width then
                insert(kept, group); i = finish + 1
            else insert(kept, words[i]); i = i + 1 end
        else insert(kept, words[i]); i = i + 1 end
    end
    words = kept
    -- Consecutive Latin words have an internal LTR order even in an RTL line.
    local groups, i = {}, 1
    while i <= #words do
        local w, arabic, ltr = words[i], false, false
        for _, g in ipairs(w) do arabic = arabic or g.arabic; ltr = ltr or isLTR(g) end
        if ltr and not arabic then
            local parts = {w}
            while i < #words do
                local nextArabic, nextLTR = false, false
                for _, g in ipairs(words[i + 1]) do nextArabic = nextArabic or g.arabic; nextLTR = nextLTR or isLTR(g) end
                if nextArabic or not nextLTR then break end
                i = i + 1; w = joined(w, words[i]); insert(parts, words[i])
            end
            w.ltr = true; w.parts = parts
        end
        insert(groups, w); i = i + 1
    end
    return groups
end

function R.WrapVisual(text, width, measure)
    if not R.HasArabic(text) or type(width) ~= "number" or width <= 0 then return text end
    local glyphs = R.Parse(text)
    local output, paragraph = {}, {}
    local function wrapParagraph()
        local original = R.Emit(paragraph)
        if not R.HasArabic(original) or measure(original) <= width then
            insert(output, original); paragraph = {}; return
        end
        local words, line = splitWords(paragraph, width, measure), {}
        local function flush()
            if #line > 0 then insert(output, R.Emit(line)); line = {} end
        end
        for wi = #words, 1, -1 do
            local word = words[wi]
            local candidate = joined(word, line)
            if #line > 0 and measure(R.Emit(candidate)) > width then flush() end
            if measure(R.Emit(word)) <= width then
                line = joined(word, line)
            else
                flush()
                -- Oversized LTR phrases break from their beginning. Arabic
                -- words break from their right edge, on UTF-8 grapheme boundaries.
                local chunk = {}
                local step, first, last = -1, #word, 1
                if word.ltr then step, first, last = 1, 1, #word end
                for j = first, last, step do
                    local g = word[j]
                    local trial = {}
                    if step < 0 then insert(trial, g) end
                    for _, old in ipairs(chunk) do insert(trial, old) end
                    if step > 0 then insert(trial, g) end
                    if #chunk > 0 and measure(R.Emit(trial)) > width then
                        insert(output, R.Emit(chunk)); chunk = {}
                        if not g.space then insert(chunk, g) end
                    else chunk = trial end
                end
                if #chunk > 0 then insert(output, R.Emit(chunk)) end
            end
        end
        flush(); paragraph = {}
    end
    for _, g in ipairs(glyphs) do
        if g.newline then wrapParagraph() else insert(paragraph, g) end
    end
    wrapParagraph()
    return concat(output, "\n")
end
