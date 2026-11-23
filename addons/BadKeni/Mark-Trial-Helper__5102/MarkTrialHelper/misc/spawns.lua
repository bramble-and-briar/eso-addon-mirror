-- Оповещения о спавне опасных врагов
local AH = _G.MarkTrialHelper
local spawnList = {}
local spawnTimer = nil

local WAVE_MOBS = {
    ["Infuser"] = { text = "|cFF0000Инфьюзер|r", sound = SOUNDS.TELVAR_GAINED },
    ["Spellthief"] = { text = "|cFF00FFСпеллтиф|r", sound = SOUNDS.TELVAR_GAINED },
    ["Flameshaper"] = { text = "|cFF6600Флеймшейпер|r", sound = SOUNDS.TELVAR_GAINED },
    ["Brewmaster"] = { text = "|cFF00FFБрюмастер|r", sound = SOUNDS.TELVAR_GAINED },
    ["Stormcaller"] = { text = "|c00FFFFШтормовик|r", sound = SOUNDS.TELVAR_GAINED },
    ["Lightbringer"] = { text = "|cE2E8A9Светонос|r", sound = SOUNDS.TELVAR_GAINED },
    ["Imp"] = { text = "|cFFFF00Имп|r", sound = SOUNDS.TELVAR_GAINED },
    ["Scrapper"] = { text = "|cFFFF00Скрэппер|r", sound = SOUNDS.TELVAR_GAINED },
    ["Conduit"] = { text = "|c00FFFFПроводник|r", sound = SOUNDS.TELVAR_GAINED },
    ["Arquebus"] = { text = "|cFF6600Сфера|r", sound = SOUNDS.TELVAR_GAINED },
    ["Sun-Eater"] = { text = "|c4169E1Пожиратель солнца|r", sound = SOUNDS.TELVAR_GAINED },
    ["Archer"] = { text = "|c00FF00Лучник|r", sound = SOUNDS.TELVAR_GAINED },
}

function AH.ShowWave(text)
    if not AH.Vars.TrackSpawns then return end
    
    local frame = AH.FrameObjectPool:AcquireObject()
    frame:SetName("Wave")
    frame:SetDimensions(600, 60)
    frame:SetPosition()
    frame:SetBackgroundColour(0, 0, 0, 0.8)
    frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, AH.Vars.WavePosition and AH.Vars.WavePosition.left or 0, AH.Vars.WavePosition.top or 350)
    frame:SetColour(1, 1, 1, 1)
    frame.control:SetDrawTier(DT_HIGH)
    frame.control:SetMouseEnabled(false)
    frame:SetText(text)
    frame:SetHidden(false)
    
    -- Автоскрытие через 7 секунд
    zo_callLater(function()
        if frame then
            frame:SetHidden(true)
            AH.FrameObjectPool:ReleaseObject(frame)
        end
    end, 7000)
end

function AH.OnSpawn(change, _, _, _, unitTag, _, _, _, _, _, _, _, _, unitName, unitId, abilityId)
    if not AH.Vars.TrackSpawns then return end
    if change ~= EFFECT_RESULT_GAINED then return end
    
    -- Проверяем только в Бесконечном Архиве
    if not IsInstanceEndlessDungeon() then return end
    
    for key, info in pairs(WAVE_MOBS) do
        if unitName:find(key) then
            AH.ShowWave(info.text)
            if AH.Vars.EnableSounds then
                PlaySound(info.sound)
            end
            return
        end
    end
end