-- ESO Adventurer Suite - Infinite Archive extended helper compatibility layer.
-- Feature behavior adapted from the user-provided ArchiveHelper v1.4.2 reference.
_G.EASArchiveHelper = _G.EASArchiveHelper or {}
local AH = _G.EASArchiveHelper

local function colour(r,g,b,a)
    if ZO_ColorDef and ZO_ColorDef.New then return ZO_ColorDef:New(r,g,b,a or 1) end
    return { Colorize = function(_,t) return tostring(t or "") end, UnpackRGBA=function() return r,g,b,a or 1 end }
end
local LC = {}
LC.Red=colour(1,0.2,0.2,1); LC.Green=colour(0.2,1,0.2,1); LC.White=colour(1,1,1,1); LC.Yellow=colour(1,1,0.25,1)
LC.Cyan=colour(0.2,1,1,1); LC.ZOSBlue=colour(0.35,0.7,1,1); LC.ZOSGold=colour(1,0.78,0.2,1); LC.ZOSGreen=colour(0.35,0.9,0.45,1); LC.ZOSPurple=colour(0.75,0.45,1,1)
function LC.Format(v) if v==nil then return "" end; if type(v)=="number" and GetString then local ok,r=pcall(GetString,v); if ok and r then return ZO_CachedStrFormat("<<C:1>>",r) end end; return ZO_CachedStrFormat("<<C:1>>",tostring(v or "")) end
function LC.Space(n) return string.rep(" ", tonumber(n) or 1) end
function LC.BuildList(t)
    local out={}
    for _,v in pairs(t or {}) do
        if type(v)=="number" then out[v]=true
        elseif type(v)=="string" then
            local found=false
            for n in v:gmatch("%d+") do out[tonumber(n)]=true; found=true end
            if not found then out[v:lower()]=true end
        elseif type(v)=="table" then
            local x=v.id or v.name or v[1]
            if type(x)=="number" then out[x]=true elseif x then out[tostring(x):lower()]=true end
        end
    end
    return out
end
function LC.Filter(t, pred) local out={}; for _,v in ipairs(t or {}) do if not pred or pred(v) then out[#out+1]=v end end; return out end
function LC.GetIconTexture(path, c, w, h)
    if zo_iconFormatInheritColor then return zo_iconFormatInheritColor(path,w or 24,h or 24) end
    if zo_iconFormat then return zo_iconFormat(path,w or 24,h or 24) end
    return tostring(path or "")
end
function LC.GetAddonVersion() return "Suite" end
function LC.ScreenAnnounce(title, message)
    if ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "%s: %s", tostring(title or "Infinite Archive"), tostring(message or ""))
    elseif d then d(tostring(title or "Infinite Archive")..": "..tostring(message or "")) end
end
AH.LC = LC
