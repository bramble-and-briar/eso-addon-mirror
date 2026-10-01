--GuildChatColors = GuildChatColors or {}
local GCC = GuildChatColors
GCC.Name = "GuildChatColors"
GCC.Version = "1.51.0"
GCC.Author = "OlegS (aka @TwilightOwl [EU])"
------------------
local SVG, SVA = {}, {}
local RealmName, AccountName, PlayerName, PlayerID = "", "", "", ""
local function GetSelectedColorsArray()
  local SG = SVG["Global"]
  local AR
  if SG.isUseGlobalColors then
    AR = SVG["Global"]
  elseif SG.isUseRealmColors then
    AR = SVG[RealmName]
  elseif SG.isUseAccountColors then
    AR = SVA[RealmName][AccountName]
  else
    AR = SVA[RealmName][AccountName].Characters[PlayerID]
  end
  return AR
end -- GetSelectedColorsArray end
------------------
local function GetGuildColorsBySlot(slot, officer)
  local R, G, B = 0, 0, 0
  if officer then
    R, G, B = GetChatCategoryColor( (CHAT_CATEGORY_OFFICER_1 - 1) + slot )
  else
    R, G, B = GetChatCategoryColor( (CHAT_CATEGORY_GUILD_1 - 1) + slot )
  end
  return R, G, B
end -- GetGuildColorsBySlot end
------------------
local function SetGuildColorsBySlot(slot, colors)
  SetChatCategoryColor( (CHAT_CATEGORY_GUILD_1 - 1) + slot, colors.Guild.R, colors.Guild.G, colors.Guild.B )
  SetChatCategoryColor( (CHAT_CATEGORY_OFFICER_1 - 1) + slot, colors.Officer.R, colors.Officer.G, colors.Officer.B )
end -- SetGuildColorsBySlot end
------------------
local function ImportGuildColorsFromChar(isNamed, isFullImport)
  local A = GetSelectedColorsArray()
  if isNamed then --== for named guilds ==--
    for i = 1, GetNumGuilds() do
      local GID = GetGuildId(i) or 0
      if GID > 0 then
        local GIS = tostring(GID)
        local GN = GetGuildName(GID)
        local gld = {R = 0, G = 0, B = 0,}
        local ofc = {R = 0, G = 0, B = 0,}
        gld.R, gld.G, gld.B = GetGuildColorsBySlot(i, false)
        ofc.R, ofc.G, ofc.B = GetGuildColorsBySlot(i, true)
        if not A.NamedGuildColors[GIS] then
          A.NamedGuildColors[GIS] = {}
          A.NamedGuildColors[GIS].Name = GN
          A.NamedGuildColors[GIS].Guild = gld
          A.NamedGuildColors[GIS].Officer = ofc
        else
          if isFullImport then
            A.NamedGuildColors[GIS].Name = GN
            A.NamedGuildColors[GIS].Guild = gld
            A.NamedGuildColors[GIS].Officer = ofc
          end
        end
      end
    end
  else --== for default guilds ==--
    for i = 1, MAX_GUILDS do
      local gld = {R = 0, G = 0, B = 0,}
      local ofc = {R = 0, G = 0, B = 0,}
      gld.R, gld.G, gld.B = GetGuildColorsBySlot(i, false)
      ofc.R, ofc.G, ofc.B = GetGuildColorsBySlot(i, true)
      if not A.GuildColors[i] then A.GuildColors[i] = {} end
      A.GuildColors[i].Guild = gld
      A.GuildColors[i].Officer = ofc
    end
  end -- is Named guild
end -- ImportGuildColorsFromChar end
------------------
local function SetGuildColorsToChar(isManual)
  local A = GetSelectedColorsArray()
  local SG = SVG["Global"]
  if SG.isAlwaysSetColors or isManual then
    for i = 1, MAX_GUILDS do
      local GID = GetGuildId(i) or 0
      if GID > 0 then
        local GIS = tostring(GID)
        if A.NamedGuildColors[GIS] then
          SetGuildColorsBySlot(i, A.NamedGuildColors[GIS])
        else
          SetGuildColorsBySlot(i, A.GuildColors[i])
        end
      else
        SetGuildColorsBySlot(i, A.GuildColors[i])
      end
    end
  end
end -- SetGuildColorsToChar end
------------------
local function GetAdditionalColorsByChannel(channel)
  local R, G, B = 0, 0, 0
  if channel == "GroupColor" then
    R, G, B = GetChatCategoryColor( CHAT_CATEGORY_PARTY )
  elseif channel == "SystemColor" then
    R, G, B = GetChatCategoryColor( CHAT_CATEGORY_SYSTEM )
  end
  return R, G, B
end -- GetAdditionalColorsByChannel end
------------------
local function SetAdditionalColorsByChannel(channel, colors)
  if channel == "GroupColor" then
    SetChatCategoryColor( CHAT_CATEGORY_PARTY, colors.R, colors.G, colors.B )
  elseif channel == "SystemColor" then
    SetChatCategoryColor( CHAT_CATEGORY_SYSTEM, colors.R, colors.G, colors.B )
  end
end -- SetGuildColorsBySlot end
------------------
local function ImportAdditionalColorsFromChar(channel, isFullImport)
  local A = GetSelectedColorsArray()
  local SG = SVG["Global"]
--
  if isFullImport or ( not A.AdditionalColors[channel] ) then
    local adc = {R = 0, G = 0, B = 0}
    adc.R, adc.G, adc.B = GetAdditionalColorsByChannel(channel)
    A.AdditionalColors[channel] = adc
  end
end -- ImportAdditionalColorsFromChar end
------------------
local function SetAdditionalColorsToChar(isManual)
  local A = GetSelectedColorsArray()
  local SG = SVG["Global"]
--
  if SG.isAlwaysSetColors or isManual then
    for cnl, clr in pairs(A.AdditionalColors) do
      if cnl == "GroupColor" then
        if SG.isSetGroupColors then
          SetAdditionalColorsByChannel(cnl, clr)
        end
      elseif cnl == "SystemColor" then
        if SG.isSetSystemColors then
          SetAdditionalColorsByChannel(cnl, clr)
        end
      end
    end
  end
end -- SetAdditionalColorsToChar end
------------------
local function ImportChatFontSizeFromChar(isFullImport)
  local A = GetSelectedColorsArray()
  if isFullImport or ( A.ChatFontSize < 8 ) then
    A.ChatFontSize = GetChatFontSize() -- CHAT_SYSTEM.GetFontSizeFromSetting()
  end
end -- ImportChatFontSizeFromChar end
------------------
local function SetChatFontSizeToChar(isManual)
  local A = GetSelectedColorsArray()
  local SG = SVG["Global"]
  if A.ChatFontSize < 8 then return end
  if SG.isAlwaysSetColors or isManual then
    if SG.isSetChatFontSize then
      CHAT_SYSTEM:SetFontSize( A.ChatFontSize ) -- KEYBOARD_CHAT_SYSTEM:SetFontSize( A.ChatFontSize )
      SetChatFontSize( A.ChatFontSize )
    end
  end
end -- SetChatFontSizeToChar end
------------------
local function CheckAdditionalArrays()
  local A = GetSelectedColorsArray()
  if not A.AdditionalColors["GroupColor"]  then ImportAdditionalColorsFromChar("GroupColor", false) end
  if not A.AdditionalColors["SystemColor"] then ImportAdditionalColorsFromChar("SystemColor", false) end
  if A.ChatFontSize < 8 then ImportChatFontSizeFromChar(false) end
end -- CheckAdditionalArrays end
------------------
local function CheckGuildArrays()
  local A = GetSelectedColorsArray()
  if #A.GuildColors < 1 then ImportGuildColorsFromChar(false, false) end
  ImportGuildColorsFromChar(true, false)
end -- CheckGuildArrays end
------------------
local function CheckGlobalSV()
  local var
  if SVG["Global"] == nil then SVG["Global"] = {} end
  var = SVG["Global"]
  if var.isAlwaysSetColors == nil then var.isAlwaysSetColors = false end
  if var.isUseGlobalColors == nil then var.isUseGlobalColors = true end
  if var.isUseRealmColors == nil then var.isUseRealmColors = true end
  if var.isUseAccountColors == nil then var.isUseAccountColors = true end
  if var.isSetGroupColors == nil then var.isSetGroupColors = false end
  if var.isSetSystemColors == nil then var.isSetSystemColors = false end
  if var.isSetChatFontSize == nil then var.isSetChatFontSize = false end
  if var.GuildColors == nil then var.GuildColors = {} end
  if var.NamedGuildColors == nil then var.NamedGuildColors = {} end
  if var.AdditionalColors == nil then var.AdditionalColors = {} end
  if var.ChatFontSize == nil then var.ChatFontSize = 0 end
--
  if SVG[RealmName] == nil then SVG[RealmName] = {} end
  var = SVG[RealmName]
  if var.GuildColors == nil then var.GuildColors = {} end
  if var.NamedGuildColors == nil then var.NamedGuildColors = {} end
  if var.AdditionalColors == nil then var.AdditionalColors = {} end
  if var.ChatFontSize == nil then var.ChatFontSize = 0 end
end -- CheckGlobalSV end
------------------
local function CheckAccountSV()
  local var
  if SVA[RealmName] == nil then SVA[RealmName] = {} end
  if SVA[RealmName][AccountName] == nil then SVA[RealmName][AccountName] = {} end
  var = SVA[RealmName][AccountName]
  if var.GuildColors == nil then var.GuildColors = {} end
  if var.NamedGuildColors == nil then var.NamedGuildColors = {} end
  if var.AdditionalColors == nil then var.AdditionalColors = {} end
  if var.ChatFontSize == nil then var.ChatFontSize = 0 end
--
  if var.Characters == nil then var.Characters = {} end
  if var.Characters[PlayerID] == nil then var.Characters[PlayerID] = {} end
  var = SVA[RealmName][AccountName].Characters[PlayerID]
  if var.Name == nil then var.Name = PlayerName end
  if var.Name ~= PlayerName then var.Name = PlayerName end
  if var.GuildColors == nil then var.GuildColors = {} end
  if var.NamedGuildColors == nil then var.NamedGuildColors = {} end
  if var.AdditionalColors == nil then var.AdditionalColors = {} end
  if var.ChatFontSize == nil then var.ChatFontSize = 0 end
end -- CheckAccountSV end
------------------
local function OnGuildDataLoaded(event)
-- EVENT_GUILD_DATA_LOADED (number eventCode)
  SetGuildColorsToChar(true)
end -- OnGuildDataLoaded end
------------------
local function OnPlrAct1Time(event, init)
  local EM = GetEventManager()
  EM:UnregisterForEvent(GCC.Name .. "1Time", EVENT_PLAYER_ACTIVATED)
  CheckGuildArrays()
  CheckAdditionalArrays()
  SetGuildColorsToChar(false)
  SetAdditionalColorsToChar(false)
  SetChatFontSizeToChar(false)
  EM:RegisterForEvent(GCC.Name, EVENT_GUILD_DATA_LOADED, OnGuildDataLoaded)
end -- OnPlrAct1Time end
------------------
local function Initialize()
  RealmName = GetWorldName()
  AccountName = GetUnitDisplayName("player")
  PlayerName = zo_strformat("<<1>>", GetRawUnitName("player"))
  PlayerID = GetCurrentCharacterId()
  SVG, SVA = GCCGlobal, GCCAccount
  CheckGlobalSV()
  CheckAccountSV()
end -- Initialize end
------------------
local function OnAddonLoaded(event, addonName)
  if addonName ~= GCC.Name then return end
  EVENT_MANAGER:UnregisterForEvent(GCC.Name, EVENT_ADD_ON_LOADED)
  if GCCGlobal == nil then GCCGlobal = {} end
  if GCCAccount == nil then GCCAccount = {} end
  Initialize()
  GCC:CreateOptionsPanel()
--
  SLASH_COMMANDS["/gcc"] = function(cmd)
    local i18n = GCC.i18n
    local function OptionToString(var)
      if type(var) == "boolean" then
        return var and GetString(SI_CHECK_BUTTON_ON) or GetString(SI_CHECK_BUTTON_OFF)
      end
      return ""
    end
    ---
    if cmd == "" then
    elseif cmd == "set" then
      SetGuildColorsToChar(true)
    elseif (cmd == "cmn") or (cmd == "common") then
      ImportGuildColorsFromChar(false, false)
    elseif (cmd == "gld") or (cmd == "guild") then
      ImportGuildColorsFromChar(true, true)
    elseif (cmd == "auto") or (cmd == "autoset") then
      SVG["Global"].isAlwaysSetColors = not SVG["Global"].isAlwaysSetColors
      d( zo_strformat("[GCC] <<1>> : <<2>>", i18n.OptAlwaysSetColors,
         OptionToString(SVG["Global"].isAlwaysSetColors)) )
    elseif (cmd == "grp") or (cmd == "group") then
      SVG["Global"].isSetGroupColors = not SVG["Global"].isSetGroupColors
      d( zo_strformat("[GCC] <<1>> : <<2>>", i18n.OptSetGroupColors,
         OptionToString(SVG["Global"].isSetGroupColors)) )
    elseif (cmd == "sys") or (cmd == "system") then
      SVG["Global"].isSetSystemColors = not SVG["Global"].isSetSystemColors
      d( zo_strformat("[GCC] <<1>> : <<2>>", i18n.OptSetSystemColors,
         OptionToString(SVG["Global"].isSetSystemColors)) )
    elseif (cmd == "fsz") or (cmd == "fontsize") then
      SVG["Global"].isSetChatFontSize = not SVG["Global"].isSetChatFontSize
      d( zo_strformat("[GCC] <<1>> : <<2>>", i18n.OptSetChatFontSize,
         OptionToString(SVG["Global"].isSetChatFontSize)) )
    end
  end
--
  EVENT_MANAGER:RegisterForEvent(GCC.Name .. "1Time", EVENT_PLAYER_ACTIVATED, OnPlrAct1Time)
end -- OnAddonLoaded end
------------------
local function GetFontSizeFromSV()
  local A = GetSelectedColorsArray()
  if A.ChatFontSize < 8 then CheckAdditionalArrays() end
  return A.ChatFontSize
end -- GetFontSizeFromSV end
------------------
local function SetFontSizeToSV(fontsize)
  local A = GetSelectedColorsArray()
  local SG = SVG["Global"]
  if fontsize < 8 then fontsize = 8 end
  if A.ChatFontSize then A.ChatFontSize = fontsize end
  if SG.isAlwaysSetColors then SetChatFontSizeToChar(false) end
end -- SetFontSizeToSV end
------------------
local function GetAddColorFromSV(channel)
  local A = GetSelectedColorsArray()
  if not A.AdditionalColors[channel] then CheckAdditionalArrays() end
  return A.AdditionalColors[channel]
end -- GetAddColorFromSV end
------------------
local function SetAddColorToSV(channel, color)
  local A = GetSelectedColorsArray()
  local SG = SVG["Global"]
  if A.AdditionalColors[channel] then
    A.AdditionalColors[channel] = color
  end
  if SG.isAlwaysSetColors then SetAdditionalColorsToChar(false) end
end -- SetAddColorToSV end
------------------
local function GetColorFromSV(slot, channel, gis)
-- slot, channel (1 guild, 2 officer), gis (or nil)
  local A = GetSelectedColorsArray()
  if not A.GuildColors[slot] then CheckGuildArrays() end
  local C = {R = 0, G = 0, B = 0}
  local isNamed = false
  if gis and (type(gis) == "string") then isNamed = true end
  if isNamed and A.NamedGuildColors[gis] then
    if channel == 1 then C = A.NamedGuildColors[gis].Guild
    else C = A.NamedGuildColors[gis].Officer
    end
  else
    if channel == 1 then C = A.GuildColors[slot].Guild
    else C = A.GuildColors[slot].Officer
    end
  end
  return C
end -- GetColorFromSV end
------------------
local function SetColorToSV(color, slot, channel, gis)
-- color array, slot, channel (1 guild, 2 officer), gis (or nil)
  local A = GetSelectedColorsArray()
  local SG = SVG["Global"]
  local isNamed = false
  if gis and (type(gis) == "string") then isNamed = true end
  if isNamed and A.NamedGuildColors[gis] then
    if channel == 1 then A.NamedGuildColors[gis].Guild = color
    else A.NamedGuildColors[gis].Officer = color
    end
  else
    if channel == 1 then A.GuildColors[slot].Guild = color
    else A.GuildColors[slot].Officer = color
    end
  end
  if SG.isAlwaysSetColors then SetGuildColorsToChar(false) end
end -- SetColorToSV end
------------------
function GCC.GetVarByName(var, val1, val2, val3)
  local CLR = {R = 0, G = 0, B = 0}
  local AddColors = { ["GroupColor"] = true, ["SystemColor"] = true }
  local SG = SVG["Global"]
  if var == "AlwaysSetColors" then
    return SG.isAlwaysSetColors
  elseif var == "UseGlobalColors" then
    return SG.isUseGlobalColors
  elseif var == "UseRealmColors" then
    return SG.isUseRealmColors
  elseif var == "UseAccountColors" then
    return SG.isUseAccountColors
  elseif var == "SetGroupColor" then
    return SG.isSetGroupColors
  elseif var == "SetSystemColor" then
    return SG.isSetSystemColors
  elseif var == "SetChatFontSize" then
    return SG.isSetChatFontSize
  elseif var == "ChatFontSize" then
    return GetFontSizeFromSV()
  elseif AddColors[var] then
    --- channel ---
    CLR = GetAddColorFromSV(var)
  elseif var == "DefaultSystem" then
    CLR = {R = 0.93333333730698, G = 0.93333333730698, B = 0}
  elseif var == "DefaultGroup" then
    CLR = {R = 0.99215686321259, G = 0.47843137383461, B = 0.10196078568697}
  elseif var == "DefaultGuild" then
    CLR = {R = 0.0588235296, G = 0.8823529482, B = 0.5647059083}
  elseif var == "DefaultOfficer" then
    CLR = {R = 0.5921568871, G = 1, B = 0.7450980544}
  elseif var == "ColorChannel" then
    --- slot, channel (1 guild, 2 officer), gis (or nil) ---
    CLR = GetColorFromSV(val1, val2, val3)
  end
  return CLR.R, CLR.G, CLR.B, 1
end -- GetVarByName end
------------------
function GCC.SetVarByName(var, val1, val2, val3, val4)
  local GLB = SVG["Global"]
  local AddColors = { ["GroupColor"] = true, ["SystemColor"] = true }
  if var == "AlwaysSetColors" then
    GLB.isAlwaysSetColors = val1
  elseif var == "UseGlobalColors" then
    GLB.isUseGlobalColors = val1
  elseif var == "UseRealmColors" then
    GLB.isUseRealmColors = val1
  elseif var == "UseAccountColors" then
    GLB.isUseAccountColors = val1
  elseif var == "SetGroupColor" then
    GLB.isSetGroupColors = val1
  elseif var == "SetSystemColor" then
    GLB.isSetSystemColors = val1
  elseif var == "SetChatFontSize" then
    GLB.isSetChatFontSize = val1
  elseif var == "ChatFontSize" then
    SetFontSizeToSV(val1)
  elseif AddColors[var] then
    --- channel, color ---
    SetAddColorToSV(var, val1)
  elseif var == "ColorChannel" then
    --- color, slot, channel (1 guild, 2 officer), gis (or nil) ---
    SetColorToSV(val1, val2, val3, val4)
  end
end -- SetVarByName end
--===================================================
EVENT_MANAGER:RegisterForEvent(GCC.Name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
