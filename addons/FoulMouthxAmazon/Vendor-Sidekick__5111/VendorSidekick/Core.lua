local V=VendorSidekick
local EM=EVENT_MANAGER
function V.Say(message)d("|cC5BF94Vendor Sidekick:|r "..tostring(message))end
local function Loaded(_,name)
 if name~=V.name then return end
 EM:UnregisterForEvent(V.name,EVENT_ADD_ON_LOADED)
 V.db=V.Model.Init(ZO_SavedVars:NewAccountWide("VendorSidekickSaved",1,GetWorldName(),{history={},characters={},keep={},settings={autoSell=true,receipts=true,protectPurple=false},nextId=0}))
 V.characterId=tostring(GetCurrentCharacterId());V.characterName=V.Model.Clean(GetUnitName("player"));V.db.characters[V.characterId]=V.db.characters[V.characterId] or {};V.db.characters[V.characterId].name=V.characterName
 V.InitTracking();V.InitUI()
 local function Slash(text)
  text=(text or ""):lower():match("^%s*(.-)%s*$")
  if text=="off" or text=="on" then V.db.settings.autoSell=text=="on";if text=="off" then V.manualBatch=false end;V.Say("Ordinary-junk auto-sale "..text..". Stolen goods remain manual only.");V.Render()
  elseif text=="sell" then local ok,msg=V.StartBatch();if not ok then V.Say(msg)end;V.Render()
  elseif text=="pause" then V.Pause();V.Say(V.notice)
  elseif text=="help" then V.page="help";if not (V.journal and V.journal:IsActive()) and V.window:IsHidden()then V.Open()end;V.Render()
  elseif text=="debug" then V.Say(string.format("v%s | store=%s fence=%s paused=%s | pending sales=%d launders=%d | journal=%s",V.version,tostring(V.open==true),tostring(V.fence==true),tostring(V.paused==true),#V.requestsSale,#V.requestsLaunder,tostring(V.journal~=nil)))
  else V.Open(text=="window")end
 end
 SLASH_COMMANDS["/vendor"]=Slash;SLASH_COMMANDS["/vsidekick"]=Slash
 LibSidekickUI.RegisterAuthorPanel(V.name,{title="Vendor Sidekick",author="FoulMouthxAmazon",version=V.version,description="/vendor opens the ledger. Ordinary junk auto-sells; stolen goods are tracked only. Use Settings to disable automation.",donation="https://buymeacoffee.com/foulmouthxamazon",goldRecipient="@FoulMouthxAmazon",onOpen=function()V.Open()end,onMessage=V.Say})
end
EM:RegisterForEvent(V.name,EVENT_ADD_ON_LOADED,Loaded)
