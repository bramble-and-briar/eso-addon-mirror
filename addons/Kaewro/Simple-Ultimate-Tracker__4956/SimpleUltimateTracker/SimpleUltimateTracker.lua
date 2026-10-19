-------------------------------------------------------------------------------
-- SimpleUltimateTracker
-- Both ultimate icons show:
--   TOP    : current/required
--   BOTTOM : percentage / missing amount
-- The icon of the OTHER bar's ultimate sits next to the current one.
-- Optional: ultimate timer with a countdown glow, ultimate gain per second or
-- time until ready, and a ready alert.
-- All texts and the ultimate skill can be unlocked and dragged anywhere.
--
-- Commands:  /sut          open the settings menu
--            /sut on       enable the tracker
--            /sut off      disable the tracker
--            /sut unlock   unlock the texts and the ultimate skill so they can be dragged
--            /sut lock     lock them again (they stay unlocked until you do)
--            /sut help     list the commands
--
-- NOTE: ESO only reports a reliable ultimate cost for the bar that is
-- currently active. So the cost of every ultimate is remembered (per
-- character) whenever it is on the active bar, and that remembered value is
-- used for the opposite bar. Until an ultimate has been active once, the
-- opposite icon uses the ability's base cost (without cost reductions).
-------------------------------------------------------------------------------
local ADDON_NAME = "SimpleUltimateTracker"
local PANEL_NAME = "SimpleUltimateTrackerPanel"

-- Ultimate action slot (slot 8 in the default UI)
local ULT_SLOT = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1

local FONT_FORMAT  = "$(BOLD_FONT)|%d|soft-shadow-thick"
local TEXT_PADDING = 3   -- pixels from the icon's top/bottom edge
local ICON_GAP     = 4   -- pixels between the ultimate button and the opposite icon
local BORDER_SIZE  = 2   -- thickness of the opposite icon's black border

-- Look of the opposite icon's picture (fixed)
local OPP_LOOK = {
    alpha         = 0.57,  -- picture alpha
    desaturation  = 0,     -- picture desaturation
    backdropAlpha = 1,     -- backdrop behind the picture
    readyGlow     = 0.25,  -- steady glow while an ultimate is ready
    flashTime     = 1400,  -- ms a ready flash lasts (3 x 2 x 220 ms, plus a little)
}

-- Choices for the settings menu
local BOTTOM_TEXT = {
    PERCENT = "Percentage",
    MISSING = "Missing amount",
    BOTH    = "Percentage and missing",
    HIDDEN  = "Hidden",
}
-- the choices of the settings menu's dropdowns
local CHOICES = {
    bottom   = { BOTTOM_TEXT.PERCENT, BOTTOM_TEXT.MISSING, BOTTOM_TEXT.BOTH, BOTTOM_TEXT.HIDDEN },
    placement = { "Automatic", "Above", "Below", "Left", "Right", "Custom" },
}
local BORDER_STYLE = {
    MATCH = "Match other skills",
    BLACK = "Black",
    ESO   = "Default ESO",
    NONE  = "None",
    esoFrameTexture = "/esoui/art/actionbar/abilityframe64_up.dds",
}
CHOICES.border        = { BORDER_STYLE.MATCH, BORDER_STYLE.ESO, BORDER_STYLE.BLACK, BORDER_STYLE.NONE }
CHOICES.timerPosition = { "Right", "Left", "Center", "Above", "Below" }
local matchWarned = false

-- Alert sounds (only the ones that exist in this game version are offered)
local SOUND_CANDIDATES = {
    { "Ultimate ready",  "ABILITY_ULTIMATE_READY" },
    { "Ding",            "DIALOG_ACCEPT" },
    { "Achievement",     "ACHIEVEMENT_AWARDED" },
    { "Level up",        "LEVEL_UP" },
    { "Champion point",  "CHAMPION_POINTS_COMMITTED" },
    { "Quest complete",  "QUEST_COMPLETED" },
    { "Book acquired",   "BOOK_ACQUIRED" },
}
local soundChoices, soundKeys = { "None" }, {}
for _, entry in ipairs(SOUND_CANDIDATES) do
    if SOUNDS[entry[2]] then
        table.insert(soundChoices, entry[1])
        soundKeys[entry[1]] = entry[2]
    end
end

-- Settings defaults (for the account-wide and the per-character settings)
local DEFAULTS = {
    enabled            = true,
    valueSize          = 19,   -- font size of current/required
    percentSize        = 27,   -- font size of the bottom text
    showValues         = true, -- show current/required at the top
    bottomMode         = BOTTOM_TEXT.PERCENT,
    readyColor         = { r = 0.3, g = 1.0, b = 0.3, a = 1 },
    notReadyColor      = { r = 1.0, g = 1.0, b = 1.0, a = 1 },
    nearMaxWarning     = true,  -- texts change colour when the ultimate is almost ready
    nearMaxPercent     = 90,    -- % of the ultimate's cost where that starts
    nearMaxColor       = { r = 1.0, g = 0.55, b = 0.0, a = 1 },
    showOpposite       = true,
    oppPlacement       = "Automatic", -- Automatic, Above, Below, Left, Right or Custom (dragged)
    oppSize            = 100,  -- percent of the ultimate button size
    oppOffsetX         = 0,
    oppOffsetY         = 0,
    dimOpposite        = true,  -- dim the opposite icon while it is not castable
    borderStyle        = BORDER_STYLE.MATCH, -- border of the opposite icon
    highlightOpposite  = true,  -- glow on the opposite icon while it is castable
    highlightActive    = true,  -- glow and green border on your ultimate while it is ready
    oppTooltip         = true,  -- show the ability tooltip when hovering the opposite icon
    showTimer          = true,  -- our own ultimate duration timer
    timerSize          = 20,    -- its font size
    timerPosition      = "Right",
    timerColor         = { r = 1, g = 1, b = 1, a = 1 },
    showCountdownGlow  = true,  -- glow on the icon that drains as the ultimate runs out
    glowColor          = { r = 1, g = 0.8, b = 0.2, a = 0.45 },
    alertSound         = soundChoices[2] or "None",
    alertFlash         = true,  -- flash the icon when the ultimate becomes ready
    alertOpposite      = false, -- also alert when the other bar's ultimate becomes ready
    hideSameOpposite   = true,  -- hide the opposite icon when both bars have the same ultimate
    -- saved positions of the texts (centre, relative to their icon's centre);
    -- by default current/required and the bottom text sit right of the icon
    textPosT           = {
        mainValue   = { dx = 88, dy = -12 }, mainPercent = { dx = 88, dy = 13 },
        oppValue    = { dx = 88, dy = -12 }, oppPercent  = { dx = 88, dy = 13 },
    },
    combatOnly         = false, -- texts hidden when out of combat
    hideOtherNumber    = false, -- hide another addon's ultimate number
    gainDisplay        = "Time until ready", -- "Off", "Gain per second" or "Time until ready" (estimates)
    rateSize           = 16,
    etaSize            = 18,
    gainColor          = { r = 1.0, g = 1.0, b = 1.0, a = 1 },   -- normal
    gainSoonSeconds    = 5,     -- "almost ready" for the last seconds
    gainSoonColor      = { r = 1.0, g = 0.55, b = 0.0, a = 1 },
    gainReadyColor     = { r = 0.3, g = 1.0, b = 0.3, a = 1 },
}

local sv        -- per-character data (remembered ultimate costs)
local settings  -- the settings in use (account-wide or this character's)
local accountSettings, charSettings
local panel     -- LibAddonMenu panel
local ultButton -- the real ultimate button control
local mainPart, oppPart
local created = false
local prevLiveId, prevReady
local combatHidden = false  -- "Show only in combat": texts hidden right now
local Refresh               -- defined further down
local holders = {}          -- the movable text and timer windows
local textsUnlocked = false
local FitHolder         -- sizes a movable text window to its text (defined below)
local ultHandle          -- invisible window the ultimate button is anchored to when moved
local ultOrigAnchor      -- the game's own anchor of the ultimate button
local ultDragPos         -- position of the ultimate button while unlocked
local ultDragMode        -- showOpposite setting that ultDragPos belongs to
local ultMoved = false   -- true while we have re-anchored the ultimate button
local otherNumbers = {}   -- another addon's number labels that we have hidden
local scanAttempts, lastScan, lastHideSetting = 0, 0, false

local function Print(text)
    d("|c00ccff[SUT]|r " .. text)
end

local function RefreshPanel()
    if panel then
        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel)
    end
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function ColorOf(c)
    return c.r, c.g, c.b, c.a
end

local function FontFor(size, scale)
    return string.format(FONT_FORMAT, math.max(8, zo_round(size * scale)))
end

local function OppScale()
    return settings.oppSize / 100
end

local function GetUltimateButtonControl()
    local button = ZO_ActionBar_GetButton(ULT_SLOT)
    if button and button.slot then
        return button.slot
    end
    return _G["ActionButton" .. ULT_SLOT]
end

local function GetBaseSize()
    local button = GetUltimateButtonControl()
    local w = button and button:GetWidth() or 0
    if w < 24 then w = 64 end
    return w
end

-------------------------------------------------------------------------------
-- Replaced icons
-- Addons like Ability Icons Framework draw their own icon files (some with a
-- frame baked in) on the action bar. We read the file the ultimate button
-- really shows and use the same style for the opposite bar icon.
-------------------------------------------------------------------------------
local iconPrefix  -- folder the icon addon uses, e.g. "/abilityiconsframework/icons/128/"
local loadTime = 0

local function Basename(path)
    return path and path:match("([^/]+)$")
end

-- Called while an ultimate is on the active bar
local function LearnIcon(liveId)
    local iconCtl = _G["ActionButton" .. ULT_SLOT .. "Icon"]
    if not liveId or not iconCtl or iconCtl:GetType() ~= CT_TEXTURE then return end

    local shown = iconCtl:GetTextureFileName()
    local original = GetSlotTexture(ULT_SLOT)
    if not shown or shown == "" or not original then return end

    if zo_strlower(shown) == zo_strlower(original) then
        iconPrefix = nil          -- no icon addon in use
        return
    end

    -- Only learn when the shown file is the same icon from another folder.
    -- Right after a bar swap the button can still show the OTHER bar's icon
    -- for a moment; that must never be learned (it made the opposite icon
    -- show the same icon as your ultimate).
    local base = Basename(original)
    if base and zo_strlower(shown):sub(-#base) == zo_strlower(base) then
        iconPrefix = shown:sub(1, #shown - #base)
    end
end

-- The icon to show for the ultimate on the given bar
local function GetDisplayIcon(hotbar)
    local original = GetSlotTexture(ULT_SLOT, hotbar)
    if iconPrefix then
        local base = Basename(original)
        if base then
            return iconPrefix .. base
        end
    end
    return original
end

-- The ultimate that is on the bar you are using RIGHT NOW (always reliable).
-- Returns abilityId, icon, cost  (or nil if no ultimate is slotted)
local function GetLiveUltimate()
    local abilityId = GetSlotBoundId(ULT_SLOT)
    if not abilityId or abilityId == 0 then
        return nil
    end

    local icon = GetSlotTexture(ULT_SLOT)

    -- Slot cost already includes cost reductions (e.g. Meditation, set bonuses)
    local cost = GetSlotAbilityCost(ULT_SLOT, COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
    if cost == 0 then
        cost = GetAbilityCost(abilityId, COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
    end

    return abilityId, icon, cost
end

-------------------------------------------------------------------------------
-- Texts
-------------------------------------------------------------------------------
-- cost may be nil = unknown. Returns nil when the bottom text is hidden.
local function BottomText(current, cost)
    if settings.bottomMode == BOTTOM_TEXT.HIDDEN then
        return nil
    end
    if not cost or cost <= 0 then
        return "--"
    end

    local percent = math.min(100, math.floor(current / cost * 100))
    local missing = math.max(0, cost - current)

    if settings.bottomMode == BOTTOM_TEXT.MISSING then
        return missing > 0 and ("-" .. missing) or "READY"
    elseif settings.bottomMode == BOTTOM_TEXT.BOTH then
        return missing > 0 and (percent .. "% -" .. missing) or (percent .. "%")
    end
    return percent .. "%"
end

-- Colour of the current/required and bottom texts: ready, almost ready
-- (a % of that icon's ultimate cost) or not ready
local function TextColor(current, cost)
    if not cost or cost <= 0 then return settings.notReadyColor end
    if current >= cost then return settings.readyColor end
    if settings.nearMaxWarning and current >= cost * settings.nearMaxPercent / 100 then
        return settings.nearMaxColor
    end
    return settings.notReadyColor
end

local function ApplyTexts(part, current, cost)
    if combatHidden then
        part.value:SetHidden(true)
        part.percent:SetHidden(true)
        return
    end
    local known = cost and cost > 0
    local color = TextColor(current, cost)

    if settings.showValues then
        part.value:SetText(known and string.format("%d/%d", current, cost) or string.format("%d/?", current))
        part.value:SetColor(ColorOf(color))
        FitHolder(part.valueHolder)
        part.value:SetHidden(false)
    else
        part.value:SetHidden(true)
    end

    local bottom = BottomText(current, cost)
    if bottom then
        part.percent:SetText(bottom)
        part.percent:SetColor(ColorOf(color))
        FitHolder(part.percentHolder)
        part.percent:SetHidden(false)
    else
        part.percent:SetHidden(true)
    end
end

local function SetPartFonts(part, scale)
    part.value:SetFont(FontFor(settings.valueSize, scale))
    part.percent:SetFont(FontFor(settings.percentSize, scale))
    FitHolder(part.valueHolder)
    FitHolder(part.percentHolder)
end

-------------------------------------------------------------------------------
-- Glow animations (flash on ready alert, pulse on castable opposite icon)
-------------------------------------------------------------------------------
local function MakeTimeline(control, lowAlpha, highAlpha, duration, loops)
    local timeline = ANIMATION_MANAGER:CreateTimeline()

    local up = timeline:InsertAnimation(ANIMATION_ALPHA, control, 0)
    up:SetAlphaValues(lowAlpha, highAlpha)
    up:SetDuration(duration)

    local down = timeline:InsertAnimation(ANIMATION_ALPHA, control, duration)
    down:SetAlphaValues(highAlpha, lowAlpha)
    down:SetDuration(duration)

    timeline:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, loops)
    return timeline
end

-- Two separate layers on an icon while an ultimate is ready:
--  part.steady: a soft glow, simply shown or hidden (never animated)
--  part.glow:   the flash, only shown while it plays and hidden right after
-- (keeping them apart means a finished animation can never leave the icon
-- covered in colour)
local function PlayFlash(part)
    if not part.flashAnim then
        part.flashAnim = MakeTimeline(part.glow, 0, 0.75, 220, 3)
    end
    local c = settings.readyColor
    part.glow:SetColor(c.r, c.g, c.b, 1)
    part.glow:SetHidden(false)
    part.flashAnim:PlayFromStart()
    part.flashToken = (part.flashToken or 0) + 1
    local token = part.flashToken
    zo_callLater(function()
        if token ~= part.flashToken then return end  -- a newer flash is playing
        part.flashAnim:Stop()
        part.glow:SetHidden(true)
    end, OPP_LOOK.flashTime)
end

-- Highlight while an ultimate is ready: a short flash the moment it becomes
-- ready (flash = true), then a steady soft glow (no flash e.g. after a bar swap)
local function SetHighlight(part, on, flash)
    if on then
        local c = settings.readyColor
        part.steady:SetColor(c.r, c.g, c.b, OPP_LOOK.readyGlow)
        part.steady:SetHidden(false)
        if not part.pulsing then
            part.pulsing = true
            if flash then PlayFlash(part) end
        end
    elseif part.pulsing then
        part.pulsing = false
        part.steady:SetHidden(true)
    end
end

-- Ready alert / Test alert
local function FlashPart(part)
    PlayFlash(part)
end

-- Style of the opposite icon: glow + tinted frame when castable, dimmed otherwise
local function ApplyOppStyle(part, castable, flash)
    local highlight = castable and settings.highlightOpposite
    SetHighlight(part, highlight, flash)

    if part.frame then
        local style = settings.borderStyle
        local copied = false

        -- "Match other skills": copy the border of the skill slot next to the
        -- ultimate (from the game or from any addon that themes it), every refresh
        if style == BORDER_STYLE.MATCH then
            -- The border can be Fancy Action Bar+'s frame ("ActionButtonOverlay<n>Frame")
            -- or the game's "Edge" texture (also used by Bandits UI themes)
            local n       = ULT_SLOT - 1
            local slot    = "ActionButton" .. n
            local srcIcon = _G[slot .. "Icon"]
            local source, file
            for _, name in ipairs({ "ActionButtonOverlay" .. n .. "Frame", slot .. "Edge" }) do
                local c = _G[name]
                if c and c:GetType() == CT_TEXTURE and not c:IsHidden() and c:GetAlpha() > 0.01 then
                    local _, _, _, a = c:GetColor()
                    local f = c:GetTextureFileName()
                    if f and f ~= "" and a > 0.01 then
                        source, file = c, f
                        break
                    end
                end
            end

            if source then
                part.copyFrame:SetTexture(file)
                part.copyFrame:SetTextureCoords(source:GetTextureCoords())
                part.copyFrame:SetColor(source:GetColor())

                -- same size relative to the icon as on the skill slot
                local size = part.icon:GetWidth()
                if srcIcon and srcIcon:GetWidth() > 0 then
                    size = size * source:GetWidth() / srcIcon:GetWidth()
                end
                part.copyFrame:ClearAnchors()
                part.copyFrame:SetAnchor(CENTER, part.icon, CENTER, 0, 0)
                part.copyFrame:SetDimensions(size, size)

                -- drawn above or below the icon, like on the skill slot
                local above = true
                if srcIcon then
                    local sl, il = source:GetDrawLayer(), srcIcon:GetDrawLayer()
                    above = sl > il or (sl == il and source:GetDrawLevel() > srcIcon:GetDrawLevel())
                end
                part.copyFrame:SetDrawLayer(DL_CONTROLS)
                part.copyFrame:SetDrawLevel(above and 7 or 4)
                copied = true
            end
            if not copied and not matchWarned and part == oppPart and GetFrameTimeSeconds() - loadTime > 15 then
                matchWarned = true
                Print("Border: couldn't find your skills' border, using black instead.")
            end
        elseif style == BORDER_STYLE.ESO then
            part.copyFrame:ClearAnchors()
            part.copyFrame:SetAnchorFill(part.icon)
            part.copyFrame:SetDrawLevel(7)
            part.copyFrame:SetTexture(BORDER_STYLE.esoFrameTexture)
            part.copyFrame:SetTextureCoords(0, 1, 0, 1)
            part.copyFrame:SetColor(1, 1, 1, 1)
            copied = true
        end

        part.copyFrame:SetHidden(not copied)
        part.frame:SetHidden(copied or style == BORDER_STYLE.NONE)

        if highlight then
            local c = settings.readyColor
            if copied then
                part.copyFrame:SetColor(c.r, c.g, c.b, 1)
            else
                part.frame:SetHidden(false)
                part.frame:SetEdgeColor(c.r, c.g, c.b, 1)
            end
        else
            part.frame:SetEdgeColor(0, 0, 0, 1)
        end
    end

    -- Dim only the picture, not the border (they are separate controls)
    local dim = settings.dimOpposite and not castable
    if part.pic then
        local alpha = OPP_LOOK.alpha
        part.pic:SetColor(1, 1, 1, 1)
        part.pic:SetDesaturation(OPP_LOOK.desaturation)
        part.pic:SetAlpha(dim and alpha * 0.5 or alpha)
    end

    if part.back then
        -- use the same backdrop texture as the skill slots if there is one
        local backAlpha = OPP_LOOK.backdropAlpha
        local source = _G["ActionButton" .. (ULT_SLOT - 1) .. "BG"]
        local file
        if source and source:GetType() == CT_TEXTURE then
            local f = source:GetTextureFileName()
            if f and f ~= "" then file = f end
        end
        if file then
            part.back:SetTexture(file)
            part.back:SetColor(1, 1, 1, backAlpha)
        else
            part.back:SetTexture("")
            part.back:SetColor(0, 0, 0, backAlpha)
        end
        part.back:SetHidden(backAlpha <= 0)
    end

    -- the real texts live in their own windows, so dim them too
    local alpha = dim and 0.5 or 1
    part.value:SetAlpha(alpha)
    part.percent:SetAlpha(alpha)
end

-------------------------------------------------------------------------------
-- Movable text windows
-- Each text lives in its own small window so it can be dragged anywhere.
-- Until it has been moved it stays on its icon (top / bottom).
-------------------------------------------------------------------------------
-- Default place: on the icon (top / bottom edge)
local function AnchorDefault(h)
    h.win:ClearAnchors()
    if h.placeFn then
        h.placeFn(h)
    elseif h.point == TOP then
        h.win:SetAnchor(TOP, h.icon, TOP, 0, TEXT_PADDING)
    else
        h.win:SetAnchor(BOTTOM, h.icon, BOTTOM, 0, -TEXT_PADDING)
    end
end

-- Moved texts are saved relative to their icon (offset of the text's centre
-- from the icon's centre), so they move along with the icon, e.g. when the
-- ultimate goes to the other row on a bar swap.
-- Older versions saved screen positions ({x, y}); those are converted once
-- the action bar has its final layout (textLayout.layoutReady).
--  layoutReady: the action bar has its final layout after login
--  legacy: true for a moment after login while old screen positions are
--  converted; the layout is then built the way older versions did (without
--  following rows)
local textLayout = { layoutReady = false, legacy = false, wasReady = {} }

-- "Automatic" placement: with two skill rows each ultimate goes in its own
-- bar's row (also with static bars); with one row the icon goes above
-- The opposite icon is in use: switched on, and not hidden because both bars
-- have the same ultimate (then everything behaves as with the icon off,
-- e.g. the ultimate is centred between two skill rows)
textLayout.oppActive = function()
    return settings.showOpposite and not textLayout.sameUlt
end

local function FollowRows()
    return settings.oppPlacement == "Automatic" and not textLayout.legacy
end

-- Back from a dragged ("Custom") opposite icon to the placement used before
local function LeaveCustomPlacement()
    settings.oppPos = nil
    if settings.oppPlacement == "Custom" then
        settings.oppPlacement = settings.lastPlacement or "Automatic"
    end
end

-- The side of the ultimate the opposite icon goes on (Automatic: above)
local function OppSide()
    local p = settings.oppPlacement
    if p == "Above" or p == "Below" or p == "Left" or p == "Right" then return p end
    return "Above"
end

-- With "Automatic" placement the texts are saved per ROW, not per icon:
-- the "main" positions are for the icon in the top row, the "opp" positions
-- for the icon in the bottom row. So when the ultimates trade rows (static
-- bars), each row keeps the text layout you gave it.
textLayout.swapKey = {
    mainValue = "oppValue",   oppValue = "mainValue",
    mainPercent = "oppPercent", oppPercent = "mainPercent",
    mainTimer = "oppTimer",   oppTimer = "mainTimer",
}

-- true when your ultimate is in the bottom row and the opposite icon in the top row
local function RowsSwapped()
    if not (textLayout.oppActive() and FollowRows()) then return false end
    local n = ULT_SLOT - 1
    local a = _G["ActionButton" .. n .. "Icon"]
    local b = _G["ActionButton" .. (n + 20) .. "Icon"]
    if not a or not b or a:IsHidden() or b:IsHidden() then return false end
    local _, ay = a:GetCenter()
    local _, by = b:GetCenter()
    return ay ~= nil and by ~= nil and ay - by > 10
end

-- true when the action bar shows two skill rows (e.g. Fancy Action Bar+)
local function TwoSkillRows()
    local n = ULT_SLOT - 1
    local a = _G["ActionButton" .. n .. "Icon"]
    local b = _G["ActionButton" .. (n + 20) .. "Icon"]
    if not a or not b or a:IsHidden() or b:IsHidden() then return false end
    local _, ay = a:GetCenter()
    local _, by = b:GetCenter()
    return ay ~= nil and by ~= nil and math.abs(ay - by) > 10
end

-- The key a text's position is saved under right now
local function KeyOf(h)
    local other = textLayout.swapKey[h.key]
    if other and RowsSwapped() then
        return other
    end
    return h.key
end

-- The saved position of a text as a screen position (centre), or nil
local function SavedTextPos(h)
    local key = KeyOf(h)
    local p = settings.textPosT[key]
    if not p then return nil end
    local ix, iy = h.icon:GetCenter()
    if p.dx == nil then
        if not textLayout.layoutReady or not ix then
            return { x = p.x, y = p.y }  -- old screen position, not converted yet
        end
        p = { dx = p.x - ix, dy = p.y - iy }
        settings.textPosT[key] = p
    end
    return { x = (ix or 0) + p.dx, y = (iy or 0) + p.dy }
end

-- Saves a text's position (a screen position, its centre)
local function SaveTextPos(h, x, y)
    local ix, iy = h.icon:GetCenter()
    settings.textPosT[KeyOf(h)] = { dx = x - (ix or 0), dy = y - (iy or 0) }
end

-- While unlocked, every text is anchored to the screen itself, by its centre,
-- so dragging always starts from a plain position. Locked, a moved text is
-- anchored to its icon.
local function ApplyHolderPosition(h)
    local saved = settings.textPosT[KeyOf(h)]
    local w, hgt = h.win:GetDimensions()

    if textsUnlocked or (saved and saved.dx == nil) then
        local pos = SavedTextPos(h) or (textsUnlocked and h.dragPos)
        saved = settings.textPosT[KeyOf(h)]  -- may have been converted
        if pos and (textsUnlocked or saved.dx == nil) then
            h.win:ClearAnchors()
            h.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x - w / 2, pos.y - hgt / 2)
            return
        end
    end

    if saved and saved.dx then
        h.win:ClearAnchors()
        h.win:SetAnchor(CENTER, h.icon, CENTER, saved.dx, saved.dy)
    else
        AnchorDefault(h)
    end
end

local function CaptureCurrentPosition(h)
    local cx, cy = h.win:GetCenter()
    h.dragPos = { x = cx, y = cy }
end

-- The window is only as big as its text, so the yellow box fits the text
FitHolder = function(h)
    if not h then return end
    local w   = math.max(24, zo_round(h.label:GetTextWidth()) + 10)
    local hgt = math.max(14, zo_round(h.label:GetTextHeight()) + 4)
    if w == h.w and hgt == h.h then return end

    h.w, h.h = w, hgt
    h.win:SetDimensions(w, hgt)
    ApplyHolderPosition(h)  -- keeps the centre where it was
end

-- Texts are only shown while the HUD is shown (not in menus, cutscenes ...)
local hudFragments = {}

local function AddToHud(win)
    local fragment = ZO_HUDFadeSceneFragment:New(win)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    table.insert(hudFragments, fragment)
end

-- While our settings page is open, the real action bar (with the ultimates,
-- the opposite icon and the texts) is shown on top of the menu, so every
-- change can be seen live in its real place.
local barInMenu = false
local barMenuList = {}  -- the fragments added to the menu (removed again on close)

-- true when control is (inside) parent
local function IsInside(control, parent)
    local c = control
    while c do
        if c == parent then return true end
        c = c:GetParent()
    end
    return false
end

-- The game's action bar fragment, plus any HUD fragment that holds the action
-- buttons (action bar addons can show their rows in their own windows)
local function ActionBarFragments()
    local list, seen = { ACTION_BAR_FRAGMENT }, { [ACTION_BAR_FRAGMENT] = true }
    local buttons = {}
    for _, n in ipairs({ 3, ULT_SLOT - 1, ULT_SLOT, ULT_SLOT - 1 + 20, ULT_SLOT + 20 }) do
        local b = _G["ActionButton" .. n]
        if b then table.insert(buttons, b) end
    end
    for _, f in ipairs(HUD_SCENE.fragments or {}) do
        local control = f.control
        if not seen[f] and control and control ~= GuiRoot then
            for _, b in ipairs(buttons) do
                if IsInside(b, control) then
                    seen[f] = true
                    table.insert(list, f)
                    break
                end
            end
        end
    end
    return list
end

-- The bar can still be hidden by the game itself (e.g. the "Show Action Bar:
-- Automatic" setting hides it out of combat) or faded out. While the settings
-- page is open, every hidden or faded window the action buttons sit in is
-- shown, and put back exactly as it was when the page closes.
local forcedShown = {}  -- control -> { hidden, alpha } before we changed it

local function ForceBarVisible()
    for _, n in ipairs({ 3, ULT_SLOT - 1, ULT_SLOT, ULT_SLOT - 1 + 20, ULT_SLOT + 20 }) do
        local c = _G["ActionButton" .. n]
        while c and c ~= GuiRoot do
            if c:IsHidden() or c:GetAlpha() < 0.99 then
                if not forcedShown[c] then
                    forcedShown[c] = { hidden = c:IsHidden(), alpha = c:GetAlpha() }
                end
                c:SetHidden(false)
                c:SetAlpha(1)
            end
            c = c:GetParent()
        end
    end
end

local function RestoreForcedBar()
    for c, old in pairs(forcedShown) do
        c:SetAlpha(old.alpha)
        c:SetHidden(old.hidden)
    end
    forcedShown = {}
end

local function ShowBarInMenu(show)
    if show == barInMenu then return end
    local scene = SCENE_MANAGER:GetScene("gameMenuInGame")
    if not scene then return end
    barInMenu = show

    local list
    if show then
        list = ActionBarFragments()
        for _, f in ipairs(hudFragments) do table.insert(list, f) end
        barMenuList = list
    else
        list = barMenuList
        barMenuList = {}
    end

    for _, f in ipairs(list) do
        if show then
            scene:AddFragment(f)
        else
            scene:RemoveFragment(f)
        end
    end
    if not show then
        RestoreForcedBar()
    end

    -- Safety net: if the bar ended up hidden on the normal game screen, show it
    if not show then
        zo_callLater(function()
            if barInMenu then return end
            local onHud = HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()
            if not onHud then return end
            for _, f in ipairs(list) do
                -- fade fragments keep their window in .control
                local control = f.control
                if control and control:IsHidden() then
                    control:SetHidden(false)
                end
            end
        end, 300)
    end
end

local function CreateMovableLabel(name, icon, point, key)
    local wm = WINDOW_MANAGER
    local h = { icon = icon, point = point, key = key }

    local win = wm:CreateTopLevelWindow(name .. "_Win")
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLevel(10)  -- above the ultimate skill's handle
    win:SetDimensions(24, 14)  -- resized to the text by FitHolder
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(false)
    win:SetMovable(false)
    h.win = win

    local label = wm:CreateControl(name, win, CT_LABEL)
    label:SetAnchor(CENTER, win, CENTER, 0, 0)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(10)
    h.label = label

    -- Yellow box shown while the texts are unlocked
    local bg = wm:CreateControl(name .. "_BG", win, CT_TEXTURE)
    bg:SetAnchorFill(win)
    bg:SetColor(1, 0.85, 0, 0.35)
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetHidden(true)
    h.bg = bg

    -- Remember where the text was dropped (stored as the window's centre)
    win:SetHandler("OnMoveStop", function(self)
        local w, hgt = self:GetDimensions()
        local pos = { x = self:GetLeft() + w / 2, y = self:GetTop() + hgt / 2 }
        SaveTextPos(h, pos.x, pos.y)
        h.dragPos = pos
        ApplyHolderPosition(h)
        RefreshPanel()  -- update the X/Y sliders
    end)

    AddToHud(win)
    ApplyHolderPosition(h)
    table.insert(holders, h)
    return h
end

-- The real ultimate button can be moved too. It is anchored to an invisible
-- window (the "handle") that is dragged; without a saved position the button is
-- left exactly as the game placed it.
local centerOffset = 0  -- how far we moved the ultimate down/up to centre it

-- Puts the ultimate button back where the game (or the action bar addon) had it
local function RestoreUltDefault()
    centerOffset = 0
    ultButton:ClearAnchors()
    local a = ultOrigAnchor
    if a then
        ultButton:SetAnchor(a[1], a[2], a[3], a[4], a[5])
    end
    ultHandle.win:ClearAnchors()
    ultHandle.win:SetAnchor(TOPLEFT, ultButton, TOPLEFT, 0, 0)
end

-------------------------------------------------------------------------------
-- Ultimate timer
-- When you cast your ultimate, its duration counts down on the icon of that
-- ultimate: on the ultimate slot while it is on your active bar, and on the
-- opposite icon after you swap bars.
-------------------------------------------------------------------------------
local mainTimer, oppTimer  -- the two timer texts
local mainTimerHolder, oppTimerHolder
local castUltId            -- ability id of the ultimate that was cast last
-- Some ultimates (e.g. Elemental Storm with a staff) report another id for the
-- bar they are slotted on than for the live slot, so remember both
local castBarId
local castEnd = 0          -- when its duration ends (ms)

local function FormatTime(ms)
    local sec = ms / 1000
    if sec >= 10 then
        return string.format("%d", math.floor(sec + 0.5))
    end
    return string.format("%.1f", sec)
end

local function PlaceTimer(label, icon)
    local pos = settings.timerPosition
    label:ClearAnchors()
    if pos == "Left" then
        label:SetAnchor(RIGHT, icon, LEFT, -2, 0)
    elseif pos == "Center" then
        label:SetAnchor(CENTER, icon, CENTER, 0, 0)
    elseif pos == "Above" then
        label:SetAnchor(BOTTOM, icon, TOP, 0, -2)
    elseif pos == "Below" then
        label:SetAnchor(TOP, icon, BOTTOM, 0, 2)
    else
        label:SetAnchor(LEFT, icon, RIGHT, 2, 0)
    end
end

-- Where the remaining time comes from (no other addon needed):
--  1. the game itself: it tracks the effect of every slotted ability for its
--     built-in ability bar timers (GetActionSlotEffectTimeRemaining), per bar;
--  2. what we saw while the ultimate was on the active bar (remembered per
--     ultimate, so it keeps counting after a bar swap);
--  3. our own cast tracking (ability duration / the effect it applied).
local ultEnds = {}  -- abilityId -> end time (ms)

local function GameSlotRemaining(hotbar)
    local remaining = GetActionSlotEffectTimeRemaining(ULT_SLOT, hotbar)
    return (remaining and remaining > 0) and remaining or 0
end

local function UltRemaining(hotbar)
    local id = GetSlotBoundId(ULT_SLOT, hotbar)
    if not id or id == 0 then return 0 end
    local now = GetGameTimeMilliseconds()

    local game = GameSlotRemaining(hotbar)
    if game > 0 then
        ultEnds[id] = now + game
    end

    local own = 0
    if castUltId then
        if castEnd <= now then
            castUltId = nil
        elseif castUltId == id or castBarId == id then
            own = castEnd - now
        end
    end

    local remembered = 0
    if ultEnds[id] then
        remembered = ultEnds[id] - now
        if remembered <= 0 then ultEnds[id] = nil end
    end

    return math.max(game, own, remembered, 0)
end

-- Countdown glow: a coloured glow over the icon that drains from the top
-- down as the ultimate's duration runs out
local mainGlow, oppGlow          -- the two glow textures
-- full duration and last value (ms), remembered per ULTIMATE (not per icon),
-- so the glow keeps its level when the ultimate moves to the other icon
local glowTotal, glowLast = {}, {}

local function UpdateGlow(glow, icon, left, abilityId)
    if not glow then return end
    if left <= 0 or not settings.showCountdownGlow or not abilityId or abilityId == 0 then
        glow:SetHidden(true)
        return
    end

    -- a new cast (time went up) starts a new full bar
    if not glowTotal[abilityId] or left > (glowLast[abilityId] or 0) + 300 then
        glowTotal[abilityId] = left
    end
    glowLast[abilityId] = left

    local fraction = math.min(1, left / glowTotal[abilityId])
    local c = settings.glowColor
    glow:SetColor(c.r, c.g, c.b, c.a)
    glow:ClearAnchors()
    glow:SetAnchor(BOTTOMLEFT, icon, BOTTOMLEFT, 0, 0)
    glow:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, 0, 0)
    glow:SetHeight(math.max(1, icon:GetHeight() * fraction))
    glow:SetHidden(false)
end

-------------------------------------------------------------------------------
-- Ultimate gain per second and time until ready (both estimates)
-- Only gains are counted (casting is ignored), over the last few seconds.
-------------------------------------------------------------------------------
local GAIN = {
    RATE    = "Gain per second",
    ETA     = "Time until ready",
    window  = 10000,  -- ms of gains used for the average
    minSpan = 2000,   -- never divide by less than this (first gains)
}
local gains = {}            -- { time, amount } of each gain in the window
local gainStart             -- when the current run of gains started
local etaTarget             -- when the ultimate should be ready (ms)
local rateHolder, etaHolder

CHOICES.gain = { "Off", GAIN.RATE, GAIN.ETA }

local function PruneGains(now)
    while gains[1] and now - gains[1].time > GAIN.window do
        table.remove(gains, 1)
    end
    if not gains[1] then
        gainStart = nil
    end
end

-- Ultimate per second, or nil when nothing was gained recently
local function UltRate(now)
    PruneGains(now)
    if not gains[1] then return nil end
    local total = 0
    for _, g in ipairs(gains) do total = total + g.amount end
    local span = math.min(GAIN.window, math.max(GAIN.minSpan, now - gainStart))
    return total / (span / 1000)
end

-- Recomputes when the ultimate should be ready (on every power change)
local function UpdateEtaTarget()
    local now = GetGameTimeMilliseconds()
    local rate = UltRate(now)
    local cost = GetSlotAbilityCost(ULT_SLOT, COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
    local current = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
    if rate and rate > 0 and cost > 0 and current < cost then
        etaTarget = now + (cost - current) / rate * 1000
    else
        etaTarget = nil
    end
end

local function RecordUltGain(amount)
    local now = GetGameTimeMilliseconds()
    PruneGains(now)
    if not gainStart then gainStart = now end
    table.insert(gains, { time = now, amount = amount })
end

-- Default place: inside the active ultimate icon, in the middle
local function PlaceGainText(h)
    h.win:SetAnchor(CENTER, h.icon, CENTER, 0, 0)
end

local function ShowGainText(h, text, size, color, show)
    if show then
        h.label:SetFont(string.format(FONT_FORMAT, size))
        h.label:SetColor(color.r, color.g, color.b, color.a)
        h.label:SetText(text)
        FitHolder(h)
    end
    h.label:SetHidden(not show)
end

local function UpdateGainTexts()
    if not rateHolder then return end
    local now = GetGameTimeMilliseconds()
    local on = settings.enabled and not combatHidden
    local sample = textsUnlocked and on

    local rate = UltRate(now)
    local current = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
    local cost = GetSlotAbilityCost(ULT_SLOT, COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
    local ready = cost > 0 and current >= cost

    -- seconds left until ready (estimate), nil when unknown
    local secLeft
    if ready then
        secLeft = 0
    elseif rate and etaTarget and cost > 0 then
        secLeft = math.max(1, math.ceil((etaTarget - now) / 1000))
    end

    -- colour (time until ready only): ready, almost ready (the last few
    -- seconds) or normal. Gain per second always uses the normal colour.
    local color = settings.gainColor
    if ready then
        color = settings.gainReadyColor
    elseif secLeft and secLeft <= settings.gainSoonSeconds then
        color = settings.gainSoonColor
    end

    local rateText = rate and string.format("+%.1f/s", rate) or "+2.4/s"
    ShowGainText(rateHolder, rateText, settings.rateSize, settings.gainColor,
        on and settings.gainDisplay == GAIN.RATE and (rate ~= nil or sample))

    local etaText = secLeft and string.format("%ds", secLeft) or "8s"
    ShowGainText(etaHolder, etaText, settings.etaSize, color,
        on and settings.gainDisplay == GAIN.ETA and ((rate ~= nil and secLeft ~= nil) or sample))
end

-- "Show only in combat": the texts (not the timers) are hidden out of combat.
-- They are always shown while positions are unlocked or the settings page is
-- open, so they can still be set up. The texts are never shown while hidden
-- (checked where they are shown), so nothing can flash them back, e.g. a bar swap.
-- The texts are also hidden while you are dead (the game hides the action bar
-- then, the texts live in their own windows and would stay on screen).
local function UpdateCombatOnly()
    -- (textLayout.isDead is set by the death / alive events: right when the
    -- event fires, IsUnitDead can still report the old state)
    local dead = textLayout.isDead and not textsUnlocked and not barInMenu
    textLayout.dead = dead
    local hide = dead or (settings.combatOnly and not textsUnlocked and not barInMenu
        and not IsUnitInCombat("player"))
    if hide ~= combatHidden then
        combatHidden = hide
        Refresh()
    end
end

-- The 100 ms updater only runs while something needs it (see NeedsUpdates)
local UPDATER = ADDON_NAME .. "_Update"
local updating = false
local HideTick  -- hides another addon's ultimate number (defined below)
local hideActive = false

local function StopUpdates()
    if updating then
        EVENT_MANAGER:UnregisterForUpdate(UPDATER)
        updating = false
    end
end

local function UpdateUltTimer()
    if not created or not mainTimer then
        StopUpdates()
        return
    end
    if barInMenu then ForceBarVisible() end
    if hideActive then HideTick() end
    UpdateCombatOnly()
    UpdateGainTexts()

    local mainLeft, oppLeft = 0, 0
    local activeBar = GetActiveHotbarCategory()
    local otherBar  = (activeBar == HOTBAR_CATEGORY_PRIMARY) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    if settings.enabled and (settings.showTimer or settings.showCountdownGlow) then
        mainLeft = UltRemaining(activeBar)
        if not oppPart.icon:IsHidden() then
            oppLeft = UltRemaining(otherBar)
        end
    end

    local font = string.format(FONT_FORMAT, settings.timerSize)
    local c = settings.timerColor
    for _, entry in ipairs({ { mainTimerHolder, mainLeft }, { oppTimerHolder, oppLeft } }) do
        local h, left = entry[1], entry[2]
        local label = h.label
        local running = left > 0
        -- while positions are unlocked, show a sample so the timer can be moved
        local show = settings.showTimer and not textLayout.dead
            and (running or (textsUnlocked and settings.enabled))
        if show then
            label:SetFont(font)
            label:SetColor(c.r, c.g, c.b, c.a)
            label:SetText(running and FormatTime(left) or "12")
            FitHolder(h)
            if h.timerPos ~= settings.timerPosition then
                h.timerPos = settings.timerPosition
                ApplyHolderPosition(h)
            end
        end
        label:SetHidden(not show)
    end

    UpdateGlow(mainGlow, _G["ActionButton" .. ULT_SLOT .. "Icon"] or ultButton, mainLeft, GetSlotBoundId(ULT_SLOT, activeBar))
    UpdateGlow(oppGlow, oppPart.pic, oppLeft, GetSlotBoundId(ULT_SLOT, otherBar))

    -- needed: in combat, an ultimate running, recent ultimate gains (gain
    -- texts), the settings page open or positions unlocked
    local needed = mainLeft > 0 or oppLeft > 0 or gains[1] ~= nil or barInMenu
        or textsUnlocked or IsUnitInCombat("player")
    if not needed then
        StopUpdates()
    end
end

-- Starts the updater (it stops itself once nothing needs it any more)
local function StartUpdates()
    if not updating then
        updating = true
        EVENT_MANAGER:RegisterForUpdate(UPDATER, 100, UpdateUltTimer)
    end
end

-- Which effect to time for each ultimate: see Data.lua
local ULT_EFFECTS = (SimpleUltimateTracker and SimpleUltimateTracker.ultEffects) or {}

local pendingId, pendingTime = nil, 0  -- cast whose duration we are still looking for
local pendingEffectId                  -- the effect we expect for that cast (ULT_EFFECTS)

-------------------------------------------------------------------------------
-- Learning the effect of ultimates that are not in ULT_EFFECTS
-- The first time you cast such an ultimate, the addon looks at the effects
-- you apply right after the cast and picks the one whose duration is one of
-- the numbers in the ultimate's own description ("... for 8 seconds"). This
-- works in every game language. What it learns is saved for the account.
-------------------------------------------------------------------------------
local learnedEffects = {}              -- ultimate id -> effect id (saved)
local learnId, learnExpected, learnCandidates

local function KnownEffect(id)
    return ULT_EFFECTS[id] or learnedEffects[id]
end

-- All numbers in the ultimate's description that could be a duration
local function DescriptionDurations(id)
    local set = {}
    local text = GetAbilityDescription(id)
    if not text then return set end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    for num in text:gmatch("%d+%.?%d*") do
        local n = tonumber(num)
        if n and n >= 1 and n <= 120 then set[#set + 1] = n end
    end
    return set
end

local function IsMajorMinor(name)
    return name:find("^major ") or name:find("^minor ")
end

-- Called a moment after the cast: pick the best matching effect
local function FinishLearning()
    local id, candidates = learnId, learnCandidates
    learnId, learnCandidates = nil, nil
    if not id or not candidates or #candidates == 0 then return end

    table.sort(candidates, function(a, b)
        local am, bm = IsMajorMinor(a.name) and 1 or 0, IsMajorMinor(b.name) and 1 or 0
        if am ~= bm then return am < bm end      -- the ultimate's own effect first
        return a.duration < b.duration
    end)
    local best = candidates[1]
    learnedEffects[id] = best.id

    if castUltId ~= id or castEnd <= GetGameTimeMilliseconds() then
        local remaining = (best.endTime - GetFrameTimeSeconds()) * 1000
        if remaining > 0 then
            castUltId = id
            castEnd = GetGameTimeMilliseconds() + remaining
            StartUpdates()
        end
    end
end
local lastCastTime = 0
local lastUltPower

local function NameOf(id)
    local name = GetAbilityName(id)
    return name and name ~= "" and zo_strlower(zo_strformat("<<1>>", name)) or nil
end

-- The effect an ultimate puts on you or an enemy has the real duration
local function OnEffectChanged(_, changeType, _, effectName, _, beginTime, endTime, _, _, _, _, _, _, _, _, abilityId)
    if not pendingId or GetGameTimeMilliseconds() - pendingTime > 2000 then return end
    -- (there is no event filter for the change type; this event is only
    -- registered for a moment after a cast, see WatchEffects)
    if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED then return end

    local name = effectName and zo_strlower(zo_strformat("<<1>>", effectName)) or ""
    if not endTime or not beginTime or endTime <= beginTime then return end

    if learnId and learnId == pendingId and learnCandidates then
        local duration = endTime - beginTime
        for _, n in ipairs(learnExpected) do
            if math.abs(duration - n) <= 0.15 then
                table.insert(learnCandidates, { id = abilityId, name = name, duration = duration, endTime = endTime })
                break
            end
        end
    end

    -- the ultimate itself or its known effect (both filtered by ability id);
    -- only while its effect is still unknown: the same name, or one name
    -- containing the other
    local match = abilityId == pendingId or (pendingEffectId and abilityId == pendingEffectId)
    if not match and not pendingEffectId then
        local ultName = NameOf(pendingId)
        match = ultName and name ~= "" and (name == ultName or name:find(ultName, 1, true) or ultName:find(name, 1, true))
    end
    if not match then return end

    local remaining = (endTime - GetFrameTimeSeconds()) * 1000
    if remaining > 0 then
        castUltId = pendingId
        castEnd = GetGameTimeMilliseconds() + remaining
        StartUpdates()
        UpdateUltTimer()
    end
end

-- EVENT_EFFECT_CHANGED is only registered for 2 seconds after you cast your
-- ultimate (that is the only time it is needed), filtered to your own
-- effects and, when the ultimate's effect is known, to its ability ids.
local EFFECT_EVENT = ADDON_NAME .. "_Effect"
local effectNames = {}  -- registered event names
local watchToken = 0

local function StopEffectWatch()
    for _, name in ipairs(effectNames) do
        EVENT_MANAGER:UnregisterForEvent(name, EVENT_EFFECT_CHANGED)
    end
    effectNames = {}
end

-- ids: the ability ids to watch, or nil = all of your effects (to learn
-- the effect of an ultimate that is not known yet)
local function WatchEffects(ids)
    StopEffectWatch()
    if ids then
        -- one registration per ability id (a filter type can only be added once per name)
        for i, id in ipairs(ids) do
            local name = EFFECT_EVENT .. i
            EVENT_MANAGER:RegisterForEvent(name, EVENT_EFFECT_CHANGED, OnEffectChanged)
            EVENT_MANAGER:AddFilterForEvent(name, EVENT_EFFECT_CHANGED,
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
                REGISTER_FILTER_ABILITY_ID, id)
            table.insert(effectNames, name)
        end
    else
        EVENT_MANAGER:RegisterForEvent(EFFECT_EVENT, EVENT_EFFECT_CHANGED, OnEffectChanged)
        EVENT_MANAGER:AddFilterForEvent(EFFECT_EVENT, EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        table.insert(effectNames, EFFECT_EVENT)
    end

    watchToken = watchToken + 1
    local token = watchToken
    zo_callLater(function()
        if token == watchToken then StopEffectWatch() end
    end, 2100)
end

-- Called when the ultimate on the active bar was cast
local function StartUltTimer(id)
    if not id or id == 0 then return end
    local now = GetGameTimeMilliseconds()
    if now - lastCastTime < 700 then return end  -- already handled this cast
    lastCastTime = now
    castBarId = GetSlotBoundId(ULT_SLOT, GetActiveHotbarCategory())

    local effectId = KnownEffect(id)
    local duration = GetAbilityDuration(id) or 0
    if duration <= 0 then
        duration = GetAbilityDuration(id, nil, "player") or 0
    end
    if duration <= 0 and effectId then
        duration = GetAbilityDuration(effectId, nil, "player") or 0
    end

    if duration > 0 then
        castUltId = id
        castEnd = now + duration
    else
        castUltId = nil
    end
    -- the buff/debuff the ultimate applies can still give (a better) duration
    pendingId, pendingTime = id, now
    pendingEffectId = effectId

    if effectId then
        WatchEffects((effectId ~= id) and { id, effectId } or { id })
    else
        learnId, learnExpected, learnCandidates = id, DescriptionDurations(id), {}
        WatchEffects(nil)
        zo_callLater(FinishLearning, 1200)
    end
    StartUpdates()
    UpdateUltTimer()
end

local function OnUltimateUsed(_, slotNum)
    if slotNum == ULT_SLOT then
        StartUltTimer(GetSlotBoundId(ULT_SLOT))
    end
end

-- Backup: a big drop of ultimate power means the ultimate was cast
local function OnUltPowerChanged()
    local power = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
    if lastUltPower and power > lastUltPower then
        RecordUltGain(power - lastUltPower)
    end
    if lastUltPower and power < lastUltPower then
        local cost = GetSlotAbilityCost(ULT_SLOT, COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
        if cost > 0 and lastUltPower - power >= cost * 0.8 then
            StartUltTimer(GetSlotBoundId(ULT_SLOT))
        end
    end
    lastUltPower = power
    UpdateEtaTarget()
    StartUpdates()
end


-- When the action bar shows two rows (e.g. Fancy Action Bar+) the ultimate is
-- placed automatically:
--  - opposite icon off: centred between the two rows;
--  - "Automatic" placement: in the row of the bar you are on (the
--    opposite icon goes in the other bar's row), also with static bars;
--  - opposite icon above/below (lined up with the skill row): the ultimate
--    goes to one row and the opposite icon to the other, so they never overlap
--    (an action bar addon may have centred the ultimate between the rows).
-- Once you move the ultimate yourself, your position is used instead (see SavedUltPos).
local function ApplyUltCentering()
    if not created or not ultOrigAnchor or ultMoved then return end

    local ok, point, rel, relPoint, x, y = ultButton:GetAnchor(0)
    if not ok then return end

    -- another addon re-anchored the button: start again from its new anchor
    local o = ultOrigAnchor
    if rel ~= o[2] or point ~= o[1] or math.abs(x - o[4]) > 0.5 or math.abs(y - (o[5] + centerOffset)) > 0.5 then
        ultOrigAnchor = { point, rel, relPoint, x, y }
        o = ultOrigAnchor
        centerOffset = 0
    end

    local desired = 0
    if settings.enabled then
        local n = ULT_SLOT - 1
        local a = _G["ActionButton" .. n .. "Icon"]
        local b = _G["ActionButton" .. (n + 20) .. "Icon"]
        if a and b and not a:IsHidden() and not b:IsHidden() then
            local _, ay = a:GetCenter()
            local _, by = b:GetCenter()
            local _, cy = ultButton:GetCenter()
            if ay and by and cy and math.abs(ay - by) > 10 then
                local defaultY = cy - centerOffset
                local topY, bottomY = math.min(ay, by), math.max(ay, by)
                local gap = bottomY - topY
                local pos = OppSide()
                if not textLayout.oppActive() then
                    desired = (topY + bottomY) / 2 - defaultY
                elseif FollowRows() then
                    -- the ultimate goes in the row of the bar you are on
                    -- (ActionButton slots always hold the active bar, also
                    -- with static bars), the opposite icon in the other row
                    desired = ay - defaultY
                elseif (pos == "Above" or pos == "Below")
                        and defaultY > topY + gap * 0.25 and defaultY < bottomY - gap * 0.25 then
                    -- the ultimate sits between the rows: move it into one row,
                    -- the opposite icon goes into the other
                    desired = ((pos == "Above") and bottomY or topY) - defaultY
                end
            end
        end
    end

    if math.abs(desired - centerOffset) > 0.5 then
        ultButton:ClearAnchors()
        ultButton:SetAnchor(o[1], o[2], o[3], o[4], o[5] + desired)
        centerOffset = desired
    end
end

-- The ultimate has two saved positions: one for when the opposite bar icon is
-- shown and one for when it is off (without it, the ultimate is centred on
-- the action bar until you move it yourself).
local function SavedUltPos()
    if textLayout.oppActive() then
        return settings.ultPos
    end
    return settings.ultPosNoOpp
end

local function SaveUltPos(pos)
    if textLayout.oppActive() then
        settings.ultPos = pos
    else
        settings.ultPosNoOpp = pos
    end
end

-- "Automatic" placement also works for an ultimate you moved yourself:
-- if you placed it at the skill rows (not somewhere else on the screen), its
-- height snaps to the row of the bar you are on; your sideways position is
-- kept. Returns the new top, or nil to leave the position as it is.
local function RowSnapY(pos)
    if not (textLayout.oppActive() and FollowRows()) then return nil end
    local n = ULT_SLOT - 1
    local a = _G["ActionButton" .. n .. "Icon"]
    local b = _G["ActionButton" .. (n + 20) .. "Icon"]
    if not a or not b or a:IsHidden() or b:IsHidden() then return nil end
    local _, ay = a:GetCenter()
    local _, by = b:GetCenter()
    if not ay or not by or math.abs(ay - by) <= 10 then return nil end

    local half = ultButton:GetHeight() / 2
    local centerY = pos.y + half
    local topY, bottomY = math.min(ay, by), math.max(ay, by)
    local gap = bottomY - topY
    if centerY < topY - gap * 0.75 or centerY > bottomY + gap * 0.75 then return nil end
    return ay - half
end

local function ApplyUltPosition()
    if not created or not ultHandle then return end

    local pos = nil
    if settings.enabled then
        pos = SavedUltPos()
        if not pos and textsUnlocked and ultDragMode == textLayout.oppActive() then
            pos = ultDragPos
        end
    end
    if pos then
        local snapY = RowSnapY(pos)
        if snapY then pos = { x = pos.x, y = snapY } end
    end

    if pos then
        local off = math.abs(ultButton:GetLeft() - pos.x) > 0.5 or math.abs(ultButton:GetTop() - pos.y) > 0.5
        if off or not ultMoved then
            ultHandle.win:ClearAnchors()
            ultHandle.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
            ultButton:ClearAnchors()
            ultButton:SetAnchor(TOPLEFT, ultHandle.win, TOPLEFT, 0, 0)
            ultMoved = true
        end
    elseif ultMoved then
        RestoreUltDefault()
        ultMoved = false
    end
end

local function CreateUltHandle()
    local wm = WINDOW_MANAGER

    local win = wm:CreateTopLevelWindow(ADDON_NAME .. "_UltHandle")
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLevel(0)  -- below the text windows, so those can still be grabbed
    win:SetDimensions(ultButton:GetWidth(), ultButton:GetHeight())
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(false)
    win:SetMovable(false)
    win:SetAnchor(TOPLEFT, ultButton, TOPLEFT, 0, 0)

    -- Yellow box shown while unlocked
    local bg = wm:CreateControl(ADDON_NAME .. "_UltHandle_BG", win, CT_TEXTURE)
    bg:SetAnchorFill(win)
    bg:SetColor(1, 0.85, 0, 0.35)
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetHidden(true)

    ultHandle = { win = win, bg = bg }

    -- Remember where the skill was dropped (the button follows the handle live)
    win:SetHandler("OnMoveStop", function(self)
        local pos = { x = self:GetLeft(), y = self:GetTop() }
        SaveUltPos(pos)
        ultDragPos = pos
        ultDragMode = textLayout.oppActive()
        ultMoved = false  -- force the anchors to be set again
        ApplyUltPosition()
        RefreshPanel()  -- update the X/Y sliders
    end)

    AddToHud(win)
end

-- The opposite icon can be dragged too (while unlocked), the same way as the
-- ultimate: an invisible window is dragged and its screen position is saved
-- (settings.oppPos). The icon is then attached to that window, so it stays
-- exactly where you dropped it. Reset positions brings back the automatic
-- placement (next to the ultimate / in the other skill row).

-- Places the opposite icon at your saved position. Returns false when there is none.
local function ApplyOppFree()
    local pos = settings.oppPos
    if not pos or settings.oppPlacement ~= "Custom" then return false end
    local h = ultHandle.opp
    local w, hgt = oppPart.icon:GetDimensions()
    h.win:ClearAnchors()
    h.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    h.win:SetDimensions(w, hgt)
    oppPart.icon:ClearAnchors()
    oppPart.icon:SetAnchor(TOPLEFT, h.win, TOPLEFT, 0, 0)
    return true
end

-- Puts the (unlocked) drag box on the opposite icon
local function PlaceOppHandle()
    if ApplyOppFree() then return end
    local h = ultHandle.opp
    local w, hgt = oppPart.icon:GetDimensions()
    h.win:ClearAnchors()
    h.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, oppPart.icon:GetLeft(), oppPart.icon:GetTop())
    h.win:SetDimensions(w, hgt)
end

local function CreateOppHandle()
    local wm = WINDOW_MANAGER
    local win = wm:CreateTopLevelWindow(ADDON_NAME .. "_OppHandle")
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLevel(1)  -- below the text windows, above the ultimate's handle
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(false)
    win:SetMovable(false)

    local bg = wm:CreateControl(ADDON_NAME .. "_OppHandle_BG", win, CT_TEXTURE)
    bg:SetAnchorFill(win)
    bg:SetColor(1, 0.85, 0, 0.35)
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetHidden(true)

    ultHandle.opp = { win = win, bg = bg }

    -- Remember where the icon was dropped (the icon follows the box)
    win:SetHandler("OnMoveStop", function(self)
        settings.oppPos = { x = self:GetLeft(), y = self:GetTop() }
        if settings.oppPlacement ~= "Custom" then
            settings.lastPlacement = settings.oppPlacement  -- for going back
            settings.oppPlacement = "Custom"
        end
        ApplyOppFree()
        Refresh()
        RefreshPanel()
    end)

    AddToHud(win)
end

-------------------------------------------------------------------------------
-- Building blocks
-------------------------------------------------------------------------------
-- The glow plus the two movable texts (current/required, bottom text) of an icon
local function CreateGlowAndLabels(part, icon, prefix, scale, posKey)
    local wm = WINDOW_MANAGER

    part.icon = icon

    part.glow = wm:CreateControl(prefix .. "_Glow", icon, CT_TEXTURE)
    part.glow:SetAnchorFill(icon)
    part.glow:SetDrawLayer(DL_OVERLAY)
    part.glow:SetDrawLevel(5)
    part.glow:SetHidden(true)

    -- steady soft glow while the ultimate is ready
    part.steady = wm:CreateControl(prefix .. "_Steady", icon, CT_TEXTURE)
    part.steady:SetAnchorFill(icon)
    part.steady:SetDrawLayer(DL_OVERLAY)
    part.steady:SetDrawLevel(5)
    part.steady:SetHidden(true)

    part.valueHolder   = CreateMovableLabel(prefix .. "_Value",   icon, TOP,    posKey .. "Value")
    part.percentHolder = CreateMovableLabel(prefix .. "_Percent", icon, BOTTOM, posKey .. "Percent")
    part.value   = part.valueHolder.label
    part.percent = part.percentHolder.label

    SetPartFonts(part, scale)
    return part
end

-- A standalone icon (texture + ability frame + glow + labels)
local function CreateIconPart(parent, prefix, scale, posKey)
    local wm = WINDOW_MANAGER
    local part = {}

    -- "icon" is an empty holder; the picture and the border are both inside it,
    -- side by side, so the picture can be faded without fading the border
    local icon = wm:CreateControl(prefix, parent, CT_CONTROL)

    -- Backdrop behind the picture (like the backdrop of the other skill slots)
    part.back = wm:CreateControl(prefix .. "_Back", icon, CT_TEXTURE)
    part.back:SetAnchorFill(icon)
    part.back:SetDrawLayer(DL_CONTROLS)
    part.back:SetDrawLevel(3)

    part.pic = wm:CreateControl(prefix .. "_Pic", icon, CT_TEXTURE)
    part.pic:SetAnchorFill(icon)
    part.pic:SetDrawLayer(DL_CONTROLS)
    part.pic:SetDrawLevel(5)

    -- Thin black border, like the other skill slots
    part.frame = wm:CreateControl(prefix .. "_Frame", icon, CT_BACKDROP)
    part.frame:SetCenterColor(0, 0, 0, 0)
    part.frame:SetEdgeTexture("", 1, 1, BORDER_SIZE)
    part.frame:SetEdgeColor(0, 0, 0, 1)
    part.frame:SetAnchorFill(icon)

    -- Copy of the border the game / other addons draw on the normal skill slots
    part.copyFrame = wm:CreateControl(prefix .. "_CopyFrame", icon, CT_TEXTURE)
    part.copyFrame:SetAnchorFill(icon)
    part.copyFrame:SetDrawLayer(DL_CONTROLS)
    part.copyFrame:SetDrawLevel(6)
    part.copyFrame:SetHidden(true)
    part.frame:SetDrawLayer(DL_CONTROLS)
    part.frame:SetDrawLevel(6)

    return CreateGlowAndLabels(part, icon, prefix, scale, posKey)
end

-- Places the opposite icon next to the main icon according to the settings
local function LayoutOpposite(oppIcon, mainIcon, size)
    local pos = OppSide()
    local ox, oy = settings.oppOffsetX, settings.oppOffsetY

    oppIcon:SetDimensions(size, size)
    oppIcon:ClearAnchors()

    if pos == "Below" then
        oppIcon:SetAnchor(TOP, mainIcon, BOTTOM, ox, ICON_GAP + oy)
    elseif pos == "Left" then
        oppIcon:SetAnchor(RIGHT, mainIcon, LEFT, -ICON_GAP + ox, oy)
    elseif pos == "Right" then
        oppIcon:SetAnchor(LEFT, mainIcon, RIGHT, ICON_GAP + ox, oy)
    else
        oppIcon:SetAnchor(BOTTOM, mainIcon, TOP, ox, -ICON_GAP + oy)
    end
end

-------------------------------------------------------------------------------
-- Real UI
-------------------------------------------------------------------------------
-- Lines the opposite icon up with your other skills: same spacing they have
-- between each other, and the same size as them (times the Size slider).
-- If the other bar is shown as its own row (e.g. Fancy Action Bar+, whose
-- other-bar slots are ActionButton23-28), the icon sits exactly in that row.
-- Returns false when the skill slots can't be read, so the normal layout is used.
local function AlignToSkillRow()

    local n = ULT_SLOT - 1
    local srcIcon = _G["ActionButton" .. n .. "Icon"]
    if not srcIcon or srcIcon:IsHidden() or srcIcon:GetWidth() < 10 then
        return false
    end

    local skillSize = srcIcon:GetWidth()
    local size = skillSize * OppScale()
    local ultX, ultY = ultButton:GetCenter()
    local rowX = srcIcon:GetCenter()
    if not ultX or not rowX then
        return false
    end

    -- horizontal distance between two neighbouring skills (centre to centre)
    local pitch = skillSize + 4
    local prevIcon = _G["ActionButton" .. (n - 1) .. "Icon"]
    if prevIcon then
        local px = prevIcon:GetCenter()
        if px and math.abs(rowX - px) > skillSize * 0.8 then
            pitch = math.abs(rowX - px)
        end
    end

    -- the rows of skills: this bar's row and (if shown) the other bar's row
    local rows = {}
    for _, name in ipairs({ "ActionButton" .. n .. "Icon", "ActionButton" .. (n + 20) .. "Icon" }) do
        local c = _G[name]
        if c and not c:IsHidden() and c:GetWidth() > 10 then
            local _, y = c:GetCenter()
            if y then table.insert(rows, y) end
        end
    end

    -- vertical distance between the rows (falls back to the horizontal one)
    local vpitch = pitch
    if #rows == 2 and math.abs(rows[1] - rows[2]) > skillSize * 0.8 then
        vpitch = math.abs(rows[1] - rows[2])
    end

    -- closest the opposite icon may be to the ultimate's centre without
    -- overlapping it (e.g. when an action bar addon centres the ultimate
    -- between its two rows, the rows are too close to use)
    local minY = ultButton:GetHeight() / 2 + size / 2 + ICON_GAP
    local minX = ultButton:GetWidth() / 2 + size / 2 + ICON_GAP

    -- a row on the requested side of the ultimate, if there is one
    local function RowOnSide(above)
        local best
        for _, y in ipairs(rows) do
            local d = y - ultY
            if (above and d <= -minY) or (not above and d >= minY) then
                if not best or math.abs(d) < math.abs(best) then best = d end
            end
        end
        return best
    end

    local icon = oppPart.icon
    icon:SetDimensions(size, size)

    -- "Automatic" placement: the opposite icon sits in the other bar's row,
    -- right in line with the ultimate (anchored to that row, so it follows
    -- when an action bar addon swaps the rows)
    local otherRow = _G["ActionButton" .. (n + 20) .. "Icon"]
    if FollowRows() and #rows == 2 and otherRow then
        local otherX = otherRow:GetCenter()
        if otherX then
            icon:ClearAnchors()
            icon:SetAnchor(CENTER, otherRow, CENTER, ultX - otherX + settings.oppOffsetX, settings.oppOffsetY)
            return true
        end
    end

    local dx, dy = 0, 0
    local pos = OppSide()
    if pos == "Below" then
        dy = RowOnSide(false) or math.max(vpitch, minY)
    elseif pos == "Left" then
        dx = -math.max(pitch, minX)
    elseif pos == "Right" then
        dx = math.max(pitch, minX)
    else -- Above
        dy = RowOnSide(true) or -math.max(vpitch, minY)
    end

    icon:ClearAnchors()
    icon:SetAnchor(CENTER, ultButton, CENTER, dx + settings.oppOffsetX, dy + settings.oppOffsetY)
    return true
end

local function ApplyLayout()
    if not created then return end
    local size = math.floor(GetBaseSize() * OppScale() + 0.5)
    if not AlignToSkillRow() then
        LayoutOpposite(oppPart.icon, ultButton, size)
    end
    ApplyOppFree()  -- a position you dragged it to wins (keeps the size from above)
    SetPartFonts(mainPart, 1)
    SetPartFonts(oppPart, OppScale())
end

local function CreateUI()
    local button = GetUltimateButtonControl()
    if not button then return false end
    ultButton = button

    local ok, point, relativeTo, relativePoint, x, y = button:GetAnchor(0)
    if ok then
        ultOrigAnchor = { point, relativeTo, relativePoint, x, y }
    end
    CreateUltHandle()

    -- Current ultimate: texts and flash on the real ultimate icon
    mainPart = CreateGlowAndLabels({}, button, ADDON_NAME .. "_Main", 1, "main")

    -- Opposite bar icon
    oppPart = CreateIconPart(button, ADDON_NAME .. "_Opp", OppScale(), "opp")
    CreateOppHandle()

    -- Green border on your ultimate while it is ready (with the glow pulse)
    local readyFrame = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "_Main_ReadyFrame", button, CT_BACKDROP)
    readyFrame:SetCenterColor(0, 0, 0, 0)
    readyFrame:SetEdgeTexture("", 1, 1, BORDER_SIZE)
    readyFrame:SetAnchorFill(_G["ActionButton" .. ULT_SLOT .. "Icon"] or button)
    readyFrame:SetDrawLayer(DL_OVERLAY)
    readyFrame:SetDrawLevel(6)
    readyFrame:SetHidden(true)
    mainPart.readyFrame = readyFrame

    -- Ultimate timer texts (on the ultimate and on the opposite icon); they can
    -- be moved like the other texts (Unlock positions)
    local function TimerHolder(name, icon, key)
        local h = CreateMovableLabel(name, icon, "timer", key)
        h.placeFn = function(self) PlaceTimer(self.win, self.icon) end
        h.timerPos = settings.timerPosition
        ApplyHolderPosition(h)
        h.label:SetHidden(true)
        return h
    end
    mainTimerHolder = TimerHolder(ADDON_NAME .. "_MainTimer", button, "mainTimer")
    oppTimerHolder  = TimerHolder(ADDON_NAME .. "_OppTimer", oppPart.icon, "oppTimer")
    mainTimer, oppTimer = mainTimerHolder.label, oppTimerHolder.label

    -- Ultimate gain per second and time until ready (inside the ultimate icon)
    local function GainHolder(name, key)
        local h = CreateMovableLabel(name, button, "gain", key)
        h.placeFn = PlaceGainText
        ApplyHolderPosition(h)
        h.label:SetHidden(true)
        return h
    end
    rateHolder = GainHolder(ADDON_NAME .. "_UltRate", "ultRate")
    etaHolder  = GainHolder(ADDON_NAME .. "_UltEta", "ultEta")

    -- Countdown glows (on the ultimate icon and on the opposite icon)
    local function MakeGlow(name, parent)
        local g = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
        g:SetTexture("")
        g:SetBlendMode(TEX_BLEND_MODE_ADD)
        g:SetDrawLayer(DL_OVERLAY)
        g:SetDrawLevel(4)
        g:SetHidden(true)
        return g
    end
    mainGlow = MakeGlow(ADDON_NAME .. "_MainCountdownGlow", button)
    oppGlow  = MakeGlow(ADDON_NAME .. "_OppCountdownGlow", oppPart.icon)

    -- Ability tooltip when the mouse is over the opposite icon
    oppPart.icon:SetMouseEnabled(true)
    oppPart.icon:SetHandler("OnMouseEnter", function(self)
        if not settings.oppTooltip or not oppPart.abilityId then return end
        InitializeTooltip(AbilityTooltip, self, BOTTOM, 0, -5, TOP)
        AbilityTooltip:SetAbilityId(oppPart.abilityId)
    end)
    oppPart.icon:SetHandler("OnMouseExit", function()
        ClearTooltip(AbilityTooltip)
    end)

    created = true
    ApplyLayout()
    return true
end

local function HideAll()
    if not created then return end
    mainPart.value:SetHidden(true)
    mainPart.percent:SetHidden(true)
    oppPart.value:SetHidden(true)
    oppPart.percent:SetHidden(true)
    SetHighlight(oppPart, false)
    SetHighlight(mainPart, false)
    mainPart.readyFrame:SetHidden(true)
    oppPart.icon:SetHidden(true)
    rateHolder.label:SetHidden(true)
    etaHolder.label:SetHidden(true)
    prevLiveId, prevReady = nil, nil
end

-------------------------------------------------------------------------------
-- Ready alert
-------------------------------------------------------------------------------
local function PlayAlertSound()
    local key = soundKeys[settings.alertSound]
    if key and SOUNDS[key] then
        PlaySound(SOUNDS[key])
    end
end

local function TriggerAlert()
    PlayAlertSound()
    if settings.alertFlash and created then
        FlashPart(mainPart)
    end
end

-------------------------------------------------------------------------------
-- Hiding another addon's ultimate number
-- Such an addon puts a text with your current ultimate value on the button.
-- We look for visible texts next to the ultimate button that are only a number
-- equal to the current ultimate value, and hide them.
-------------------------------------------------------------------------------
-- Number texts next to the ultimate button that equal the current ultimate
local function FindNearbyNumbers(current)
    local found = {}
    if not ultButton then return found end

    local L, T = ultButton:GetLeft(), ultButton:GetTop()
    local x1, y1 = L - 60, T - 60
    local x2, y2 = L + ultButton:GetWidth() + 60, T + ultButton:GetHeight() + 60
    local visited = 0

    local function Overlaps(c)
        return c:GetRight() > x1 and c:GetLeft() < x2 and c:GetBottom() > y1 and c:GetTop() < y2
    end

    local function Scan(parent, depth)
        for i = 1, parent:GetNumChildren() do
            visited = visited + 1
            if visited > 6000 then return end

            local child = parent:GetChild(i)
            local name = child and child:GetName() or ""
            if child and not name:find("^" .. ADDON_NAME) and Overlaps(child) then
                if child:GetType() == CT_LABEL and not child:IsHidden() then
                    local text = child:GetText() or ""
                    if text:find("^%d+$") and tonumber(text) == current then
                        table.insert(found, child)
                    end
                end
                if depth < 5 and child:GetNumChildren() > 0 then
                    Scan(child, depth + 1)
                end
            end
        end
    end

    Scan(GuiRoot, 1)
    return found
end

-- Fancy Action Bar+ draws its ultimate number in "UltimateButtonOverlay<slot>Value"
local OTHER_NUMBER_NAMES = { "UltimateButtonOverlay" .. ULT_SLOT .. "Value" }
local otherSet = {}

local function AddOtherNumber(c)
    if c and not otherSet[c] then
        otherSet[c] = true
        table.insert(otherNumbers, c)
    end
end

-- The other addon can show its number again when it updates it, so this is
-- repeated on every refresh and every 0.1 s while the updater runs.
local function HideOtherNumbers()
    for _, c in ipairs(otherNumbers) do
        if not c:IsHidden() then c:SetHidden(true) end
        if c:GetAlpha() > 0 then c:SetAlpha(0) end
    end
end

local function FindNamedNumbers()
    for _, name in ipairs(OTHER_NUMBER_NAMES) do
        local c = _G[name]
        if c and c.SetHidden then
            AddOtherNumber(c)
        end
    end
end

HideTick = function()
    FindNamedNumbers()
    HideOtherNumbers()
end

local function RestoreOtherNumbers()
    for _, c in ipairs(otherNumbers) do
        c:SetHidden(false)
        c:SetAlpha(1)
    end
    otherNumbers, otherSet = {}, {}
end

local function UpdateOtherNumbers(current)
    local want = settings.enabled and settings.hideOtherNumber

    if not want then
        hideActive = false
        if #otherNumbers > 0 then
            RestoreOtherNumbers()
        end
        lastHideSetting = false
        return
    end

    if not lastHideSetting then
        lastHideSetting = true
        scanAttempts = 0
    end

    -- (repeated by the updater while it runs, e.g. in combat)
    hideActive = true

    FindNamedNumbers()
    HideOtherNumbers()

    -- Fallback for other addons: look for a number text next to the button that
    -- equals the current ultimate (a few tries, a few seconds apart)
    if #otherNumbers == 0 and current > 0 and scanAttempts < 5 then
        local now = GetGameTimeMilliseconds()
        if now - lastScan > 3000 then
            scanAttempts = scanAttempts + 1
            lastScan = now
            for _, c in ipairs(FindNearbyNumbers(current)) do
                AddOtherNumber(c)
            end
            HideOtherNumbers()
        end
    end
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------
-- While unlocked, the current/required and bottom texts of both icons are
-- always shown (so they can be grabbed) and they show your REAL ultimate
-- values, even if a text is switched off in the settings. Only when there is nothing real to show (no ultimate slotted) a
-- sample value is used.
local function ApplyTextsUnlocked(part, current, cost)
    local known = cost and cost > 0
    local color = TextColor(current, cost)

    part.value:SetText(known and string.format("%d/%d", current, cost) or string.format("%d/?", current))
    part.value:SetColor(ColorOf(color))
    FitHolder(part.valueHolder)
    part.value:SetHidden(false)

    -- the bottom text follows the chosen mode; if it is set to "Hidden", show the percentage
    local bottom = BottomText(current, cost)
    if not bottom then
        bottom = known and (math.min(100, math.floor(current / cost * 100)) .. "%") or "--"
    end
    part.percent:SetText(bottom)
    part.percent:SetColor(ColorOf(color))
    FitHolder(part.percentHolder)
    part.percent:SetHidden(false)
end

-- Cost of the other bar's ultimate: what we saw while it was on the active
-- bar (includes cost reductions), else the ability's base cost
local function OtherCost(otherId)
    local cost = sv.costs[otherId]
    if cost and cost > 0 then return cost end
    cost = GetAbilityCost(otherId, COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
    return cost > 0 and cost or nil
end

local function ShowUnlockedTexts(current, liveId, liveCost, otherId)
    if liveId then
        ApplyTextsUnlocked(mainPart, current, liveCost)
    else
        ApplyTextsUnlocked(mainPart, 132, 250)  -- sample: no ultimate slotted
    end

    if otherId and otherId ~= 0 then
        ApplyTextsUnlocked(oppPart, current, OtherCost(otherId))
    else
        ApplyTextsUnlocked(oppPart, 250, 250)   -- sample: no ultimate on the other bar
    end
end

Refresh = function()
    if not created then return end

    -- the same ultimate on both bars: the opposite icon would only be a copy
    -- (the live slot can report another id for the same skill, so both ids are compared)
    do
        local bar = GetActiveHotbarCategory()
        local other = (bar == HOTBAR_CATEGORY_PRIMARY) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
        local otherUlt = GetSlotBoundId(ULT_SLOT, other)
        textLayout.sameUlt = settings.hideSameOpposite and otherUlt ~= nil and otherUlt ~= 0
            and (otherUlt == GetSlotBoundId(ULT_SLOT) or otherUlt == GetSlotBoundId(ULT_SLOT, bar))
    end

    ApplyUltPosition()
    ApplyUltCentering()

    -- Disabled: hide everything and stop
    if not settings.enabled then
        UpdateOtherNumbers(0)
        HideAll()
        return
    end

    local current = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
    UpdateOtherNumbers(current)

    -- Current bar (live data) + remember its cost for later
    local liveId, _, liveCost = GetLiveUltimate()
    -- (also under the id the bar itself reports, which can differ, e.g.
    -- Elemental Storm with a staff, so the opposite icon finds it later)
    if liveId and liveCost and liveCost > 0 then
        sv.costs[liveId] = liveCost
        local barId = GetSlotBoundId(ULT_SLOT, GetActiveHotbarCategory())
        if barId and barId ~= 0 then
            sv.costs[barId] = liveCost
        end
    end
    LearnIcon(liveId)

    if liveId then
        ApplyTexts(mainPart, current, liveCost)
    else
        mainPart.value:SetHidden(true)
        mainPart.percent:SetHidden(true)
    end

    -- Ready alert: the same ultimate just became castable
    local ready = liveId ~= nil and liveCost ~= nil and liveCost > 0 and current >= liveCost

    -- glow and green border on your ultimate while it is ready
    -- (flash only when this ultimate itself just became ready)
    local wasReady = textLayout.wasReady
    local flashMain = liveId ~= nil and ready and wasReady[liveId] == false
    if liveId then wasReady[liveId] = ready end
    local highlight = ready and settings.highlightActive
    SetHighlight(mainPart, highlight, flashMain)
    if highlight then
        local c = settings.readyColor
        mainPart.readyFrame:SetEdgeColor(c.r, c.g, c.b, 1)
    end
    mainPart.readyFrame:SetHidden(not highlight)
    local alerted = false
    if liveId and liveId == prevLiveId and ready and not prevReady then
        TriggerAlert()
        alerted = true
    end
    prevLiveId, prevReady = liveId, ready

    -- Opposite bar: icon from the other hotbar, cost from what we remembered
    local activeBar = GetActiveHotbarCategory()
    local otherBar  = (activeBar == HOTBAR_CATEGORY_PRIMARY) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY

    local otherId = GetSlotBoundId(ULT_SLOT, otherBar)
    local hasOther = textLayout.oppActive() and otherId and otherId ~= 0
    if hasOther then
        -- Safety net: a different ultimate must never show the icon your
        -- ultimate button shows; if it would, use the game's own icon for it
        -- (compared with the icon your ultimate SHOULD show, not with what the
        -- button shows, which can lag behind for a moment after a bar swap)
        local tex = GetDisplayIcon(otherBar)
        local activeTex = GetDisplayIcon(activeBar)
        if otherId ~= liveId and tex and activeTex and zo_strlower(tex) == zo_strlower(activeTex) then
            tex = GetSlotTexture(ULT_SLOT, otherBar)
        end
        oppPart.pic:SetTexture(tex)
        oppPart.abilityId = otherId
        local otherCost = OtherCost(otherId)
        ApplyTexts(oppPart, current, otherCost)
        local oppReady = otherCost ~= nil and otherCost > 0 and current >= otherCost
        local flashOpp = oppReady and textLayout.wasReady[otherId] == false
        textLayout.wasReady[otherId] = oppReady
        ApplyOppStyle(oppPart, oppReady, flashOpp)

        -- optional ready alert for the other bar's ultimate (so you know to swap)
        if flashOpp and settings.alertOpposite then
            if not alerted then PlayAlertSound() end
            if settings.alertFlash then FlashPart(oppPart) end
        end
    else
        SetHighlight(oppPart, false)
        oppPart.value:SetHidden(true)
        oppPart.percent:SetHidden(true)
    end
    oppPart.icon:SetHidden(not hasOther)
    if hasOther then
        AlignToSkillRow()
    end
    if hasOther then ApplyOppFree() end

    -- the ultimates traded rows: each row's texts use that row's positions
    local swapped = RowsSwapped()
    if swapped ~= textLayout.swapped then
        textLayout.swapped = swapped
        for _, h in ipairs(holders) do
            ApplyHolderPosition(h)
        end
        RefreshPanel()
    end

    if textsUnlocked then
        ShowUnlockedTexts(current, liveId, liveCost, otherId)
    end
end

-- The game can report the new bar a moment after the swap, so refresh twice
local function RefreshSoon()
    Refresh()
    zo_callLater(Refresh, 100)
    zo_callLater(Refresh, 300)  -- action bar addons can move their rows a bit later
    StartUpdates()
end

-------------------------------------------------------------------------------
-- Lock / unlock the texts
-------------------------------------------------------------------------------
local function LockTexts()
    if not textsUnlocked then return end
    textsUnlocked = false

    for _, h in ipairs(holders) do
        h.win:SetMouseEnabled(false)
        h.win:SetMovable(false)
        h.bg:SetHidden(true)
        ApplyHolderPosition(h)
    end

    ultHandle.win:SetMouseEnabled(false)
    ultHandle.win:SetMovable(false)
    ultHandle.bg:SetHidden(true)
    ultHandle.opp.win:SetMouseEnabled(false)
    ultHandle.opp.win:SetMovable(false)
    ultHandle.opp.bg:SetHidden(true)
    ApplyUltPosition()

    Refresh()
    RefreshPanel()
    StartUpdates()  -- one more update hides the sample timers

    -- Leave the "mouse cursor" HUD again
    if SCENE_MANAGER:IsShowing("hudui") then
        SCENE_MANAGER:ShowBaseScene()
    end
end

local function UnlockTexts(fromMenu)
    if not created then return end
    if textsUnlocked then return end
    if not settings.enabled then
        Print("Turn the tracker on first (/sut on).")
        return
    end

    textsUnlocked = true

    -- Every text gets a plain screen position first, then becomes draggable
    for _, h in ipairs(holders) do
        if not settings.textPosT[KeyOf(h)] then
            AnchorDefault(h)
            CaptureCurrentPosition(h)
        end
        ApplyHolderPosition(h)
        h.win:SetMouseEnabled(true)
        h.win:SetMovable(true)
        h.bg:SetHidden(false)
    end

    -- Same for the ultimate skill itself
    ultDragPos = SavedUltPos() or { x = ultButton:GetLeft(), y = ultButton:GetTop() }
    ultDragMode = textLayout.oppActive()
    ultMoved = false
    ApplyUltPosition()
    ultHandle.win:SetDimensions(ultButton:GetWidth(), ultButton:GetHeight())
    ultHandle.win:SetMouseEnabled(true)
    ultHandle.win:SetMovable(true)
    ultHandle.bg:SetHidden(false)

    Refresh()

    -- and the opposite icon (when it is shown)
    if not oppPart.icon:IsHidden() then
        PlaceOppHandle()
        ultHandle.opp.win:SetMouseEnabled(true)
        ultHandle.opp.win:SetMovable(true)
        ultHandle.opp.bg:SetHidden(false)
    end

    RefreshPanel()
    StartUpdates()

    if fromMenu then
        -- The settings page shows the real bar and already has a mouse cursor,
        -- so the yellow boxes can be dragged right there
        return
    end

    -- From chat: go to the HUD with a mouse cursor so things can be dragged
    SCENE_MANAGER:Show("hudui")
    Print("Unlocked: drag the yellow boxes (the texts, the ultimate skill and the opposite icon). They stay unlocked until you click Lock positions or type /sut lock.")
end

local function ToggleLock(fromMenu)
    if textsUnlocked then
        LockTexts()
    else
        UnlockTexts(fromMenu)
    end
end

local function ResetPositions()
    -- everything back to the defaults in one go
    settings.ultPos = nil
    settings.ultPosNoOpp = nil
    settings.oppOffsetX, settings.oppOffsetY = 0, 0
    LeaveCustomPlacement()
    settings.textPosT = ZO_DeepTableCopy(DEFAULTS.textPosT)

    -- The ultimate goes first (the opposite icon and the texts are placed
    -- relative to it), then the rest. Done twice: the action bar can settle
    -- a moment later.
    local function Apply()
        ultDragPos = nil
        if ultMoved then
            RestoreUltDefault()
            ultMoved = false
        end
        ApplyUltCentering()
        ApplyLayout()
        Refresh()

        for _, h in ipairs(holders) do
            h.dragPos = nil
            AnchorDefault(h)
            if textsUnlocked then CaptureCurrentPosition(h) end
            ApplyHolderPosition(h)
        end

        if textsUnlocked then
            ultDragPos = { x = ultButton:GetLeft(), y = ultButton:GetTop() }
            ultDragMode = textLayout.oppActive()
            ApplyUltPosition()
            PlaceOppHandle()
        end
        RefreshPanel()
    end
    Apply()
    zo_callLater(Apply, 150)
end

-- Plays the alert sound and flashes the ultimate (settings button)
local function TestAlert()
    PlayAlertSound()
    if settings.alertFlash and created then
        FlashPart(mainPart)
    end
end

-------------------------------------------------------------------------------
-- Settings menu (LibAddonMenu-2.0)
-------------------------------------------------------------------------------
local function SettingsChanged()
    ApplyLayout()
    Refresh()
    RefreshPanel()  -- greys options in or out
    StartUpdates()
end

-- Switches between account-wide settings and this character's own settings.
-- The first time a character gets its own settings, it starts as a copy of
-- the account-wide ones, so nothing you changed is lost.
local function SetAccountWide(value)
    sv.useAccountWide = value

    if not value and not charSettings.initialized then
        for key, v in pairs(accountSettings) do
            -- (learned ultimate effects stay account-wide)
            if key ~= "version" and key ~= "learnedUltEffects" and key ~= "migratedFromOld" then
                charSettings[key] = (type(v) == "table") and ZO_DeepTableCopy(v) or v
            end
        end
        charSettings.initialized = true
    end

    settings = value and accountSettings or charSettings

    -- apply the other set of settings right away
    for _, h in ipairs(holders) do
        h.dragPos = nil
        ApplyHolderPosition(h)
    end
    ApplyUltPosition()
    ApplyLayout()
    RefreshSoon()
    RefreshPanel()
end

local function SetEnabled(value)
    settings.enabled = value
    if not value and textsUnlocked then
        LockTexts()
    end
    RefreshSoon()
    RefreshPanel()
end

local function BuildSettingsMenu()
    local LAM = LibAddonMenu2

    local panelData = {
        type = "panel",
        name = "SimpleUltimateTracker",
        displayName = "Simple Ultimate Tracker",
        author = "Kaewro",
        version = "1.0.4",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    panel = LAM:RegisterAddonPanel(PANEL_NAME, panelData)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(p)
        if p == panel then
            ShowBarInMenu(true)
            StartUpdates()
            zo_callLater(Refresh, 50)
        end
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(p)
        if p == panel then ShowBarInMenu(false) end
    end)
    -- also when the whole menu is closed (e.g. with Escape)
    local menuScene = SCENE_MANAGER:GetScene("gameMenuInGame")
    if menuScene then
        menuScene:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_HIDING or newState == SCENE_HIDDEN then ShowBarInMenu(false) end
        end)
    end

    local function ColorPicker(name, key)
        return {
            type = "colorpicker",
            name = name,
            getFunc = function()
                local c = settings[key]
                return c.r, c.g, c.b, c.a
            end,
            setFunc = function(r, g, b, a)
                settings[key] = { r = r, g = g, b = b, a = a }
                SettingsChanged()
            end,
            default = DEFAULTS[key],
        }
    end

    local function Checkbox(name, key, tooltip)
        return {
            type = "checkbox",
            name = name,
            tooltip = tooltip,
            getFunc = function() return settings[key] end,
            setFunc = function(value)
                settings[key] = value
                SettingsChanged()
            end,
            default = DEFAULTS[key],
        }
    end

    local function Slider(name, key, min, max, step)
        return {
            type = "slider",
            name = name,
            min = min, max = max, step = step,
            getFunc = function() return settings[key] end,
            setFunc = function(value)
                settings[key] = value
                SettingsChanged()
            end,
            default = DEFAULTS[key],
        }
    end

    local function Dropdown(name, key, choices)
        return {
            type = "dropdown",
            name = name,
            choices = choices,
            getFunc = function() return settings[key] end,
            setFunc = function(value)
                settings[key] = value
                SettingsChanged()
            end,
            default = DEFAULTS[key],
        }
    end

    local soundDropdown = Dropdown("Alert sound", "alertSound", soundChoices)
    do
        local setFunc = soundDropdown.setFunc
        soundDropdown.setFunc = function(value)
            setFunc(value)
            PlayAlertSound()  -- sample of the chosen sound
        end
    end

    ---------------------------------------------------------------------------
    -- X / Y sliders for everything that can be moved
    ---------------------------------------------------------------------------
    local screenW = math.floor(GuiRoot:GetWidth())
    local screenH = math.floor(GuiRoot:GetHeight())

    -- the text that uses this saved position right now (see KeyOf)
    local function HolderByKey(key)
        for _, h in ipairs(holders) do
            if KeyOf(h) == key then return h end
        end
    end

    -- a text or timer: its saved centre, or where it is right now
    local function TextAxis(key, axis, label, disabled)
        return {
            type = "slider",
            name = label,
            min = 0, max = (axis == "x") and screenW or screenH, step = 1,
            getFunc = function()
                local h = HolderByKey(key)
                if not h then return 0 end
                local pos = SavedTextPos(h)
                if pos then return zo_round(pos[axis]) end
                local cx, cy = h.win:GetCenter()
                return zo_round(((axis == "x") and cx or cy) or 0)
            end,
            setFunc = function(value)
                local h = HolderByKey(key)
                if not h then return end
                local cx, cy = h.win:GetCenter()
                local old = SavedTextPos(h) or { x = cx, y = cy }
                local pos = { x = old.x, y = old.y }
                pos[axis] = value
                SaveTextPos(h, pos.x, pos.y)
                h.dragPos = pos
                ApplyHolderPosition(h)
            end,
            disabled = disabled,
        }
    end

    -- the ultimate skill: its saved top-left corner, or where it is now
    local function UltAxis(axis, label)
        return {
            type = "slider",
            name = label,
            min = 0, max = (axis == "x") and screenW or screenH, step = 1,
            getFunc = function()
                local pos = SavedUltPos()
                if pos then return zo_round(pos[axis]) end
                if not ultButton then return 0 end
                return zo_round((axis == "x") and ultButton:GetLeft() or ultButton:GetTop())
            end,
            setFunc = function(value)
                if not ultButton then return end
                local cur = SavedUltPos() or { x = ultButton:GetLeft(), y = ultButton:GetTop() }
                local pos = { x = cur.x, y = cur.y }
                pos[axis] = value
                SaveUltPos(pos)
                ultDragPos, ultDragMode = pos, textLayout.oppActive()
                ApplyUltPosition()
                Refresh()
            end,
        }
    end

    local noOpposite = function() return not settings.showOpposite end
    local noTimer    = function() return not settings.showTimer end
    local noOppTimer = function() return not settings.showTimer or not settings.showOpposite end
    local noRate     = function() return settings.gainDisplay ~= GAIN.RATE end
    local noEta      = function() return settings.gainDisplay ~= GAIN.ETA end

    -- Greys an option out while a switch is off
    -- Changing how the opposite icon is placed brings back the automatic
    -- placement if you had dragged it somewhere yourself (nothing else moves)
    local function PlacesOpposite(ctrl)
        local setFunc = ctrl.setFunc
        ctrl.setFunc = function(...)
            LeaveCustomPlacement()
            setFunc(...)
            if textsUnlocked then PlaceOppHandle() end
        end
        return ctrl
    end

    local function NeedsOpposite(ctrl)
        ctrl.disabled = function() return not settings.showOpposite end
        return ctrl
    end
    local function NeedsTimer(ctrl)
        ctrl.disabled = function() return not settings.showTimer end
        return ctrl
    end

    local options = {
        {
            type = "checkbox",
            name = "Enable Ultimate Tracker",
            tooltip = "Turns the ultimate values and the opposite bar icon on or off. (Also: /sut on, /sut off)",
            getFunc = function() return settings.enabled end,
            setFunc = function(value) SetEnabled(value) end,
            default = DEFAULTS.enabled,
        },
        {
            type = "checkbox",
            name = "Use account-wide settings",
            tooltip = "ON: all your characters share the same settings. OFF: this character keeps its own settings (starting as a copy of the account-wide ones).",
            getFunc = function() return sv.useAccountWide end,
            setFunc = function(value) SetAccountWide(value) end,
            default = true,
        },
        {
            type = "button",
            name = function() return textsUnlocked and "Lock positions" or "Unlock positions" end,
            func = function() ToggleLock(true) end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset positions",
            isDangerous = true,
            warning = "Puts the ultimate, the opposite icon and all texts back to their default positions.",
            func = function() ResetPositions() RefreshPanel() end,
            width = "half",
        },
        {
            type = "submenu",
            name = "Text",
            controls = {
                Slider("Value text size", "valueSize", 8, 30, 1),
                Slider("Bottom text size", "percentSize", 8, 30, 1),
                Checkbox("Show only in combat", "combatOnly"),
                Checkbox("Show current/required", "showValues"),
                Dropdown("Bottom text", "bottomMode", CHOICES.bottom),
                ColorPicker("Ready color", "readyColor"),
                ColorPicker("Not ready color", "notReadyColor"),
                Checkbox("Highlight ultimate when ready", "highlightActive",
                    "Your ultimate (on the bar you are on) glows and gets a border in the ready color while it is ready, like the opposite icon does."),
                Checkbox("Almost ready color", "nearMaxWarning",
                    "The current/required and bottom texts change colour when your ultimate is almost ready (a % of that ultimate's cost). Each icon uses its own ultimate's cost."),
                (function()
                    local c = Slider("Almost ready at (% of cost)", "nearMaxPercent", 50, 99, 1)
                    c.disabled = function() return not settings.nearMaxWarning end
                    return c
                end)(),
                (function()
                    local c = ColorPicker("Almost ready text color", "nearMaxColor")
                    c.disabled = function() return not settings.nearMaxWarning end
                    return c
                end)(),
            },
        },
        {
            type = "submenu",
            name = "Opposite bar icon",
            controls = {
                Checkbox("Show opposite bar icon", "showOpposite"),
                (function()
                    local c = Dropdown("Placement", "oppPlacement", CHOICES.placement)
                    c.tooltip = "Automatic: with two skill rows (e.g. Fancy Action Bar+, also static bars) each ultimate goes in its own bar's row; with one row the icon goes above your ultimate.\n\nAbove / Below / Left / Right: next to your ultimate on that side.\n\nCustom: where you dragged it yourself (Unlock positions). Pick another option to go back.\n\nThe icon always lines up with the size and spacing of your skills; Offset X/Y fine-tune it."
                    local setFunc = c.setFunc
                    c.setFunc = function(value)
                        if value == "Custom" then
                            -- only by dragging the icon (there is no position to use yet)
                            if not settings.oppPos then RefreshPanel() return end
                        else
                            settings.oppPos = nil
                        end
                        setFunc(value)
                        if textsUnlocked then PlaceOppHandle() end
                    end
                    c.disabled = function() return not settings.showOpposite end
                    return c
                end)(),
                NeedsOpposite(Checkbox("Hide when both bars have the same ultimate", "hideSameOpposite",
                    "The opposite icon is hidden while your other bar has the same ultimate as the bar you are on, since it would only be a copy.")),
                NeedsOpposite(Checkbox("Show tooltip on hover", "oppTooltip")),
                NeedsOpposite(Slider("Size (%)", "oppSize", 50, 100, 5)),
                (function()
                    local c = PlacesOpposite(Slider("Offset X", "oppOffsetX", -screenW, screenW, 1))
                    c.tooltip = "Moves the opposite icon from its automatic place. If you dragged the icon yourself, changing this puts it back in its automatic place first."
                    c.disabled = function() return not settings.showOpposite end
                    return c
                end)(),
                (function()
                    local c = PlacesOpposite(Slider("Offset Y", "oppOffsetY", -screenH, screenH, 1))
                    c.tooltip = "Moves the opposite icon from its automatic place. If you dragged the icon yourself, changing this puts it back in its automatic place first."
                    c.disabled = function() return not settings.showOpposite end
                    return c
                end)(),
                {
                    type = "button",
                    name = "Reset icon position",
                    tooltip = "Puts the opposite icon back in its automatic place after you dragged it yourself. Nothing else is moved.",
                    func = function()
                        LeaveCustomPlacement()
                        SettingsChanged()
                        if textsUnlocked then PlaceOppHandle() end
                    end,
                    disabled = function() return not settings.showOpposite or settings.oppPlacement ~= "Custom" end,
                    width = "half",
                },
                NeedsOpposite(Dropdown("Border", "borderStyle", CHOICES.border)),
                NeedsOpposite(Checkbox("Dim while not castable", "dimOpposite")),
                NeedsOpposite(Checkbox("Highlight while castable", "highlightOpposite")),
            },
        },
        {
            type = "submenu",
            name = "Ultimate timer",
            controls = {
                Checkbox("Show ultimate timer", "showTimer"),
                NeedsTimer(Slider("Timer text size", "timerSize", 8, 40, 1)),
                NeedsTimer(Dropdown("Timer position", "timerPosition", CHOICES.timerPosition)),
                NeedsTimer(ColorPicker("Timer color", "timerColor")),
                Checkbox("Show countdown glow", "showCountdownGlow"),
                (function()
                    local c = ColorPicker("Glow color", "glowColor")
                    c.disabled = function() return not settings.showCountdownGlow end
                    return c
                end)(),
            },
        },
        {
            type = "submenu",
            name = "Ultimate gain",
            controls = {
                (function()
                    local c = Dropdown("Show", "gainDisplay", CHOICES.gain)
                    c.tooltip = "Off: nothing is shown.\n\nGain per second: how much ultimate you gain per second, e.g. +2.4/s.\n\nTime until ready: seconds until your ultimate is ready, e.g. 8s, counting down.\n\nBoth are estimates based on the ultimate you gained in the last 10 seconds, so they change with your rotation and the fight. Hidden while you are not gaining ultimate."
                    return c
                end)(),
                (function()
                    local c = Slider("Gain text size", "rateSize", 8, 30, 1)
                    c.disabled = noRate
                    return c
                end)(),
                (function()
                    local c = Slider("Time text size", "etaSize", 8, 30, 1)
                    c.disabled = noEta
                    return c
                end)(),
                (function()
                    local c = ColorPicker("Color", "gainColor")
                    c.disabled = function() return settings.gainDisplay == "Off" end
                    return c
                end)(),
                (function()
                    local c = Slider("Almost ready at (seconds left)", "gainSoonSeconds", 1, 15, 1)
                    c.tooltip = "Time until ready changes to the almost ready color when the estimated time until your ultimate is ready is this many seconds or less."
                    c.disabled = noEta
                    return c
                end)(),
                (function()
                    local c = ColorPicker("Almost ready color", "gainSoonColor")
                    c.disabled = noEta
                    return c
                end)(),
                (function()
                    local c = ColorPicker("Ready color", "gainReadyColor")
                    c.disabled = noEta
                    return c
                end)(),
            },
        },
        {
            type = "submenu",
            name = "Positions",
            controls = {
                { type = "header", name = "Ultimate skill" },
                UltAxis("x", "X"),
                UltAxis("y", "Y"),

                { type = "header", name = "Ultimate: current/required" },
                TextAxis("mainValue", "x", "X"),
                TextAxis("mainValue", "y", "Y"),
                { type = "header", name = "Ultimate: bottom text" },
                TextAxis("mainPercent", "x", "X"),
                TextAxis("mainPercent", "y", "Y"),
                { type = "header", name = "Ultimate: timer" },
                TextAxis("mainTimer", "x", "X", noTimer),
                TextAxis("mainTimer", "y", "Y", noTimer),
                { type = "header", name = "Ultimate: gain per second" },
                TextAxis("ultRate", "x", "X", noRate),
                TextAxis("ultRate", "y", "Y", noRate),
                { type = "header", name = "Ultimate: time until ready" },
                TextAxis("ultEta", "x", "X", noEta),
                TextAxis("ultEta", "y", "Y", noEta),

                { type = "header", name = "Opposite icon: current/required" },
                TextAxis("oppValue", "x", "X", noOpposite),
                TextAxis("oppValue", "y", "Y", noOpposite),
                { type = "header", name = "Opposite icon: bottom text" },
                TextAxis("oppPercent", "x", "X", noOpposite),
                TextAxis("oppPercent", "y", "Y", noOpposite),
                { type = "header", name = "Opposite icon: timer" },
                TextAxis("oppTimer", "x", "X", noOppTimer),
                TextAxis("oppTimer", "y", "Y", noOppTimer),

                {
                    type = "button",
                    name = "Reset positions",
                    isDangerous = true,
                    warning = "Puts the ultimate, the opposite icon and all texts back to their default positions.",
                    func = function() ResetPositions() RefreshPanel() end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = "Ready alert",
            controls = {
                soundDropdown,
                Checkbox("Flash icon", "alertFlash"),
                Checkbox("Also alert for the opposite ultimate", "alertOpposite",
                    "Also plays the alert (and flashes the opposite icon) when the ultimate on your other bar becomes ready, so you know to swap."),
                {
                    type = "button",
                    name = "Test alert",
                    func = function() TestAlert() end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = "Misc",
            controls = {
                (function()
                    local c = Checkbox("Hide other ultimate number values", "hideOtherNumber")
                    c.tooltip = "Hides the ultimate number that other addons (or the game) show on your ultimate, so only this addon's values are shown.\n\nThis may not work for every addon."
                    return c
                end)(),
            },
        },
    }

    LAM:RegisterOptionControls(PANEL_NAME, options)
end

local function OpenSettings()
    LibAddonMenu2:OpenToPanel(panel)
end

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------
local function OnSlashCommand(arg)
    arg = zo_strlower(zo_strtrim(arg or ""))

    if arg == "" then
        OpenSettings()
    elseif arg == "on" then
        SetEnabled(true)
        Print("Ultimate Tracker |c00ff00enabled|r.")
    elseif arg == "off" then
        SetEnabled(false)
        Print("Ultimate Tracker |cff4444disabled|r.")
    elseif arg == "unlock" then
        UnlockTexts()
    elseif arg == "lock" then
        LockTexts()
    elseif arg == "help" then
        Print("Commands:")
        Print("/sut  - open the settings menu")
        Print("/sut on  - enable the tracker")
        Print("/sut off  - disable the tracker")
        Print("/sut unlock  - unlock the texts and the ultimate skill so you can move them")
        Print("/sut lock  - lock them in place again")
        Print("/sut help  - show this list")
    else
        Print("Unknown command. Type /sut help for a list of commands.")
    end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local function OnPlayerActivated()
    textLayout.isDead = IsUnitDead("player")  -- e.g. after a /reloadui while dead
    if not created then
        CreateUI()
    end
    RefreshSoon()
    -- once the action bar has its final layout, texts can be placed relative
    -- to their icons (and old screen positions converted)
    zo_callLater(function()
        if not created then return end

        -- texts moved with an older version were saved as screen positions,
        -- matching the layout of that version: convert them in that layout,
        -- so they keep their place next to their icon
        local hasOld = false
        for _, p in pairs(settings.textPosT) do
            if p.dx == nil then hasOld = true end
        end
        if hasOld then
            textLayout.legacy = true
            Refresh()
        end

        textLayout.layoutReady = true
        for _, h in ipairs(holders) do
            ApplyHolderPosition(h)
        end

        if hasOld then
            textLayout.legacy = false
            Refresh()
        end
    end, 600)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- Remembered ultimate costs (per character) and settings (account-wide)
    sv              = ZO_SavedVars:NewCharacterIdSettings("SimpleUltimateTrackerSV", 1, nil, { costs = {}, useAccountWide = true })
    -- account-wide settings are saved per server (EU / NA / PTS); the character
    -- ones are already, because character ids are unique per server
    accountSettings = ZO_SavedVars:NewAccountWide("SimpleUltimateTrackerSV", 1, "Settings", DEFAULTS, GetWorldName())

    -- One-time move of settings saved by older versions (before they were
    -- saved per server) into this server's settings, then remove the old copy
    local raw = SimpleUltimateTrackerSV
    local oldAccount = raw and raw["Default"] and raw["Default"][GetDisplayName()]
    local oldSettings = oldAccount and oldAccount["$AccountWide"] and oldAccount["$AccountWide"]["Settings"]
    if oldSettings and not accountSettings.migratedFromOld then
        for key, value in pairs(oldSettings) do
            if key ~= "version" then
                accountSettings[key] = (type(value) == "table") and ZO_DeepTableCopy(value) or value
            end
        end
        accountSettings.migratedFromOld = true
        oldAccount["$AccountWide"]["Settings"] = nil
    end
    sv.icons = nil  -- icons learned by older versions (could be wrong, no longer used)
    accountSettings.learnedUltEffects = accountSettings.learnedUltEffects or {}
    learnedEffects = accountSettings.learnedUltEffects
    charSettings    = ZO_SavedVars:NewCharacterIdSettings("SimpleUltimateTrackerSV", 1, "CharSettings", DEFAULTS)
    settings        = sv.useAccountWide and accountSettings or charSettings

    -- A sound that no longer exists in the game falls back to the default
    if settings.alertSound ~= "None" and not soundKeys[settings.alertSound] then
        settings.alertSound = DEFAULTS.alertSound
    end

    local validTimerPos = false
    for _, v in ipairs(CHOICES.timerPosition) do
        if settings.timerPosition == v then validTimerPos = true end
    end
    if not validTimerPos then settings.timerPosition = DEFAULTS.timerPosition end
    -- Older versions had Position + "Line up with skill row" + "Follow action
    -- bar rows"; they are now one setting, Placement (converted once)
    for _, t in ipairs({ accountSettings, charSettings }) do
        if not t.placementMigrated then
            t.placementMigrated = true
            if t.oppPos then
                t.oppPlacement = "Custom"
            elseif t.alignToSkills == false or t.followRows == false then
                t.oppPlacement = t.oppPosition or "Above"
            else
                t.oppPlacement = "Automatic"
            end
            t.alignToSkills, t.followRows, t.oppPosition = nil, nil, nil
        end
    end
    local validPlacement = false
    for _, v in ipairs(CHOICES.placement) do
        if settings.oppPlacement == v then validPlacement = true end
    end
    if not validPlacement or (settings.oppPlacement == "Custom" and not settings.oppPos) then
        settings.oppPlacement = DEFAULTS.oppPlacement
    end

    if settings.gainDisplay ~= GAIN.RATE and settings.gainDisplay ~= GAIN.ETA then
        settings.gainDisplay = "Off"
    end

    local validBorder = false
    for _, v in ipairs(CHOICES.border) do
        if settings.borderStyle == v then validBorder = true end
    end
    if not validBorder then settings.borderStyle = DEFAULTS.borderStyle end

    loadTime = GetFrameTimeSeconds()
    BuildSettingsMenu()
    SLASH_COMMANDS["/sut"] = OnSlashCommand

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    -- Ultimate value changes
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Power", EVENT_POWER_UPDATE, function()
        OnUltPowerChanged()
        Refresh()
    end)
    -- (EVENT_EFFECT_CHANGED is only registered right after a cast: WatchEffects)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "_Power", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_ULTIMATE)

    -- Bar swap / skill changes
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, RefreshSoon)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, function()
        if created then
            UpdateCombatOnly()
            StartUpdates()
        end
    end)
    -- hide the texts while dead, show them again when you are alive
    local function OnDeathChanged(isDead)
        textLayout.isDead = isDead
        if created then
            UpdateCombatOnly()
            StartUpdates()
        end
    end
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_DEAD, function() OnDeathChanged(true) end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ALIVE, function() OnDeathChanged(false) end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Slots", EVENT_ACTION_SLOTS_FULL_UPDATE, RefreshSoon)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Hotbars", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, RefreshSoon)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Used", EVENT_ACTION_SLOT_ABILITY_USED, OnUltimateUsed)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Slot", EVENT_ACTION_SLOT_UPDATED, function(_, slotNum)
        if slotNum == ULT_SLOT then RefreshSoon() end
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
