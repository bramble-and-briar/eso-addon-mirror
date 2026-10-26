local AMW=AutoMasterWrits

function AMW:GetQueuedMaterialsWorker()
    local result={materials={},requests=0,unavailable=0}
    local interaction=WritCreater.LLCInteractionMaster
    if type(interaction.getAddonCraftingQueue)~="function" or type(interaction.getMatRequirements)~="function" then
        result.error="This LibLazyCrafting version does not expose material inspection."
        return result
    end
    if not self:ScanWorker() then result.error="Bank closed during inspection."; return result end
    local queue=interaction:getAddonCraftingQueue()
    for _,requests in pairs(queue) do
        for _,request in ipairs(requests) do
            local record=self.inventory[request.reference]
            if record and record.bag==BAG_BACKPACK and not record.deferred and not record.crafted then
                result.requests=result.requests+1
                local copy={}
                for key,value in pairs(request) do copy[key]=value end
                local ok,requirements=pcall(interaction.getMatRequirements,interaction,copy)
                if not ok or type(requirements)~="table" or not next(requirements) then
                    result.unavailable=result.unavailable+1
                else
                    local complete=true
                    for id,amount in pairs(requirements) do
                        if type(id)=="number" and id>0 and type(amount)=="number" and amount>0 then
                            result.materials[id]=(result.materials[id] or 0)+amount
                        else complete=false end
                        self:Yield()
                    end
                    if not complete then result.unavailable=result.unavailable+1 end
                end
                self:Yield(25)
            else self:Yield() end
        end
    end
    return result
end

function AMW:OpenMaterials(page)
    if not self:ActivateSession() then return end
    if self:IsBusy() then return self:Alert("Finish or stop the current operation before reviewing materials.") end
    if not self:IsSettingsShowing() then self:OpenActions() end
    local generation=self.settingsGeneration
    self:StartJob("materials",function()
        local summary=self:GetQueuedMaterialsWorker()
        if summary.error then return self:Alert(summary.error) end
        local rows={}
        for id,amount in pairs(summary.materials) do
            local link=LibLazyCrafting.getItemLinkFromItemId(id)
            rows[#rows+1]={name=GetItemLinkName(link),amount=amount,link=link}
            self:Yield()
        end
        rows=self:SortWorker(rows,function(a,b) return a.name<b.name end)
        local pages=math.max(1,math.ceil(#rows/10))
        page=math.max(1,math.min(page or 1,pages))
        local entries,LHA={},LibHarvensAddonSettings
        local function add(entry) entries[#entries+1]=entry; self:Yield() end
        add({type=LHA.ST_LABEL,label=string.format("%d requests; %d calculations incomplete. Page %d/%d.",summary.requests,summary.unavailable,page,pages)})
        add({type=LHA.ST_LABEL,label="Partial quantities from LibLazyCrafting, not prices. Queue writs with Lazy Writ Crafter before reviewing."})
        for index=(page-1)*10+1,math.min(page*10,#rows) do
            local row=rows[index]
            add({type=LHA.ST_LABEL,label=row.amount.." x "..row.name,tooltip=row.link})
        end
        if page>1 then add({type=LHA.ST_BUTTON,label="Previous page",buttonText="Previous",clickHandler=function() self:OpenMaterials(page-1) end}) end
        if page<pages then add({type=LHA.ST_BUTTON,label="Next page",buttonText="Next",clickHandler=function() self:OpenMaterials(page+1) end}) end
        self:PresentSettingsPage("Queued material requirements",entries,"materials",generation)
    end)
end

