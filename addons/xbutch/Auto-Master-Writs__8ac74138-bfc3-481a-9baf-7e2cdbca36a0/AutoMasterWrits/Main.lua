local AMW=AutoMasterWrits

function AMW:Bootstrap()
    if self.bootstrapped then return end
    self.bootstrapped=true
    ZO_CreateStringId("SI_BINDING_NAME_AMW_DELIVERY","Auto Master Writs: start or resume delivery")
    ZO_CreateStringId("SI_BINDING_NAME_AMW_REVIEW","Auto Master Writs: review deferred writs")
    -- ZO_CreateStringId("SI_BINDING_NAME_AMW_QUEUE","Auto Master Writs: queue eligible writs")
    ZO_CreateStringId("SI_AMW_INCLUDE","Include this writ once")
    ZO_CreateStringId("SI_AMW_DEFER","Defer this writ")
    ZO_CreateStringId("SI_AMW_REMOVE_OVERRIDE","Remove inclusion override")
    -- Only small access-point registrations. No saved-variable load, inventory,
    -- buff or quest reads, runtime hooks, HUD, timers or activation listeners.
    self:RegisterSettings()
    if not self:RegisterRadialMenu() then
        EVENT_MANAGER:RegisterForEvent(self.name.."RadialLoad",EVENT_ADD_ON_LOADED,function()
            if self:RegisterRadialMenu() then EVENT_MANAGER:UnregisterForEvent(self.name.."RadialLoad",EVENT_ADD_ON_LOADED) end
        end)
    end
    SLASH_COMMANDS["/amw"]=function(command)
        command=string.lower(command or "")
        if command=="scan" then self:Scan(true)
        elseif command=="extract" or command=="open" then self:StartExtraction()
        elseif command=="review" then self:OpenReview()
        elseif command=="clear" then self:ClearDeferred()
        -- elseif command=="queue" then self:QueueEligible()
        elseif command=="start" or command=="resume" then self:StartDelivery()
        elseif command=="stop" then self:StopAll("Stopped. AMW acceptance and XP guards released.")
        elseif command=="buffs" then self:PrintBuffDiagnostics()
        else self:OpenActions() end
    end
end

EVENT_MANAGER:RegisterForEvent(AMW.name,EVENT_ADD_ON_LOADED,function(_,addonName)
    if addonName~=AMW.name then return end
    EVENT_MANAGER:UnregisterForEvent(AMW.name,EVENT_ADD_ON_LOADED)
    AMW:Bootstrap()
end)

