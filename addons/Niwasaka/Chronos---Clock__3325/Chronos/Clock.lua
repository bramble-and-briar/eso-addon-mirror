local Chronos = _G['Chronos']

local ChronosClockFragment = ZO_HUDFadeSceneFragment:New(ChronosClock)
local LMP = LibMediaProvider
LMP:Register("background", "ESO Status", "EsoUI/art/performance/statusmetermunge.dds")

function Chronos:UpdateTime()
    local timeString = Chronos:GetTimeString()
    if (ChronosClockText:GetText() ~= timeString) then
        ChronosClockText:SetText(timeString)
    end
end

function Chronos:UpdateTimeZone()
    if not self.db.showClockUTC then
        ChronosClockTimeZoneText:SetHidden(true)
        return
    end

    local offset = Chronos:GetSelectedTimeZoneOffset()
    local absHours = math.floor(math.abs(offset))
    local minutes = math.floor((math.abs(offset) - absHours) * 60)
    local sign = offset >= 0 and "+" or "-"
    local fractiontext = string.format("%02d", minutes)

    ChronosClockTimeZoneText:SetHidden(false)
    ChronosClockTimeZoneText:SetText(string.format("UTC%s%d:%s", sign, absHours, fractiontext))
end

function Chronos:UpdateClockStyle()
    local font = LMP:Fetch("font", self.db.clockTextFont)
    local fontStr = string.format("%s|%d|%s", font, self.db.clockFontSize, self.db.clockFontOutline)
    local timeZonefontStr = string.format("%s|%d|%s", font, self.db.clockUTCFontSize, self.db.clockFontOutline)
    local texture = LMP:Fetch("background", self.db.clockBackground)

    if self.db.showClockBG == true then
        ChronosClockBG:SetHidden(false)
        ChronosClockBG:SetTexture(texture)
        local r, g, b = self:ConvHexToRGB(self.db.clockBackgroundColor)
        ChronosClockBG:SetColor(r, g, b, 1)
        ChronosClockBG:SetAlpha(self.db.clockBackgroundAlpha / 100)
    else
        ChronosClockBG:SetHidden(true)
    end

    ChronosClockText:SetFont(fontStr)
    local r, g, b = self:ConvHexToRGB(self.db.clockFontColor)
    ChronosClockText:SetColor(r, g, b, 1)
    local width, height = ChronosClockText:GetTextDimensions()

    local kaese, nacho = 0, 0

    ChronosClockText:ClearAnchors()
    if self.db.showClockUTC then
        ChronosClockTimeZoneText:SetFont(timeZonefontStr)
        local ur, ug, ub = self:ConvHexToRGB(self.db.clockUTCColor)
        ChronosClockTimeZoneText:SetColor(ur, ug, ub, 1)

        kaese, nacho = ChronosClockTimeZoneText:GetTextDimensions()
        ChronosClockText:SetAnchor(CENTER, ChronosClock, CENTER, 0, -nacho / 2)
    else
        ChronosClockText:SetAnchor(CENTER, ChronosClock, CENTER, 0, 0)
    end

    ChronosClock:SetDimensions(math.max(width, kaese) + 40, height + nacho + 18)
end

function Chronos:SetClockPreview(previewOpen)
    self.clockPreview = previewOpen
    self:UpdateAnchors()
end

function Chronos:UpdateAnchors()
    ChronosClock:ClearAnchors()
    if self.clockPreview then
        ChronosClock:SetAnchor(LEFT, LAMAddonSettingsWindow, RIGHT, 50, 0)
        ChronosClock:SetHidden(not self.db.showClock)
    else
        if self.db.clockOffset == nil then
            ChronosClock:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, 0)
        else
            ChronosClock:SetAnchor(CENTER, GuiRoot, TOPLEFT, self.db.clockOffset.x, self.db.clockOffset.y)
        end
        ChronosClock:SetHidden(not ChronosClockFragment:IsShowing())
    end
    ChronosClock:SetMovable(not self.clockPreview)
end

function Chronos:InitClock()
    EVENT_MANAGER:UnregisterForUpdate("ChronosClockUpdate")
    HUD_SCENE:RemoveFragment(ChronosClockFragment)
    HUD_UI_SCENE:RemoveFragment(ChronosClockFragment)

    if self.db.showClock == true then
        HUD_SCENE:AddFragment(ChronosClockFragment)
        HUD_UI_SCENE:AddFragment(ChronosClockFragment)

        EVENT_MANAGER:RegisterForUpdate("ChronosClockUpdate", 2000, function()
            self:UpdateTime()
        end)

        self:UpdateTimeZone()
        self:UpdateTime()
        self:UpdateClockStyle()

        zo_callLater(function()
            Chronos:UpdateClockStyle()
        end, 500)
    end

    self:UpdateAnchors()
end

function Chronos:MigrateUTCFontSize()
    if self.db.clockUTCDelta ~= nil then
        self.db.clockUTCFontSize = math.max(self.db.clockFontSize - self.db.clockUTCDelta, 6)
        self.db.clockUTCDelta = nil
    end
end

function Chronos:SaveClockPosition()
    local centerx, centery = ChronosClock:GetCenter()
    self.db.clockOffset = {
        x = centerx,
        y = centery
    }
end
