-- Precios de Tamriel Trade Centre bajo cada objeto.
-- Si tienes "Tamriel Trade Centre Simple Price", se usa SU propia función
-- (TTCSP.DisplayPrice) con SUS ajustes: mismo precio, mismo verde/rojo, y
-- cualquier actualización de ese addon o de los precios de TTC se refleja sola.
-- Si no lo tienes, se calcula igual que él a partir de TamrielTradeCentrePrice.
local NWUI = NWUI
local P = {}
NWUI.Price = P

-- Solo números enteros: "21,166.21" -> "21,166"
local function Integers(text)
    if type(text) ~= "string" then return text end
    return (text:gsub("%.%d+", ""))
end
P.Integers = Integers

local function Fmt(n)
    n = math.floor((n or 0) + 0.5)
    if TamrielTradeCentre and TamrielTradeCentre.FormatNumber then
        local ok, s = pcall(TamrielTradeCentre.FormatNumber, TamrielTradeCentre, n, 0)
        if ok and s then return Integers(s) end
    end
    return ZO_CommaDelimitNumber(n)
end

function P.HasTTC()
    return TamrielTradeCentrePrice ~= nil and TamrielTradeCentrePrice.GetPriceInfo ~= nil
end

function P.HasTTCSP()
    return TTCSP ~= nil and type(TTCSP.DisplayPrice) == "function" and TTCSP.vars ~= nil and TTCSP.name ~= nil
end

function P.Enabled()
    return NWUI.sv.inv.showPrices and P.HasTTC()
end

local function UseTTCSP()
    local src = NWUI.sv.inv.priceSource
    return P.HasTTCSP() and (src == "auto" or src == "ttcsp")
end

local function Place(label, c)
    label:ClearAnchors()
    label:SetAnchor(TOP, c, BOTTOM, 0, 0)
    label:SetFont(NWUI.F.price)
    label:SetDrawLevel(9)
    label:SetWidth(c:GetWidth() + 8)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    if label.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
    label:SetHidden(false)
end

-- Caché de precios de la sesión: cada objeto se consulta UNA vez.
-- Los datos de TTC solo cambian al recargar la interfaz, así que no se pierde nada.
local cache = {}
function P.ClearCache() cache = {} end

-- Con TTC Simple Price se llama a SU función sobre un control oculto ("sonda")
-- y se copian su texto y su color: mismo resultado, sin repetir el trabajo.
local probe
local function Probe()
    if not probe then
        probe = WINDOW_MANAGER:CreateControl("NWUI_PriceProbe", GuiRoot, CT_CONTROL)
        probe:SetHidden(true)
    end
    return probe
end

local function FromTTCSP(link, stack)
    local p = Probe()
    local ok = pcall(TTCSP.DisplayPrice, p, link, stack, 0, 0)
    local m = ok and p:GetNamedChild(TTCSP.name) or nil
    if not m then return nil end
    local text = Integers(m:GetText() or "")
    local r, g, b = 1, 1, 1
    if m.GetColor then
        local okc, cr, cg, cb = pcall(m.GetColor, m)
        if okc and cr then r, g, b = cr, cg, cb end
    end
    return { text = text, r = r, g = g, b = b }
end

local function FromOwn(link, stack)
    local s = NWUI.sv.inv
    local ok, info = pcall(TamrielTradeCentrePrice.GetPriceInfo, TamrielTradeCentrePrice, link)
    if not ok or type(info) ~= "table" or info.Avg == nil then return { text = "" } end
    local mult = s.priceStack and (stack or 1) or 1
    local price, text
    if s.priceType == "TTC" then
        price = (info.SuggestedPrice or 0) * mult
        text = Fmt(price) .. " ~ " .. Fmt(price * 1.25)
    else
        price = (info.Avg or 0) * mult
        text = Fmt(price)
    end
    if price ~= 0 and price >= (s.priceMin or 0) then
        return { text = text, r = 0, g = 1, b = 0 }
    elseif s.priceShowLow then
        return { text = text, r = 1, g = 0, b = 0 }
    end
    return { text = "" }
end

local function Lookup(link, stack)
    local useSP = UseTTCSP()
    local perStack
    if useSP then perStack = TTCSP.vars and TTCSP.vars.stackMultiplier else perStack = NWUI.sv.inv.priceStack end
    local key = (useSP and "sp|" or "own|") .. link .. "|" .. (perStack and (stack or 1) or 1)
    local e = cache[key]
    if e == nil then
        e = (useSP and FromTTCSP(link, stack)) or FromOwn(link, stack)
        cache[key] = e
    end
    return e
end

function P.Apply(c, d)
    -- etiquetas viejas que TTC Simple Price pudo dejar en la casilla
    local marker = P.HasTTCSP() and c.GetNamedChild and c:GetNamedChild(TTCSP.name) or nil
    if marker and marker.SetText then marker:SetText("") end
    if not c.price then return end
    if not (P.Enabled() and d.hasItem and (d.kind == "item" or d.kind == "bank" or d.kind == "guild" or d.kind == "craft")) then
        c.price:SetText("")
        return
    end
    local link = GetItemLink(d.bagId, d.slotIndex)
    if not link or link == "" then
        c.price:SetText("")
        return
    end
    local e = Lookup(link, d.stack or 1)
    if e and e.text ~= "" then
        Place(c.price, c)
        c.price:SetColor(e.r, e.g, e.b, 1)
        c.price:SetText(e.text)
    else
        c.price:SetText("")
    end
end
