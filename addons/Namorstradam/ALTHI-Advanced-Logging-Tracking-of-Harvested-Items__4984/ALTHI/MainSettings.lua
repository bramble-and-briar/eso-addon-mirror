local A=ALTHarvestItems
local function L(key) return A:T(key) end
A.priceProviders={
    {key="useAGS",short="AGS",name="Awesome Guild Store"},
    {key="useTTC",short="TTC",name="Tamriel Trade Centre"},
    {key="useATT",short="ATT",name="Arkadius' Trade Tools"},
    {key="useMM",short="MM",name="Master Merchant"},
}
function A:WindowActions()
    return {
        {name=L("OPEN_FILTER_LIST"),run=function() self:OpenSettings() end},
        {name=L("SHOW_MAIN_WINDOW"),run=function() self:ToggleWindow(true) end},
        {name=L("VIEW_AND_TRANSPARENCY"),run=function() self:OpenViewSettings() end},
        {name=L("CHOOSE_LANGUAGE"),run=function() self:OpenLanguagePicker(false) end},
    }
end
function A:SetAutomatic(value)
    self.db.options.autoStart=true; self.db.options.autoResume=value==true
    self:QueueRefresh()
    if self.mainSettings then self:RefreshMainSettings() end
end
function A:RefreshMainSettings()
    local window=self.mainSettings
    window.trader:SetText(L(self.db.options.guildTrader and "ACCOUNT_FOR_GUILD_TRADER" or "IGNORE_GUILD_TRADER"))
    window.auto:SetText(L("AUTO_RESUME_ON_FIND_SETTING")..": "..(self.db.options.autoResume and L("ON") or L("OFF")))
    window.menuHiding:SetText(L("HIDE_OVERVIEW_IN_ESO_MENUS")..": "..(self.db.options.hideInMenus~=false and L("ON") or L("OFF")))
    for _,provider in ipairs(self.priceProviders) do
        window.providers[provider.key]:SetText(provider.short.." – "..provider.name.."  ·  "..(self.db.options[provider.key] and L("ON") or L("OFF")))
    end
end
function A:HasIntegratedSettings()
    local lam=LibAddonMenu2
    local panel=self.lamPanel or _G.ALTHIOptions
    return lam and type(lam.OpenToPanel)=="function" and panel~=nil
end
function A:OpenMainSettings()
    local lam=LibAddonMenu2
    local panel=self.lamPanel or _G.ALTHIOptions
    if self:HasIntegratedSettings() then
        self:CloseAllDialogs()
        lam:OpenToPanel(panel)
        return
    end
    self:OpenStandaloneSettings()
end
function A:OpenStandaloneSettings()
    if not self.mainSettings then
        local window=WINDOW_MANAGER:CreateTopLevelWindow("ALTHIMainSettings")
        local screenHeight=GuiRoot:GetHeight() or 1000
        window:SetDimensions(920,math.max(430,math.min(850,screenHeight-40)))
        window:SetAnchor(CENTER,GuiRoot,CENTER,0,0); window:SetMouseEnabled(true)
        window:SetMovable(true); window:SetClampedToScreen(true); self:Backdrop(window)
        local title=self:Label(window,"ZoFontWinH2"); title:SetAnchor(TOPLEFT,window,TOPLEFT,22,14)
        title:SetText(self:GoldText("ALTHI"))
        local subtitle=self:Label(window,"ZoFontGame")
        subtitle:SetAnchor(TOPLEFT,window,TOPLEFT,22,48); subtitle:SetText("Advanced Logging & Tracking of Harvested Items")
        local authors=self:Label(window,"ZoFontGameSmall")
        authors:SetAnchor(TOPLEFT,window,TOPLEFT,22,78); authors:SetText(L("AUTHORS")..self.authors)
        local viewport=WINDOW_MANAGER:CreateControl(nil,window,CT_CONTROL)
        viewport:SetAnchor(TOPLEFT,window,TOPLEFT,22,112); viewport:SetAnchor(BOTTOMRIGHT,window,BOTTOMRIGHT,-44,-60)
        viewport:SetAutoRectClipChildren(true)
        local body=WINDOW_MANAGER:CreateControl(nil,viewport,CT_CONTROL); body:SetDimensions(850,1170)
        local function Text(text,y,height,font)
            local label=self:Label(body,font); label:SetAnchor(TOPLEFT,body,TOPLEFT,0,y)
            label:SetDimensions(840,height); label:SetMaxLineCount(4); label:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
            label:SetText(text); return label
        end
        Text(L("SEARCH_CATEGORIES_CHOOSE_MATERIALS_AND_SET_CUSTOM_PRICES_TOTALS_INCLUD"),0,64)
        Text(self:GoldText(L("WINDOWS_DISPLAY")),76,28,"ZoFontWinH3")
        for index,action in ipairs(self:WindowActions()) do
            local button=self:MenuButton(body,action.name,400,action.run)
            button:SetAnchor(TOPLEFT,body,TOPLEFT,((index-1)%2)*430,110+math.floor((index-1)/2)*40)
        end
        window.auto=self:Button(body,"",830,function() self:SetAutomatic(not self.db.options.autoResume) end)
        window.auto:SetAnchor(TOPLEFT,body,TOPLEFT,0,202)
        window.menuHiding=self:MenuButton(body,"",830,function() self:SetMenuHiding(self.db.options.hideInMenus==false) end)
        window.menuHiding:SetAnchor(TOPLEFT,body,TOPLEFT,0,242)
        Text(self:GoldText(L("PRICE_SOURCES")),302,30,"ZoFontWinH3")
        window.trader=self:MenuButton(body,"",830,function() self:SetGuildTrader(not self.db.options.guildTrader) end)
        window.trader:SetAnchor(TOPLEFT,body,TOPLEFT,0,340)
        Text(L("THIS_SETTING_CONTROLS_PRICES_THROUGHOUT_THE_ADDON_ACCOUNT_FOR_GUILD_TR"),378,88,"ZoFontGameSmall")
        Text(L("ALL_SOURCE_AND_CUSTOM_PRICES_ARE_GROSS_WHEN_ENABLED_GROSS_0_93_7_SALE_"),478,88,"ZoFontGameSmall")
        Text(L("CHOOSE_THE_PRICE_ADDONS_TO_USE_THE_FIRST_ENABLED_SOURCE_WITH_AN_AVAILA"),572,56)
        Text(L("ORDER_ALTHI_OVERRIDE_AGS_TTC_ATT_MM_NPC_VENDOR_PRICE"),640,56)
        window.providers={}
        for index,provider in ipairs(self.priceProviders) do
            local key=provider.key; local y=712+(index-1)*67
            local button=self:MenuButton(body,"",820,function()
                self.db.options[key]=not self.db.options[key]; self:RefreshPrices(); self:RefreshMainSettings()
            end)
            button:SetAnchor(TOPLEFT,body,TOPLEFT,0,y); window.providers[key]=button
        end
        Text(L("AGS_USES_YOUR_LAST_OWN_LISTING_PRICE_PER_UNIT_NOT_A_CONFIRMED_SALE_NPC"),998,88,"ZoFontGameSmall")
        Text(L("FISHING"),1090,28,"ZoFontWinH3")
        window.resetFishing=self:MenuButton(body,L("RESET_LIFETIME"),830,function() ZO_Dialogs_ShowDialog("ALTHI_FISHING_TOTAL_RESET") end)
        window.resetFishing:SetAnchor(TOPLEFT,body,TOPLEFT,0,1126)
        local maxOffset=math.max(0,1170-(window:GetHeight()-172))
        local slider=self:MakeSlider("ALTHIMainSettingsSlider",window,116,-64,function(value)
            window.offset=value; body:ClearAnchors(); body:SetAnchor(TOPLEFT,viewport,TOPLEFT,0,-value)
        end)
        slider:SetMinMax(0,math.max(1,maxOffset)); slider:SetValue(0); slider:SetHidden(maxOffset==0)
        window:SetHandler("OnMouseWheel",function(_,delta) slider:SetValue(math.max(0,math.min(maxOffset,(window.offset or 0)-delta*60))) end)
        window.althiRoot=true; self:CloseIcon(window)
        self.mainSettings=window
    end
    self:RefreshMainSettings(); self:ShowDialog(self.mainSettings)
end
function A:RegisterLAM()
    local lam=LibAddonMenu2
    if not lam or not lam.RegisterAddonPanel or not lam.RegisterOptionControls then return end
    self.lamPanel=lam:RegisterAddonPanel("ALTHIOptions",{type="panel",name="ALTHI",displayName=self.title,
        author=self.authors,version=self.version,registerForRefresh=true})
    local options={
        {type="description",text=L("SEARCH_CATEGORIES_CHOOSE_MATERIALS_AND_SET_CUSTOM_PRICES_TOTALS_INCLUD")},
        {type="header",name=L("WINDOWS_DISPLAY")},
    }
    for _,action in ipairs(self:WindowActions()) do options[#options+1]={type="button",name=action.name,func=action.run} end
    options[#options+1]={type="checkbox",name=L("AUTO_RESUME_ON_FIND_SETTING"),
        getFunc=function() return self.db.options.autoResume end,setFunc=function(value) self:SetAutomatic(value) end}
    options[#options+1]={type="checkbox",name=L("HIDE_OVERVIEW_IN_ESO_MENUS"),
        getFunc=function() return self.db.options.hideInMenus~=false end,setFunc=function(value) self:SetMenuHiding(value) end}
    options[#options+1]={type="checkbox",name=L("AUTO_BAIT"),
        getFunc=function() return self.db.options.autoBait end,
        setFunc=function(value) self.db.options.autoBait=value; self:QueueRefresh() end}
    options[#options+1]={type="header",name=L("PRICE_SOURCES")}
    options[#options+1]={type="dropdown",name=L("GUILD_TRADER"),
        choices={L("IGNORE_GUILD_TRADER"),L("ACCOUNT_FOR_GUILD_TRADER")},
        getFunc=function() return L(self.db.options.guildTrader and "ACCOUNT_FOR_GUILD_TRADER" or "IGNORE_GUILD_TRADER") end,
        setFunc=function(value) self:SetGuildTrader(value==L("ACCOUNT_FOR_GUILD_TRADER")) end}
    options[#options+1]={type="description",text=L("THIS_SETTING_CONTROLS_PRICES_THROUGHOUT_THE_ADDON_ACCOUNT_FOR_GUILD_TR")}
    options[#options+1]={type="description",text=L("ALL_SOURCE_AND_CUSTOM_PRICES_ARE_GROSS_WHEN_ENABLED_GROSS_0_93_7_SALE_")}
    options[#options+1]={type="description",text=L("CHOOSE_THE_PRICE_ADDONS_TO_USE_THE_FIRST_ENABLED_SOURCE_WITH_AN_AVAILA")}
    options[#options+1]={type="description",text=L("ORDER_ALTHI_OVERRIDE_AGS_TTC_ATT_MM_NPC_VENDOR_PRICE")}
    for _,provider in ipairs(self.priceProviders) do
        local key=provider.key
        options[#options+1]={type="checkbox",name=provider.short.." – "..provider.name,getFunc=function() return self.db.options[key] end,
            setFunc=function(value) self.db.options[key]=value; self:RefreshPrices(); if self.mainSettings then self:RefreshMainSettings() end end}
        options[#options+1]={type="divider"}
    end
    options[#options+1]={type="description",text=L("AGS_USES_YOUR_LAST_OWN_LISTING_PRICE_PER_UNIT_NOT_A_CONFIRMED_SALE_NPC")}
    options[#options+1]={type="header",name=L("FISHING")}
    options[#options+1]={type="button",name=L("RESET_LIFETIME"),func=function() ZO_Dialogs_ShowDialog("ALTHI_FISHING_TOTAL_RESET") end}
    lam:RegisterOptionControls("ALTHIOptions",options)
end
