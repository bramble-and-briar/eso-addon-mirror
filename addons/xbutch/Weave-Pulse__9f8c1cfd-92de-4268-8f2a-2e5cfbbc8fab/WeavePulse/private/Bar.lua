-- Adapted from CombatMetronome 1.7.7 / DariansUtilities 1.8.7.
-- Original authors: Darianopolis and barny. Artistic License 2.0.
-- Upstream: DariansUtilities/controls/Bar.lua. See third-party/UPSTREAM.md for modifications.

local Util = WeavePulse.Util
Util.Bar = Util.Bar or { }
local Bar = Util.Bar

local log = Util.log

local count = 0

function Bar:New(name, parent)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    count = count + 1
    o.index = count
    o.id = (name or "WeavePulse.Util.Bar").."["..tostring(o.index).."]"

    o.segments = { }
    o.sortable = { }

    o.xOffset = 0
    o.yOffset = 0

    o.background = Util.Controls:New(CT_BACKDROP, o.id..".Background", parent or GuiRoot)

    o.align = CENTER

    return o
end

function Bar:UpdateSegment(key, segment)
    local existing = self.segments[key]
    if not existing then
        self.segments[key] = segment
        self.sortable[#self.sortable + 1] = segment

        if not segment.progress then
            segment.progress = 0
        end

        segment.bars = { }
        segment.key = key

        for j = 1, 2 do
            local left = j == 1
            local bar = Util.Controls:New(CT_BACKDROP, self.id..".Segment["..tostring(key).."]."..(left and "L" or "R"), self.background)
            bar.innerTarget = left and TOPLEFT or TOPRIGHT
            bar.outerTarget = left and BOTTOMRIGHT or BOTTOMLEFT
            bar.direction = left and -1 or 1
            segment.bars[j] = bar
        end
    else
        segment.bars = nil

        for k, v in pairs(segment) do
            existing[k] = v
        end
    end

    return existing or segment
end

function Bar:RemoveSegment(key, segment)
    local existing = self.segments[key]

    if existing then
        for _, b in ipairs(existing.bars) do WINDOW_MANAGER:RemoveControl(existing.bars) end
        self.segments[key] = nil
    end
end

function Bar:Update()
    table.sort(self.sortable, function(a, b) return (not a.clip) and (b.clip or a.progress < b.progress) end)

    local maximum = self.sortable[#self.sortable].progress

    local offset = 0
    local offsetMult = (self.align == CENTER and 0.5) or 1

    local topAlign   = (self.align == CENTER and TOP)    or (self.align == LEFT  and TOPLEFT)    or TOPRIGHT
    local botAlign   = (self.align == CENTER and BOTTOM) or (self.align == LEFT  and BOTTOMLEFT) or BOTTOMRIGHT
    local hide       = (self.align == LEFT   and 1)      or (self.align == RIGHT and 2)

    local width = self.background:GetWidth()

    for _, s in ipairs(self.sortable) do
        local color = s.colorEnd and Util.Vectors.mix(s.color, s.colorEnd, s.progress) or s.color

        local nextOffset = math.min(s.progress, maximum) * width * offsetMult

        for i, b in ipairs(s.bars) do
            b:ClearAnchors()
            if i ~= hide then
                b:SetCenterColor(unpack(color))
                b:SetAnchor(b.innerTarget, self.frame, topAlign, b.direction * offset, 0)
                b:SetAnchor(b.outerTarget, self.frame, botAlign, b.direction * nextOffset, 0)
            end
        end

        offset = nextOffset
    end

end

function Bar:SetHidden(state)
    self.background:SetHidden(state)
end
