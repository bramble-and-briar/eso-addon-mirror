-- Screen adapters. Bind text at assignment time, before the owning UI measures it.
local R = ESO_ARABIC_TEXT
local REGULAR, BOLD = "EsoAR/fonts/ArabicUI.slug", "EsoAR/fonts/ArabicUIBold.slug"
local bound = setmetatable({}, {__mode = "k"})
local pending = setmetatable({}, {__mode = "k"})
local refreshRunning = false
local function reportError(b, err)
    R.lastError = tostring(err)
    if not b.reported then b.reported = true; d("ESO Arabic: " .. tostring(err)) end
end
local function queueRefresh(c)
    local b = bound[c]
    if b and not b.busy and not R.IsWriting(c) then pending[c] = true end
end
function R.FlushLayoutRefreshes()
    if refreshRunning then return end
    refreshRunning = true
    local count = 0
    local started = GetGameTimeMilliseconds and GetGameTimeMilliseconds()
    for c in pairs(pending) do
        pending[c] = nil
        local b = bound[c]
        if b then
            local ok, err = pcall(function() if not c:IsHidden() then b.refresh() end end)
            if not ok then reportError(b, err) end
        end
        count = count + 1
        if count >= 8 or (started and GetGameTimeMilliseconds() - started >= 2) then break end
    end
    refreshRunning = false
end
if EVENT_MANAGER then
    EVENT_MANAGER:RegisterForUpdate("ESOArabicLayoutRefresh", 30, R.FlushLayoutRefreshes)
end
local function child(c, name) return c and c.GetNamedChild and c:GetNamedChild(name) end
-- Tooltip pools measure their labels synchronously. A label previously found
-- by discovery must stop receiving queued refreshes once the tooltip owns it.
function R.ReleaseLabelBinding(c)
    local b = bound[c]
    if b then c.SetText = b.original end
    bound[c], pending[c] = nil, nil
    R.Manage(c)
end
local function hook(object, key, before, after)
    if not object or type(object[key]) ~= "function" then return end
    local marker = "esoArabic131_" .. key
    if object[marker] then return end
    object[marker] = true
    -- Housing market setup calls private APIs: preserve the native call stack.
    if key == "RunSetupOnControl" then
        assert(not before, "RunSetupOnControl must remain a post-hook")
        if SecurePostHook and after then SecurePostHook(object, key, after) end
        return
    end
    local original = object[key]
    object[key] = function(self, ...)
        if before then before(self, ...) end
        local result = original(self, ...)
        if after then after(self, ...) end
        return result
    end
end

function R.BindLabel(c, options)
    if not c or not c.GetText or not c.SetText or c:GetType() ~= CT_LABEL then return end
    if bound[c] then
        if options then bound[c].options = options end
        return bound[c].refresh
    end
    local b = {original = c.SetText, options = options or {flow = true}}
    bound[c] = b
    R.Manage(c)
    local function render(text)
        if b.busy or R.IsWriting(c) or not R.IsActive() or not R.HasArabic(text) then return end
        b.busy = true
        local ok, err = pcall(function()
            local sourceOptions = type(b.options) == "function" and b.options(c) or b.options
            local opts = {}
            for k, v in pairs(sourceOptions) do opts[k] = v end
            opts.text, opts.managed = text, true
            if opts.size and (not c:GetFont() or c:GetFont() == "" or c:GetFontSize() == 0) then
                c:SetFont((opts.face or REGULAR) .. "|" .. opts.size .. "|soft-shadow-thin")
            end
            -- LabelControl has SetMaxLineCount but no GetMaxLineCount in ESO.
            -- Adaptive dialogue labels otherwise retain their native 11-line
            -- cap, even when our measured font fits more lines in the space.
            if (opts.flow or opts.unlimited) and not opts.autoWidth and not b.lineLimitCleared then
                c:SetMaxLineCount(0)
                b.lineLimitCleared = true
            end
            R.ProcessControl(c, opts)
        end)
        b.busy = false
        if not ok then reportError(b, err) end
    end
    b.refresh = function() render(c:GetText()) end
    c.SetText = function(self, text)
        if b.busy then return R.WriteText(self, text) end
        if R.IsActive() and R.HasArabic(text) then
            -- Avoid ESO's font-adjusting SetText override in Arabic. It chooses
            -- another font after each assignment and invalidates the line widths.
            b.busy = true
            local ok, err = pcall(R.WriteText, self, text)
            b.busy = false
            if not ok then reportError(b, err); return end
            render(text)
        else
            b.original(self, text)
            R.ProcessControl(self, {managed = true})
        end
    end
    if ZO_PostHookHandler then
        -- Native UI code can assign text without calling the Lua SetText
        -- override. Use the same guarded path for those assignments.
        -- Native rect notifications can run while ESO is resolving an auto-
        -- sized label. Measuring/mutating that same rect from the callback can
        -- make the native layout engine loop before Lua regains control.
        -- Lua SetText assignments above still reflow before owner measurement.
        local changed = function() queueRefresh(c) end
        ZO_PostHookHandler(c, "OnTextChanged", changed)
        ZO_PostHookHandler(c, "OnRectWidthChanged", changed)
        ZO_PostHookHandler(c, "OnEffectivelyShown", changed)
    end
    -- FontAdjustingWrapLabel also changes the font from OnUpdate. Keep that
    -- callback for non-Arabic text and suppress only its Arabic font selection.
    if c.GetFonts and c.GetHandler then
        local onUpdate = c:GetHandler("OnUpdate")
        if onUpdate then c:SetHandler("OnUpdate", function(self, ...)
            if R.IsActive() and R.HasArabic(self:GetText()) then return end
            return onUpdate(self, ...)
        end) end
    end
    b.refresh()
    return b.refresh
end

local function dialogueOptions(c)
    local gp = IsInGamepadPreferredMode()
    local name = c:GetName() or ""
    local isBody = c.GetFonts or name:find("BodyText", 1, true)
    local bottom = isBody and c.GetBottom and c:GetBottom()
    local height = bottom and math.max(160, bottom - 50) or nil
    return {size = gp and 36 or 26, minimum = gp and 26 or 22,
        face = REGULAR, flow = height == nil, height = height, unlimited = isBody,
        reflowVisual = true, align = TEXT_ALIGN_RIGHT}
end
-- Mirror only the interaction selection decoration, not the whole UI tree.
local function mirrorDialogueHighlight(control, depth)
    if not control or depth > 2 then return end
    if control.GetType and control:GetType() == CT_TEXTURE and control.GetTextureCoords then
        local coords = control.esoArabicOriginalCoords
        if not coords then
            coords = {control:GetTextureCoords()}
            if #coords == 4 then control.esoArabicOriginalCoords = coords end
        end
        if coords and #coords == 4 then
            if R.IsActive() then control:SetTextureCoords(coords[2], coords[1], coords[3], coords[4])
            else control:SetTextureCoords(unpack(coords)) end
        end
    end
    if control.GetNumChildren then
        for i = 1, control:GetNumChildren() do mirrorDialogueHighlight(control:GetChild(i), depth + 1) end
    end
end
-- Keep the native dialogue width; only mirror its decorations and option origin.
local function keyboardPanel(self, lastOption)
    local root = self.control
    local divider = child(root, "Divider")
    local options = child(root, "PlayerAreaOptions")
    if not divider or not options then return end
    local names = {"PlayerAreaOptions", "ReplayAudio", "TopBG", "BottomBG", "VerticalSeparator"}
    if not self.esoArabicPanel11 then
        self.esoArabicPanel11 = {}
        for _, name in ipairs(names) do
            local c = child(root, name)
            if c then
                local saved = {anchors = {}}
                for i = 0, c:GetNumAnchors() - 1 do
                    local valid, p, target, relative, x, y = c:GetAnchor(i)
                    if valid then saved.anchors[#saved.anchors + 1] = {p, target, relative, x, y} end
                end
                if c.GetTextureCoords then saved.coords = {c:GetTextureCoords()} end
                self.esoArabicPanel11[name] = saved
            end
        end
    end
    if not R.IsActive() then
        if self.esoArabicPanel11Active then
            for name, saved in pairs(self.esoArabicPanel11) do
                local c = child(root, name)
                c:ClearAnchors()
                for _, anchor in ipairs(saved.anchors) do c:SetAnchor(unpack(anchor)) end
                if saved.coords then c:SetTextureCoords(unpack(saved.coords)) end
            end
            options:SetResizeToFitDescendents(true)
            self.esoArabicPanel11Active = false
        end
        return
    end
    self.esoArabicPanel11Active = true
    -- A right-anchored child must not determine its parent's width.
    options:SetResizeToFitDescendents(false)
    options:SetWidth(divider:GetWidth())
    options:ClearAnchors()
    options:SetAnchor(TOPRIGHT, child(root, "PlayerArea"), TOPRIGHT, 0, 0)
    local audio = child(root, "ReplayAudio")
    audio:ClearAnchors()
    audio:SetAnchor(TOPRIGHT, child(root, "TargetArea"), BOTTOMRIGHT, 0, 5)
    local top, bottom = child(root, "TopBG"), child(root, "BottomBG")
    top:ClearAnchors()
    top:SetAnchor(TOPRIGHT, child(root, "TargetAreaTitle"), TOPRIGHT, 10, -120)
    top:SetAnchor(BOTTOMLEFT, divider, LEFT, -10, 0)
    if lastOption then self.esoArabicLastOption11 = lastOption end
    lastOption = self.esoArabicLastOption11
    if lastOption then
        bottom:ClearAnchors()
        bottom:SetAnchor(TOPLEFT, divider, LEFT, -10, 0)
        bottom:SetAnchor(BOTTOMRIGHT, lastOption, BOTTOMRIGHT, 40, 120)
    end
    for _, name in ipairs({"TopBG", "BottomBG", "VerticalSeparator"}) do
        local c, saved = child(root, name), self.esoArabicPanel11[name]
        if saved and saved.coords then
            local t = saved.coords
            c:SetTextureCoords(t[2], t[1], t[3], t[4])
        end
    end
    local separator = child(root, "VerticalSeparator")
    separator:ClearAnchors()
    separator:SetAnchor(TOPLEFT, top, TOPRIGHT, 0, 0)
    separator:SetAnchor(BOTTOMLEFT, bottom, BOTTOMRIGHT, 0, 0)
end

local function bindKeyboard(self)
    keyboardPanel(self)
    mirrorDialogueHighlight(_G.ZO_InteractWindowPlayerAreaHighlight, 0)
    R.BindLabel(child(self.control, "TargetAreaBodyText"), dialogueOptions)
    for index, c in ipairs(self.optionControls or {}) do
        R.BindLabel(c, dialogueOptions)
        if not c.esoArabicOriginalAnchor7 then
            local valid, point, target, relative, x, y = c:GetAnchor(0)
            if valid then c.esoArabicOriginalAnchor7 = {point, target, relative, x, y} end
        end
        if R.IsActive() then
            c:ClearAnchors()
            if index == 1 then c:SetAnchor(TOPRIGHT, c:GetParent(), TOPRIGHT, -30, 0)
            else c:SetAnchor(TOPRIGHT, self.optionControls[index - 1], BOTTOMRIGHT, 0, 8) end
        elseif c.esoArabicOriginalAnchor7 then
            c:ClearAnchors(); c:SetAnchor(unpack(c.esoArabicOriginalAnchor7))
        end
        local icon = child(c, "Icon")
        if icon then
            icon:ClearAnchors()
            if R.IsActive() then icon:SetAnchor(LEFT, c, RIGHT, 5, 0)
            else icon:SetAnchor(RIGHT, c, LEFT, -5, 0) end
        end
    end
end
local function bindGamepad(self)
    R.BindLabel(self.textControl, dialogueOptions)
    local list = self.itemList
    if list then
        mirrorDialogueHighlight(list.selectionHighlightControl, 0)
        -- The native TOP/CENTER anchors position rows inside the clipping area.
        -- RTL belongs inside each row; moving the row to the center point's
        -- right edge displaces half its width outside the visible list.
    end
    if list and list.dataTypes then
        for name, info in pairs(list.dataTypes) do
            if (name == "ZO_ChatterOption_Gamepad" or name == "ZO_InteractWindow_GamepadBodyTextItem") and not info.esoArabic131 then
                info.esoArabic131 = true
                local original = info.setupFunction
                info.setupFunction = function(control, ...)
                    local label = child(control, "Text") or child(child(control, "TargetArea"), "BodyText")
                    local refresh = R.BindLabel(label, dialogueOptions)
                    original(control, ...)
                    if refresh then refresh() end
                    if name == "ZO_ChatterOption_Gamepad" and label then
                        local icon = child(control, "Icon")
                        if R.IsActive() then
                            label:ClearAnchors()
                            label:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
                            label:SetAnchor(TOPRIGHT, control, TOPRIGHT, icon and not icon:IsHidden() and -44 or 0, 0)
                            if icon then
                                icon:ClearAnchors()
                                icon:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 3)
                            end
                            if refresh then refresh() end
                        elseif icon then
                            icon:ClearAnchors()
                            icon:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 3)
                        end
                        control:SetHeight(label:GetTextHeight())
                    end
                end
            end
        end
    end
end

local function statsRow(row)
    if not row then return end
    local name, value = row.name or row.nameLabel, row.value or row.valueLabel
    if not name or not value or not R.HasArabic(name:GetText()) then return end
    local reserve = math.max(65, value:GetTextWidth())
    for _, key in ipairs({"pendingBonus", "comparisonValue"}) do
        local extra = row[key]
        if extra and not extra:IsHidden() then reserve = reserve + extra:GetTextWidth() + 8 end
    end
    local width = math.max(50, row:GetWidth() - reserve - 36)
    name:ClearAnchors()
    name:SetAnchor(LEFT, row, LEFT, 0, 0)
    name:SetWidth(width)
    name:SetMaxLineCount(1)
    R.Manage(name)
    R.ProcessControl(name, {managed = true, single = true, width = width,
        size = 20, minimum = 14, align = TEXT_ALIGN_RIGHT})
end
R.LayoutStatsRow = statsRow

local function horizontalPoint(point)
    if point == LEFT or point == TOPLEFT or point == BOTTOMLEFT then return 0 end
    if point == RIGHT or point == TOPRIGHT or point == BOTTOMRIGHT then return 2 end
    return 1
end

local function stretchesHorizontally(c)
    if c:GetNumAnchors() < 2 then return false end
    if not c.GetAnchor then return true end
    local first
    for i = 0, c:GetNumAnchors() - 1 do
        local valid, point, _, _, _, _, constraint = c:GetAnchor(i)
        if valid and constraint ~= ANCHOR_CONSTRAINS_Y then
            local x = horizontalPoint(point)
            if first ~= nil and first ~= x then return true end
            first = x
        end
    end
    return false
end

local function discoveredOptions(c)
    local name = (c:GetName() or ""):lower()
    local single = name:find("keybind", 1, true) or name:find("button", 1, true)
    local opts = {flow = not single, single = single, align = TEXT_ALIGN_RIGHT}
    if name:find("gamemenu", 1, true) then
        opts.flow, opts.single = false, true
        opts.size, opts.minimum, opts.height = 22, 16, 28
    end
    local parent = c:GetParent()
    if name:find("champion", 1, true) and name:match("pointheader$")
        and child(parent, "ConstellationName") and child(parent, "PointValue") then
        local title, value = child(parent, "ConstellationName"), child(parent, "PointValue")
        title:SetWidth(200)
        title:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        c:ClearAnchors()
        c:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 0)
        value:ClearAnchors()
        value:SetAnchor(RIGHT, c, LEFT, -10, 0)
    end
    -- Tree rows have fixed native spacing. Keep their navigation caption on
    -- one measured line instead of spilling into the following menu entry.
    if parent and parent.node and parent.text == c then
        opts.flow, opts.single = false, true
        opts.size, opts.minimum = IsInGamepadPreferredMode() and 28 or 22, 16
    end
    -- A fixed-height row cannot grow when a translated caption wraps.
    -- This applies to keyboard navigation rows even when node.text is absent.
    if not IsInGamepadPreferredMode() and parent and parent.GetDesiredHeight then
        local rowHeight = parent:GetDesiredHeight()
        if rowHeight and rowHeight > 0 and rowHeight <= 40 then
            opts.flow, opts.single = false, true
            opts.height, opts.minimum = rowHeight, 14
        end
    end
    if name:find("buff", 1, true) and name:find("duration", 1, true) then
        opts.flow, opts.single, opts.align = false, true, TEXT_ALIGN_CENTER
        opts.size, opts.minimum = 20, 14
    end
    if name:find("gamepadplayerprogressbar", 1, true) or name:find("genericfooter_gamepad", 1, true) then
        opts.flow, opts.single = false, true
        opts.size, opts.minimum = 30, 22
    end
    if parent and name:find("inventory", 1, true) and name:match("name$") and parent.GetDesiredHeight then
        local rowHeight = parent:GetDesiredHeight()
        if rowHeight and rowHeight > 0 then
            opts.flow, opts.height, opts.minimum = false, math.max(20, rowHeight - 4), 16
            opts.multiline = true
            opts.unlimited = true
            opts.size = 20
        end
    end
    if c.GetDesiredHeight then
        local height = c:GetDesiredHeight()
        if height > 0 and not opts.multiline then opts.flow, opts.height = false, height end
        if not IsInGamepadPreferredMode() and height > 0 and height <= 32 and not opts.multiline then
            opts.flow, opts.single = false, true
            opts.minimum = 14
        end
    end
    if c.GetDesiredWidth and c:GetDesiredWidth() <= 0 and not stretchesHorizontally(c) then
        local _, _, maximum = c:GetDimensionConstraints()
        if maximum and maximum > 0 then
            -- Quest headers have a maximum width but shrink to the rendered
            -- glyphs. Reusing that glyph extent loses padding on every pass.
            opts.width = maximum
        else
            opts.autoWidth = true
        end
    end
    if not IsInGamepadPreferredMode() and name:find("unitframe", 1, true)
        and (name:match("name$") or name:match("status$")) then
        opts.flow, opts.single = false, true
        opts.size, opts.minimum = 20, 14
        if name == "zo_companionunitframename" then
            -- Native nameWidth (215) extends beyond the 170px health bar.
            opts.autoWidth, opts.width, opts.height = false, 170, 22
            c:SetWidth(170)
            c:SetMaxLineCount(1)
        end
    end
    if not IsInGamepadPreferredMode() and name == "zo_guildsharedinfocountlabel" then
        opts.flow, opts.single, opts.autoWidth = false, true, true
        opts.size, opts.minimum = 18, 14
    end
    if not IsInGamepadPreferredMode() and name:find("questjournalnavigationentry", 1, true) then
        -- This native label is only 22px high. Header-sized Arabic glyphs
        -- extend below its clip rectangle even when their width fits.
        opts.flow, opts.single, opts.autoWidth = false, true, false
        opts.width, opts.height = 220, 22
        opts.size, opts.minimum = 16, 12
        c:SetMaxLineCount(1)
        c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    if not IsInGamepadPreferredMode() and name:find("collectionsbook", 1, true) then
        if name:find("subcategory", 1, true) then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.size, opts.minimum, opts.width = 20, 12, 218
            -- Match the actual label box to its measured width so the right
            -- edge remains inside the category scroll container's clip rect.
            c:SetWidth(218)
            c:SetMaxLineCount(1)
        end
    end
    if not IsInGamepadPreferredMode() and child(parent, "Title") == c
        and child(parent, "CooldownIconDesaturated") and child(parent, "CornerTag") then
        -- Collectible tiles reserve 54px below the icon, with side padding.
        opts.flow, opts.single, opts.autoWidth = false, false, false
        opts.multiline, opts.unlimited = true, true
        opts.height, opts.width = 50, math.max(40, parent:GetWidth() - 24)
        opts.size, opts.minimum = 20, 12
        opts.align = TEXT_ALIGN_CENTER
    end
    if not IsInGamepadPreferredMode() then
        if name:match("summaryinsetpoints$") and name:find("achievement", 1, true) then
            if not c.esoArabicSummaryPosition then
                c:ClearAnchors()
                c:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, -32)
                c.esoArabicSummaryPosition = true
            end
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.width, opts.size, opts.minimum = 300, 20, 14
        end
        local journalCategory = name:find("antiquityjournal_subcategory", 1, true)
            or name:find("achievements_subcategory", 1, true)
        if journalCategory then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.size, opts.minimum, opts.width = 18, 12, 210
            c:SetWidth(210)
            c:SetMaxLineCount(1)
        end
        if name:find("lorelibrarynavigationentry", 1, true) then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.size, opts.minimum, opts.width = 20, 12, 320
            c:SetWidth(320)
            c:SetMaxLineCount(1)
        elseif name:find("lorelibrary", 1, true) and child(parent, "Text") == c and child(parent, "Icon") then
            opts.flow, opts.single, opts.autoWidth = false, false, false
            opts.multiline, opts.unlimited = true, true
            opts.width, opts.height, opts.size, opts.minimum = c:GetWidth(), 44, 18, 12
        end
        if child(parent, "AntiquityType") and child(parent, "NumRecovered") then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.size, opts.minimum = 18, 12
            if child(parent, "Title") == c then opts.width = 340
            elseif child(parent, "AntiquityType") == c then opts.width = 155
            elseif child(parent, "NumRecovered") == c then opts.width = 175 end
            if opts.width then c:SetWidth(opts.width) end
            c:SetMaxLineCount(1)
        end
        if child(parent, "Points") and child(parent, "Description") and child(parent, "Title")
            and (child(parent, "Title") == c or child(parent, "Description") == c) then
            opts.flow, opts.autoWidth = false, false
            opts.width, opts.size, opts.minimum = 274, 18, 12
            c:SetWidth(274)
            if child(parent, "Title") == c then
                opts.single = true
                c:SetMaxLineCount(1)
            else
                local _, _, _, cap = c:GetDimensionConstraints()
                opts.height = cap and cap > 0 and cap or nil
                opts.multiline, opts.unlimited = true, true
                opts.flow = opts.height == nil
            end
        end
        if name:find("leaderboardsinformationarea", 1, true) then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.width = math.max(100, parent:GetWidth() / 2 - 12)
            opts.size, opts.minimum = 18, 12
            c:SetWidth(opts.width)
            c:SetMaxLineCount(1)
        end
    end
    -- Promotional activity rows reserve a single caption above Progress.
    -- Allowing automatic wrapping spills the caption into adjacent rows.
    if not IsInGamepadPreferredMode() and name:find("promotionalevent", 1, true)
        and child(parent, "Name") == c and child(parent, "TrackButton")
        and child(parent, "Progress") then
        opts.flow, opts.single, opts.autoWidth = false, true, false
        opts.size, opts.minimum = 22, 12
        opts.width = child(parent, "Progress"):GetWidth()
        opts.height = nil
        c:SetMaxLineCount(1)
    end
    if not IsInGamepadPreferredMode() then
        local collectionBook = name:find("dlcbook", 1, true) or name:find("housingbook", 1, true)
            or name:find("tributepatronbook", 1, true)
        if collectionBook and name:match("description$") then
            opts.reflowVisual = true
        end
        if name:find("specializedcollection_book_navigationentry", 1, true) then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.reflowVisual = true
            opts.width, opts.height, opts.size, opts.minimum = 200, 22, 16, 12
            c:SetWidth(200)
            c:SetMaxLineCount(1)
        end
        if name:find("lorelibrary", 1, true) and name:match("text$") then
            opts.reflowVisual = true
        end
        if name:find("itemsetsbook", 1, true) and child(parent, "Name") == c
            and child(parent, "Progress") then
            opts.flow, opts.single, opts.autoWidth = false, true, false
            opts.width = math.max(40, child(parent, "Progress"):GetWidth())
            opts.size, opts.minimum = 18, 12
            opts.reflowVisual = true
            c:SetMaxLineCount(1)
        end
    end
    return opts
end

local function buttonOptions(c, button)
    return {single = true, flow = false, width = math.max(40, button:GetWidth() - 16),
        size = IsInGamepadPreferredMode() and 26 or 22, minimum = 14,
        align = TEXT_ALIGN_CENTER}
end

local function bindButton(c)
    -- A ButtonControl owns a native LabelControl which is not necessarily a
    -- child returned by GetChild. Use the documented label accessor.
    if not c.GetLabelControl then return end
    local label = c:GetLabelControl()
    if not label or not R.HasArabic(label:GetText()) then return end
    local refresh = R.BindLabel(label, function(l) return buttonOptions(l, c) end)
    if not c.esoArabicButtonHook and ZO_PostHook then
        c.esoArabicButtonHook = true
        ZO_PostHook(c, "SetText", function() queueRefresh(label) end)
    end
    if refresh then refresh() end
end

local function headerOptions(c)
    -- ESO stretches the caption across the whole row and anchors its value
    -- to that row's right edge. Right-aligning that caption overlays the value.
    local key = (c:GetName() or ""):match("(Data[1-4])Header$")
    local value = key and child(c:GetParent(), key)
    local opts = {single = true, align = TEXT_ALIGN_LEFT, size = 26, minimum = 20}
    if value and not value:IsHidden() and stretchesHorizontally(c) then
        opts.width = math.max(40, c:GetWidth() - value:GetTextWidth() - 20)
    elseif not stretchesHorizontally(c) then
        opts.autoWidth = true
    end
    return opts
end

local function bindHeader(control)
    for i = 1, 4 do
        local c = child(control, "Data" .. i .. "Header")
        if c then
            local refresh = R.BindLabel(c, headerOptions)
            if refresh then refresh() end
        end
    end
end

function R.BindDiscoveredControl(c)
    if CT_BUTTON and c:GetType() == CT_BUTTON then bindButton(c); return end
    if c:GetType() ~= CT_LABEL then return end
    -- Numeric labels never enter the Arabic shaping path. The replacement
    -- font has wider digits, so fit known numeric columns independently.
    local numericName = c:GetName() or ""
    local skillRank = numericName == "ZO_SkillsSkillInfoRank"
        or numericName == "ZO_CompanionSkills_Panel_KeyboardSkillLineInfoRank"
    if not IsInGamepadPreferredMode() and R.IsActive()
        and (skillRank
            or ((numericName:find("GuildRoster", 1, true)
                or numericName:find("FriendsList", 1, true)) and numericName:match("Level$"))) then
        local text = c:GetText() or ""
        local width = c:GetWidth()
        if text:match("^%d+$") and width > 0 then
            local signature = text .. ":" .. tostring(width)
            if c.esoArabicNumericFit ~= signature then
                c:SetMaxLineCount(1)
                if skillRank then
                    -- Name and XPBar anchor to opposite edges of Rank.
                    -- Preserve their vertical separation after fitting digits.
                    c:SetHeight(65)
                    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                end
                local size = skillRank and 36 or 18
                c:SetFont(BOLD .. "|" .. size .. "|soft-shadow-thick")
                while c:GetTextWidth() > width and size > 12 do
                    size = size - 1
                    c:SetFont(BOLD .. "|" .. size .. "|soft-shadow-thick")
                end
                c.esoArabicNumericFit = signature
            end
        end
        return
    end
    if bound[c] then bound[c].refresh(); return end
    if R.IsManaged(c) then return end
    local text = c:GetText()
    if not R.HasArabic(text) then return end
    local name = c:GetName() or ""
    -- Existing specialized layouts (books/tooltips) remain under their owners.
    if name:find("ESOArabic", 1, true) then return end
    local parent = c:GetParent()
    if parent and ((parent.name == c and parent.value) or (parent.nameLabel == c and parent.valueLabel)) then
        statsRow(parent); return
    end
    R.Metrics.discovered = R.Metrics.discovered + 1
    -- GetWidth on a natural-width title is its current text extent, not an
    -- available text box. Feeding that extent back as a wrap limit continually
    -- shrinks the label and splits short headings into individual glyphs.
    R.BindLabel(c, name:match("Data[1-4]Header$") and headerOptions or discoveredOptions)
end

-- Map lists use fixed native row spacing. Bind before their setup measures text.
local function bindMapLists13()
    if not ZO_ScrollList_GetDataTypeTable then return end
    local specs = {
        {WORLD_MAP_HOUSES, 2, {"Name", "Location"}, 24},
        {WORLD_MAP_HOUSES, 1, {"Label"}, 26},
        {WORLD_MAP_ANTIQUITIES_KEYBOARD, 2, {"Label"}, 26},
        {WORLD_MAP_LOCATIONS, 1, {"Location"}, 22},
        {WORLD_MAP_ANTIQUITIES_KEYBOARD, 1, {"Name"}, 26},
    }
    for _, spec in ipairs(specs) do
        local owner, id, names, height = unpack(spec)
        if owner and owner.list then
            local dt = ZO_ScrollList_GetDataTypeTable(owner.list, id)
            if dt and not dt.esoArabicMap13 then
                dt.esoArabicMap13 = true
                local original = dt.setupCallback
                dt.setupCallback = function(row, data, ...)
                    for _, name in ipairs(names) do
                        local c = (name == "Name" and row.nameLabel) or child(row, name)
                        if c then
                            R.BindLabel(c, function(label)
                                -- Measure against the fixed row, never the auto-sized text itself.
                                -- Otherwise shrinking changes the next available width.
                                local width = math.max(120, row:GetWidth() - 24)
                                return {single = true, flow = false, width = width,
                                    size = height - 2, minimum = 14, height = height,
                                    reflowVisual = true, align = TEXT_ALIGN_RIGHT}
                            end)
                        end
                    end
                    local result = original(row, data, ...)
                    if R.IsActive() and row.progressIconMetaPool and row.nameLabel then
                        local icons = {}
                        for _, icon in pairs(row.progressIconMetaPool:GetActiveObjects()) do icons[#icons+1]=icon end
                        table.sort(icons,function(a,b)return a:GetLeft()<b:GetLeft() end)
                        local previous
                        for _, icon in ipairs(icons) do
                            icon:ClearAnchors()
                            if previous then icon:SetAnchor(TOPRIGHT,previous,TOPLEFT,-2,0)
                            else icon:SetAnchor(TOPRIGHT,row.nameLabel,BOTTOMRIGHT,0,2) end
                            previous=icon
                        end
                    end
                    return result
                end
            end
        end
    end
end


-- Keep collection announcement artwork adjacent to the Arabic caption.
local function collectionIcon15(self)
    local label, icon = self.smallCombinedText, self.smallCombinedIcon
    if not R.IsActive() or not label or not icon or icon:IsHidden() or not R.HasArabic(label:GetText()) then return end
    local refresh = R.BindLabel(label, {single=true, flow=false, width=math.max(120,label:GetWidth()-80), size=IsInGamepadPreferredMode() and 36 or 26, minimum=20, reflowVisual=true, align=TEXT_ALIGN_RIGHT})
    if refresh then refresh() end
    icon:ClearAnchors()
    icon:SetAnchor(LEFT,label,RIGHT,10,0)
end
local function mapQuest15(self, row)
    if not row or not R.IsActive() then return end
    local label, icon = child(row,"Name"), child(row,"AssistedIcon")
    if not label then return end
    label:ClearAnchors()
    label:SetAnchor(TOPRIGHT,row,TOPRIGHT,-28,0)
    local refresh=R.BindLabel(label,{width=math.max(120,row:GetWidth()-28),size=22,minimum=18,flow=true,reflowVisual=true,align=TEXT_ALIGN_RIGHT})
    if refresh then refresh() end
    if icon then icon:ClearAnchors();icon:SetAnchor(TOPRIGHT,row,TOPRIGHT,0,0) end
    row:SetHeight(math.max(24,label:GetTextHeight()))
end

-- Preserve semantic effect rows before gamepad tooltip reflow joins visual lines.
-- This getter is shared by keyboard and controller difficulty views.
local function installDifficultySpacing()
    if R.difficultySpacingInstalled or type(GetOverlandDifficultyEffects) ~= "function" then return end
    R.difficultySpacingInstalled = true
    local original = GetOverlandDifficultyEffects
    GetOverlandDifficultyEffects = function(...)
        local text = original(...)
        if not R.IsActive() or not R.HasArabic(text) then return text end
        return (text:gsub("\r\n", "\n"):gsub("\n+", "\n\n"))
    end
end

-- Keyboard-only difficulty panel: native background ends before the effects.
local function keyboardDifficultyLayout(self)
    if not R.IsActive() or IsInGamepadPreferredMode() then return end
    local panel, label = self.control, self.difficultyEffectsLabel
    if not panel or not label then return end
    local width = math.max(100, panel:GetWidth() - 64)
    label:ClearAnchors()
    label:SetAnchor(TOPRIGHT, panel:GetNamedChild("MainSectionDivider"), BOTTOMRIGHT, -32, 8)
    label:SetWidth(width)
    local refresh = R.BindLabel(label, {width=width, size=22, minimum=22,
        flow=true, unlimited=true, reflowVisual=false, align=TEXT_ALIGN_RIGHT})
    local text = GetOverlandDifficultyEffects(self.pendingDifficulty)
    -- Compact keyboard rows; retain one blank line between penalties and bonuses.
    local lines, previousRed = {}, false
    for line in text:gmatch("[^\r\n]+") do
        local lower = line:lower()
        if previousRed and lower:find("|c2adc22",1,true) then lines[#lines+1] = "" end
        lines[#lines+1] = line
        previousRed = lower:find("|cff1919",1,true) ~= nil
    end
    label:SetText(table.concat(lines,"\n"))
    if refresh then refresh() end
    local bg = panel:GetNamedChild("BG")
    if bg then
        bg:ClearAnchors()
        bg:SetAnchor(TOPLEFT,panel,TOPLEFT,0,0)
        bg:SetAnchor(BOTTOMRIGHT,label,BOTTOMRIGHT,32,24)
    end
end

function R.InstallLayouts()
    hook(ZO_ChallengeDifficultyScreen_Keyboard,"RefreshText",nil,keyboardDifficultyLayout)
    if ZO_CHALLENGE_DIFFICULTY_KEYBOARD then keyboardDifficultyLayout(ZO_CHALLENGE_DIFFICULTY_KEYBOARD) end
    installDifficultySpacing()
    hook(ZO_CenterScreenAnnouncementLargeLine,"SetIcon",nil,collectionIcon15)
    hook(ZO_CenterScreenAnnouncementLargeLine,"ApplyPlatformStyle",nil,collectionIcon15)
    hook(ZO_CenterScreenAnnouncementLargeLine,"SetSmallCombinedText",nil,collectionIcon15)
    hook(WORLD_MAP_QUESTS,"SetupQuestHeader",nil,mapQuest15)
    bindMapLists13()
    hook(ZO_MapHouses_Keyboard, "RefreshHouseList", bindMapLists13)
    hook(ZO_MapAntiquities_Keyboard, "RefreshList", bindMapLists13)
    hook(WORLD_MAP_LOCATIONS, "UpdateSelectedMap", bindMapLists13)
    -- Both chat systems share TextEntry, but maintain their own controls.
    local function alignEntry(entry)
        if not R.IsActive() then return end
        local label, bg, control = entry.channelLabel, entry.editBg, entry.control
        if not label or not bg or not control then return end
        label:ClearAnchors()
        label:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
        label:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        bg:ClearAnchors()
        bg:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        bg:SetAnchor(TOPRIGHT, label, TOPLEFT, -8, 0)
    end
    for _, system in pairs({KEYBOARD_CHAT_SYSTEM, GAMEPAD_CHAT_SYSTEM}) do
        local entry = system and system.textEntry
        if entry and not entry.esoArabicRightEntry then
            entry.esoArabicRightEntry = true
            local original = entry.SetChannel
            entry.SetChannel = function(self, ...)
                local changed = original(self, ...)
                alignEntry(self)
                return changed
            end
            alignEntry(entry)
        end
    end

    local function fitCompanionName(self)
        if self.unitTag ~= "companion" or not R.IsActive() then return end
        local label = self.nameLabel
        if not label or not R.HasArabic(label:GetText()) then return end
        -- Frame instances have generated names; identify the unit, not its
        -- virtual template name. Keep the caption inside the health bar edges.
        local refresh = R.BindLabel(label, function(c)
            c:ClearAnchors()
            local gp = IsInGamepadPreferredMode()
            local bar = self.healthBar and self.healthBar.barControls and self.healthBar.barControls[1]
            local width = gp and 306 or 170
            if bar and bar:GetWidth() > 0 then
                width = math.max(40, bar:GetWidth() - 4)
                c:SetDimensionConstraints(0, 0, 0, 0)
                c:SetAnchor(BOTTOMRIGHT, bar, TOPRIGHT, -2, -4)
            else
                c:SetAnchor(TOPLEFT, self.frame, TOPLEFT, gp and 0 or 35, gp and 1 or 19)
            end
            c:SetWidth(width)
            c:SetMaxLineCount(1)
            return {single = true, autoWidth = false, width = width, height = gp and 32 or 22,
                size = gp and 26 or 18, minimum = 12, align = TEXT_ALIGN_RIGHT}
        end)
        if refresh then refresh() end
    end
    hook(ZO_UnitFrameObject, "ApplyVisualStyle", nil, fitCompanionName)
    hook(ZO_UnitFrameObject, "UpdateName", nil, fitCompanionName)
    hook(ZO_UnitFrameObject, "SetTextIndented", nil, fitCompanionName)
    local function refreshRaceClass(self)
        if not R.IsActive() or IsInGamepadPreferredMode() then return end
        local section = child(self.control, "TitleSection")
        local label = child(section, "RaceClass")
        local name = child(section, "Name")
        if not label or not name then return end
        label:SetText(zo_strformat("<<2>> — <<1>>", GetUnitRace("player"), GetUnitClass("player")))
        R.BindLabel(label, function()
            return {single = true, autoWidth = false, width = math.max(100, name:GetWidth()),
                size = 18, minimum = 12, align = TEXT_ALIGN_RIGHT}
        end)
    end
    hook(ZO_Stats, "RefreshTitleSection", nil, refreshRaceClass)
    if STATS then refreshRaceClass(STATS) end
    -- Use the original seconds, never parse already-localized unit strings.
    -- This formatter is shared by journal rows and Lua antiquity tooltips.
    if type(ZO_FormatAntiquityLeadTime) == "function" and not R.antiquityTimeHook then
        R.antiquityTimeHook = true
        local original = ZO_FormatAntiquityLeadTime
        ZO_FormatAntiquityLeadTime = function(seconds, ...)
            if R.IsActive() then return R.FormatDuration(seconds, 2) end
            return original(seconds, ...)
        end
    end
    hook(ZO_BattlegroundLeaderboardsManager_Keyboard, "RefreshHeaderTimer", nil, function(self)
        if not R.IsActive() or IsInGamepadPreferredMode() or not self.selectedSubType then return end
        local closes, opens = GetBattlegroundLeaderboardsSchedule(self.selectedSubType)
        local seconds = closes > 0 and closes or opens
        if seconds > 0 then
            self.timerLabel:SetText(zo_strformat(closes > 0 and SI_LEADERBOARDS_CLOSES_IN_TIMER
                or SI_LEADERBOARDS_REOPENS_IN_TIMER, R.FormatDuration(seconds, 2)))
        end
    end)
    if LORE_LIBRARY_SCENE and not R.journalLoreHook then
        R.journalLoreHook = true
        LORE_LIBRARY_SCENE:RegisterCallback("StateChange", function(_, state)
            if state ~= SCENE_SHOWING or not R.IsActive() then return end
            local search = _G.Lorebook_Research
            local label = child(search, "SearchLabel")
            if label then
                label:SetText(R.ShapeLogical("البحث في المكتبة:"))
                R.BindLabel(label, {single = true, width = 270, size = 18, minimum = 14, align = TEXT_ALIGN_RIGHT})
            end
            local box = child(search, "Box")
            if box then box:SetDefaultText(R.ShapeLogical("اسم الكتاب")) end
            local checkbox = LORE_LIBRARY and child(LORE_LIBRARY.totalCollectedLabel, "IncludeMotifs")
            if checkbox then ZO_CheckButton_SetLabelText(checkbox, R.ShapeLogical("تضمين الأنماط")) end
        end)
    end
    hook(_G, "ZO_GamepadGenericHeader_RefreshData", bindHeader, bindHeader)
    hook(ZO_Interaction, "OnScreenResized", nil, keyboardPanel)
    hook(ZO_Interaction, "AnchorBottomBG", nil, keyboardPanel)
    hook(ZO_Interaction, "ResetInteraction", bindKeyboard)
    hook(ZO_Interaction, "PopulateChatterOption", bindKeyboard)
    hook(ZO_GamepadInteraction, "ResetInteraction", bindGamepad)
    hook(ZO_GamepadInteraction, "FinalizeChatterOptions", bindGamepad)
    if INTERACTION then bindKeyboard(INTERACTION) end
    if GAMEPAD_INTERACTION then bindGamepad(GAMEPAD_INTERACTION) end
    local function subtitleOptions(c)
        local gp = IsInGamepadPreferredMode()
        return {flow = true, unlimited = true, reflowVisual = true,
            width = c:GetWidth(), size = gp and 30 or 26, minimum = 22,
            face = REGULAR, align = TEXT_ALIGN_CENTER}
    end
    local function bindSubtitle(self)
        local refresh = R.BindLabel(self.messageText, subtitleOptions)
        if refresh then refresh() end
    end
    local sub = ZO_SUBTITLE_MANAGER
    if sub then bindSubtitle(sub) end
    hook(ZO_SubtitleManager, "UpdatePlatformStyles", nil, bindSubtitle)
    hook(ZO_SubtitleManager, "OnShowSubtitle", bindSubtitle, function(self, messageType, speaker, message)
        if not R.IsActive() or not (R.HasArabic(message) or R.HasArabic(speaker)) then return end
        -- Preserve ESO's repeated-speaker suppression, timing and name color.
        -- Visual RTL text puts the speaker on the right, before the dialogue.
        local previous = self.previousSubtitle
        local showSpeaker = not (previous and previous:GetSpeakerName() == speaker
            and previous:GetStartTime() + previous:GetDisplayLength() + 5 >= GetFrameTimeSeconds())
        local text = R.JoinVisualLines(R.Prepare(message))
        if showSpeaker then
            text = "|cffffff" .. text .. "|r :" .. R.Prepare(zo_strformat("<<t:1>>", speaker))
        end
        self.messageText:SetText(text)
        self.messageBackground:SetWidth(self.messageText:GetTextWidth())
    end)
    -- DLC panels combine an auto-width heading and a native baseline anchor.
    -- Give both columns explicit widths before wrapping the quest description.
    hook(ZO_GamepadCollectionsBook, "RefreshDLCTooltip", nil, function(self, collectibleData)
        if not R.IsActive() then return end
        local panel = self.infoPanelControl
        if not panel then return end
        local title = panel.nameControl
        local container = title and title:GetParent()
        if not container then return end
        local width = container:GetWidth()
        if width <= 0 then return end
        for _, item in ipairs({{title, 30}, {panel.descriptionControl, 26},
            {panel.questAcceptDescription, 26}, {panel.questAcceptIndicator, 24}}) do
            local c = item[1]
            if c then
                c:SetWidth(width)
                local refresh = R.BindLabel(c, {width = width, autoWidth = false,
                    flow = true, unlimited = true, reflowVisual = true,
                    size = item[2], minimum = 22, align = TEXT_ALIGN_RIGHT})
                if refresh then refresh() end
            end
        end
        local header = child(container, "QuestStatusHeader")
        local value = panel.questStatusControl
        if header and value then
            local state = collectibleData:GetCollectibleAssociatedQuestState()
            local accepted = state == COLLECTIBLE_ASSOCIATED_QUEST_STATE_ACCEPTED or state == COLLECTIBLE_ASSOCIATED_QUEST_STATE_COMPLETED
            value:SetText(zo_strformat("(<<2>>) <<1>>", collectibleData:GetQuestName(),
                GetString(accepted and SI_DLC_BOOK_QUEST_STATUS_ACCEPTED or SI_DLC_BOOK_QUEST_STATUS_NOT_ACCEPTED)))
            header:ClearAnchors()
            header:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 8)
            header:SetWidth(90)
            value:ClearAnchors()
            value:SetAnchor(TOPRIGHT, header, TOPLEFT, -10, 0)
            value:SetWidth(math.max(100, width - 100))
            local refresh = R.BindLabel(value, {width = math.max(100, width - 100),
                single = true, size = 24, minimum = 18, reflowVisual = true})
            if refresh then refresh() end
            local scroll = child(container, "ScrollSection")
            if scroll then
                scroll:ClearAnchors()
                scroll:SetAnchor(TOPLEFT, container, TOPLEFT, 0, title:GetBottom() - container:GetTop() + 70)
                scroll:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
            end
        end
    end)
    for _, screen in ipairs({LoadingScreen, GamepadLoadingScreen}) do
        if screen and screen.zoneDescription then
            R.BindLabel(screen.zoneDescription, {flow = true, size = 30, face = REGULAR, align = TEXT_ALIGN_RIGHT})
        end
    end
    hook(LoadingScreen_Base, "SetZoneDescription", function(self)
        R.BindLabel(self.zoneDescription, {flow = true, size = 30, face = REGULAR, align = TEXT_ALIGN_RIGHT})
    end)
    hook(ZO_StatEntry_Keyboard, "UpdateStatValue", nil, function(self) statsRow(self.control) end)
    hook(ZO_StatEntry_Keyboard, "ShowComparisonValue", nil, function(self) statsRow(self.control) end)
    if STATS and STATS.statEntries then
        for _, entry in pairs(STATS.statEntries) do statsRow(entry.control) end
    end
    -- All parametric gamepad list items are measured just after this function.
    hook(ZO_ParametricScrollList, "RunSetupOnControl", nil, function(self, control)
        if not R.IsActive() then return end
        local function visit(c, depth)
            if not c or depth > 3 then return end
            if c:GetType() == CT_LABEL then
                if not bound[c] and not R.IsManaged(c) and R.HasArabic(c:GetText()) then
                    R.BindLabel(c, function(label)
                        local opts = discoveredOptions(label)
                        opts.size, opts.minimum = 28, 20
                        return opts
                    end)
                elseif bound[c] then bound[c].refresh() end
            end
            for i = 1, c:GetNumChildren() do visit(c:GetChild(i), depth + 1) end
        end
        visit(control, 0)
    end)
    if R.InstallGamepadLayouts then R.InstallGamepadLayouts() end
end

-- Timed activity labels retain native vertical anchors and update handlers.
local challengeAlignmentInstalled = false
function R.InstallChallengeAlignment()
    if challengeAlignmentInstalled or not SecurePostHook or not ZO_TimedActivities_Shared then return end
    challengeAlignmentInstalled = true
    SecurePostHook(ZO_TimedActivities_Shared, "RefreshTimeRemaining", function(_, label)
        if not R.IsActive() or not label or label:IsHidden() then return end
        local parent = label:GetParent()
        local name = parent and parent:GetNamedChild("Name")
        local title = parent and parent:GetNamedChild("Title")
        local reference = IsInGamepadPreferredMode() and name or title
        if not reference then return end
        -- Set width without moving the left anchor: the controller claim row
        -- depends on that anchor. Right alignment then follows the title edge.
        local width = reference:GetWidth()
        if width and width > 0 then
            label:SetWidth(width)
            label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
    end)
    if ZO_TimedActivitiesList_Gamepad then
        SecurePostHook(ZO_TimedActivitiesList_Gamepad, "RefreshTimeRemaining", function(self)
            if not R.IsActive() then return end
            local header, value = self.timeRemainingHeaderLabel, self.timeRemainingLabel
            if not header or not value then return end
            header:ClearAnchors()
            header:SetAnchor(BOTTOMRIGHT, self.control, TOPRIGHT, -40, 100)
            value:ClearAnchors()
            value:SetAnchor(BOTTOMRIGHT, header, BOTTOMLEFT, -16, 0)
        end)
    end
end

-- BEGIN REVIEWED SEASON ADAPTERS
do
local seasonNames = {
    {"<<1[ﺮﺼﻨﻋ/ﺮﺻﺎﻨﻋ]>> <<F:1>> ﻕﺮﺳﺍ", "اسرق <<F:1>> <<1[عنصر/عناصر]>>"},
    {"<<1[ﺔﻤﻬﻣ/ﻡﺎﻬﻣ]>> <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> <<1[مهمة/مهام]>>"},
    {"ﻲﻣﻮﻴﻟﺍ ﻝﻮﺧﺪﻟﺍ ﻞﻴﺠﺴﺗ", "تسجيل الدخول اليومي"},
    {"<<1[ﻲﻧﻭﺭ ﺮﺠﺣ/ﺔﻴﻧﻭﺭ ﺭﺎﺠﺣﺃ]>> <<1>> ﻦﻣ ﺩﺭﺍﻮﻤﻟﺍ ﻊﻤﺟﺍ", "اجمع الموارد من <<1>> <<1[حجر روني/أحجار رونية]>>"},
    {"|t32:32:EsoUI/Art/Icons/mapKey/mapKey_groupInstance.dds|t ﺔﻴﻋﺎﻤﺟ <<1[ﺔﻧﺍﺰﻧﺯ/ﺕﺎﻧﺍﺰﻧﺯ]>> <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> <<1[زنزانة جماعية/زنزانات جماعية]>> |t32:32:EsoUI/Art/Icons/mapKey/mapKey_groupInstance.dds|t"},
    {"<<1[ﺔﻴﻜﻴﻣﺎﻨﻳﺩ ﺔﻬﺟﺍﻮﻣ/ﺔﻴﻜﻴﻣﺎﻨﻳﺩ ﺕﺎﻬﺟﺍﻮﻣ]>> ﻭﺃ <<1[ﺡﺎﻴﺘﺟﺍ/ﺕﺎﺣﺎﻴﺘﺟﺍ]>> <<F:1>> ﻞﻤﻛﺃ", "أكمل <<F:1>> <<1[اجتياح/اجتياحات]>> أو <<1[مواجهة ديناميكية/مواجهات ديناميكية]>>"},
    {"ﺔﻴﻓﺮﺣ ﺓﺭﺎﻬﻣ ﻱﺃ ﻡﺍﺪﺨﺘﺳﺎﺑ <<1[ﺮﺼﻨﻋ/ﺮﺻﺎﻨﻋ]>> <<1>> ﻊﻨﺻﺍ", "اصنع <<1>> <<1[عنصر/عناصر]>> باستخدام أي مهارة حرفية"},
    {"ﺕﺎﺑﺎﻘﻨﻠﻟ ﺔﻴﻣﻮﻳ <<1[ﺔﻤﻬﻣ/ﻡﺎﻬﻣ]>> <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> <<1[مهمة يومية/مهام يومية]>> للنقابات"},
    {"|t32:32:EsoUI/Art/Icons/mapKey/mapKey_dynamic_world_event.dds|t ﺔﻴﻜﻴﻣﺎﻨﻳﺩ <<1[ﺔﻬﺟﺍﻮﻣ/ﺕﺎﻬﺟﺍﻮﻣ]>> <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> <<1[مواجهة ديناميكية/مواجهات ديناميكية]>> |t32:32:EsoUI/Art/Icons/mapKey/mapKey_dynamic_world_event.dds|t"},
    {"|t32:32:EsoUI/Art/Icons/mapKey/mapKey_portal.dds|t ﺡﻮﺘﻔﻤﻟﺍ ﻢﻟﺎﻌﻟﺍ ﻲﻓ <<1[ﺡﺎﻴﺘﺟﺍ/ﺕﺎﺣﺎﻴﺘﺟﺍ]>> <<1>> ـﻝ ﺪَّﺼﺗ", "تصدَّ لـ <<1>> <<1[اجتياح/اجتياحات]>> في العالم المفتوح |t32:32:EsoUI/Art/Icons/mapKey/mapKey_portal.dds|t"},
    {"ﺐﻫﺫ ﺔﻌﻄﻗ <<1>> ﻞﺑﺎﻘﻣ ﺕﺎﻗﻭﺮﺴﻤﻟﺍ ﻊﺑِ", "بِع المسروقات مقابل <<1>> قطعة ذهب"},
    {"ﺭﺍﺮﺣﺍ ﻦﻴﺋﺍﺪّﻌﻟﺍ ﺪﻳﺮﺒﻟ <<1[ﺔﻣﺪﺧ ﺔﻤﻬﻣ/ﺔﻣﺪﺧ ﻡﺎﻬﻣ]>> <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> <<1[مهمة خدمة/مهام خدمة]>> لبريد العدّائين الأحرار"},
    {"ﺔﺒﻴﺠﻌﻟﺍ ﻥﺎﻜﻣﻟﺍ ﺢﻴﺗﺎﻔﻣ ﻦﻣ <<F:1>> ﻊﻤﺟﺍ", "اجمع <<F:1>> من مفاتيح اللامكان العجيبة"},
    {"ﺎﻬﺟﺭﺎﺧﻭ ﺍﺮﺒﻣﻮﻨﻴﻠﻏ ﻲﻓ ﺔﻴﻋﺎﻤﺟ <<1[ﺔﻧﺍﺰﻧﺯ/ﺕﺎﻧﺍﺰﻧﺯ]>> <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> <<1[زنزانة جماعية/زنزانات جماعية]>> في غلينومبرا وخارجها"},
    {"ﺹﻮﺼﻠﻟﺍ ﺔﺑﺎﻘﻧ ﻲﻓ ﺩﺍﺩﺮﺘﺳﺍ ﺔﺣﻮﻟ ﻦﻣ <<1[ﺔﻤﻬﻣ/ﻡﺎﻬﻣ]>> <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> <<1[مهمة/مهام]>> من لوحة الاسترداد في نقابة اللصوص"},
    {"<<1[ﺔﻧﺰﺧ/ﻦﺋﺍﺰﺧ]>> <<1>> ﺐﻬﻧﺍ", "انهب <<1>> <<1[خزنة/خزائن]>>"},
    {"ﺭﺎﺤﺒﻟﺍ ﻲﻟﺎﻋﺃ ﺔﻴﻟﺎﻌﻓ ﺀﺎﻨﺛﺃ ﻲﺴﻴﺑﺃ ﺮﺤﺑ ﻲﻓ <<1[ﻭﺪﻋ/ﺀﺍﺪﻋﺃ]>> <<F:1>> ﻞﺘﻗﺍ", "اقتل <<F:1>> <<1[عدو/أعداء]>> في بحر أبيسي أثناء فعالية أعالي البحار"},
    {"<<1[ﺔﻋﺎﺷﺇ/ﺕﺎﻋﺎﺷﺇ]>> <<1>> ﻲﻓ ﻖﻴﻘﺤﺘﻟﺍ ﻞﻤﻛﺃ", "أكمل التحقيق في <<1>> <<1[إشاعة/إشاعات]>>"},
    {"ﻝﻮﻓﺮﺟﺍﺩ ﺹﻮﺼﻟ ﺔﺑﺎﻘﻨﻟ <<1[ﺔﻤﻬﻣ/ﻡﺎﻬﻣ]>> <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> <<1[مهمة/مهام]>> لنقابة لصوص داجرفول"},
    {"ﺙﺍﺭﻮﻏﻮﻴﺸﻟ <<1[ﺔﻤﻬﻣ/ﻡﺎﻬﻣ]>> <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> <<1[مهمة/مهام]>> لشيوغوراث"},
    {"ﺹﻮﺼﻠﻟﺍ ﺔﺑﺎﻘﻧ ﻝﺰﻨﻣ ﻦﻣ <<1[ﺀﺰﺟ/ﺀﺍﺰﺟﺃ]>> <<1>> ﻰﻠﻋ ﺮﺜﻋﺍ", "اعثر على <<1>> <<1[جزء/أجزاء]>> من منزل نقابة اللصوص"},
    {"ﻒﺠﺗﺮﻤﻟﺍ ﺥﻮﻜﻟﺍ ﻲﻓ ﺙﻮﻧ ﻰﻟﺇ ﺙﺪﺤﺗ", "تحدث إلى نوث في الكوخ المرتجف"},
    {"ﺙﺍﺭﻮﻏﻮﻴﺷ ﻉِﺪﺘﺳﺍ", "استدعِ شيوغوراث"},
    {"ﻰﺗﻮﻤﻟﺍ ﺔﻋﺎﻗ ﻲﻓ <<1[ﻱﺭﺪﻳﺩ ﺫﺮﺟ/ﺔﻳﺭﺪﻳﺩ ﻥﺍﺫﺮﺟ]>> <<1>> ﻞﺘﻗﺍ", "اقتل <<1>> <<1[جرذ ديدري/جرذان ديدرية]>> في قاعة الموتى"},
    {"<<1[ﻕﻤﻋ ﻱﺭﺪﻳﺩ ﺫﺮﺟ/ﺔﻗﻤﻋ ﺔﻳﺭﺪﻳﺩ ﻥﺍﺫﺮﺟ]>> <<1>> ﻞﺘﻗﺍ", "اقتل <<1>> <<1[جرذ ديدري عملاق/جرذان ديدرية عملاقة]>>"},
    {"ﺖﺳﺮﻳﺍﻭ ﻕﻮﺳ ﻒﺸﻜﺘﺳﺍ", "استكشف سوق وايرست"},
    {"ﻦﻓﺎﻬﻣﺭﻮﺘﺳ ﻲﻓ <<1[ﺐﻫﺎﻧ/ﻦﻴﺒﻫﺎﻧ]>> <<1>> ﻞﺘﻗﺍ", "اقتل <<1>> <<1[ناهب/ناهبين]>> في ستورمهافن"},
    {"ﺐﻬﻨﻟﺍ ﻚﻠﻣ ﻦﻳﺮﻟﺪﻧﺇ ﺏﻮﺠﺘﺳﺍ", "استجوب إندلرين ملك النهب"},
    {"ﻝﺩﺎﻨﻟﺍﻭ ﺔﻧﺎﺤﻟﺍ ﺐﺣﺎﺻ ﻰﻟﺇ ﺙﺪﺤﺗ", "تحدث إلى صاحب الحانة والنادل"},
    {"ﻙﻮﺛﻭﺃ ﺄﺒﺨﻣ ﻲﻓ ﻖﻘﺣ", "حقق في مخبأ أوثوك"},
    {"ﻞﻴﺸﻣﻮﺗ ﻪﻛﺮﺗ ﻱﺬﻟﺍ ﻥﻮﻨﺠﻟﺍ ﺏﺭﺩ ﻊﺒﺗﺍ", "اتبع درب الجنون الذي تركه تومشيل"},
    {"ﻲﻛﺍﺯ ﻡﺰﻫﺍ", "اهزم لازاكي"},
    {"ﺙﺍﺭﻮﻏﻮﻴﺷ ﺎﺼﻋ ﺪﻌﺘﺳﺍ", "استعد عصا شيوغوراث"},
    {"ﺙﺍﺭﻮﻏﻮﻴﺷ ﺓﻮﻗ ﺕﺍﺭﺬﺷ ﺺﺘﻣﺍ", "امتص شذرات قوة شيوغوراث"},
    {"ﻥﺎﻜﻣﻟﺍ ﻮﺒﻗ ﻲﻓ <<1[ﺔﻓﺮﻏ/ﻑﺮﻏ]>> <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> <<1[غرفة/غرف]>> في قبو اللامكان"},
    {"<<1[ﻱﺮﺛﺃ ﻞﻴﻟﺩ/ﺔﻳﺮﺛﺃ ﺔﻟﺩﺃ]>> <<1>> ﻰﻠﻋ ﻞﺼﺣﺍ", "احصل على <<1>> <<1[دليل أثري/أدلة أثرية]>>"},
    {"ﺐﻴﻘﻨﺗ ﻊﻗﻮﻣ ﻦﻣ <<1[ﺔﻴﻓﺎﺿﺍ ﻢﺋﺎﻨﻐﻟﺍ]>> ﻦﻣ <<1>> ﻰﻠﻋ ﻞﺼﺣﺍ", "احصل على <<1>> من <<1[الغنائم الإضافية]>> من موقع تنقيب"},
    {"ﺩﻮﺘﻴﻟﻮﺳ ﻲﻓ »ﻦﻴﻳﺮﺛﺍ ﺔﻘﻠﺣ« ﺔﻤﻬﻣ ﻞﻤﻛﺃ", "أكمل مهمة «حلقة الأثريين» في سوليتود"},
    {"<<1[ﺭﺎﺛﺍ ﺔﻋﻮﺳﻮﻣ ﺕﺠﺳ]>> ﻦﻣ <<1>> ﻲﻓ ﺎﻣًﺪﻘﺗ ﺯﺮﺣﺃ", "أحرز تقدمًا في <<1>> من <<1[سجلات موسوعة الآثار]>>"},
    {"<<1[ﺓﺮﻣ/ﺕﺍﺮﻣ]>> <<1>> ﻱﺮﺛﺍ ﻦﻴﻋ ﻡﺪﺨﺘﺳﺍ", "استخدم عين الأثري <<1>> <<1[مرة/مرات]>>"},
    {"ﺭﺎﺤﺒﻟﺍ ﻲﻟﺎﻋﺃ ﻰﻟﺇ <<1[ﺔﻠﺣﺭ/ﺕﺣﺭ]>> <<1>> ﻲﻓ ﺮﺤﺒﻟﺍ ﺖﺤﺗ ﺰﻨﻜﻟﺍ ﻰﻠﻋ ﻞﺼﺣﺍ", "احصل على الكنز تحت البحر في <<1>> <<1[رحلة/رحلات]>> إلى أعالي البحار"},
    {"»ﺲﻳﺭﺪﻳﺭ ﺲﺗﻮﻳﺍﺭ ﻊﻓﺭ« ﺔﻤﻬﻣ ﻞﻤﻛﺃ", "أكمل مهمة «رفع رايوتس ريدريس»"},
    {"<<1[ﺓﺮﻣ/ﺕﺍﺮﻣ]>> <<1>> ﻲﺴﻴﺑﺃ ﺮﺤﺑ ﻲﻓ ﺔﺤﻟﺎﻤﻟﺍ ﻩﺎﻴﻤﻟﺎﺑ ﺪﻴﺼﻟﺍ ﻖﻃﺎﻨﻣ ﻦﻣ ﺪﻄﺻﺍ", "اصطد من مناطق الصيد بالمياه المالحة في بحر أبيسي <<1>> <<1[مرة/مرات]>>"},
    {"<<1[ﻞﻤﻘﻟﺍ ﻲﺴﻣﺎﻫ ﻞﻄﺑ/ﻞﻤﻘﻟﺍ ﻲﺴﻣﺎﻫ ﻝﺎﻄﺑﺃ]>> <<1>> ﻡﺰﻫﺍ", "اهزم <<1>> <<1[بطل هامسي القمل/أبطال هامسي القمل]>>"},
    {"<<1[ﺓﺮﻐﺛ/ﺕﺍﺮﻐﺛ]>> <<1>> ﺢﻠﺻﺃ", "أصلح <<1>> <<1[ثغرة/ثغرات]>>"},
    {"<<1[ﺓﺮﻣ/ﺕﺍﺮﻣ]>> <<1>> ﺭﺎﺼﺤﻟﺍ ﺔﺤﻠﺳﺃ ﻖﻠﻃﺃ", "أطلق أسلحة الحصار <<1>> <<1[مرة/مرات]>>"},
    {"ﺔﻳﺩﺎﻌﻣ ﺔﻨﻴﻔﺳ ﻕﺮﻏﺃ", "أغرق سفينة معادية"},
    {"ﺔﻳﺮﻤﻳﻭﺪﻟﺍ ﺹﻮﻐﻟﺍ ﺓﺮﺠﺣ ﻡﺍﺪﺨﺘﺳﺎﺑ ﻲﺴﻴﺑﺃ ﺮﺤﺑ ﻕﺎﻤﻋﺃ ﻒﺸﻜﺘﺳﺍ", "استكشف أعماق بحر أبيسي باستخدام حجرة الغوص الدويمرية"},
    {"ﺔﺑﺮﺤﻟﺎﺑ ﺍﻭًﺪﻋ ﺐﺻﺃ", "أصب عدوًا بالحربة"},
    {"<<1[ﺓﺮﻣ/ﺕﺍﺮﻣ]>> <<1>> ﻖﺋﺎﻋ ﺔﻟﺍﺯ ﺔﺑﺮﺤﻟﺍ ﻡﺪﺨﺘﺳﺍ", "استخدم الحربة لإزالة عائق <<1>> <<1[مرة/مرات]>>"},
    {"<<1[ﻲﻧﺎﺟﺮﻣ ﻞﺣﻭ ﻥﺎﻃﺮﺳ/ﺔﻴﻧﺎﺟﺮﻣ ﻞﺣﻭ ﺕﺎﻧﺎﻃﺮﺳ]>> <<1>> ﻞﺘﻗﺍ", "اقتل <<1>> <<1[سرطان وحل مرجاني/سرطانات وحل مرجانية]>>"},
    {"ﻲﺴﻴﺑﺃ ﺮﺤﺑ ﻕﺎﻤﻋﺃ ﻑﺎﺸﻜﺘﺳﺍ ﺀﺎﻨﺛﺃ ﺍﺮﻏﺎﻴﻟﺍ ﻦﻣ <<1>> ﻞﺘﻗﺍ", "اقتل <<1>> من الياغرا أثناء استكشاف أعماق بحر أبيسي"},
    {"ﻉﺎﻤّﻄﻟﺍ ﺐﻠﺨﻤﻟﺍ ،ﻙﺍﺮﻐﻛﻛ ﻡﺰﻫﺍ", "اهزم كلاكغراك، المخلب الطمّاع"},
    {"ﻖﻟﺄﺘﻤﻟﺍ ﻝﺯﺎﺑﻭ ﻅﻮﻈﺤﻤﻟﺍ ﺶﺘﻳﺮﻏ ،ﺏﺎﻌﺸﻟﺍ ﻲﺳﺭﺎﺣ ﻞﺘﻗﺍ", "اقتل حارسي الشعاب، غريتش المحظوظ وبازل المتألق"},
    {"ﺭﺎﺤﺒﻟﺍ ﻲﻟﺎﻋﺃ ﺐﻋﺭ ،ﺭﺎﻤﻳﺰﻠﻳﺮﻛ ﻡﺰﻫﺍ", "اهزم كريلزيمار، رعب أعالي البحار"},
    {"<<1[ﺓﺮﻣ/ﺕﺍﺮﻣ]>> <<1>> ﺪﻴﺼﻟﺎﺑ ﻢﺋﺎﻌﻟﺍ ﻡﺎﻄﺤﻟﺍ ﻦﻣ ﺯﻮﻨﻜﻟﺍ ﻞﺸﺘﻧﺍ", "انتشل الكنوز من الحطام العائم بالصيد <<1>> <<1[مرة/مرات]>>"},
    {"ﺲﻳﺭﺪﻳﺭ ﺲﺗﻮﻳﺍﺭ ﺔﻨﻴﻔﺳ ﻰﻠﻋ ﺱﺮﺠﻟﺍ ﻉﺮﻗﺍ", "اقرع الجرس على سفينة رايوتس ريدريس"},
    {"ﻡﻋﺍ ﻊﻴﻤﺟ ﻝﻮﻄﺳﺃ ﻲﻓ ﻥﺎﻄﺒﻘﻟﺍ ﻥﻭﺭﺎﺒﻟﺍ ،ﺩﺭﺎﻣ ﻱﺎﻏ ﻦﻴﻴﺴﻟﻭﺃ ﻰﻟﺇ ﺙﺪﺤﺗ", "تحدث إلى أولسيين غاي مارد، البارون القبطان في أسطول جميع الأعلام"},
    {"ﻥﺎﻜﻣﻟﺍ ﻮﺒﻗ ﻰﻘﺘﻠﻣ ﻞﺧﺩﺍ", "ادخل ملتقى قبو اللامكان"},
    {"ﺭﺍﺮﺳﺍ ﺡﺎﻨﺟ ﻲﻓ ﻱﺪﺤﺘﻟﺍ ﻑﺮﻏ ﻦﻣ <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> من غرف التحدي في جناح الأسرار"},
    {"ﻱﺮﻤﻘﻟﺍ ﺭﺎﺴﻤﻟﺍ ﺡﺎﻨﺟ ﻲﻓ ﻱﺪﺤﺘﻟﺍ ﻑﺮﻏ ﻦﻣ <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> من غرف التحدي في جناح المسار القمري"},
    {"ﺔﻧﻮﻌﻠﻤﻟﺍ ﺔﻌﻠﻘﻟﺍ ﺡﺎﻨﺟ ﻲﻓ ﻱﺪﺤﺘﻟﺍ ﻑﺮﻏ ﻦﻣ <<1>> ﻞﻤﻛﺃ", "أكمل <<1>> من غرف التحدي في جناح القلعة الملعونة"},
    {"ﻥﺎﻜﻣﻟﺍ ﻮﺒﻗ ﻲﻓ ﺊﺑﺎﺨﻤﻟﺍ ﻑﺮﻏ ﻦﻣ <<1>> ﻞﺧﺩﺍ", "ادخل <<1>> من غرف المخابئ في قبو اللامكان"},
    {"<<1[ﻥﺎﻜﻣﻟﺍ ﻕﻭﺪﻨﺻ/ﻥﺎﻜﻣﻟﺍ ﻖﻳﺩﺎﻨﺻ]>> <<F:1>> ﺢﺘﻓﺍ", "افتح <<F:1>> <<1[صندوق اللامكان/صناديق اللامكان]>>"},
    {"ﺔﻳﺮﻄﻔﻟﺍ ﺓﻮﻬﻟﺍ ﻱﺪﺤﺗ ﺔﻓﺮﻏ ﻞﻤﻛﺃ", "أكمل غرفة تحدي الهوة الفطرية"},
    {"ﻪﻣﺰﻫﺍﻭ ﺐﻗﺍﺮﻤﻟﺍ ﺶﺣﻮﻟﺍ ﻉِﺪﺘﺳﺍ", "استدعِ الوحش المراقب واهزمه"},
    {"ﺔﻤﺘﻌﻤﻟﺍ ﺓﺭﺎﻐﻤﻟﺍ ﻱﺪﺤﺗ ﺔﻓﺮﻏ ﻦﻣ ﺞُﻧﺍ", "انجُ من غرفة تحدي المغارة المعتمة"},
    {"ﺔﻣﺎﺴﻟﺍ ﻡﺍ ﻡﺰﻫﺍ", "اهزم الأم السامة"},
    {"ﺮﻤﻘﻟﺎﺑ ﺓﺀﺎﻀﻤﻟﺍ ﺭﺰﺠﻟﺍ ﻲﻓ ﺭﻮﺴﺠﻟﺍ ﻦﻣ <<1>> ﻞﻌّﻓ", "فعّل <<1>> من الجسور في الجزر المضاءة بالقمر"},
    {"ﻖﻔﺸﻟﺍ ﺔﻫﺎﺘﻣ ﻲﻓ ﻍﺍﺮﻔﻟﺍ ﻲﻧﺎﻏﺃ ﻦﻣ <<1>> ﻞﺘﻗﺍ", "اقتل <<1>> من أغاني الفراغ في متاهة الشفق"},
    {"ﺐﺋﺎﺠﻌﻟﺍ ﺽﺮﻌﻣ ﻱﺪﺤﺗ ﺔﻓﺮﻏ ﻲﻓ ﺔﺒﻳﺮﻐﻟﺍ ﻒﺤﺘﻟﺍ ﻦﻣ <<1>> ﻰﻠﻋ ﺮﺜﻋﺍ", "اعثر على <<1>> من التحف الغريبة في غرفة تحدي معرض العجائب"},
    {"!ﺓﺎﺷﺮﻔﻟﺍ ﻉِﺪﺘﺳﺍ", "استدعِ الفرشاة!"},
    {"ﻕﺭﺎﻐﻟﺍ ﺀﺎﻨﻔﻟﺍ ﻲﻓ ﺔﻔﺻﺎﻌﻟﺍ ﺕﺍﺭﻮﻠﺑ ﻦﻣ <<1>> ﻞﻄّﻋ", "عطّل <<1>> من بلورات العاصفة في الفناء الغارق"},
    {"ﺔﻔﺻﺎﻌﻟﺍ ﻢﻃﺍﻮﻃ ﻦﻣ <<1>> ﺢﻠﺻﺃ", "أصلح <<1>> من طواطم العاصفة"},
    {"ﺀﺎﺴﺤﻟﺍ ﻲﻓ ﻞﺣﻮﻟﺍ ﺕﺎﻨﺋﺎﻛ ﻦﻣ <<1>> ﻞﺘﻗﺍ", "اقتل <<1>> من كائنات الوحل في الحساء"},
    {"ﻥﻮﻜﺴﻤﻟﺍ ﺏﺍﺩﺮﺴﻟﺍ ﻞﺧﺍﺩ ﺀﺎﺴﺤﻟﺍ ﻲﻓ ﻞﺣﻮﻟﺍ ﺕﺎﻨﺋﺎﻛ ﻦﻣ <<1>> ﻞﺘﻗﺍ", "اقتل <<1>> من كائنات الوحل في الحساء داخل السرداب المسكون"},
    {"ﺯﻮﻨﻜﻟﺍ ﻥﺰﺨﻣ ﻲﻓ <<[ﻕﻭﺪﻨﺻ/ﻖﻳﺩﺎﻨﺻ]>> <<F:1>> ﺢﺘﻓﺍ", "افتح <<F:1>> <<[صندوق/صناديق]>> في مخزن الكنوز"},
    {"ﻦﻣﺰﻟﺍ ﺔﺳﺍﺮﺣ ﻡﺎﺘﺧﺃ ﻦﻣ <<1>> ﻊﻤﺟﺍ", "اجمع <<1>> من أختام حراسة الزمن"},
    {"ﺩﺍﻮﻤﻟﺍ ﻊﻤﺟﻭ ﺺﻨﻘﻟﺍﻭ ﺪﻴﺼﻟﺎﺑ <<1[ﺩﺭﻮﻣ/ﺩﺭﺍﻮﻣ]>> <<F:1>> ﻊﻤﺟﺍ", "اجمع <<F:1>> <<1[مورد/موارد]>> بالصيد والقنص وجمع المواد"},
    {"|t32:32:EsoUI/Art/Icons/mapKey/mapKey_groupInstance.dds|t ﺔﻴﻋﺎﻤﺟ <<1[ﺔﻧﺍﺰﻧﺯ/ﺕﺎﻧﺍﺰﻧﺯ]>> <<F:1>> ﻞﻤﻛﺃ", "أكمل <<F:1>> <<1[زنزانة جماعية/زنزانات جماعية]>> |t32:32:EsoUI/Art/Icons/mapKey/mapKey_groupInstance.dds|t"},
    {"|t32:32:EsoUI/Art/Icons/mapKey/mapKey_solo_dungeon.dds|t ﺔﻳﺩﺮﻓ <<1[ﺔﻧﺍﺰﻧﺯ/ﺕﺎﻧﺍﺰﻧﺯ]>> <<F:1>> ﻞﻤﻛﺃ", "أكمل <<F:1>> <<1[زنزانة فردية/زنزانات فردية]>> |t32:32:EsoUI/Art/Icons/mapKey/mapKey_solo_dungeon.dds|t"},
    {"|t32:32:EsoUI/Art/Icons/mapKey/mapKey_raidDungeon.dds|t <<1[ﺔﻨﺤﻣ/ﻦﺤﻣ]>> <<F:1>> ﻞﻤﻛﺃ", "أكمل <<F:1>> <<1[محنة/محن]>> |t32:32:EsoUI/Art/Icons/mapKey/mapKey_raidDungeon.dds|t"},
    {"|t32:32:EsoUI/Art/Icons/mapKey/mapKey_groupBoss.dds|t ﺡﻮﺘﻔﻤﻟﺍ ﻢﻟﺎﻌﻟﺍ ﻲﻓ <<1[ﻢﻴﻋﺯ/ﺀﺎﻤﻋﺯ]>> <<F:1>> ﻞﺘﻗﺍ", "اقتل <<F:1>> <<1[زعيم/زعماء]>> في العالم المفتوح |t32:32:EsoUI/Art/Icons/mapKey/mapKey_groupBoss.dds|t"},
    {"|t32:32:EsoUI/Art/Icons/mapKey/mapKey_dungeon.dds|t ﺔﻣﺎﻌﻟﺍ ﺕﺎﻧﺍﺰﻧﺰﻟﺍ ﻲﻓ <<1[ﻢﻴﻋﺯ/ﺀﺎﻤﻋﺯ]>> <<F:1>> ﻞﺘﻗﺍ", "اقتل <<F:1>> <<1[زعيم/زعماء]>> في الزنزانات العامة |t32:32:EsoUI/Art/Icons/mapKey/mapKey_dungeon.dds|t"},
    {"ﺔﻴﻋﺎﻤﺟﻭ ﺔﻳﺩﺮﻓ <<1[ﺔﻧﺍﺰﻧﺯ/ﺕﺎﻧﺍﺰﻧﺯ]>> <<F:1>> ﻞﻤﻛﺃ", "أكمل <<F:1>> <<1[زنزانة فردية وجماعية/زنزانات فردية وجماعية]>>"},
    {"ﺕﺍﺮﺣﺎﺴﻟﺍ ﻥﺎﺟﺮﻬﻣ ﺀﺎﻨﺛﺃ <<1[ﻢﺋﺎﻨﻏ ﺔﻤﺠﻤﺟ/ﻢﺋﺎﻨﻏ ﻢﺟﺎﻤﺟ]>> <<1>> ﻰﻠﻋ ﻞﺼﺣﺍ", "احصل على <<1>> <<1[جمجمة غنائم/جماجم غنائم]>> أثناء مهرجان الساحرات"},
    {"ﺶﺘﻳﺮﻛﺑﻭ ﺶﺘﻳﺭ ﺍﺫﻭ ﻡﺮﻳﺎﻜﺳ ﺏﺮﻏ ﻲﻓ <<1[ﻭﺪﻋ/ﺀﺍﺪﻋﺃ]>> <<F:1>> ﻞﺘﻗﺍ", "اقتل <<F:1>> <<1[عدو/أعداء]>> في غرب سكايرم وذا ريتش وبلاكريتش"},
    {"ﺓﺪﻳﺪﺠﻟﺍ ﺓﺎﻴﺤﻟﺍ ﻥﺎﺟﺮﻬﻣ ﻦﻣ <<1[ﻕﻭﺪﻨﺻ/ﻖﻳﺩﺎﻨﺻ]>> <<1>> ﻰﻠﻋ ﻞﺼﺣﺍ", "احصل على <<1>> <<1[صندوق/صناديق]>> من مهرجان الحياة الجديدة"},
    {"|t32:32:EsoUI/Art/Icons/POI/POI_portal_complete.dds|t ﺮﻴﻜﻴﻟﺃ ﺀﺍﺮﺤﺻ ﻲﻓ <<1[ﺔﻤﻠﻈﻣ ﺓﺎﺳﺮﻣ/ﺔﻤﻠﻈﻣ ﻲﺳﺍﺮﻣ]>> <<F:1>> ﺮﻣّﺩ", "دمّر <<F:1>> <<1[مرساة مظلمة/مراسي مظلمة]>> في صحراء أليكير |t32:32:EsoUI/Art/Icons/POI/POI_portal_complete.dds|t"},
    {"ﺮﻴﻜﻴﻟﺃ ﺀﺍﺮﺤﺻ ﻲﻓ ﻞﻨﻴﺘﻨﺳ ﻰﻟﺇ ﺮﻓﺎﺳ", "سافر إلى سنتينل في صحراء أليكير"},
}
local seasonDuals = {
    ["عنصر"] = "عنصرين",
    ["مهمة"] = "مهمتين",
    ["حجر روني"] = "حجرين رونيين",
    ["زنزانة"] = "زنزانتين",
    ["اجتياح"] = "اجتياحين",
    ["مواجهة ديناميكية"] = "مواجهتين ديناميكيتين",
    ["مواجهة"] = "مواجهتين",
    ["مهمة خدمة"] = "مهمتي خدمة",
    ["خزنة"] = "خزنتين",
    ["عدو"] = "عدوين",
    ["إشاعة"] = "إشاعتين",
    ["جزء"] = "جزأين",
    ["جرذ ديدري"] = "جرذين ديدريين",
    ["جرذ ديدري عملاق"] = "جرذين ديدريين عملاقين",
    ["ناهب"] = "ناهبين",
    ["غرفة"] = "غرفتين",
    ["دليل أثري"] = "دليلين أثريين",
    ["مرة"] = "مرتين",
    ["رحلة"] = "رحلتين",
    ["بطل هامسي القمل"] = "بطلين من هامسي القمل",
    ["ثغرة"] = "ثغرتين",
    ["سرطان وحل مرجاني"] = "سرطاني وحل مرجانيين",
    ["صندوق اللامكان"] = "صندوقين من اللامكان",
    ["صندوق"] = "صندوقين",
    ["مورد"] = "موردين",
    ["محنة"] = "محنتين",
    ["زعيم"] = "زعيمين",
    ["جمجمة غنائم"] = "جمجمتي غنائم",
    ["مرساة مظلمة"] = "مرساتين مظلمتين",
    ["زنزانة جماعية"] = "زنزانتين جماعيتين",
    ["زنزانة فردية"] = "زنزانتين فرديتين",
    ["زنزانة فردية وجماعية"] = "زنزانتين فرديتين أو جماعيتين",
    ["مهمة يومية"] = "مهمتين يوميتين",
}
-- Exact reviewed native names only; unrelated activities retain native output.
-- No persistent cache, control-tree scanning, or global string-format override.
local accusatives = {
    ["عنصر"] = "عنصرًا", ["عدو"] = "عدوًا", ["جزء"] = "جزءًا",
    ["حجر روني"] = "حجرًا رونيًا", ["جرذ ديدري"] = "جرذًا ديدريًا",
    ["جرذ ديدري عملاق"] = "جرذًا ديدريًا عملاقًا", ["ناهب"] = "ناهبًا",
    ["دليل أثري"] = "دليلًا أثريًا", ["بطل هامسي القمل"] = "بطلًا من هامسي القمل",
    ["سرطان وحل مرجاني"] = "سرطان وحل مرجانيًا", ["صندوق اللامكان"] = "صندوقًا من اللامكان",
    ["صندوق"] = "صندوقًا", ["مورد"] = "موردًا", ["زعيم"] = "زعيمًا", ["اجتياح"] = "اجتياحًا",
}
local function counted(singular, plural, n)
    if n == 2 then return seasonDuals[singular] or singular end
    if n >= 11 then return accusatives[singular] or singular end
    return n >= 3 and n <= 10 and plural or singular
end
function R.ResolveSeasonTitle(logical, n)
    local number = tostring(n)
    local formatted = number:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    local result = logical
    local function phrase(modifier, singular, plural)
        local noun = counted(singular, plural, n)
        if n == 1 or n == 2 then return noun end
        return (modifier == 'F:' and formatted or number) .. ' ' .. noun
    end
    result = result:gsub('<<F:1>> <<1%[([^/]+)/([^%]]+)%]>>', function(a,b) return phrase('F:',a,b) end)
    result = result:gsub('<<1>> <<1%[([^/]+)/([^%]]+)%]>>', function(a,b) return phrase('',a,b) end)
    result = result:gsub('<<F:1>> <<%[([^/]+)/([^%]]+)%]>>', function(a,b) return phrase('F:',a,b) end)
    result = result:gsub('<<1%[([^/]+)/([^%]]+)%]>>', function(a,b) return counted(a,b,n) end)
    result = result:gsub('<<1%[([^%]]+)%]>>', '%1')
    result = result:gsub('<<F:1>>', formatted):gsub('<<1>>', number)
    if n == 1 then
        result = result:gsub('اقتل عدو ', 'اقتل عدوًا '):gsub('اسرق عنصر$', 'اسرق عنصرًا')
    end
    return result
end
local grammarInstalled = false
function R.InstallSeasonGrammar()
    if grammarInstalled or not ZO_TimedActivityData or not ZO_TimedActivityData.GetName then return end
    grammarInstalled = true
    local original = ZO_TimedActivityData.GetName
    -- Only sixteen target counts are retained; discarded when the UI reloads.
    local lookups, order = {}, {}
    ZO_TimedActivityData.GetName = function(self, ...)
        local native = original(self, ...)
        if not R.IsActive() then return native end
        local n = self:GetMaxProgress()
        if type(n) ~= 'number' or n < 1 or n ~= math.floor(n) then return native end
        local lookup = lookups[n]
        if not lookup then
            lookup = {}
            for _, row in ipairs(seasonNames) do
                local key = zo_strformat(row[1], n)
                local logical = R.ResolveSeasonTitle(row[2], n)
                if not logical:find('<<', 1, true) then lookup[key] = R.ShapeLogical(logical) end
            end
            if #order == 16 then lookups[table.remove(order, 1)] = nil end
            order[#order + 1], lookups[n] = n, lookup
        end
        return lookup[native] or native
    end
end

end

do
-- Source: ZO_TimedActivityTile_Keyboard.LayoutPlatform and its 720x130 template.
local seasonInstalled = false
function R.InstallSeasonLayouts()
    if seasonInstalled or not SecurePostHook or not ZO_TimedActivityTile_Keyboard then return end
    seasonInstalled = true
    SecurePostHook(ZO_TimedActivityTile_Keyboard, "LayoutPlatform", function(self)
        if not R.IsActive() or IsInGamepadPreferredMode() then return end
        local control = self.control
        if not control then return end
        local width = control:GetWidth() - 32
        if width <= 0 then return end
        local function place(label, y, height, labelWidth, alignment, size)
            if not label then return end
            label:ClearAnchors()
            label:SetAnchor(TOPLEFT, control, TOPLEFT, 16, y)
            label:SetDimensions(labelWidth, height)
            local refresh = R.BindLabel(label, {width = labelWidth, height = height,
                size = size, minimum = 14, flow = false, multiline = true,
                reflowVisual = true, align = alignment})
            if refresh then refresh() end
            label:SetHeight(height)
            label:SetMaxLineCount(height > 30 and 2 or 1)
        end
        place(self.titleLabel, 8, 44, width, TEXT_ALIGN_RIGHT, 22)
        place(self.timeRemainingLabel, 56, 22, width, TEXT_ALIGN_RIGHT, 18)
        place(self.claimedLabel, 82, 20, width * 0.65, TEXT_ALIGN_LEFT, 18)
    end)
end

end
