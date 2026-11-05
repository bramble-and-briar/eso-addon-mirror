local C = CrownCrateCodex
function C:CrateChoices()
    local choices={}
    for _,crate in pairs(self.db.crates) do choices[#choices+1]={id=crate.id,name=crate.name} end
    table.sort(choices,function(a,b)
        local lower=zo_strlower or string.lower
        local left,right=lower(a.name),lower(b.name)
        if left==right then return a.id<b.id end
        return left<right
    end)
    return choices
end
function C:SelectCrate(id)
    self.crateFilter,self.page,self.scrollOffset,self.selectedReward=id,1,0,nil
    self:RefreshUI()
end
function C:ShowCrateMenu()
    local entries={{name=C.L("All crate types"),selected=self.crateFilter==nil,callback=function() self:SelectCrate(nil) end}}
    for _,choice in ipairs(self:CrateChoices()) do
        local id=choice.id
        entries[#entries+1]={name=choice.name,selected=self.crateFilter==id,callback=function() self:SelectCrate(id) end}
    end
    self:ShowChoiceMenu(self.crateButton,C.L("Crate type"),entries)
end

function C:RewardCategoryMatches(reward)
    if not self.categoryFilter then return true end
    if self.categoryFilter == "collectibles" then return reward.productType == MARKET_PRODUCT_TYPE_COLLECTIBLE end
    if self.categoryFilter == "items" then return reward.productType == MARKET_PRODUCT_TYPE_ITEM end
    return reward.productType == MARKET_PRODUCT_TYPE_COLLECTIBLE and reward.categoryId == self.categoryFilter
end

function C:ShowCategoryMenu()
    local entries={}
    local function Add(name,value)
        entries[#entries+1]={name=name,selected=self.categoryFilter==value,callback=function() self.categoryFilter=value; self.categoryFilterName=name; self.page=1; self:RefreshUI() end}
    end
    Add(C.L("All reward types"),nil); Add(C.L("All collectibles"),"collectibles"); Add(C.L("Items and consumables"),"items")
    local categories = {}
    for _,opening in ipairs(self.db.history) do
        for _,reward in ipairs(opening.rewards) do
            if reward.categoryId then categories[reward.categoryId]=reward.typeText or tostring(reward.categoryId) end
        end
    end
    local choices = {}
    for id,name in pairs(categories) do choices[#choices+1]={id=id,name=name} end
    table.sort(choices,function(a,b) return a.name<b.name end)
    for _,choice in ipairs(choices) do Add(choice.name,choice.id) end
    self:ShowChoiceMenu(self.categoryButton,C.L("Reward type"),entries)
end

function C:SetDisplaySize(value)
    if value ~= "Compact" and value ~= "Large" and value ~= "Extra Large" then return end
    self.db.settings.displaySize = value
    if self.window then self.page = 1; self:RefreshUI() end
end

function C:OpenKeybindings()
    if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
        if KEYBINDINGS_SCENE_GAMEPAD then
            if self.window then self:SetWindowHidden(self.window,true) end
            if self.HideChoiceMenu then self:HideChoiceMenu() end
            SCENE_MANAGER:Push("keybindings_gamepad")
            return
        end
        d(C.L("Crown Crate Codex: switch to keyboard mode to open Controls > Keybindings.")); return
    end
    if self.window then self:SetWindowHidden(self.window,true) end
    self.keybindRequest = (self.keybindRequest or 0) + 1
    local request, attempts = self.keybindRequest, 0
    local function Select()
        if request ~= self.keybindRequest or not SCENE_MANAGER:IsShowing("gameMenuInGame") then return end
        attempts = attempts + 1
        local menu = ZO_GameMenu_InGame and ZO_GameMenu_InGame.gameMenu
        local tree = menu and menu.navigationTree
        local addonNode, nativeNode
        if tree and tree.ExecuteOnSubTree then
            tree:ExecuteOnSubTree(nil, function(node)
                local data = node.data
                if data and data.categoryName == GetString(SI_GAME_MENU_CONTROLS) then
                    if libAddonKeybinds and data.name == "Addon Keybinds" then addonNode = node end
                    if data.name == GetString(SI_GAME_MENU_KEYBINDINGS) then nativeNode = node end
                end
            end)
        end
        if addonNode or nativeNode then
            tree:SelectNode(addonNode or nativeNode)
            if VOTANS_KEYBINDER and VOTANS_KEYBINDER.searchBox and VOTANS_KEYBINDER.FilterTextChanged then
                VOTANS_KEYBINDER.searchBox:SetText("Crown Crate Codex")
                VOTANS_KEYBINDER:FilterTextChanged()
            else d(C.L("Crown Crate Codex: keybindings opened. Find the Crown Crate Codex category.")) end
        elseif attempts < 10 then zo_callLater(Select, 100)
        else d(C.L("Crown Crate Codex: open Controls > Keybindings and find Crown Crate Codex.")) end
    end
    SCENE_MANAGER:Show("gameMenuInGame")
    zo_callLater(Select, 100)
end

function C:FitSettingsControls()
    for _,name in ipairs({"CrownCrateCodexOpenHistory","CrownCrateCodexKeys","CrownCrateCodexLegacyImport","CrownCrateCodexUESP","CrownCrateCodexBethesda","CrownCrateCodexResetPosition"}) do
        local control=_G[name]
        if control and control.button then
            local width=control:GetWidth()
            control:SetDimensions(width,44)
            control.button:ClearAnchors()
            control.button:SetAnchor(TOPLEFT,control,TOPLEFT,8,6)
            control.button:SetDimensions(width-16,30)
        end
    end
    for _,name in ipairs({"CrownCrateCodexLegacyHeader","CrownCrateCodexSourcesHeader","CrownCrateCodexBrowsingHeader"}) do
        local control=_G[name]
        if control then control:SetDimensions(control:GetWidth(),44) end
    end
end

function C:SettingsControls()
    local languageNames,languageCodes={C.L("Automatic — follow ESO"),"English"},{"auto","en"}
    if self.LanguageChoices then languageNames,languageCodes=self:LanguageChoices() end
    local controls={
        {type="description", text=C.L("Display, history statistics, and shortcuts. These settings never erase recorded openings.")},
        {type="button", name=C.L("Open history"), reference="CrownCrateCodexOpenHistory", width="full", func=function() SCENE_MANAGER:Hide("gameMenuInGame"); if not self.window or self.window:IsHidden() then self:Toggle() end end},
        {type="button", name=C.L("Keybindings"), reference="CrownCrateCodexKeys", width="full", func=function() self:OpenKeybindings() end},
        {type="dropdown", name=C.L("Text and icon size"), choices={C.L("Compact"),C.L("Large"),C.L("Extra Large")}, choicesValues={"Compact","Large","Extra Large"}, default="Large",
            getFunc=function() return self.db.settings.displaySize end, setFunc=function(value) self:SetDisplaySize(value) end},
        {type="slider", name=C.L("Window scale (%)"), min=75, max=130, step=5, default=100,
            getFunc=function() return self.db.settings.windowScale end,
            setFunc=function(value) self.db.settings.windowScale=value; if self.window then self:RefreshUI() end end,
            tooltip=C.L("The complete window stays within the screen. Extra Large also increases icons and text independently of this scale.")},
        {type="checkbox", name=C.L("Include imported openings in percentages"), default=true,
            tooltip=self:ImportHelp("rewards"),
            getFunc=function() return self.db.settings.includeImported end,
            setFunc=function(value) self.db.settings.includeImported=value; if self.window then self:RefreshUI() end end},
        {type="checkbox", name=C.L("Include verified imported tiers in rarity percentages"), default=true,
            tooltip=self:ImportHelp("tiers"),
            getFunc=function() return self.db.settings.includeImportedTiers end,
            setFunc=function(value) self.db.settings.includeImportedTiers=value; if self.window then self:RefreshUI() end end},
        {type="header", name=C.L("Legacy Crown Crate Tracker history"),reference="CrownCrateCodexLegacyHeader",width="full"},
        {type="button", name=C.L("Import Crown Crate Tracker History"), reference="CrownCrateCodexLegacyImport", width="full", tooltip=C.L("Optional recovery for single-server history. Shows a server warning and requires explicit confirmation. Mixed-server records cannot be reliably separated."), func=function() self:OpenLegacyImportDialog() end},
        {type="header", name=C.L("Sources and references"),reference="CrownCrateCodexSourcesHeader",width="full"},
        {type="button", name=C.L("UESP: Crown Crates and rewards"), reference="CrownCrateCodexUESP", width="full", tooltip=C.L("Opens the UESP Crown Crates page in your browser using ESO's external-link prompt."), func=function() RequestOpenUnsafeURL("https://en.uesp.net/wiki/Online:Crown_Crates") end},
        {type="button", name=C.L("Bethesda: Crown Crate reward odds"), reference="CrownCrateCodexBethesda", width="full", tooltip=C.L("Opens Bethesda Support's published reward-group guidelines in your browser."), func=function() RequestOpenUnsafeURL("https://help.bethesda.net/#en/answer/49828") end},
        {type="header", name=C.L("Browsing and visibility"),reference="CrownCrateCodexBrowsingHeader",width="full"},
        {type="checkbox",name=C.L("Show account name"),default=true,
            tooltip=C.L("Show your ESO @UserID beside the server in the Codex header. Turn off to hide it in screenshots."),
            getFunc=function() return self.db.settings.showAccountName end,
            setFunc=function(value) self.db.settings.showAccountName=value; if self.window then self:RefreshUI() end end},
        {type="dropdown",name=C.L("History navigation"),choices={C.L("Pages"),C.L("Scrolling")},choicesValues={"Pages","Scrolling"},default="Pages",
            getFunc=function() return self.db.settings.browseMode end,setFunc=function(value) self:SetBrowseMode(value) end,
            tooltip=C.L("Scrolling reuses visible rows. Mouse wheel and scrollbar move through matching records without creating controls for the entire history.")},
        {type="slider",name=C.L("Rows per mouse-wheel notch"),min=1,max=5,step=1,default=1,
            getFunc=function() return self.db.settings.scrollStep end,setFunc=function(value) self.db.settings.scrollStep=value end},
        {type="checkbox",name=C.L("Keep Codex above other panels"),default=true,
            getFunc=function() return self.db.settings.alwaysOnTop end,setFunc=function(value) self.db.settings.alwaysOnTop=value; self:RaiseWindow() end},
        {type="slider",name=C.L("Background opacity (%)"),min=0,max=100,step=1,default=96,
            tooltip=C.L("Higher values make the dark background more solid. 100% is fully opaque; 0% makes the main background transparent. Changes apply immediately."),
            getFunc=function() return self.db.settings.backgroundOpacity end,setFunc=function(value) self.db.settings.backgroundOpacity=value; if self.window then self:RefreshUI() end end},
        {type="checkbox",name=C.L("Show help and reference hints"),default=true,
            getFunc=function() return self.db.settings.showHelp end,setFunc=function(value) self.db.settings.showHelp=value; if self.window then self:RefreshUI() end end},
        {type="colorpicker",name=C.L("Right-click action hint color"),default={r=0.41,g=0.84,b=1,a=1},
            getFunc=function() local c=self.db.settings.actionColor; return c[1],c[2],c[3],1 end,
            setFunc=function(r,g,b) self.db.settings.actionColor={r,g,b}; if self.window then self:RefreshUI() end end},
        {type="slider",name=C.L("Description tooltip width"),min=360,max=900,step=20,default=640,
            getFunc=function() return self.db.settings.tooltipWidth end,setFunc=function(value) self.db.settings.tooltipWidth=value end,
            tooltip=C.L("Tooltips also clamp to the current screen width and height.")},
        {type="button",name=C.L("Reset window position"), reference="CrownCrateCodexResetPosition", width="full",func=function()
            if self.window then self.window:ClearAnchors(); self.window:SetAnchor(RIGHT,GuiRoot,RIGHT,-20,0) end
        end},
        {type="checkbox",name=C.L("Show official reference column"),default=true,
            getFunc=function() return self.db.settings.showOfficialReference end,
            setFunc=function(value) self.db.settings.showOfficialReference=value; if self.window then self:RefreshUI() end end,
            tooltip=C.L("General purchased-crate guidelines, kept separate from your measured results. The 2% figure applies to Apex and Radiant Apex combined; no separate official Radiant percentage is supplied. Known preview and Ouroboros crates show no applicable reference.")},
        {type="checkbox",name=C.L("Controller navigation"),default=true,
            getFunc=function() return self.db.settings.gamepadNavigation end,
            setFunc=function(value) self.db.settings.gamepadNavigation=value; if self.SyncGamepad then self:SyncGamepad() end end},
        {type="dropdown",name=C.L("Language"),choices=languageNames,choicesValues=languageCodes,default="auto",
            tooltip=C.L("Language changes apply after /reloadui. Your saved history is preserved. ESO supplies reward and crate names in the game client's language."),
            getFunc=function() return self.db.settings.language end,
            setFunc=function(value)
                local valid={auto=true,en=true,de=true,fr=true,es=true,ru=true,zh=true,ja=true}
                if valid[value] then self.db.settings.language=value end
            end,requiresReload=true},
    }
    table.insert(controls,4,table.remove(controls)) -- Language beside the primary display options.
    return controls
end

function C:InitializeSettings()
    if self.settingsPanel then return true end
    local addonMenu = LibAddonMenu2
    if not addonMenu then return false end
    self.settingsPanel = addonMenu:RegisterAddonPanel("CrownCrateCodexOptions", {
        type="panel", name="Crown Crate Codex", displayName="Crown Crate Codex",
        author="Crown Crate Codex contributors", version=self.version, registerForRefresh=true,
    })
    local controls=self:SettingsControls()
    addonMenu:RegisterOptionControls("CrownCrateCodexOptions",controls)
    if CALLBACK_MANAGER then
        for _,event in ipairs({"LAM-PanelControlsCreated","LAM-PanelOpened"}) do
            CALLBACK_MANAGER:RegisterCallback(event,function(panel)
                if panel==self.settingsPanel then self:FitSettingsControls() end
            end)
        end
    end
    return true
end

function C:OpenSettings()
    if self.GamepadSettings and self.db.settings.gamepadNavigation~=false and IsInGamepadPreferredMode and IsInGamepadPreferredMode() then self:GamepadSettings(); return end
    if not self:InitializeSettings() then d(C.L("Crown Crate Codex: install/enable LibAddonMenu-2.0 for Settings > AddOns. Display controls and /ccc keys still work.")); return end
    if self.window then self:SetWindowHidden(self.window,true) end
    LibAddonMenu2:OpenToPanel(self.settingsPanel)
end

function C:OpenCollectible(reward)
    if not reward or reward.productType ~= MARKET_PRODUCT_TYPE_COLLECTIBLE or not reward.referenceId then return false end
    local book = IsInGamepadPreferredMode and IsInGamepadPreferredMode() and GAMEPAD_COLLECTIONS_BOOK or COLLECTIONS_BOOK
    if not book or not book.BrowseToCollectible then d(C.L("Crown Crate Codex: this client cannot open that collectible directly.")); return false end
    if self.window then self:SetWindowHidden(self.window,true) end
    if self.exportWindow then self:SetWindowHidden(self.exportWindow,true) end
    book:BrowseToCollectible(reward.referenceId)
    return true
end
