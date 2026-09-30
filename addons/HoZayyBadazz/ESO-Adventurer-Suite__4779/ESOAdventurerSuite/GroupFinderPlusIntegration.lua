-- ESO Adventurer Suite
-- Suite-native Group Finder Plus integration.
-- Reimplements the useful behavior from the user-provided GroupFinderPlus addon
-- while keeping the floating HUD listing browser independently optional.

local EPC = ESOProgressionCoach
if not EPC or not EVENT_MANAGER or not WINDOW_MANAGER then return end

EPC.GroupFinderPlus = EPC.GroupFinderPlus or {}
local GF = EPC.GroupFinderPlus
local EM, WM = EVENT_MANAGER, WINDOW_MANAGER
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_GroupFinderPlus029669"

local DEFAULTS = {
    enabled = true,
    showHudOverlay = false,
    hideWTS = true,
    hideInsufficientCP = false,
    allowAllRoles = true,
    showInstanceTooltip = true,
    showModeButton = true,
    saveLastCategory = true,
    hideInInstances = false,
    lastBossHighlight = true,
    titleColor = "B000FF",
    descriptionColor = "8A2BE2",
    windowLeft = 20,
    windowTop = 180,
    lastCategory = nil,
    instanceMode = 2,
    categoriesEnabled = {},
    trialsEnabled = {},
    blacklist = {},
    savedListing = nil,
}

local TRIALS = {
    AA=638, AS=1000, CR=1051, HoF=975, HRC=636, SO=639, MoL=725,
    SS=1121, KA=1196, RG=1263, DSR=1344, SE=1427, LC=1478, OC=1548,
}
GF.Trials = TRIALS

local function copyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                copyDefaults(dst[k], v)
            else
                dst[k] = v
            end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            copyDefaults(dst[k], v)
        end
    end
end

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e,f,g,h = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a,b,c,d,e,f,g,h
end

local function clean(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(text) return string.lower(clean(text)) end

local function normalizeHex(hex, fallback)
    hex = tostring(hex or fallback or "FFFFFF"):upper():gsub("[^0-9A-F]", "")
    if #hex ~= 6 then return fallback or "FFFFFF" end
    return hex
end

local function colorize(text, hex)
    text = clean(text)
    if text == "" then return "" end
    return "|c" .. normalizeHex(hex, "FFFFFF") .. text .. "|r"
end

local function notify(text)
    if EPC and type(EPC.Print) == "function" then EPC:Print(text)
    elseif type(d) == "function" then d("[EAS] " .. tostring(text)) end
end

local function EAS_GetSVCore(self)
    if not EPC.saved then return nil end
    EPC.saved.groupFinderPlus029669 = EPC.saved.groupFinderPlus029669 or {}
    copyDefaults(EPC.saved.groupFinderPlus029669, DEFAULTS)
    local sv = EPC.saved.groupFinderPlus029669
    for short in pairs(TRIALS) do
        if sv.trialsEnabled[short] == nil then sv.trialsEnabled[short] = true end
    end
    return sv
end

local function categories()
    local out = {}
    local function add(id, name, icon)
        if id ~= nil then out[#out+1] = { id=id, name=name, icon=icon } end
    end
    add(rawget(_G,"GROUP_FINDER_CATEGORY_TRIAL"), "Trials", "esoui/art/icons/mapkey/mapkey_raiddungeon.dds")
    add(rawget(_G,"GROUP_FINDER_CATEGORY_DUNGEON"), "Dungeons", "esoui/art/icons/mapkey/mapkey_groupinstance.dds")
    add(rawget(_G,"GROUP_FINDER_CATEGORY_ARENA"), "Arenas", "esoui/art/icons/mapkey/mapkey_groupdelve.dds")
    add(rawget(_G,"GROUP_FINDER_CATEGORY_ENDLESS_DUNGEON"), "Infinite Archive", "esoui/art/leaderboards/gamepad/gp_leaderboards_menuicon_endlessdungeon_duo.dds")
    add(rawget(_G,"GROUP_FINDER_CATEGORY_ZONE"), "Zone", "esoui/art/armory/buildicons/buildicon_47.dds")
    if rawget(_G,"GROUP_FINDER_CATEGORY_ADVENTURE_ZONE") and safe(IsGroupFinderCategoryAvailable, false, GROUP_FINDER_CATEGORY_ADVENTURE_ZONE) then
        add(GROUP_FINDER_CATEGORY_ADVENTURE_ZONE, "Event Zone", "esoui/art/treeicons/gamepad/gp_nightmarket.dds")
    end
    add(rawget(_G,"GROUP_FINDER_CATEGORY_CUSTOM"), "Custom", "esoui/art/guildfinder/gamepad/gp_guildrecruitment_menuicon_applications.dds")
    return out
end

function GF:GetCategories()
    self.categoryList = categories()
    local sv = self:GetSV()
    for _, c in ipairs(self.categoryList) do
        if sv and sv.categoriesEnabled[c.id] == nil then sv.categoriesEnabled[c.id] = true end
    end
    return self.categoryList
end

function GF:CurrentCategory()
    local list, sv = self:GetCategories(), self:GetSV()
    if #list == 0 then return nil end
    local wanted = sv and sv.lastCategory
    for i,c in ipairs(list) do
        if c.id == wanted and (not sv or sv.categoriesEnabled[c.id] ~= false) then
            self.categoryIndex = i
            return c
        end
    end
    for i,c in ipairs(list) do
        if not sv or sv.categoriesEnabled[c.id] ~= false then
            self.categoryIndex = i
            if sv then sv.lastCategory = c.id end
            return c
        end
    end
    self.categoryIndex = 1
    return list[1]
end

function GF:CycleCategory()
    local list, sv = self:GetCategories(), self:GetSV()
    if #list == 0 or not sv then return end
    local start = tonumber(self.categoryIndex) or 1
    local i = start
    repeat
        i = i + 1
        if i > #list then i = 1 end
        if sv.categoriesEnabled[list[i].id] ~= false then break end
    until i == start
    self.categoryIndex = i
    sv.lastCategory = list[i].id
    self:UpdateHeader()
    self:RequestSearch(true)
end

function GF:SwitchMode()
    local sv = self:GetSV(); if not sv then return end
    sv.instanceMode = tonumber(sv.instanceMode) == 1 and 2 or 1
    self:UpdateHeader()
    self:RequestSearch(true)
end

local function trialShortFromText(text)
    local t = string.upper(clean(text))
    local aliases = {
        HRC={"HRC","HEL RA"}, SO={"SO","SANCTUM OPHIDIA"}, AA={"AA","AETHERIAN ARCHIVE"},
        MoL={"MOL","MAW OF LORKHAJ"}, HoF={"HOF","HALLS OF FABRICATION"}, AS={"AS","ASYLUM SANCTORIUM"},
        CR={"CR","CLOUDREST"}, SS={"SS","SUNSPIRE"}, KA={"KA","KYNE'S AEGIS"}, RG={"RG","ROCKGROVE"},
        DSR={"DSR","DREADSAIL REEF"}, SE={"SE","SANITY'S EDGE"}, LC={"LC","LUCENT CITADEL"}, OC={"OC","OSSEIN CAGE"},
    }
    for short, names in pairs(aliases) do
        for _, token in ipairs(names) do
            if t:find(token, 1, true) then return short end
        end
    end
    return nil
end

local function isLastBoss(title, desc)
    local t = lower(title) .. " " .. lower(desc)
    return t:find("last boss",1,true) ~= nil or t:find("final boss",1,true) ~= nil or t:find("end boss",1,true) ~= nil
end

local ROLE_ICONS = {
    [LFG_ROLE_TANK] = "esoui/art/lfg/lfg_icon_tank.dds",
    [LFG_ROLE_HEAL] = "esoui/art/lfg/lfg_icon_healer.dds",
    [LFG_ROLE_DPS] = "esoui/art/lfg/lfg_icon_dps.dds",
}

function GF:ReadListings()
    self.listings = {}
    local sv = self:GetSV(); if not sv then return end
    local count = tonumber(safe(GetGroupFinderSearchNumListings, 0)) or 0
    local custom = rawget(_G,"GROUP_FINDER_CATEGORY_CUSTOM")
    local current = self:CurrentCategory()
    local currentId = current and current.id
    local playerCP = tonumber(safe(GetUnitChampionPoints, 0, "player")) or 0
    for i=1,count do
        local title = tostring(safe(GetGroupFinderSearchListingTitleByIndex, "", i) or "")
        local desc = tostring(safe(GetGroupFinderSearchListingDescriptionByIndex, "", i) or "")
        local leader = tostring(safe(GetGroupFinderSearchListingLeaderDisplayNameByIndex, "", i) or "")
        local hideWts = sv.hideWTS == true and currentId ~= custom and lower(title):find("wts",1,true) ~= nil
        local required = tonumber(safe(GetGroupFinderSearchListingChampionPointsByIndex, 0, i)) or 0
        local requires = safe(DoesGroupFinderSearchListingRequireChampion, false, i) == true
        local hideCP = sv.hideInsufficientCP == true and requires and playerCP < required
        local session = leader .. "|" .. clean(title)
        local short = currentId == rawget(_G,"GROUP_FINDER_CATEGORY_TRIAL") and trialShortFromText(title .. " " .. desc) or nil
        local hideTrial = short and sv.trialsEnabled[short] == false
        if not hideWts and not hideCP and not hideTrial and not (self.hiddenSession and self.hiddenSession[session]) and not sv.blacklist[leader] then
            local roles = {}
            for _, role in ipairs({LFG_ROLE_TANK,LFG_ROLE_HEAL,LFG_ROLE_DPS}) do
                local requested, present = safe(GetGroupFinderSearchListingRoleStatusCount, 0, i, role)
                roles[role] = { requested=tonumber(requested) or 0, current=tonumber(present) or 0 }
            end
            self.listings[#self.listings+1] = {
                index=i, title=title, desc=desc, leader=leader, session=session, short=short,
                pending=safe(IsGroupFinderSearchListingActiveApplication,false,i)==true,
                joinResult=safe(GetGroupFinderSearchListingJoinabilityResult,0,i),
                requiresCP=requires, requiredCP=required, roles=roles,
                enforcesRoles=safe(DoesGroupFinderSearchListingEnforceRoles,false,i)==true,
                lastBoss=isLastBoss(title,desc),
            }
        end
    end
end

local function EAS_CreateRowCore(self, index)
    self.rows = self.rows or {}
    if self.rows[index] then return self.rows[index] end
    local row = WM:CreateControl("EAS_GroupFinderPlus_Row"..tostring(index), self.window, CT_CONTROL)
    row:SetHeight(28); row:SetMouseEnabled(true)
    local bg = WM:CreateControl(nil,row,CT_BACKDROP); bg:SetAnchorFill(row); bg:SetCenterColor(.06,.06,.08,.70); bg:SetEdgeColor(.18,.18,.22,.9); bg:SetEdgeTexture(nil,1,1,1)
    local label = WM:CreateControl(nil,row,CT_LABEL); label:SetAnchor(LEFT,row,LEFT,6,0); label:SetFont("ZoFontGame"); label:SetColor(1,1,1,1)
    local roleBox = WM:CreateControl(nil,row,CT_CONTROL); roleBox:SetAnchor(RIGHT,row,RIGHT,-6,0); roleBox:SetDimensions(122,26)
    row.roleControls = {}
    local prev
    for _, role in ipairs({LFG_ROLE_TANK,LFG_ROLE_HEAL,LFG_ROLE_DPS}) do
        local icon = WM:CreateControl(nil,roleBox,CT_TEXTURE); icon:SetDimensions(18,18); icon:SetTexture(ROLE_ICONS[role]); icon:SetAnchor(LEFT,prev or roleBox,prev and RIGHT or LEFT,prev and 7 or 0,0)
        local txt = WM:CreateControl(nil,roleBox,CT_LABEL); txt:SetDimensions(20,18); txt:SetFont("ZoFontGameSmall"); txt:SetAnchor(LEFT,icon,RIGHT,1,0); txt:SetText("0"); prev=txt
        row.roleControls[role]={icon=icon,text=txt}
    end
    row.bg,row.label,row.roleBox=bg,label,roleBox
    row:SetHandler("OnMouseEnter",function(r) r.bg:SetCenterColor(.22,.22,.26,.78); GF:ShowRowTooltip(r) end)
    row:SetHandler("OnMouseExit",function(r) GF:HideRowTooltip(); GF:ApplyRowColor(r) end)
    row:SetHandler("OnMouseUp",function(r,button,upInside)
        if upInside==false then return end
        if button==MOUSE_BUTTON_INDEX_RIGHT then GF:ShowContextMenu(r)
        elseif button==MOUSE_BUTTON_INDEX_LEFT then GF:ApplyToRow(r) end
    end)
    self.rows[index]=row
    return row
end

function GF:ApplyRowColor(row)
    if not row or not row.bg then return end
    if row.data and row.data.pending then row.bg:SetCenterColor(.55,.50,.10,.48)
    elseif row.data and row.data.joinResult == 4 then row.bg:SetCenterColor(.10,.42,.12,.45)
    elseif row.data and row.data.lastBoss and self:GetSV().lastBossHighlight then row.bg:SetCenterColor(.36,.08,.48,.52)
    else row.bg:SetCenterColor(.06,.06,.08,.70) end
end

function GF:ShowRowTooltip(row)
    local sv = self:GetSV(); if not sv or not row or not row.data then return end
    InitializeTooltip(InformationTooltip,row,RIGHT,8,0)
    local d=row.data
    InformationTooltip:AddLine(clean(d.title),"ZoFontWinH3",1,.85,.35)
    InformationTooltip:AddLine(d.leader,"ZoFontGame",.7,.9,1)
    if clean(d.desc)~="" then InformationTooltip:AddLine(clean(d.desc),"ZoFontGame",1,1,1) end
    if d.requiresCP then InformationTooltip:AddLine("Required CP: "..tostring(d.requiredCP),"ZoFontGameSmall",1,.55,.2) end
end
function GF:HideRowTooltip() ClearTooltip(InformationTooltip) end

function GF:CreateWindow()
    if self.window then return end
    local sv=self:GetSV(); if not sv then return end
    local w=WM:CreateTopLevelWindow("EAS_GroupFinderPlus_HUD")
    w:SetDimensions(430,120); w:SetMovable(true); w:SetMouseEnabled(true); w:SetClampedToScreen(true); w:SetDrawLayer(DL_OVERLAY); w:SetDrawTier(DT_MEDIUM); w:SetHidden(true)
    w:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tonumber(sv.windowLeft) or 20,tonumber(sv.windowTop) or 180)
    w:SetHandler("OnMoveStop",function(c) sv.windowLeft=c:GetLeft(); sv.windowTop=c:GetTop() end)
    local header=WM:CreateControl(nil,w,CT_BACKDROP); header:SetAnchor(TOPLEFT,w,TOPLEFT,0,0); header:SetAnchor(TOPRIGHT,w,TOPRIGHT,0,0); header:SetHeight(34); header:SetCenterColor(.015,.018,.028,.92); header:SetEdgeColor(.70,.52,.18,.95); header:SetEdgeTexture(nil,1,1,1)
    header:SetMouseEnabled(true); header:SetHandler("OnMouseDown",function(_,b) if b==MOUSE_BUTTON_INDEX_LEFT then w:StartMoving() end end); header:SetHandler("OnMouseUp",function(_,b) if b==MOUSE_BUTTON_INDEX_LEFT then w:StopMovingOrResizing() end end)
    local cat=WM:CreateControl(nil,header,CT_BUTTON); cat:SetAnchor(LEFT,header,LEFT,8,0); cat:SetDimensions(210,28); cat:SetFont("ZoFontGameBold"); cat:SetHorizontalAlignment(TEXT_ALIGN_LEFT); cat:SetHandler("OnClicked",function() GF:CycleCategory() end)
    local mode=WM:CreateControl(nil,header,CT_BUTTON); mode:SetAnchor(RIGHT,header,RIGHT,-8,0); mode:SetDimensions(90,26); mode:SetFont("ZoFontGameSmall"); mode:SetHandler("OnClicked",function() GF:SwitchMode() end)
    local status=WM:CreateControl(nil,w,CT_LABEL); status:SetAnchor(TOPLEFT,header,BOTTOMLEFT,6,4); status:SetDimensions(410,24); status:SetFont("ZoFontGameSmall"); status:SetHorizontalAlignment(TEXT_ALIGN_CENTER); status:SetColor(.65,.65,.68,1)
    self.window,self.header,self.categoryButton,self.modeButton,self.status=w,header,cat,mode,status
    self.fragment=ZO_HUDFadeSceneFragment:New(w)
    self:UpdateHeader()
end

function GF:UpdateHeader()
    if not self.window then return end
    local sv=self:GetSV(); local c=self:CurrentCategory()
    self.categoryButton:SetText(c and ("Group Finder: "..c.name.."  ▶") or "Group Finder")
    self.modeButton:SetHidden(not sv.showModeButton)
    self.modeButton:SetText((tonumber(sv.instanceMode)==1) and "NORMAL" or "VETERAN")
end

function GF:RefreshRows()
    if not self.window then return end
    self:ReadListings()
    local y=62
    for i,data in ipairs(self.listings or {}) do
        local row=self:CreateRow(i); row.data=data; row:ClearAnchors(); row:SetAnchor(TOPLEFT,self.window,TOPLEFT,0,y); row:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,0,y); y=y+28
        local prefix=data.short and ("["..data.short.."] ") or ""
        row.label:SetText(prefix..clean(data.title)); row.label:SetWidth(math.max(190,self.window:GetWidth()-150))
        for _,role in ipairs({LFG_ROLE_TANK,LFG_ROLE_HEAL,LFG_ROLE_DPS}) do
            local rd=data.roles[role]; row.roleControls[role].text:SetText(tostring(rd and rd.current or 0))
            local alpha=(data.enforcesRoles and rd and rd.requested==0) and .25 or 1
            row.roleControls[role].icon:SetAlpha(alpha); row.roleControls[role].text:SetAlpha(alpha)
        end
        self:ApplyRowColor(row); row:SetHidden(false)
    end
    for i=#(self.listings or {})+1,#(self.rows or {}) do self.rows[i]:SetHidden(true) end
    if #(self.listings or {})==0 then self.status:SetText("No matching listings") else self.status:SetText(tostring(#self.listings).." matching listing"..(#self.listings==1 and "" or "s")) end
    self.window:SetHeight(math.max(92,66+(#(self.listings or {})*28)))
end

function GF:IsOverlayAllowed()
    local sv=self:GetSV(); if not sv or not sv.enabled or not sv.showHudOverlay then return false end
    if tonumber(safe(GetUnitLevel,50,"player")) < 10 then return false end
    if safe(IsActiveWorldBattleground,false) then return false end
    if safe(GetCurrentGroupFinderUserType,0)==1 then return false end
    if sv.hideInInstances and safe(IsUnitInDungeon,false,"player") and not safe(IsInAdventureZone,false) then return false end
    return true
end

function GF:RefreshVisibility()
    self:CreateWindow(); if not self.window then return end
    local show=self:IsOverlayAllowed()
    if show then
        HUD_SCENE:AddFragment(self.fragment); HUD_UI_SCENE:AddFragment(self.fragment)
        self:UpdateHeader(); self:RequestSearch(false)
    else
        HUD_SCENE:RemoveFragment(self.fragment); HUD_UI_SCENE:RemoveFragment(self.fragment); self.window:SetHidden(true)
    end
end

function GF:RequestSearch(force)
    if not self:IsOverlayAllowed() then return end
    local c=self:CurrentCategory(); if not c then return end
    local sv=self:GetSV()
    if type(SetGroupFinderFilterCategory)=="function" then pcall(SetGroupFinderFilterCategory,c.id,true) end
    if (c.id==rawget(_G,"GROUP_FINDER_CATEGORY_TRIAL") or c.id==rawget(_G,"GROUP_FINDER_CATEGORY_DUNGEON") or c.id==rawget(_G,"GROUP_FINDER_CATEGORY_ARENA")) and type(SetGroupFinderFilterPrimaryOptionByIndex)=="function" then
        pcall(SetGroupFinderFilterPrimaryOptionByIndex,tonumber(sv.instanceMode) or 2,true)
    end
    if sv.allowAllRoles and type(SetGroupFinderFilterEnforceRoles)=="function" then pcall(SetGroupFinderFilterEnforceRoles,false) end
    if force or safe(IsGroupFinderSearchOnCooldown,false)~=true then
        self.status:SetText("Searching…")
        if type(RequestGroupFinderSearch)=="function" then pcall(RequestGroupFinderSearch) end
    end
end

local function EAS_ApplyToRowLegacy(self, row)
    if not row or not row.data then return end
    local idx=row.data.index
    if safe(DoesGroupFinderSearchListingAutoAcceptRequests,false,idx) then pcall(RequestApplyToGroupListing,idx)
    else
        local dialogData={listingIndex=idx,DoesGroupAutoAcceptRequests=function() return false end}
        if ZO_Dialogs_ShowDialog then pcall(ZO_Dialogs_ShowDialog,"GROUP_FINDER_APPLICATION_KEYBOARD",dialogData) else pcall(RequestApplyToGroupListing,idx) end
    end
end

function GF:ShowContextMenu(row)
    if not row or not row.data then return end
    ClearMenu(); local d=row.data
    AddCustomMenuItem("Apply to Group",function() GF:ApplyToRow(row) end)
    AddCustomMenuItem("Whisper Leader",function() if type(StartChatInput)=="function" then StartChatInput("/w "..d.leader.." ") end end)
    AddCustomMenuItem("Hide This Listing (Session)",function() GF.hiddenSession[d.session]=true GF:RefreshRows() end)
    AddCustomMenuItem("Blacklist "..d.leader,function() local sv=GF:GetSV(); sv.blacklist[d.leader]=true GF:RefreshRows(); notify("Blacklisted "..d.leader.." from Group Finder Plus.") end)
    ShowMenu(row)
end

function GF:GetBlacklistChoices()
    local sv=self:GetSV(); local out={}
    if sv then for name,v in pairs(sv.blacklist) do if v then out[#out+1]=name end end end
    table.sort(out); return out
end
function GF:Unblacklist(name)
    local sv=self:GetSV(); if sv and name and name~="" then sv.blacklist[name]=nil self:RefreshRows() end
end

local function EAS_ApplyColorLegacy(self, kind)
    local sv=self:GetSV(); if not sv then return end
    local name=(kind=="description") and "ZO_GroupFinder_Keyboard_TopLevelCreateGroupListingPanelContentDescriptionEdit" or "ZO_GroupFinder_Keyboard_TopLevelCreateGroupListingPanelContentGroupTitleBackdropEdit"
    local field=WM:GetControlByName(name); if not field or type(field.GetText)~="function" then return end
    local raw=clean(field:GetText()); if raw=="" then return end
    field:SetText(colorize(raw,kind=="description" and sv.descriptionColor or sv.titleColor))
end

function GF:ShowColorPicker(kind)
    local sv=self:GetSV(); if not sv or not COLOR_PICKER then return end
    local hex=kind=="description" and sv.descriptionColor or sv.titleColor
    local def=ZO_ColorDef:New(normalizeHex(hex,"FFFFFF"))
    COLOR_PICKER:Show(function(r,g,b)
        local h=ZO_ColorDef:New(r,g,b):ToHex():upper():sub(1,6)
        if kind=="description" then sv.descriptionColor=h else sv.titleColor=h end
        GF:ApplyColorToField(kind)
    end,def:UnpackRGB())
end

local function EAS_CreateNativeEnhancementsLegacy(self)
    if self.nativeButtonsDone then return end
    local title=WM:GetControlByName("ZO_GroupFinder_Keyboard_TopLevelCreateGroupListingPanelContentGroupTitleBackdropEdit")
    local desc=WM:GetControlByName("ZO_GroupFinder_Keyboard_TopLevelCreateGroupListingPanelContentDescriptionEdit")
    local function swatch(field,kind)
        if not field then return end
        local c=WM:CreateControl("EAS_GroupFinderPlus_"..kind.."Color",field:GetParent(),CT_BUTTON)
        c:SetDimensions(30,24); c:SetFont("ZoFontGameBold"); c:SetText("■"); c:SetAnchor(RIGHT,field,LEFT,-6,0)
        c:SetHandler("OnMouseEnter",function(self) InitializeTooltip(InformationTooltip,self,RIGHT,4,0); SetTooltipText(InformationTooltip,"Choose "..kind.." text color") end)
        c:SetHandler("OnMouseExit",function() ClearTooltip(InformationTooltip) end)
        c:SetHandler("OnClicked",function() GF:ShowColorPicker(kind) end)
    end
    swatch(title,"title"); swatch(desc,"description")
    local overview=WM:GetControlByName("ZO_GroupFinder_Keyboard_TopLevelOverview")
    if overview then
        local create=overview:GetNamedChild("CreateGroupButton")
        if create then
            local b=WM:CreateControl("EAS_GroupFinderPlus_RecreateButton",overview,CT_BUTTON); b:SetDimensions(105,30); b:SetFont("ZoFontGameSmall"); b:SetText("RECREATE"); b:SetAnchor(RIGHT,create,LEFT,-8,0); b:SetHandler("OnClicked",function() GF:RestoreSavedListing() end)
        end
    end
    self.nativeButtonsDone=true
end

function GF:SelectedOptionIndex(userType,primary)
    local count=primary and safe(GetGroupFinderUserTypeGroupListingNumPrimaryOptions,0,userType) or safe(GetGroupFinderUserTypeGroupListingNumSecondaryOptions,0,userType)
    for i=1,tonumber(count) or 0 do
        local _,setState
        if primary then _,setState=safe(GetGroupFinderUserTypeGroupListingPrimaryOptionByIndex,nil,userType,i) else _,setState=safe(GetGroupFinderUserTypeGroupListingSecondaryOptionByIndex,nil,userType,i) end
        if setState then return i end
    end
end

function GF:SaveCurrentListing()
    local sv=self:GetSV(); if not sv then return end
    local ut=rawget(_G,"GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING") or 1
    sv.savedListing={
        title=safe(GetGroupFinderUserTypeGroupListingTitle,"",ut), description=safe(GetGroupFinderUserTypeGroupListingDescription,"",ut),
        category=safe(GetGroupFinderUserTypeGroupListingCategory,nil,ut), mode=self:SelectedOptionIndex(ut,true), target=self:SelectedOptionIndex(ut,false),
        groupSize=safe(GetGroupFinderUserTypeGroupListingGroupSize,nil,ut), playstyle=safe(GetGroupFinderUserTypeGroupListingPlaystyle,nil,ut),
        requiresChampion=safe(DoesGroupFinderUserTypeGroupListingRequireChampion,false,ut), cp=safe(GetGroupFinderCreateGroupListingChampionPoints,0,ut),
        requiresVOIP=safe(DoesGroupFinderUserTypeGroupListingRequireVOIP,false,ut), requiresCode=safe(DoesGroupFinderUserTypeGroupListingRequireInviteCode,false,ut), code=safe(GetGroupFinderUserTypeGroupListingInviteCode,"",ut),
        autoAccept=safe(DoesGroupFinderUserTypeGroupListingAutoAcceptRequests,false,ut), enforceRoles=safe(DoesGroupFinderUserTypeGroupListingEnforceRoles,false,ut),
        tank=safe(GetGroupFinderUserTypeGroupListingDesiredRoleCount,0,ut,LFG_ROLE_TANK), heal=safe(GetGroupFinderUserTypeGroupListingDesiredRoleCount,0,ut,LFG_ROLE_HEAL), dps=safe(GetGroupFinderUserTypeGroupListingDesiredRoleCount,0,ut,LFG_ROLE_DPS),
    }
end

function GF:RestoreSavedListing()
    local sv=self:GetSV(); local d=sv and sv.savedListing
    if not d then notify("No saved Group Finder listing yet.") return end
    if safe(HasGroupListingForUserType,false,rawget(_G,"GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING") or 1) then notify("A Group Finder listing is already active.") return end
    local ut=rawget(_G,"GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING") or 1
    local calls={{SetGroupFinderUserTypeGroupListingCategory,d.category},{SetGroupFinderUserTypeGroupListingPrimaryOption,d.mode},{SetGroupFinderUserTypeGroupListingSecondaryOption,d.target},{SetGroupFinderUserTypeGroupListingGroupSize,d.groupSize},{SetGroupFinderUserTypeGroupListingPlaystyle,d.playstyle},{SetGroupFinderUserTypeGroupListingRequiresChampion,d.requiresChampion},{SetGroupFinderUserTypeGroupListingChampionPoints,d.cp},{SetGroupFinderUserTypeGroupListingRequiresVOIP,d.requiresVOIP},{SetGroupFinderUserTypeGroupListingRequiresInviteCode,d.requiresCode},{SetGroupFinderUserTypeGroupListingInviteCode,d.code},{SetGroupFinderUserTypeGroupListingAutoAcceptRequests,d.autoAccept},{SetGroupFinderUserTypeGroupListingEnforceRoles,d.enforceRoles}}
    for _,x in ipairs(calls) do if type(x[1])=="function" and x[2]~=nil then pcall(x[1],ut,x[2]) end end
    if type(SetGroupFinderUserTypeGroupListingRoleCount)=="function" then pcall(SetGroupFinderUserTypeGroupListingRoleCount,ut,LFG_ROLE_TANK,d.tank or 0); pcall(SetGroupFinderUserTypeGroupListingRoleCount,ut,LFG_ROLE_HEAL,d.heal or 0); pcall(SetGroupFinderUserTypeGroupListingRoleCount,ut,LFG_ROLE_DPS,d.dps or 0) end
    if type(SetGroupFinderUserTypeGroupListingTitle)=="function" then pcall(SetGroupFinderUserTypeGroupListingTitle,ut,d.title or "") end
    if type(SetGroupFinderUserTypeGroupListingDescription)=="function" then pcall(SetGroupFinderUserTypeGroupListingDescription,ut,d.description or "") end
    if type(RequestCreateGroupListing)=="function" then pcall(RequestCreateGroupListing) end
end

function GF:InstallAllowAllRolesHook()
    if self.rolesHookDone or not GROUP_FINDER_SEARCH_MANAGER or type(ZO_PreHook)~="function" then return end
    self.rolesHookDone=true
    ZO_PreHook(GROUP_FINDER_SEARCH_MANAGER,"ExecuteSearch",function()
        local sv=GF:GetSV(); if sv and sv.enabled and sv.allowAllRoles and type(SetGroupFinderFilterEnforceRoles)=="function" then pcall(SetGroupFinderFilterEnforceRoles,false) end
    end)
end

function GF:Initialize()
    if self.initialized then return end
    self.initialized=true; self.hiddenSession={}; self.rows={}; self.listings={}
    self:GetSV(); self:InstallAllowAllRolesHook(); self:CreateWindow(); self:CreateNativeEnhancementButtons(); self:RefreshVisibility()
    EM:RegisterForEvent(NAME.."_Search",EVENT_GROUP_FINDER_SEARCH_COMPLETE,function(_,result) if result==GROUP_FINDER_ACTION_RESULT_SUCCESS and GF:IsOverlayAllowed() then GF:RefreshRows() end end)
    if rawget(_G,"EVENT_GROUP_FINDER_CREATE_GROUP_LISTING_RESULT") then EM:RegisterForEvent(NAME.."_Create",EVENT_GROUP_FINDER_CREATE_GROUP_LISTING_RESULT,function(_,result) if result==GROUP_FINDER_ACTION_RESULT_SUCCESS then zo_callLater(function() GF:SaveCurrentListing(); GF:RefreshVisibility() end,400) end end) end
    if rawget(_G,"EVENT_GROUP_FINDER_UPDATE_GROUP_LISTING_RESULT") then EM:RegisterForEvent(NAME.."_Update",EVENT_GROUP_FINDER_UPDATE_GROUP_LISTING_RESULT,function() zo_callLater(function() GF:SaveCurrentListing() end,400) end) end
    if rawget(_G,"EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_RESULT") then EM:RegisterForEvent(NAME.."_Remove",EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_RESULT,function() GF:RefreshVisibility() end) end
    EM:RegisterForEvent(NAME.."_Activated",EVENT_PLAYER_ACTIVATED,function() GF:CreateNativeEnhancementButtons(); GF:RefreshVisibility() end)
    SLASH_COMMANDS=SLASH_COMMANDS or {}
    SLASH_COMMANDS["/easgf"]=function(arg)
        arg=lower(arg)
        local sv=GF:GetSV()
        if arg=="overlay" then sv.showHudOverlay=not sv.showHudOverlay GF:RefreshVisibility(); notify("Group Finder HUD overlay "..(sv.showHudOverlay and "enabled" or "disabled")..".")
        elseif arg=="recreate" then GF:RestoreSavedListing()
        elseif arg=="search" then GF:RequestSearch(true)
        else notify("/easgf overlay | recreate | search") end
    end
end

function ESOAdventurerSuite_GroupFinderPlusToggleOverlay()
    local sv=GF:GetSV(); if not sv then return end
    sv.showHudOverlay=not sv.showHudOverlay; GF:RefreshVisibility()
end
function ESOAdventurerSuite_GroupFinderPlusCycleCategory() GF:CycleCategory() end
function ESOAdventurerSuite_GroupFinderPlusSwitchMode() GF:SwitchMode() end
function ESOAdventurerSuite_GroupFinderPlusRecreate() GF:RestoreSavedListing() end

if type(ZO_CreateStringId)=="function" then
    ZO_CreateStringId("SI_BINDING_NAME_ESO_ADVENTURER_SUITE_GF_OVERLAY","Toggle Group Finder HUD Overlay")
    ZO_CreateStringId("SI_BINDING_NAME_ESO_ADVENTURER_SUITE_GF_CATEGORY","Next Group Finder Category")
    ZO_CreateStringId("SI_BINDING_NAME_ESO_ADVENTURER_SUITE_GF_MODE","Switch Group Finder Normal / Veteran")
    ZO_CreateStringId("SI_BINDING_NAME_ESO_ADVENTURER_SUITE_GF_RECREATE","Recreate Last Group Finder Listing")
end

EM:RegisterForEvent(NAME.."_Loaded",EVENT_ADD_ON_LOADED,function(_,addonName)
    if addonName~=(EPC.name or "ESOAdventurerSuite") then return end
    EM:UnregisterForEvent(NAME.."_Loaded",EVENT_ADD_ON_LOADED)
    if type(zo_callLater)=="function" then zo_callLater(function() GF:Initialize() end,0) else GF:Initialize() end
end)


-- Group Finder absorbed correction layers

-- BEGIN ABSORBED: GroupFinderPlusSafetyFix.lua
-- ESO Adventurer Suite
-- v0.29.669 Group Finder Plus interaction/color hardening.
local EPC = ESOProgressionCoach
local GF = EPC and EPC.GroupFinderPlus
if not GF then return end

-- The reference addon avoided three identical consecutive hex digits because
-- Group Finder text validation can reject/sanitize some color-code patterns.
local function safeHex(hex)
    hex = tostring(hex or "A020F0"):upper():gsub("[^0-9A-F]", "")
    if #hex ~= 6 then hex = "A020F0" end
    local out, previous, run = {}, nil, 0
    for i=1,#hex do
        local c=hex:sub(i,i)
        if c==previous then run=run+1 else run=1 end
        if run>2 then
            local n=tonumber(c,16) or 0
            c=string.format("%X",(n+1)%16)
            run=1
        end
        out[#out+1]=c
        previous=c
    end
    return table.concat(out)
end

function GF:GetSV()
    local sv = EAS_GetSVCore(self)
    if sv then
        if sv.titleColor==nil or sv.titleColor=="B000FF" then sv.titleColor="A020F0" end
        sv.titleColor=safeHex(sv.titleColor)
        sv.descriptionColor=safeHex(sv.descriptionColor or "8A2BE2")
    end
    return sv
end

local function EAS_ApplyColorCore(self, kind)
    local sv=self:GetSV(); if not sv or not WINDOW_MANAGER then return end
    local name=(kind=="description") and "ZO_GroupFinder_Keyboard_TopLevelCreateGroupListingPanelContentDescriptionEdit" or "ZO_GroupFinder_Keyboard_TopLevelCreateGroupListingPanelContentGroupTitleBackdropEdit"
    local field=WINDOW_MANAGER:GetControlByName(name)
    if not field or type(field.GetText)~="function" or type(field.SetText)~="function" then return end
    local text=tostring(field:GetText() or ""):gsub("|c%x%x%x%x%x%x",""):gsub("|r","")
    text=text:gsub("^%s+",""):gsub("%s+$","")
    if text=="" then return end
    local hex=safeHex(kind=="description" and sv.descriptionColor or sv.titleColor)
    field:SetText("|c"..hex..text.."|r")
end

-- Rebuild the native helper controls lazily if Group Finder keyboard controls
-- were not instantiated yet at addon load. Each helper has its own guard.
local function EAS_CreateNativeEnhancementButtonsCore(self)
    if not WINDOW_MANAGER then return end
    local WM=WINDOW_MANAGER
    local function ensureSwatch(controlName, kind)
        if self["native"..kind.."Button029669"] then return true end
        local field=WM:GetControlByName(controlName)
        if not field then return false end
        local c=WM:CreateControl("EAS_GroupFinderPlus_"..kind.."Color",field:GetParent(),CT_BUTTON)
        c:SetDimensions(30,24); c:SetFont("ZoFontGameBold"); c:SetText("■"); c:SetAnchor(RIGHT,field,LEFT,-6,0)
        c:SetHandler("OnMouseEnter",function(control) InitializeTooltip(InformationTooltip,control,RIGHT,4,0); SetTooltipText(InformationTooltip,"Choose "..kind.." text color") end)
        c:SetHandler("OnMouseExit",function() ClearTooltip(InformationTooltip) end)
        c:SetHandler("OnClicked",function() GF:ShowColorPicker(kind) end)
        self["native"..kind.."Button029669"]=c
        return true
    end
    ensureSwatch("ZO_GroupFinder_Keyboard_TopLevelCreateGroupListingPanelContentGroupTitleBackdropEdit","title")
    ensureSwatch("ZO_GroupFinder_Keyboard_TopLevelCreateGroupListingPanelContentDescriptionEdit","description")

    if not self.nativeRecreateButton029669 then
        local overview=WM:GetControlByName("ZO_GroupFinder_Keyboard_TopLevelOverview")
        local create=overview and overview:GetNamedChild("CreateGroupButton")
        if overview and create then
            local b=WM:CreateControl("EAS_GroupFinderPlus_RecreateButton",overview,CT_BUTTON)
            b:SetDimensions(105,30); b:SetFont("ZoFontGameSmall"); b:SetText("RECREATE"); b:SetAnchor(RIGHT,create,LEFT,-8,0)
            b:SetHandler("OnClicked",function() GF:RestoreSavedListing() end)
            self.nativeRecreateButton029669=b
        end
    end
end

-- Match the reference interaction: rows drag the HUD on single left click and
-- only apply to a listing on a deliberate double-click. Right-click keeps the
-- context menu.
function GF:CreateRow(index)
    local row=EAS_CreateRowCore(self,index)
    if not row or row.easGroupFinderGesture029669 then return row end
    row.easGroupFinderGesture029669=true
    row:SetHandler("OnMouseDown",function(control,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and GF.window then GF.window:StartMoving() end
    end)
    row:SetHandler("OnMouseUp",function(control,button,upInside)
        if button==MOUSE_BUTTON_INDEX_LEFT and GF.window then GF.window:StopMovingOrResizing()
        elseif button==MOUSE_BUTTON_INDEX_RIGHT and upInside~=false then GF:ShowContextMenu(control) end
    end)
    row:SetHandler("OnMouseDoubleClick",function(control,button)
        if button==MOUSE_BUTTON_INDEX_LEFT then GF:ApplyToRow(control) end
    end)
    return row
end

-- Use the same keyboard application-dialog data contract ESO's Group Finder
-- expects so invite-code/manual-approval listings behave correctly.
function GF:ApplyToRow(row)
    if not row or not row.data then return end
    local data=row.data
    local index=tonumber(data.index)
    if not index then return end
    local joinResult=type(GetGroupFinderSearchListingJoinabilityResult)=="function" and GetGroupFinderSearchListingJoinabilityResult(index) or 0
    if joinResult==13 then
        if EPC and EPC.Print then EPC:Print("That listing does not accept your current role.") end
        return
    end
    local auto=type(DoesGroupFinderSearchListingAutoAcceptRequests)=="function" and DoesGroupFinderSearchListingAutoAcceptRequests(index)==true
    if auto then
        if type(RequestApplyToGroupListing)=="function" then pcall(RequestApplyToGroupListing,index,nil,nil) end
        return
    end
    if type(ZO_Dialogs_ShowDialog)=="function" then
        local session=data.session
        local dialogData={
            GetListingIndex=function()
                for _,listing in ipairs(GF.listings or {}) do if listing.session==session then return listing.index end end
                return index
            end,
            GetTitle=function() return data.title or "" end,
            DoesGroupAutoAcceptRequests=function() return auto end,
            DoesGroupRequireInviteCode=function()
                return type(DoesGroupFinderSearchListingRequireInviteCode)=="function" and DoesGroupFinderSearchListingRequireInviteCode(index)==true
            end,
        }
        pcall(ZO_Dialogs_ShowDialog,"GROUP_FINDER_APPLICATION_KEYBOARD",dialogData)
    elseif type(RequestApplyToGroupListing)=="function" then
        pcall(RequestApplyToGroupListing,index)
    end
end

-- END ABSORBED: GroupFinderPlusSafetyFix.lua

-- BEGIN ABSORBED: GroupFinderPlusSwatchFix.lua
-- ESO Adventurer Suite
-- v0.29.671 - Group Finder Plus native color swatch presentation fix.
-- ESO's Group Finder font does not render the Unicode square glyph reliably;
-- replace it with a real backdrop so the selected color is always visible.

local EPC = ESOProgressionCoach
if not EPC or not WINDOW_MANAGER then return end
local GF = EPC.GroupFinderPlus
if type(GF) ~= "table" then return end
local WM = WINDOW_MANAGER

local function colorRGB(kind)
    local sv = type(GF.GetSV) == "function" and GF:GetSV() or nil
    local hex = sv and ((kind == "description") and sv.descriptionColor or sv.titleColor) or "FFFFFF"
    hex = tostring(hex or "FFFFFF"):upper():gsub("[^0-9A-F]", "")
    if #hex ~= 6 then hex = "FFFFFF" end
    local color = ZO_ColorDef and ZO_ColorDef:New(hex) or nil
    if color and type(color.UnpackRGB) == "function" then
        return color:UnpackRGB()
    end
    return 1, 1, 1
end

local function ensureSwatch(kind)
    local button = WM:GetControlByName("EAS_GroupFinderPlus_" .. tostring(kind) .. "Color")
    if not button then return false end

    if type(button.SetText) == "function" then button:SetText("") end

    local swatch = button.epcColorSwatch029671
    if not swatch then
        swatch = WM:CreateControl(nil, button, CT_BACKDROP)
        swatch:SetAnchor(TOPLEFT, button, TOPLEFT, 4, 4)
        swatch:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -4, -4)
        swatch:SetMouseEnabled(false)
        swatch:SetEdgeTexture(nil, 1, 1, 1)
        swatch:SetEdgeColor(0.85, 0.82, 0.68, 1)
        button.epcColorSwatch029671 = swatch
    end

    local r, g, b = colorRGB(kind)
    swatch:SetCenterColor(r, g, b, 1)
    return true
end

local function refreshSwatches()
    ensureSwatch("title")
    ensureSwatch("description")
end

function GF:CreateNativeEnhancementButtons(...)
    local result = EAS_CreateNativeEnhancementButtonsCore(self, ...)
    refreshSwatches()
    return result
end

function GF:ApplyColorToField(kind, ...)
    local result = EAS_ApplyColorCore(self, kind, ...)
    ensureSwatch(kind)
    return result
end

local function applyNow()
    if type(GF.CreateNativeEnhancementButtons) == "function" then
        GF:CreateNativeEnhancementButtons()
    end
    refreshSwatches()
end

if type(zo_callLater) == "function" then
    zo_callLater(applyNow, 0)
    zo_callLater(applyNow, 500)
else
    applyNow()
end

if EVENT_MANAGER and rawget(_G, "EVENT_PLAYER_ACTIVATED") then
    local key = (EPC.name or "ESOAdventurerSuite") .. "_GroupFinderPlusSwatch029671"
    EPC.Runtime:RegisterEvent("GroupFinderPlusIntegration","SwatchActivated",EVENT_PLAYER_ACTIVATED, function()
        if type(zo_callLater) == "function" then zo_callLater(applyNow, 200) else applyNow() end
    end)
end

EPC.groupFinderPlusSwatchFix029671 = true

-- END ABSORBED: GroupFinderPlusSwatchFix.lua

-- BEGIN ABSORBED: GroupFinderTooltipPositionFix.lua
-- ESO Adventurer Suite
-- Group Finder tooltip placement polish (0.29.693).
-- Keeps listing details readable without covering the left-side Group Finder tabs.

local EPC = ESOProgressionCoach
local GF = EPC and EPC.GroupFinderPlus
if not GF or not WINDOW_MANAGER or not GuiRoot then return end
if GF._tooltipPositionFix029693 then return end
GF._tooltipPositionFix029693 = true

local WM = WINDOW_MANAGER
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_GroupFinderTooltip029693"

local function callMethod(object, methodName, fallback, ...)
    if not object then return fallback end
    local method = object[methodName]
    if type(method) ~= "function" then return fallback end
    local ok, a, b, c, d = pcall(method, object, ...)
    if not ok or a == nil then return fallback end
    return a, b, c, d
end

local function clean(text)
    return tostring(text or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function colorMarkupOnly(text)
    text = tostring(text or "")
    if type(EscapeMarkup) == "function" and rawget(_G, "ALLOW_MARKUP_TYPE_COLOR_ONLY") then
        local ok, escaped = pcall(EscapeMarkup, text, ALLOW_MARKUP_TYPE_COLOR_ONLY)
        if ok and escaped then return escaped end
    end
    return text
end

local function yesNo(value)
    if type(GetString) == "function" then
        local id = value and rawget(_G, "SI_DIALOG_YES") or rawget(_G, "SI_DIALOG_NO")
        if id then
            local ok, text = pcall(GetString, id)
            if ok and text then return text end
        end
    end
    return value and "Yes" or "No"
end

local function EAS_EnsureCompactListingTooltipCore(self)
    if self.compactListingTooltip029693 then return self.compactListingTooltip029693 end

    local root = WM:CreateTopLevelWindow("EAS_GroupFinderCompactTooltip029693")
    root:SetDimensions(300, 410)
    root:SetMouseEnabled(false)
    root:SetClampedToScreen(true)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)

    local bg = WM:CreateControl(nil, root, CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0.015, 0.018, 0.025, 0.96)
    bg:SetEdgeColor(0.72, 0.64, 0.42, 0.95)
    bg:SetEdgeTexture(nil, 1, 1, 1)

    local title = WM:CreateControl(nil, root, CT_LABEL)
    title:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 11)
    title:SetDimensions(276, 52)
    title:SetFont("ZoFontWinH3")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    title:SetColor(1, 0.85, 0.35, 1)

    local divider = WM:CreateControl(nil, root, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 4)
    divider:SetDimensions(276, 1)
    divider:SetColor(0.62, 0.56, 0.39, 0.9)

    local body = WM:CreateControl(nil, root, CT_LABEL)
    body:SetAnchor(TOPLEFT, divider, BOTTOMLEFT, 0, 8)
    body:SetDimensions(276, 325)
    body:SetFont("ZoFontGame")
    body:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)
    body:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    body:SetColor(0.92, 0.92, 0.9, 1)

    root.easTitle029693 = title
    root.easBody029693 = body
    self.compactListingTooltip029693 = root
    return root
end

local function EAS_BuildCompactListingTextCore(self, data)
    if not data then return "" end

    local ownerDisplay = callMethod(data, "GetOwnerDisplayName", "")
    local ownerCharacter = callMethod(data, "GetOwnerCharacterName", "")
    local owner = tostring(ownerDisplay or "")
    if type(ZO_GetPrimaryPlayerNameWithSecondary) == "function" then
        local ok, formatted = pcall(ZO_GetPrimaryPlayerNameWithSecondary, ownerDisplay, ownerCharacter)
        if ok and formatted then owner = formatted end
    elseif ownerCharacter and ownerCharacter ~= "" then
        owner = tostring(ownerCharacter) .. " (" .. tostring(ownerDisplay) .. ")"
    end

    local category = tonumber(callMethod(data, "GetCategory", 0)) or 0
    local categoryText = tostring(category)
    if type(GetString) == "function" then
        local ok, text = pcall(GetString, "SI_GROUPFINDERCATEGORY", category)
        if ok and text and text ~= "" then categoryText = text end
    end

    local primary = tostring(callMethod(data, "GetPrimaryOptionText", "") or "")
    local secondary = tostring(callMethod(data, "GetSecondaryOptionText", "") or "")
    local optionParts = {}
    if primary ~= "" then optionParts[#optionParts + 1] = primary end
    if secondary ~= "" and secondary ~= primary then optionParts[#optionParts + 1] = secondary end
    if #optionParts > 0 then categoryText = categoryText .. " — " .. table.concat(optionParts, ", ") end

    local playerCount, roleList = "", ""
    if type(ZO_GroupFinder_GroupListing_GetPlayerCountAndRoleStrings) == "function" then
        local ok, a, b = pcall(ZO_GroupFinder_GroupListing_GetPlayerCountAndRoleStrings, data, 24)
        if ok then playerCount, roleList = tostring(a or ""), tostring(b or "") end
    end

    local desc = colorMarkupOnly(callMethod(data, "GetDescription", "") or "")
    local requiresChampion = callMethod(data, "DoesGroupRequireChampion", false) == true
    local championPoints = callMethod(data, "GetChampionPoints", 0)
    local championText = requiresChampion and tostring(championPoints or 0) or "N/A"
    local requiresInvite = callMethod(data, "DoesGroupRequireInviteCode", false) == true
    local autoAccept = callMethod(data, "DoesGroupAutoAcceptRequests", false) == true
    local requiresVoice = callMethod(data, "DoesGroupRequireVOIP", false) == true

    local lines = {
        "|cC8B98CListing Owner|r  " .. tostring(owner or ""),
        "|cC8B98CCategory|r  " .. categoryText,
    }

    if playerCount ~= "" or roleList ~= "" then
        lines[#lines + 1] = "|cC8B98CPlayers|r  " .. playerCount .. (roleList ~= "" and ("   " .. roleList) or "")
    end

    if clean(desc) ~= "" then
        lines[#lines + 1] = ""
        lines[#lines + 1] = desc
        lines[#lines + 1] = ""
    end

    lines[#lines + 1] = "|cC8B98CChampion Points Required|r  " .. championText
    lines[#lines + 1] = "|cC8B98CRequires Invite Code|r  " .. yesNo(requiresInvite)

    if category == rawget(_G, "GROUP_FINDER_CATEGORY_DUNGEON")
        or category == rawget(_G, "GROUP_FINDER_CATEGORY_ARENA")
        or category == rawget(_G, "GROUP_FINDER_CATEGORY_TRIAL") then
        local playstyle = tonumber(callMethod(data, "GetPlaystyle", 0)) or 0
        local playstyleText = tostring(playstyle)
        if type(GetString) == "function" then
            local ok, text = pcall(GetString, "SI_GROUPFINDERPLAYSTYLE", playstyle)
            if ok and text and text ~= "" then playstyleText = text end
        end
        lines[#lines + 1] = "|cC8B98CPlaystyle|r  " .. playstyleText
    end

    lines[#lines + 1] = "|cC8B98CAuto Accepts Applications|r  " .. yesNo(autoAccept)
    lines[#lines + 1] = "|cC8B98CRequires Voice Chat|r  " .. yesNo(requiresVoice)

    if type(ZO_GroupFinder_GroupListing_GetDesiredRolesList) == "function" then
        local ok, roles = pcall(ZO_GroupFinder_GroupListing_GetDesiredRolesList, data, 24)
        if ok and roles and roles ~= "" then
            lines[#lines + 1] = "|cC8B98CLooking For|r  " .. tostring(roles)
        end
    end

    local warning = callMethod(data, "GetWarningText", nil)
    if warning and warning ~= "" then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cFF6666" .. clean(warning) .. "|r"
    end

    return table.concat(lines, "\n")
end

function GF:PositionCompactListingTooltip029693(anchorControl)
    local tip = self:EnsureCompactListingTooltip029693()
    if not tip then return end

    local screenW = tonumber(GuiRoot:GetWidth()) or 1920
    local screenH = tonumber(GuiRoot:GetHeight()) or 1080
    local anchorLeft = anchorControl and tonumber(anchorControl:GetLeft()) or (screenW * 0.68)
    local anchorTop = anchorControl and tonumber(anchorControl:GetTop()) or (screenH * 0.25)

    -- Native Group Finder keeps roughly a 280px navigation strip to the left of
    -- the listing content. Place the compact tooltip just left of that strip,
    -- but clamp its left edge so it does not slide over the character preview.
    local width, height = 300, 410
    local rightEdge = anchorLeft - 265
    local left = rightEdge - width
    local characterSafeLeft = screenW * 0.31
    if left < characterSafeLeft then left = characterSafeLeft end
    if left + width > screenW - 20 then left = screenW - width - 20 end

    local top = math.max(95, anchorTop - 105)
    if top + height > screenH - 55 then top = math.max(40, screenH - height - 55) end

    tip:ClearAnchors()
    tip:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

local function EAS_ShowCompactListingTooltipCore(self, anchorControl, data)
    if not data then return end
    if GroupFinderGroupListingTooltip and type(ClearTooltip) == "function" then
        pcall(ClearTooltip, GroupFinderGroupListingTooltip)
    end

    local tip = self:EnsureCompactListingTooltip029693()
    if not tip then return end
    tip.easTitle029693:SetText(colorMarkupOnly(callMethod(data, "GetTitle", "") or ""))
    tip.easBody029693:SetText(self:BuildCompactListingText029693(data))
    self:PositionCompactListingTooltip029693(anchorControl)
    tip:SetHidden(false)
end

function GF:HideCompactListingTooltip029693()
    if self.compactListingTooltip029693 then
        self.compactListingTooltip029693:SetHidden(true)
    end
end

function GF:PatchNativeListingTooltips029693()
    local keyboard = rawget(_G, "GROUP_FINDER_KEYBOARD")
    if not keyboard then return false end

    local applications = keyboard.applicationsManagementContent
    if applications and applications.myListingControl and applications.myListingData then
        local control = applications.myListingControl
        if not control.easCompactTooltip029693 then
            control.easCompactTooltip029693 = true
            control:SetHandler("OnMouseEnter", function(c)
                GF:ShowCompactListingTooltip029693(c, applications.myListingData)
            end)
            control:SetHandler("OnMouseExit", function()
                GF:HideCompactListingTooltip029693()
            end)
        end
    end

    local overview = keyboard.overviewAppliedToGroupListingControl
    if overview and keyboard.appliedToListingData and not overview.easCompactTooltip029693 then
        overview.easCompactTooltip029693 = true
        overview:SetHandler("OnMouseEnter", function(c)
            GF:ShowCompactListingTooltip029693(c, keyboard.appliedToListingData)
            if KEYBIND_STRIP and keyboard.appliedToListingKeybindStripDescriptor then
                KEYBIND_STRIP:AddKeybindButtonGroup(keyboard.appliedToListingKeybindStripDescriptor)
            end
        end)
        overview:SetHandler("OnMouseExit", function()
            GF:HideCompactListingTooltip029693()
            if KEYBIND_STRIP and keyboard.appliedToListingKeybindStripDescriptor then
                KEYBIND_STRIP:RemoveKeybindButtonGroup(keyboard.appliedToListingKeybindStripDescriptor)
            end
        end)
    end

    return applications and applications.myListingControl ~= nil
end

-- Search-result rows use the same native 512px tooltip. Keep ESO's native row
-- hover/keybind behavior, then replace only the tooltip with the compact panel.
if rawget(_G, "ZO_GroupFinder_SearchResultsList_Keyboard")
    and type(ZO_GroupFinder_SearchResultsList_Keyboard.Row_OnMouseEnter) == "function"
    and not ZO_GroupFinder_SearchResultsList_Keyboard.easCompactTooltipPatched029693 then

    ZO_GroupFinder_SearchResultsList_Keyboard.easCompactTooltipPatched029693 = true
    local baseEnter = ZO_GroupFinder_SearchResultsList_Keyboard.Row_OnMouseEnter
    local baseExit = ZO_GroupFinder_SearchResultsList_Keyboard.Row_OnMouseExit

    function ZO_GroupFinder_SearchResultsList_Keyboard:Row_OnMouseEnter(control)
        baseEnter(self, control)
        if GroupFinderGroupListingTooltip and type(ClearTooltip) == "function" then
            pcall(ClearTooltip, GroupFinderGroupListingTooltip)
        end
        local data = type(ZO_ScrollList_GetData) == "function" and ZO_ScrollList_GetData(control) or nil
        if data then GF:ShowCompactListingTooltip029693(control, data) end
    end

    function ZO_GroupFinder_SearchResultsList_Keyboard:Row_OnMouseExit(control)
        GF:HideCompactListingTooltip029693()
        if type(baseExit) == "function" then return baseExit(self, control) end
    end
end

local function install(retries)
    if GF:PatchNativeListingTooltips029693() then return end
    if retries > 0 and type(zo_callLater) == "function" then
        zo_callLater(function() install(retries - 1) end, 500)
    end
end

install(8)

if EVENT_MANAGER and rawget(_G, "EVENT_PLAYER_ACTIVATED") then
    EPC.Runtime:RegisterEvent("GroupFinderPlusIntegration","TooltipActivated",EVENT_PLAYER_ACTIVATED, function()
        GF:HideCompactListingTooltip029693()
        if type(zo_callLater) == "function" then
            zo_callLater(function() GF:PatchNativeListingTooltips029693() end, 100)
        else
            GF:PatchNativeListingTooltips029693()
        end
    end)
end

EPC.groupFinderTooltipPositionFix029693 = true

-- END ABSORBED: GroupFinderTooltipPositionFix.lua

-- BEGIN ABSORBED: GroupFinderTooltipWrapFix.lua
-- ESO Adventurer Suite
-- Group Finder compact-tooltip wrapping/auto-height polish.
-- Loaded after GroupFinderTooltipPositionFix.lua.

local EPC = ESOProgressionCoach
local GF = EPC and EPC.GroupFinderPlus
if not GF or GF._tooltipWrapFix029694 then return end
GF._tooltipWrapFix029694 = true

function GF:PositionWrappedListingTooltip029694(anchorControl)
    local tip = self:EnsureCompactListingTooltip029693()
    if not tip or not GuiRoot then return end

    local screenW = tonumber(GuiRoot:GetWidth()) or 1920
    local screenH = tonumber(GuiRoot:GetHeight()) or 1080
    local anchorLeft = anchorControl and tonumber(anchorControl:GetLeft()) or (screenW * 0.68)
    local anchorTop = anchorControl and tonumber(anchorControl:GetTop()) or (screenH * 0.25)

    local width = tonumber(tip:GetWidth()) or 300
    local height = tonumber(tip:GetHeight()) or 410

    -- Keep the right edge beside the Group Finder navigation strip. This leaves
    -- the tabs readable while avoiding an unnecessary shift over the character.
    local rightEdge = anchorLeft - 265
    local left = rightEdge - width
    local characterSafeLeft = screenW * 0.31
    if left < characterSafeLeft then left = characterSafeLeft end
    if left + width > screenW - 20 then left = screenW - width - 20 end

    local top = math.max(78, anchorTop - 105)
    if top + height > screenH - 45 then
        top = math.max(38, screenH - height - 45)
    end

    tip:ClearAnchors()
    tip:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

EPC.groupFinderTooltipWrapFix029694 = true


-----------------------------------------------------------------------
-- 0.29.751: native Group Finder tooltip readability fallback.
-- Some Group Finder Plus views still invoke ESO's stock listing tooltip
-- instead of the Suite compact tooltip. ESO lays the requirement labels
-- out in two columns, which can make long labels/role lists collide.
-----------------------------------------------------------------------

local function EAS_LayoutNativeGroupFinderTooltip029751(tooltipControl)
    if not tooltipControl then return end

    -- ESO's stock description is capped at 10 lines. Group Finder listing
    -- descriptions are short enough to remain screen-safe with this higher
    -- limit, while no longer hiding valid text behind an ellipsis.
    local description = tooltipControl.descriptionLabel
        or (type(tooltipControl.GetNamedChild) == "function" and tooltipControl:GetNamedChild("Description"))
    if description then
        if type(description.SetMaxLineCount) == "function" then
            description:SetMaxLineCount(32)
        end
        if type(description.SetWidth) == "function" then
            description:SetWidth(480)
        end
    end

    local flagsSection = type(tooltipControl.GetNamedChild) == "function"
        and tooltipControl:GetNamedChild("FlagsSection")
        or nil
    if not flagsSection then return end

    local labels = {
        tooltipControl.championLabel,
        tooltipControl.inviteCodeLabel,
        tooltipControl.playstyleLabel,
        tooltipControl.autoAcceptLabel,
        tooltipControl.VOIPLabel,
        tooltipControl.lookingForLabel,
    }

    -- Replace ESO's two-column requirement layout with one full-width
    -- vertical column. This prevents "Requires Voice Chat" and "Looking For"
    -- (and localized equivalents) from drawing into each other.
    local previous
    for _, label in ipairs(labels) do
        if label and (type(label.IsHidden) ~= "function" or not label:IsHidden()) then
            if type(label.ClearAnchors) == "function" then label:ClearAnchors() end
            if type(label.SetWidth) == "function" then label:SetWidth(480) end
            if type(label.SetMaxLineCount) == "function" then label:SetMaxLineCount(6) end

            if type(label.SetAnchor) == "function" then
                if previous then
                    label:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 8)
                else
                    label:SetAnchor(TOPLEFT, flagsSection, TOPLEFT, 0, 0)
                end
            end
            previous = label
        end
    end
end

if type(ZO_PostHook) == "function"
    and type(rawget(_G, "ZO_GroupFinderGroupListingTooltip_SetGroupFinderListing")) == "function" then

    ZO_PostHook("ZO_GroupFinderGroupListingTooltip_SetGroupFinderListing", function(tooltipControl)
        EAS_LayoutNativeGroupFinderTooltip029751(tooltipControl)
    end)
elseif type(rawget(_G, "ZO_GroupFinderGroupListingTooltip_SetGroupFinderListing")) == "function" then
    local baseNativeSetGroupFinderListing029751 = ZO_GroupFinderGroupListingTooltip_SetGroupFinderListing
    function ZO_GroupFinderGroupListingTooltip_SetGroupFinderListing(tooltipControl, ...)
        local result = baseNativeSetGroupFinderListing029751(tooltipControl, ...)
        EAS_LayoutNativeGroupFinderTooltip029751(tooltipControl)
        return result
    end
end

EPC.groupFinderNativeTooltipReadabilityFix029751 = true


-----------------------------------------------------------------------
-- 0.29.752: compact Group Finder tooltip full-text sizing fix.
-- The compact panel was measuring GetTextHeight while its body was still
-- constrained to the original 325px height. That made the measured height
-- stop at the control boundary and left the final requirements clipped.
-----------------------------------------------------------------------

function GF:EnsureCompactListingTooltip029693()
    local tip = EAS_EnsureCompactListingTooltipCore(self)
    if not tip then return tip end

    tip:SetWidth(360)
    local title = tip.easTitle029693
    local body = tip.easBody029693
    if title then
        title:SetWidth(336)
        if type(title.SetMaxLineCount) == "function" then title:SetMaxLineCount(3) end
    end
    if body then
        body:SetWidth(336)
        if type(body.SetMaxLineCount) == "function" then body:SetMaxLineCount(64) end
    end
    return tip
end

function GF:BuildCompactListingText029693(data)
    local text = tostring(EAS_BuildCompactListingTextCore(self, data) or "")
    text = text:gsub("\n(|cC8B98CLooking For|r)", "\n\n%1")
    return text
end

local function EAS_ResizeCompactTooltipToFullText029752(self, anchorControl)
    local tip = self.compactListingTooltip029693
    if not tip then return end
    local body = tip.easBody029693
    if not body then return end

    body:SetWidth(336)
    if type(body.SetMaxLineCount) == "function" then body:SetMaxLineCount(64) end

    -- IMPORTANT: expand first, then measure. Measuring while the control is
    -- still 325px tall only reports the clipped render height.
    body:SetHeight(760)

    local currentText = type(body.GetText) == "function" and tostring(body:GetText() or "") or ""
    if currentText ~= "" and type(body.SetText) == "function" then
        -- Re-setting after the width/height change forces ESO to recompute wrap.
        body:SetText(currentText)
    end

    local measured = type(body.GetTextHeight) == "function" and tonumber(body:GetTextHeight()) or 0
    local _, newlineCount = currentText:gsub("\n", "\n")
    local explicitLines = (newlineCount or 0) + 1
    local lineFloor = explicitLines * 22 + 6
    local textHeight = math.max(measured or 0, lineFloor, 80)

    -- Keep the popup screen-safe while allowing far more room than the old
    -- 325px body. Ordinary listings will remain compact.
    local screenH = GuiRoot and tonumber(GuiRoot:GetHeight()) or 1080
    local maxBody = math.max(325, screenH - 170)
    textHeight = math.min(textHeight, maxBody)

    body:SetHeight(textHeight)
    tip:SetHeight(96 + textHeight)

    if type(self.PositionWrappedListingTooltip029694) == "function" then
        self:PositionWrappedListingTooltip029694(anchorControl)
    elseif type(self.PositionCompactListingTooltip029693) == "function" then
        self:PositionCompactListingTooltip029693(anchorControl)
    end
end

function GF:ShowCompactListingTooltip029693(anchorControl, data)
    EAS_ShowCompactListingTooltipCore(self, anchorControl, data)
    EAS_ResizeCompactTooltipToFullText029752(self, anchorControl)

    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if GF and GF.compactListingTooltip029693
                and not GF.compactListingTooltip029693:IsHidden() then
                EAS_ResizeCompactTooltipToFullText029752(GF, anchorControl)
            end
        end, 0)
    end
end

EPC.groupFinderCompactTooltipFullTextFix029752 = true

-- END ABSORBED: GroupFinderTooltipWrapFix.lua

-- BEGIN ABSORBED: GroupFinderRoleRequirementFix.lua
-- ESO Adventurer Suite
-- v0.29.696 Group Finder enforced-role reconciliation.
-- ESO validates requested listing roles against the roles already attained by
-- the current group. If the group changes while the create/edit panel is open,
-- the cached spinner minimums can be stale and ESO can reject an otherwise
-- sensible listing with a role-mismatch error. Refresh and rebalance once, only
-- when the player presses Create/Edit; no polling or OnUpdate is used.

local EPC = ESOProgressionCoach
local GF = EPC and EPC.GroupFinderPlus
if not GF then return end
if GF._easRoleRequirementFix029696 then return end
GF._easRoleRequirementFix029696 = true

local ROLE_TANK = rawget(_G, "LFG_ROLE_TANK")
local ROLE_HEAL = rawget(_G, "LFG_ROLE_HEAL")
local ROLE_DPS = rawget(_G, "LFG_ROLE_DPS")
local ROLE_ANY = rawget(_G, "LFG_ROLE_INVALID")
if not ROLE_TANK or not ROLE_HEAL or not ROLE_DPS or ROLE_ANY == nil then return end

local SPECIFIC_ROLES = { ROLE_TANK, ROLE_HEAL, ROLE_DPS }
local ALL_ROLES = { ROLE_TANK, ROLE_HEAL, ROLE_DPS, ROLE_ANY }

local function asCount(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    return math.floor(value + 0.5)
end

local function roleName(roleType)
    if roleType == ROLE_TANK then return "Tank" end
    if roleType == ROLE_HEAL then return "Healer" end
    if roleType == ROLE_DPS then return "Damage" end
    return "Any"
end

local function printMessage(text)
    if EPC and type(EPC.Print) == "function" then
        EPC:Print(text)
    elseif type(d) == "function" then
        d("[ESO Adventurer Suite] " .. tostring(text))
    end
end

-- Remember the role the player changed most recently. If ESO's live attained
-- role counts force a rebalance, preserve that requested role before trimming
-- spare slots from the other roles. This is what lets a player deliberately add
-- a Healer even when another group member's role changed after the panel opened.
if ZO_GroupListingUserTypeData
    and type(ZO_GroupListingUserTypeData.SetDesiredRoleCountAtEdit) == "function"
    and not ZO_GroupListingUserTypeData._easRoleEditTracking029696 then

    ZO_GroupListingUserTypeData._easRoleEditTracking029696 = true
    local baseSetDesiredRoleCountAtEdit = ZO_GroupListingUserTypeData.SetDesiredRoleCountAtEdit
    function ZO_GroupListingUserTypeData:SetDesiredRoleCountAtEdit(roleType, value)
        if not GF._reconcilingRoles029696 and roleType ~= ROLE_ANY then
            GF.lastRoleEdited029696 = roleType
        end
        return baseSetDesiredRoleCountAtEdit(self, roleType, value)
    end
end

function GF:ReconcileCurrentGroupRoles029696(panel)
    local data = panel and panel.userTypeData
    if not data then return false end
    if type(data.DoesGroupEnforceRoles) ~= "function" or data:DoesGroupEnforceRoles() ~= true then
        return false
    end
    if type(data.GetNumRoles) ~= "function" then return false end

    local totalSlots = asCount(data:GetNumRoles())
    if totalSlots <= 0 then return false end

    -- Refresh both the editable cache used by the spinners and ESO's live
    -- attained counts used by the server-side listing validation.
    local attained, desired = {}, {}
    for _, roleType in ipairs(ALL_ROLES) do
        if type(data.UpdateAttainedRoleCountAtEdit) == "function" then
            pcall(data.UpdateAttainedRoleCountAtEdit, data, roleType)
        end
        if type(data.UpdateDesiredRoleCountAtEdit) == "function" then
            pcall(data.UpdateDesiredRoleCountAtEdit, data, roleType)
        end

        local a = 0
        if type(data.GetAttainedRoleCount) == "function" then
            local ok, value = pcall(data.GetAttainedRoleCount, data, roleType)
            if ok then a = asCount(value) end
        end
        attained[roleType] = a

        local dCount = 0
        if type(data.GetDesiredRoleCountAtEdit) == "function" then
            local ok, value = pcall(data.GetDesiredRoleCountAtEdit, data, roleType)
            if ok then dCount = asCount(value) end
        elseif type(data.GetDesiredRoleCount) == "function" then
            local ok, value = pcall(data.GetDesiredRoleCount, data, roleType)
            if ok then dCount = asCount(value) end
        end
        desired[roleType] = dCount
    end

    local original = {
        [ROLE_TANK] = desired[ROLE_TANK],
        [ROLE_HEAL] = desired[ROLE_HEAL],
        [ROLE_DPS] = desired[ROLE_DPS],
    }

    -- Existing group members must fit inside the enforced requested role counts.
    for _, roleType in ipairs(SPECIFIC_ROLES) do
        if desired[roleType] < attained[roleType] then
            desired[roleType] = attained[roleType]
        end
    end

    -- Keep enough Any slots for current members who do not have a specific LFG
    -- role. The remaining capacity can be divided among Tank/Healer/Damage.
    local specificCapacity = math.max(0, totalSlots - attained[ROLE_ANY])
    local specificTotal = desired[ROLE_TANK] + desired[ROLE_HEAL] + desired[ROLE_DPS]
    local excess = math.max(0, specificTotal - specificCapacity)
    local protectedRole = self.lastRoleEdited029696

    -- Remove excess only from slots that are not already occupied. Prefer to
    -- preserve the role the player most recently changed (for example Healer).
    local function reduceOnePass(allowProtected)
        local bestRole, bestSlack = nil, 0
        for _, roleType in ipairs(SPECIFIC_ROLES) do
            if allowProtected or roleType ~= protectedRole then
                local slack = desired[roleType] - attained[roleType]
                if slack > bestSlack then
                    bestRole, bestSlack = roleType, slack
                end
            end
        end
        if not bestRole or bestSlack <= 0 then return false end
        local amount = math.min(excess, bestSlack)
        desired[bestRole] = desired[bestRole] - amount
        excess = excess - amount
        return true
    end

    while excess > 0 and reduceOnePass(false) do end
    while excess > 0 and reduceOnePass(true) do end

    -- A valid group can never have attained roles that exceed its target size,
    -- but if ESO is mid-sync, do not disable role enforcement or submit a bad
    -- request. Let ESO's native role-change state settle instead.
    if excess > 0 then
        printMessage("Group Finder roles are still syncing. Try Confirm again in a moment.")
        return false, true
    end

    local changed = false
    for _, roleType in ipairs(SPECIFIC_ROLES) do
        if desired[roleType] ~= original[roleType] then changed = true break end
    end

    if changed and type(data.SetDesiredRoleCountAtEdit) == "function" then
        self._reconcilingRoles029696 = true
        for _, roleType in ipairs(SPECIFIC_ROLES) do
            pcall(data.SetDesiredRoleCountAtEdit, data, roleType, desired[roleType])
        end
        self._reconcilingRoles029696 = false

        if panel and type(panel.UpdateRoles) == "function" then
            pcall(panel.UpdateRoles, panel)
        end

        local anyCount = math.max(0, totalSlots - desired[ROLE_TANK] - desired[ROLE_HEAL] - desired[ROLE_DPS])
        printMessage(string.format(
            "Group Finder roles updated for the current group: Tank %d, Healer %d, Damage %d, Any %d.",
            desired[ROLE_TANK], desired[ROLE_HEAL], desired[ROLE_DPS], anyCount
        ))
    end

    return changed, false
end

-- Hook the shared submit path so both keyboard and gamepad create/edit flows get
-- the same one-shot reconciliation immediately before ESO's native request.
if ZO_GroupFinder_CreateEditGroupListing_Shared
    and type(ZO_GroupFinder_CreateEditGroupListing_Shared.DoCreateEdit) == "function"
    and not ZO_GroupFinder_CreateEditGroupListing_Shared._easRoleRequirementFix029696 then

    ZO_GroupFinder_CreateEditGroupListing_Shared._easRoleRequirementFix029696 = true
    local baseDoCreateEdit = ZO_GroupFinder_CreateEditGroupListing_Shared.DoCreateEdit
    function ZO_GroupFinder_CreateEditGroupListing_Shared:DoCreateEdit(...)
        local _, blockSubmit = GF:ReconcileCurrentGroupRoles029696(self)
        if blockSubmit then return end
        return baseDoCreateEdit(self, ...)
    end
end

EPC.groupFinderRoleRequirementFix029696 = true

-- END ABSORBED: GroupFinderRoleRequirementFix.lua
