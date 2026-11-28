-- Requests only saved champion hotbar slots. Allocated points are read for validation.
function SetupWardrobeChampionSwap()
    local cooldownUntil, pendingUntil = 0, 0
    local failure, status
    local function validate(cp)
        if not cp then return true end
        for slot=1,12 do
            local id=cp[slot]
            if id and id>0 and (not CanChampionSkillTypeBeSlotted(GetChampionSkillType(id))
                or not WouldChampionSkillNodeBeUnlocked(id,GetNumPointsSpentOnChampionSkill(id))) then
                return false, "Championstern nicht freigeschaltet: "..ControllerWardrobeDisplayName(GetChampionSkillName(id))
            end
        end
        return true
    end
    EVENT_MANAGER:RegisterForEvent("SetupWardrobeChampion",EVENT_CHAMPION_PURCHASE_RESULT,function(_,result)
        local now=GetGameTimeMilliseconds()
        local ours=pendingUntil>0
        pendingUntil=0
        if result==CHAMPION_PURCHASE_SUCCESS then
            cooldownUntil=now+31000
        elseif ours then
            if result==CHAMPION_PURCHASE_CHAMPION_BAR_ON_COOLDOWN then
                cooldownUntil=now+31000
            elseif result~=CHAMPION_PURCHASE_IN_COMBAT then
                failure="Championwechsel abgelehnt: "..GetString("SI_CHAMPIONPURCHASERESULT",result)
            end
        end
    end)
    if CHAMPION_PERKS and ZO_PreHook then
        ZO_PreHook(CHAMPION_PERKS,"StartStarConfirmAnimation",function()
            return pendingUntil>GetGameTimeMilliseconds()
                and (not CHAMPION_PERKS_SCENE or CHAMPION_PERKS_SCENE:GetState()~="shown")
        end)
    end
    return {
        Validate=validate,
        Reset=function() failure,status=nil,nil end,
        Status=function() return status end,
        Step=function(cp)
            status=nil
            if not cp then return true end
            local changes={}
            for slot=1,12 do
                local id=cp[slot]
                if id~=nil and GetSlotBoundId(slot,HOTBAR_CATEGORY_CHAMPION)~=id then
                    changes[#changes+1]={slot=slot,id=id}
                end
            end
            if #changes==0 then return true end
            if failure then return false,failure end
            local now=GetGameTimeMilliseconds()
            if pendingUntil>0 then
                if now>=pendingUntil then
                    pendingUntil=0
                    return false,"Championwechsel wurde von ESO nicht bestätigt. Bitte erneut versuchen."
                end
                status="Championsterne werden übernommen"
                return false
            end
            if now<cooldownUntil then
                status="Championsterne · "..math.ceil((cooldownUntil-now)/1000).." s Abklingzeit"
                return false
            end
            local valid,reason=validate(cp)
            if not valid then return false,reason end
            if CHAMPION_PERKS and CHAMPION_PERKS_SCENE and CHAMPION_PERKS_SCENE:GetState()=="shown" then
                CHAMPION_PERKS:PrepareStarConfirmAnimation()
            end
            PrepareChampionPurchaseRequest(false)
            for _,change in ipairs(changes) do
                AddHotbarSlotToChampionPurchaseRequest(change.slot,change.id)
            end
            local expected=GetExpectedResultForChampionPurchaseRequest()
            if expected==CHAMPION_PURCHASE_CHAMPION_BAR_ON_COOLDOWN then
                cooldownUntil=now+1000
                status="Championsterne · Abklingzeit"
                return false
            elseif expected==CHAMPION_PURCHASE_IN_COMBAT then
                cooldownUntil=now+250
                status="Championsterne · wartet auf Kampfende"
                return false
            elseif expected~=CHAMPION_PURCHASE_SUCCESS then
                return false,"Championwechsel abgelehnt: "..GetString("SI_CHAMPIONPURCHASERESULT",expected)
            end
            pendingUntil=now+5000
            status="Championsterne werden übernommen"
            SendChampionPurchaseRequest()
            return false
        end,
    }
end
