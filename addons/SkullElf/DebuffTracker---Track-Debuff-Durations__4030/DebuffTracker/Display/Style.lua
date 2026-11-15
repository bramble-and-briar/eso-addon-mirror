-- Shared visual helpers: fonts, the per-style look of windows/rows, and state colors.

local DT = DebuffTracker
local Style = DT.Style
local C = DT.Const
local U = DT.Util

-- Window/row look per bar style (icons/text/alert displays use "clean" chrome unless classic).
-- stripe: an extra marker bar at the row's left edge for the target. Off in every style: the
-- highlight border already marks the target, and the stripe sat where the fill starts, so it looked
-- like a piece of the bar that never drained.
Style.LOOKS = {
    classic = {
        windowEdge = { 0, 0, 0, 1 }, track = false, stripe = false,
        iconFrame = false, divider = false, uptimeInTitle = true,
        highlightEdge = { 1, 1, 0, 1 }, highlightSize = 2, titleFont = "ZoFontGameSmall",
        titleColor = { 1, 1, 1, 1 }, headerScale = 1, gap = 2, padX = 5, padTop = 0, padBottom = 2,
    },
    clean = {
        windowEdge = { 0.29, 0.32, 0.36, 1 }, track = true, stripe = false,
        iconFrame = true, divider = true, uptimeInTitle = false,
        highlightEdge = { 1, 0.88, 0.5, 1 }, highlightSize = 1, titleFont = "$(BOLD_FONT)|14|soft-shadow-thick",
        titleColor = { 0.91, 0.89, 0.82, 1 }, headerScale = 1, gap = 3, padX = 6, padTop = 5, padBottom = 4,
    },
    compact = {
        windowEdge = { 0, 0, 0, 0 }, track = true, stripe = false,
        iconFrame = false, divider = false, uptimeInTitle = false,
        highlightEdge = { 1, 0.88, 0.5, 1 }, highlightSize = 1, titleFont = "$(BOLD_FONT)|12|soft-shadow-thick",
        titleColor = { 0.91, 0.89, 0.82, 1 }, headerScale = 0.7, gap = 2, padX = 4, padTop = 1, padBottom = 3,
    },
}

function Style.Look(ds)
    return Style.LOOKS[ds.style] or Style.LOOKS.clean
end

-- size 0 = automatic from the given reference size
-- the font size in pixels Style.Font picks (the classic style's game font is about 14)
function Style.FontSize(ds, refSize, ratio, minSize, maxSize)
    local size = ds.fontSize
    if not size or size <= 0 then
        if ds.style == "classic" and ds.fontFace == "MEDIUM_FONT" and ratio == nil then return 14 end
        size = U.Clamp(math.floor(refSize * (ratio or 0.56) + 0.5), minSize or 10, maxSize or 18)
    end
    return size
end

-- Text in a row is centred on its line box, which also holds room for descenders (g, y, p) below the
-- letters -- so names and numbers look a pixel or two too high. This many pixels down puts them in the
-- visual middle.
function Style.TextNudge(size)
    return math.max(1, math.floor(size * 0.08 + 0.5))
end

-- The small numbers in an icon's corners (stacks, a proc's buff time, players count, resource %):
-- sized from the ICON only, so a big "Font size" for the timer doesn't blow them up (Tony).
function Style.IconFont(ds, iconSize, ratio, minSize, maxSize)
    local size = U.Clamp(math.floor(iconSize * ratio + 0.5), minSize or 9, maxSize or 24)
    if ds.fontEffect == "none" then return string.format("$(%s)|%d", ds.fontFace, size) end
    return string.format("$(%s)|%d|%s", ds.fontFace, size, ds.fontEffect)
end

function Style.Font(ds, refSize, ratio, minSize, maxSize)
    local size = ds.fontSize
    if not size or size <= 0 then
        size = U.Clamp(math.floor(refSize * (ratio or 0.56) + 0.5), minSize or 10, maxSize or 18)
    end
    if ds.style == "classic" and ds.fontFace == "MEDIUM_FONT" and ds.fontSize <= 0 and ratio == nil then
        return "ZoFontGameSmall"
    end
    if ds.fontEffect == "none" then
        return string.format("$(%s)|%d", ds.fontFace, size)
    end
    return string.format("$(%s)|%d|%s", ds.fontFace, size, ds.fontEffect)
end

-- the tracker's font face and outline at a given size
function Style.FontAt(ds, size)
    if ds.fontEffect == "none" then return string.format("$(%s)|%d", ds.fontFace, size) end
    return string.format("$(%s)|%d|%s", ds.fontFace, size, ds.fontEffect)
end

-- fraction: 1 = full (just applied), 0 = about to expire
function Style.Color(ds, fraction)
    if ds.colorMode == "solid" then return ds.colorSolid end
    if ds.colorMode == "tiers" then
        if fraction > 0.66 then return ds.colorFull end
        if fraction > 0.33 then return ds.colorMid end
        return ds.colorEnd
    end
    if fraction > 0.5 then return U.LerpColor(ds.colorMid, ds.colorFull, (fraction - 0.5) * 2) end
    return U.LerpColor(ds.colorEnd, ds.colorMid, fraction * 2)
end

Style.INACTIVE = { 0.35, 0.35, 0.38, 1 }
Style.EXPIRED = { 0.80, 0.22, 0.22, 1 }    -- "it just ended" entries (Keep it shown after it ends)

function Style.SetColor(control, c, alphaMul)
    control:SetColor(c[1], c[2], c[3], (c[4] or 1) * (alphaMul or 1))
end

-- Remaining fraction of a state (1 = full). Untimed states are full; resources use pct.
function Style.Fraction(s, now, ds)
    -- entries that fill up toward a moment (resource ticks): empty at the start, full at the end
    if s.fillUp and (s.duration or 0) > 0 then return U.Clamp((now - (s.start or now)) / s.duration, 0, 1) end
    if s.pct and s.max then return U.Clamp(s.pct / 100, 0, 1) end
    if not s.active then return 1 end
    -- "Timer counts down to: ready" (Tony: bars stayed "separated"): one run from the proc to ready
    if ds and ds.timerTo == "ready" and s.wholeStart then
        local finish = ((s.phase == 1 or s.cycleWhole) and (s.cdEnd or 0) > (s.expire or 0)) and s.cdEnd or s.expire
        if finish and finish > s.wholeStart then
            return U.Clamp((finish - now) / (finish - s.wholeStart), 0, 1)
        end
    end
    if (s.duration or 0) > 0 and (s.expire or 0) > 0 then
        return U.Clamp((s.expire - now) / s.duration, 0, 1)
    end
    return 1
end

-- Blink/pulse alpha for this frame (1 = steady).
function Style.PulseAlpha(nowMs, minAlpha)
    local phase = 0.5 + 0.5 * math.cos(nowMs / 360 * math.pi)
    return (minAlpha or 0.4) + (1 - (minAlpha or 0.4)) * phase
end

function Style.ShouldBlink(ds, s, now)
    if not ds.blink or not s.active or s.cooldown then return false end
    if (s.expire or 0) <= 0 or (s.duration or 0) <= 0 then return false end
    return (s.expire - now) <= ds.blinkThreshold
end
