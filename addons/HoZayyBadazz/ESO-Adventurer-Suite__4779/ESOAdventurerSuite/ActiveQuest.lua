-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.ActiveQuest = EPC.ActiveQuest or {}
local Q = EPC.ActiveQuest
local wm = WINDOW_MANAGER

local DEFAULT_WIDTH = 420
local DEFAULT_HEIGHT = 128
local MIN_WIDTH = 180
local MIN_HEIGHT = 76
local MAX_WIDTH = 900
local MAX_HEIGHT = 520

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e,f,g,h,i,j,k = pcall(fn, ...)
    if not ok then return fallback end
    return a,b,c,d,e,f,g,h,i,j,k
end

local function safeNumber(fn, fallback, ...)
    local value = safe(fn, fallback, ...)
    local number = tonumber(value)
    if number ~= nil then return number end
    return tonumber(fallback) or 0
end

local function trim(value)
    local s = tostring(value or "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function stripESOFormatting(value)
    value = tostring(value or "")
    value = value:gsub("|c%x%x%x%x%x%x", "")
    value = value:gsub("|r", "")
    value = value:gsub("|t.-|t", " ")
    value = value:gsub("|H.-|h(.-)|h", "%1")
    -- Quest condition strings can contain hidden control bytes used by ESO's
    -- tracker formatter. Those bytes may render as square glyphs and can split
    -- an otherwise normal 7/9 token so the old duplicate matcher misses it.
    value = value:gsub("[%z\1-\31\127]", " ")
    return trim(value:gsub("%s+", " "))
end

local function extractAndStripProgress(value)
    value = stripESOFormatting(value)
    local firstCurrent, firstMaximum = nil, nil
    local function capture(a, b)
        if firstCurrent == nil then
            firstCurrent = tostring(a):gsub(",", "")
            firstMaximum = tostring(b):gsub(",", "")
        end
        return " "
    end
    value = value:gsub("%(%s*([%d,]+)%s*/%s*([%d,]+)%s*%)", capture)
    value = value:gsub("%(%s*([%d,]+)%s+[Oo][Ff]%s+([%d,]+)%s*%)", capture)
    value = value:gsub("([%d,]+)%s*/%s*([%d,]+)", capture)
    value = value:gsub("([%d,]+)%s+[Oo][Ff]%s+([%d,]+)", capture)
    value = trim(value:gsub("%s+", " "))
    return value, tonumber(firstCurrent), tonumber(firstMaximum)
end

local function collapseAdjacentDuplicateWords(value)
    local words = {}
    for word in tostring(value or ""):gmatch("%S+") do
        local key = string.lower(word:gsub("[%p]+$", ""))
        local previous = words[#words]
        local previousKey = previous and string.lower(previous:gsub("[%p]+$", "")) or nil
        if key == "" or key ~= previousKey then
            words[#words + 1] = word
        end
    end
    return table.concat(words, " ")
end

local function escapeLuaPattern(value)
    return tostring(value or ""):gsub("([^%w])", "%%%1")
end

local function stripAuthoritativeProgress(value, current, maximum)
    value = tostring(value or "")
    current = tonumber(current)
    maximum = tonumber(maximum)
    if not current or not maximum or maximum <= 1 then return value end

    local cur = escapeLuaPattern(string.format("%d", current))
    local max = escapeLuaPattern(string.format("%d", maximum))

    -- Remove the authoritative counter even when ESO inserts hidden glyphs,
    -- icons, punctuation, or non-ASCII separator bytes around the slash.
    -- The bounded separator class deliberately refuses letters/digits so it
    -- cannot consume ordinary objective text.
    local pattern = cur .. "%s*[^%a%d]-/%s*[^%a%d]-" .. max
    value = value:gsub(pattern, " ")
    return trim(value:gsub("%s+", " "))
end

local function stripTrailingProgressGarbage(value)
    value = stripESOFormatting(value)

    -- Some ESO tracker strings contain non-printing/private glyph bytes inside
    -- the progress token. In-game those can appear as square boxes, e.g.
    -- "Resources:[] 70 /[] 9" even though the API reports 7/9. Treat any
    -- trailing digit/slash/digit cluster with no letters after it as tracker
    -- progress garbage and remove the whole cluster before rendering.
    local prefix = value:match("^(.-)%s*[%d,]+%s*[^%a%d]-/%s*[^%a%d]-[%d,]+%s*$")
    if prefix then
        -- Also remove separator glyphs/punctuation immediately before the
        -- numeric cluster so unsupported formatting does not survive as boxes.
        prefix = prefix:gsub("[^%w%)%]]+$", "")
        return trim(prefix)
    end
    return value
end

local function stripMalformedProgressSuffix(value)
    value = stripESOFormatting(value)

    -- ESO can occasionally return a visually corrupted tracker suffix such as
    -- "70 /□ 9" while the numeric API correctly reports 7/9.  When a line
    -- has a colon-delimited suffix containing digits and a slash, the suffix is
    -- presentation data, not objective text, so discard it wholesale.
    local head, tail = value:match("^(.*:)([^:]*)$")
    if head and tail and tail:find("/", 1, true) and tail:find("%d") then
        return trim(head)
    end

    -- Fallback for tracker strings without a colon.  Remove a trailing
    -- digit/separator/digit cluster even when unsupported glyphs sit around
    -- the slash.  Requiring a slash prevents ordinary numbered objectives
    -- such as "Defeat 3 Captains" from being stripped.
    local prefix = value:match("^(.-)%s+%d[^%a]-/[^%a]-%d.*$")
    if prefix and prefix ~= "" then return trim(prefix) end
    return value
end

local function sanitizeRenderedLine(value, current, maximum)
    current = tonumber(current)
    maximum = tonumber(maximum)

    -- When the quest API gives us an authoritative current/max pair, strip
    -- every textual copy of that pair before generic cleanup, then append one
    -- clean counter at the very end. This guarantees a single x/y on screen.
    local prepared = stripESOFormatting(value)
    if maximum and maximum > 1 then
        prepared = stripMalformedProgressSuffix(prepared)
        prepared = stripAuthoritativeProgress(prepared, current or 0, maximum)
        prepared = stripTrailingProgressGarbage(prepared)
    end

    local base, embeddedCurrent, embeddedMaximum = extractAndStripProgress(prepared)
    base = collapseAdjacentDuplicateWords(base)

    if not maximum or maximum <= 1 then
        current, maximum = embeddedCurrent, embeddedMaximum
    end

    if maximum and maximum > 1 then
        local counter = string.format("%d/%d", current or 0, maximum)
        return base ~= "" and (base .. "  " .. counter) or counter
    end
    return base
end

local function normalizeProgressCounters(value)
    local out, seen = {}, {}
    for line in (tostring(value or "") .. "\n"):gmatch("(.-)\n") do
        line = sanitizeRenderedLine(line)
        local key = string.lower(line:gsub("[%d,]+%s*/%s*[%d,]+", " "):gsub("[%p%s]+", " "))
        key = trim(key:gsub("%s+", " "))
        if line ~= "" and not seen[key] then
            seen[key] = true
            out[#out + 1] = line
        end
    end
    return table.concat(out, "\n")
end

local GetActiveQuestIndexImplArch

function Q:GetActiveQuestIndex(...)

    return GetActiveQuestIndexImplArch(self, ...)

end

GetActiveQuestIndexImplArch = function(self)
    local fallbackTracked = nil
    local max = tonumber(MAX_JOURNAL_QUESTS) or 25
    for i = 1, max do
        local valid = type(IsValidQuestIndex) ~= "function" or safe(IsValidQuestIndex, false, i) == true
        if valid then
            local name, _, _, _, _, _, tracked = safe(GetJournalQuestInfo, "", i)
            name = trim(name)
            if name ~= "" then
                if TRACK_TYPE_QUEST ~= nil and type(GetTrackedIsAssisted) == "function" then
                    local assisted = safe(GetTrackedIsAssisted, false, TRACK_TYPE_QUEST, i, 0) == true
                    if assisted then return i end
                end
                if tracked == true and not fallbackTracked then fallbackTracked = i end
            end
        end
    end
    return fallbackTracked
end


function Q:WrapTitleText(text)
    text = tostring(text or "")
    if text == "" then return "" end

    local width = 0
    if self.title and type(self.title.GetWidth) == "function" then
        width = tonumber(self.title:GetWidth()) or 0
    end
    if width <= 0 and self.frame and type(self.frame.GetWidth) == "function" then
        width = math.max(80, (tonumber(self.frame:GetWidth()) or DEFAULT_WIDTH) - 24)
    end
    if width <= 0 then width = DEFAULT_WIDTH - 24 end

    -- ZoFontGameBold is wider than the objective font, so use a conservative
    -- character estimate and insert real newlines instead of relying on the
    -- label's implicit wrapping behavior.
    local maxChars = math.max(14, math.floor((width - 8) / 9.0))
    local lines, current = {}, ""

    local function flush()
        if current ~= "" then
            lines[#lines + 1] = current
            current = ""
        end
    end

    for word in string.gmatch(text, "%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if string.len(candidate) > maxChars and current ~= "" then
            flush()
            current = word
        else
            current = candidate
        end
    end
    flush()
    return table.concat(lines, "\n")
end

function Q:WrapObjectiveText(text)
    text = tostring(text or "")
    if text == "" then return "" end

    local width = 0
    if self.steps and type(self.steps.GetWidth) == "function" then
        width = tonumber(self.steps:GetWidth()) or 0
    end
    if width <= 0 and self.frame and type(self.frame.GetWidth) == "function" then
        width = math.max(80, (tonumber(self.frame:GetWidth()) or DEFAULT_WIDTH) - 24)
    end
    if width <= 0 then width = DEFAULT_WIDTH - 24 end

    -- ZoFontGame averages roughly 7.5-8.5 px per character. Keeping a little
    -- safety room prevents ESO from placing the final word outside the HUD edge.
    local maxChars = math.max(18, math.floor((width - 10) / 8.2))
    local wrapped = {}

    local function appendWrappedLine(line)
        line = tostring(line or "")
        if line == "" then
            wrapped[#wrapped + 1] = ""
            return
        end

        local bullet = string.sub(line, 1, 4) == "• "
        local content = bullet and string.sub(line, 5) or line
        local firstPrefix = bullet and "• " or ""
        local continuationPrefix = bullet and "  " or ""
        local availableFirst = math.max(8, maxChars - string.len(firstPrefix))
        local availableNext = math.max(8, maxChars - string.len(continuationPrefix))
        local current = ""
        local first = true

        local function flush()
            if current ~= "" then
                wrapped[#wrapped + 1] = (first and firstPrefix or continuationPrefix) .. current
                current = ""
                first = false
            end
        end

        local function limitForCurrent()
            return first and availableFirst or availableNext
        end

        for word in string.gmatch(content, "%S+") do
            local limit = limitForCurrent()
            if current == "" and string.len(word) > limit then
                local remaining = word
                while string.len(remaining) > limit do
                    current = string.sub(remaining, 1, limit)
                    flush()
                    remaining = string.sub(remaining, limit + 1)
                    limit = limitForCurrent()
                end
                current = remaining
            else
                local candidate = current == "" and word or (current .. " " .. word)
                if string.len(candidate) > limit and current ~= "" then
                    flush()
                    limit = limitForCurrent()
                    if string.len(word) > limit then
                        local remaining = word
                        while string.len(remaining) > limit do
                            current = string.sub(remaining, 1, limit)
                            flush()
                            remaining = string.sub(remaining, limit + 1)
                            limit = limitForCurrent()
                        end
                        current = remaining
                    else
                        current = word
                    end
                else
                    current = candidate
                end
            end
        end
        flush()
    end

    for line in string.gmatch(text .. "\n", "(.-)\n") do
        appendWrappedLine(line)
    end
    return table.concat(wrapped, "\n")
end

function Q:BuildObjectiveText(index)
    if not index then return "Track or focus a quest to see its next steps." end

    local questName, _, activeStepText, _, activeOverride, completed = safe(GetJournalQuestInfo, "", index)
    questName = trim(questName)

    local function objectiveKey(value)
        local stripped = extractAndStripProgress(value)
        value = string.lower(stripped)
        value = value:gsub("^optional%s*:?%s*", "")
        value = value:gsub("[%[%]%(%){}<>]", " ")
        value = value:gsub("[%p%s]+", " ")
        value = trim(value:gsub("%s+", " "))
        return value
    end

    local function displayLine(base, current, maximum)
        return sanitizeRenderedLine(base, current, maximum)
    end

    local questKey = objectiveKey(questName)
    local ordered = {}
    local byKey = {}

    local function addObjective(textValue, current, maximum)
        local base = extractAndStripProgress(textValue)
        if base == "" then return end
        local key = objectiveKey(base)
        if key == "" or key == questKey then return end

        -- One authoritative row per normalized objective. If ESO exposes the same
        -- objective through more than one step/condition, keep only the most useful
        -- counter for that objective instead of rendering a duplicate line.
        local existing = byKey[key]
        local cur = tonumber(current) or 0
        local max = tonumber(maximum) or 0
        if existing then
            local replace = false
            if max > (existing.maximum or 0) then
                replace = true
            elseif max == (existing.maximum or 0) and cur > (existing.current or 0) then
                replace = true
            end
            if replace then
                existing.current = cur
                existing.maximum = max
                existing.text = displayLine(base, cur, max)
            end
            return
        end

        local row = {
            key = key,
            current = cur,
            maximum = max,
            text = displayLine(base, cur, max),
        }
        byKey[key] = row
        ordered[#ordered + 1] = row
    end

    if completed == true and type(GetJournalQuestEnding) == "function" then
        local ending = sanitizeRenderedLine(safe(GetJournalQuestEnding, "", index))
        if ending ~= "" then return ending end
    end

    -- Conditions are the single source of truth for the live objective list.
    -- Do not also render step/tracker override strings when conditions exist;
    -- mixing both sources is what caused repeated names and repeated counters.
    local numSteps = safeNumber(GetJournalQuestNumSteps, 0, index)
    if type(GetJournalQuestNumConditions) == "function" and type(GetJournalQuestConditionInfo) == "function" then
        for stepIndex = 1, numSteps do
            local _, visibility = safe(GetJournalQuestStepInfo, "", index, stepIndex)
            if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN then
                local conditionCount = safeNumber(GetJournalQuestNumConditions, 0, index, stepIndex)
                for conditionIndex = 1, conditionCount do
                    local conditionText, current, maximum, isFail, isComplete, _, isVisible = safe(GetJournalQuestConditionInfo, "", index, stepIndex, conditionIndex, true)
                    if isVisible ~= false and isComplete ~= true and isFail ~= true then
                        addObjective(conditionText, current, maximum)
                    end
                end
            end
        end
    end

    local lines = {}
    for i = 1, #ordered do
        local row = ordered[i]
        if row.text and row.text ~= "" then
            lines[#lines + 1] = "• " .. row.text
        end
    end

    if #lines == 0 then
        -- Only use ESO's tracker/step text as a fallback when no visible incomplete
        -- condition rows exist. Normalize every progress token down to one copy.
        local fallback = sanitizeRenderedLine(activeOverride)
        if fallback == "" then fallback = sanitizeRenderedLine(activeStepText) end
        if fallback ~= "" and objectiveKey(fallback) ~= questKey then
            lines[1] = fallback
        end
    end

    if #lines == 0 then
        lines[1] = completed == true and "Quest ready to complete." or "Follow the quest marker."
    end
    return normalizeProgressCounters(table.concat(lines, "\n"))
end

-- v0.29.337: keep the raw quest text so the overlay can re-wrap it when
-- objective count changes. Gameplay height is content-driven; the user's saved
-- width remains the baseline and the overlay only widens modestly for unusually
-- dense objective lists.
function Q:SetOverlayText337(titleText, objectiveText)
    self.rawTitleText337 = tostring(titleText or "")
    self.rawObjectiveText337 = tostring(objectiveText or "")
    if self.title then self.title:SetText(self:WrapTitleText(self.rawTitleText337)) end
    if self.steps then self.steps:SetText(self:WrapObjectiveText(self.rawObjectiveText337)) end
end

local function easCountLines337(text)
    text = tostring(text or "")
    if text == "" then return 0 end
    local count = 1
    for _ in string.gmatch(text, "\n") do count = count + 1 end
    return count
end

-- v0.28.72: quest overlay visibility/content is independent from the single
-- authoritative assisted-quest/compass source. If Golden Pursuits owns the
-- compass, the Active Quest overlay still shows the remembered Active Quest so
-- both dedicated overlays can be visible together. Main Quest keeps its legacy
-- behavior in the Active Quest frame when Main Quest is the selected source.
function Q:GetOverlayQuestSource2872()
    local source = self.GetQuestTrackingSource2513 and self:GetQuestTrackingSource2513() or "ACTIVE_QUEST"
    if source == "GOLDEN_PURSUITS" then return "ACTIVE_QUEST" end
    return source
end

function Q:GetOverlayQuestIndex2872()
    local source = self:GetOverlayQuestSource2872()
    if self.ResolveQuestSource2520 then
        return self:ResolveQuestSource2520(source)
    end
    if source == "ACTIVE_QUEST" and self.ResolveTrackedSourceQuest2513 then
        return self:ResolveTrackedSourceQuest2513("ACTIVE_QUEST")
    end
    return self:GetActiveQuestIndex()
end

function Q:GetTrackedQuestHeader()
    local source = self.GetOverlayQuestSource2872 and self:GetOverlayQuestSource2872()
        or (self.GetQuestTrackingSource2513 and self:GetQuestTrackingSource2513() or "ACTIVE_QUEST")
    if source == "MAIN_QUEST" then return "MAIN QUEST" end
    if source == "GOLDEN_PURSUITS" then return "GOLDEN PURSUITS" end
    return "ACTIVE QUEST"
end

function Q:Create()
    -- v0.25.09: migrate the older tall HUD once while preserving width/position.
    if EPC.saved and EPC.saved.activeQuestCompactHeightVersion ~= 2509 then
        EPC.saved.activeQuestHeight = DEFAULT_HEIGHT
        EPC.saved.activeQuestCompactHeightVersion = 2509
    end

    local frame = wm:CreateTopLevelWindow("EAS_ActiveQuestOverlay")
    local savedWidth = tonumber(EPC.saved and EPC.saved.activeQuestWidth) or DEFAULT_WIDTH
    local savedHeight = tonumber(EPC.saved and EPC.saved.activeQuestHeight) or DEFAULT_HEIGHT
    savedWidth = math.max(MIN_WIDTH, math.min(MAX_WIDTH, savedWidth))
    savedHeight = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, savedHeight))
    frame:SetDimensions(savedWidth, savedHeight)
    frame:SetDimensionConstraints(MIN_WIDTH, MIN_HEIGHT)
    frame:SetResizeHandleSize(18)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)

    local left = tonumber(EPC.saved and EPC.saved.activeQuestLeft) or -1
    local top = tonumber(EPC.saved and EPC.saved.activeQuestTop) or -1
    local side = EPC.saved and EPC.saved.activeQuestAnchorSide339 or nil
    local rightMargin = tonumber(EPC.saved and EPC.saved.activeQuestRightMargin339)
    if side == "RIGHT" and rightMargin and rightMargin >= 0 and top >= 0 then
        frame:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -rightMargin, top)
    elseif left >= 0 and top >= 0 then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 34, 180)
    end

    -- v0.25.05: match the Golden Pursuits HUD with the same inset dark card,
    -- gold border, spacing, and layout-mode resize treatment.
    local background = wm:CreateControl("EAS_ActiveQuestOverlay_Background2505", frame, CT_BACKDROP)
    background:SetAnchor(TOPLEFT, frame, TOPLEFT, 2, 2)
    background:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -2, -2)
    background:SetCenterColor(0.025, 0.022, 0.018, 0.90)
    background:SetEdgeTexture(nil, 1, 1, 2)
    background:SetEdgeColor(0.92, 0.72, 0.25, 0.95)
    background:SetMouseEnabled(false)

    local layoutGuide = wm:CreateControl("EAS_ActiveQuestOverlay_LayoutGuide", frame, CT_BACKDROP)
    layoutGuide:SetAnchor(TOPLEFT, frame, TOPLEFT, 4, 4)
    layoutGuide:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -4, -4)
    layoutGuide:SetCenterColor(0, 0, 0, 0)
    layoutGuide:SetEdgeTexture(nil, 1, 1, 1)
    layoutGuide:SetEdgeColor(1, 0.84, 0.42, 0.65)
    layoutGuide:SetHidden(true)

    local header = wm:CreateControl("EAS_ActiveQuestOverlay_Header", frame, CT_LABEL)
    header:SetFont("ZoFontGameBold")
    header:SetColor(0.96, 0.80, 0.36, 1)
    header:SetAnchor(TOPLEFT, frame, TOPLEFT, 12, 8)
    header:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -12, 8)
    header:SetHeight(20)
    header:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    header:SetVerticalAlignment(TEXT_ALIGN_TOP)
    header:SetText("ACTIVE QUEST")
    header:SetHidden(false)

    local title = wm:CreateControl("EAS_ActiveQuestOverlay_Title", frame, CT_LABEL)
    title:SetFont("ZoFontGameBold")
    title:SetColor(0.96, 0.96, 0.94, 1)
    title:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 2)
    title:SetAnchor(TOPRIGHT, header, BOTTOMRIGHT, 0, 2)
    title:SetHeight(36)
    title:SetVerticalAlignment(TEXT_ALIGN_TOP)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    if title.SetMaxLineCount then title:SetMaxLineCount(0) end
    if title.SetWrapMode and TEXT_WRAP_MODE_TRUNCATE then title:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE) end
    if title.SetLineSpacing then title:SetLineSpacing(2) end

    local steps = wm:CreateControl("EAS_ActiveQuestOverlay_Steps", frame, CT_LABEL)
    steps:SetFont("ZoFontGameSmall")
    steps:SetColor(0.92, 0.94, 0.97, 1)
    steps:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 8)
    steps:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 8)
    steps:SetHeight(56)
    steps:SetVerticalAlignment(TEXT_ALIGN_TOP)
    steps:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    if steps.SetMaxLineCount then steps:SetMaxLineCount(0) end
    if steps.SetLineSpacing then steps:SetLineSpacing(4) end

    local moveHint = wm:CreateControl("EAS_ActiveQuestOverlay_MoveHint", frame, CT_LABEL)
    moveHint:SetFont("ZoFontGameSmall")
    moveHint:SetColor(0.96, 0.80, 0.36, 1)
    moveHint:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -12, 7)
    moveHint:SetDimensions(230, 18)
    moveHint:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    moveHint:SetText("DRAG TO MOVE - EDGES TO RESIZE")
    moveHint:SetHidden(true)

    frame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            local left = tonumber(control:GetLeft()) or 0
            local top = tonumber(control:GetTop()) or 0
            local right = tonumber(control:GetRight()) or (left + (tonumber(control:GetWidth()) or DEFAULT_WIDTH))
            local guiWidth = GuiRoot and type(GuiRoot.GetWidth) == "function" and tonumber(GuiRoot:GetWidth()) or 1920
            local centerX = (left + right) * 0.5
            EPC.saved.activeQuestLeft = left
            EPC.saved.activeQuestTop = top
            if centerX >= guiWidth * 0.5 then
                EPC.saved.activeQuestAnchorSide339 = "RIGHT"
                EPC.saved.activeQuestRightMargin339 = math.max(0, guiWidth - right)
            else
                EPC.saved.activeQuestAnchorSide339 = "LEFT"
                EPC.saved.activeQuestRightMargin339 = nil
            end
            local w, h = control:GetDimensions()
            EPC.saved.activeQuestPositionWidth338 = tonumber(w) or DEFAULT_WIDTH
            EPC.saved.activeQuestPositionHeight338 = tonumber(h) or DEFAULT_HEIGHT
        end
    end)
    frame:SetHandler("OnResizeStop", function(control)
        if EPC.saved then
            local width, height = control:GetDimensions()
            EPC.saved.activeQuestWidth = math.floor((tonumber(width) or DEFAULT_WIDTH) + 0.5)
            EPC.saved.activeQuestHeight = math.floor((tonumber(height) or DEFAULT_HEIGHT) + 0.5)
            EPC.saved.activeQuestPositionWidth338 = tonumber(width) or DEFAULT_WIDTH
            EPC.saved.activeQuestPositionHeight338 = tonumber(height) or DEFAULT_HEIGHT
            local left = tonumber(control:GetLeft()) or 0
            local right = tonumber(control:GetRight()) or (left + (tonumber(width) or DEFAULT_WIDTH))
            local guiWidth = GuiRoot and type(GuiRoot.GetWidth) == "function" and tonumber(GuiRoot:GetWidth()) or 1920
            if ((left + right) * 0.5) >= guiWidth * 0.5 then
                EPC.saved.activeQuestAnchorSide339 = "RIGHT"
                EPC.saved.activeQuestRightMargin339 = math.max(0, guiWidth - right)
            else
                EPC.saved.activeQuestAnchorSide339 = "LEFT"
                EPC.saved.activeQuestRightMargin339 = nil
            end
            -- v0.28.75: once the player manually resizes the overlay, preserve
            -- that exact viewport instead of auto-growing it back to fit text.
            EPC.saved.activeQuestManualSize2875 = true
        end
        if self.ApplyManualLayout2875 then self:ApplyManualLayout2875() end
        self:Refresh()
    end)

    self.frame, self.header, self.title, self.steps, self.moveHint = frame, header, title, steps, moveHint
    self.background2505 = background
    self.layoutGuide = layoutGuide
end

-- v0.28.75: manual quest-overlay sizing is a viewport. The frame is allowed
-- to be substantially smaller than the full wrapped text; labels are constrained
-- to the available room rather than forcing the top-level window to grow again.
function Q:ApplyManualLayout2875()
    if not self.frame or not self.title or not self.steps then return end
    local frameHeight = math.max(MIN_HEIGHT, tonumber(self.frame:GetHeight()) or DEFAULT_HEIGHT)
    local headerHeight = 20
    if self.header then self.header:SetHeight(headerHeight) end

    local titleDesired = 36
    if type(self.title.GetTextHeight) == "function" then
        local ok, value = pcall(self.title.GetTextHeight, self.title)
        if ok and tonumber(value) then titleDesired = math.max(18, math.ceil(tonumber(value)) + 2) end
    end

    -- Header starts at y=8; title begins two pixels below it. Keep at least one
    -- readable title row and give the remainder to objectives.
    local contentBottom = frameHeight - 8
    local titleTop = 8 + headerHeight + 2
    local minStepsRoom = 18
    local titleHeight = math.max(18, math.min(titleDesired, math.max(18, contentBottom - titleTop - 4 - minStepsRoom)))
    self.title:SetHeight(titleHeight)

    local stepsTop = titleTop + titleHeight + 4
    local stepsHeight = math.max(0, contentBottom - stepsTop)
    self.steps:SetHeight(stepsHeight)
    self.steps:SetHidden(stepsHeight < 8)
end

-- Keep the HUD only as tall as the rendered title/objectives require. This uses
-- the label's real wrapped-text height, so 3+ objectives and long objective text
-- expand the card automatically, then shrink again when the quest gets shorter.
function Q:AutoFitHeight()
    if not self.frame or not self.title or not self.steps or self.layoutMode then return end

    self.steps:SetHidden(false)
    local guiWidth = GuiRoot and type(GuiRoot.GetWidth) == "function" and tonumber(GuiRoot:GetWidth()) or 1920
    local guiHeight = GuiRoot and type(GuiRoot.GetHeight) == "function" and tonumber(GuiRoot:GetHeight()) or 1080

    -- Always return to the user's chosen width first. Dense quests may borrow a
    -- little extra horizontal room so four or more objectives do not turn into
    -- a very tall wall of wrapped text.
    local baseWidth = math.max(MIN_WIDTH, math.min(MAX_WIDTH, tonumber(EPC.saved and EPC.saved.activeQuestWidth) or DEFAULT_WIDTH))
    local logicalRows = easCountLines337(self.rawObjectiveText337 or self.steps:GetText())
    local extraWidth = logicalRows > 4 and math.min(150, (logicalRows - 4) * 30) or 0
    local screenWidthCap = math.max(baseWidth, math.min(MAX_WIDTH, math.floor(guiWidth * 0.48)))
    local targetWidth = math.min(screenWidthCap, baseWidth + extraWidth)
    self.frame:SetWidth(targetWidth)

    -- Re-wrap from raw text after any adaptive width change. This avoids keeping
    -- old manual newline breaks from a narrower quest.
    if self.rawTitleText337 ~= nil then self.title:SetText(self:WrapTitleText(self.rawTitleText337)) end
    if self.rawObjectiveText337 ~= nil then self.steps:SetText(self:WrapObjectiveText(self.rawObjectiveText337)) end

    local physicalRows = easCountLines337(self.steps:GetText())
    if self.steps.SetLineSpacing then
        if physicalRows >= 8 then
            self.steps:SetLineSpacing(0)
        elseif physicalRows >= 5 then
            self.steps:SetLineSpacing(2)
        else
            self.steps:SetLineSpacing(4)
        end
    end

    local headerHeight = 20
    if self.header then self.header:SetHeight(headerHeight) end

    local titleHeight = 36
    if type(self.title.GetTextHeight) == "function" then
        local ok, value = pcall(self.title.GetTextHeight, self.title)
        if ok and tonumber(value) then titleHeight = math.max(24, math.ceil(tonumber(value)) + 2) end
    end
    self.title:SetHeight(titleHeight)

    local stepsHeight = 24
    if type(self.steps.GetTextHeight) == "function" then
        local ok, value = pcall(self.steps.GetTextHeight, self.steps)
        if ok and tonumber(value) then stepsHeight = math.max(24, math.ceil(tonumber(value)) + 2) end
    else
        stepsHeight = math.max(24, physicalRows * 22)
    end
    self.steps:SetHeight(stepsHeight)

    local desiredHeight = 10 + headerHeight + 2 + titleHeight + 6 + stepsHeight + 10
    local userMax = tonumber(EPC.saved and EPC.saved.activeQuestAutoMaxHeight337) or MAX_HEIGHT
    userMax = math.max(220, math.min(MAX_HEIGHT, userMax))
    local screenMax = math.max(220, math.floor(guiHeight * 0.48))
    local maxHeight = math.min(userMax, screenMax)

    -- Four/five-objective quests normally fit before this cap because spacing
    -- and width are adaptive. Extremely long quest descriptions are bounded to
    -- under half the screen so the HUD does not take over gameplay.
    local finalHeight = math.max(MIN_HEIGHT, math.min(maxHeight, desiredHeight))
    self.frame:SetHeight(finalHeight)

    local contentBottom = finalHeight - 8
    local titleTop = 8 + headerHeight + 2
    self.title:SetHeight(math.min(titleHeight, math.max(18, contentBottom - titleTop - 24)))
    local stepsTop = titleTop + self.title:GetHeight() + 6
    self.steps:SetHeight(math.max(0, contentBottom - stepsTop))
    self.steps:SetHidden(self.steps:GetHeight() < 8)

    if EPC.saved then EPC.saved.activeQuestHeight = math.floor(finalHeight + 0.5) end

    -- v0.29.339: preserve the edge the player actually chose in HUD Layout.
    -- Right-side placements use a true TOPRIGHT anchor, so auto-width growth
    -- expands leftward without making the overlay jump back toward its old
    -- TOPLEFT position. Left-side placements keep a TOPLEFT anchor.
    local savedLeft = tonumber(EPC.saved and EPC.saved.activeQuestLeft)
    local savedTop = tonumber(EPC.saved and EPC.saved.activeQuestTop)
    if savedLeft == nil or savedLeft < 0 then savedLeft = tonumber(self.frame:GetLeft()) or 34 end
    if savedTop == nil or savedTop < 0 then savedTop = tonumber(self.frame:GetTop()) or 180 end

    local positionedWidth = tonumber(EPC.saved and EPC.saved.activeQuestPositionWidth338) or baseWidth
    local side = EPC.saved and EPC.saved.activeQuestAnchorSide339 or nil
    if side ~= "LEFT" and side ~= "RIGHT" then
        side = (savedLeft + positionedWidth * 0.5 >= guiWidth * 0.5) and "RIGHT" or "LEFT"
    end

    local renderTop = math.max(8, math.min(math.max(8, guiHeight - finalHeight - 8), savedTop))
    self.frame:ClearAnchors()
    if side == "RIGHT" then
        local rightMargin = tonumber(EPC.saved and EPC.saved.activeQuestRightMargin339)
        if rightMargin == nil then
            rightMargin = math.max(8, guiWidth - (savedLeft + positionedWidth))
        end
        rightMargin = math.max(8, math.min(math.max(8, guiWidth - targetWidth - 8), rightMargin))
        self.frame:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -rightMargin, renderTop)
    else
        local renderLeft = math.max(8, math.min(math.max(8, guiWidth - targetWidth - 8), savedLeft))
        self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, renderLeft, renderTop)
    end
end

local RefreshImplArch

function Q:Refresh(...)

    return RefreshImplArch(self, ...)

end

RefreshImplArch = function(self)
    if not self.frame or not EPC.saved then return end
    local show = EPC.saved.showActiveQuestOverlay ~= false
    if self.layoutMode then show = true
    elseif EPC.OverlayModeAllows then show = show and EPC:OverlayModeAllows("activeQuestVisibility") end
    if show and not self.layoutMode and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then show = false end
    self.frame:SetHidden(not show)
    if not show then return end

    local index = self.GetOverlayQuestIndex2872 and self:GetOverlayQuestIndex2872() or self:GetActiveQuestIndex()
    if not self.layoutMode and not index then
        -- No accepted/tracked quest means no gameplay quest overlay. Keep the
        -- saved position/size/settings intact so it returns when a quest is active.
        self.frame:SetHidden(true)
        return
    end
    if self.layoutMode and not index then
        if self.header then self.header:SetText("ACTIVE QUEST") end
        self:SetOverlayText337("Quest Overlay Preview", "• Current objective\n• Next quest step")
        self:AutoFitHeight()
        return
    end
    if not index then
        local source = self.GetQuestTrackingSource2513 and self:GetQuestTrackingSource2513() or "ACTIVE_QUEST"
        if self.header then self.header:SetText(self:GetTrackedQuestHeader()) end
        local pendingMain = source == "MAIN_QUEST" and EPC.saved.mainQuestDiscoveryTarget or nil
        if pendingMain and trim(pendingMain.name) ~= "" then
            -- Keep the unaccepted Main Quest HUD intentionally minimal. Detailed
            -- prerequisites and route notes stay in Quest Finder.
            local pendingTitle337 = tostring(pendingMain.name or "Main Story")
            local zone = tostring(pendingMain.zone or "Main Story")
            local giver = trim(pendingMain.questGiver or pendingMain.starter or "")
            local acceptAt = trim(pendingMain.acceptAt or "")
            local lines = {
                "• NEXT: ACCEPT QUEST",
            }
            if giver ~= "" then lines[#lines+1] = "• FROM: " .. giver end
            if acceptAt ~= "" then
                lines[#lines+1] = "• AT: " .. acceptAt
            else
                lines[#lines+1] = "• IN: " .. zone
            end
            lines[#lines+1] = "• TRAVEL: Nearest wayshrine"
            self:SetOverlayText337(pendingTitle337, table.concat(lines, "\n"))
        else
            self:SetOverlayText337("No Focused Quest", "Track or focus a quest to see its next steps.")
        end
        self:AutoFitHeight()
        return
    end
    local name = trim(safe(GetJournalQuestInfo, "", index))
    if name == "" then name = "Active Quest" end
    if self.header then self.header:SetText(self:GetTrackedQuestHeader()) end
    self:SetOverlayText337(name, normalizeProgressCounters(self:BuildObjectiveText(index)))
    self:AutoFitHeight()
end

local SetLayoutModeImplArch

function Q:SetLayoutMode(...)

    return SetLayoutModeImplArch(self, ...)

end

SetLayoutModeImplArch = function(self, active)
    self.layoutMode = active == true
    if not self.frame then return end
    self.frame:SetMouseEnabled(self.layoutMode)
    self.frame:SetMovable(self.layoutMode)
    if self.moveHint then self.moveHint:SetHidden(not self.layoutMode) end
    if self.layoutGuide then self.layoutGuide:SetHidden(not self.layoutMode) end
    self:Refresh()
end

function Q:SetSize(width, height)
    if not self.frame or not EPC.saved then return end
    width = math.max(MIN_WIDTH, math.min(MAX_WIDTH, tonumber(width) or self.frame:GetWidth()))
    height = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, tonumber(height) or self.frame:GetHeight()))
    self.frame:SetDimensions(width, height)
    EPC.saved.activeQuestWidth = math.floor(width + 0.5)
    EPC.saved.activeQuestHeight = math.floor(height + 0.5)
    EPC.saved.activeQuestManualSize2875 = false
    self:Refresh()
end

function Q:ResetSize()
    if not self.frame or not EPC.saved then return end
    EPC.saved.activeQuestWidth = DEFAULT_WIDTH
    EPC.saved.activeQuestHeight = DEFAULT_HEIGHT
    EPC.saved.activeQuestManualSize2875 = false
    self.frame:SetDimensions(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    self.steps:SetHidden(false)
    self:Refresh()
end

local ResetPositionImplArch

function Q:ResetPosition(...)

    return ResetPositionImplArch(self, ...)

end

ResetPositionImplArch = function(self)
    if not self.frame or not EPC.saved then return end
    EPC.saved.activeQuestLeft, EPC.saved.activeQuestTop = -1, -1
    EPC.saved.activeQuestPositionWidth338 = nil
    EPC.saved.activeQuestPositionHeight338 = nil
    EPC.saved.activeQuestAnchorSide339 = nil
    EPC.saved.activeQuestRightMargin339 = nil
    self.frame:ClearAnchors()
    self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 34, 180)
end

local InitializeImplArch

function Q:Initialize(...)

    return InitializeImplArch(self, ...)

end

InitializeImplArch = function(self)
    self.layoutMode = false
    self:Create()
    self:Refresh()
    local prefix = EPC.name .. "_ActiveQuest"
    local events = { EVENT_QUEST_ADDED, EVENT_QUEST_REMOVED, EVENT_QUEST_ADVANCED, EVENT_QUEST_CONDITION_COUNTER_CHANGED, EVENT_QUEST_COMPLETE, EVENT_TRACKING_UPDATE }
    local seen = {}
    for i=1,#events do
        local eventId = events[i]
        if eventId and not seen[eventId] then
            seen[eventId] = true
            EVENT_MANAGER:RegisterForEvent(prefix .. "_" .. tostring(eventId), eventId, function(eventCode, ...)
                if self.HandleQuestLifecycle2744 then
                    self:HandleQuestLifecycle2744(eventCode, ...)
                else
                    self:Refresh()
                end
            end)
        end
    end
    -- v0.29.341: lifecycle events + the final consolidated safety pulse own refreshes.
end

-- ============================================================================
-- v0.25.12 - authoritative Quest Finder/Golden Pursuit selection + direction HUD
-- ============================================================================
local EAS_QUEST_ARROW_TEXTURE_2512 = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds"
local EAS_QUEST_ARROW_DEFAULT_2512 = 78
local EAS_QUEST_ARROW_MIN_2512 = 42
local EAS_QUEST_ARROW_MAX_2512 = 220

local function easLower2512(value)
    local text = tostring(value or "")
    if type(zo_strlower) == "function" then return zo_strlower(text) end
    return string.lower(text)
end

local function easQuestName2512(index)
    if not index or type(GetJournalQuestName) ~= "function" then return "" end
    local ok, name = pcall(GetJournalQuestName, index)
    return ok and trim(name) or ""
end

local function easQuestId2512(index)
    if not index or type(GetJournalQuestId) ~= "function" then return 0 end
    local ok, questId = pcall(GetJournalQuestId, index)
    return ok and (tonumber(questId) or 0) or 0
end

local ResolveSelectedQuest2512ImplArch

function Q:ResolveSelectedQuest2512(...)

    return ResolveSelectedQuest2512ImplArch(self, ...)

end

ResolveSelectedQuest2512ImplArch = function(self)
    if not EPC.saved then return nil end
    local wantedId = tonumber(EPC.saved.selectedHudQuestId) or 0
    local wantedName = trim(EPC.saved.selectedHudQuestName)
    if wantedId <= 0 and wantedName == "" then return nil end

    local max = tonumber(MAX_JOURNAL_QUESTS) or 25
    local wantedLower = easLower2512(wantedName)
    local nameMatch = nil
    for index = 1, max do
        local valid = type(IsValidQuestIndex) ~= "function" or safe(IsValidQuestIndex, false, index) == true
        if valid then
            local name = easQuestName2512(index)
            if name ~= "" then
                local questId = easQuestId2512(index)
                if wantedId > 0 and questId == wantedId then
                    EPC.saved.selectedHudQuestIndex = index
                    EPC.saved.selectedHudQuestName = name
                    return index
                end
                if not nameMatch and wantedLower ~= "" and easLower2512(name) == wantedLower then
                    nameMatch = index
                end
            end
        end
    end

    if nameMatch then
        EPC.saved.selectedHudQuestIndex = nameMatch
        EPC.saved.selectedHudQuestId = easQuestId2512(nameMatch)
        EPC.saved.selectedHudQuestName = easQuestName2512(nameMatch)
        return nameMatch
    end

    -- The selected quest is no longer in the journal. Release the override so
    -- ESO's normal assisted/tracked quest can take over again.
    EPC.saved.selectedHudQuestIndex = nil
    EPC.saved.selectedHudQuestId = 0
    EPC.saved.selectedHudQuestName = ""
    EPC.saved.selectedHudQuestSource = ""
    return nil
end

local SetSelectedQuest2512ImplArch

function Q:SetSelectedQuest2512(...)

    return SetSelectedQuest2512ImplArch(self, ...)

end

SetSelectedQuest2512ImplArch = function(self, questIndex, questId, questName, source)
    if not EPC.saved then return false end
    questIndex = tonumber(questIndex)
    if not questIndex or questIndex <= 0 then return false end

    local currentName = easQuestName2512(questIndex)
    if currentName == "" then return false end
    local currentId = easQuestId2512(questIndex)

    EPC.saved.selectedHudQuestIndex = questIndex
    EPC.saved.selectedHudQuestId = tonumber(questId) or currentId
    if (tonumber(EPC.saved.selectedHudQuestId) or 0) <= 0 then EPC.saved.selectedHudQuestId = currentId end
    EPC.saved.selectedHudQuestName = trim(questName) ~= "" and trim(questName) or currentName
    EPC.saved.selectedHudQuestSource = tostring(source or "ACTIVE")

    if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
        EPC.Travel:InvalidateQuestPositionCache()
    end
    self:Refresh()
    self:UpdateDirectionArrow2512(true)
    return true
end

local ClearSelectedQuest2512ImplArch

function Q:ClearSelectedQuest2512(...)

    return ClearSelectedQuest2512ImplArch(self, ...)

end

ClearSelectedQuest2512ImplArch = function(self)
    if not EPC.saved then return end
    EPC.saved.selectedHudQuestIndex = nil
    EPC.saved.selectedHudQuestId = 0
    EPC.saved.selectedHudQuestName = ""
    EPC.saved.selectedHudQuestSource = ""
    if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
        EPC.Travel:InvalidateQuestPositionCache()
    end
    self:Refresh()
end

local easLegacyGetActiveQuestIndex_2512 = GetActiveQuestIndexImplArch
GetActiveQuestIndexImplArch = function(self)
    local selected = self:ResolveSelectedQuest2512()
    if selected then return selected end
    return easLegacyGetActiveQuestIndex_2512(self)
end

local function easWorldMapShowing2512()
    if SCENE_MANAGER and type(SCENE_MANAGER.IsShowing) == "function" then
        local ok, showing = pcall(SCENE_MANAGER.IsShowing, SCENE_MANAGER, "worldMap")
        if ok and showing == true then return true end
    end
    return false
end

local function easEnsurePlayerMap2512()
    if easWorldMapShowing2512() then return end
    if type(DoesCurrentMapMatchMapForPlayerLocation) == "function" then
        local ok, matches = pcall(DoesCurrentMapMatchMapForPlayerLocation)
        if ok and matches == true then return end
    end
    if type(SetMapToPlayerLocation) == "function" then pcall(SetMapToPlayerLocation) end
end

local function easAtan2_2512(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi * 0.5 end
    if x == 0 and y < 0 then return -math.pi * 0.5 end
    return 0
end

-- v0.25.17: make the direction HUD self-describing so the player always knows
-- which Suite quest source, quest, and objective the arrow is using.
local function easQuestSourceLabel2517(source)
    if source == "GOLDEN_PURSUITS" then return "GOLDEN PURSUITS" end
    if source == "MAIN_QUEST" then return "MAIN QUEST" end
    return "ACTIVE QUEST"
end

local function easRelativeDirection2517(rotation)
    rotation = tonumber(rotation) or 0
    local twoPi = math.pi * 2
    while rotation > math.pi do rotation = rotation - twoPi end
    while rotation < -math.pi do rotation = rotation + twoPi end
    local degrees = rotation * 180 / math.pi
    if degrees >= -22.5 and degrees <= 22.5 then return "AHEAD" end
    if degrees > 22.5 and degrees <= 67.5 then return "AHEAD-RIGHT" end
    if degrees > 67.5 and degrees <= 112.5 then return "RIGHT" end
    if degrees > 112.5 and degrees <= 157.5 then return "BEHIND-RIGHT" end
    if degrees > 157.5 or degrees < -157.5 then return "BEHIND" end
    if degrees >= -157.5 and degrees < -112.5 then return "BEHIND-LEFT" end
    if degrees >= -112.5 and degrees < -67.5 then return "LEFT" end
    return "AHEAD-LEFT"
end

local function easQuestTargetText2517(questIndex, stepIndex, conditionIndex)
    local conditionText, current, maximum = safe(GetJournalQuestConditionInfo, "", questIndex, stepIndex, conditionIndex, true)
    local textValue = sanitizeRenderedLine(conditionText, current, maximum)
    if textValue ~= "" then return textValue end

    local stepText, _, _, trackerOverride = safe(GetJournalQuestStepInfo, "", questIndex, stepIndex)
    textValue = sanitizeRenderedLine(trackerOverride)
    if textValue == "" then textValue = sanitizeRenderedLine(stepText) end
    if textValue ~= "" then return textValue end

    local _, objectiveName = safe(GetJournalQuestLocationInfo, "", questIndex)
    objectiveName = sanitizeRenderedLine(objectiveName)
    if objectiveName ~= "" then return objectiveName end
    return "Current quest objective"
end

local CreateDirectionArrow2512ImplArch

function Q:CreateDirectionArrow2512(...)

    return CreateDirectionArrow2512ImplArch(self, ...)

end

CreateDirectionArrow2512ImplArch = function(self)
    if self.directionFrame2512 or not wm then return self.directionFrame2512 end

    local size = tonumber(EPC.saved and EPC.saved.questDirectionArrowSize) or EAS_QUEST_ARROW_DEFAULT_2512
    size = math.max(EAS_QUEST_ARROW_MIN_2512, math.min(EAS_QUEST_ARROW_MAX_2512, size))

    local frame = wm:CreateTopLevelWindow("EAS_QuestDirection2512")
    frame:SetDimensions(size, size)
    frame:SetDimensionConstraints(EAS_QUEST_ARROW_MIN_2512, EAS_QUEST_ARROW_MIN_2512)
    frame:SetResizeHandleSize(18)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)
    frame:SetHidden(true)
    if frame.SetDrawLayer then frame:SetDrawLayer(DL_OVERLAY) end
    if DT_HIGH ~= nil and frame.SetDrawTier then frame:SetDrawTier(DT_HIGH) end

    local left = tonumber(EPC.saved and EPC.saved.questDirectionArrowLeft) or -1
    local top = tonumber(EPC.saved and EPC.saved.questDirectionArrowTop) or -1
    if left >= 0 and top >= 0 then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, -170)
    end

    local glow = wm:CreateControl("EAS_QuestDirectionGlow2512", frame, CT_TEXTURE)
    glow:SetAnchor(TOPLEFT, frame, TOPLEFT, 5, 5)
    glow:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -5, -5)
    glow:SetTexture(EAS_QUEST_ARROW_TEXTURE_2512)
    glow:SetColor(0.92, 0.72, 0.25, 0.25)

    local arrow = wm:CreateControl("EAS_QuestDirectionArrow2512", frame, CT_TEXTURE)
    arrow:SetAnchor(TOPLEFT, frame, TOPLEFT, 10, 10)
    arrow:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -10, -10)
    arrow:SetTexture(EAS_QUEST_ARROW_TEXTURE_2512)
    arrow:SetColor(1, 0.88, 0.42, 1)

    -- These labels are parented to GuiRoot instead of the square arrow frame so
    -- long quest/objective names are not clipped by the resize box. They stay
    -- anchored to the arrow and therefore move with it.
    local targetLabel = wm:CreateControl("EAS_QuestDirectionTarget2517", GuiRoot, CT_LABEL)
    targetLabel:SetFont("ZoFontGameBold")
    targetLabel:SetColor(0.96, 0.80, 0.36, 1)
    targetLabel:SetDimensions(560, 24)
    targetLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    targetLabel:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    targetLabel:SetAnchor(BOTTOM, frame, TOP, 0, -6)
    targetLabel:SetHidden(true)
    if targetLabel.SetDrawLayer then targetLabel:SetDrawLayer(DL_OVERLAY) end
    if DT_HIGH ~= nil and targetLabel.SetDrawTier then targetLabel:SetDrawTier(DT_HIGH) end

    local objectiveLabel = wm:CreateControl("EAS_QuestDirectionObjective2517", GuiRoot, CT_LABEL)
    objectiveLabel:SetFont("ZoFontGameSmall")
    objectiveLabel:SetColor(0.92, 0.94, 0.97, 1)
    objectiveLabel:SetDimensions(600, 46)
    objectiveLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    objectiveLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    objectiveLabel:SetAnchor(TOP, frame, BOTTOM, 0, 6)
    objectiveLabel:SetHidden(true)
    if objectiveLabel.SetDrawLayer then objectiveLabel:SetDrawLayer(DL_OVERLAY) end
    if DT_HIGH ~= nil and objectiveLabel.SetDrawTier then objectiveLabel:SetDrawTier(DT_HIGH) end

    local guide = wm:CreateControl("EAS_QuestDirectionGuide2512", frame, CT_BACKDROP)
    guide:SetAnchor(TOPLEFT, frame, TOPLEFT, 1, 1)
    guide:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -1, -1)
    guide:SetCenterColor(0, 0, 0, 0.18)
    guide:SetEdgeTexture(nil, 1, 1, 2)
    guide:SetEdgeColor(1, 0.84, 0.42, 0.85)
    guide:SetHidden(true)

    frame:SetHandler("OnMoveStop", function(control)
        if not EPC.saved then return end
        EPC.saved.questDirectionArrowLeft = math.max(0, tonumber(control:GetLeft()) or 0)
        EPC.saved.questDirectionArrowTop = math.max(0, tonumber(control:GetTop()) or 0)
    end)
    frame:SetHandler("OnResizeStop", function(control)
        local width, height = control:GetDimensions()
        local newSize = math.max(tonumber(width) or size, tonumber(height) or size)
        newSize = math.max(EAS_QUEST_ARROW_MIN_2512, math.min(EAS_QUEST_ARROW_MAX_2512, newSize))
        control:SetDimensions(newSize, newSize)
        if EPC.saved then EPC.saved.questDirectionArrowSize = math.floor(newSize + 0.5) end
    end)

    self.directionFrame2512 = frame
    self.directionArrow2512 = arrow
    self.directionGlow2512 = glow
    self.directionGuide2512 = guide
    self.directionTargetLabel2517 = targetLabel
    self.directionObjectiveLabel2517 = objectiveLabel
    return frame
end

local GetQuestDirectionPosition2512ImplArch

function Q:GetQuestDirectionPosition2512(...)

    return GetQuestDirectionPosition2512ImplArch(self, ...)

end

GetQuestDirectionPosition2512ImplArch = function(self, questIndex)
    if not questIndex or not EPC.Travel or not EPC.Travel.RequestFocusedQuestPosition then return nil end
    easEnsurePlayerMap2512()

    local mapId = 0
    if type(GetCurrentMapId) == "function" then
        local ok, value = pcall(GetCurrentMapId)
        if ok then mapId = tonumber(value) or 0 end
    end

    local px, py, shown = nil, nil, false
    if type(GetMapPlayerPosition) == "function" then
        local ok, x, y, _, isShown = pcall(GetMapPlayerPosition, "player")
        if ok then px, py, shown = tonumber(x), tonumber(y), isShown == true end
    end

    local best = nil
    local bestDistance = nil
    local pending = false
    local fallbackTarget = ""
    local numSteps = safeNumber(GetJournalQuestNumSteps, 0, questIndex)
    for stepIndex = 1, numSteps do
        local _, visibility = safe(GetJournalQuestStepInfo, "", questIndex, stepIndex)
        if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN then
            local conditionCount = safeNumber(GetJournalQuestNumConditions, 0, questIndex, stepIndex)
            for conditionIndex = 1, conditionCount do
                local conditionText, current, maximum, isFail, isComplete, _, isVisible = safe(GetJournalQuestConditionInfo, "", questIndex, stepIndex, conditionIndex, true)
                if isVisible ~= false and isFail ~= true and isComplete ~= true then
                    local targetText = sanitizeRenderedLine(conditionText, current, maximum)
                    if targetText == "" then targetText = easQuestTargetText2517(questIndex, stepIndex, conditionIndex) end
                    if fallbackTarget == "" then fallbackTarget = targetText end

                    local positionKey = string.format("%d:%d:%d:%d", questIndex, stepIndex, conditionIndex, mapId)
                    local position = EPC.Travel.questPositionCache and EPC.Travel.questPositionCache[positionKey] or nil
                    if position == nil then
                        EPC.Travel:RequestFocusedQuestPosition({
                            questIndex = questIndex,
                            stepIndex = stepIndex,
                            conditionIndex = conditionIndex,
                            positionKey = positionKey,
                        })
                        pending = true
                    elseif position.available == true and position.x ~= nil and position.y ~= nil and shown and px ~= nil and py ~= nil then
                        local dx = tonumber(position.x) - px
                        local dy = tonumber(position.y) - py
                        local distance = (dx * dx) + (dy * dy)
                        if bestDistance == nil or distance < bestDistance then
                            best = {
                                available = true,
                                x = tonumber(position.x),
                                y = tonumber(position.y),
                                insideCurrentMapWorld = position.insideCurrentMapWorld == true,
                                isBreadcrumb = position.isBreadcrumb == true,
                                symbolicState = position.symbolicState,
                                targetText = targetText,
                                stepIndex = stepIndex,
                                conditionIndex = conditionIndex,
                            }
                            bestDistance = distance
                        end
                    end
                end
            end
        end
    end

    if fallbackTarget == "" then
        local _, objectiveName = safe(GetJournalQuestLocationInfo, "", questIndex)
        fallbackTarget = sanitizeRenderedLine(objectiveName)
    end
    if fallbackTarget == "" then fallbackTarget = "Current quest objective" end

    return best, px, py, pending, fallbackTarget
end

local UpdateDirectionArrow2512ImplArch

function Q:UpdateDirectionArrow2512(...)

    return UpdateDirectionArrow2512ImplArch(self, ...)

end

UpdateDirectionArrow2512ImplArch = function(self, force)
    local frame = self:CreateDirectionArrow2512()
    if not frame or not EPC.saved then return end

    local show = EPC.saved.showQuestDirectionArrow ~= false
    if self.layoutMode then
        show = true
    elseif EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then
        show = false
    end

    local source = self.GetQuestTrackingSource2513 and self:GetQuestTrackingSource2513() or "ACTIVE_QUEST"
    local questIndex
    if self.ResolveQuestSource2516 then
        questIndex = self:ResolveQuestSource2516(source)
    else
        questIndex = self:GetActiveQuestIndex()
    end
    if not questIndex and not self.layoutMode then show = false end

    local position, px, py, pending, fallbackTarget = nil, nil, nil, false, ""
    if show and questIndex then
        position, px, py, pending, fallbackTarget = self:GetQuestDirectionPosition2512(questIndex)
    end

    frame:SetHidden(not show)
    if self.directionTargetLabel2517 then self.directionTargetLabel2517:SetHidden(not show) end
    if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetHidden(not show) end
    if not show then return end

    local sourceLabel = easQuestSourceLabel2517(source)
    local questName = questIndex and easQuestName2512(questIndex) or "Tracked quest preview"
    if questName == "" then questName = "Tracked quest" end
    if self.directionTargetLabel2517 then
        self.directionTargetLabel2517:SetText(sourceLabel .. " - " .. questName)
    end

    if self.layoutMode and not position then
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(false) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(false) end
        if self.directionArrow2512 and self.directionArrow2512.SetTextureRotation then self.directionArrow2512:SetTextureRotation(0, 0.5, 0.5) end
        if self.directionGlow2512 and self.directionGlow2512.SetTextureRotation then self.directionGlow2512:SetTextureRotation(0, 0.5, 0.5) end
        if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetText("TARGET: current tracked quest objective - AHEAD") end
        return
    end

    if not position or px == nil or py == nil then
        -- Never leave a decorative arrow pointing north when ESO has not given
        -- us a real objective position. Show what quest/objective is selected and
        -- explain the missing direction instead.
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(true) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(true) end
        local statusText
        if pending then
            statusText = "LOCATING: " .. tostring(fallbackTarget ~= "" and fallbackTarget or "current quest objective")
        else
            local zoneName = ""
            if questIndex then zoneName = trim(safe(GetJournalQuestLocationInfo, "", questIndex)) end
            statusText = "NO MAP DIRECTION: " .. tostring(fallbackTarget ~= "" and fallbackTarget or "current quest objective")
            if zoneName ~= "" then statusText = statusText .. " - " .. zoneName end
        end
        if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetText(statusText) end
        return
    end

    local dx = tonumber(position.x) - px
    local dy = tonumber(position.y) - py
    if math.abs(dx) < 0.00001 and math.abs(dy) < 0.00001 then
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(true) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(true) end
        if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetText("TARGET REACHED: " .. tostring(position.targetText or fallbackTarget or "current quest objective")) end
        return
    end

    -- Map coordinates use north/up as negative Y. This produces a world heading
    -- compatible with ESO's 0=north heading convention, then converts it to a
    -- camera-relative HUD direction for the selected Suite quest source only.
    local worldHeading = easAtan2_2512(dx, -dy)
    local cameraHeading = 0
    if type(GetPlayerCameraHeading) == "function" then
        local ok, value = pcall(GetPlayerCameraHeading)
        if ok then cameraHeading = tonumber(value) or 0 end
    elseif type(GetMapPlayerPosition) == "function" then
        local ok, _, _, heading = pcall(GetMapPlayerPosition, "player")
        if ok then cameraHeading = tonumber(heading) or 0 end
    end
    local rotation = worldHeading - cameraHeading
    if self.directionArrow2512 then self.directionArrow2512:SetHidden(false) end
    if self.directionGlow2512 then self.directionGlow2512:SetHidden(false) end
    if self.directionArrow2512 and self.directionArrow2512.SetTextureRotation then self.directionArrow2512:SetTextureRotation(rotation, 0.5, 0.5) end
    if self.directionGlow2512 and self.directionGlow2512.SetTextureRotation then self.directionGlow2512:SetTextureRotation(rotation, 0.5, 0.5) end

    local targetText = tostring(position.targetText or fallbackTarget or "Current quest objective")
    if position.isBreadcrumb == true then targetText = targetText .. " (route / entrance)" end
    if self.directionObjectiveLabel2517 then
        self.directionObjectiveLabel2517:SetText("TARGET: " .. targetText .. " - " .. easRelativeDirection2517(rotation))
    end
end

local easLegacySetLayoutMode_2512 = SetLayoutModeImplArch
SetLayoutModeImplArch = function(self, active)
    easLegacySetLayoutMode_2512(self, active)
    local frame = self:CreateDirectionArrow2512()
    if frame then
        frame:SetMouseEnabled(self.layoutMode == true)
        frame:SetMovable(self.layoutMode == true)
        if self.directionGuide2512 then self.directionGuide2512:SetHidden(self.layoutMode ~= true) end
    end
    self:UpdateDirectionArrow2512(true)
end

local easLegacyResetPosition_2512 = ResetPositionImplArch
ResetPositionImplArch = function(self)
    easLegacyResetPosition_2512(self)
    local frame = self:CreateDirectionArrow2512()
    if frame and EPC.saved then
        EPC.saved.questDirectionArrowLeft = -1
        EPC.saved.questDirectionArrowTop = -1
        frame:ClearAnchors()
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, -170)
    end
end

local easLegacyInitialize_2512 = InitializeImplArch
InitializeImplArch = function(self)
    easLegacyInitialize_2512(self)
    self:CreateDirectionArrow2512()
    local prefix = EPC.name .. "_QuestDirection2512"
    -- Legacy custom direction-arrow polling retired; ESO native compass owns guidance.
    self:UpdateDirectionArrow2512(true)
end

-- ============================================================================
-- v0.25.13 - single selectable quest-tracking source
-- Only one source drives the Suite quest HUD + direction arrow at a time.
-- ============================================================================
local function easQuestTrackingSource2513()
    local source = tostring(EPC.saved and EPC.saved.questTrackingSource or "ACTIVE_QUEST")
    if source ~= "GOLDEN_PURSUITS" then source = "ACTIVE_QUEST" end
    return source
end

local GetQuestTrackingSource2513ImplArch

function Q:GetQuestTrackingSource2513(...)

    return GetQuestTrackingSource2513ImplArch(self, ...)

end

GetQuestTrackingSource2513ImplArch = function(self)
    return easQuestTrackingSource2513()
end

local function easQuestKeys2513(source)
    if source == "GOLDEN_PURSUITS" then
        return "goldenHudQuestIndex", "goldenHudQuestId", "goldenHudQuestName"
    end
    return "activeHudQuestIndex", "activeHudQuestId", "activeHudQuestName"
end

function Q:ResolveTrackedSourceQuest2513(source)
    if not EPC.saved then return nil end
    source = source == "GOLDEN_PURSUITS" and "GOLDEN_PURSUITS" or "ACTIVE_QUEST"
    local indexKey, idKey, nameKey = easQuestKeys2513(source)
    local wantedId = tonumber(EPC.saved[idKey]) or 0
    local wantedName = trim(EPC.saved[nameKey])

    if source == "GOLDEN_PURSUITS" and wantedId <= 0 and wantedName == "" then
        wantedName = trim(EPC.saved.goldenPursuitQuestName)
        if wantedName ~= "" then EPC.saved[nameKey] = wantedName end
    end
    if wantedId <= 0 and wantedName == "" then return nil end

    local max = tonumber(MAX_JOURNAL_QUESTS) or 25
    local wantedLower = easLower2512(wantedName)
    local nameMatch = nil
    for index = 1, max do
        local valid = type(IsValidQuestIndex) ~= "function" or safe(IsValidQuestIndex, false, index) == true
        if valid then
            local name = easQuestName2512(index)
            if name ~= "" then
                local questId = easQuestId2512(index)
                if wantedId > 0 and questId == wantedId then
                    EPC.saved[indexKey] = index
                    EPC.saved[nameKey] = name
                    return index
                end
                if not nameMatch and wantedLower ~= "" and easLower2512(name) == wantedLower then
                    nameMatch = index
                end
            end
        end
    end

    if nameMatch then
        EPC.saved[indexKey] = nameMatch
        EPC.saved[idKey] = easQuestId2512(nameMatch)
        EPC.saved[nameKey] = easQuestName2512(nameMatch)
        return nameMatch
    end

    EPC.saved[indexKey] = nil
    EPC.saved[idKey] = 0
    EPC.saved[nameKey] = ""
    return nil
end

local SyncQuestTrackingCompatibility2513ImplArch

function Q:SyncQuestTrackingCompatibility2513(...)

    return SyncQuestTrackingCompatibility2513ImplArch(self, ...)

end

SyncQuestTrackingCompatibility2513ImplArch = function(self)
    if not EPC.saved then return end
    local source = self:GetQuestTrackingSource2513()
    local indexKey, idKey, nameKey = easQuestKeys2513(source)
    EPC.saved.selectedHudQuestIndex = EPC.saved[indexKey]
    EPC.saved.selectedHudQuestId = tonumber(EPC.saved[idKey]) or 0
    EPC.saved.selectedHudQuestName = tostring(EPC.saved[nameKey] or "")
    EPC.saved.selectedHudQuestSource = source == "GOLDEN_PURSUITS" and "GOLDEN_PURSUIT" or "QUEST_FINDER"
end

local SetQuestTrackingSource2513ImplArch

function Q:SetQuestTrackingSource2513(...)

    return SetQuestTrackingSource2513ImplArch(self, ...)

end

SetQuestTrackingSource2513ImplArch = function(self, source)
    if not EPC.saved then return end
    source = source == "GOLDEN_PURSUITS" and "GOLDEN_PURSUITS" or "ACTIVE_QUEST"
    EPC.saved.questTrackingSource = source
    self:SyncQuestTrackingCompatibility2513()
    if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
        EPC.Travel:InvalidateQuestPositionCache()
    end
    self:Refresh()
    self:UpdateDirectionArrow2512(true)
    if EPC.GoldenPursuits and EPC.GoldenPursuits.RefreshVisibility2496 then
        EPC.GoldenPursuits:RefreshVisibility2496()
    end
end

SetSelectedQuest2512ImplArch = function(self, questIndex, questId, questName, source)
    if not EPC.saved then return false end
    questIndex = tonumber(questIndex)
    if not questIndex or questIndex <= 0 then return false end

    local currentName = easQuestName2512(questIndex)
    if currentName == "" then return false end
    local currentId = easQuestId2512(questIndex)
    local trackedSource = tostring(source or "") == "GOLDEN_PURSUIT" and "GOLDEN_PURSUITS" or "ACTIVE_QUEST"
    local indexKey, idKey, nameKey = easQuestKeys2513(trackedSource)

    EPC.saved[indexKey] = questIndex
    EPC.saved[idKey] = tonumber(questId) or currentId
    if (tonumber(EPC.saved[idKey]) or 0) <= 0 then EPC.saved[idKey] = currentId end
    EPC.saved[nameKey] = trim(questName) ~= "" and trim(questName) or currentName

    if trackedSource == self:GetQuestTrackingSource2513() then
        self:SyncQuestTrackingCompatibility2513()
        if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
            EPC.Travel:InvalidateQuestPositionCache()
        end
        self:Refresh()
        self:UpdateDirectionArrow2512(true)
    end
    return true
end

ClearSelectedQuest2512ImplArch = function(self)
    if not EPC.saved then return end
    local source = self:GetQuestTrackingSource2513()
    local indexKey, idKey, nameKey = easQuestKeys2513(source)
    EPC.saved[indexKey] = nil
    EPC.saved[idKey] = 0
    EPC.saved[nameKey] = ""
    self:SyncQuestTrackingCompatibility2513()
    if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
        EPC.Travel:InvalidateQuestPositionCache()
    end
    self:Refresh()
    self:UpdateDirectionArrow2512(true)
end

ResolveSelectedQuest2512ImplArch = function(self)
    return self:ResolveTrackedSourceQuest2513(self:GetQuestTrackingSource2513())
end

GetActiveQuestIndexImplArch = function(self)
    local source = self:GetQuestTrackingSource2513()
    local selected = self:ResolveTrackedSourceQuest2513(source)
    if selected then return selected end
    if source == "GOLDEN_PURSUITS" then return nil end
    return easLegacyGetActiveQuestIndex_2512(self)
end

local SetDirectionArrowSize2513ImplArch

function Q:SetDirectionArrowSize2513(...)

    return SetDirectionArrowSize2513ImplArch(self, ...)

end

SetDirectionArrowSize2513ImplArch = function(self, size)
    if not EPC.saved then return end
    size = math.max(EAS_QUEST_ARROW_MIN_2512, math.min(EAS_QUEST_ARROW_MAX_2512, tonumber(size) or EAS_QUEST_ARROW_DEFAULT_2512))
    EPC.saved.questDirectionArrowSize = math.floor(size + 0.5)
    local frame = self:CreateDirectionArrow2512()
    if frame then frame:SetDimensions(size, size) end
    self:UpdateDirectionArrow2512(true)
end

local easLegacyRefresh_2513 = RefreshImplArch
RefreshImplArch = function(self)
    -- v0.28.72: do not hide the Active Quest overlay just because Golden
    -- Pursuits owns the assisted quest/compass. Its own show setting decides.
    return easLegacyRefresh_2513(self)
end

local easLegacyInitialize_2513 = InitializeImplArch
InitializeImplArch = function(self)
    if EPC.saved then
        local source = tostring(EPC.saved.questTrackingSource or "ACTIVE_QUEST")
        if source ~= "GOLDEN_PURSUITS" then source = "ACTIVE_QUEST" end
        EPC.saved.questTrackingSource = source

        local legacySource = tostring(EPC.saved.selectedHudQuestSource or "")
        if legacySource == "GOLDEN_PURSUIT" then
            if (tonumber(EPC.saved.goldenHudQuestId) or 0) <= 0 and trim(EPC.saved.goldenHudQuestName) == "" then
                EPC.saved.goldenHudQuestIndex = EPC.saved.selectedHudQuestIndex
                EPC.saved.goldenHudQuestId = tonumber(EPC.saved.selectedHudQuestId) or 0
                EPC.saved.goldenHudQuestName = tostring(EPC.saved.selectedHudQuestName or EPC.saved.goldenPursuitQuestName or "")
            end
        else
            if (tonumber(EPC.saved.activeHudQuestId) or 0) <= 0 and trim(EPC.saved.activeHudQuestName) == "" then
                EPC.saved.activeHudQuestIndex = EPC.saved.selectedHudQuestIndex
                EPC.saved.activeHudQuestId = tonumber(EPC.saved.selectedHudQuestId) or 0
                EPC.saved.activeHudQuestName = tostring(EPC.saved.selectedHudQuestName or "")
            end
        end
        if trim(EPC.saved.goldenHudQuestName) == "" and trim(EPC.saved.goldenPursuitQuestName) ~= "" then
            EPC.saved.goldenHudQuestName = tostring(EPC.saved.goldenPursuitQuestName)
        end
        self:SyncQuestTrackingCompatibility2513()
    end
    easLegacyInitialize_2513(self)
end

-- ============================================================================
-- v0.25.14 - independent Main Quest tracking source
-- Main Story quests no longer override the Active Quest source. The Suite now
-- exposes MAIN_QUEST as a third, explicit tracker/arrow source.
-- ============================================================================
local EAS_MAIN_PROGRESSION_NAMES_2745 = {
    ["soul shriven in coldharbour"] = true,
    ["the harborage"] = true,
    ["daughter of giants"] = true,
    ["chasing shadows"] = true,
    ["castle of the worm"] = true,
    ["the tharn speaks"] = true,
    ["halls of torment"] = true,
    ["valley of blades"] = true,
    ["shadow of sancre tor"] = true,
    ["council of the five companions"] = true,
    ["messages across tamriel"] = true,
    ["the weight of three crowns"] = true,
    ["the hollow city"] = true,
    ["the army of meridia"] = true,
    ["into the woods"] = true,
    ["light from the darkness"] = true,
    ["vanus unleashed"] = true,
    ["breaking the shackle"] = true,
    ["crossing the chasm"] = true,
    ["the harvest heart"] = true,
    ["the citadel must fall"] = true,
    ["the final assault"] = true,
    ["god of schemes"] = true,
}

local function easIsKnownMainProgressionName2745(name)
    name = easLower2512(trim(name))
    return name ~= "" and EAS_MAIN_PROGRESSION_NAMES_2745[name] == true
end

local function easIsMainQuest2514(questIndex)
    if not questIndex then return false end
    local name, _, _, _, _, _, _, _, _, questType = safe(GetJournalQuestInfo, "", questIndex)
    if QUEST_TYPE_MAIN_STORY ~= nil and questType == QUEST_TYPE_MAIN_STORY then return true end
    return easIsKnownMainProgressionName2745(name)
end

function Q:ResolveMainQuest2514()
    local max = tonumber(MAX_JOURNAL_QUESTS) or 25
    local firstMain, trackedMain = nil, nil

    for index = 1, max do
        local valid = type(IsValidQuestIndex) ~= "function" or safe(IsValidQuestIndex, false, index) == true
        if valid then
            local name, _, _, _, _, completed, tracked, _, _, questType = safe(GetJournalQuestInfo, "", index)
            name = trim(name)
            local mainProgression = (QUEST_TYPE_MAIN_STORY ~= nil and questType == QUEST_TYPE_MAIN_STORY) or easIsKnownMainProgressionName2745(name)
            if name ~= "" and completed ~= true and mainProgression then
                if not firstMain then firstMain = index end
                if TRACK_TYPE_QUEST ~= nil and type(GetTrackedIsAssisted) == "function" then
                    local assisted = safe(GetTrackedIsAssisted, false, TRACK_TYPE_QUEST, index, 0) == true
                    if assisted then return index end
                end
                if tracked == true and not trackedMain then trackedMain = index end
            end
        end
    end
    return trackedMain or firstMain
end

function Q:ResolveActiveNonMainQuest2514()
    local max = tonumber(MAX_JOURNAL_QUESTS) or 25
    local fallbackTracked = nil
    for index = 1, max do
        local valid = type(IsValidQuestIndex) ~= "function" or safe(IsValidQuestIndex, false, index) == true
        if valid then
            local name, _, _, _, _, completed, tracked, _, _, questType = safe(GetJournalQuestInfo, "", index)
            name = trim(name)
            local isMain = QUEST_TYPE_MAIN_STORY ~= nil and questType == QUEST_TYPE_MAIN_STORY
            if name ~= "" and completed ~= true and not isMain then
                if TRACK_TYPE_QUEST ~= nil and type(GetTrackedIsAssisted) == "function" then
                    local assisted = safe(GetTrackedIsAssisted, false, TRACK_TYPE_QUEST, index, 0) == true
                    if assisted then return index end
                end
                if tracked == true and not fallbackTracked then fallbackTracked = index end
            end
        end
    end
    return fallbackTracked
end

GetQuestTrackingSource2513ImplArch = function(self)
    local source = tostring(EPC.saved and EPC.saved.questTrackingSource or "ACTIVE_QUEST")
    if source ~= "GOLDEN_PURSUITS" and source ~= "MAIN_QUEST" then source = "ACTIVE_QUEST" end
    return source
end

local easLegacySyncQuestTrackingCompatibility_2514 = SyncQuestTrackingCompatibility2513ImplArch
SyncQuestTrackingCompatibility2513ImplArch = function(self)
    if not EPC.saved then return end
    local source = self:GetQuestTrackingSource2513()
    if source ~= "MAIN_QUEST" then
        return easLegacySyncQuestTrackingCompatibility_2514(self)
    end

    local index = self:ResolveMainQuest2514()
    EPC.saved.selectedHudQuestIndex = index
    EPC.saved.selectedHudQuestId = index and easQuestId2512(index) or 0
    EPC.saved.selectedHudQuestName = index and easQuestName2512(index) or ""
    EPC.saved.selectedHudQuestSource = "MAIN_QUEST"
end

SetQuestTrackingSource2513ImplArch = function(self, source)
    if not EPC.saved then return end
    source = tostring(source or "ACTIVE_QUEST")
    if source ~= "GOLDEN_PURSUITS" and source ~= "MAIN_QUEST" then source = "ACTIVE_QUEST" end
    EPC.saved.questTrackingSource = source
    self:SyncQuestTrackingCompatibility2513()
    if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
        EPC.Travel:InvalidateQuestPositionCache()
    end
    self:Refresh()
    self:UpdateDirectionArrow2512(true)
    if EPC.GoldenPursuits and EPC.GoldenPursuits.RefreshVisibility2496 then
        EPC.GoldenPursuits:RefreshVisibility2496()
    end
end

local easLegacySetSelectedQuest_2514 = SetSelectedQuest2512ImplArch
SetSelectedQuest2512ImplArch = function(self, questIndex, questId, questName, source)
    local sourceName = tostring(source or "")
    if sourceName ~= "GOLDEN_PURSUIT" and easIsMainQuest2514(tonumber(questIndex)) then
        -- Main Story selection must not overwrite the separately remembered
        -- Active Quest selection. MAIN_QUEST resolves directly from the journal.
        if self:GetQuestTrackingSource2513() == "MAIN_QUEST" then
            self:SyncQuestTrackingCompatibility2513()
            if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
                EPC.Travel:InvalidateQuestPositionCache()
            end
            self:Refresh()
            self:UpdateDirectionArrow2512(true)
        end
        return true
    end
    return easLegacySetSelectedQuest_2514(self, questIndex, questId, questName, source)
end

local easLegacyClearSelectedQuest_2514 = ClearSelectedQuest2512ImplArch
ClearSelectedQuest2512ImplArch = function(self)
    if self:GetQuestTrackingSource2513() == "MAIN_QUEST" then
        -- MAIN_QUEST has no independent saved selection to clear and must never
        -- clear the stored Active Quest selection.
        self:SyncQuestTrackingCompatibility2513()
        self:Refresh()
        self:UpdateDirectionArrow2512(true)
        return
    end
    return easLegacyClearSelectedQuest_2514(self)
end

ResolveSelectedQuest2512ImplArch = function(self)
    local source = self:GetQuestTrackingSource2513()
    if source == "MAIN_QUEST" then return self:ResolveMainQuest2514() end
    return self:ResolveTrackedSourceQuest2513(source)
end

GetActiveQuestIndexImplArch = function(self)
    local source = self:GetQuestTrackingSource2513()
    if source == "GOLDEN_PURSUITS" then
        return self:ResolveTrackedSourceQuest2513("GOLDEN_PURSUITS")
    end
    if source == "MAIN_QUEST" then
        return self:ResolveMainQuest2514()
    end

    local selected = self:ResolveTrackedSourceQuest2513("ACTIVE_QUEST")
    if selected and not easIsMainQuest2514(selected) then return selected end
    return self:ResolveActiveNonMainQuest2514()
end

local easLegacyInitialize_2514 = InitializeImplArch
InitializeImplArch = function(self)
    local requestedSource = tostring(EPC.saved and EPC.saved.questTrackingSource or "ACTIVE_QUEST")
    easLegacyInitialize_2514(self)
    if not EPC.saved then return end
    if requestedSource ~= "GOLDEN_PURSUITS" and requestedSource ~= "MAIN_QUEST" then
        requestedSource = "ACTIVE_QUEST"
    end
    EPC.saved.questTrackingSource = requestedSource
    self:SyncQuestTrackingCompatibility2513()
    self:Refresh()
    self:UpdateDirectionArrow2512(true)
    if EPC.GoldenPursuits and EPC.GoldenPursuits.RefreshVisibility2496 then
        EPC.GoldenPursuits:RefreshVisibility2496()
    end
end


-- ============================================================================
-- v0.25.16 - authoritative three-source quest priority
-- The source selected in Suite Settings owns both the HUD/arrow and ESO's
-- assisted quest. Native ESO assisted/tracked state is only a fallback when the
-- selected Suite source has no remembered quest at all.
-- ============================================================================
local function easSourceKeys2516(source)
    if source == "GOLDEN_PURSUITS" then
        return "goldenHudQuestIndex", "goldenHudQuestId", "goldenHudQuestName"
    elseif source == "MAIN_QUEST" then
        return "mainHudQuestIndex", "mainHudQuestId", "mainHudQuestName"
    end
    return "activeHudQuestIndex", "activeHudQuestId", "activeHudQuestName"
end

local function easResolveRememberedQuest2516(source)
    if not EPC.saved then return nil end
    local indexKey, idKey, nameKey = easSourceKeys2516(source)
    local wantedId = tonumber(EPC.saved[idKey]) or 0
    local wantedName = trim(EPC.saved[nameKey])
    if wantedId <= 0 and wantedName == "" then return nil end

    local max = tonumber(MAX_JOURNAL_QUESTS) or 25
    local wantedLower = easLower2512(wantedName)
    local nameMatch = nil
    for index = 1, max do
        local valid = type(IsValidQuestIndex) ~= "function" or safe(IsValidQuestIndex, false, index) == true
        if valid then
            local name = easQuestName2512(index)
            if name ~= "" then
                local isMain = easIsMainQuest2514(index)
                local sourceMatches = (source == "MAIN_QUEST" and isMain)
                    or (source == "ACTIVE_QUEST" and not isMain)
                    or source == "GOLDEN_PURSUITS"
                if sourceMatches then
                    local questId = easQuestId2512(index)
                    if wantedId > 0 and questId == wantedId then
                        EPC.saved[indexKey] = index
                        EPC.saved[nameKey] = name
                        return index
                    end
                    if not nameMatch and wantedLower ~= "" and easLower2512(name) == wantedLower then
                        nameMatch = index
                    end
                end
            end
        end
    end

    if nameMatch then
        EPC.saved[indexKey] = nameMatch
        EPC.saved[idKey] = easQuestId2512(nameMatch)
        EPC.saved[nameKey] = easQuestName2512(nameMatch)
        return nameMatch
    end
    return nil
end

local ResolveQuestSource2516ImplArch

function Q:ResolveQuestSource2516(...)

    return ResolveQuestSource2516ImplArch(self, ...)

end

ResolveQuestSource2516ImplArch = function(self, source)
    source = tostring(source or self:GetQuestTrackingSource2513())
    if source ~= "GOLDEN_PURSUITS" and source ~= "MAIN_QUEST" then source = "ACTIVE_QUEST" end

    local remembered = easResolveRememberedQuest2516(source)
    if remembered then return remembered end

    -- Golden Pursuits should never silently fall back to an unrelated native
    -- quest. It only has a quest when a linked pursuit quest was remembered.
    if source == "GOLDEN_PURSUITS" then
        local pursuitName = trim(EPC.saved and EPC.saved.goldenPursuitQuestName)
        if pursuitName ~= "" then
            local _, _, nameKey = easSourceKeys2516(source)
            EPC.saved[nameKey] = pursuitName
            return easResolveRememberedQuest2516(source)
        end
        return nil
    end

    if source == "MAIN_QUEST" then
        local fallback = self:ResolveMainQuest2514()
        if fallback then
            local indexKey, idKey, nameKey = easSourceKeys2516(source)
            EPC.saved[indexKey] = fallback
            EPC.saved[idKey] = easQuestId2512(fallback)
            EPC.saved[nameKey] = easQuestName2512(fallback)
        end
        return fallback
    end

    -- ACTIVE_QUEST uses the Suite-selected non-main quest first. Only if no
    -- Suite selection exists do we use a native assisted/tracked non-main quest.
    local fallback = self:ResolveActiveNonMainQuest2514()
    if fallback then
        local indexKey, idKey, nameKey = easSourceKeys2516(source)
        EPC.saved[indexKey] = fallback
        EPC.saved[idKey] = easQuestId2512(fallback)
        EPC.saved[nameKey] = easQuestName2512(fallback)
    end
    return fallback
end

local ApplySelectedSourceToESO2516ImplArch

function Q:ApplySelectedSourceToESO2516(...)

    return ApplySelectedSourceToESO2516ImplArch(self, ...)

end

ApplySelectedSourceToESO2516ImplArch = function(self)
    if not EPC.saved then return nil end
    local source = self:GetQuestTrackingSource2513()
    local questIndex = self:ResolveQuestSource2516(source)

    if questIndex and TRACK_TYPE_QUEST ~= nil and type(SetTrackedIsAssisted) == "function" then
        if type(SetTracked) == "function" then
            pcall(SetTracked, TRACK_TYPE_QUEST, true, questIndex, 0)
        end
        pcall(SetTrackedIsAssisted, TRACK_TYPE_QUEST, true, questIndex, 0)
    end

    EPC.saved.selectedHudQuestIndex = questIndex
    EPC.saved.selectedHudQuestId = questIndex and easQuestId2512(questIndex) or 0
    EPC.saved.selectedHudQuestName = questIndex and easQuestName2512(questIndex) or ""
    EPC.saved.selectedHudQuestSource = source

    if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
        EPC.Travel:InvalidateQuestPositionCache()
    end
    self:Refresh()
    self:UpdateDirectionArrow2512(true)
    if EPC.GoldenPursuits and EPC.GoldenPursuits.RefreshVisibility2496 then
        EPC.GoldenPursuits:RefreshVisibility2496()
    end
    return questIndex
end

SetQuestTrackingSource2513ImplArch = function(self, source)
    if not EPC.saved then return end
    source = tostring(source or "ACTIVE_QUEST")
    if source ~= "GOLDEN_PURSUITS" and source ~= "MAIN_QUEST" then source = "ACTIVE_QUEST" end
    EPC.saved.questTrackingSource = source
    self:ApplySelectedSourceToESO2516()
end

SetSelectedQuest2512ImplArch = function(self, questIndex, questId, questName, source)
    if not EPC.saved then return false end
    questIndex = tonumber(questIndex)
    if not questIndex or questIndex <= 0 then return false end
    local currentName = easQuestName2512(questIndex)
    if currentName == "" then return false end

    local sourceName = tostring(source or "")
    local targetSource
    if sourceName == "GOLDEN_PURSUIT" then
        targetSource = "GOLDEN_PURSUITS"
    elseif easIsMainQuest2514(questIndex) then
        targetSource = "MAIN_QUEST"
    else
        targetSource = "ACTIVE_QUEST"
    end

    local indexKey, idKey, nameKey = easSourceKeys2516(targetSource)
    local currentId = easQuestId2512(questIndex)
    EPC.saved[indexKey] = questIndex
    EPC.saved[idKey] = tonumber(questId) or currentId
    if (tonumber(EPC.saved[idKey]) or 0) <= 0 then EPC.saved[idKey] = currentId end
    EPC.saved[nameKey] = trim(questName) ~= "" and trim(questName) or currentName

    -- Store all three source selections independently. Only the source chosen in
    -- Settings is allowed to change ESO's assisted quest/HUD/arrow.
    if self:GetQuestTrackingSource2513() == targetSource then
        self:ApplySelectedSourceToESO2516()
    end
    return true
end

ClearSelectedQuest2512ImplArch = function(self)
    if not EPC.saved then return end
    local source = self:GetQuestTrackingSource2513()
    local indexKey, idKey, nameKey = easSourceKeys2516(source)
    EPC.saved[indexKey] = nil
    EPC.saved[idKey] = 0
    EPC.saved[nameKey] = ""
    self:ApplySelectedSourceToESO2516()
end

ResolveSelectedQuest2512ImplArch = function(self)
    return self:ResolveQuestSource2516(self:GetQuestTrackingSource2513())
end

GetActiveQuestIndexImplArch = function(self)
    return self:ResolveQuestSource2516(self:GetQuestTrackingSource2513())
end

local easLegacyInitialize_2516 = InitializeImplArch
InitializeImplArch = function(self)
    easLegacyInitialize_2516(self)
    if not EPC.saved then return end
    if EPC.saved.mainHudQuestIndex == nil then EPC.saved.mainHudQuestIndex = nil end
    EPC.saved.mainHudQuestId = tonumber(EPC.saved.mainHudQuestId) or 0
    EPC.saved.mainHudQuestName = tostring(EPC.saved.mainHudQuestName or "")
    -- Re-apply the selected Suite source after all legacy initialization so a
    -- native ESO assisted quest cannot win startup order.
    self:ApplySelectedSourceToESO2516()
end

-- ============================================================================
-- v0.25.19 - live ESO quest-breadcrumb direction tracking
-- Use ESO's own WORLD_MAP_QUEST_BREADCRUMBS positions for the exact quest
-- selected by the Suite source instead of maintaining a second navigation
-- cache. The arrow rotates against the player heading returned by the same map
-- coordinate system as the quest target.
-- ============================================================================
local function easDirectionNow2519()
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

local function easMapId2519()
    if type(GetCurrentMapId) == "function" then
        local ok, value = pcall(GetCurrentMapId)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

local function easPlayerMapState2519()
    easEnsurePlayerMap2512()
    if type(GetMapPlayerPosition) ~= "function" then return nil, nil, 0, false, false end
    local ok, x, y, heading, shown, symbolic = pcall(GetMapPlayerPosition, "player")
    if not ok then return nil, nil, 0, false, false end
    return tonumber(x), tonumber(y), tonumber(heading) or 0, shown == true, symbolic == true
end

local function easPositionOnCurrentMap2519(position)
    if not position then return false, nil, nil end
    local x = tonumber(position.xLoc or position.x)
    local y = tonumber(position.yLoc or position.y)
    local inside = position.insideCurrentMapWorld == true
    if inside and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        return true, x, y
    end
    return false, x, y
end

function Q:EnsureQuestBreadcrumbs2519(questIndex, force)
    local breadcrumbs = WORLD_MAP_QUEST_BREADCRUMBS
    if not questIndex or not breadcrumbs or type(breadcrumbs.RefreshQuest) ~= "function" then return end

    local mapId = easMapId2519()
    local now = easDirectionNow2519()
    local changedQuest = self.directionBreadcrumbQuest2519 ~= questIndex
    local changedMap = self.directionBreadcrumbMap2519 ~= mapId
    local lastRefresh = tonumber(self.directionBreadcrumbRefresh2519) or -100000
    local missing = type(breadcrumbs.GetSteps) == "function" and breadcrumbs:GetSteps(questIndex) == nil
    local staleMissing = missing and (now == 0 or now - lastRefresh >= 1200)

    if force or changedQuest or changedMap or staleMissing then
        self.directionBreadcrumbQuest2519 = questIndex
        self.directionBreadcrumbMap2519 = mapId
        self.directionBreadcrumbRefresh2519 = now
        pcall(breadcrumbs.RefreshQuest, breadcrumbs, questIndex)
    end
end

local function easDirectionCandidate2519(questIndex, stepIndex, conditionIndex, position, px, py, mainStep)
    local onMap, x, y = easPositionOnCurrentMap2519(position)
    if not onMap or px == nil or py == nil then return nil end

    local dx = x - px
    local dy = y - py
    local distanceSq = dx * dx + dy * dy
    local mainPriority = stepIndex == mainStep and 0 or 1
    local breadcrumbPriority = position.isBreadcrumb == true and 1 or 0

    return {
        available = true,
        x = x,
        y = y,
        insideCurrentMapWorld = true,
        isBreadcrumb = position.isBreadcrumb == true,
        symbolicState = position.symbolicState,
        targetText = easQuestTargetText2517(questIndex, stepIndex, conditionIndex),
        stepIndex = stepIndex,
        conditionIndex = conditionIndex,
        mainPriority = mainPriority,
        breadcrumbPriority = breadcrumbPriority,
        distanceSq = distanceSq,
    }
end

local function easCandidateBetter2519(candidate, best)
    if not candidate then return false end
    if not best then return true end
    if candidate.mainPriority ~= best.mainPriority then
        return candidate.mainPriority < best.mainPriority
    end
    if candidate.breadcrumbPriority ~= best.breadcrumbPriority then
        return candidate.breadcrumbPriority < best.breadcrumbPriority
    end
    return candidate.distanceSq < best.distanceSq
end

GetQuestDirectionPosition2512ImplArch = function(self, questIndex)
    if not questIndex then return nil end

    local px, py, heading, shown, symbolic = easPlayerMapState2519()
    self.directionPlayerHeading2519 = heading
    self.directionPlayerSymbolic2519 = symbolic
    if not shown or px == nil or py == nil then
        return nil, px, py, false, "Player position is not available on this map"
    end

    self:EnsureQuestBreadcrumbs2519(questIndex, false)
    local breadcrumbs = WORLD_MAP_QUEST_BREADCRUMBS
    local mainStep = tonumber(QUEST_MAIN_STEP_INDEX) or 1
    local best = nil
    local fallbackTarget = ""
    local pending = false

    if breadcrumbs then
        if type(breadcrumbs.DoesQuestHavePendingTasks) == "function" then
            local ok, value = pcall(breadcrumbs.DoesQuestHavePendingTasks, breadcrumbs, questIndex)
            pending = ok and value == true or false
        end

        local questComplete = safe(GetJournalQuestIsComplete, false, questIndex) == true
        if questComplete then
            local position = type(breadcrumbs.GetQuestConditionPosition) == "function"
                and breadcrumbs:GetQuestConditionPosition(questIndex, mainStep, 1) or nil
            local candidate = easDirectionCandidate2519(questIndex, mainStep, 1, position, px, py, mainStep)
            if candidate then
                candidate.targetText = "Turn in quest"
                best = candidate
            end
            fallbackTarget = "Turn in quest"
        else
            local numSteps = safeNumber(GetJournalQuestNumSteps, 0, questIndex)
            for stepIndex = mainStep, numSteps do
                local _, visibility = safe(GetJournalQuestStepInfo, "", questIndex, stepIndex)
                if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN then
                    local conditionCount = safeNumber(GetJournalQuestNumConditions, 0, questIndex, stepIndex)
                    for conditionIndex = 1, conditionCount do
                        local current, maximum, isFail, isComplete, _, isVisible = safe(GetJournalQuestConditionValues, 0, questIndex, stepIndex, conditionIndex)
                        if isVisible == true and isFail ~= true and isComplete ~= true then
                            local targetText = easQuestTargetText2517(questIndex, stepIndex, conditionIndex)
                            if fallbackTarget == "" then fallbackTarget = targetText end

                            local position = type(breadcrumbs.GetQuestConditionPosition) == "function"
                                and breadcrumbs:GetQuestConditionPosition(questIndex, stepIndex, conditionIndex) or nil
                            local candidate = easDirectionCandidate2519(questIndex, stepIndex, conditionIndex, position, px, py, mainStep)
                            if candidate then
                                candidate.targetText = targetText
                                if easCandidateBetter2519(candidate, best) then best = candidate end
                            end
                        end
                    end
                end
            end
        end
    end

    if fallbackTarget == "" then
        local _, objectiveName = safe(GetJournalQuestLocationInfo, "", questIndex)
        fallbackTarget = sanitizeRenderedLine(objectiveName)
    end
    if fallbackTarget == "" then fallbackTarget = "Current quest objective" end

    -- If ESO has not populated the breadcrumb table yet, refresh only on a
    -- throttle rather than spamming requests every HUD frame.
    if not best and not pending then
        self:EnsureQuestBreadcrumbs2519(questIndex, false)
        if breadcrumbs and type(breadcrumbs.DoesQuestHavePendingTasks) == "function" then
            local ok, value = pcall(breadcrumbs.DoesQuestHavePendingTasks, breadcrumbs, questIndex)
            pending = ok and value == true or false
        end
    end

    return best, px, py, pending, fallbackTarget
end

UpdateDirectionArrow2512ImplArch = function(self, force)
    local frame = self:CreateDirectionArrow2512()
    if not frame or not EPC.saved then return end

    local show = EPC.saved.showQuestDirectionArrow ~= false
    if self.layoutMode then
        show = true
    elseif EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then
        show = false
    end

    local source = self.GetQuestTrackingSource2513 and self:GetQuestTrackingSource2513() or "ACTIVE_QUEST"
    local questIndex = self.ResolveQuestSource2516 and self:ResolveQuestSource2516(source) or self:GetActiveQuestIndex()
    if not questIndex and not self.layoutMode then show = false end

    if show and questIndex and force then
        self:EnsureQuestBreadcrumbs2519(questIndex, true)
    end

    local position, px, py, pending, fallbackTarget = nil, nil, nil, false, ""
    if show and questIndex then
        position, px, py, pending, fallbackTarget = self:GetQuestDirectionPosition2512(questIndex)
    end

    frame:SetHidden(not show)
    if self.directionTargetLabel2517 then self.directionTargetLabel2517:SetHidden(not show) end
    if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetHidden(not show) end
    if not show then return end

    local sourceLabel = easQuestSourceLabel2517(source)
    local questName = questIndex and easQuestName2512(questIndex) or "Tracked quest preview"
    if questName == "" then questName = "Tracked quest" end
    if self.directionTargetLabel2517 then
        self.directionTargetLabel2517:SetText(sourceLabel .. " - " .. questName)
    end

    if self.layoutMode and not position then
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(false) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(false) end
        if self.directionArrow2512 and self.directionArrow2512.SetTextureRotation then self.directionArrow2512:SetTextureRotation(0, 0.5, 0.5) end
        if self.directionGlow2512 and self.directionGlow2512.SetTextureRotation then self.directionGlow2512:SetTextureRotation(0, 0.5, 0.5) end
        if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetText("TARGET: current tracked quest objective - AHEAD") end
        return
    end

    if not position or px == nil or py == nil then
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(true) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(true) end
        local statusText
        if pending then
            statusText = "LOCATING: " .. tostring(fallbackTarget ~= "" and fallbackTarget or "current quest objective")
        else
            statusText = "NO MAP DIRECTION: " .. tostring(fallbackTarget ~= "" and fallbackTarget or "current quest objective")
        end
        if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetText(statusText) end
        return
    end

    local dx = tonumber(position.x) - px
    local dy = tonumber(position.y) - py
    if math.abs(dx) < 0.00001 and math.abs(dy) < 0.00001 then
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(true) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(true) end
        if self.directionObjectiveLabel2517 then
            self.directionObjectiveLabel2517:SetText("TARGET REACHED: " .. tostring(position.targetText or fallbackTarget or "current quest objective"))
        end
        return
    end

    -- Quest and player coordinates now come from the same live ESO map system.
    -- The player-map heading is the orientation of the same player pip texture
    -- used by this HUD, so the relative rotation remains locked to the target
    -- as the player turns and moves.
    local worldHeading = easAtan2_2512(dx, -dy)
    local playerHeading = tonumber(self.directionPlayerHeading2519) or 0
    local rotation = worldHeading - playerHeading
    local twoPi = math.pi * 2
    while rotation > math.pi do rotation = rotation - twoPi end
    while rotation < -math.pi do rotation = rotation + twoPi end

    if self.directionArrow2512 then self.directionArrow2512:SetHidden(false) end
    if self.directionGlow2512 then self.directionGlow2512:SetHidden(false) end
    if self.directionArrow2512 and self.directionArrow2512.SetTextureRotation then self.directionArrow2512:SetTextureRotation(rotation, 0.5, 0.5) end
    if self.directionGlow2512 and self.directionGlow2512.SetTextureRotation then self.directionGlow2512:SetTextureRotation(rotation, 0.5, 0.5) end

    local targetText = tostring(position.targetText or fallbackTarget or "Current quest objective")
    if position.isBreadcrumb == true then targetText = targetText .. " (route / entrance)" end
    if self.directionObjectiveLabel2517 then
        self.directionObjectiveLabel2517:SetText("TARGET: " .. targetText .. " - " .. easRelativeDirection2517(rotation))
    end
end

-- ============================================================================
-- v0.25.20 - strict three-source arrow binding
-- The direction arrow must never fall through to another quest source. The
-- Settings selection is normalized and becomes the single source of truth.
-- ============================================================================
local function easNormalizeQuestSource2520(source)
    local value = tostring(source or "ACTIVE_QUEST"):upper()
    value = value:gsub("%s+", "_"):gsub("%-", "_")
    if value == "GOLDEN_PURSUIT" or value == "GOLDEN_PURSUITS" then
        return "GOLDEN_PURSUITS"
    end
    if value == "MAIN" or value == "MAIN_QUEST" then
        return "MAIN_QUEST"
    end
    return "ACTIVE_QUEST"
end

GetQuestTrackingSource2513ImplArch = function(self)
    local source = easNormalizeQuestSource2520(EPC.saved and EPC.saved.questTrackingSource or "ACTIVE_QUEST")
    if EPC.saved then EPC.saved.questTrackingSource = source end
    return source
end

function Q:ResolveQuestSource2520(source)
    if not EPC.saved then return nil end
    source = easNormalizeQuestSource2520(source or self:GetQuestTrackingSource2513())

    -- Active Quest is ONLY the independently remembered non-main quest chosen
    -- through the Suite. Never borrow ESO's currently assisted quest here.
    if source == "ACTIVE_QUEST" then
        return easResolveRememberedQuest2516("ACTIVE_QUEST")
    end

    -- Golden Pursuits is ONLY the journal quest linked to the selected pursuit.
    if source == "GOLDEN_PURSUITS" then
        local remembered = easResolveRememberedQuest2516("GOLDEN_PURSUITS")
        if remembered then return remembered end
        local linkedName = trim(EPC.saved.goldenPursuitQuestName)
        if linkedName ~= "" then
            EPC.saved.goldenHudQuestName = linkedName
            return easResolveRememberedQuest2516("GOLDEN_PURSUITS")
        end
        return nil
    end

    -- A quest explicitly selected from Quest Finder's MAIN QUEST section is
    -- authoritative for this source. Some Main Story journal entries do not
    -- consistently report QUEST_TYPE_MAIN_STORY, so do not discard the user's
    -- explicit selection solely because of that metadata.
    if EPC.saved.mainQuestFinderSelected == true then
        local wantedIndex = tonumber(EPC.saved.mainHudQuestIndex) or 0
        local wantedId = tonumber(EPC.saved.mainHudQuestId) or 0
        local wantedName = trim(EPC.saved.mainHudQuestName)
        local max = tonumber(MAX_JOURNAL_QUESTS) or 25
        local function matches(index)
            local valid = type(IsValidQuestIndex) ~= "function" or safe(IsValidQuestIndex, false, index) == true
            if not valid then return false end
            local name = easQuestName2512(index)
            if name == "" then return false end
            local id = easQuestId2512(index)
            if wantedId > 0 and id == wantedId then return true end
            return wantedName ~= "" and easLower2512(name) == easLower2512(wantedName)
        end
        if wantedIndex > 0 and matches(wantedIndex) then return wantedIndex end
        for index = 1, max do
            if matches(index) then
                EPC.saved.mainHudQuestIndex = index
                EPC.saved.mainHudQuestId = easQuestId2512(index)
                EPC.saved.mainHudQuestName = easQuestName2512(index)
                return index
            end
        end
    end

    -- Otherwise discover ESO's currently accepted Main Story quest normally.
    local remembered = easResolveRememberedQuest2516("MAIN_QUEST")
    if remembered and easIsMainQuest2514(remembered) then return remembered end

    local mainQuest = self:ResolveMainQuest2514()
    if mainQuest and easIsMainQuest2514(mainQuest) then
        EPC.saved.mainHudQuestIndex = mainQuest
        EPC.saved.mainHudQuestId = easQuestId2512(mainQuest)
        EPC.saved.mainHudQuestName = easQuestName2512(mainQuest)
        return mainQuest
    end
    return nil
end

-- Keep every compatibility caller on the strict resolver.
ResolveQuestSource2516ImplArch = function(self, source)
    return self:ResolveQuestSource2520(source)
end

ResolveSelectedQuest2512ImplArch = function(self)
    return self:ResolveQuestSource2520(self:GetQuestTrackingSource2513())
end

GetActiveQuestIndexImplArch = function(self)
    return self:ResolveQuestSource2520(self:GetQuestTrackingSource2513())
end

local function easClearOldAssistedQuest2520(questIndex)
    questIndex = tonumber(questIndex)
    if not questIndex or questIndex <= 0 or TRACK_TYPE_QUEST == nil then return end
    if type(SetTrackedIsAssisted) == "function" then
        pcall(SetTrackedIsAssisted, TRACK_TYPE_QUEST, false, questIndex, 0)
    end
    if type(SetTracked) == "function" then
        pcall(SetTracked, TRACK_TYPE_QUEST, false, questIndex, 0)
    end
end

local ApplySelectedSourceToESO2520ImplArch

function Q:ApplySelectedSourceToESO2520(...)

    return ApplySelectedSourceToESO2520ImplArch(self, ...)

end

ApplySelectedSourceToESO2520ImplArch = function(self)
    if not EPC.saved then return nil end

    local source = self:GetQuestTrackingSource2513()
    local previousIndex = tonumber(EPC.saved.selectedHudQuestIndex)
    local questIndex = self:ResolveQuestSource2520(source)

    if previousIndex and previousIndex > 0 and previousIndex ~= questIndex then
        easClearOldAssistedQuest2520(previousIndex)
    end

    if questIndex and TRACK_TYPE_QUEST ~= nil then
        if type(SetTracked) == "function" then
            pcall(SetTracked, TRACK_TYPE_QUEST, true, questIndex, 0)
        end
        if type(SetTrackedIsAssisted) == "function" then
            pcall(SetTrackedIsAssisted, TRACK_TYPE_QUEST, true, questIndex, 0)
        end
    end

    EPC.saved.selectedHudQuestIndex = questIndex
    EPC.saved.selectedHudQuestId = questIndex and easQuestId2512(questIndex) or 0
    EPC.saved.selectedHudQuestName = questIndex and easQuestName2512(questIndex) or ""
    EPC.saved.selectedHudQuestSource = source

    -- Throw away direction state from the old source so an asynchronous
    -- breadcrumb result can never visually survive a source switch.
    local oldBoundIndex = tonumber(self.directionBoundQuestIndex2520)
    if oldBoundIndex and oldBoundIndex > 0 and oldBoundIndex ~= questIndex then
        local breadcrumbs = WORLD_MAP_QUEST_BREADCRUMBS
        if breadcrumbs and type(breadcrumbs.CancelPendingTasksForQuest) == "function" then
            pcall(breadcrumbs.CancelPendingTasksForQuest, breadcrumbs, oldBoundIndex)
        end
    end
    self.directionBoundSource2520 = source
    self.directionBoundQuestIndex2520 = questIndex
    self.directionBoundQuestId2520 = questIndex and easQuestId2512(questIndex) or 0
    self.directionBreadcrumbQuest2519 = nil
    self.directionBreadcrumbMap2519 = nil
    self.directionBreadcrumbRefresh2519 = -100000

    if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
        EPC.Travel:InvalidateQuestPositionCache()
    end
    self:Refresh()
    self:UpdateDirectionArrow2512(true)
    if EPC.GoldenPursuits and EPC.GoldenPursuits.RefreshVisibility2496 then
        EPC.GoldenPursuits:RefreshVisibility2496()
    end
    return questIndex
end

ApplySelectedSourceToESO2516ImplArch = function(self)
    return self:ApplySelectedSourceToESO2520()
end

SetQuestTrackingSource2513ImplArch = function(self, source)
    if not EPC.saved then return end
    source = easNormalizeQuestSource2520(source)
    EPC.saved.questTrackingSource = source
    self:ApplySelectedSourceToESO2520()
end

SetSelectedQuest2512ImplArch = function(self, questIndex, questId, questName, source)
    if not EPC.saved then return false end
    questIndex = tonumber(questIndex)
    if not questIndex or questIndex <= 0 then return false end

    local currentName = easQuestName2512(questIndex)
    if currentName == "" then return false end

    local sourceName = easNormalizeQuestSource2520(source)
    local rawSource = tostring(source or ""):upper():gsub("%s+", "_"):gsub("%-", "_")
    local targetSource
    if rawSource == "GOLDEN_PURSUIT" or rawSource == "GOLDEN_PURSUITS" then
        targetSource = "GOLDEN_PURSUITS"
    elseif rawSource == "MAIN_QUEST" or easIsMainQuest2514(questIndex) then
        targetSource = "MAIN_QUEST"
    else
        targetSource = "ACTIVE_QUEST"
    end

    local indexKey, idKey, nameKey = easSourceKeys2516(targetSource)
    local currentId = easQuestId2512(questIndex)
    local storedId = tonumber(questId) or currentId
    if storedId <= 0 then storedId = currentId end

    EPC.saved[indexKey] = questIndex
    EPC.saved[idKey] = storedId
    EPC.saved[nameKey] = trim(questName) ~= "" and trim(questName) or currentName

    if self:GetQuestTrackingSource2513() == targetSource then
        self:ApplySelectedSourceToESO2520()
    end
    return true
end

UpdateDirectionArrow2512ImplArch = function(self, force)
    local frame = self:CreateDirectionArrow2512()
    if not frame or not EPC.saved then return end

    local show = EPC.saved.showQuestDirectionArrow ~= false
    if self.layoutMode then
        show = true
    elseif EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then
        show = false
    end

    local source = self:GetQuestTrackingSource2513()
    local questIndex = self:ResolveQuestSource2520(source)
    local questId = questIndex and easQuestId2512(questIndex) or 0

    local sourceChanged = self.directionBoundSource2520 ~= source
    local questChanged = (tonumber(self.directionBoundQuestId2520) or 0) ~= questId
    if sourceChanged or questChanged then
        local oldIndex = tonumber(self.directionBoundQuestIndex2520)
        if oldIndex and oldIndex > 0 and oldIndex ~= questIndex then
            local breadcrumbs = WORLD_MAP_QUEST_BREADCRUMBS
            if breadcrumbs and type(breadcrumbs.CancelPendingTasksForQuest) == "function" then
                pcall(breadcrumbs.CancelPendingTasksForQuest, breadcrumbs, oldIndex)
            end
        end
        self.directionBoundSource2520 = source
        self.directionBoundQuestIndex2520 = questIndex
        self.directionBoundQuestId2520 = questId
        self.directionBreadcrumbQuest2519 = nil
        self.directionBreadcrumbMap2519 = nil
        self.directionBreadcrumbRefresh2519 = -100000
        force = true
    end

    if not questIndex and not self.layoutMode then show = false end
    if show and questIndex and force then self:EnsureQuestBreadcrumbs2519(questIndex, true) end

    local position, px, py, pending, fallbackTarget = nil, nil, nil, false, ""
    if show and questIndex then
        position, px, py, pending, fallbackTarget = self:GetQuestDirectionPosition2512(questIndex)
    end

    frame:SetHidden(not show)
    if self.directionTargetLabel2517 then self.directionTargetLabel2517:SetHidden(not show) end
    if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetHidden(not show) end
    if not show then return end

    local sourceLabel = easQuestSourceLabel2517(source)
    local questName = questIndex and easQuestName2512(questIndex) or "No quest selected"
    if self.directionTargetLabel2517 then
        self.directionTargetLabel2517:SetText(sourceLabel .. " - " .. questName)
    end

    if self.layoutMode and not questIndex then
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(false) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(false) end
        if self.directionArrow2512 and self.directionArrow2512.SetTextureRotation then self.directionArrow2512:SetTextureRotation(0, 0.5, 0.5) end
        if self.directionGlow2512 and self.directionGlow2512.SetTextureRotation then self.directionGlow2512:SetTextureRotation(0, 0.5, 0.5) end
        if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetText("No quest selected for this source") end
        return
    end

    if not position or px == nil or py == nil then
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(true) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(true) end
        local statusText = pending and "LOCATING: " or "NO MAP DIRECTION: "
        statusText = statusText .. tostring(fallbackTarget ~= "" and fallbackTarget or "current quest objective")
        if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetText(statusText) end
        return
    end

    local dx = tonumber(position.x) - px
    local dy = tonumber(position.y) - py
    if math.abs(dx) < 0.00001 and math.abs(dy) < 0.00001 then
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(true) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(true) end
        if self.directionObjectiveLabel2517 then
            self.directionObjectiveLabel2517:SetText("TARGET REACHED: " .. tostring(position.targetText or fallbackTarget or "current quest objective"))
        end
        return
    end

    local worldHeading = easAtan2_2512(dx, -dy)
    local playerHeading = 0
    if type(GetPlayerCameraHeading) == "function" then
        local ok, value = pcall(GetPlayerCameraHeading)
        if ok then playerHeading = tonumber(value) or 0 end
    elseif type(GetMapPlayerPosition) == "function" then
        local ok, _, _, value = pcall(GetMapPlayerPosition, "player")
        if ok then playerHeading = tonumber(value) or 0 end
    end

    local rotation = worldHeading - playerHeading
    local twoPi = math.pi * 2
    while rotation > math.pi do rotation = rotation - twoPi end
    while rotation < -math.pi do rotation = rotation + twoPi end

    if self.directionArrow2512 then self.directionArrow2512:SetHidden(false) end
    if self.directionGlow2512 then self.directionGlow2512:SetHidden(false) end
    if self.directionArrow2512 and self.directionArrow2512.SetTextureRotation then self.directionArrow2512:SetTextureRotation(rotation, 0.5, 0.5) end
    if self.directionGlow2512 and self.directionGlow2512.SetTextureRotation then self.directionGlow2512:SetTextureRotation(rotation, 0.5, 0.5) end

    local targetText = tostring(position.targetText or fallbackTarget or "Current quest objective")
    if position.isBreadcrumb == true then targetText = targetText .. " (route / entrance)" end
    if self.directionObjectiveLabel2517 then
        self.directionObjectiveLabel2517:SetText("TARGET: " .. targetText .. " - " .. easRelativeDirection2517(rotation))
    end
end

local easLegacyInitialize_2520 = InitializeImplArch
InitializeImplArch = function(self)
    easLegacyInitialize_2520(self)
    if not EPC.saved then return end
    EPC.saved.questTrackingSource = easNormalizeQuestSource2520(EPC.saved.questTrackingSource)
    self:ApplySelectedSourceToESO2520()
end

-- ============================================================================
-- v0.25.21 - native compass synchronized quest guidance
-- Keep ESO's assisted quest, the Suite quest HUD, and the movable direction
-- arrow locked to the exact same Settings source.  The native compass uses the
-- assisted quest state for its quest marker/vertical guidance, so we maintain
-- exactly one assisted quest and use GetMapPlayerPosition's heading for the
-- custom arrow because that heading shares the quest map coordinate system.
-- ============================================================================
local function easIsValidJournalQuest2521(questIndex)
    questIndex = tonumber(questIndex)
    if not questIndex or questIndex <= 0 then return false end
    if type(IsValidQuestIndex) == "function" then
        local ok, valid = pcall(IsValidQuestIndex, questIndex)
        return ok and valid == true
    end
    return easQuestName2512(questIndex) ~= ""
end

local function easSetQuestAssisted2521(questIndex, assisted)
    questIndex = tonumber(questIndex)
    if not questIndex or questIndex <= 0 or TRACK_TYPE_QUEST == nil then return end
    if type(SetTrackedIsAssisted) == "function" then
        pcall(SetTrackedIsAssisted, TRACK_TYPE_QUEST, assisted == true, questIndex, 0)
    end
end

local LockNativeCompassToQuest2521ImplArch

function Q:LockNativeCompassToQuest2521(...)

    return LockNativeCompassToQuest2521ImplArch(self, ...)

end

LockNativeCompassToQuest2521ImplArch = function(self, questIndex, force)
    questIndex = tonumber(questIndex)
    local now = easDirectionNow2519()
    local last = tonumber(self.nativeCompassSyncTime2521) or -100000
    local source = self:GetQuestTrackingSource2513()
    local questId = questIndex and easQuestId2512(questIndex) or 0
    local changed = self.nativeCompassSyncSource2521 ~= source
        or (tonumber(self.nativeCompassSyncQuestId2521) or 0) ~= questId

    if not force and not changed and now > 0 and now - last < 750 then
        return
    end
    self.nativeCompassSyncTime2521 = now
    self.nativeCompassSyncSource2521 = source
    self.nativeCompassSyncQuestId2521 = questId

    -- ESO's native compass shows the assisted quest. Remove assistance from all
    -- other journal quests so another ESO/native selection cannot steal the
    -- compass marker from the Suite's chosen Active/Golden/Main source.
    local maxQuests = tonumber(MAX_JOURNAL_QUESTS) or 25
    if TRACK_TYPE_QUEST ~= nil and type(GetTrackedIsAssisted) == "function" then
        for index = 1, maxQuests do
            if index ~= questIndex and easIsValidJournalQuest2521(index) then
                local ok, assisted = pcall(GetTrackedIsAssisted, TRACK_TYPE_QUEST, index)
                if ok and assisted == true then
                    easSetQuestAssisted2521(index, false)
                end
            end
        end
    end

    if questIndex and easIsValidJournalQuest2521(questIndex) then
        if type(SetTracked) == "function" and TRACK_TYPE_QUEST ~= nil then
            pcall(SetTracked, TRACK_TYPE_QUEST, true, questIndex, 0)
        end
        easSetQuestAssisted2521(questIndex, true)
    end
end

function Q:ApplySelectedSourceToESO2521()
    if not EPC.saved then return nil end

    local source = self:GetQuestTrackingSource2513()
    local questIndex = self:ResolveQuestSource2520(source)

    -- Keep the Suite's three sources independent, but make the currently chosen
    -- one the sole assisted quest so the native ESO compass and our HUD agree.
    self:LockNativeCompassToQuest2521(questIndex, true)

    EPC.saved.selectedHudQuestIndex = questIndex
    EPC.saved.selectedHudQuestId = questIndex and easQuestId2512(questIndex) or 0
    EPC.saved.selectedHudQuestName = questIndex and easQuestName2512(questIndex) or ""
    EPC.saved.selectedHudQuestSource = source

    local oldBoundIndex = tonumber(self.directionBoundQuestIndex2520)
    if oldBoundIndex and oldBoundIndex > 0 and oldBoundIndex ~= questIndex then
        local breadcrumbs = WORLD_MAP_QUEST_BREADCRUMBS
        if breadcrumbs and type(breadcrumbs.CancelPendingTasksForQuest) == "function" then
            pcall(breadcrumbs.CancelPendingTasksForQuest, breadcrumbs, oldBoundIndex)
        end
    end

    self.directionBoundSource2520 = source
    self.directionBoundQuestIndex2520 = questIndex
    self.directionBoundQuestId2520 = questIndex and easQuestId2512(questIndex) or 0
    self.directionBreadcrumbQuest2519 = nil
    self.directionBreadcrumbMap2519 = nil
    self.directionBreadcrumbRefresh2519 = -100000

    if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
        EPC.Travel:InvalidateQuestPositionCache()
    end
    self:Refresh()
    self:UpdateDirectionArrow2512(true)
    if EPC.GoldenPursuits and EPC.GoldenPursuits.RefreshVisibility2496 then
        EPC.GoldenPursuits:RefreshVisibility2496()
    end
    return questIndex
end

-- Compatibility callers now use the v0.25.21 synchronized implementation.
ApplySelectedSourceToESO2520ImplArch = function(self)
    return self:ApplySelectedSourceToESO2521()
end
ApplySelectedSourceToESO2516ImplArch = function(self)
    return self:ApplySelectedSourceToESO2521()
end

SetQuestTrackingSource2513ImplArch = function(self, source)
    if not EPC.saved then return end
    source = easNormalizeQuestSource2520(source)
    EPC.saved.questTrackingSource = source
    self:ApplySelectedSourceToESO2521()
end

SetSelectedQuest2512ImplArch = function(self, questIndex, questId, questName, source)
    if not EPC.saved then return false end
    questIndex = tonumber(questIndex)
    if not questIndex or questIndex <= 0 then return false end

    local currentName = easQuestName2512(questIndex)
    if currentName == "" then return false end

    local rawSource = tostring(source or ""):upper():gsub("%s+", "_"):gsub("%-", "_")
    local targetSource
    if rawSource == "GOLDEN_PURSUIT" or rawSource == "GOLDEN_PURSUITS" then
        targetSource = "GOLDEN_PURSUITS"
    elseif rawSource == "MAIN_QUEST" or easIsMainQuest2514(questIndex) then
        targetSource = "MAIN_QUEST"
    else
        targetSource = "ACTIVE_QUEST"
    end

    local indexKey, idKey, nameKey = easSourceKeys2516(targetSource)
    local currentId = easQuestId2512(questIndex)
    local storedId = tonumber(questId) or currentId
    if storedId <= 0 then storedId = currentId end

    EPC.saved[indexKey] = questIndex
    EPC.saved[idKey] = storedId
    EPC.saved[nameKey] = trim(questName) ~= "" and trim(questName) or currentName

    if self:GetQuestTrackingSource2513() == targetSource then
        self:ApplySelectedSourceToESO2521()
    end
    return true
end

UpdateDirectionArrow2512ImplArch = function(self, force)
    local frame = self:CreateDirectionArrow2512()
    if not frame or not EPC.saved then return end

    local show = EPC.saved.showQuestDirectionArrow ~= false
    if self.layoutMode then
        show = true
    elseif EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then
        show = false
    end

    local source = self:GetQuestTrackingSource2513()
    local questIndex = self:ResolveQuestSource2520(source)
    local questId = questIndex and easQuestId2512(questIndex) or 0

    local sourceChanged = self.directionBoundSource2520 ~= source
    local questChanged = (tonumber(self.directionBoundQuestId2520) or 0) ~= questId
    if sourceChanged or questChanged then
        local oldIndex = tonumber(self.directionBoundQuestIndex2520)
        if oldIndex and oldIndex > 0 and oldIndex ~= questIndex then
            local breadcrumbs = WORLD_MAP_QUEST_BREADCRUMBS
            if breadcrumbs and type(breadcrumbs.CancelPendingTasksForQuest) == "function" then
                pcall(breadcrumbs.CancelPendingTasksForQuest, breadcrumbs, oldIndex)
            end
        end
        self.directionBoundSource2520 = source
        self.directionBoundQuestIndex2520 = questIndex
        self.directionBoundQuestId2520 = questId
        self.directionBreadcrumbQuest2519 = nil
        self.directionBreadcrumbMap2519 = nil
        self.directionBreadcrumbRefresh2519 = -100000
        force = true
    end

    if questIndex then
        -- Reassert the same assisted quest on a light throttle. This prevents
        -- ESO's own journal/tracker from silently changing the compass target
        -- behind the Suite setting.
        self:LockNativeCompassToQuest2521(questIndex, force)
    end

    if not questIndex and not self.layoutMode then show = false end
    if show and questIndex and force then self:EnsureQuestBreadcrumbs2519(questIndex, true) end

    local position, px, py, pending, fallbackTarget = nil, nil, nil, false, ""
    if show and questIndex then
        position, px, py, pending, fallbackTarget = self:GetQuestDirectionPosition2512(questIndex)
    end

    frame:SetHidden(not show)
    if self.directionTargetLabel2517 then self.directionTargetLabel2517:SetHidden(not show) end
    if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetHidden(not show) end
    if not show then return end

    local sourceLabel = easQuestSourceLabel2517(source)
    local questName = questIndex and easQuestName2512(questIndex) or "No quest selected"
    if self.directionTargetLabel2517 then
        self.directionTargetLabel2517:SetText(sourceLabel .. " - " .. questName)
    end

    if self.layoutMode and not questIndex then
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(false) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(false) end
        if self.directionArrow2512 and self.directionArrow2512.SetTextureRotation then self.directionArrow2512:SetTextureRotation(0, 0.5, 0.5) end
        if self.directionGlow2512 and self.directionGlow2512.SetTextureRotation then self.directionGlow2512:SetTextureRotation(0, 0.5, 0.5) end
        if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetText("No quest selected for this source") end
        return
    end

    if not position or px == nil or py == nil then
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(true) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(true) end
        local statusText = pending and "LOCATING: " or "NO MAP DIRECTION: "
        statusText = statusText .. tostring(fallbackTarget ~= "" and fallbackTarget or "current quest objective")
        if self.directionObjectiveLabel2517 then self.directionObjectiveLabel2517:SetText(statusText) end
        return
    end

    local dx = tonumber(position.x) - px
    local dy = tonumber(position.y) - py
    if math.abs(dx) < 0.00001 and math.abs(dy) < 0.00001 then
        if self.directionArrow2512 then self.directionArrow2512:SetHidden(true) end
        if self.directionGlow2512 then self.directionGlow2512:SetHidden(true) end
        if self.directionObjectiveLabel2517 then
            self.directionObjectiveLabel2517:SetText("TARGET REACHED: " .. tostring(position.targetText or fallbackTarget or "current quest objective"))
        end
        return
    end

    -- IMPORTANT: use GetMapPlayerPosition's heading, not camera heading. ESO's
    -- normalized quest X/Y and this heading are in the same compass/map frame.
    -- Using camera heading made the arrow drift or point somewhere unrelated
    -- when the third-person camera was turned independently of the character.
    local worldHeading = easAtan2_2512(dx, -dy)
    local playerHeading = tonumber(self.directionPlayerHeading2519) or 0
    local rotation = worldHeading - playerHeading
    local twoPi = math.pi * 2
    while rotation > math.pi do rotation = rotation - twoPi end
    while rotation < -math.pi do rotation = rotation + twoPi end

    if self.directionArrow2512 then self.directionArrow2512:SetHidden(false) end
    if self.directionGlow2512 then self.directionGlow2512:SetHidden(false) end
    if self.directionArrow2512 and self.directionArrow2512.SetTextureRotation then self.directionArrow2512:SetTextureRotation(rotation, 0.5, 0.5) end
    if self.directionGlow2512 and self.directionGlow2512.SetTextureRotation then self.directionGlow2512:SetTextureRotation(rotation, 0.5, 0.5) end

    local targetText = tostring(position.targetText or fallbackTarget or "Current quest objective")
    if position.isBreadcrumb == true then targetText = targetText .. " (route / entrance)" end
    if self.directionObjectiveLabel2517 then
        self.directionObjectiveLabel2517:SetText("TARGET: " .. targetText .. " - " .. easRelativeDirection2517(rotation))
    end
end

local easLegacyInitialize_2521 = InitializeImplArch
InitializeImplArch = function(self)
    easLegacyInitialize_2521(self)
    if not EPC.saved then return end
    EPC.saved.questTrackingSource = easNormalizeQuestSource2520(EPC.saved.questTrackingSource)
    self:ApplySelectedSourceToESO2521()
end


-- ============================================================================
-- v0.25.22 - custom quest direction arrow removed
-- Quest-source selection continues to own ESO's assisted quest/native compass,
-- but the Suite no longer creates, displays, moves, resizes, or updates its own
-- direction-arrow HUD.
-- ============================================================================
local function easHideRemovedQuestArrow2522(self)
    if self.directionFrame2512 and type(self.directionFrame2512.SetHidden) == "function" then
        self.directionFrame2512:SetHidden(true)
    end
    if self.directionTargetLabel2517 and type(self.directionTargetLabel2517.SetHidden) == "function" then
        self.directionTargetLabel2517:SetHidden(true)
    end
    if self.directionObjectiveLabel2517 and type(self.directionObjectiveLabel2517.SetHidden) == "function" then
        self.directionObjectiveLabel2517:SetHidden(true)
    end
end

CreateDirectionArrow2512ImplArch = function(self)
    easHideRemovedQuestArrow2522(self)
    return nil
end

UpdateDirectionArrow2512ImplArch = function(self, force)
    easHideRemovedQuestArrow2522(self)
end

SetDirectionArrowSize2513ImplArch = function(self, size)
    easHideRemovedQuestArrow2522(self)
end

local RefreshNativeQuestTracking2522ImplArch

function Q:RefreshNativeQuestTracking2522(...)

    return RefreshNativeQuestTracking2522ImplArch(self, ...)

end

RefreshNativeQuestTracking2522ImplArch = function(self, force)
    if not EPC.saved then return end
    local source = self:GetQuestTrackingSource2513()
    local questIndex = self.ResolveQuestSource2520 and self:ResolveQuestSource2520(source) or nil
    if self.LockNativeCompassToQuest2521 then
        self:LockNativeCompassToQuest2521(questIndex, force == true)
    end
end

local easLegacyInitialize_2522 = InitializeImplArch
InitializeImplArch = function(self)
    easLegacyInitialize_2522(self)

    -- Earlier versions registered a 100 ms arrow updater. Remove that updater
    -- entirely and replace it with a light native-compass synchronization tick.
    if EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForUpdate(EPC.name .. "_QuestDirection2512")
        local prefix = EPC.name .. "_QuestTracking2522"
        EVENT_MANAGER:UnregisterForUpdate(prefix)
        -- v0.29.341: native quest tracking is serviced by the final consolidated safety pulse.
    end

    easHideRemovedQuestArrow2522(self)
    self:RefreshNativeQuestTracking2522(true)
end

-- ============================================================================
-- v0.27.44 - live Main Quest acceptance/progression reconciliation
-- A Quest Finder NEXT selection may exist before ESO has a journal entry. When
-- ESO adds that quest, promote the exact journal quest immediately and keep the
-- overlay bound to it through objective/advance/removal events.
-- ============================================================================
local function easNormalizeQuestTitle2744(value)
    local s = trim(value)
    if s == "" then return "" end
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<z:1>>", s)
        if ok and formatted then s = tostring(formatted) end
    end
    s = s:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("%s+", " ")
    return easLower2512(trim(s))
end

function Q:PromotePendingMainQuest2744(preferredIndex, preferredName)
    if not EPC.saved then return nil end
    if self:GetQuestTrackingSource2513() ~= "MAIN_QUEST" then return nil end
    local pending = EPC.saved.mainQuestDiscoveryTarget
    if type(pending) ~= "table" then return nil end

    local wantedId = tonumber(pending.questId) or 0
    local wantedName = easNormalizeQuestTitle2744(pending.name)
    local preferred = tonumber(preferredIndex) or 0

    local function matches(index, suppliedName)
        if not index or index <= 0 then return false end
        if type(IsValidQuestIndex) == "function" and safe(IsValidQuestIndex, false, index) ~= true then return false end
        local id = easQuestId2512(index)
        local name = trim(suppliedName)
        if name == "" then name = easQuestName2512(index) end
        if wantedId > 0 and id > 0 and id == wantedId then return true end
        return wantedName ~= "" and easNormalizeQuestTitle2744(name) == wantedName
    end

    local found = nil
    if preferred > 0 and matches(preferred, preferredName) then
        found = preferred
    else
        local max = tonumber(MAX_JOURNAL_QUESTS) or 25
        for index = 1, max do
            if matches(index, nil) then found = index break end
        end
    end
    if not found then return nil end

    local id = easQuestId2512(found)
    local name = easQuestName2512(found)
    EPC.saved.mainQuestFinderSelected = true
    EPC.saved.mainHudQuestIndex = found
    EPC.saved.mainHudQuestId = id
    EPC.saved.mainHudQuestName = name
    EPC.saved.selectedHudQuestIndex = found
    EPC.saved.selectedHudQuestId = id
    EPC.saved.selectedHudQuestName = name
    EPC.saved.selectedHudQuestSource = "MAIN_QUEST"
    EPC.saved.mainQuestDiscoveryTarget = nil

    if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
        EPC.Travel:InvalidateQuestPositionCache()
    end
    if self.ApplySelectedSourceToESO2520 then self:ApplySelectedSourceToESO2520() end
    if self.RefreshNativeQuestTracking2522 then self:RefreshNativeQuestTracking2522(true) end
    return found
end

function Q:ReconcileMainQuest2744(preferredIndex, preferredName)
    if not EPC.saved or self:GetQuestTrackingSource2513() ~= "MAIN_QUEST" then return end

    local promoted = self:PromotePendingMainQuest2744(preferredIndex, preferredName)
    if not promoted then
        local current = self.ResolveQuestSource2520 and self:ResolveQuestSource2520("MAIN_QUEST") or nil
        if current then
            local id = easQuestId2512(current)
            local name = easQuestName2512(current)
            EPC.saved.mainHudQuestIndex = current
            EPC.saved.mainHudQuestId = id
            EPC.saved.mainHudQuestName = name
            EPC.saved.selectedHudQuestIndex = current
            EPC.saved.selectedHudQuestId = id
            EPC.saved.selectedHudQuestName = name
            EPC.saved.selectedHudQuestSource = "MAIN_QUEST"
            EPC.saved.mainQuestDiscoveryTarget = nil
        end
    end

    if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
        EPC.Travel:InvalidateQuestPositionCache()
    end
    self:Refresh()
    if EPC.MiniMap and EPC.MiniMap.RefreshQuestPin then EPC.MiniMap:RefreshQuestPin() end
end

function Q:HandleQuestLifecycle2744(eventCode, ...)
    local args = {...}
    local preferredIndex, preferredName = nil, nil
    if eventCode == EVENT_QUEST_ADDED then
        preferredIndex = tonumber(args[1])
        preferredName = args[2]
    end

    self:ReconcileMainQuest2744(preferredIndex, preferredName)

    -- ESO can fire the lifecycle event slightly before journal conditions and
    -- assisted tracking are finalized. Reconcile again after the journal settles.
    if type(zo_callLater) == "function" then
        zo_callLater(function() self:ReconcileMainQuest2744(preferredIndex, preferredName) end, 120)
        zo_callLater(function() self:ReconcileMainQuest2744(nil, nil) end, 450)
    end
end

-- ============================================================================
-- v0.25.81 - live Main Quest source refresh
-- Main Story quests use their own tracker source. Re-resolve that source on
-- every HUD refresh so a newly advanced/replaced Main Quest cannot keep stale
-- journal index/id data or a cached travel destination from the previous step.
-- ============================================================================
local function easResolvePendingMainQuest2739()
    if not EPC.saved then return nil end
    local pending = EPC.saved.mainQuestDiscoveryTarget
    if type(pending) ~= "table" then return nil end
    local wantedId = tonumber(pending.questId) or 0
    local wantedName = trim(pending.name)
    local max = tonumber(MAX_JOURNAL_QUESTS) or 25
    for index = 1, max do
        local valid = type(IsValidQuestIndex) ~= "function" or safe(IsValidQuestIndex, false, index) == true
        if valid then
            local name = easQuestName2512(index)
            local id = easQuestId2512(index)
            if (wantedId > 0 and id == wantedId) or (wantedName ~= "" and easLower2512(name) == easLower2512(wantedName)) then
                EPC.saved.mainQuestFinderSelected = true
                EPC.saved.mainHudQuestIndex = index
                EPC.saved.mainHudQuestId = id
                EPC.saved.mainHudQuestName = name
                EPC.saved.mainQuestDiscoveryTarget = nil
                return index
            end
        end
    end
    return nil
end

local easLegacyRefresh_2581 = RefreshImplArch
RefreshImplArch = function(self)
    if EPC.saved and self.GetQuestTrackingSource2513 and self:GetQuestTrackingSource2513() == "MAIN_QUEST" then
        local previousIndex = tonumber(EPC.saved.selectedHudQuestIndex) or 0
        local previousId = tonumber(EPC.saved.selectedHudQuestId) or 0

        -- If the user selected a NEXT Main Quest before accepting it, promote
        -- that exact quest as soon as ESO adds it to the journal.
        easResolvePendingMainQuest2739()

        -- Respect the Quest Finder's explicit Main Quest selection first.
        -- The old refresh used ResolveMainQuest2514 directly, which could
        -- replace the user's selection with a different ESO Main Story entry.
        local currentIndex = self.ResolveQuestSource2520 and self:ResolveQuestSource2520("MAIN_QUEST") or nil
        if not currentIndex and self.ResolveMainQuest2514 then
            currentIndex = self:ResolveMainQuest2514()
        end
        local currentId = currentIndex and easQuestId2512(currentIndex) or 0
        local currentName = currentIndex and easQuestName2512(currentIndex) or ""

        EPC.saved.selectedHudQuestIndex = currentIndex
        EPC.saved.selectedHudQuestId = currentId
        EPC.saved.selectedHudQuestName = currentName
        EPC.saved.selectedHudQuestSource = "MAIN_QUEST"

        if currentIndex then
            EPC.saved.mainHudQuestIndex = currentIndex
            EPC.saved.mainHudQuestId = currentId
            EPC.saved.mainHudQuestName = currentName
            EPC.saved.mainQuestDiscoveryTarget = nil
        end

        if previousIndex ~= (tonumber(currentIndex) or 0) or previousId ~= currentId then
            if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
                EPC.Travel:InvalidateQuestPositionCache()
            end
            if self.ApplySelectedSourceToESO2520 then
                self:ApplySelectedSourceToESO2520()
            end
        end
    end
    return easLegacyRefresh_2581(self)
end

-- ============================================================================
-- v0.29.74 - follow ESO's native Change Quest / assisted-quest selection
-- ESO's normal quest-cycle keybind changes the assisted quest and emits a
-- tracking update. The Suite used to periodically force its prior selection
-- back onto ESO. External native quest changes now become the Suite ACTIVE_QUEST
-- selection instead, while Suite-originated assistance writes are guarded from
-- feeding back into this adoption path.
-- ============================================================================
local function easQuestSyncNow2974()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

function Q:GetESOAssistedQuestIndex2974()
    if TRACK_TYPE_QUEST == nil or type(GetTrackedIsAssisted) ~= "function" then
        return self:GetActiveQuestIndex()
    end
    local max = tonumber(MAX_JOURNAL_QUESTS) or 25
    for index = 1, max do
        local valid = type(IsValidQuestIndex) ~= "function" or safe(IsValidQuestIndex, false, index) == true
        if valid then
            local ok, assisted = pcall(GetTrackedIsAssisted, TRACK_TYPE_QUEST, index, 0)
            if ok and assisted == true then return index end
        end
    end
    return nil
end

function Q:AdoptESOFocusedQuest2974(force)
    if not EPC.saved then return false end
    if (tonumber(self.nativeTrackingWriteDepth2974) or 0) > 0 then return false end

    local now = easQuestSyncNow2974()
    local ignoreUntil = tonumber(self.nativeTrackingIgnoreUntil2974) or 0
    if not force and now > 0 and ignoreUntil > now then return false end

    local questIndex = self:GetESOAssistedQuestIndex2974()
    if not questIndex or questIndex <= 0 then return false end

    local questName = easQuestName2512(questIndex)
    if questName == "" then return false end
    local questId = easQuestId2512(questIndex)

    -- v0.29.77: ESO's Change Quest keybind is allowed to cycle onto Main Story
    -- quests. ACTIVE_QUEST intentionally excludes Main Story entries, so storing
    -- every native selection there made the overlay disappear as soon as a Main
    -- Quest became assisted. Mirror the native quest into the matching Suite
    -- source instead.
    local isMain = easIsMainQuest2514(questIndex) == true
    local targetSource = isMain and "MAIN_QUEST" or "ACTIVE_QUEST"
    local indexKey, idKey, nameKey = easSourceKeys2516(targetSource)

    local changed = self:GetQuestTrackingSource2513() ~= targetSource
        or (tonumber(EPC.saved[idKey]) or 0) ~= questId
        or tonumber(EPC.saved[indexKey]) ~= questIndex

    EPC.saved.questTrackingSource = targetSource
    EPC.saved[indexKey] = questIndex
    EPC.saved[idKey] = questId
    EPC.saved[nameKey] = questName

    -- Treat a Main Quest chosen through ESO's own quest-cycle keybind as an
    -- explicit current Main Quest selection. This prevents an older Quest Finder
    -- Main Quest choice from overriding the quest ESO just focused.
    if isMain then
        EPC.saved.mainQuestFinderSelected = true
        EPC.saved.mainQuestDiscoveryTarget = nil
    else
        -- Native ESO quest cycling has left the Main Story quest. Do not leave
        -- the Main Quest selector marked as the controlling native selection.
        -- The remembered Main Quest is preserved for later; only ACTIVE_QUEST
        -- becomes the current HUD source now.
        EPC.saved.mainQuestDiscoveryTarget = nil
    end

    EPC.saved.selectedHudQuestIndex = questIndex
    EPC.saved.selectedHudQuestId = questId
    EPC.saved.selectedHudQuestName = questName
    EPC.saved.selectedHudQuestSource = targetSource

    if changed then
        self.directionBoundSource2520 = targetSource
        self.directionBoundQuestIndex2520 = questIndex
        self.directionBoundQuestId2520 = questId
        if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
            EPC.Travel:InvalidateQuestPositionCache()
        end
        self:Refresh()
        self:UpdateDirectionArrow2512(true)
        if EPC.MiniMap and EPC.MiniMap.RefreshQuestPin then
            EPC.MiniMap:RefreshQuestPin()
        end
    end
    return true
end

local easLegacyLockNativeCompass2974 = LockNativeCompassToQuest2521ImplArch
LockNativeCompassToQuest2521ImplArch = function(self, questIndex, force)
    self.nativeTrackingWriteDepth2974 = (tonumber(self.nativeTrackingWriteDepth2974) or 0) + 1
    local result
    if easLegacyLockNativeCompass2974 then
        result = easLegacyLockNativeCompass2974(self, questIndex, force)
    end
    self.nativeTrackingWriteDepth2974 = math.max(0, (tonumber(self.nativeTrackingWriteDepth2974) or 1) - 1)
    local now = easQuestSyncNow2974()
    if now > 0 then self.nativeTrackingIgnoreUntil2974 = now + 180 end
    return result
end

local easLegacyRefreshNativeQuestTracking2974 = RefreshNativeQuestTracking2522ImplArch
RefreshNativeQuestTracking2522ImplArch = function(self, force)
    if not EPC.saved then return end
    -- v0.29.79: both ACTIVE QUEST and MAIN QUEST are native-led after ESO's
    -- Change Quest keybind is used. Keeping MAIN_QUEST on the legacy path caused
    -- the Suite to immediately re-assist the Main Story quest, preventing ESO's
    -- next cycle from reaching a normal quest. Follow whichever quest ESO has
    -- currently assisted, then AdoptESOFocusedQuest2974() switches the Suite
    -- source between MAIN_QUEST and ACTIVE_QUEST as needed.
    local nativeSource2979 = self:GetQuestTrackingSource2513()
    if nativeSource2979 == "ACTIVE_QUEST" or nativeSource2979 == "MAIN_QUEST" then
        if force == true then
            -- Initialization/explicit Suite selection may have just written the
            -- native assisted quest. Do not immediately reverse that write.
            local now = easQuestSyncNow2974()
            if (tonumber(self.nativeTrackingIgnoreUntil2974) or 0) <= now then
                self:AdoptESOFocusedQuest2974(false)
            end
        else
            self:AdoptESOFocusedQuest2974(false)
        end
        return
    end
    if easLegacyRefreshNativeQuestTracking2974 then
        return easLegacyRefreshNativeQuestTracking2974(self, force)
    end
end

local easLegacyInitialize2974 = InitializeImplArch
InitializeImplArch = function(self)
    easLegacyInitialize2974(self)

    if EVENT_MANAGER and EVENT_TRACKING_UPDATE then
        local eventName = EPC.name .. "_NativeQuestCycle2974"
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_TRACKING_UPDATE)
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_TRACKING_UPDATE, function()
            if (tonumber(Q.nativeTrackingWriteDepth2974) or 0) > 0 then return end
            local function adopt()
                Q:AdoptESOFocusedQuest2974(false)
            end
            -- ESO can emit the tracking event between unassisting the old quest
            -- and assisting the new one. Reconcile after the journal settles.
            if type(zo_callLater) == "function" then
                zo_callLater(adopt, 40)
                zo_callLater(adopt, 160)
                zo_callLater(adopt, 350)
                -- Main Story <-> normal quest transitions can settle later than
                -- ordinary journal tracking changes on some UI states.
                zo_callLater(adopt, 700)
            else
                adopt()
            end
        end)
    end
end


-- v0.29.337 - migrate old fixed-height quest viewports to adaptive content fit.
local easInitializeBefore337 = InitializeImplArch
InitializeImplArch = function(self)
    if EPC.saved and EPC.saved.activeQuestAutoFitVersion337 ~= 337 then
        EPC.saved.activeQuestManualSize2875 = false
        EPC.saved.activeQuestAutoMaxHeight337 = tonumber(EPC.saved.activeQuestAutoMaxHeight337) or MAX_HEIGHT
        EPC.saved.activeQuestAutoFitVersion337 = 337
    end
    return easInitializeBefore337(self)
end

-- ==========================================================================
-- v0.29.341 - FPS audit: consolidate legacy quest safety polling.
-- Quest lifecycle/tracking events still refresh immediately. Older revisions
-- left both a 1s full-HUD refresh and a separate native-tracking poll alive.
-- Keep one low-frequency safety tick instead so the two jobs cannot align and
-- burst on the same frame while the player is moving through a busy area.
-- ==========================================================================
local EAS_ActiveQuestInitializeBase029341 = InitializeImplArch
InitializeImplArch = function(self)
    EAS_ActiveQuestInitializeBase029341(self)
    if not EVENT_MANAGER then return end
    EVENT_MANAGER:UnregisterForUpdate(EPC.name .. "_ActiveQuest_Tick")
    EVENT_MANAGER:UnregisterForUpdate(EPC.name .. "_QuestTracking2522")
    local key = EPC.name .. "_ActiveQuestSafety029341"
    EVENT_MANAGER:UnregisterForUpdate(key)
    EVENT_MANAGER:RegisterForUpdate(key, 1500, function()
        if not EPC or not EPC.ActiveQuest then return end
        local q = EPC.ActiveQuest
        if q.RefreshNativeQuestTracking2522 then q:RefreshNativeQuestTracking2522(false) end
        -- v0.29.342: the 0.29.341 guard only refreshed an already-visible frame.
        -- If the overlay initialized before quest tracking was ready, it could
        -- remain hidden forever. Refresh is safe here: it exits immediately when
        -- disabled/suppressed, and this is only a low-frequency safety pulse.
        if q.Refresh then q:Refresh() end
    end)

    -- Player activation is the authoritative login/reload/zone-ready moment.
    -- Do two one-shot reconciliations so the overlay appears promptly without
    -- bringing back a permanent 1-second quest polling loop.
    if EVENT_PLAYER_ACTIVATED then
        local eventKey = EPC.name .. "_ActiveQuestActivated029342"
        EVENT_MANAGER:UnregisterForEvent(eventKey, EVENT_PLAYER_ACTIVATED)
        EVENT_MANAGER:RegisterForEvent(eventKey, EVENT_PLAYER_ACTIVATED, function()
            local function refreshQuest()
                local q = EPC and EPC.ActiveQuest
                if not q then return end
                if q.RefreshNativeQuestTracking2522 then q:RefreshNativeQuestTracking2522(false) end
                if q.Refresh then q:Refresh() end
            end
            refreshQuest()
            if type(zo_callLater) == "function" then
                zo_callLater(refreshQuest, 250)
                zo_callLater(refreshQuest, 900)
            end
        end)
    end
end


-- ============================================================================
-- v0.29.789 - Update 51 focused-quest cycle compatibility
--
-- Update 51 changed FOCUSED_QUEST_TRACKER:AssistNext() so the native
-- ASSIST_NEXT_TRACKED_QUEST keybind only advances while ESO's stock quest
-- tracker is displayed. The Suite uses its own Active Quest overlay and may
-- keep the stock tracker hidden, so the native T key can become a no-op.
--
-- Bindings.xml adds a hidden action inheriting ASSIST_NEXT_TRACKED_QUEST. This
-- function advances the accepted journal quest list directly while preserving
-- ESO's assisted quest/compass state and the Suite's current source metadata.
-- ============================================================================
function Q:GetCycleableJournalQuests029789()
    local quests = {}
    local max = tonumber(MAX_JOURNAL_QUESTS) or 25
    for index = 1, max do
        local valid = type(IsValidQuestIndex) ~= "function" or safe(IsValidQuestIndex, false, index) == true
        if valid and easQuestName2512(index) ~= "" then
            quests[#quests + 1] = index
        end
    end
    return quests
end

function Q:CycleTrackedQuestFallback029789(expectedQuestIndex)
    local current = type(self.GetESOAssistedQuestIndex2974) == "function" and self:GetESOAssistedQuestIndex2974() or nil
    if expectedQuestIndex and current and current ~= expectedQuestIndex then
        -- ESO's own Update 51 interaction already advanced successfully.
        self:AdoptESOFocusedQuest2974(true)
        return true
    end

    -- Prefer ESO's own tracker method. It preserves journal sort order,
    -- wraparound, zone-story behavior, focus audio, and tracker callbacks.
    local tracker = rawget(_G, "FOCUSED_QUEST_TRACKER")
    if tracker and type(tracker.AssistNext) == "function" then
        local ok = pcall(tracker.AssistNext, tracker, true)
        if ok then
            local function adopt()
                if Q and type(Q.AdoptESOFocusedQuest2974) == "function" then
                    Q:AdoptESOFocusedQuest2974(true)
                end
            end
            if type(zo_callLater) == "function" then
                zo_callLater(adopt, 30)
                zo_callLater(adopt, 120)
            else
                adopt()
            end
            return true
        end
    end

    -- Conservative fallback for unusual UI states where the native tracker
    -- object is unavailable. Advance accepted journal quests directly.
    local quests = self:GetCycleableJournalQuests029789()
    if #quests == 0 then return false end
    current = current or tonumber(EPC.saved.selectedHudQuestIndex)

    local currentPos = 0
    for i, questIndex in ipairs(quests) do
        if questIndex == current then currentPos = i break end
    end
    local nextQuest = quests[currentPos > 0 and ((currentPos % #quests) + 1) or 1]
    if not nextQuest then return false end

    self.nativeTrackingWriteDepth2974 = (tonumber(self.nativeTrackingWriteDepth2974) or 0) + 1
    if TRACK_TYPE_QUEST ~= nil and type(SetTrackedIsAssisted) == "function" then
        for _, questIndex in ipairs(quests) do
            pcall(SetTrackedIsAssisted, TRACK_TYPE_QUEST, questIndex == nextQuest, questIndex, 0)
        end
    end
    if TRACK_TYPE_QUEST ~= nil and type(SetTracked) == "function" then
        pcall(SetTracked, TRACK_TYPE_QUEST, true, nextQuest, 0)
    end
    self.nativeTrackingWriteDepth2974 = math.max(0, (tonumber(self.nativeTrackingWriteDepth2974) or 1) - 1)
    self:AdoptESOFocusedQuest2974(true)
    return true
end

function Q:CycleTrackedQuestU51029789()
    local before = type(self.GetESOAssistedQuestIndex2974) == "function" and self:GetESOAssistedQuestIndex2974() or nil

    -- Our hidden action inherits ESO's ASSIST_NEXT_TRACKED_QUEST bind. Depending
    -- on the active Update 51 HUD path, ESO may also process the native action.
    -- Wait one frame: if ESO changed focus, merely adopt it; otherwise perform
    -- the fallback. This makes the compatibility layer safe with the stock
    -- tracker both enabled and disabled and prevents skipping two quests.
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            local q = ESOProgressionCoach and ESOProgressionCoach.ActiveQuest
            if not q then return end
            q:CycleTrackedQuestFallback029789(before)
        end, 25)
        return true
    end
    return self:CycleTrackedQuestFallback029789(before)
end

function Q:InstallQuestCycleHook029790()
    if self.questCycleHookInstalled029790 == true then return true end
    local manager = rawget(_G, "HUD_TRACKER_MANAGER")
    if not manager or type(manager.EndAssistInteract) ~= "function" or type(ZO_PreHook) ~= "function" then
        return false
    end

    self.questCycleHookInstalled029790 = true

    ZO_PreHook(manager, "EndAssistInteract", function(hudTrackerManager)
        -- A held Cycle Tracked Activity key cycles tracked aspirations. Preserve
        -- ESO's long-press behavior and only supply the missing short-tap quest
        -- advance when Update 51 suppresses it because the stock quest tracker
        -- setting is hidden.
        if hudTrackerManager and hudTrackerManager.cycledAssistedAsipration then
            return false
        end

        local trackerVisible = true
        if type(GetSetting_Bool) == "function"
            and SETTING_TYPE_UI ~= nil
            and UI_SETTING_SHOW_QUEST_TRACKER ~= nil then
            local ok, value = pcall(GetSetting_Bool, SETTING_TYPE_UI, UI_SETTING_SHOW_QUEST_TRACKER)
            if ok then trackerVisible = value == true end
        end
        if trackerVisible then
            -- ESO will call FOCUSED_QUEST_TRACKER:AssistNext() itself.
            return false
        end

        local q = ESOProgressionCoach and ESOProgressionCoach.ActiveQuest
        local tracker = rawget(_G, "FOCUSED_QUEST_TRACKER")
        if not q or not tracker or type(tracker.AssistNext) ~= "function" then
            return false
        end

        -- The vanilla EndAssistInteract path skips this exact call when the
        -- quest-tracker setting is hidden. Run ESO's own implementation here so
        -- journal order, wraparound, zone-story behavior, audio, and callbacks
        -- remain native.
        local ok = pcall(tracker.AssistNext, tracker, true)
        if ok then
            local function adopt()
                local activeQuest = ESOProgressionCoach and ESOProgressionCoach.ActiveQuest
                if activeQuest and type(activeQuest.AdoptESOFocusedQuest2974) == "function" then
                    activeQuest:AdoptESOFocusedQuest2974(true)
                end
            end
            if type(zo_callLater) == "function" then
                zo_callLater(adopt, 30)
                zo_callLater(adopt, 120)
            else
                adopt()
            end
        end

        -- Do not suppress ESO's EndAssistInteract cleanup. Its own quest-cycle
        -- branch still no-ops because trackerVisible is false.
        return false
    end)

    return true
end

local EAS_ActiveQuestInitializeBefore029790 = InitializeImplArch
InitializeImplArch = function(self)
    EAS_ActiveQuestInitializeBefore029790(self)
    if not self:InstallQuestCycleHook029790() and type(zo_callLater) == "function" then
        zo_callLater(function()
            local q = ESOProgressionCoach and ESOProgressionCoach.ActiveQuest
            if q then q:InstallQuestCycleHook029790() end
        end, 500)
    end
end
