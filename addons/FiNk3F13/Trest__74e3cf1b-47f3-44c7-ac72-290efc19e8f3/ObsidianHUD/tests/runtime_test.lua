COMBAT_MECHANIC_FLAGS_HEALTH,COMBAT_MECHANIC_FLAGS_MAGICKA,COMBAT_MECHANIC_FLAGS_STAMINA=1,2,3
HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
CT_TEXTURE,CT_LABEL,CT_CONTROL,CT_STATUSBAR=1,2,3,4
TOPLEFT,TOPRIGHT,BOTTOMLEFT,BOTTOMRIGHT,TOP,BOTTOM,LEFT,RIGHT,CENTER=1,2,3,4,5,6,7,8,9
DL_CONTROLS,DL_OVERLAY,DT_LOW,DL_BACKGROUND,DL_TEXT=1,2,1,0,3
DT_HIGH,CT_BACKDROP,MOUSE_BUTTON_INDEX_LEFT=3,5,1
EVENT_ADD_ON_LOADED,EVENT_PLAYER_ACTIVATED,EVENT_PLAYER_DEACTIVATED=1,2,3
EVENT_POWER_UPDATE,EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,REGISTER_FILTER_UNIT_TAG=4,5,1
EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED=6
ATTRIBUTE_VISUAL_POWER_SHIELDING,STAT_MITIGATION,ATTRIBUTE_HEALTH=1,1,1
unpack=unpack or table.unpack
local function copy(v)
    if type(v)~="table" then return v end
    local n={}; for k,x in pairs(v) do n[k]=copy(x) end; return n
end
local function control()
    return setmetatable({alpha=1,children={},handlers={}},{__index=function(_,key)
        if key=="GetNamedChild" then return function(self,name) return self.children[name] end end
        if key=="GetAlpha" then return function(self) return self.alpha end end
        if key=="SetAlpha" then return function(self,value) self.alpha=value end end
        if key=="SetHandler" then return function(self,event,fn) self.handlers=self.handlers or {}; self.handlers[event]=fn end end
        if key=="GetWidth" then return function(self) return (rawget(self,"width") or self.SetDimensionsArgs[1])*(rawget(self,"SetScaleArgs") and self.SetScaleArgs[1] or 1) end end
        if key=="GetHeight" then return function(self) return (rawget(self,"height") or self.SetDimensionsArgs[2])*(rawget(self,"SetScaleArgs") and self.SetScaleArgs[1] or 1) end end
        if key=="GetLeft" then return function(self) return rawget(self,"left") or GuiRoot:GetWidth()/2+self.SetAnchorArgs[4]-self:GetWidth()/2 end end
        if key=="GetTop" then return function(self) return rawget(self,"top") or GuiRoot:GetHeight()+self.SetAnchorArgs[5]-self:GetHeight() end end
        return function(self,...) self[key.."Args"]={...} end
    end})
end
GuiRoot=control()
GuiRoot.width,GuiRoot.height=1920,1080
local moveTime,stickX,stickY=0,0,0
local uiMode,cameraMode=false,false
function GetFrameTimeSeconds() return moveTime end
function GetGamepadRightStickX() return stickX end
function GetGamepadRightStickY() return stickY end
function IsGameCameraUIModeActive() return cameraMode end
function SetGameCameraUIMode(value) cameraMode=value end
SCENE_MANAGER={IsInUIMode=function() return uiMode end,SetInUIMode=function(_,value) uiMode=value end}
local ownLoaded,fallbackLoaded=true,true
local assetWidth,assetHeight=64,64
ObsidianHUDAssetsSolid={IsTextureLoaded=function() return ownLoaded end,
    GetTextureFileDimensions=function() return assetWidth,assetHeight end}
ObsidianHUDAssetsFallback={IsTextureLoaded=function() return fallbackLoaded end,
    GetTextureFileDimensions=function() return 64,64 end}
local fantasyLoaded=true
local function artAsset(width,height)
    return {IsTextureLoaded=function() return fantasyLoaded end,
        GetTextureFileDimensions=function() return width,height end}
end
ObsidianHUDAssetsFantasyFrame=artAsset(512,64)
ObsidianHUDAssetsFantasyFill=artAsset(512,64)
ObsidianHUDAssetsFantasyDiamond=artAsset(128,128)
ObsidianHUDAssetsFantasyRound=artAsset(128,128)
ObsidianHUDAssetsFantasySlot=artAsset(64,64)
ObsidianHUDAssetsCurveFrame=artAsset(512,64)
ObsidianHUDAssetsCurveFill=artAsset(512,64)
local classesLoaded=true
ObsidianHUDAssetsClasses={IsTextureLoaded=function() return classesLoaded end,
    GetTextureFileDimensions=function() return 1024,512 end}
WINDOW_MANAGER={CreateControl=function(_,name,parent) local c=control(); c.parent=parent; return c end,
    CreateTopLevelWindow=function() return control() end}
local events,updates={},{},{}
EVENT_MANAGER={RegisterForEvent=function(_,name,event,fn) events[event]=fn end,
    UnregisterForEvent=function(_,name,event) events[event]=nil end,
    AddFilterForEvent=function() end,
    RegisterForUpdate=function(_,name,interval,fn) updates[name]=fn end,
    UnregisterForUpdate=function(_,name) updates[name]=nil end}
local hud=true
HUD_SCENE={IsShowing=function() return hud end,AddFragment=function() end}
HUD_UI_SCENE={IsShowing=function() return false end,AddFragment=function() end}
ZO_SimpleSceneFragment={New=function() return {} end}
ZO_SavedVars={NewAccountWide=function(_,name,version,namespace,defaults) return copy(defaults) end}
SLASH_COMMANDS={}
function zo_strtrim(s) return s:match("^%s*(.-)%s*$") end
local messages={}
function d(message) messages[#messages+1]=message end
local powers={[1]={500,1000,1000},[2]={200,400,400},[3]={0,0,0}}
function GetUnitPower(unit,power) return unpack(powers[power]) end
function GetUnitAttributeVisualizerEffectInfo() return 250 end
local active=0
function GetActiveHotbarCategory() return active end
function GetSlotTexture(slot,bar) return "icon-"..slot.."-"..bar end
function GetSlotBoundId(slot,bar) return slot+bar*100 end
function GetSlotCooldownInfo() return 3000,5000,false end
function GetActionSlotEffectTimeRemaining() return 8000 end
local nativeButtons,backButtons={},{}
for slot=3,8 do
    local icon,parent=control(),control()
    parent.children.Backdrop=control(); parent.children.Decoration=control()
    nativeButtons[slot]={slot=parent,icon=icon}
    backButtons[slot]={slot=control()}
end
function ZO_ActionBar_GetButton(slot,bar)
    if bar==nil or bar==active then return nativeButtons[slot] end
    return backButtons[slot]
end
local function nativeBar(unit,power)
    return {unitTag=unit,powerType=power,
        SetExternalVisibilityRequirement=function(self,fn) self.externalVisibilityRequirement=fn end,
        UpdateContextualFading=function(self) self.visible=not self.externalVisibilityRequirement or self.externalVisibilityRequirement() end,
        UpdateStatusBar=function(self) self:UpdateContextualFading() end}
end
local originalRequirement=function() return true end
local hp,mp,sp=nativeBar("player",1),nativeBar("player",2),nativeBar("player",3)
mp.externalVisibilityRequirement=originalRequirement
local siege,mount,werewolf=nativeBar("controlledsiege",1),nativeBar("player",4),nativeBar("player",5)
PLAYER_ATTRIBUTE_BARS={bars={hp,mp,sp,siege,mount,werewolf}}
local rows
LibHarvensAddonSettings={ST_CHECKBOX=1,ST_SLIDER=2,ST_LABEL=3,ST_SECTION=4,ST_COLOR=5,ST_BUTTON=6,
    AddAddon=function() return {AddSettings=function(_,s) rows=s end} end}
for _,file in ipairs({"Core.lua","ClassIcons.lua","UI.lua","Move.lua","NativeMove.lua","Native.lua","Settings.lua","ObsidianHUD.lua"}) do dofile(file) end
local O=ObsidianHUD
events[1](nil,"OtherAddon"); assert(not O.vars)
events[1](nil,"ObsidianHUD")
events[2]()
assert(O.Ratio(500,1000)==0.5 and O.Ratio(3,0)==0)
assert(O.Ratio(3000,1000)==1 and O.Ratio(-2,100)==0)
assert(O.ValueText(0,0)=="--")
assert(O.bars.health.fill.SetValueArgs[1]==0.5)
assert(O.bars.stamina.value.SetTextArgs[1]=="--")
assert(O.shield.SetValueArgs[1]==0.25)
assert(not hp.visible and not mp.visible and not sp.visible)
assert(siege.externalVisibilityRequirement==nil and mount.externalVisibilityRequirement==nil and werewolf.externalVisibilityRequirement==nil)
assert(nativeButtons[3].slot.children.Backdrop.alpha==0)
assert(backButtons[3].slot.alpha==0)
assert(O.OtherBar(0)==1 and O.OtherBar(1)==0 and O.OtherBar(7)==nil)
local byLabel={}; for _,row in ipairs(rows) do if type(row.label)=="string" then byLabel[row.label]=row end end
byLabel["Obsidian HUD aktiv"].setFunction(false)
assert(hp.externalVisibilityRequirement==nil and hp.visible)
assert(mp.externalVisibilityRequirement==originalRequirement and mp.visible)
assert(nativeButtons[3].slot.children.Backdrop.alpha==1 and backButtons[3].slot.alpha==1)
assert(O.root.SetHiddenArgs[1])
byLabel["Obsidian HUD aktiv"].setFunction(true)
byLabel["Originale Ressourcenbalken ausblenden"].setFunction(false)
assert(hp.visible)
byLabel["Originale Ressourcenbalken ausblenden"].setFunction(true)
assert(not hp.visible)
byLabel["Andere Waffenleiste als zweite Reihe"].setFunction(false)
assert(backButtons[3].slot.alpha==1)
byLabel["Andere Waffenleiste als zweite Reihe"].setFunction(true)
active=1; O.Tick(); assert(backButtons[3].slot.alpha==0)
active=7; O.Tick(); assert(nativeButtons[3].slot.children.Backdrop.alpha==1 and backButtons[3].slot.alpha==1)
active=0
-- Engine category and action bar category can disagree during a weapon swap.
-- A back-bar lookup may then return the same physical slot as the active one.
local normalButtonLookup=ZO_ActionBar_GetButton
local staleCategory=false
function ZO_ActionBar_GetButton(slot,bar)
    if staleCategory and bar~=nil then return nativeButtons[slot] end
    return normalButtonLookup(slot,bar)
end
for swap=1,30 do
    active=swap%2
    staleCategory=true; O.Tick()
    for slot=3,8 do
        assert(nativeButtons[slot].slot.alpha==1,"a stale category must never hide the active slot")
        assert(backButtons[slot].slot.alpha==1,"previously hidden back slots are released before resolving new targets")
    end
    staleCategory=false; O.Tick()
    for slot=3,8 do
        assert(nativeButtons[slot].slot.alpha==1 and backButtons[slot].slot.alpha==0)
    end
end
ZO_ActionBar_GetButton=normalButtonLookup
active=0
-- Weapon swaps update the preview synchronously without firing the 250ms timer.
local originalSlotTexture=GetSlotTexture
local textureCalls,lastPreviewBar=0,nil
function GetSlotTexture(slot,bar)
    textureCalls=textureCalls+1; lastPreviewBar=bar
    return originalSlotTexture(slot,bar)
end
for swap=1,30 do
    active=swap%2
    local before=textureCalls
    events[EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED](6,true)
    assert(textureCalls==before+6 and lastPreviewBar==O.OtherBar(active),"weapon swap must update every preview immediately")
    assert(updates[O.name.."SwapSync"],"native event order is reconciled on the next frame")
end
local before=textureCalls
updates[O.name.."SwapSync"]()
assert(textureCalls==before+6 and not updates[O.name.."SwapSync"],"reconciliation runs once and unregisters itself")
events[6](6,true); events[3]()
assert(not updates[O.name.."SwapSync"],"loading cancels pending swap reconciliation")
events[2]()
GetSlotTexture=originalSlotTexture
active=0
hud=false; O.Tick(); assert(O.root.SetHiddenArgs[1])
hud=true; O.Tick(); assert(not O.root.SetHiddenArgs[1])
events[3](); assert(O.root.SetHiddenArgs[1] and backButtons[3].slot.alpha==1)
events[2](); assert(not O.root.SetHiddenArgs[1])
powers[1]={1200,1000,2000}; events[4](nil,"player",0,1,1200,1000,2000)
assert(O.bars.health.fill.SetValueArgs[1]==0.6,"effective max reflects changed food/gear")
byLabel["Lebensfarbe"].setFunction(0.1,0.2,0.3)
assert(O.vars.health[3]==0.3 and O.vars.magicka[3]==0.94,"individual colours")
byLabel["Vertikal verschieben"].setFunction(-400)
byLabel["Position und Groesse zuruecksetzen"].clickHandler(); assert(O.vars.y==-215)
SLASH_COMMANDS["/obsidian"]("off"); assert(hp.visible and O.root.SetHiddenArgs[1])
SLASH_COMMANDS["/obsidian"]("on"); assert(not hp.visible and not O.root.SetHiddenArgs[1])
-- Do not erase a visibility owner installed after ours when releasing.
local laterOwner=function() return false end
hp.externalVisibilityRequirement=laterOwner
O.ReleaseResources(); assert(hp.externalVisibilityRequirement==laterOwner)
-- A missing DDS must never leave the user with only labels and no resource bars.
hp.externalVisibilityRequirement=nil
ownLoaded=false; fallbackLoaded=true; O.Tick()
assert(O.materialReady and not O.root.SetHiddenArgs[1])
assert(O.panel.background.SetTextureArgs[1]=="esoui/art/miscellaneous/progressbar_genericfill.dds")
assert(O.bars.health.fill.SetTextureArgs[1]=="ObsidianHUD/art/fantasy_fill.dds","resource silhouette is independent of solid fallback")
assert(O.bars.health.fill.SetDrawLayerArgs[1]==DL_CONTROLS)
assert(O.bars.health.name.SetDrawLayerArgs[1]==DL_TEXT)
fallbackLoaded=false; O.Tick()
assert(not O.materialReady and O.root.SetHiddenArgs[1] and hp.visible,
    "unloaded materials restore native resource bars rather than hiding all bars")
ownLoaded=true; O.Tick()
assert(O.materialReady and not hp.visible)
assert(O.panel.background.SetTextureArgs[1]=="ObsidianHUD/art/obsidian_solid.dds")
assetWidth,assetHeight=4,4; O.Tick()
assert(not O.materialReady and hp.visible,"unexpected fallback dimensions are rejected")
assetWidth,assetHeight=64,64
O.Tick()
assert(O.materialReady and not hp.visible)
local enabledBefore=O.vars.enabled
SLASH_COMMANDS["/obsidian"]("status")
assert(O.vars.enabled==enabledBefore,"status must not toggle HUD")
assert(messages[#messages]:find("ESO%-Ersatz") and messages[#messages]:find("64x64"),"status reports individual file dimensions")
fantasyLoaded=false; O.Tick()
assert(not O.materialReady and hp.visible,"unloaded metal graphics retain native resources")
fantasyLoaded=true; O.Tick()
assert(O.materialReady and not hp.visible)
assert(O.panel.SetHiddenArgs[1],"old rectangular panel is removed from fantasy design")
byLabel["Rundes Emblem statt Raute"].setFunction(true)
assert(O.badge.SetTextureArgs[1]=="ObsidianHUD/art/fantasy_round.dds")
byLabel["Rundes Emblem statt Raute"].setFunction(false)
assert(O.badge.SetTextureArgs[1]=="ObsidianHUD/art/fantasy_diamond.dds")
function GetNumClasses() return 2 end
function GetUnitClassId() return 117 end
function GetClassInfo(index)
    if index==1 then return 1,"lore","class-one-normal",nil,nil,true,"class-one","class-one-pad" end
    return 117,"lore","class-two-normal",nil,nil,true,"class-two","class-two-pad"
end
function IsInGamepadPreferredMode() return true end
assert(O.GetClassTexture()=="class-two-pad","class IDs are matched through index enumeration")
local nativeClassId=GetUnitClassId
local selectedClass=117
function GetUnitClassId() return selectedClass end
O.vars.roundBadge=true
for classId,tile in pairs({[1]=0,[2]=1,[3]=2,[6]=3,[4]=4,[5]=5,[117]=6}) do
    selectedClass=classId; O.UpdateClassIcon()
    assert(O.classIcon.SetTextureArgs[1]=="ObsidianHUD/art/class_emblems.dds")
    local uv=O.classIcon.SetTextureCoordsArgs
    assert(uv[1]==tile%4/4 and uv[2]==(tile%4+1)/4)
    assert(uv[3]==math.floor(tile/4)/2 and uv[4]==(math.floor(tile/4)+1)/2)
    assert(O.classIcon.SetDimensionsArgs[1]==77 and not O.classIcon.SetHiddenArgs[1])
end
selectedClass=117; classesLoaded=false; O.UpdateClassIcon()
assert(O.classIcon.SetTextureArgs[1]=="class-two-pad" and O.classIcon.SetTextureCoordsArgs[2]==1,"unloaded custom art uses native icon")
classesLoaded=true; O.UpdateClassIcon()
assert(O.classIcon.SetTextureArgs[1]=="ObsidianHUD/art/class_emblems.dds","late asset loading automatically selects custom art")
byLabel["Eigene Klassensymbole"].setFunction(false)
assert(O.classIcon.SetTextureArgs[1]=="class-two-pad")
byLabel["Eigene Klassensymbole"].setFunction(true)
selectedClass=9999; O.UpdateClassIcon()
assert(O.classIcon.SetHiddenArgs[1],"unknown class without a native icon retains the badge crest")
GetUnitClassId=nativeClassId
O.vars.roundBadge=false; O.Layout()
-- Sorting follows resource capacity, never the amount remaining during combat.
powers[2]={300,2000,2000}; powers[3]={100,3000,3000}
O.UpdateResources()
assert(O.displayedPrimary=="stamina")
assert(O.bars.health.frame.SetAnchorArgs[5]==27)
assert(O.bars.stamina.frame.SetAnchorArgs[5]==54 and O.bars.magicka.frame.SetAnchorArgs[5]==81)
assert(O.bars.stamina.name.SetTextArgs[1]=="AUSDAUER","labels remain tied to their resource")
powers[2][1]=2000; powers[3][1]=1
O.UpdateResources(); assert(O.displayedPrimary=="stamina","spending stamina cannot reorder bars")
powers[2]={10,3000,3000}
O.UpdateResources(); assert(O.displayedPrimary=="stamina","equal maxima preserve the last order")
powers[2]={0,3000,4200}
O.UpdateResources(); assert(O.displayedPrimary=="magicka","increased effective capacity can change build priority")
assert(O.bars.magicka.frame.SetAnchorArgs[5]==54 and O.bars.stamina.frame.SetAnchorArgs[5]==81)
assert(O.bars.health.frame.SetAnchorArgs[5]==27)
powers[2]={0,0,0}; powers[3]={0,0,0}
O.UpdateResources(); assert(O.displayedPrimary=="magicka","unavailable maxima cannot cause flickering order")
local characterId="character-a"
function GetCurrentCharacterId() return characterId end
O.resourceOrderCharacter=nil
active=0; powers[2]={200,4000,4000}; powers[3]={100,3000,3000}
O.UpdateResources()
assert(O.vars.frontResourceOrder[characterId]=="magicka")
for swap=1,30 do
    active=1; powers[2]={200,2000,2000}; powers[3]={100,5000,5000}
    events[6](6,true)
    assert(O.displayedPrimary=="magicka","larger back-bar stamina must not change front-bar order")
    assert(O.bars.stamina.value.SetTextArgs[1]==O.ValueText(100,5000),"back-bar values still update")
    active=0; powers[2]={200,4000,4000}; powers[3]={100,3000,3000}
    events[6](6,true)
    assert(O.displayedPrimary=="magicka")
end
active=1; O.primaryResource=nil; O.resourceOrderCharacter=nil
O.UpdateResources()
assert(O.displayedPrimary=="magicka","saved character order is restored when starting on back bar")
characterId="character-b"; active=0
powers[2]={100,2000,2000}; powers[3]={100,4000,4000}; O.UpdateResources()
assert(O.displayedPrimary=="stamina" and O.vars.frontResourceOrder[characterId]=="stamina")
active=1; powers[2]={100,5000,5000}; powers[3]={100,2000,2000}; O.UpdateResources()
assert(O.displayedPrimary=="stamina","larger back-bar magicka must not change stamina front-bar order")
characterId="character-a"; O.UpdateResources()
assert(O.displayedPrimary=="magicka","character orders do not leak between characters")
active=0; powers[2]={100,0,0}; powers[3]={100,2000,2000}; O.UpdateResources()
assert(O.displayedPrimary=="magicka","partially missing stats must not overwrite the saved order")
powers[2]={100,3000,3000}; powers[3]={100,2000,2000}; O.UpdateResources()
-- The circular cap must retain its geometry while only the straight body grows.
byLabel["Rundes Emblem statt Raute"].setFunction(true)
assert(O.badge.SetDimensionsArgs[1]==100 and O.badge.SetAnchorArgs[4]==-7)
assert(O.level.SetAnchorArgs[5]==3,"level text has a gap beneath the enlarged badge")
for _,width in ipairs({380,480,800}) do
    byLabel["Breite"].setFunction(width)
    local curved=O.bars[O.ResourceOrder()[3].key]
    assert(curved.curved and curved.fill.SetHiddenArgs[1])
    assert(curved.curve.capBorder.SetDimensionsArgs[1]==394*96/512,"changing width must not stretch the curved cap")
    for _,ratio in ipairs({0,0.05,0.5,1}) do
        O.UpdateCurvedFill(curved,ratio)
        local filled=curved.curve.capFill.SetWidthArgs[1]+curved.curve.bodyFill.SetWidthArgs[1]
        assert(math.abs(filled-curved.curveWidth*ratio)<0.001,"cap and body must show the full resource ratio")
        assert(curved.curve.capFill.SetHiddenArgs[1]==(ratio==0))
    end
end
byLabel["Breite"].setFunction(480)
byLabel["Rundes Emblem statt Raute"].setFunction(false)
-- Move UI remains available in settings, saves scaled screen positions and
-- restores the pre-existing cursor modes instead of closing a settings cursor.
hud=false
O.vars.scale=1.4; O.Layout()
byLabel["Move UI"].clickHandler()
assert(O.moving and uiMode and cameraMode and not O.root.SetHiddenArgs[1])
O.root.handlers.OnMouseDown(O.root,1)
O.root.left,O.root.top=300,400
moveTime=10; O.MoveUpdate()
assert(O.moving,"dragging cannot time out")
O.root.handlers.OnMouseUp(O.root,1)
assert(math.abs(O.vars.x-(300+480*1.4/2-960))<0.001)
assert(math.abs(O.vars.y-(400+116*1.4-1080))<0.001)
O.Layout() -- Simulate the anchors updated by ESO's native drag operation.
O.root.left,O.root.top=nil,nil
moveTime=12.9; O.MoveUpdate(); assert(O.moving)
moveTime=13.1; O.MoveUpdate()
assert(not O.moving and not uiMode and not cameraMode and O.root.SetHiddenArgs[1])
assert(not updates[O.name.."Move"] and not O.root.SetMouseEnabledArgs[1])
local savedX,savedY=O.vars.x,O.vars.y
O.Layout(); assert(O.vars.x==savedX and O.vars.y==savedY,"layout preserves saved position")
uiMode,cameraMode=true,true
O.StartMove(); stickX,stickY=1,1; O.MoveUpdate()
assert(O.vars.x>savedX and O.vars.y<savedY,"right stick moves the selected resource group")
O.vars.x,O.vars.y=100000,-100000; O.Layout(); O.MoveUpdate()
assert(O.root:GetLeft()>=0 and O.root:GetTop()>=0)
assert(O.root:GetLeft()+O.root:GetWidth()<=GuiRoot:GetWidth())
stickX,stickY=0,0
O.StopMove(); assert(uiMode and cameraMode,"existing settings cursor must stay enabled")
O.StartMove(); O.vars.enabled=false; O.Tick()
assert(not O.moving and not O.root.SetMouseEnabledArgs[1],"disabling releases move mode")
O.StartMove(); assert(not O.moving,"disabled HUD cannot start moving")
O.vars.enabled=true; hud=true; O.StartMove(); events[3]()
assert(not O.moving and O.root.SetHiddenArgs[1],"loading screens end move mode")
print("Obsidian HUD: resources, native restoration, weapon swap regression, controller callbacks and Move UI passed")
