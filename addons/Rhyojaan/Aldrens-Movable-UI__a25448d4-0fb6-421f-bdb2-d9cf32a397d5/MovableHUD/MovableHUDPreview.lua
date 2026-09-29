-- Per-section previews use our own passive controls, never reveal live dialogs.
local MH = MovableHUD
local selected
local observed = {}
local function Bounds(c)
    if not c or not c.GetLeft or not c.GetRight then return end
    if c.GetScreenRect then
        local l,t,r,b=c:GetScreenRect()
        if l and t and r and b and r>l and b>t then return l,t,r,b end
    end
    local l,t,r,b = c:GetLeft(),c:GetTop(),c:GetRight(),c:GetBottom()
    if l and t and r and b and r>l and b>t then return l,t,r,b end
end
function MH:RememberPreview(key)
    local controls = self:GetTargetControls(key, false)
    local left,top,right,bottom
    for _, c in ipairs(controls) do
        if not c:IsHidden() then
            local l,t,r,b = Bounds(c)
            if l then
                left=left and math.min(left,l) or l;top=top and math.min(top,t) or t
                right=right and math.max(right,r) or r;bottom=bottom and math.max(bottom,b) or b
            end
        end
    end
    local s=self:GetElementSettings(key)
    if left and s then observed[key]={left,top,right,bottom,x=s.x,y=s.y,scale=s.scale} end
end
local baseApply=MH.ApplyTarget
function MH:ApplyTarget(key)
    local result=baseApply(self,key)
    pcall(self.RememberPreview,self,key)
    return result
end
function MH:IsElementPreviewEnabled(key) return selected==key end
function MH:ClearElementPreview()
    selected=nil
    self:HidePreviews()
end
function MH:SetElementPreviewEnabled(key,enabled)
    if enabled then
        selected=key
        self.saved.previewEnabled=true
    elseif selected==key then selected=nil end
    self:UpdatePreviews()
end
local baseSetValue=MH.SetElementValue
function MH:SetElementValue(key,property,value)
    -- Focus the matching box before the existing setter updates the live UI.
    if self:IsSettingsPanelVisible(true) and self:GetElementSettings(key)
        and (property=="x" or property=="y" or property=="width" or property=="height" or property=="scale") then
        selected=key
        self.saved.previewEnabled=true
    end
    return baseSetValue(self,key,property,value)
end
local baseEnabled=MH.SetElementEnabled
function MH:SetElementEnabled(key,enabled)
    if enabled and self:IsSettingsPanelVisible(true) and self:GetElementSettings(key) then
        selected=key
        self.saved.previewEnabled=true
    end
    return baseEnabled(self,key,enabled)
end
function MH:UpdatePreviews()
    self:HidePreviews()
    if not self:IsSettingsPanelVisible() then
        -- Selecting a section is a temporary editing aid, never saved across sessions.
        selected=nil
        return
    end
    local keys=selected and {selected} or self.targetOrder
    for _,key in ipairs(keys) do
        local s=self:GetElementSettings(key)
        if s and (selected==key or s.enabled) then
            local preview=self:CreatePreviewControl(key)
            local actual=self:GetPrimaryPreviewControl(key)
            local positioned=false
            local label=self:GetTargetName(key)
            if key~="group" and actual and not actual:IsHidden() then
                positioned=self:AnchorPreviewToControl(preview,actual)
                label=label .. " — Live"
            elseif key=="group" then
                self:RememberPreview(key)
            end
            if not positioned and selected==key then
                local rect=observed[key]
                local x,y,w,h
                if rect then
                    x=rect[1]+(s.x-rect.x);y=rect[2]+(s.y-rect.y)
                    w=rect[3]-rect[1];h=rect[4]-rect[2]
                    if key=="chat" or key=="quest" then
                        w,h=s.width*s.scale,s.height*s.scale
                    elseif key=="group" then
                        local ratio=s.scale/(rect.scale or 1)
                        w,h=w*ratio,h*ratio
                    end
                    label=label .. " — Last observed position"
                else
                    w,h=360,100
                    x=(GuiRoot:GetWidth()-w)/2+s.x
                    y=(GuiRoot:GetHeight()-h)/2+s.y
                    if (key=="chat" or key=="quest") and s.initialized then
                        x,y=s.x,s.y
                        w,h=s.width*s.scale,s.height*s.scale
                    end
                    label=label .. " — Sample (not currently visible)"
                end
                preview:ClearAnchors();preview:SetScale(1)
                preview:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
                preview:SetDimensions(w,h)
                positioned=true
            elseif not positioned and key=="group" and observed[key] then
                local r=observed[key]
                preview:ClearAnchors();preview:SetScale(1)
                preview:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,r[1],r[2])
                preview:SetDimensions(r[3]-r[1],r[4]-r[2]);positioned=true
            end
            if preview.movableHUDPreviewLabel then preview.movableHUDPreviewLabel:SetText(label) end
            preview:SetHidden(not positioned)
        end
    end
end
