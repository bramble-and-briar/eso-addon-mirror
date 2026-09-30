local ADDON_NAME = "GuildTraderCaption"

local function GetGuildTraderName()
    local unitTag = "reticleover"

    -- Это вообще не торговец — ничего не делаем.
    if not IsUnitGuildKiosk(unitTag) then
        return nil
    end

    -- Получаем Caption торговца.
    local caption = GetUnitCaption(unitTag)

    if not caption or caption == "" then
        return nil
    end

    -- В Caption у нас:
    -- "Гильдейский торговец (White Eagle Pact)"
    --
    -- Забираем только содержимое скобок.
    local guildName = caption:match("%((.-)%)")

    return guildName
end

local function AddGuildNameToReticle()
    local guildName = GetGuildTraderName()

    if not guildName then
        return
    end

    local unitName = GetUnitName("reticleover")

    if not unitName or unitName == "" then
        return
    end

    -- Добавляем название ГИ второй строкой.
    RETICLE.interactContext:SetText(
        unitName .. "\n" .. guildName
    )
end

local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(
        ADDON_NAME,
        EVENT_ADD_ON_LOADED
    )

    -- Выполняем нашу проверку после того,
    -- как штатный интерфейс ESO обновил Reticle.
    SecurePostHook(
        RETICLE,
        "UpdateInteractText",
        AddGuildNameToReticle
    )
end

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_ADD_ON_LOADED,
    OnAddOnLoaded
)