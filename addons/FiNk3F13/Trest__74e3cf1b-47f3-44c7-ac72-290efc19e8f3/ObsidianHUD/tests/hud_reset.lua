DT_LOW=1
GuiRoot={GetWidth=function() return 1920 end,GetHeight=function() return 1080 end}
ObsidianHUD={name="ObsidianHUD",defaults={x=0,y=-215,width=480,scale=1,opacity=0.94,skillHudScale=1},
    vars={x=500,y=-50,width=800,scale=1.6,opacity=0.4,skillHudScale=1.5,
        timerSize=37,skillHudView="fixed_dual",health={1,0,0},hudPositions={controller={skills={x=0.9,y=0.3}}}}}
local O=ObsidianHUD
local nativeStops,resets,refreshes,unregisters=0,0,0,0
O.root={}
function O.root:StopMovingOrResizing() end
function O.root:GetLeft() return 900 end
function O.root:GetTop() return 500 end
function O.root:GetWidth() return 800 end
function O.root:GetHeight() return 116 end
function O.root:SetMovable() end
function O.root:SetMouseEnabled() end
function O.root:SetDrawTier() end
function O.root:SetDrawLevel() end
O.moveOverlay={SetHidden=function() end}
EVENT_MANAGER={UnregisterForUpdate=function() unregisters=unregisters+1 end}
function O.Refresh() refreshes=refreshes+1 end
function O.StopNativeMove() nativeStops=nativeStops+1 end
function O.ResetNativePositions()
    resets=resets+1; O.vars.hudPositions={}; O.skillScalePositions=nil
    assert(not O.moving and O.vars.skillHudScale==1)
end
dofile("Move.lua")
O.moving=true
O.ResetResourceLayout()
assert(not O.moving and unregisters==1)
for _,key in ipairs({"x","y","width","scale","opacity"}) do assert(O.vars[key]==O.defaults[key]) end
assert(O.vars.skillHudScale==1.5 and O.vars.hudPositions.controller.skills,"resource-only reset is scoped")
O.moving=true; O.vars.x=300; O.skillScalePositions={skills={x=0.99,y=0.99}}
local color=O.vars.health
O.ResetHudLayout()
assert(not O.moving and nativeStops==1 and resets==1 and unregisters==2)
assert(O.vars.x==0 and O.vars.y==-215 and O.vars.skillHudScale==1 and O.skillScalePositions==nil)
assert(next(O.vars.hudPositions)==nil)
assert(O.vars.timerSize==37 and O.vars.skillHudView=="fixed_dual" and O.vars.health==color)
local captured
LibHarvensAddonSettings={ST_BUTTON=1,ST_CHECKBOX=2,ST_SLIDER=3,ST_DROPDOWN=4,ST_COLOR=5,ST_LABEL=6,ST_SECTION=7}
function LibHarvensAddonSettings:AddAddon() return {AddSettings=function(_,entries) captured=entries end} end
dofile("Settings.lua"); O.CreateSettings()
local full,resource,native,skills
for _,entry in ipairs(captured) do
    if entry.type==1 then assert(type(entry.buttonText)=="string" and #entry.buttonText>0,"every PC button needs visible text") end
    if entry.buttonText=="Gesamtes HUD zuruecksetzen" then full=entry end
    if entry.buttonText=="Ressourcen-HUD zuruecksetzen" then resource=entry end
    if entry.buttonText=="Positionen zuruecksetzen" then native=entry end
    if entry.buttonText=="Skill-Positionen zuruecksetzen" then skills=entry end
end
assert(full and not resource and not native and not skills,"only the complete HUD reset remains in settings")
full.clickHandler(); assert(resets==2)
print("PASS: reset buttons have PC text; active resource moves stop before defaults; full reset includes skill scale and preserves colors/timers/view")
