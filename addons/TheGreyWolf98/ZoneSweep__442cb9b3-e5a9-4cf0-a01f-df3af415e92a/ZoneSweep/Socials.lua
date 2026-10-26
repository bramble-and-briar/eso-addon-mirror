-- Local presentation module; no polling, saved data or external dependencies.
local P={title="ZoneSweep",folder="ZoneSweep",parent="zonesweep",version="0.5.2"}
TGWZoneSweepSocials=P
function P.Font(size) return "$(GAMEPAD_MEDIUM_FONT)|"..size.."|soft-shadow-thin" end
function P.Show()
 if not P.scene then
  local W,H=1080,660
  local root=WINDOW_MANAGER:CreateTopLevelWindow(P.folder.."SocialsWindow")
  root:SetDimensions(W,H);root:SetAnchor(CENTER,GuiRoot,CENTER,0,-15);root:SetHidden(true)
  local bg=WINDOW_MANAGER:CreateControl(nil,root,CT_BACKDROP);bg:SetAnchorFill(root)
  bg:SetCenterColor(.025,.035,.05,1);bg:SetEdgeColor(.55,.36,.13,1);bg:SetEdgeTexture(nil,1,1,2)
  local function text(value,x,y,width,height,size)
   local c=WINDOW_MANAGER:CreateControl(nil,root,CT_LABEL);c:SetAnchor(TOPLEFT,root,TOPLEFT,x,y)
   c:SetDimensions(width,height);c:SetFont(P.Font(size));c:SetColor(.94,.96,1,1);c:SetText(value);return c
  end
  text(P.title:upper().." / SOCIALS & SUPPORT",36,24,1008,50,34)
  text("@TheGreyWolf98",36,80,1008,36,26)
  text("Enjoying the add-on? Buy me a beer on Ko-fi.",36,134,1008,40,28)
  local qr=WINDOW_MANAGER:CreateControl(nil,root,CT_TEXTURE);qr:SetAnchor(TOPLEFT,root,TOPLEFT,36,190)
  qr:SetDimensions(320,320);qr:SetTexture(P.folder.."/Textures/KoFiQR.dds")
  text("Scan to open Ko-fi",36,520,350,36,24)
  text("ko-fi.com/thegreywolf98",396,204,648,40,28)
  text("Instagram",396,286,648,36,24);text("@thegreywolf_98",396,322,648,40,28)
  text("Discord / updates & bug reports",396,402,648,36,24);text("discord.gg/Fp9RSaeU8h",396,438,648,40,28)
  text("Always free. Support is optional.",36,590,1008,36,24)
  local function resize()root:SetScale(math.min(GuiRoot:GetWidth()*.94/W,GuiRoot:GetHeight()*.88/H))end
  P.scene=ZO_Scene:New(P.parent.."Socials",SCENE_MANAGER)
  P.scene:AddFragment(ZO_SimpleSceneFragment:New(root))
  P.scene:AddFragmentGroup(IsInGamepadPreferredMode() and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
  local keys={alignment=KEYBIND_STRIP_ALIGN_LEFT,{name="Back to "..P.title,keybind="UI_SHORTCUT_NEGATIVE",callback=function()SCENE_MANAGER:Show(P.parent)end}}
  local active=false
  P.scene:RegisterCallback("StateChange",function(_,state)
   if state==SCENE_SHOWING then resize();if not active then KEYBIND_STRIP:AddKeybindButtonGroup(keys);active=true end
   elseif state==SCENE_HIDING or state==SCENE_HIDDEN then if active then KEYBIND_STRIP:RemoveKeybindButtonGroup(keys);active=false end end
  end)
  root:RegisterForEvent(EVENT_SCREEN_RESIZED,resize);resize()
 end
 SCENE_MANAGER:Show(P.parent.."Socials")
end
function P.Keybind()return {name="Socials / Support",keybind="UI_SHORTCUT_LEFT_STICK",callback=P.Show}end
