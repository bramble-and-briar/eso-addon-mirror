-- Comando de chat (/vigilant) y nombres de los atajos de teclado.

local VG = Vigilant
local U = VG.Utils
local L = VG.L
local Cmd = {}
VG.Commands = Cmd

local function Help()
    VG.Print(L.HELP_HEADER, VG.version)
    for _, line in ipairs(L.HELP) do VG.Chat(line) end
end

-- Lista los bufos de una unidad con su ID, para añadir los que no están en el catálogo.
function Cmd.Scan(unitTag)
    if unitTag == "" then unitTag = "player" end
    if not DoesUnitExist(unitTag) then
        VG.Print(L.UNIT_NOT_FOUND, unitTag)
        return
    end
    local n = GetNumBuffs(unitTag)
    VG.Print(L.SCAN_HEADER, n, U.UnitName(unitTag))
    local now = GetFrameTimeSeconds()
    for i = 1, n do
        local name, _, endTime, _, _, icon, _, _, _, _, abilityId = GetUnitBuffInfo(unitTag, i)
        local rem = endTime > now and (" |c999999" .. U.FormatTime(endTime - now) .. "s|r") or ""
        local iconText = icon ~= "" and zo_iconFormat(icon, 18, 18) or ""
        VG.Chat(string.format("  %s |cFFFF00%d|r %s%s", iconText, abilityId,
            U.FormatAbility(name), rem))
    end
end

-- Comprueba que los IDs del catálogo siguen dando el bufo esperado. Solo se puede
-- comparar el nombre en el cliente en inglés; en otros idiomas se muestra para revisarlo.
local function Check()
    local english = GetCVar("language.2") == "en"
    local bad = 0
    for _, b in ipairs(VG.Catalog.BUFFS) do
        for _, id in ipairs(b.ids) do
            local name = U.AbilityName(id)
            local ok = name ~= nil and (not english or name == b.en)
            if not ok then bad = bad + 1 end
            if not ok or not english then
                VG.Chat(string.format("  %s%d|r %s -> %s", ok and "|c00FF00" or "|cFF4444",
                    id, b.en, name or "?"))
            end
        end
    end
    VG.Print(bad == 0 and L.CHECK_OK or L.CHECK_BAD, bad)
end

local function List()
    local cols = VG.Tracker.columns
    if #cols == 0 then
        VG.Print(L.NO_BUFFS)
        return
    end
    VG.Print(L.LIST_HEADER, #cols)
    for _, col in ipairs(cols) do
        VG.Chat(string.format("  %s %s%s", zo_iconFormat(col.icon, 18, 18), col.name,
            col.custom and " |c999999(" .. L.CUSTOM_TAG .. ")|r" or ""))
    end
end

local function Handle(args)
    local cmd, rest = U.Trim(args):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "" then
        VG.Toggle()
    elseif cmd == "help" or cmd == "?" then
        Help()
    elseif cmd == "lock" then
        VG.Panel.SetLocked(true)
        VG.Print(L.LOCKED)
    elseif cmd == "unlock" then
        VG.Panel.SetLocked(false)
        VG.Print(L.UNLOCKED)
    elseif cmd == "grid" or cmd == "summary" then
        VG.Panel.SetLayout(cmd)
    elseif cmd == "add" then
        if rest == "" then VG.Print(L.USAGE_ADD) else VG.Catalog.AddCustom(rest) end
    elseif cmd == "remove" or cmd == "del" then
        if rest == "" then VG.Print(L.USAGE_REMOVE) else VG.Catalog.RemoveCustom(rest) end
    elseif cmd == "list" then
        List()
    elseif cmd == "scan" then
        Cmd.Scan(rest)
    elseif cmd == "reset" then
        VG.ResetUptime()
        VG.Print(L.UPTIME_RESET_DONE)
    elseif cmd == "check" then
        Check()
    elseif cmd == "browse" or cmd == "catalog" then
        VG.Browser.Open()
    elseif cmd == "settings" or cmd == "config" then
        VG.Settings.Open()
    else
        Help()
    end
end

function Cmd.Init()
    SLASH_COMMANDS["/vigilant"] = Handle
end

ZO_CreateStringId("SI_BINDING_NAME_VIGILANT_TOGGLE", L.BINDING_TOGGLE)
ZO_CreateStringId("SI_BINDING_NAME_VIGILANT_LOCK", L.BINDING_LOCK)
