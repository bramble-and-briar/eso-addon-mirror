local CB = ERUI_CustomBuffs
local WM = WINDOW_MANAGER

local auraIDCounter = 1

local function FormatTime(remaining)
    if remaining <= 0 then
        return ""
    elseif remaining < 60 then
        return string.format("%d", math.floor(remaining + 1))
    elseif remaining < 3600 then
        return string.format("%dm", math.floor((remaining / 60) + 0.5))
    else
        return string.format("%dh", math.floor(remaining / 3600))
    end
end

local function SortAuras(a, b)
    if a.isPassive ~= b.isPassive then
        return a.isPassive
    end
    if not a.isPassive and a.finish ~= b.finish then
        return a.finish > b.finish
    end
    return a.auraName > b.auraName
end

-- Player frame: buffs first, then debuffs; inside each group the usual order
local function SortPlayerAuras(a, b)
    local aDebuff = a.effectType == BUFF_EFFECT_TYPE_DEBUFF
    local bDebuff = b.effectType == BUFF_EFFECT_TYPE_DEBUFF
    if aDebuff ~= bDebuff then
        return bDebuff
    end
    return SortAuras(a, b)
end

local function OnAuraMouseEnter(aura)
    InitializeTooltip(InformationTooltip, aura, BOTTOM, 0, -5, TOP)
    if aura.buffSlot and aura.buffSlot > 0 then
        InformationTooltip:SetBuff(aura.buffSlot, aura.unitTag)
    elseif DoesAbilityExist(aura.abilityID) then
        InformationTooltip:SetAbilityId(aura.abilityID)
    else
        SetTooltipText(InformationTooltip, aura.auraName)
    end
    InformationTooltip:AddVerticalPadding(8)
    InformationTooltip:AddLine("ID: " .. tostring(aura.abilityID), "ZoFontWinH5", 0.7, 0.7, 0.7, CENTER)
end

local function OnAuraMouseExit()
    ClearTooltip(InformationTooltip)
end

local function OnAuraMouseUp(aura, button, upInside)
    if aura.unitTag ~= "player" then return end
    if button ~= MOUSE_BUTTON_INDEX_RIGHT or not upInside or aura.effectType ~= BUFF_EFFECT_TYPE_BUFF then return end

    for i = 1, GetNumBuffs("player") do
        local _, _, _, buffSlot, _, _, _, _, _, _, abilityId, canClickOff = GetUnitBuffInfo("player", i)
        if abilityId == aura.abilityID and canClickOff then
            CancelBuff(buffSlot)
            break
        end
    end
end

local function CreateAuraControl(parent)
    local aura = WM:CreateControl(nil, parent, CT_CONTROL)
    aura.auraID = auraIDCounter
    aura.unitTag = parent.unitTag
    auraIDCounter = auraIDCounter + 1

    aura:SetDimensions(32, 32)
    aura:SetAlpha(0.9)
    aura:SetMouseEnabled(true)
    aura:SetHandler("OnMouseEnter", OnAuraMouseEnter)
    aura:SetHandler("OnMouseExit", OnAuraMouseExit)
    aura:SetHandler("OnMouseUp", OnAuraMouseUp)

    aura.border = WM:CreateControl(nil, aura, CT_TEXTURE)
    aura.border:SetTexture("EldenRingUI/Textures/ERIcon.dds")
    aura.border:SetDimensions(34, 34)
    aura.border:SetAnchor(CENTER)
    aura.border:SetDrawLevel(0)

    aura.icon = WM:CreateControl(nil, aura, CT_TEXTURE)
    aura.icon:SetDimensions(26, 26)
    aura.icon:SetAnchor(CENTER)
    aura.icon:SetAlpha(0.8)
    aura.icon:SetDrawLevel(1)

    aura.stacks = WM:CreateControl(nil, aura, CT_LABEL)
    aura.stacks:SetFont("$(GAMEPAD_BOLD_FONT)|16|outline")
    aura.stacks:SetColor(0.9, 0.6, 0.1, 0.9)
    aura.stacks:SetAnchor(TOPRIGHT, aura, TOPRIGHT, -4, 1)
    aura.stacks:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    aura.stacks:SetDrawLevel(4)

    aura.timer = WM:CreateControl(nil, aura, CT_LABEL)
    aura.timer:SetFont("$(GAMEPAD_BOLD_FONT)|16|soft-shadow-thick")
    aura.timer:SetColor(0.9, 0.9, 0.9, 0.9)
    aura.timer:SetAnchor(TOP, aura, BOTTOM, 0, 0)
    aura.timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    aura.timer:SetDrawLevel(4)

    return aura
end

function CB:CreateDisplayFrame(name, unitTag, growLeft)
    local df = WM:CreateControl(name, GuiRoot, CT_TOPLEVELCONTROL)
    df:SetDimensions(32, 32)
    df:SetMouseEnabled(false)
    df:SetMovable(false)

    df.unitTag = unitTag
    df.aurasActive = {}
    df.aurasInactive = {}
    df.aurasSorted = {}
    df.activeTimed = {}

    function df:AddOrUpdateAura(flagBurst, auraName, start, finish, stacks, icon, effectType, abilityId, buffSlot)
        local aura = self.aurasActive[abilityId]
        if not aura then
            aura = table.remove(self.aurasInactive, 1) or CreateAuraControl(self)
            self.aurasActive[abilityId] = aura
            table.insert(self.aurasSorted, aura)
        end

        aura.auraName = CB.FormatName(auraName)
        aura.abilityID = abilityId
        aura.buffSlot = buffSlot
        aura.effectType = effectType
        aura.start = start
        aura.finish = finish
        aura.stacksCount = stacks or 0
        aura.isPassive = (start == finish) or (finish <= 0)

        aura.icon:SetTexture(icon)
        aura.stacks:SetText(aura.stacksCount > 0 and tostring(aura.stacksCount) or "")

        if effectType == BUFF_EFFECT_TYPE_DEBUFF and self.unitTag == "player" then
            aura.border:SetColor(1, 0.3, 0.3, 1)
        else
            aura.border:SetColor(1, 1, 1, 1)
        end

        local currentTime = GetGameTimeMilliseconds() / 1000
        if not aura.isPassive and finish > currentTime then
            aura.timer:SetText(FormatTime(finish - currentTime))
            self.activeTimed[aura.auraID] = aura
        else
            aura.timer:SetText("")
            self.activeTimed[aura.auraID] = nil
        end

        aura:SetHidden(false)

        if not flagBurst then
            self:UpdateDisplay()
        end
    end

    function df:RemoveAura(abilityId, flagBurst)
        local aura = self.aurasActive[abilityId]
        if not aura then return end

        aura:SetHidden(true)
        self.aurasActive[abilityId] = nil
        self.activeTimed[aura.auraID] = nil

        for i, sortedAura in ipairs(self.aurasSorted) do
            if sortedAura.auraID == aura.auraID then
                table.remove(self.aurasSorted, i)
                break
            end
        end

        table.insert(self.aurasInactive, aura)

        if not flagBurst then
            self:UpdateDisplay()
        end
    end

    function df:ReleaseAllAuras()
        for abilityId in pairs(self.aurasActive) do
            self:RemoveAura(abilityId, true)
        end
        self:UpdateDisplay()
    end

    function df:UpdateDisplay()
        table.sort(self.aurasSorted, self.unitTag == "player" and SortPlayerAuras or SortAuras)

        for i, aura in ipairs(self.aurasSorted) do
            aura:ClearAnchors()
            if growLeft then
                aura:SetAnchor(TOPRIGHT, self, TOPRIGHT, -(i - 1) * 40, 0)
            else
                aura:SetAnchor(TOPLEFT, self, TOPLEFT, (i - 1) * 40, 0)
            end
        end
    end

    local nextUpdate = 0
    df:SetHandler("OnUpdate", function(_, updateTime)
        if updateTime < nextUpdate then return end
        nextUpdate = updateTime + 0.05

        for _, aura in pairs(df.activeTimed) do
            local remaining = aura.finish - updateTime
            if remaining <= 0 then
                df:RemoveAura(aura.abilityID)
            else
                aura.timer:SetText(FormatTime(remaining))
            end
        end
    end)

    return df
end