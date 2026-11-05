--	TOM Reborn - Roleplay - Splitter (v6.5.0)
--	✅ P5YCH3: New file. Cuts a long text into parts that each fit one chat line. Pure Lua, no game calls.
--	Text is read as UTF-8 characters, never bytes. Each part ends at the strongest break that fits (blank line, line break, sentence end, space);
--	a word is only cut when it is longer than a whole line. Markers go before/after the parts and may use {n} (part number) and {t} (total).
--	Text containing | and parts starting with / are refused (chat reads them as codes and commands).

tomRP = tomRP or {}
local S = {}
tomRP.Splitter = S

local byte, sub, concat, floor = string.byte, string.sub, table.concat, math.floor

-- ✅ P5YCH3: Optional invisible tag (four zero-width spaces) placed in front of each part so tagged lines can be told apart when recording. A label, not security.
S.TAG = "\226\128\139\226\128\139\226\128\139\226\128\139"
S.TAG_LEN = 4

local ELLIPSIS, EMDASH = "\226\128\166", "\226\128\148"
local LDQUO, RDQUO, RSQUO = "\226\128\156", "\226\128\157", "\226\128\153"

function S.StripTag(text)
	if type(text) == "string" and sub(text, 1, #S.TAG) == S.TAG then
		return sub(text, #S.TAG + 1), true
	end
	return text, false
end

-- Returns one character (as a string) and the next byte position, or nil + the position of the problem.
local function readChar(text, at)
	local first = byte(text, at)
	if first < 128 then return sub(text, at, at), at + 1 end
	local size
	if first >= 194 and first <= 223 then size = 2
	elseif first >= 224 and first <= 239 then size = 3
	elseif first >= 240 and first <= 244 then size = 4
	else return nil, at end
	if at + size - 1 > #text then return nil, at end
	for k = 1, size - 1 do
		local b = byte(text, at + k)
		if b < 128 or b > 191 then return nil, at + k end
	end
	-- reject overlong forms and surrogates
	local b2 = byte(text, at + 1)
	if first == 224 and b2 < 160 then return nil, at end
	if first == 237 and b2 >= 160 then return nil, at end
	if first == 240 and b2 < 144 then return nil, at end
	if first == 244 and b2 >= 144 then return nil, at end
	return sub(text, at, at + size - 1), at + size
end

-- Number of characters in a UTF-8 string, or nil + byte position of the first bad sequence.
function S.Length(text)
	if type(text) ~= "string" then return nil, 0 end
	local at, count = 1, 0
	while at <= #text do
		local ch, nextAt = readChar(text, at)
		if not ch then return nil, nextAt end
		count, at = count + 1, nextAt
	end
	return count
end

-- Whitespace classes: 1 = space-like, 3 = line break. Anything else is 0.
local SPACE_CHARS = { [" "] = 1, ["\t"] = 1, ["\r"] = 3, ["\n"] = 3, ["\194\160"] = 1, ["\226\128\168"] = 3, ["\226\128\169"] = 3, ["\194\133"] = 3, ["\227\128\128"] = 1 }
local TERMINATORS = { ["."] = true, ["!"] = true, ["?"] = true, [ELLIPSIS] = true }
local CLOSERS = { ['"'] = true, ["'"] = true, [RDQUO] = true, [RSQUO] = true, [")"] = true, ["]"] = true, ["}"] = true, ["\194\187"] = true, ["\226\128\186"] = true }

local function isControl(ch)
	local b = byte(ch, 1)
	return #ch == 1 and (b < 32 or b == 127)
end

-- Reads the text into characters (atoms) and the strength of the gap before each one.
-- Returns atoms, gaps (gaps[i] = 0 none, 1 space, 2 sentence end, 3 line break, 4 blank line) or nil + message key + position.
local function readAtoms(text, markers)
	local atoms, gaps, n = {}, {}, 0
	local at, pending, lines = 1, 0, 0
	while at <= #text do
		local ch, nextAt = readChar(text, at)
		if not ch then return nil, "BAD_TEXT", nextAt end
		if ch == "|" then return nil, "PIPE", at end
		local space = SPACE_CHARS[ch]
		if space then
			if space == 3 then lines = lines + 1 end
			if space > pending then pending = space end
		else
			if isControl(ch) then return nil, "CONTROL", at end
			if n > 0 and pending > 0 then
				-- two or more line breaks in one gap (a blank line) make a paragraph break
				gaps[n + 1] = (pending == 3 and lines >= 2) and 4 or pending
			elseif n > 0 then
				gaps[n + 1] = 0
			else
				gaps[1] = 0
			end
			n = n + 1
			atoms[n] = ch
			pending, lines = 0, 0
		end
		at = nextAt
	end
	-- sentence ends: a terminator (optionally followed by closing quotes/brackets) before a plain space becomes strength 2
	if markers ~= false then
		local ending = false
		for i = 1, n do
			local ch = atoms[i]
			if i > 1 and gaps[i] == 1 and ending then gaps[i] = 2 end
			if TERMINATORS[ch] then ending = true
			elseif not CLOSERS[ch] then ending = false end
		end
	end
	return atoms, gaps, n
end

-- A marker (prefix/suffix) must be a single line without |, controls or newline. Returns its characters or nil + key.
local function readMarker(text)
	if text == nil then return {} end
	if type(text) ~= "string" then return nil, "MARKER_TYPE" end
	local chars, at = {}, 1
	while at <= #text do
		local ch, nextAt = readChar(text, at)
		if not ch then return nil, "MARKER_BAD" end
		if ch == "|" then return nil, "MARKER_PIPE" end
		if ch == "\n" or ch == "\r" or isControl(ch) and ch ~= "\t" then return nil, "MARKER_LINE" end
		chars[#chars + 1] = ch
		at = nextAt
	end
	return chars
end

local function digitsOf(number)
	return #tostring(number)
end

-- Marker text for part n of t ({n} and {t} replaced).
local function renderMarker(markerText, n, t)
	if markerText == nil or markerText == "" then return "" end
	local out = markerText:gsub("{n}", tostring(n)):gsub("{t}", tostring(t))
	return out
end

-- Widest length a marker can take when its numbers have `digits` digits.
local function markerWidth(markerText, digits)
	if markerText == nil or markerText == "" then return 0 end
	local filled = markerText:gsub("{n}", string.rep("9", digits)):gsub("{t}", string.rep("9", digits))
	return S.Length(filled) or 0
end

-- ✅ P5YCH3: Split(text, options) -> parts, info   or   nil, messageKey, detail
--   options: maxChars (characters one line may hold, markers included), reserve (characters kept free for the tag), prefix / suffix (markers),
--   sentences (false = ignore sentence ends), paragraphs (true = a blank line always starts a new part),
--   everyPart (true = prefix and suffix go on every part, even a single one; false = only between parts: no prefix on the first, no suffix on the last).
--   info: total, chars, longest, lengths, limit. All or nothing: an error never returns a partial list.
function S.Split(text, options)
	options = options or {}
	if type(text) ~= "string" then return nil, "BAD_TEXT", 0 end
	local limit = options.maxChars
	if type(limit) ~= "number" or limit ~= limit or limit < 1 or limit ~= floor(limit) or limit == math.huge then return nil, "LIMIT" end
	limit = limit - (options.reserve or 0)
	if limit < 1 then return nil, "TOO_SMALL" end
	local prefix, suffix = options.prefix, options.suffix
	if prefix == nil then prefix = "+ " end
	if suffix == nil then suffix = " +" end
	local err
	local _
	_, err = readMarker(prefix); if err then return nil, err end
	_, err = readMarker(suffix); if err then return nil, err end
	if prefix:match("^%s*/") then return nil, "PREFIX_COMMAND" end

	local atoms, gaps, n = readAtoms(text, options.sentences ~= false)
	if not atoms then return nil, gaps, n end
	if n == 0 then return nil, "EMPTY" end

	-- cumulative count of gaps so the length of any run of atoms is a subtraction
	local gapCount = {}
	local running = 0
	for i = 1, n do
		if gaps[i] > 0 and i > 1 then running = running + 1 end
		gapCount[i] = running
	end
	local function runLength(a, b)
		-- characters in atoms a..b with one space per interior gap (the gap before atom a is not part of the run)
		return (b - a + 1) + (gapCount[b] - gapCount[a])
	end

	-- paragraph mode: for every atom, the end of the paragraph it sits in (the atom just before the next blank line), found in one pass from the back
	local nextParaEnd = {}
	if options.paragraphs then
		for i = n, 1, -1 do
			if i < n and gaps[i + 1] == 4 then nextParaEnd[i] = i else nextParaEnd[i] = nextParaEnd[i + 1] end
		end
	end

	local digits = 1
	for attempt = 1, 4 do
		local preW, sufW = markerWidth(prefix, digits), markerWidth(suffix, digits)
		local parts, spans = {}, {}
		local start = 1
		local failed
		while start <= n do
			local first = (#spans == 0)
			local lead = (options.everyPart or not first) and preW or 0
			local tail = options.everyPart and sufW or 0	-- the last part carries the suffix too when markers go on every part
			-- paragraph mode: the end of the paragraph this part starts in (the atom just before the next blank line), if any
			local paraEnd = options.paragraphs and nextParaEnd[start] or nil
			-- does the rest fit as the final part (prefix only)?
			if not paraEnd and runLength(start, n) <= limit - lead - tail then
				spans[#spans + 1] = { start, n }
				start = n + 1
			else
				local room = limit - lead - sufW
				if room < 1 then return nil, "TOO_SMALL" end
				-- the furthest atom b whose run still fits the room
				local b = start
				while b < n and runLength(start, b + 1) <= room do b = b + 1 end
				-- paragraph mode: a part may not run across a blank line
				local cut
				if paraEnd and runLength(start, paraEnd) <= room then cut = paraEnd end
				if not cut then
					local bestRank, bestAt = 0, nil
					for e = start, b do
						-- cutting after atom e needs a gap right after it; the gap after the last atom that fits is simply dropped
						local rank = (e < n) and gaps[e + 1] or 0
						if rank > 0 and rank >= bestRank then bestRank, bestAt = rank, e end
					end
					cut = bestAt or b
				end
				spans[#spans + 1] = { start, cut }
				start = cut + 1
			end
		end
		local total = #spans
		if digitsOf(total) <= digits then
			for i, span in ipairs(spans) do
				local pieces, p = {}, 0
				for k = span[1], span[2] do
					if k > span[1] and gaps[k] > 0 then p = p + 1; pieces[p] = " " end
					p = p + 1; pieces[p] = atoms[k]
				end
				local text2 = concat(pieces)
				if options.everyPart or i > 1 then text2 = renderMarker(prefix, i, total) .. text2 end
				if options.everyPart or i < total then text2 = text2 .. renderMarker(suffix, i, total) end
				if text2:match("^%s*/") then return nil, "STARTS_COMMAND", i end
				parts[i] = text2
			end
			local lengths, longest = {}, 0
			for i, p in ipairs(parts) do
				lengths[i] = S.Length(p)
				if lengths[i] > longest then longest = lengths[i] end
			end
			return parts, { total = total, chars = runLength(1, n), longest = longest, lengths = lengths, limit = limit }
		end
		digits = digitsOf(total)
	end
	return nil, "TOO_SMALL"
end

-- ✅ P5YCH3: Polish(text) -> text. Optional typography tidy-up: "..." to an ellipsis, "--" to a dash, curly quotes and apostrophes, extra spaces removed.
function S.Polish(text)
	if type(text) ~= "string" then return text end
	local out = text:gsub("\r\n", "\n"):gsub("\r", "\n")
	out = out:gsub("%.%.%.+", ELLIPSIS)
	out = out:gsub(" ?%-%-+ ?", EMDASH)
	out = out:gsub("[ \t]+", " "):gsub(" +\n", "\n"):gsub("\n +", "\n")
	-- curly double quotes: a quote opens after the start, whitespace or an opening bracket/dash, otherwise it closes
	local pieces, open = {}, true
	local prev = ""
	for ch in out:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		if ch == '"' then
			if prev == "" or prev == " " or prev == "\n" or prev == "(" or prev == "[" or prev == EMDASH or prev == LDQUO then
				pieces[#pieces + 1] = LDQUO
			else
				pieces[#pieces + 1] = RDQUO
			end
		elseif ch == "'" and (prev:match("^%a$") or (#prev > 1 and prev ~= ELLIPSIS and prev ~= EMDASH and prev ~= LDQUO and prev ~= RDQUO and prev ~= RSQUO)) then
			pieces[#pieces + 1] = RSQUO -- apostrophe or closing single quote after a letter
		else
			pieces[#pieces + 1] = ch
		end
		prev = ch
	end
	return concat(pieces)
end

return S
