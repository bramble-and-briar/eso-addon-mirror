local N=ESOHardcore
local registered={}
local function register()
 local lib=_G.LibRadialMenu
 if type(lib)~='table' or type(lib.RegisterAddon)~='function' or type(lib.RegisterEntry)~='function' then return false end
 local ok=pcall(function()
  if not registered.addon then lib:RegisterAddon('ESOHardcore','Tamriel Unbound');registered.addon=true end
  if not registered.inventory then
   lib:RegisterEntry('ESOHardcore','Toggle HC Inventory','hc_inventory','/esoui/art/icons/icon_dualwield.dds',function() N.inventory.toggle() end,'Open or close the Hardcore OneBag inventory.');registered.inventory=true
  end
  if not registered.menu then
   lib:RegisterEntry('ESOHardcore','Toggle Tamriel Unbound Menu','hc_menu','/esoui/art/icons/achievement_dungeon_001.dds',function() N.toggleHardcorePage(1) end,'Open or close the Tamriel Unbound dashboard.');registered.menu=true
  end
 end)
 return ok and registered.inventory and registered.menu
end
EVENT_MANAGER:RegisterForEvent('ESOHardcoreRadialInit',EVENT_PLAYER_ACTIVATED,function()
 if register() then EVENT_MANAGER:UnregisterForEvent('ESOHardcoreRadialInit',EVENT_PLAYER_ACTIVATED);return end
 local attempts=0
 EVENT_MANAGER:RegisterForUpdate('ESOHardcoreRadialRetry',2500,function()
  attempts=attempts+1
  if register() or attempts>=10 then EVENT_MANAGER:UnregisterForUpdate('ESOHardcoreRadialRetry') end
 end)
end)
