-- Arclight Taunt | Shared urgency colors and custom palette
local A = ArclightTaunt
local base = {}
for key, value in pairs(A.C) do base[key] = value end
local fields = {"customSafeColor", "customWarningColor", "customDangerColor"}
local function HexColor(hex)
    return {tonumber(hex:sub(1,2),16)/255, tonumber(hex:sub(3,4),16)/255, tonumber(hex:sub(5,6),16)/255, 1}
end
local function ValidHex(value)
    return type(value)=="string" and #value==6 and value:match("^%x+$") ~= nil
end
local function Scale(color, factor, alpha)
    return {color[1]*factor, color[2]*factor, color[3]*factor, alpha or 1}
end
local function Luminance(color)
    local function linear(v) return v<=0.04045 and v/12.92 or ((v+0.055)/1.055)^2.4 end
    return 0.2126*linear(color[1])+0.7152*linear(color[2])+0.0722*linear(color[3])
end
local function Readable(color, background, contrast)
    -- Adjust numeric text against the brightest solid surface in its stage.
    -- The fills keep their palette, and the text won't flash when a fill
    -- recedes from behind the timer.
    local required = contrast * (Luminance(background) + 0.05)
    if Luminance(color) + 0.05 >= required then return color end
    local low, high = 0, 1
    local result = {color[1],color[2],color[3],1}
    for _=1,10 do
        local mix=(low+high)/2
        for i=1,3 do result[i]=color[i]+(1-color[i])*mix end
        if Luminance(result) + 0.05 >= required then high=mix else low=mix end
    end
    for i=1,3 do result[i]=color[i]+(1-color[i])*high end
    return result
end

function A.NormalizePalette()
    local saved=A.saved
    if saved.colorProfile~="arclight" and saved.colorProfile~="custom" then
        saved.colorProfile="arclight"
    end
    for _,key in ipairs(fields) do
        saved[key]=ValidHex(saved[key]) and saved[key]:upper() or A.defaults[key]
    end
end

function A.ApplyAlertPalette(kind, alert)
    if not alert or not alert.backgroundControl then return end
    local opacity=A.saved.bossAlertOpacity/100
    if alert.paletteRevision==A.paletteRevision and alert.paletteOpacity==opacity then return end
    local early=kind=="early"
    local alternate=A.paletteProfile~="arclight"
    local edge=early and A.C.safe or (alternate and A.C.danger or A.C.alertEdge)
    local hair=early and A.C.alertEarlyHairline or A.C.alertHairline
    alert.backgroundControl:SetTexture(early and A.BOSS_EARLY_TEXTURE or A.BOSS_WARNING_TEXTURE)
    -- Preserve the body texture's authored dark RGB and transparency.
    alert.backgroundControl:SetColor(1,1,1,opacity)
    if alert.accent then A.SetColor(alert.accent,edge,opacity) end
    if alert.edge then A.SetColor(alert.edge,edge) end
    if alert.timerFill then A.SetColor(alert.timerFill,edge) end
    if alert.topLine then A.SetColor(alert.topLine,hair,.8) end
    if alert.divider then
        A.SetColor(alert.divider,{.55,.61,.68,.28})
    end
    if alert.title then A.SetColor(alert.title,early and A.C.alertEarlyTitle or A.C.alertTitle) end
    if alert.track then
        A.SetColor(alert.track,{.20,.24,.29,.60})
    end
    alert.paletteRevision,alert.paletteOpacity=A.paletteRevision,opacity
end

function A.ApplyPalette(refresh)
    A.NormalizePalette()
    local C=A.C
    for key,value in pairs(base) do C[key]=value end
    local profile=A.saved.colorProfile
    local colors
    if profile=="custom" then colors={A.saved.customSafeColor,A.saved.customWarningColor,A.saved.customDangerColor} end
    A.paletteProfile=profile
    if colors then
        C.safe,C.warning,C.danger=HexColor(colors[1]),HexColor(colors[2]),HexColor(colors[3])
        C.highDanger=C.danger
        C.warningRow,C.dangerRow=Scale(C.warning,0.10),Scale(C.danger,0.12)
        C.fullSafe,C.fullWarning,C.fullDanger=Scale(C.safe,0.40,0.64),Scale(C.warning,0.40,0.64),Scale(C.danger,0.40,0.64)
        C.highSafeRow,C.highWarningRow,C.highDangerRow=Scale(C.safe,0.18),Scale(C.warning,0.20),Scale(C.danger,0.22)
        C.highFullSafe,C.highFullWarning,C.highFullDanger=Scale(C.safe,0.44),Scale(C.warning,0.44),Scale(C.danger,0.44)
        C.alertHairline,C.alertEarlyHairline=C.danger,C.safe
        C.alertTitle,C.alertEarlyTitle=C.white,C.white
    end
    local contrast = colors and 7 or 4.5
    C.timeSafe = Readable(C.safe, C.highFullSafe, contrast)
    C.timeWarning = Readable(C.warning, C.highFullWarning, contrast)
    C.timeDanger = Readable(C.highDanger, C.highFullDanger, contrast)
    A.paletteRevision=(A.paletteRevision or 0)+1
    if refresh~=false then
        if A.ApplyMedia then A.ApplyMedia() end
        for kind,alert in pairs(A.bossAlerts) do A.ApplyAlertPalette(kind,alert) end
        A.Tick()
    end
end
function A.SetColorProfile(profile)
    if profile~="arclight" and profile~="custom" then return end
    if A.saved.colorProfile==profile then return end
    A.saved.colorProfile=profile
    A.ApplyPalette()
end
function A.GetCustomUrgencyColor(key)
    return unpack(HexColor(A.saved[key]))
end
function A.SetCustomUrgencyColor(key,r,g,b)
    local allowed=false
    for _,field in ipairs(fields) do if field==key then allowed=true end end
    if not allowed then return end
    local values={r,g,b}
    local fallback=HexColor(A.defaults[key])
    for i=1,3 do values[i]=math.floor(A.FiniteBoundedNumber(values[i],fallback[i],0,1)*255+0.5) end
    A.saved[key]=string.format("%02X%02X%02X",unpack(values))
    if A.saved.colorProfile=="custom" then A.ApplyPalette() end
end
function A.ResetCustomUrgencyColors()
    for _,key in ipairs(fields) do A.saved[key]=A.defaults[key] end
    if A.saved.colorProfile=="custom" then A.ApplyPalette() end
end
