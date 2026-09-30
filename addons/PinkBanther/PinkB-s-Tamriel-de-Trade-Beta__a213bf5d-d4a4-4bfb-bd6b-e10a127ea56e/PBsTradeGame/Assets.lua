-- Match the working PBsWarTable loader: verify texture dimensions, then retry
-- using the install root reported by ESO. Never change visibility owned by the UI.
local A={legacyRoot="PBsTradeGame/",fallbackSeconds=4,controls=setmetatable({},{__mode="k"})}
A.sizes={coin={128,64},coin_plinth={512,128},treasury={2048,1024},title_hall={1024,512},ember={512,512},crest={256,256},
    atlas={1024,1024},wood_frame={512,256},band_glow={128,32},band_tip_left={128,32},band_tip_right={128,32},
    chapter_1={1024,512},chapter_2={1024,512},chapter_3={1024,512},chapter_4={1024,512},chapter_5={1024,512}}
for _,name in ipairs({"bank","market","warehouse","tavern","guildhall","ground","tree","cypress","walkway","bureau","gate"}) do A.sizes["hub_"..name]={512,512} end
PBTrade.Assets=A
function A.Initialize(preferredRoot)
    A.roots={A.legacyRoot}; A.controls=setmetatable({},{__mode="k"})
    local manager=GetAddOnManager and GetAddOnManager()
    if manager and manager.GetAddOnRootDirectoryPath then
        for i=1,manager:GetNumAddOns() do
            if manager:GetAddOnInfo(i)==PBTrade.Config.addonId then
                local root=manager:GetAddOnRootDirectoryPath(i)
                if type(root)=="string" and root~="" then
                    A.reportedRoot=root
                    root=root:gsub("\\","/"):gsub("/+$","").."/"
                    if root~=A.legacyRoot then A.roots[#A.roots+1]=root end
                end
                break
            end
        end
    end
    A.rootIndex=(preferredRoot and A.roots[preferredRoot]) and preferredRoot or 1
end
function A.Path(name,index) return (A.roots or {A.legacyRoot})[index or A.rootIndex or 1].."assets/"..name..".dds" end
function A.Apply(control,name)
    control.pbtradeAsset=name; control.pbtradeExpected=A.sizes[name]
    control.pbtradeRoot=A.rootIndex or 1
    control.pbtradeLoadTime=0; control.pbtradeLoadDone=false
    control:SetTexture(A.Path(name,control.pbtradeRoot)); A.controls[control]=true
end
-- Manual choice of load path (management ledger). Returns the new index.
function A.UseRoot(index)
    if not A.roots or not A.roots[index] then index=1 end
    A.rootIndex=index
    for control in pairs(A.controls) do A.Apply(control,control.pbtradeAsset) end
    return index
end
function A.NextRoot() return A.UseRoot((A.rootIndex or 1)%#(A.roots or {A.legacyRoot})+1) end
local function onScreen(control)
    if control.IsControlHidden then return not control:IsControlHidden() end
    return not (control.IsHidden and control:IsHidden())
end
local function loaded(control) return control.IsTextureLoaded and control:IsTextureLoaded() end
function A.IsUsable(control)
    if not loaded(control) then return false end
    if not control.GetTextureFileDimensions then return true end
    local w,h=control:GetTextureFileDimensions()
    local expected=control.pbtradeExpected
    return expected and w==expected[1] and h==expected[2]
end
function A.PollAll(dt)
    for control in pairs(A.controls) do
        if not control.pbtradeLoadDone and onScreen(control) then
            if A.IsUsable(control) then
                control.pbtradeLoadDone=true
            else
                control.pbtradeLoadTime=(control.pbtradeLoadTime or 0)+(dt or 0)
                if control.pbtradeLoadTime>=A.fallbackSeconds then
                    control.pbtradeLoadTime=0
                    local index=control.pbtradeRoot or 1
                    if index<#(A.roots or {A.legacyRoot}) then
                        control.pbtradeRoot=index+1
                        control:SetTexture(A.Path(control.pbtradeAsset,index+1))
                    else
                        -- As in v0.7.5, never strand textures at an unsuccessful
                        -- manager path. Leave the primary request alive for late loading.
                        control.pbtradeRoot=1
                        control:SetTexture(A.Path(control.pbtradeAsset,1))
                        control.pbtradeLoadDone=true
                    end
                end
            end
        end
    end
end
-- Diagnostics for /pbtrade assets and the management ledger.
function A.Describe()
    local roots=A.roots or {A.legacyRoot}
    local lines={}
    for i,root in ipairs(roots) do lines[#lines+1]=(i==(A.rootIndex or 1) and "▶ " or "　 ")..i.."："..root.."assets/…" end
    if not roots[2] then lines[#lines+1]="　 （ESOが別の格納先を報告していません"..(A.reportedRoot and ("："..A.reportedRoot) or "").."）" end
    local header=table.concat(lines,"\n")
    local assets={}; local seen={}
    for control in pairs(A.controls) do
        local name=control.pbtradeAsset
        if name and not seen[name] then
            seen[name]=true
            local state=A.IsUsable(control) and ("読込済（経路"..(control.pbtradeRoot or 1).."）") or (onScreen(control) and "未読込（表示中）" or "非表示")
            if loaded(control) and control.GetTextureFileDimensions then
                local w,h=control:GetTextureFileDimensions(); local e=A.sizes[name]
                state=state.." "..tostring(w).."x"..tostring(h)..((e and (w~=e[1] or h~=e[2])) and "（想定と異なる）" or "")
            end
            assets[#assets+1]=name.."："..state.."\n  "..A.Path(name,control.pbtradeRoot)
        end
    end
    table.sort(assets)
    return "読み込み先\n"..header.."\n\n"..table.concat(assets,"\n")
end
return A
