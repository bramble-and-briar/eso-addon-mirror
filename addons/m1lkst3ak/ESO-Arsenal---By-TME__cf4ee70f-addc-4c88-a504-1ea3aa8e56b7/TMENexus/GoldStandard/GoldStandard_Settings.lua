-- Gold Standard | Console-friendly, collapsible settings.
-- Native Add-Ons menu keeps controller focus. No ESO scene switching.
local GS = GoldStandard

function GS:InitializeSettings()
    local lam = TMENexus.settingsProxy
    if type(lam) ~= "table" or type(lam.RegisterAddonPanel) ~= "function" then return end
    local panelId="GoldStandard_Options"
    lam:RegisterAddonPanel(panelId,{
        type="panel",name="Gold Standard",
        displayName="|cE8BC63GOLD STANDARD|r  |cCCCCCCKnow What It's Worth.|r",
        author="Trash Man Enterprises",version=self.version,
        registerForRefresh=true,registerForDefaults=true,
    })
    local function settingKey(key)
        local id,axis=key:match("^(%a+)Pos([XY])$")
        if not id then id=key:match("^(%a+)Scale$");if id then axis="scale" end end
        return id,axis
    end
    local function get(key)
        local id,axis=settingKey(key)
        if id then return self:LayoutValue(id,axis=="X" and "x" or axis=="Y" and "y" or "scale") end
        return self.saved[key]
    end
    local function set(key,value)
        local id,axis=settingKey(key)
        if id then
            self:ChangeLayoutSetting(id,axis=="X" and "x" or axis=="Y" and "y" or "scale",value)
            return
        end
        self.saved[key]=value
        if key=="wealthMaterialKeep" or key=="wealthFurnitureKeep" then self.wealthSnapshot=nil end
        if key=="minProfit" or key=="minROI" or key=="resaleFee" or key=="marketMultiplier" then
            self:AnalyzeAllFlips()
        end
        self:Refresh()
    end
    local function toggle(name,key,tip)
        return {type="checkbox",name=name,tooltip=tip,getFunc=function()return get(key)end,
            setFunc=function(v)set(key,v)end,default=self.defaults[key]}
    end
    local function slider(name,key,min,max,step,tip)
        return {type="slider",name=name,tooltip=tip,min=min,max=max,step=step,
            getFunc=function()return get(key)end,setFunc=function(v)set(key,v)end,
            default=self.defaults[key] or 100}
    end
    local function action(name,fn)
        return {type="button",name=name,func=fn}
    end
    local function submenu(name,items)
        return {type="submenu",name=name,controls=items}
    end
    local function window(name,id)
        return submenu(name,{
            slider("Horizontal Position",id.."PosX",0,100,1),
            slider("Vertical Position",id.."PosY",0,100,1),
            slider("Size",id.."Scale",65,150,5),
            action("Preview / Hide",function()self:ShowLayoutSliderPreview(id)end),
            action("Reset Layout",function()self:ResetSliderLayout(id)end),
        })
    end

    local controls={
        {type="header",name="QUICK ACCESS"},
        action("OPEN EMPIRE",function()self:OpenPanelFromSettings("empire")end),
        action("OPEN TRACKER",function()self:OpenPanelFromSettings("tracker")end),
        action("FLIP FINDER RESULTS",function()self:OpenPanelFromSettings("flip")end),
        action("CLOSE DASHBOARD",function()self:HidePanel()end),
        submenu("TRACKER & CURRENCIES",{
            toggle("Enable Tracking","tracking"),
            toggle("Show Tracker HUD","showHUD"),
            toggle("Show Gold Balances","hudShowGold"),
            toggle("Show AP Conversion","hudShowAP"),
            toggle("Show Tel Var Conversion","hudShowTelVar"),
            slider("HUD Detail","hudMode",1,3,1),
            action("Reset Session",function()self:ResetSession()end),
        }),
        submenu("Wealth Management",{
            toggle("Show Wealth HUD","showWealthHUD"),
            slider("Materials to Keep","wealthMaterialKeep",0,1000,10),
            slider("Furnishings to Keep","wealthFurnitureKeep",0,20,1),
            action("Refresh Wealth",function()self:ScanWealth(true);self:Refresh()end),
        }),
        submenu("Loot Notifications",{
            toggle("Show Loot Popups","showLootToast"),
            action("Preview / Hide Loot Popup",function() self:ShowLayoutSliderPreview("toast") end),
            toggle("Show Missing Prices","showUnpriced"),
            slider("Minimum Loot Value (g)","minToast",0,100000,100),
            slider("Display Time (sec)","toastSeconds",1,10,1),
        }),
        submenu("FLIP FINDER",{
            toggle("Auto-Scan Visited Traders","autoFlipScan"),
            toggle("Show Trader Popup","flipPopup"),
            slider("Maximum Scan Pages","autoScanPages",1,40,1),
            slider("Minimum Profit (g)","minProfit",0,1000000,500),
            slider("Minimum ROI (%)","minROI",0,500,5),
            slider("Selling Costs (%)","resaleFee",0,30,1),
            slider("Market Price Adjustment (%)","marketMultiplier",25,150,5),
        }),
        {type="header",name="WINDOW POSITION & SIZE"},
        window("Tracker HUD","hud"),
        window("Wealth HUD","wealth"),
        window("Dashboard","panel"),
        window("Flip Finder Popup","popup"),
        window("Loot Notification","toast"),
        action("HIDE ALL PREVIEWS",function()self:CloseSliderPreview()end),
        submenu("DASHBOARD NAVIGATION",{
            action("Previous Tab",function()self:SettingsDashboardNavigate(-1)end),
            action("Next Tab",function()self:SettingsDashboardNavigate(1)end),
            action("Previous Page",function()self:SettingsDashboardPage(-1)end),
            action("Next Page",function()self:SettingsDashboardPage(1)end),
            action("Close Dashboard",function()self:HidePanel()end),
        }),
    }
    lam:RegisterOptionControls(panelId,controls)
end

function GS:OpenPanelFromSettings(tab)
    self.dashboardFromSettings=true
    self:ShowPanel(tab)
end
function GS:SettingsDashboardNavigate(direction)
    if not self.panel or self.panel:IsHidden() then self:OpenPanelFromSettings("tracker") end
    self:SwitchTab(direction)
end
function GS:SettingsDashboardPage(direction)
    if not self.panel or self.panel:IsHidden() then self:OpenPanelFromSettings("tracker") end
    self:PageScroll(direction)
end
