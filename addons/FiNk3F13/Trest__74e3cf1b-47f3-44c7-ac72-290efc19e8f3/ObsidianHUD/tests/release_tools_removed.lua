ObsidianHUD={vars={},stackPreviewUntil=999999}
local O=ObsidianHUD
dofile("UI.lua"); dofile("Native.lua"); dofile("SkillTimers.lua")
dofile("StackEffects.lua"); dofile("SkillText.lua")
assert(O.PrintMaterialStatus==nil and O.MaterialStatus==nil)
assert(O.PrintSkillTimers==nil and O.GetSkillTimerState==nil and O.PreviewSkillStacks==nil)
function O.GetSkillStackCount() return 7 end
local label={SetText=function(self,value) self.text=value end}
O.UpdateStackText(label,3,0)
assert(label.text=="7","only real stacks are displayed, even with stale preview state")
local settings
LibHarvensAddonSettings={ST_BUTTON=1,ST_CHECKBOX=2,ST_SLIDER=3,ST_DROPDOWN=4,ST_COLOR=5,ST_LABEL=6,ST_SECTION=7}
function LibHarvensAddonSettings:AddAddon() return {AddSettings=function(_,rows) settings=rows end} end
dofile("Settings.lua"); O.CreateSettings()
local group,reset=false,false
for _,entry in ipairs(settings) do
    assert(entry.label~="Stack-Anzeige testen")
    if entry.buttonText=="Skill-HUD gemeinsam verschieben" then group=true end
    if entry.buttonText=="Gesamtes HUD zuruecksetzen" then reset=true end
end
assert(group and reset,"menu features remain available without commands")
print("PASS: release has no diagnostic/test helpers; real stacks and menu movement/reset remain")
