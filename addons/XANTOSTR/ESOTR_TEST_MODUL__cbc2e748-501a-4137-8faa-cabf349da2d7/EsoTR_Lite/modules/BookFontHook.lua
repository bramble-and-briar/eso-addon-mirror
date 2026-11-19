-- -----------------------------------------------------------------
-- XANTOS-TR TARAFINDAN YAZILMIŞTIR
-- ESO TR Book Font Hook (PC + PS5 / Gamepad)
-- -----------------------------------------------------------------
EsoTR_Lite_BookHook_Guard = EsoTR_Lite_BookHook_Guard or {}
if EsoTR_Lite_BookHook_Guard.Active then return end
EsoTR_Lite_BookHook_Guard.Active = true

-- -----------------------------------------------------------------
-- FONT TANIMLARI
-- -----------------------------------------------------------------
local antiqueFont     = "EsoTR_Lite/fonts/ProseAntique_Regular_tr.slug"
local handwrittenFont = "EsoTR_Lite/fonts/Handwritten_bold_tr.slug"
local tabletFont      = "EsoTR_Lite/fonts/Univers57.slug"

local titleFontBook   = "EsoTR_Lite/fonts/Univers55.slug"
local titleFontSafe   = "EsoTR_Lite/fonts/Univers57.slug"

-- -----------------------------------------------------------------
-- 🔑 EsoTR_Lite SavedVars OKUMA (DOĞRU YÖNTEM)
-- -----------------------------------------------------------------
local EsoTR_Lite_SV

local function GetBookScale()
    if not EsoTR_Lite_SV then
        EsoTR_Lite_SV = ZO_SavedVars:NewAccountWide(
            "EsoTR_Lite_SavedVars",
            1,
            nil,
            { bookFontScale = 0 }
        )
    end

    local v = EsoTR_Lite_SV.bookFontScale
    if type(v) ~= "number" then return 0 end
    return v
end

-- -----------------------------------------------------------------
local function ApplyBookHook()
    if not GetBookMediumFontInfo then return end

    if not EsoTR_Lite_BookHook_Guard.Original then
        EsoTR_Lite_BookHook_Guard.Original = GetBookMediumFontInfo
    end

    if GetBookMediumFontInfo == EsoTR_Lite_BookHook_Guard.Hooked then
        return
    end

    EsoTR_Lite_BookHook_Guard.Hooked = function(mediumId, isGamepad)
        local titleFontName, titleFontSize, titleFontStyle,
              bodyFontName,  bodyFontSize,  bodyFontStyle,
              r, g, b, a, sr, sg, sb, sa =
            EsoTR_Lite_BookHook_Guard.Original(mediumId, isGamepad)

        -- GAMEPAD / PS5 OKUNABİLİRLİK (MEVCUT)
        if isGamepad then
            titleFontSize = titleFontSize + 2
            bodyFontSize  = bodyFontSize  + 1
        end

        -- 🔤 KULLANICI FONT SCALE (0–12)
        local scale = GetBookScale()
        titleFontSize = titleFontSize + scale
        bodyFontSize  = bodyFontSize  + scale

        -- 📚 MEDIUM FONT SEÇİMİ
        if mediumId == 1 or mediumId == 2 or mediumId == 3
        or mediumId == 8 or mediumId == 9 then
            titleFontName = titleFontBook
            bodyFontName  = antiqueFont

        elseif mediumId == 4 or mediumId == 5 or mediumId == 6
        or mediumId == 10 or mediumId == 11 then
            titleFontName = handwrittenFont
            bodyFontName  = handwrittenFont

        elseif mediumId == 7 then
            titleFontName = tabletFont
            bodyFontName  = tabletFont
        end

        return titleFontName, titleFontSize, titleFontStyle,
               bodyFontName,  bodyFontSize,  bodyFontStyle,
               r, g, b, a, sr, sg, sb, sa
    end

    GetBookMediumFontInfo = EsoTR_Lite_BookHook_Guard.Hooked
end

-- -----------------------------------------------------------------
local function WakeWatchdog()
    ApplyBookHook()
end

EVENT_MANAGER:RegisterForEvent("EsoTR_Lite_BookHook_AL", EVENT_ADD_ON_LOADED, WakeWatchdog)
EVENT_MANAGER:RegisterForEvent("EsoTR_Lite_BookHook_PA", EVENT_PLAYER_ACTIVATED, WakeWatchdog)
EVENT_MANAGER:RegisterForEvent("EsoTR_Lite_BookHook_SB", EVENT_SHOW_BOOK, WakeWatchdog)
