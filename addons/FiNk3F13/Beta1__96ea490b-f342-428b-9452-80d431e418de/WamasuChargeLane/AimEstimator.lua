-- Independent spatial aim-ray least-squares estimator.
-- Research reference: PUYO's Sul-Xan's Marker (ESOUI 4943), not copied source.
-- Coordinates and distances are centimeters. Enemy ground height is NOT exposed.
local E = { tracks = {}, current = nil }
WamasuChargeLaneAimEstimator = E
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < 1e9 end
function E:Clear() self.tracks = {}; self.current = nil; self.reason = "Noch keine Blicklinien." end
function E:Break() self.current = nil end
function E:Observe(ray)
    for _, key in ipairs({"time", "x", "y", "z", "fx", "fy", "fz", "zone"}) do
        if not finite(ray[key]) then return false end
    end
    local horizontal = math.sqrt(ray.fx^2 + ray.fz^2)
    if horizontal < 0.15 then self.reason = "Blickrichtung zu steil."; return false end
    local track = self.current
    if not track or track.name ~= ray.name or track.zone ~= ray.zone
        or ray.time - track.last > 300 or (track.id and ray.id and track.id ~= ray.id)
        or (track.hpMax and ray.hpMax and track.hpMax ~= ray.hpMax)
        or (track.hp and ray.hp and ray.hpMax and ray.hp > track.hp + ray.hpMax * 0.05) then
        track = {name=ray.name, zone=ray.zone, rays={}, last=ray.time}
        self.tracks[#self.tracks+1] = track; self.current = track
    end
    track.last, track.hp, track.hpMax = ray.time, ray.hp, ray.hpMax
    if ray.id then track.id = ray.id end
    track.rays[#track.rays+1] = ray
    while #track.rays > 70 or (#track.rays > 0 and ray.time-track.rays[1].time > 3000) do table.remove(track.rays,1) end
    for i=#self.tracks,1,-1 do if ray.time-self.tracks[i].last>3000 then table.remove(self.tracks,i) end end
    while #self.tracks>8 do table.remove(self.tracks,1) end
    self.reason = tostring(#track.rays) .. " Blicklinien erfasst."
    return true
end
local function SpatialFit(list,now)
    local ref=list[#list]
    local matrix={{0,0,0,0,1,0,0},{0,0,0,0,0,1,0},{0,0,0,0,0,0,1}}
    local weight,baseline=0,0
    local directions={}
    for index,r in ipairs(list) do
        local norm=math.sqrt(r.fx^2+r.fy^2+r.fz^2)
        if norm<0.01 then return nil end
        directions[index]={r.fx/norm,r.fy/norm,r.fz/norm}
    end
    local lastDirection=directions[#list]
    for index,r in ipairs(list) do
        local v=directions[index]
        local origin={r.x-ref.x,r.y-ref.y,r.z-ref.z}
        local along=0
        for i=1,3 do along=along+origin[i]*lastDirection[i] end
        local cross=0
        for i=1,3 do cross=cross+(origin[i]-along*lastDirection[i])^2 end
        baseline=math.max(baseline,math.sqrt(cross))
        local w=math.exp(-(now-r.time)/1100)
        weight=weight+w
        for i=1,3 do
            for j=1,3 do
                local coefficient=w*((i==j and 1 or 0)-v[i]*v[j])
                matrix[i][j]=matrix[i][j]+coefficient
                matrix[i][4]=matrix[i][4]+coefficient*origin[j]
            end
        end
    end
    if baseline<100 then return nil,"Zu wenig Perspektivwechsel (etwa 1 m Kamerabasis erforderlich).",true end
    -- Pivoted elimination simultaneously obtains the point and inverse information matrix.
    for column=1,3 do
        local pivot=column
        for row=column+1,3 do if math.abs(matrix[row][column])>math.abs(matrix[pivot][column]) then pivot=row end end
        if math.abs(matrix[pivot][column])<weight*0.000001 then return nil,"Räumliche Blicklinien fast parallel." end
        matrix[column],matrix[pivot]=matrix[pivot],matrix[column]
        local divisor=matrix[column][column]
        for j=column,7 do matrix[column][j]=matrix[column][j]/divisor end
        for row=1,3 do
            if row~=column then
                local factor=matrix[row][column]
                for j=column,7 do matrix[row][j]=matrix[row][j]-factor*matrix[column][j] end
            end
        end
    end
    local solution={matrix[1][4],matrix[2][4],matrix[3][4]}
    local sum,errors,depth=0,{},0
    for index,r in ipairs(list) do
        local delta={solution[1]+ref.x-r.x,solution[2]+ref.y-r.y,solution[3]+ref.z-r.z}
        local along=0
        for i=1,3 do along=along+delta[i]*directions[index][i] end
        if along<50 or along>8000 then return nil,"Schnittpunkt hinter der Kamera oder zu weit entfernt." end
        local error=0
        for i=1,3 do error=error+(delta[i]-along*directions[index][i])^2 end
        errors[index]=math.sqrt(error)
        sum=sum+math.exp(-(now-r.time)/1100)*error
        if index==#list then depth=along end
    end
    local residual=math.sqrt(sum/weight)
    local variance=0
    for i=1,3 do for j=1,3 do variance=variance+lastDirection[i]*matrix[i][j+4]*lastDirection[j] end end
    local uncertainty=math.max(8,residual,depth*0.006)*math.sqrt(weight*math.max(0,variance))
    return {zone=ref.zone,x=ref.x+solution[1],aimY=ref.y+solution[2],z=ref.z+solution[3],
        baseline=baseline,residual=residual,uncertainty=uncertainty,samples=#list,
        errors=errors,depth=depth,ref=ref,direction=lastDirection}
end
function E.Solve(rays, now, maxAge)
    local list = {}
    for _, r in ipairs(rays) do if now-r.time>=0 and now-r.time<=3000 then list[#list+1]=r end end
    if #list<6 then return nil,"Noch zu wenige Blicklinien.",true end
    if list[#list].time-list[1].time<200 then return nil,"Beobachtung zu kurz." end
    local last=list[#list]
    if now-last.time>(maxAge or 350) then return nil,"Blicklinien zu alt." end
    local point,reason,lacksParallax=SpatialFit(list,now)
    if not point then return nil,reason or "Räumliche Lösung nicht bestimmbar.",lacksParallax end
    if point.residual>35 then
        local sorted={}
        for i,error in ipairs(point.errors) do sorted[i]=error end
        table.sort(sorted)
        local limit=math.max(60,sorted[math.ceil(#sorted/2)]*3)
        local keep={}
        for i,r in ipairs(list) do if point.errors[i]<=limit then keep[#keep+1]=r end end
        local removed=#list-#keep
        if removed>0 then
            if removed>math.floor(#list*0.2) or #keep<6 or keep[#keep]~=last then
                return nil,"Zu viele oder aktuelle Blicklinien widersprüchlich."
            end
            point,reason=SpatialFit(keep,now)
            if not point then return nil,reason end
            point.trimmed=removed
        end
    end
    if point.residual>65 or point.errors[#point.errors]>80 then return nil,"Blicklinien passen räumlich nicht zusammen." end
    if point.uncertainty>250 then return nil,"Tiefenschätzung zu unsicher; mehr Perspektivwechsel nötig." end
    -- Align the displayed origin with the most recent ray, after validating lateral error.
    point.x=point.ref.x+point.direction[1]*point.depth
    point.aimY=point.ref.y+point.direction[2]*point.depth
    point.z=point.ref.z+point.direction[3]*point.depth
    point.errors,point.ref,point.direction=nil,nil,nil
    return point
end
-- With a steady downward reticle aimed at the feet, intersect the ray with the
-- observer's floor. This is a flat-ground approximation, independent of parallax.
local function ProjectFeet(track, observer, now)
    if not observer or observer.zone~=track.zone then return nil end
    local firstTime, point
    for i=#track.rays,1,-1 do
        local r=track.rays[i]
        if now-r.time>250 then break end
        local horizontal=math.sqrt(r.fx^2+r.fz^2)
        if r.fy>=-0.25*horizontal then
            return nil,"Für die Frontalschätzung von oben auf die Füße des Wamasu zielen."
        end
        local scale=(observer.y-r.y)/r.fy
        if scale<=0 or scale*horizontal>4500 then return nil,"Kein plausibler Schnittpunkt mit deiner Bodenhöhe." end
        local x,z=r.x+scale*r.fx,r.z+scale*r.fz
        if not point then
            point={zone=track.zone,x=x,y=observer.y,z=z,groundProjection=true}
        elseif (x-point.x)^2+(z-point.z)^2>75^2 then
            return nil,"Blick auf die Füße noch unruhig."
        end
        firstTime=r.time
    end
    if firstTime and track.last-firstTime>=100 then return point end
    return nil,"Wamasu-Füße kurz im Fadenkreuz halten."
end

function E:Estimate(sourceId, name, now, observer, historySince)
    local candidates,history,exact={},{},nil
    for _,track in ipairs(self.tracks) do
        if track.name==name and now-track.last<=1500 then
            if not track.id or track.id==sourceId then history[#history+1]=track end
            if now-track.last<=350 and (not track.id or track.id==sourceId) then
                candidates[#candidates+1]=track
            end
            if track.id==sourceId then
                if exact then return nil,"Gegner-ID mehrfach erfasst." end
                exact=track
            end
        end
    end
    local chosen=exact
    if not chosen then
        if self.current and self.current.name==name and self.current.id and self.current.id~=sourceId then
            return nil,"Beobachtete Gegner-ID passt nicht zum Charge."
        end
        if #candidates==1 and candidates[1]==self.current then
            chosen=self.current
        elseif historySince and #history==1 and history[1]~=self.current then
            chosen=history[1]
        elseif #candidates>1 or #history>1 then
            return nil,"Mehrere frische Beobachtungen mit demselben Namen; Gegner-ID fehlt."
        else
            return nil,"Keine eindeutig zuordenbare aktuelle Position des Wamasu."
        end
    end
    local previous=chosen~=self.current
    if previous and historySince and chosen.rays[1].time<=historySince then
        if chosen.last<=historySince then
            return nil,"Für diesen Charge fehlt eine neue Messung nach der letzten Aufladung."
        end
        local fresh={}
        for _,r in ipairs(chosen.rays) do
            if r.time>historySince then fresh[#fresh+1]=r end
        end
        chosen={rays=fresh,last=chosen.last,zone=chosen.zone}
    end
    local sampleTime=previous and chosen.last or now
    local result,reason,lacksParallax=self.Solve(chosen.rays,sampleTime,exact and 1500 or 350)
    if not result and lacksParallax and observer then
        if previous and historySince then
            local last=chosen.rays[#chosen.rays]
            if last.groundY and observer.zone==chosen.zone then
                result,reason=ProjectFeet(chosen,{zone=chosen.zone,y=last.groundY},sampleTime)
            end
        elseif not previous and now-chosen.last<=75 then
            result,reason=ProjectFeet(chosen,observer,now)
        end
    end
    if result then
        result.idConfirmed=exact~=nil
        if previous then result.age=now-chosen.last end
    end
    return result,reason
end
function E:BindId(id,name,now)
    if self.current and self.current.name==name and now-self.current.last<=350 then
        if self.current.id and self.current.id~=id then self:Break();return false end
        self.current.id=id;return true
    end
    return false
end
E:Clear()
