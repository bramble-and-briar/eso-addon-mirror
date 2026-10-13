if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS


function FCOChangeStuff.tooltipBorderSizeHack()
    --[[
        ItemTooltip:SetDimensionConstraints(532, 0, 532, 1440)
        PopupTooltip:SetDimensionConstraints(532, 0, 532, 1440)
        ComparativeTooltip1:SetDimensionConstraints(600, 0, 600, 8192)
        ComparativeTooltip2:SetDimensionConstraints(600, 0, 600, 8192)

        ComparativeTooltip1:SetScale(0.875)
        ComparativeTooltip2:SetScale(0.875)
    ]]

    local settings = FCOChangeStuff.settingsVars.settings
    --Toltip border size
    local widthNormal = 416 --2021-01-04
    local heightMax = 1440
    local heightMaxComparative = 8192

    local itemBorderSize = settings.tooltipSizeItemBorder or widthNormal
    ItemTooltip:SetDimensionConstraints(itemBorderSize, 0, itemBorderSize, heightMax)

    local popupBorderSize = settings.tooltipSizePopupBorder or widthNormal
    PopupTooltip:SetDimensionConstraints(popupBorderSize, 0, popupBorderSize, heightMax)

    local comparativeBorderSize = settings.tooltipSizeComparativeBorder or widthNormal
    ComparativeTooltip1:SetDimensionConstraints(comparativeBorderSize, 0, comparativeBorderSize, heightMaxComparative)
    ComparativeTooltip2:SetDimensionConstraints(comparativeBorderSize, 0, comparativeBorderSize, heightMaxComparative)
end

function FCOChangeStuff.tooltipScalingHack()
    local settings = FCOChangeStuff.settingsVars.settings
    --Scaling the tooltips
    local scaleNormal = 1
    local itemScale = scaleNormal
    local popupScale = scaleNormal
    local comparativeScale = scaleNormal
    if settings.tooltipSizeItemScaleHackPercentage < 100 or settings.tooltipSizeItemScaleHackPercentage > 100 then
        itemScale = settings.tooltipSizeItemScaleHackPercentage / 100
        if itemScale < 0.01 then itemScale = 0.01 end
        if itemScale > 1.5 then itemScale = 1.5 end
    end
    if settings.tooltipSizePopupScaleHackPercentage < 100 or settings.tooltipSizePopupScaleHackPercentage > 100  then
        popupScale = settings.tooltipSizePopupScaleHackPercentage / 100
        if popupScale < 0.01 then popupScale = 0.01 end
        if popupScale > 1.5 then popupScale = 1.5 end
    end
    if settings.tooltipSizeComparativeScaleHackPercentage < 100 or settings.tooltipSizeComparativeScaleHackPercentage > 100  then
        comparativeScale = settings.tooltipSizeComparativeScaleHackPercentage / 100
        if comparativeScale < 0.01 then comparativeScale = 0.01 end
        if comparativeScale > 1.5 then comparativeScale = 1.5 end
    end
    ItemTooltip:SetScale(itemScale)
    PopupTooltip:SetScale(popupScale)
    ComparativeTooltip1:SetScale(comparativeScale)
    ComparativeTooltip2:SetScale(comparativeScale)
end


function FCOChangeStuff.tooltipSizeHacks()
    FCOChangeStuff.tooltipBorderSizeHack()
    FCOChangeStuff.tooltipScalingHack()
end

--Changes related to tooltips
function FCOChangeStuff.tooltipChanges()
    FCOChangeStuff.tooltipSizeHacks()
end