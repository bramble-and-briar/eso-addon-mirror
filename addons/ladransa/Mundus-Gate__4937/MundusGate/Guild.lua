-- Гильдии: перемещение к гильдейскому торговцу и в гильдхолл.
--
-- У каждой гильдии два «места» — их можно добавить в «Мои места», вынести
-- кнопкой на экран, положить в колесо, как любое другое место:
--   • "trader:<guildId>" — торговец гильдии: перемещение к ближайшему
--     святилищу. Игра сообщает только имя торговца, поэтому святилище ищется
--     по названию: сначала в имени торговца («Доннейлайн в Белкарте»), потом
--     в описании и сообщении дня гильдии (там обычно пишут, где торговец).
--     Не нашлось или нашлось не то — святилище выбирается вручную (ПКМ).
--   • "hall:<guildId>" — гильдхолл: дом игрока. По умолчанию — основной дом
--     главы гильдии; владельца и конкретный дом можно указать (ПКМ).
-- На вкладке гильдии «Главная»: под торговцем — кнопка «Перемещение к
-- торговцу», ниже — раздел «Гильдейский холл» со значком и кнопкой
-- «Перемещение в холл» (ПКМ по кнопкам — действия).
local QTM  = MundusGate
local L    = QTM.L
local Data = QTM.Data

local Guild = {}
QTM.Guild = Guild

local ICON_TRADER = "EsoUI/Art/Guild/ownership_icon_guildTrader.dds"
local ICON_HALL   = "/esoui/art/icons/poi/poi_group_house_owned.dds"
local MIN_MATCH   = 4   -- столько первых букв слова должно совпасть

-- Только UTF-8-безопасное понижение регистра: string.lower в русской Windows портит байты UTF-8
local lower = LocaleAwareToLower or zo_strlower or function(text) return text end

function Guild:Initialize()
    ZO_Dialogs_RegisterCustomDialog("MUNDUSGATE_GUILD_HALL", {
        title    = { text = L.GUILD_HALL_DIALOG_TITLE },
        mainText = { text = L.GUILD_HALL_DIALOG_TEXT },
        editBox  = { defaultText = "", maxInputCharacters = 40, selectAll = true },
        buttons  = {
            {
                text     = L.RENAME_SAVE,
                callback = function(dialog)
                    self:SetHallOwner(dialog.data.guildId, ZO_Dialogs_GetEditBoxText(dialog))
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })

    -- Состав гильдий изменился — пересобрать места
    local function OnGuildsChanged()
        Data:Invalidate()
        if QTM.RefreshAllViews then QTM.RefreshAllViews() end
        self:RefreshHomeButtons()
    end
    local em = EVENT_MANAGER
    local name = QTM.name .. "Guild"
    for _, eventName in ipairs({ "EVENT_GUILD_SELF_JOINED_GUILD", "EVENT_GUILD_SELF_LEFT_GUILD" }) do
        if _G[eventName] then em:RegisterForEvent(name, _G[eventName], OnGuildsChanged) end
    end
    for _, eventName in ipairs({ "EVENT_PLAYER_ACTIVATED", "EVENT_GUILD_DATA_LOADED" }) do
        if _G[eventName] then em:RegisterForEvent(name .. eventName, _G[eventName], OnGuildsChanged) end
    end
    if EVENT_GUILD_TRADER_HIRED_UPDATED then
        em:RegisterForEvent(name, EVENT_GUILD_TRADER_HIRED_UPDATED, function()
            if QTM.RefreshTravelState then QTM.RefreshTravelState() end
            self:RefreshHomeButtons()
        end)
    end

    self:CreateHomeButtons()

    -- /mgtrader — что аддон видит про торговцев (если святилище не находится)
    SLASH_COMMANDS["/mgtrader"] = function() self:PrintDiagnostics() end
end

function Guild:PrintDiagnostics()
    local out = CHAT_ROUTER and function(text) CHAT_ROUTER:AddSystemMessage(text) end or d
    local count = #self:GetWayshrineWords()
    out(zo_strformat(L.GUILD_DIAG_SHRINES, count))
    for _, guildId in ipairs(self:GetGuildIds()) do
        local kiosk = self:GetKioskName(guildId)
        local node, source = self:GetTraderWayshrine(guildId)
        out(string.format("%s: %s -> %s (%s)", zo_strformat("<<1>>", GetGuildName(guildId) or ""),
            kiosk or "-", node and node.name or "-", node and source or tostring(source)))
        if kiosk then
            local words, town = self:GetKioskTownWords(kiosk)
            out(string.format("   town: %s | words: %s", tostring(town), table.concat(words, ", ")))
            for index, result in ipairs(self:ScoreWayshrines(kiosk)) do
                if index > 3 then break end
                local candidate = Data:GetNode(result.nodeIndex)
                out(string.format("   %d. %s [%d]", index, candidate and candidate.originalName or "?", result.score))
            end
        end
    end
end

---------------------------------------------------------------------------
-- Места гильдий для списка мест (Data:BuildNodes)
---------------------------------------------------------------------------
function Guild:GetGuildIds()
    local ids = {}
    for index = 1, (GetNumGuilds and GetNumGuilds() or 0) do
        local guildId = GetGuildId(index)
        if guildId and guildId ~= 0 then ids[#ids + 1] = guildId end
    end
    return ids
end

function Guild:MakeNodes()
    local nodes = {}
    for _, guildId in ipairs(self:GetGuildIds()) do
        local guildName = zo_strformat("<<1>>", GetGuildName(guildId) or "")
        local hall = self:GetHall(guildId)
        nodes[#nodes + 1] = {
            nodeIndex     = "trader:" .. guildId,
            isGuildTrader = true,
            guildId       = guildId,
            originalName  = zo_strformat(L.GUILD_TRADER_NAME, guildName),
            zoneName      = L.GUILDS_ZONE,
            icon          = ICON_TRADER,
            type          = Data.TYPE_GUILD,
        }
        nodes[#nodes + 1] = {
            nodeIndex     = "hall:" .. guildId,
            isGuildHall   = true,
            isPlayerHouse = true,       -- перемещение как в дом игрока: бесплатно, без бесплатного пути
            guildId       = guildId,
            displayName   = hall.owner,
            originalName  = zo_strformat(L.GUILD_HALL_NAME, guildName),
            zoneName      = L.GUILDS_ZONE,
            icon          = ICON_HALL,
            type          = Data.TYPE_GUILD,
        }
    end
    return nodes
end

---------------------------------------------------------------------------
-- Торговец: святилище в городе торговца
---------------------------------------------------------------------------
function Guild:GetKioskName(guildId)
    local name = GetGuildOwnedKioskInfo and GetGuildOwnedKioskInfo(guildId)
    if name and name ~= "" then return zo_strformat("<<1>>", name) end
    return nil
end

-- Знаки препинания UTF-8, которые не должны прилипать к словам
local UTF8_MARKS = { "«", "»", "„", "“", "”", "‘", "’", "—", "–", "…", "\194\160" }

---------------------------------------------------------------------------
-- Буквы и слова UTF-8 — без шаблонов Lua с байтами больше 127.
-- В Lua игры такие шаблоны ([\128-\255], [^\128-\191]) не совпадают с
-- русскими буквами: русские слова пропадали целиком, и название города
-- ни с чем не сравнивалось. Поэтому текст разбирается по байтам вручную.
---------------------------------------------------------------------------
local IS_MARK = {}
for _, mark in ipairs(UTF8_MARKS) do IS_MARK[mark] = true end

-- Замена подстроки без шаблонов (поиск plain)
local function ReplacePlain(text, what, with)
    local parts, pos = {}, 1
    while true do
        local found = text:find(what, pos, true)
        if not found then break end
        parts[#parts + 1] = text:sub(pos, found - 1)
        parts[#parts + 1] = with
        pos = found + #what
    end
    parts[#parts + 1] = text:sub(pos)
    return table.concat(parts)
end

local function ByteAt(text, index)
    local value = text:byte(index)
    if value and value < 0 then value = value + 256 end
    return value
end

-- Буквы строки: каждая — целиком (одна латинская или несколько байтов UTF-8)
local function Chars(text)
    local chars = {}
    text = text or ""
    local index, length = 1, #text
    while index <= length do
        local finish = index
        while finish < length do
            local nextByte = ByteAt(text, finish + 1)
            if nextByte < 128 or nextByte >= 192 then break end
            finish = finish + 1
        end
        chars[#chars + 1] = text:sub(index, finish)
        index = finish + 1
    end
    return chars
end

-- Часть слова: латинская буква или цифра, любая не-ASCII буква, а также
-- символы из keep (например, апостроф и дефис)
local function IsWordChar(char, keep)
    if IS_MARK[char] then return false end
    if #char > 1 then return true end
    local value = ByteAt(char, 1)
    if (value >= 48 and value <= 57) or (value >= 65 and value <= 90) or (value >= 97 and value <= 122) then return true end
    return keep ~= nil and keep[char] == true
end

-- Слова текста: список { text = "слово", chars = { буквы } }
local function SplitWords(text, keep)
    local words, current = {}, {}
    local function Flush()
        if #current > 0 then
            words[#words + 1] = { text = table.concat(current), chars = current }
            current = {}
        end
    end
    for _, char in ipairs(Chars(text)) do
        if IsWordChar(char, keep) then current[#current + 1] = char else Flush() end
    end
    Flush()
    return words
end

-- Слова текста в нижнем регистре, по буквам
local function Words(text)
    local words = {}
    for _, word in ipairs(SplitWords(lower(text or ""))) do
        if #word.chars >= MIN_MATCH then words[#words + 1] = word.chars end
    end
    return words
end

-- Сколько первых букв совпадает (окончания могут отличаться: «Белкарте» и «Белкарта»)
local function MatchScore(a, b)
    local common = 0
    for index = 1, zo_min(#a, #b) do
        if a[index] ~= b[index] then break end
        common = common + 1
    end
    if common < MIN_MATCH or common < zo_min(#a, #b) - 2 then return 0 end
    return common
end

-- Слова в названиях святилищ без общих («святилище», «wayshrine»):
-- слово, которое есть в каждом четвёртом названии, ничего не различает
function Guild:GetWayshrineWords()
    local nodes = Data:GetNodes()
    if self.matchNodes == nodes and self.wayshrineWords then return self.wayshrineWords end
    -- Кэш поиска сбрасывается сразу; места запоминаются только в конце, чтобы
    -- при сбое список собрался заново, а не остался пустым
    self.matchCache = {}

    local entries, seen, total = {}, {}, 0
    for _, node in ipairs(nodes) do
        if node.type == Data.TYPE_WAYSHRINE then
            total = total + 1
            local words, keys = Words(node.originalName), {}
            for index, word in ipairs(words) do
                local key = table.concat(word)
                keys[index] = key
                seen[key] = (seen[key] or 0) + 1
            end
            entries[#entries + 1] = { nodeIndex = node.nodeIndex, words = words, keys = keys }
        end
    end
    local limit = zo_max(3, total / 4) or 3
    self.commonWords = {}
    for key, count in pairs(seen) do
        if count > limit then self.commonWords[key] = true end
    end
    for _, entry in ipairs(entries) do
        local distinct = {}
        for index, word in ipairs(entry.words) do
            if (seen[entry.keys[index]] or 0) <= limit then distinct[#distinct + 1] = word end
        end
        entry.words, entry.keys = distinct, nil
    end
    self.wayshrineWords, self.matchNodes = entries, nodes
    return entries
end

-- Убрать из текста цвета и ссылки чата
local function PlainText(text)
    text = text or ""
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H[^|]*|h(.-)|h", "%1"):gsub("|t[^|]*|t", "")
    return text
end

-- Святилища, чьи названия упомянуты в тексте: лучшие первыми
-- (больше совпавших букв; при равенстве — то, что упомянуто раньше)
function Guild:ScoreWayshrines(text)
    local textWords = Words(PlainText(text))
    local results = {}
    for _, entry in ipairs(self:GetWayshrineWords()) do
        local score, firstPos = 0, nil
        for _, nodeWord in ipairs(entry.words) do
            local wordBest, wordPos = 0, nil
            for pos, textWord in ipairs(textWords) do
                local match = MatchScore(nodeWord, textWord)
                if match > wordBest then wordBest, wordPos = match, pos end
            end
            score = score + wordBest
            if wordPos and (not firstPos or wordPos < firstPos) then firstPos = wordPos end
        end
        if score > 0 then results[#results + 1] = { nodeIndex = entry.nodeIndex, score = score, pos = firstPos } end
    end
    table.sort(results, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.pos < b.pos
    end)
    return results
end

-- Святилище, название которого упомянуто в тексте (или nil)
function Guild:FindWayshrine(text)
    text = PlainText(text)
    if text == "" then return nil end
    self:GetWayshrineWords()   -- сбрасывает кэш, если места пересобраны
    local cached = self.matchCache[text]
    if cached ~= nil then return cached or nil end

    local best = self:ScoreWayshrines(text)[1]
    best = best and best.nodeIndex
    self.matchCache[text] = best or false
    return best
end

-- Строки описания, где речь о торговце
local TRADER_HINTS = { "торгов", "киоск", "trader", "kiosk", "store", "händler", "marchand", "comerciante", "mercante" }

local function TraderLines(text)
    local lines = {}
    for line in (text or ""):gmatch("[^\n]+") do
        local low = lower(line)
        for _, hint in ipairs(TRADER_HINTS) do
            if low:find(hint, 1, true) then lines[#lines + 1] = line; break end
        end
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Город торговца: «Доннейлайн в Белкарте» — значит, святилище в Белкарте.
-- Сначала ищется святилище, в названии которого есть основа слова города
-- («Белкарт» из «Белкарте»); не нашлось — место на карте с таким названием
-- (город, район) и ближайшее к нему святилище той же локации.
---------------------------------------------------------------------------
-- Предлоги перед городом на языках игры
local TOWN_PREPOSITIONS = { " в ", " во ", " in ", " im ", " à ", " au ", " aux ", " en ", " a ", " w ", " we ", " na " }

-- Слова города (после последнего предлога; если предлога нет — все слова, кроме первого)
function Guild:GetKioskTownWords(kiosk)
    local text = PlainText(kiosk or "")
    for _, mark in ipairs(UTF8_MARKS) do text = ReplacePlain(text, mark, " ") end
    local town
    local low = " " .. lower(text) .. " "
    local bestPos
    for _, prep in ipairs(TOWN_PREPOSITIONS) do
        local pos = 1
        while true do
            local found = low:find(prep, pos, true)
            if not found then break end
            if not bestPos or found > bestPos then bestPos = found; town = text:sub(found - 1 + #prep) end
            pos = found + 1
        end
    end
    local words = {}
    local keep = { ["'"] = true, ["-"] = true }
    if town then
        for _, word in ipairs(SplitWords(town, keep)) do words[#words + 1] = word.text end
    else
        for index, word in ipairs(SplitWords(text, keep)) do
            if index > 1 then words[#words + 1] = word.text end
        end
    end
    -- Общие слова («святилище», «city») ничего не различают
    self:GetWayshrineWords()
    local filtered = {}
    for _, word in ipairs(words) do
        if #Chars(word) >= MIN_MATCH and not self.commonWords[lower(word)] then filtered[#filtered + 1] = word end
    end
    words = filtered
    -- Длинные слова первыми: у «Vivec City» сначала ищется «Vivec»
    table.sort(words, function(x, y) return #Chars(x) > #Chars(y) end)
    return words, town
end

-- Основы слова: целиком, без одной, двух и трёх последних букв (не короче четырёх)
local function Stems(word)
    local chars = Chars(word)
    local stems = {}
    for cut = 0, 3 do
        local count = #chars - cut
        if count < MIN_MATCH then break end
        stems[#stems + 1] = table.concat(chars, "", 1, count)
    end
    return stems
end

-- Есть ли основа в названии: как есть или без учёта регистра
local function HasStem(name, stem)
    if name:find(stem, 1, true) then return true end
    return lower(name):find(lower(stem), 1, true) ~= nil
end

-- Буква в «каноническом» виде: строчная, ё → е, латинские двойники русских
-- букв (a, e, o, p, c, x, y, k) → русские. В переводах встречаются смешанные
-- буквы, и «Белкарт» с латинской «а» иначе не совпал бы с русским
local CANON = {
    ["a"] = "а", ["e"] = "е", ["o"] = "о", ["p"] = "р", ["c"] = "с", ["x"] = "х", ["y"] = "у", ["k"] = "к",
    ["ё"] = "е", ["Ё"] = "е",
}
local UPPER_RU = {}
do
    local upper = { "А","Б","В","Г","Д","Е","Ж","З","И","Й","К","Л","М","Н","О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я" }
    local lowerRu = { "а","б","в","г","д","е","ж","з","и","й","к","л","м","н","о","п","р","с","т","у","ф","х","ц","ч","ш","щ","ъ","ы","ь","э","ю","я" }
    for index, char in ipairs(upper) do UPPER_RU[char] = lowerRu[index] end
end

local function CanonWords(text)
    local words = {}
    for _, word in ipairs(SplitWords(text)) do
        local chars = {}
        for _, char in ipairs(word.chars) do
            if #char == 1 then char = char:lower() end
            char = UPPER_RU[char] or char
            chars[#chars + 1] = CANON[char] or char
        end
        if #chars >= MIN_MATCH then words[#words + 1] = chars end
    end
    return words
end

-- Расстояние Левенштейна между словами (по буквам)
local function Distance(a, b)
    local previous, current = {}, {}
    for j = 0, #b do previous[j] = j end
    for i = 1, #a do
        current[0] = i
        for j = 1, #b do
            local cost = a[i] == b[j] and 0 or 1
            current[j] = zo_min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
        end
        previous, current = current, previous
    end
    return previous[#b]
end

-- Насколько слово города похоже на слово названия: 0 — не похоже.
-- Совпадает начало (окончания разные: «Белкарте» / «Белкарта») или
-- отличаются не больше двух букв
local function WordScore(town, word)
    local common = 0
    for index = 1, zo_min(#town, #word) do
        if town[index] ~= word[index] then break end
        common = common + 1
    end
    if common >= MIN_MATCH and common >= zo_min(#town, #word) - 2 then return common * 2 end
    local shortest = zo_min(#town, #word)
    if shortest >= 5 then
        local distance = Distance(town, word)
        if distance <= 2 then return (zo_max(#town, #word) - distance) * 2 - 1 end
    end
    return 0
end

-- Места, среди которых ищется святилище: святилища, а на случай, если
-- святилище распознано не как святилище, — и прочие места с перемещением
local function Candidates()
    local list = {}
    for _, node in ipairs(Data:GetNodes()) do
        if type(node.nodeIndex) == "number" and (node.type == Data.TYPE_WAYSHRINE or node.type == Data.TYPE_OTHER) then
            list[#list + 1] = node
        end
    end
    return list
end

-- Святилища, похожие на город: лучшие первыми ({ node, score })
function Guild:RankByTown(words)
    local results = {}
    local townWords = {}
    for _, word in ipairs(words) do
        for _, chars in ipairs(CanonWords(word)) do townWords[#townWords + 1] = chars end
    end
    for _, node in ipairs(Candidates()) do
        local score = 0
        for _, nameWord in ipairs(CanonWords(node.originalName)) do
            for _, townWord in ipairs(townWords) do
                score = zo_max(score, WordScore(townWord, nameWord))
            end
        end
        if score > 0 then
            if node.type == Data.TYPE_WAYSHRINE then score = score + 1 end
            results[#results + 1] = { node = node, score = score }
        end
    end
    table.sort(results, function(x, y)
        if x.score ~= y.score then return x.score > y.score end
        return #x.node.originalName < #y.node.originalName
    end)
    return results
end

-- Самый простой способ, без разбора на буквы: основа города (город без
-- последних байтов) ищется обычным поиском подстроки в названиях святилищ.
-- Обычный поиск работает в игре всегда (на нём же поиск по списку мест)
function Guild:FindWayshrineByStem(town)
    if not town or town == "" then return nil end
    local pieces = {}
    local text = " " .. lower(town) .. " "
    local pos = 1
    while true do
        local space = text:find(" ", pos + 1, true)
        if not space then break end
        local piece = text:sub(pos + 1, space - 1)
        if #piece >= 4 and not (self.commonWords and self.commonWords[piece]) then pieces[#pieces + 1] = piece end
        pos = space
    end
    table.sort(pieces, function(x, y) return #x > #y end)
    local candidates = Candidates()
    local names = {}
    for index, node in ipairs(candidates) do names[index] = " " .. lower(node.originalName or "") end
    for _, piece in ipairs(pieces) do
        -- Отрезается до 6 байтов (до трёх русских букв окончания), но основа —
        -- не короче 4 байтов и двух третей слова
        local minLength = zo_max(4, math.floor(#piece * 2 / 3))
        for cut = 0, 6 do
            local stem = piece:sub(1, #piece - cut)
            if #stem < minLength then break end
            local best, bestLength
            for index, node in ipairs(candidates) do
                -- Только с начала слова: « белкарт» в « дорожное святилище белкарта»
                if names[index]:find(" " .. stem, 1, true) then
                    local length = #names[index] + (node.type == Data.TYPE_WAYSHRINE and 0 or 1000)
                    if not bestLength or length < bestLength then best, bestLength = node, length end
                end
            end
            if best then return best.nodeIndex end
        end
    end
    return nil
end

function Guild:FindWayshrineByTown(words)
    local best = self:RankByTown(words)[1]
    return best and best.node.nodeIndex or nil
end

-- Для отчёта: святилища, чьи названия начинаются похоже на город (первые три буквы)
function Guild:SimilarNames(words, limit)
    local names = {}
    local first = words[1] and CanonWords(words[1])[1]
    if not first then return names end
    local prefix = table.concat(first, "", 1, zo_min(3, #first))
    for _, node in ipairs(Candidates()) do
        for _, nameWord in ipairs(CanonWords(node.originalName)) do
            if table.concat(nameWord, "", 1, zo_min(3, #nameWord)) == prefix then
                names[#names + 1] = node.originalName
                break
            end
        end
        if #names >= limit then break end
    end
    return names
end

-- Место на карте (город, район) с названием города — ближайшее святилище в той же локации
function Guild:FindWayshrineNearPlace(words)
    if not (GetNumZones and GetNumPOIs and GetPOIInfo and GetPOIMapInfo and GetFastTravelNodePOIIndicies) then return nil end
    for _, word in ipairs(words) do
        for _, stem in ipairs(Stems(word)) do
            for zoneIndex = 1, GetNumZones() do
                for poiIndex = 1, GetNumPOIs(zoneIndex) do
                    local name = GetPOIInfo(zoneIndex, poiIndex)
                    if name and name ~= "" and HasStem(zo_strformat("<<1>>", name), stem) then
                        local x, y = GetPOIMapInfo(zoneIndex, poiIndex)
                        local best, bestDistance
                        for _, node in ipairs(Data:GetNodes()) do
                            if node.type == Data.TYPE_WAYSHRINE and type(node.nodeIndex) == "number" then
                                local nodeZone, nodePoi = GetFastTravelNodePOIIndicies(node.nodeIndex)
                                if nodeZone == zoneIndex and nodePoi then
                                    local nx, ny = GetPOIMapInfo(nodeZone, nodePoi)
                                    local distance = (nx - x) * (nx - x) + (ny - y) * (ny - y)
                                    if not bestDistance or distance < bestDistance then best, bestDistance = node, distance end
                                end
                            end
                        end
                        if best then return best.nodeIndex end
                    end
                end
            end
        end
    end
    return nil
end

-- Святилище у торговца гильдии (или nil, причина).
-- Второе значение при успехе — откуда взято: "manual", "stem", "town", "place", "kiosk", "description"
function Guild:GetTraderWayshrine(guildId)
    local kiosk = self:GetKioskName(guildId)
    if not kiosk then return nil, L.REASON_NO_TRADER end

    pcall(self.GetWayshrineWords, self)   -- сбрасывает кэш, если места пересобраны
    self.matchCache = self.matchCache or {}
    local cacheKey = "trader:" .. kiosk
    local cached = self.matchCache[cacheKey]
    local nodeIndex, source = QTM.sv.traderShrines[kiosk], "manual"
    if not nodeIndex and cached ~= nil then
        nodeIndex, source = cached and cached.nodeIndex, cached and cached.source
    elseif not nodeIndex then
        -- Автопоиск не должен ломать интерфейс: при ошибке — «не найдено»,
        -- святилище можно выбрать вручную
        local ok, foundIndex, foundSource = pcall(self.SearchTraderWayshrine, self, guildId, kiosk)
        if ok then
            nodeIndex, source = foundIndex, foundSource
        else
            nodeIndex = nil
            self.lastSearchError = foundIndex
        end
        self.matchCache[cacheKey] = nodeIndex and { nodeIndex = nodeIndex, source = source } or false
    end
    local node = nodeIndex and Data:GetNode(nodeIndex)
    if not node then return nil, L.REASON_TRADER_UNKNOWN end
    return node, source
end

-- Автопоиск святилища торговца (nodeIndex, откуда взято)
function Guild:SearchTraderWayshrine(guildId, kiosk)
    local nodeIndex, source
    do
        local words, town = self:GetKioskTownWords(kiosk)
        nodeIndex, source = self:FindWayshrineByStem(town), "stem"
        if not nodeIndex then nodeIndex, source = self:FindWayshrineByTown(words), "town" end
        if not nodeIndex then nodeIndex, source = self:FindWayshrineNearPlace(words), "place" end
        if not nodeIndex then nodeIndex, source = self:FindWayshrine(kiosk), "kiosk" end
        if not nodeIndex then
            local about = (GetGuildDescription and GetGuildDescription(guildId) or "") .. "\n"
                .. (GetGuildMotD and GetGuildMotD(guildId) or "")
            nodeIndex = self:FindWayshrine(TraderLines(about)) or self:FindWayshrine(about)
            source = "description"
        end
    end
    return nodeIndex, source
end

-- Выбор святилища торговца вручную (один раз — запоминается для этого торговца).
-- travelAfter — сразу переместиться к выбранному
function Guild:PickTraderWayshrine(guildId, travelAfter)
    local kiosk = self:GetKioskName(guildId)
    if not kiosk then
        Data.Alert(L.REASON_NO_TRADER)
        return
    end
    -- В поиск подставляется начало названия города: сразу видны подходящие святилища
    local _, town = self:GetKioskTownWords(kiosk)
    local query = ""
    if town then
        local chars = Chars(zo_strtrim(town))
        local count = #chars > 5 and #chars - 2 or #chars
        query = table.concat(chars, "", 1, count)
    end
    QTM.PlacePicker:Open(function(nodeIndex)
        local node = Data:GetNode(nodeIndex)
        if not node or node.type ~= Data.TYPE_WAYSHRINE then
            Data.Alert(L.GUILD_PICK_WAYSHRINE)
            return
        end
        QTM.sv.traderShrines[kiosk] = nodeIndex
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.GUILD_TRADER_SET, kiosk, node.name))
        self:Changed()
        if travelAfter then self:Travel("trader", guildId) end
    end, nil, query)
end

function Guild:ResetTraderWayshrine(guildId)
    local kiosk = self:GetKioskName(guildId)
    if kiosk then QTM.sv.traderShrines[kiosk] = nil end
    self:Changed()
end

---------------------------------------------------------------------------
-- Гильдхолл: владелец (по умолчанию глава гильдии) и дом (по умолчанию основной)
---------------------------------------------------------------------------
function Guild:GetLeader(guildId)
    local _, _, leader = GetGuildInfo(guildId)
    return leader
end

function Guild:GetHall(guildId)
    local saved = QTM.sv.guildHalls[guildId]
    local owner = saved and saved.owner
    local isDefault = owner == nil or owner == ""
    if isDefault then owner = self:GetLeader(guildId) end
    return { owner = owner, houseId = saved and saved.houseId or nil, isDefault = isDefault }
end

function Guild:SetHallOwner(guildId, text)
    text = zo_strtrim(text or "")
    local saved = QTM.sv.guildHalls[guildId] or {}
    if text == "" then
        saved.owner = nil
    else
        if text:sub(1, 1) ~= "@" then text = "@" .. text end
        saved.owner = text
    end
    QTM.sv.guildHalls[guildId] = saved
    self:Changed()
end

function Guild:ShowHallOwnerDialog(guildId)
    local saved = QTM.sv.guildHalls[guildId]
    ZO_Dialogs_ShowDialog("MUNDUSGATE_GUILD_HALL", { guildId = guildId }, {
        mainTextParams  = { zo_strformat("<<1>>", GetGuildName(guildId) or ""), self:GetLeader(guildId) or "" },
        initialEditText = saved and saved.owner or "",
    })
end

function Guild:PickHallHouse(guildId)
    QTM.PlacePicker:Open(function(nodeIndex)
        local node = Data:GetNode(nodeIndex)
        if not node or node.type ~= Data.TYPE_HOUSE then
            Data.Alert(L.GUILD_PICK_HOUSE)
            return
        end
        local saved = QTM.sv.guildHalls[guildId] or {}
        saved.houseId = Data:GetHouseId(node)
        QTM.sv.guildHalls[guildId] = saved
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.GUILD_HALL_HOUSE_SET, node.originalName))
        self:Changed()
    end, nil, "")
end

function Guild:ResetHallHouse(guildId)
    local saved = QTM.sv.guildHalls[guildId]
    if saved then saved.houseId = nil end
    self:Changed()
end

function Guild:JumpToHall(guildId)
    local hall = self:GetHall(guildId)
    if not hall.owner or hall.owner == "" then
        Data.Alert(L.REASON_NO_HALL)
        return nil
    end
    if hall.owner == GetDisplayName() then
        -- Свой дом: напрямую (не выбран — основной)
        local houseId = hall.houseId or (GetHousingPrimaryHouse and GetHousingPrimaryHouse()) or 0
        if houseId ~= 0 and RequestJumpToHouse then
            RequestJumpToHouse(houseId, QTM.sv.houseOutside)
        else
            Data.Alert(L.GUILD_HALL_OWN)
            return nil
        end
    elseif hall.houseId and JumpToSpecificHouse then
        JumpToSpecificHouse(hall.owner, hall.houseId)
    else
        JumpToHouse(hall.owner)
    end
    return "started"
end

---------------------------------------------------------------------------
-- Доступность (Data:GetNodeStatus)
---------------------------------------------------------------------------
function Guild:GetStatus(node)
    if node.isGuildHall then
        local hall = self:GetHall(node.guildId)
        if not hall.owner or hall.owner == "" then return false, L.REASON_NO_HALL end
        return true
    end
    local target, reason = self:GetTraderWayshrine(node.guildId)
    if not target then return false, reason end
    return Data:GetNodeStatus(target)
end

-- Подпись под названием: куда ведёт место
function Guild:Describe(node)
    if node.isGuildHall then
        local hall = self:GetHall(node.guildId)
        local text = zo_strformat(L.GUILD_HALL_OWNER, hall.owner or "?")
        if hall.isDefault then text = text .. " " .. L.GUILD_HALL_DEFAULT end
        if hall.houseId then
            local houseName = GetCollectibleName and GetCollectibleIdForHouse and GetCollectibleName(GetCollectibleIdForHouse(hall.houseId))
            if houseName and houseName ~= "" then text = text .. "\n" .. zo_strformat("<<1>>", houseName) end
        end
        return text
    end
    local kiosk = self:GetKioskName(node.guildId)
    if not kiosk then return L.REASON_NO_TRADER end
    local target, source = self:GetTraderWayshrine(node.guildId)
    local text = kiosk
    if target then
        text = text .. "\n" .. zo_strformat(L.GUILD_TRADER_SHRINE, target.name)
        if source == "description" then text = text .. " " .. L.GUILD_TRADER_FROM_DESC end
        if source == "manual" then text = text .. " " .. L.GUILD_TRADER_MANUAL end
    end
    return text
end

function Guild:Changed()
    self.matchNodes = nil
    Data:Invalidate()
    if QTM.RefreshAllViews then QTM.RefreshAllViews() end
    if QTM.Buttons and QTM.Buttons.RefreshAll then QTM.Buttons:RefreshAll() end
    self:RefreshHomeButtons()
end

---------------------------------------------------------------------------
-- Действия с местом гильдии (ПКМ по кнопке на вкладке гильдии)
---------------------------------------------------------------------------
-- Место гильдии. Список мест мог собраться до того, как игра загрузила
-- гильдии (сразу после входа) — тогда пересобрать его
function Guild:GetNode(kind, guildId)
    if not guildId then return nil end
    local key = kind .. ":" .. guildId
    local node = Data:GetNode(key)
    if not node then
        Data:Invalidate()
        node = Data:GetNode(key)
    end
    return node
end

function Guild:Travel(kind, guildId)
    local node = self:GetNode(kind, guildId)
    PlaySound(SOUNDS.DEFAULT_CLICK)
    if not node then
        self:Report(guildId, L.GUILD_DIAG_NO_NODE)
        return
    end
    -- Святилище торговца не нашлось само — выбрать его один раз вручную
    if kind == "trader" and self:GetKioskName(guildId) and not self:GetTraderWayshrine(guildId) then
        self:Report(guildId, L.REASON_TRADER_UNKNOWN)
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.GENERAL_ALERT_ERROR, L.GUILD_PICK_ONCE)
        self:PickTraderWayshrine(guildId, true)
        return
    end
    local result = Data:Travel(node, false, "Menu")
    if result == "started" then
        SCENE_MANAGER:ShowBaseScene()
    elseif result == nil and kind == "trader" then
        -- Не получилось — написать в чат, что видит аддон (чтобы понять причину)
        local _, reason = Data:GetNodeStatus(node)
        self:Report(guildId, reason)
    end
end

-- Строка в чат: торговец, город, найденное святилище и причина отказа
function Guild:Report(guildId, reason)
    local out = CHAT_ROUTER and function(text) CHAT_ROUTER:AddSystemMessage(text) end or d
    local kiosk = self:GetKioskName(guildId) or "-"
    local _, town = self:GetKioskTownWords(kiosk)
    local target = self:GetTraderWayshrine(guildId)
    out(zo_strformat(L.GUILD_DIAG_LINE, kiosk, town or "-", target and target.name or "-", reason or "-"))
    if not target then
        local words = self:GetKioskTownWords(kiosk)
        local wayshrines = 0
        for _, node in ipairs(Data:GetNodes()) do
            if node.type == Data.TYPE_WAYSHRINE then wayshrines = wayshrines + 1 end
        end
        local similar = self:SimilarNames(words, 5)
        out(zo_strformat(L.GUILD_DIAG_SIMILAR, wayshrines, #similar > 0 and table.concat(similar, "; ") or "-"))
        self:ReportBytes(out, town, words)
        if self.lastSearchError then out("Mundus Gate debug: " .. tostring(self.lastSearchError)) end
    end
end

-- Техническая строка для разбора: байты города, сколько слов разобрано,
-- и пример названия святилища (чтобы было видно, в одной ли они кодировке)
function Guild:ReportBytes(out, town, words)
    local function Hex(text)
        local bytes = {}
        for index = 1, zo_min(#(text or ""), 12) do bytes[#bytes + 1] = string.format("%02X", ByteAt(text, index)) end
        return table.concat(bytes, " ")
    end
    local sample
    for _, node in ipairs(Candidates()) do
        if node.type == Data.TYPE_WAYSHRINE then sample = node; break end
    end
    local sampleName = sample and sample.originalName or "-"
    out(string.format("Mundus Gate debug: town [%s] words=%d | %s [%s] words=%d | lower=%s",
        Hex(town), #(words or {}), sampleName, Hex(sampleName), #CanonWords(sampleName),
        tostring(lower("БЕЛ") == "бел")))
end

function Guild:ShowMenu(control, kind, guildId)
    local node = self:GetNode(kind, guildId)
    if not node then return end
    ClearMenu()
    local available = Data:GetNodeStatus(node)
    if available then
        AddMenuItem(L.CTX_TRAVEL, function() self:Travel(kind, guildId) end)
    end
    if Data:IsFavorite(node.nodeIndex) then
        AddMenuItem(L.MAP_REMOVE, function() Data:SetFavorite(node.nodeIndex, false); self:Changed() end)
    else
        AddMenuItem(L.MAP_ADD, function()
            Data:SetFavorite(node.nodeIndex, true)
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.MAP_ADDED, node.name))
            self:Changed()
        end)
    end
    AddMenuItem(L.CTX_ADD_BUTTON, function()
        QTM.Buttons:Add(node.nodeIndex)
        QTM.Buttons:UpdateVisibility()
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.ALERT_BUTTON_ADDED, node.name))
    end)
    AddMenuItem(L.CTX_ADD_WHEEL, function()
        if QTM.Wheel:AddSlot(node.nodeIndex) then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.ALERT_WHEEL_ADDED, node.name))
        end
    end)
    if kind == "trader" then
        AddMenuItem(L.GUILD_CTX_PICK_SHRINE, function() self:PickTraderWayshrine(guildId) end)
        local kiosk = self:GetKioskName(guildId)
        if kiosk and QTM.sv.traderShrines[kiosk] then
            AddMenuItem(L.GUILD_CTX_AUTO_SHRINE, function() self:ResetTraderWayshrine(guildId) end)
        end
    else
        AddMenuItem(L.GUILD_CTX_HALL_OWNER, function() self:ShowHallOwnerDialog(guildId) end)
        AddMenuItem(L.GUILD_CTX_HALL_HOUSE, function() self:PickHallHouse(guildId) end)
        if self:GetHall(guildId).houseId then
            AddMenuItem(L.GUILD_CTX_HALL_PRIMARY, function() self:ResetHallHouse(guildId) end)
        end
    end
    ShowMenu(control)
end

---------------------------------------------------------------------------
-- Вкладка гильдии «Главная»: кнопка под торговцем и раздел «Гильдейский холл»
-- в том же виде, что «Владения» и «Торговец»: заголовок, значок, подпись, кнопка
---------------------------------------------------------------------------
local WM = WINDOW_MANAGER

local function NormalTextColor()
    if GetInterfaceColor and INTERFACE_COLOR_TYPE_TEXT_COLORS then
        return GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL)
    end
    return 0.77, 0.76, 0.62, 1
end

function Guild:MakeTravelButton(name, parent, kind, text)
    local button = WM:CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
    button:SetDimensions(200, 28)
    button:SetText(text)
    button.kind = kind
    button:SetHandler("OnClicked", function(c)
        local guildId = self:GetHomeGuildId()
        if guildId then self:Travel(c.kind, guildId) end
    end)
    -- ПКМ — действия (своё имя обработчика, чтобы не заменить обработчики кнопки)
    button:SetHandler("OnMouseUp", function(c, mouseButton, upInside)
        local guildId = self:GetHomeGuildId()
        if upInside and guildId and mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
            ZO_Tooltips_HideTextTooltip()
            self:ShowMenu(c, c.kind, guildId)
        end
    end, QTM.name)
    button:SetHandler("OnMouseEnter", function(c) self:OnButtonEnter(c) end, QTM.name)
    button:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end, QTM.name)
    return button
end

function Guild:CreateHomeButtons()
    local trader = ZO_GuildHomeTrader
    local traderName = ZO_GuildHomeTraderName
    if not (trader and traderName) then return end
    local home = trader:GetParent()
    self.traderName = traderName
    self.bidsButton = ZO_GuildHomeTraderViewWeeklyBids

    -- Под торговцем: «Перемещение к торговцу»
    local traderButton = self:MakeTravelButton("MundusGateGuildTraderTravel", trader, "trader", L.GUILD_BUTTON_TRADER)

    -- Раздел «Гильдейский холл»: заголовок, значок, подпись, кнопка
    local hall = WM:CreateControl("MundusGateGuildHall", home, CT_CONTROL)
    hall:SetDimensions(200, 230)
    hall:SetAnchor(TOP, traderButton, BOTTOM, 0, 30)

    local header = WM:CreateControl("MundusGateGuildHallOwnership", hall, CT_LABEL)
    header:SetFont("ZoFontHeader2")
    header:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    header:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    header:SetAnchor(TOPLEFT, hall, TOPLEFT, 0, 0)
    header:SetAnchor(TOPRIGHT, hall, TOPRIGHT, 0, 0)
    header:SetText(L.GUILD_HALL_HEADER)

    local icon = WM:CreateControl("MundusGateGuildHallIcon", hall, CT_TEXTURE)
    icon:SetDimensions(96, 96)
    icon:SetAnchor(TOP, header, BOTTOM, 0, 6)
    icon:SetTexture(ICON_HALL)
    icon:SetMouseEnabled(true)
    icon.kind = "hall"
    icon:SetHandler("OnMouseEnter", function(c) self:OnButtonEnter(c) end)
    icon:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end)
    icon:SetHandler("OnMouseUp", function(c, mouseButton, upInside)
        local guildId = self:GetHomeGuildId()
        if upInside and guildId and mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
            ZO_Tooltips_HideTextTooltip()
            self:ShowMenu(c, "hall", guildId)
        end
    end)

    local name = WM:CreateControl("MundusGateGuildHallName", hall, CT_LABEL)
    name:SetFont("ZoFontHeader2")
    name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    name:SetColor(NormalTextColor())
    name:SetAnchor(TOPLEFT, hall, TOPLEFT, 0, 132)
    name:SetAnchor(TOPRIGHT, hall, TOPRIGHT, 0, 132)

    local hallButton = self:MakeTravelButton("MundusGateGuildHallTravel", hall, "hall", L.GUILD_BUTTON_HALL)
    hallButton:SetAnchor(TOP, name, BOTTOM, 0, 10)

    self.home = { traderButton = traderButton, hall = hall, hallIcon = icon, hallName = name, hallButton = hallButton }

    if GUILD_HOME_SCENE then
        GUILD_HOME_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING then self:RefreshHomeButtons() end
        end)
    end
    if GUILD_HOME and (SecurePostHook or ZO_PostHook) then
        local hook = SecurePostHook or ZO_PostHook
        -- RefreshAll вызывается при смене гильдии, RefreshPermissions — когда меняется видимость «Ставок»
        for _, method in ipairs({ "RefreshAll", "RefreshPermissions", "RefreshTraderOwnership" }) do
            if GUILD_HOME[method] then hook(GUILD_HOME, method, function() self:RefreshHomeButtons() end) end
        end
    end
    self:RefreshHomeButtons()
end

function Guild:GetHomeGuildId()
    return GUILD_HOME and GUILD_HOME.guildId or nil
end

-- Подпись под значком гильдхолла: дом и владелец
function Guild:GetHallCaption(guildId)
    local hall = self:GetHall(guildId)
    if not hall.owner or hall.owner == "" then return L.REASON_NO_HALL end
    local houseName
    if hall.houseId and GetCollectibleIdForHouse and GetCollectibleName then
        houseName = zo_strformat("<<1>>", GetCollectibleName(GetCollectibleIdForHouse(hall.houseId)) or "")
    end
    if not houseName or houseName == "" then houseName = L.GUILD_HALL_PRIMARY end
    return zo_strformat(L.GUILD_HALL_CAPTION, houseName, hall.owner)
end

function Guild:RefreshHomeButtons()
    local home = self.home
    local guildId = self:GetHomeGuildId()
    if not home or not guildId then return end

    -- Кнопка торговца — под «Ставками за неделю», если они видны, иначе под именем торговца
    local below = (self.bidsButton and not self.bidsButton:IsHidden()) and self.bidsButton or self.traderName
    home.traderButton:ClearAnchors()
    home.traderButton:SetAnchor(TOP, below, BOTTOM, 0, 10)

    local traderNode = self:GetNode("trader", guildId)
    home.traderButton:SetHidden(GetGuildOwnedKioskInfo(guildId) == nil)
    home.traderButton:SetAlpha((traderNode and Data:GetNodeStatus(traderNode)) and 1 or 0.6)

    local hallNode = self:GetNode("hall", guildId)
    local hallAvailable = hallNode and Data:GetNodeStatus(hallNode)
    home.hallIcon:SetAlpha(hallAvailable and 1 or 0.2)
    home.hallName:SetText(self:GetHallCaption(guildId))
    home.hallButton:SetAlpha(hallAvailable and 1 or 0.6)
end

function Guild:OnButtonEnter(control)
    local guildId = self:GetHomeGuildId()
    local node = guildId and self:GetNode(control.kind, guildId)
    if not node then return end
    local title = control.kind == "trader" and L.GUILD_TRAVEL_TRADER or L.GUILD_TRAVEL_HALL
    local available, reason = Data:GetNodeStatus(node)
    local lines = { title, self:Describe(node) }
    if available then
        lines[#lines + 1] = Data:GetPriceLine(node, "Menu")
    elseif reason then
        lines[#lines + 1] = "|cFF6060" .. reason .. "|r"
    end
    lines[#lines + 1] = "|c8A8A8A" .. L.GUILD_BUTTON_HINT .. "|r"
    QTM.ShowTip("guild", control, RIGHT, table.concat(lines, "\n"))
end
