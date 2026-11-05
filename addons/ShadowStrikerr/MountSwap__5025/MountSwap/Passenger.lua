-- Independently implemented using ESO's public group/passenger APIs.
local M = MountSwap
local function say(message) M:Chat(message) end
function M:FindNearestPassengerMount()
    local zone, px, py, pz = GetUnitWorldPosition('player')
    if not zone or zone == 0 or type(px) ~= 'number' or type(py) ~= 'number' or type(pz) ~= 'number' then
        return nil, 'Your world position is unavailable. Try again after loading.'
    end
    local nearest, nearestDistance
    for index = 1, GetGroupSize() do
        local unit = GetGroupUnitTagByIndex(index)
        if unit and not AreUnitsEqual(unit, 'player') and IsUnitOnline(unit) and not IsUnitDead(unit) then
            local name = GetUnitName(unit)
            if name and name ~= '' then
                local state, multi, free = GetTargetMountedStateInfo(name)
                if state == MOUNTED_STATE_MOUNT_RIDER and multi and free then
                    local targetZone, x, y, z = GetUnitWorldPosition(unit)
                    if targetZone == zone and type(x) == 'number' and type(y) == 'number' and type(z) == 'number' then
                        local distance = (x - px)^2 + (y - py)^2 + (z - pz)^2
                        if not nearestDistance or distance < nearestDistance then
                            nearest, nearestDistance = name, distance
                        end
                    end
                end
            end
        end
    end
    return nearest, 'No group member with an available multi-rider passenger seat was found in your zone.'
end
function M:ConfirmPassenger()
    local request = self.pendingPassenger
    if request and IsGroupMountPassengerForTarget(request.name) then
        self.pendingPassenger = nil
        self:NotifyMessage('Passenger seat joined', zo_strformat('<<1>>', request.name))
        say('Joined ' .. zo_strformat('<<1>>', request.name) .. ' as a passenger.')
    end
end
function M:NearestPassenger()
    if not self.saved then return end
    if IsUnitDead('player') then say('You cannot join a passenger seat while dead.'); return end
    if IsGroupMountPassenger() then say('You are already riding as a passenger.'); return end
    if GetGroupSize() == 0 then say('Join a group to use another player\'s multi-rider mount.'); return end
    local name, reason = self:FindNearestPassengerMount()
    if not name then say(reason); return end
    local request = {name = name}
    self.pendingPassenger = request
    say('Requesting a passenger seat with ' .. zo_strformat('<<1>>', name) .. '.')
    UseMountAsPassenger(name)
    self:ConfirmPassenger()
    zo_callLater(function()
        if self.pendingPassenger ~= request then return end
        self:ConfirmPassenger()
        if self.pendingPassenger == request then
            self.pendingPassenger = nil
            say('ESO did not confirm joining ' .. zo_strformat('<<1>>', name) .. '. Move closer and check that the seat is still free; game restrictions may prevent boarding.')
        end
    end, 2500)
end
