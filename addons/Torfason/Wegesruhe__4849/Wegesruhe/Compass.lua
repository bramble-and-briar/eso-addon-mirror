local WR = Wegesruhe

WR.compassOriginalAlpha = {}
WR.compassHooked = false

function WR:InitializeCompass()
    if not COMPASS or not COMPASS.container then
        return
    end

    for _, pinType in ipairs(self.managedCompassPins) do
        local a, b, c, d = COMPASS.container:GetAlphaDropoffBehavior(pinType)
        self.compassOriginalAlpha[pinType] = { a, b, c, d }
    end

    if not self.compassHooked and ZO_CompassContainer and ZO_CompassContainer.IsCenterOveredPinSuppressed then
        self.compassHooked = true
        self.originalCenterOverSuppressed = ZO_CompassContainer.IsCenterOveredPinSuppressed
        local original = self.originalCenterOverSuppressed
        function ZO_CompassContainer:IsCenterOveredPinSuppressed(pinIndex, ...)
            local pinType = self:GetCenterOveredPinType(pinIndex)
            if pinType and not WR:IsCompassPinVisible(pinType) then
                return true
            end
            return original(self, pinIndex, ...)
        end
    end
end

function WR:RefreshCompass()
    if not COMPASS or not COMPASS.container then
        return
    end

    -- Compute quest eligibility once per refresh, not every compass frame.
    if self.RefreshQuestCompassEligibility then
        self:RefreshQuestCompassEligibility()
    end

    for _, pinType in ipairs(self.managedCompassPins) do
        local visible = self:IsCompassPinVisible(pinType)
        if visible then
            local values = self.compassOriginalAlpha[pinType]
            if values then
                COMPASS.container:SetAlphaDropoffBehavior(pinType, values[1], values[2], values[3], values[4])
            end
        else
            -- A true zero can remove the related floating marker in ESO. Tiny values keep
            -- the systems independent while making the compass marker effectively invisible.
            COMPASS.container:SetAlphaDropoffBehavior(pinType, 0.001, 0.001, 0, 1)
        end
    end

    -- Quest-area animations are not normal compass pins. Their display is
    -- controlled by the guarded PlayQuestAreaPinOutAnimation hook in
    -- QuestFilters.lua; refresh only when those filter settings actually change.
    if self.ApplyQuestAreaFilters then
        self:ApplyQuestAreaFilters()
    end
end
