-- Motor: monta el runtime de cada aura y la evalúa periódicamente.

local OA = OmniAura
local T = OA.Triggers

local E = { runtime = {} }
OA.Engine = E

local UPDATE_NAME = "OmniAura_Update"
local UPDATE_MS = 100
local PREVIEW_CYCLE = 10

local function CheckLoad(aura, inCombat)
    local load = aura.load
    if not load then return true end
    if load.combat == "in" and not inCombat then return false end
    if load.combat == "out" and inCombat then return false end
    return true
end

-- logic = "all" (todos los triggers activos) | "any" (al menos uno).
-- El primer trigger activo aporta el estado que se muestra.
local function Evaluate(rt, ctx)
    local aura = rt.aura
    local triggers = aura.triggers or {}
    if #triggers == 0 then return false end

    local any, all, primary = false, true, nil
    for i, trig in ipairs(triggers) do
        local trt = rt.triggers[i]
        local active, state = false, nil
        if trt then active, state = trt.tt.Check(trig, trt, ctx) end
        if active then
            any = true
            primary = primary or state
        else
            all = false
        end
    end

    local show
    if aura.logic == "any" then show = any else show = all end
    return show, primary
end

local function PreviewState(rt, now)
    local trt = rt.triggers[1]
    return {
        name = rt.aura.name,
        icon = trt and trt.icon,
        expires = now + PREVIEW_CYCLE - (now % PREVIEW_CYCLE),
        duration = PREVIEW_CYCLE,
        stacks = 3, value = 75, max = 100, percent = 0.75,
    }
end

function E.UpdateAura(rt, ctx, inCombat)
    local aura, now = rt.aura, ctx.now
    local show, state = false, nil

    if OA.unlocked or OA.previewId == aura.id then
        show, state = true, PreviewState(rt, now)
    elseif OA.editorOpen then
        -- Mientras se edita no se muestran las auras activas, solo la que se ubica.
        show = false
    elseif aura.enabled ~= false and CheckLoad(aura, inCombat) then
        show, state = Evaluate(rt, ctx)
    end

    if show and state then
        state.auraName = aura.name
        state.name = state.name or aura.name
        rt.display:Update(state, now)
        if not rt.shown and not OA.unlocked and not OA.previewId and aura.sound and SOUNDS[aura.sound] then
            PlaySound(SOUNDS[aura.sound])
        end
    else
        show = false
    end

    if show ~= rt.shown then
        rt.display:SetShown(show)
        rt.shown = show
    end
end

function E.OnUpdate()
    local now = GetFrameTimeSeconds()
    local ctx = T.NewContext(now)
    local inCombat = IsUnitInCombat("player")
    for id, rt in pairs(E.runtime) do
        if not rt.broken then
            local ok, err = pcall(E.UpdateAura, rt, ctx, inCombat)
            if not ok then
                -- Un aura rota se desactiva para no inundar de errores cada 100 ms.
                rt.broken = true
                rt.display:SetShown(false)
                OA.Print(OA.L.AURA_ERROR, rt.aura.name or "?", tostring(err))
            end
        end
    end
end

function E.SetupAura(aura)
    local rt = { aura = aura, triggers = {}, shown = false }
    rt.display = OA.Display.Acquire(aura)

    if aura.enabled ~= false then
        for i, trig in ipairs(aura.triggers or {}) do
            local tt = T.types[trig.type]
            if tt then
                local trt = { tt = tt }
                if tt.Prepare then tt.Prepare(trig, trt) end
                if tt.Register then tt.Register(trig, trt, string.format("OmniAura_A%d_T%d", aura.id, i)) end
                rt.triggers[i] = trt
            end
        end
    end

    E.runtime[aura.id] = rt
end

function E.Teardown()
    for _, rt in pairs(E.runtime) do
        for _, trt in pairs(rt.triggers) do
            if trt.tt.Unregister then trt.tt.Unregister(trt) end
        end
    end
    E.runtime = {}
    OA.Display.ReleaseAll()
end

-- Llamar tras cualquier cambio en OA.sv.auras.
-- Ámbito de cada aura: "account" (todos los personajes, por defecto) o "character"
-- (solo el personaje que la configuró, guardado en aura.owner).
function E.IsAvailable(aura)
    return aura.scope ~= "character" or aura.owner == GetCurrentCharacterId()
end

function E.SetScope(aura, scope)
    if scope == "character" then
        aura.scope = "character"
        aura.owner = GetCurrentCharacterId()
        aura.ownerName = zo_strformat("<<1>>", GetUnitName("player"))
    else
        aura.scope, aura.owner, aura.ownerName = nil, nil, nil
    end
end

function E.Rebuild()
    E.Teardown()
    for _, aura in pairs(OA.sv.auras) do
        if E.IsAvailable(aura) then E.SetupAura(aura) end
    end
end

---------------------------------------------------------------------------
-- Alta, copia y borrado de auras
---------------------------------------------------------------------------
local function CountAuras()
    local n = 0
    for _ in pairs(OA.sv.auras) do n = n + 1 end
    return n
end

function E.CreateAura(name, triggers, display)
    local sv = OA.sv
    local id = sv.nextId
    sv.nextId = id + 1

    local n = CountAuras()
    display.x = display.x or zo_round(((n % 8) - 3.5) * 70)
    display.y = display.y or -220

    local aura = {
        id = id,
        name = name,
        enabled = true,
        logic = "all",
        triggers = triggers,
        display = display,
        load = { combat = "any" },
    }
    sv.auras[id] = aura
    E.Rebuild()
    return aura
end

function E.DuplicateAura(id)
    local src = OA.sv.auras[id]
    if not src then return nil end
    local copy = OA.Utils.DeepCopy(src)
    copy.display = copy.display or {}
    copy.display.x = (copy.display.x or 0) + 60
    local aura = E.CreateAura((copy.name or "?") .. OA.L.COPY_SUFFIX, copy.triggers or {}, copy.display)
    aura.logic, aura.load, aura.sound, aura.enabled = copy.logic, copy.load, copy.sound, copy.enabled
    aura.scope, aura.owner, aura.ownerName = copy.scope, copy.owner, copy.ownerName
    E.Rebuild()
    return aura
end

function E.DeleteAura(id)
    if not OA.sv.auras[id] then return false end
    OA.sv.auras[id] = nil
    if OA.previewId == id then OA.previewId = nil end
    E.Rebuild()
    return true
end

-- IDs de las auras disponibles para el personaje actual, en orden de creación.
function E.SortedIds()
    local ids = {}
    for id, aura in pairs(OA.sv.auras) do
        if E.IsAvailable(aura) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

function E.Init()
    E.Rebuild()
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, UPDATE_MS, E.OnUpdate)
end
