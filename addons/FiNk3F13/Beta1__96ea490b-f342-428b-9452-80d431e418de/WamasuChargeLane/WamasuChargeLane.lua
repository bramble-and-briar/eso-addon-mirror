-- Fixed-spawn prediction. This addon does not receive the server's hitbox or path.
local NAME, ZONE, CHARGE, TRASH_CHARGE = "WamasuChargeLane", 1427, 191133, 200544
local EM = EVENT_MANAGER
local A = { lanes = {}, seen = {}, ids = {}, tagIds = {}, pool = {}, enemies = {}, pending = {}, estimateBlocks = {}, historyAfter = {} }
WamasuChargeLane = A
local estimator = WamasuChargeLaneAimEstimator
local settings, registered, running, serial, warned = nil, false, false, 0, false
local camera, previewRequest

local function Message(text) d("WamasuChargeLane 1.2.2: " .. text) end
local function ChargeStatus(message)
    A.lastStatus = message
    if settings.diagnostics then Message(message) end
end
local function Name(tag) return zo_strformat("<<1>>", GetUnitName(tag) or "") end
local function Identity(tag) return GetUnitDisplayName(tag) .. "/" .. Name(tag) end
local function Valid(tag)
    return tag and DoesUnitExist(tag) and not IsUnitDead(tag)
        and (tag == "player" or (IsUnitOnline(tag)
            and IsGroupMemberInSameWorldAsPlayer(tag) and IsGroupMemberInSameInstanceAsPlayer(tag)))
end
local function Position(tag)
    local zone, x, y, z = GetUnitRawWorldPosition(tag)
    if not zone or zone == 0 or not x or not y or not z or (x == 0 and y == 0 and z == 0) then return nil end
    return { zone = zone, x = x, y = y, z = z }
end
local function CaptureReticle()
    local exists = DoesUnitExist("reticleover")
    local snapshot = { exists = exists, name = exists and Name("reticleover") or "kein Ziel" }
    if exists then
        snapshot.zone, snapshot.x, snapshot.y, snapshot.z = GetUnitRawWorldPosition("reticleover")
        snapshot.reaction = GetUnitReaction("reticleover")
    end
    return snapshot
end
local function PrintReticle(snapshot)
    if not snapshot then Message("Noch keine Fadenkreuz-Messung bei einem Charge."); return end
    Message("Fadenkreuz beim Charge: " .. snapshot.name .. "; Zone=" .. tostring(snapshot.zone)
        .. "; X=" .. tostring(snapshot.x) .. "; Y=" .. tostring(snapshot.y) .. "; Z=" .. tostring(snapshot.z) .. ".")
end
local function DirectReticleStart(sourceId, sourceName, targetTag)
    if not settings.reticleFallback then return nil, "Fadenkreuz-Modus ausgeschaltet." end
    if not targetTag or not AreUnitsEqual(targetTag, "player") then return nil, "Charge-Ziel ist nicht dein eigener Spieler." end
    if not DoesUnitExist("reticleover") then return nil, "ESO meldet kein Ziel im Fadenkreuz." end
    if IsUnitDead("reticleover") then return nil, "Ziel im Fadenkreuz ist tot." end
    if A.reticleAmbiguousUntil and GetGameTimeMilliseconds() < A.reticleAmbiguousUntil then
        return nil, "Mehrere Charges: Zuordnung vorübergehend gesperrt."
    end
    -- A real known ID always wins over a name match; never override a contradiction.
    if A.reticleId and A.reticleId ~= sourceId then return nil, "Erfasste Gegner-ID stimmt nicht mit dem Charge überein." end
    local aimedName = zo_strlower(Name("reticleover"))
    local casterName = zo_strlower(zo_strformat("<<1>>", sourceName or ""))
    if aimedName == "" or aimedName ~= casterName then
        return nil, "Name passt nicht: Fadenkreuz='" .. aimedName .. "', Charge='" .. casterName .. "'."
    end
    if not aimedName:find("wamasu", 1, true) then return nil, "Zielname enthält nicht Wamasu: " .. aimedName .. "." end
    if GetUnitReaction("reticleover") ~= UNIT_REACTION_HOSTILE then return nil, "Fadenkreuz-Ziel wird nicht als feindlich gemeldet." end
    -- Explicit aim-based mode, NOT an ID-to-position lookup. No synthetic ID binding is cached.
    local position = Position("reticleover")
    if not position then return nil, "ESO liefert für das Fadenkreuz-Ziel keine brauchbaren Weltkoordinaten." end
    return position
end
local function DistanceSquared(a, b)
    if a.zone ~= b.zone then return math.huge end
    return (a.x - b.x)^2 + (a.y - b.y)^2 + (a.z - b.z)^2
end
local function ResetReticle()
    A.reticleId = nil
    A.reticleName = nil
    estimator:Break()
end
-- Enemy IDs only acquire a position through a real reticleover effect event.
-- Exact ID tracking remains separate from the explicitly approximate aimed-at mode.
local function SampleReticle()
    if not A.reticleId or not DoesUnitExist("reticleover") then return end
    if A.reticleName ~= Name("reticleover") then ResetReticle(); return end
    local position = Position("reticleover")
    if position then A.enemies[A.reticleId] = { position=position,time=GetGameTimeMilliseconds(),name=A.reticleName } end
end
function A.TrashStart(sourceId, liveOnly)
    SampleReticle()
    local enemy = A.enemies[sourceId]
    if not enemy then return nil end
    -- While the identified caster is still aimed at, read its current position.
    if A.reticleId == sourceId and DoesUnitExist("reticleover") then return Position("reticleover") end
    if liveOnly then return nil end
    -- A fixed saved spawn is usable only after this exact caster was observed there.
    if GetGameTimeMilliseconds() - enemy.time > 10000 then return nil end
    local found
    for _, spawn in ipairs(settings.trashSpawns) do
        if DistanceSquared(enemy.position, spawn) <= 300^2 then
            if found then return nil end -- ambiguous overlapping calibration points
            found = spawn
        end
    end
    return found
end
local function Resolve(id, targetName, kind)
    if kind == COMBAT_UNIT_TYPE_PLAYER then return "player" end
    local cached = A.ids[id]
    if cached and Valid(cached.tag) and Identity(cached.tag) == cached.identity then return cached.tag end
    local crutchTag = CrutchAlerts and CrutchAlerts.groupIdToTag and CrutchAlerts.groupIdToTag[id]
    if crutchTag and Valid(crutchTag) then return crutchTag end
    local wanted = zo_strformat("<<1>>", targetName or "")
    if wanted == "" then return nil end
    local found
    for i = 0, GetGroupSize() do
        local tag = i == 0 and "player" or GetGroupUnitTagByIndex(i)
        if Valid(tag) and (wanted == Name(tag) or wanted == GetUnitDisplayName(tag)) then
            if found and not AreUnitsEqual(found, tag) then return nil end
            found = tag
        end
    end
    return found
end

local function Release(key)
    local lane = A.lanes[key]
    if not lane then return end
    for _, texture in ipairs(lane.textures) do texture:SetHidden(true) end
    A.pool[#A.pool + 1] = lane.textures
    A.lanes[key] = nil
end
function A.Clear(resetSeen)
    for key in pairs(A.lanes) do Release(key) end
    EM:UnregisterForUpdate(NAME .. "Update")
    running = false
    previewRequest = nil
    A.pending = {}
    EM:UnregisterForUpdate(NAME .. "Preview")
    if resetSeen then
        A.seen = {}; A.ids = {}; A.tagIds = {}; A.enemies = {}; A.reticleAmbiguousUntil = nil
        ResetReticle(); estimator:Clear(); A.estimateBlocks = {}; A.historyAfter = {}; warned = false
    end
end

local function Acquire()
    local textures = table.remove(A.pool)
    if textures then return textures end
    textures = {}
    serial = serial + 1
    for i = 1, 5 do
        local texture = WINDOW_MANAGER:CreateControl(NAME .. "Lane" .. serial .. "Part" .. i,
            WamasuChargeLaneRoot, CT_TEXTURE)
        texture:Create3DRenderSpace()
        texture:SetTexture(NAME .. "/assets/white.dds")
        -- The lane is an overlay. Terrain must not hide the whole rectangle.
        texture:Set3DRenderSpaceUsesDepthBuffer(false)
        texture:SetHidden(true)
        textures[i] = texture
    end
    return textures
end

function A.Geometry(start, finish, width)
    local dx, dy, dz = finish.x - start.x, finish.y - start.y, finish.z - start.z
    local flat = math.sqrt(dx * dx + dz * dz)
    if flat < 30 or flat > 12000 or start.zone ~= finish.zone then return nil end
    return { x = (start.x + finish.x) / 2, y = (start.y + finish.y) / 2,
        z = (start.z + finish.z) / 2, length = math.sqrt(flat * flat + dy * dy) / 100,
        pitch = math.pi / 2 - zo_atan2(dy, flat), yaw = math.pi / 2 - zo_atan2(dz, dx),
        sideX = dz / flat * width * 50, sideZ = -dx / flat * width * 50 }
end

function A.Update()
    SampleReticle()
    local now = GetGameTimeMilliseconds()
    local player = Position("player")
    for key, lane in pairs(A.lanes) do
        if now >= lane.expires or not Valid(lane.tag) or Identity(lane.tag) ~= lane.identity
            or not player or player.zone ~= lane.start.zone then
            Release(key)
        else
            -- This charge's endpoints remain fixed even when the target moves.
            local g = A.Geometry(lane.start, lane.finish, settings.width)
            for i, texture in ipairs(lane.textures) do
                texture:SetHidden(not g)
                if g then
                    local side = i == 2 and -1 or (i == 3 and 1 or 0)
                    local isStart=i>=4
                    local x, z = g.x + side * g.sideX, g.z + side * g.sideZ
                    local y=g.y+settings.lift
                    if isStart then x,z,y=lane.start.x,lane.start.z,lane.start.y+settings.lift+3 end
                    texture:Set3DRenderSpaceOrigin(WorldPositionToGuiRender3DPosition(x,y,z))
                    texture:Set3DRenderSpaceOrientation(isStart and math.pi/2 or g.pitch,
                        isStart and (i==4 and 0 or math.pi/2) or g.yaw,0)
                    texture:Set3DLocalDimensions(isStart and 0.12 or (i == 1 and settings.width or 0.08),isStart and 1.2 or g.length)
                    local urgent = not lane.unknownDuration and lane.castEnd - now < 700
                    local opacity = lane.preview and math.max(0.5, settings.opacity / 100) or settings.opacity / 100
                    texture:SetColor(1, lane.estimated and 0.8 or (urgent and 0.08 or 0.45), 0.02,
                        i == 1 and opacity or math.min(1, opacity + 0.4))
                end
            end
        end
    end
    if not next(A.lanes) then
        EM:UnregisterForUpdate(NAME .. "Update")
        running = false
    end
end

local function Start(key, tag, sourceId, duration, start, finish, preview, unknownDuration)
    if not Valid(tag) or not A.Geometry(start, finish, settings.width) then return end
    Release(key)
    local now = GetGameTimeMilliseconds()
    A.lanes[key] = { textures = Acquire(), tag = tag, identity = Identity(tag), sourceId = sourceId,
        start = {zone=start.zone,x=start.x,y=start.y,z=start.z},
        finish = {zone=finish.zone,x=finish.x,y=finish.y,z=finish.z},
        preview = preview, unknownDuration = unknownDuration,
        castEnd = now + duration, expires = now + duration + (unknownDuration and 0 or 1500) }
    if not running then EM:RegisterForUpdate(NAME .. "Update", 33, A.Update); running = true end
    A.Update()
end
local function Cancel(id)
    A.pending[id] = nil
    for key, lane in pairs(A.lanes) do
        if lane.sourceId == id and id ~= 0 then Release(key) end
    end
    if running then A.Update() end
end

local function EstimateStart(sourceId, sourceName, historySince)
    local name = zo_strformat("<<1>>", sourceName or "")
    local now = GetGameTimeMilliseconds()
    if (A.estimateBlocks[name] or 0) > now then return nil,"Mehrere gleichnamige Charges; Schätzung gesperrt." end
    local point, reason = estimator:Estimate(sourceId, name, now, Position("player"), historySince)
    if not point then return nil,reason end
    if point.groundProjection then return point end
    -- Ground height is an explicit approximation using the nearest known player's feet.
    local ground, nearest = nil, math.huge
    for i=0,GetGroupSize() do
        local tag=i==0 and "player" or GetGroupUnitTagByIndex(i)
        if Valid(tag) then
            local position=Position(tag)
            if position and position.zone==point.zone then
                local distance=(position.x-point.x)^2+(position.z-point.z)^2
                if distance<nearest then nearest=distance;ground=position.y end
            end
        end
    end
    if not ground or math.abs(point.aimY-ground)>1000 then return nil,"Bodenhöhe am Wamasu nicht plausibel." end
    point.y=ground
    return point
end

local function ClaimEstimate(sourceId, sourceName, point)
    if point.idConfirmed then return true end
    local name=zo_strformat("<<1>>",sourceName or "")
    local ambiguous=false
    for key,lane in pairs(A.lanes) do
        if lane.estimated and not lane.estimateConfirmed and lane.sourceName==name and lane.sourceId~=sourceId then
            Release(key);ambiguous=true
        end
    end
    for key,pending in pairs(A.pending) do
        if pending.name==name and key~=sourceId then A.pending[key]=nil;ambiguous=true end
    end
    if ambiguous then
        A.pending[sourceId]=nil;A.estimateBlocks[name]=GetGameTimeMilliseconds()+6000
        if running then A.Update() end
        return false
    end
    return true
end

local function ApplyEstimate(sourceId, tag, targetId, name, point, deadline, expiry, unknown, trash, targetPosition)
    if not ClaimEstimate(sourceId,name,point) then
        ChargeStatus("Mehrere gleichnamige Wamasu laden auf: unbestätigte Schätzungen entfernt.");return false
    end
    Start(sourceId,tag,sourceId,math.max(1,deadline-GetGameTimeMilliseconds()),point,targetPosition,false,unknown)
    local lane=A.lanes[sourceId]
    if not lane then return false end
    lane.estimated=true;lane.estimateConfirmed=point.idConfirmed;lane.sourceName=name
    lane.castEnd=deadline;lane.expires=expiry
    lane.estimateError=point.uncertainty;lane.trash=trash
    A.Update()
    local method = point.groundProjection and "Frontalschätzung auf deiner Bodenhöhe"
        or ("Triangulation, Tiefenunsicherheit ca. " .. string.format("%.1f",point.uncertainty/100) .. " m")
    if point.age then method=method .. string.format(", vor %.1f s gesehen",point.age/1000) end
    ChargeStatus("Geschätzte Spur auf " .. Name(tag) .. " (" .. method .. "). Quellen-ID "
        .. (point.idConfirmed and "zugeordnet." or "nicht bestätigt."))
    return true
end

local function SampleAim()
    if not settings.estimate then return end
    if DoesUnitExist("reticleover") and not IsUnitDead("reticleover")
        and GetUnitReaction("reticleover")==UNIT_REACTION_HOSTILE then
        local name=Name("reticleover")
        if zo_strlower(name):find("wamasu",1,true) then
            Set3DRenderSpaceToCurrentCamera(NAME .. "Camera")
            local x,y,z=GuiRender3DPositionToWorldPosition(camera:Get3DRenderSpaceOrigin())
            local fx,fy,fz=camera:Get3DRenderSpaceForward()
            local zone,_,groundY=GetUnitRawWorldPosition("player")
            local hp,hpMax=GetUnitPower("reticleover",COMBAT_MECHANIC_FLAGS_HEALTH)
            estimator:Observe({name=name,id=A.reticleId,time=GetGameTimeMilliseconds(),zone=zone,
                x=x,y=y,z=z,fx=fx,fy=fy,fz=fz,hp=hp,hpMax=hpMax,groundY=groundY})
        else estimator:Break() end
    else estimator:Break() end
    local now=GetGameTimeMilliseconds()
    for sourceId,pending in pairs(A.pending) do
        if now>=pending.deadline or not Valid(pending.tag) or Identity(pending.tag)~=pending.identity then
            A.pending[sourceId]=nil
            if now>=pending.deadline then
                ChargeStatus("Aufladung beendet, keine Spur auf " .. Name(pending.tag) .. ". " .. pending.reason)
            end
        else
            local point,reason=EstimateStart(sourceId,pending.name,pending.historySince)
            pending.reason=reason or "Start und Ziel ergeben keine darstellbare Spur."
            if point and ApplyEstimate(sourceId,pending.tag,pending.targetId,pending.name,point,
                pending.deadline,pending.expiry,pending.unknown,pending.trash,pending.finish) then A.pending[sourceId]=nil end
        end
    end
end

local function OnCharge(_, result, isError, _, _, _, sourceName, _, targetName, targetType,
        duration, _, _, _, sourceId, targetId, abilityId)
    if isError then return end
    if result == ACTION_RESULT_BEGIN then
        local now=GetGameTimeMilliseconds()
        local active=sourceId and A.lanes[sourceId]
        local pending=sourceId and A.pending[sourceId]
        if (active and now<active.expires) or (pending and now<pending.deadline) then
            return -- Repeated BEGIN notifications must not move an already locked lane.
        end
        A.lastCharge = { abilityId = abilityId, sourceId = sourceId, targetId = targetId,
            targetName = targetName, targetType = targetType, rawDuration = duration, sourceName = sourceName }
        A.lastReticle = CaptureReticle()
        local prefix = abilityId == TRASH_CHARGE and "Trash-Charge: " or "Boss-Charge: "
        if not sourceId or sourceId == 0 then ChargeStatus(prefix .. "Ereignis ohne Gegner-ID."); return end
        if abilityId == TRASH_CHARGE and not settings.trashEnabled then
            ChargeStatus(prefix .. "Trash-Anzeige ausgeschaltet."); return
        end
        if type(duration) ~= "number" or duration < 100 or duration > 30000 then
            local channeled,castTime,channelTime=GetAbilityCastInfo(abilityId)
            duration=channeled and channelTime or castTime
        end
        local unknownDuration=type(duration)~="number" or duration<100 or duration>30000
        if unknownDuration then duration=5000 end
        local name=zo_strformat("<<1>>",sourceName or "")
        local historySince=A.historyAfter[name] or -1
        A.historyAfter[name]=math.max(historySince,now+duration)
        local alreadySeen = A.seen[sourceId]
        local tag = Resolve(targetId, targetName, targetType)
        if not Valid(tag) then ChargeStatus(prefix .. "Zielspieler nicht zugeordnet: " .. (targetName or "") .. "."); return end
        local finish=Position(tag)
        if not finish then ChargeStatus(prefix .. "Zielposition bei Ladebeginn fehlt."); return end
        local start
        if abilityId == TRASH_CHARGE then start = A.TrashStart(sourceId, alreadySeen)
        elseif not alreadySeen then start = settings.spawn end
        local assumedReticle, reticleReason = false, nil
        if not start then
            start, reticleReason = DirectReticleStart(sourceId, sourceName, tag)
            assumedReticle = start ~= nil
        end
        -- Saved spawns are first-charge-only. A live aimed-at position can be read again later.
        A.seen[sourceId] = true
        if not start then
            if settings.estimate then
                A.pending[sourceId]=nil
                SampleAim()
                local point,reason=EstimateStart(sourceId,sourceName,historySince)
                local deadline=now+duration
                local expiry=deadline+(unknownDuration and 0 or 1500)
                if point then
                    if ApplyEstimate(sourceId,tag,targetId,name,point,deadline,expiry,unknownDuration,abilityId==TRASH_CHARGE,finish) then return end
                    if (A.estimateBlocks[zo_strformat("<<1>>",sourceName or "")] or 0)>now then return end
                    reason="Start und Ziel ergeben keine darstellbare Spur."
                elseif not ClaimEstimate(sourceId,name,{}) then
                    ChargeStatus("Mehrere gleichnamige Wamasu laden auf: Startposition mehrdeutig.")
                    return
                end
                A.pending[sourceId]={name=zo_strformat("<<1>>",sourceName or ""),tag=tag,identity=Identity(tag),
                    targetId=targetId,deadline=deadline,expiry=expiry,unknown=unknownDuration,trash=abilityId==TRASH_CHARGE,historySince=historySince,
                    finish=finish,reason=reason or estimator.reason}
                ChargeStatus(prefix .. "Positionsschätzung wartet: " .. (reason or estimator.reason))
                return
            end
            ChargeStatus(prefix .. (reticleReason or "Startposition fehlt."))
            if settings.diagnostics then PrintReticle(A.lastReticle) end
            return
        end
        if assumedReticle then
            local ambiguous = false
            for key, lane in pairs(A.lanes) do
                if lane.assumedReticle and lane.sourceId ~= sourceId then Release(key); ambiguous = true end
            end
            if ambiguous then
                A.reticleAmbiguousUntil = GetGameTimeMilliseconds() + 6000
                if running then A.Update() end
                ChargeStatus(prefix .. "mehrere Charges auf dich; Fadenkreuz-Zuordnung mehrdeutig. Spuren entfernt.")
                return
            end
        end
        if not A.Geometry(start, finish, settings.width) then
            ChargeStatus(prefix .. "Start-/Zielpunkt ungültig oder außerhalb der Reichweite."); return
        end
        Start(sourceId, tag, sourceId, duration, start, finish, false, unknownDuration)
        if A.lanes[sourceId] then
            A.lanes[sourceId].trash = abilityId == TRASH_CHARGE
            A.lanes[sourceId].assumedReticle = assumedReticle
        end
        ChargeStatus(prefix .. "Spur auf " .. Name(tag) .. (unknownDuration
            and " angezeigt (Ladezeit fehlt; max. 5 Sekunden Anzeige)." or " angezeigt.")
            .. (assumedReticle and " Fadenkreuz-Modus: Gegner-Zuordnung nicht per ID bestätigt." or ""))
    elseif result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_BLOCKED_DAMAGE or result == ACTION_RESULT_DAMAGE_SHIELDED
        or result == ACTION_RESULT_DODGED or result == ACTION_RESULT_MISS then
        Cancel(sourceId)
    end
end
local function OnCancel(_, _, isError, _, _, _, _, _, _, _, _, _, _, _, _, targetId)
    if not isError then Cancel(targetId) end
end
local function Cache(_, _, _, _, tag, _, _, _, _, _, _, _, _, _, id)
    if tag == "reticleover" and DoesUnitExist(tag) and id and id ~= 0 then
        local position = Position(tag)
        local now = GetGameTimeMilliseconds()
        for key, enemy in pairs(A.enemies) do
            if now - enemy.time > 10000 then A.enemies[key] = nil end
        end
        A.reticleId = id
        A.reticleName = Name(tag)
        estimator:BindId(id,A.reticleName,now)
        if position then A.enemies[id] = { position = position, time = now, name = Name(tag) } end
    elseif (tag == "player" or (tag and tag:match("^group%d+$"))) and DoesUnitExist(tag) and id and id ~= 0 then
        local old = A.tagIds[tag]
        if old and old ~= id then A.ids[old] = nil end
        A.tagIds[tag] = id
        A.ids[id] = { tag = tag, identity = Identity(tag) }
    end
end
local stops = {
    { ACTION_RESULT_INTERRUPT, "Interrupt" }, { ACTION_RESULT_STUNNED, "Stunned" },
    { ACTION_RESULT_FEARED, "Feared" }, { ACTION_RESULT_DIED, "Died" }, { ACTION_RESULT_DIED_XP, "DiedXP" },
}
local function Refresh()
    A.Clear(true)
    local active = settings.enabled and GetZoneId(GetUnitZoneIndex("player")) == ZONE
    EM:UnregisterForUpdate(NAME .. "Aim")
    if active then EM:RegisterForUpdate(NAME .. "Aim",50,SampleAim) end
    if registered == active then return end
    registered = active
    if active then
        EM:RegisterForEvent(NAME .. "Charge", EVENT_COMBAT_EVENT, OnCharge)
        EM:AddFilterForEvent(NAME .. "Charge", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, CHARGE)
        EM:RegisterForEvent(NAME .. "TrashCharge", EVENT_COMBAT_EVENT, OnCharge)
        EM:AddFilterForEvent(NAME .. "TrashCharge", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, TRASH_CHARGE)
        EM:RegisterForEvent(NAME .. "Reticle", EVENT_RETICLE_TARGET_CHANGED, ResetReticle)
        for _, stop in ipairs(stops) do
            EM:RegisterForEvent(NAME .. stop[2], EVENT_COMBAT_EVENT, OnCancel)
            EM:AddFilterForEvent(NAME .. stop[2], EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, stop[1])
        end
        for _, prefix in ipairs({ "group", "player", "reticleover" }) do
            EM:RegisterForEvent(NAME .. prefix, EVENT_EFFECT_CHANGED, Cache)
            EM:AddFilterForEvent(NAME .. prefix, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, prefix)
        end
    else
        EM:UnregisterForUpdate(NAME .. "Aim")
        EM:UnregisterForEvent(NAME .. "Charge", EVENT_COMBAT_EVENT)
        EM:UnregisterForEvent(NAME .. "TrashCharge", EVENT_COMBAT_EVENT)
        EM:UnregisterForEvent(NAME .. "Reticle", EVENT_RETICLE_TARGET_CHANGED)
        for _, stop in ipairs(stops) do EM:UnregisterForEvent(NAME .. stop[2], EVENT_COMBAT_EVENT) end
        for _, prefix in ipairs({ "group", "player", "reticleover" }) do EM:UnregisterForEvent(NAME .. prefix, EVENT_EFFECT_CHANGED) end
    end
end

local function SaveSpawn()
    if GetZoneId(GetUnitZoneIndex("player")) ~= ZONE then
        Message("Spawnpunkt bitte in Rand des Wahnsinns bei Yaseyla speichern."); return
    end
    local position = Position("player")
    if not position then Message("Position momentan nicht verfügbar."); return end
    A.Clear(true)
    settings.spawn = position
    Message("Deine aktuelle Position ist als Wamasu-Spawnpunkt gespeichert.")
end
local function SaveTrashSpawn()
    if GetZoneId(GetUnitZoneIndex("player")) ~= ZONE then
        Message("Trash-Spawnpunkte bitte in Rand des Wahnsinns speichern."); return
    end
    local position = Position("player")
    if not position then return end
    for _, spawn in ipairs(settings.trashSpawns) do
        if DistanceSquared(spawn, position) < 300^2 then
            Message("Hier ist bereits ein Trash-Spawnpunkt gespeichert."); return
        end
    end
    if #settings.trashSpawns >= 30 then Message("Maximal 30 Trash-Spawnpunkte."); return end
    settings.trashSpawns[#settings.trashSpawns + 1] = position
    Message("Trash-Spawnpunkt " .. #settings.trashSpawns .. " gespeichert.")
end
local function ShowPreview(spawn)
    local player = Position("player")
    if not player then return end
    local start, finish = spawn, player
    if not start then
        -- A visible example ahead of the camera, never a guessed real spawn.
        Set3DRenderSpaceToCurrentCamera(NAME .. "Camera")
        local fx, _, fz = camera:Get3DRenderSpaceForward()
        local flat = math.sqrt(fx * fx + fz * fz)
        if flat < 0.01 then Message("Für den Test die Kamera etwas waagerechter ausrichten."); return end
        fx, fz = fx / flat, fz / flat
        start = { zone = player.zone, x = player.x + fx * 200, y = player.y + 15, z = player.z + fz * 200 }
        finish = { zone = player.zone, x = player.x + fx * 1400, y = player.y + 15, z = player.z + fz * 1400 }
    end
    if not A.Geometry(start, finish, settings.width) then
        Message("Für die Vorschau einige Meter vom gespeicherten Spawnpunkt weggehen.")
        return
    end
    Start("preview", "player", -1, 10000, start, finish, true)
    if A.lanes.preview then
        A.lanes.preview.preview = true
        A.lanes.preview.expires = A.lanes.preview.castEnd
        A.Update()
    end
    Message("10 Sekunden Vorschau vor dir. Breite: " .. settings.width .. " m.")
end
local function Preview(spawn)
    A.Clear(false)
    local function IsHUDVisible()
        return not SCENE_MANAGER or not SCENE_MANAGER.IsShowing
            or SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
    end
    if IsHUDVisible() then ShowPreview(spawn); return end
    previewRequest = { spawn = spawn, expires = GetGameTimeMilliseconds() + 60000 }
    EM:RegisterForUpdate(NAME .. "Preview", 100, function()
        local request = previewRequest
        if not request or GetGameTimeMilliseconds() >= request.expires then
            EM:UnregisterForUpdate(NAME .. "Preview"); previewRequest = nil
        elseif IsHUDVisible() then
            EM:UnregisterForUpdate(NAME .. "Preview"); previewRequest = nil
            ShowPreview(request.spawn)
        end
    end)
    Message("Vorschau bereit. Einstellungen schließen, dann startet der 10-Sekunden-Test.")
end
local function CreateSettings()
    local lib = LibHarvensAddonSettings
    local menu = lib:AddAddon(NAME, { allowDefaults = false, allowRefresh = true })
    if not menu then return end
    menu:AddSettings({
        { type = lib.ST_LABEL, label = "PS5-Test: erster Wamasu-Charge bei Yaseyla und Trash" },
        { type = lib.ST_LABEL, label = "Vorhersage, keine vom Spiel gelieferte Trefferfläche. 6 m ist eine Testbreite." },
        { type = lib.ST_CHECKBOX, label = "Charge-Spur aktiv", getFunction = function() return settings.enabled end,
            setFunction = function(v) settings.enabled = v; Refresh() end },
        { type = lib.ST_BUTTON, label = "Spawnpunkt speichern", buttonText = "Aktuelle Spielerposition speichern",
            tooltip = "Genau auf den festen Wamasu-Spawnpunkt bei Yaseyla stellen, dann speichern. Dauerhaft gespeichert.",
            clickHandler = SaveSpawn },
        { type = lib.ST_LABEL, label = function() return settings.spawn and "Spawnpunkt gespeichert" or "Spawnpunkt fehlt" end },
        { type = lib.ST_CHECKBOX, label = "Trash-Wamasu anzeigen", getFunction = function() return settings.trashEnabled end,
            setFunction = function(v)
                settings.trashEnabled = v
                if not v then
                    for key, lane in pairs(A.lanes) do if lane.trash then Release(key) end end
                    if running then A.Update() end
                end
            end },
        { type = lib.ST_BUTTON, label = "Trash-Spawnpunkt hinzufügen", buttonText = "Aktuelle Spielerposition speichern",
            tooltip = "Auf einen festen Trash-Wamasu-Spawnpunkt stellen. Mehrere Punkte möglich. Ersetzt den Boss-Spawnpunkt nicht.",
            clickHandler = SaveTrashSpawn },
        { type = lib.ST_LABEL, label = function() return "Trash-Spawnpunkte: " .. #settings.trashSpawns end },
        { type = lib.ST_LABEL, label = "Bei Charge auf dich: den aufladenden Wamasu genau im Fadenkreuz behalten." },
        { type = lib.ST_CHECKBOX, label = "Wamasu-Position aus Blicklinien schätzen",
            tooltip = "Seitliche Bewegung ermöglicht Triangulation. Frontal auf ebenem Boden von oben auf die Füße des Wamasu zielen. Die gelbe Spur zeigt eine geschätzte Bahn.",
            getFunction = function() return settings.estimate end,
            setFunction = function(v) settings.estimate=v;estimator:Clear();A.pending={} end },
        { type = lib.ST_BUTTON, label = "Positionsschätzung prüfen", buttonText = "Messstatus im Chat",
            clickHandler = function() Message(estimator.reason or "Noch keine Blicklinien.") end },
        { type = lib.ST_CHECKBOX, label = "Fadenkreuz-Modus bei Charge auf mich",
            tooltip = "Liest den anvisierten feindlichen Wamasu ohne Effekt-ID. Gleichnamige Gegner können verwechselt werden. Bei erkannten gleichzeitigen Charges werden diese Spuren entfernt. Für andere Spieler weiterhin ID-Zuordnung nötig.",
            getFunction = function() return settings.reticleFallback end,
            setFunction = function(v) settings.reticleFallback = v end },
        { type = lib.ST_BUTTON, label = "Trash-Erfassung prüfen", buttonText = "Status im Chat",
            clickHandler = function()
                SampleReticle()
                Message(A.reticleId and "Gegner-ID im Fadenkreuz erfasst: " .. A.reticleId
                    or "Noch keine Gegner-ID erfasst. Anvisieren allein garantiert keine ID-Meldung.")
            end },
        { type = lib.ST_BUTTON, label = "Letzten Trash-Spawnpunkt entfernen", buttonText = "Letzten Punkt löschen",
            clickHandler = function() table.remove(settings.trashSpawns); Message("Trash-Spawnpunkte: " .. #settings.trashSpawns) end },
        { type = lib.ST_BUTTON, label = "Letzten Trash-Spawnpunkt testen", buttonText = "10 Sekunden Vorschau",
            clickHandler = function()
                local spawn = settings.trashSpawns[#settings.trashSpawns]
                if spawn then Preview(spawn) else Message("Zuerst einen Trash-Spawnpunkt speichern.") end
            end },
        { type = lib.ST_SLIDER, label = "Streifenbreite (Meter)", min = 1, max = 12, step = 0.5, format = "%.1f",
            tooltip = "An die tatsächliche Charge-Breite anpassen. Der Standard 6 m ist noch nicht vermessen.",
            getFunction = function() return settings.width end, setFunction = function(v) settings.width = v; if running then A.Update() end end },
        { type = lib.ST_SLIDER, label = "Deckkraft (%)", min = 10, max = 70, step = 5,
            getFunction = function() return settings.opacity end, setFunction = function(v) settings.opacity = v end },
        { type = lib.ST_SLIDER, label = "Bodenabstand (cm)", min = 2, max = 40, step = 2,
            tooltip = "Erhöhen, wenn die Spur im Boden verschwindet. Die Fläche folgt keiner unebenen Bodengeometrie.",
            getFunction = function() return settings.lift end, setFunction = function(v) settings.lift = v end },
        { type = lib.ST_BUTTON, label = "Spur testen", buttonText = "10 Sekunden vor der Kamera",
            tooltip = "Unabhängig vom Spawnpunkt. Startet erst nach dem Schließen der Einstellungen.",
            clickHandler = function() Preview() end },
        { type = lib.ST_CHECKBOX, label = "Charge-Diagnose im Chat",
            tooltip = "Zeigt bei jeder Aufladung, ob eine Spur erstellt oder warum sie ausgelassen wurde.",
            getFunction = function() return settings.diagnostics end,
            setFunction = function(v) settings.diagnostics = v end },
        { type = lib.ST_BUTTON, label = "Letzten Charge prüfen", buttonText = "Diagnose im Chat",
            clickHandler = function()
                Message(A.lastStatus or "Noch keine Wamasu-Aufladung empfangen.")
                Message("Aktiv: " .. tostring(registered) .. "; Trash: " .. tostring(settings.trashEnabled)
                    .. "; gespeicherte Trash-Punkte: " .. #settings.trashSpawns .. ".")
                local charge = A.lastCharge
                if charge then Message("Fähigkeit " .. tostring(charge.abilityId) .. "; Gegner " .. tostring(charge.sourceId)
                    .. " (" .. tostring(charge.sourceName) .. "); Ziel " .. tostring(charge.targetId)
                    .. "; gemeldete Ladezeit " .. tostring(charge.rawDuration) .. ".") end
                PrintReticle(A.lastReticle)
            end },
        { type = lib.ST_BUTTON, label = "Anzeige beenden", buttonText = "Spuren entfernen", clickHandler = function() A.Clear(false) end },
    }, nil, false)
end
local function Initialize(_, addon)
    if addon ~= NAME then return end
    EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    camera = WINDOW_MANAGER:CreateControl(NAME .. "Camera", WamasuChargeLaneRoot, CT_CONTROL)
    camera:Create3DRenderSpace()
    settings = ZO_SavedVars:NewAccountWide("WamasuChargeLaneSavedVariables", 1, nil,
        { enabled = true, width = 6, opacity = 25, lift = 8,
            trashEnabled = true, trashSpawns = {}, diagnostics = true, reticleFallback = true, estimate = true })
    settings.follow=nil
    if not settings.widthRevision then
        if settings.width == 4 then settings.width = 6 end
        settings.widthRevision = 1
    end
    CreateSettings()
    SLASH_COMMANDS["/wcharge"] = function(text)
        if text == "spawn" then SaveSpawn()
        elseif text == "trashspawn" then SaveTrashSpawn()
        elseif text == "test" then Preview()
        elseif text == "stop" then A.Clear(false)
        else Message("Einstellungen → Addons → WamasuChargeLane. /wcharge spawn | trashspawn | test | stop") end
    end
    EM:RegisterForEvent(NAME .. "Zone", EVENT_PLAYER_ACTIVATED, Refresh)
    EM:RegisterForEvent(NAME .. "Leave", EVENT_PLAYER_DEACTIVATED, function()
        A.Clear(true);EM:UnregisterForUpdate(NAME .. "Aim")
    end)
    EM:RegisterForEvent(NAME .. "Group", EVENT_GROUP_UPDATE, function() A.Clear(false); A.ids = {}; A.tagIds = {} end)
    EM:RegisterForEvent(NAME .. "Combat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then A.Clear(true) end
    end)
    Refresh()
end
EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
