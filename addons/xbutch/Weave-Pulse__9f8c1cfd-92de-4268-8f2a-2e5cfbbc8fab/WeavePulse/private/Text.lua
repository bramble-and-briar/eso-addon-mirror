-- Adapted from CombatMetronome 1.7.7 / DariansUtilities 1.8.7.
-- Original authors: Darianopolis and barny. Artistic License 2.0.
-- Upstream: DariansUtilities/utility/Text.lua. See third-party/UPSTREAM.md for modifications.

local Util = WeavePulse.Util
Util.Text = Util.Text or { }

local log = Util.log

function Util.Text.getFontString(family, size, style)

    family = family or "$(CHAT_FONT)"
    size = size or 10
    style = style or "outline"
    return string.format("%s|%u|%s", family, size, style)
end

function Util.Text.formatNumberCompact(value)

    if value > 100000 then

        return string.format("%.1fM", value / 1000000)
    end

    if value > 100 then

        return string.format("%.1fk", value / 1000)
    end

    return string.format("%i", value)
end

function Util.Text.CropZOSString(zosString, formatter)

    if formatter == "ability" then
        return zo_strformat(SI_ABILITY_NAME, zosString)
    elseif formatter == "name" then
        return zo_strformat(SI_TOOLTIP_UNIT_NAME, zosString)
    elseif formatter == "item" then
        return zo_strformat(SI_TOOLTIP_ITEM_NAME, zosString)
    elseif formatter == "collectible" then
        return zo_strformat(SI_COLLECTIBLE_NAME_FORMATTER, zosString)
    elseif formatter == "synergy" then
        return zo_strformat(SI_USE_SYNERGY, zosString)
    end
end
