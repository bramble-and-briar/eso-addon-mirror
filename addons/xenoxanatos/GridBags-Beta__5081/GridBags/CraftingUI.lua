GridBagsCraftingUI = {}
local U = GridBagsCraftingUI
local F, R, P = GridBagsCrafting, GridBagsRouting, GridBagsRoutingUI
local SCOPES = { all="All related (storage)", usable="Usable at destination", known="Known, skill-qualified recipes" }

function U:Close()
    if self.window then self.window:SetHidden(true); self.editor:SetHidden(true) end
    for _, edit in ipairs({self.quantity,self.units,self.moves}) do if edit then edit:LoseFocus() end end
    if self.editing then
        P.editingSession = false; self.editing = nil; R:Notify()
        if GridBagsGoldUI and GridBagsGoldUI.window then GridBagsGoldUI:Update() end
    end
end

function U:Show()
    if GridBagsRecipeGatherUI then GridBagsRecipeGatherUI:Close()end
    if GridBagsProtectionUI then GridBagsProtectionUI:Close() end
    if GridBagsDeliveryUI then GridBagsDeliveryUI:Close() end
    GridBags:ReleaseSearchFocus(); P:Close(); self:Close()
    self.character = self.character or R.character
    self.window:SetHidden(false); self:Update()
end

function U:Update()
    local id = self.character
    self.characterButton:SetText(R:Name(id))
    local skills, recipes = F:Skills(id), F:Recipes(id)
    local rec = GridBagsSnapshots.records[id]
    local age = id == R.character and "Live skills" or (rec and "Snapshot age: " .. math.floor(math.max(0, GetTimeStamp()-rec.updatedAt)/3600) .. " hours" or "No scan")
    self.status:SetText(age .. "; recipe scan: " .. (recipes and recipes.complete and "available" or "missing/stale; log into this character to refresh"))
    for craft, row in ipairs(self.rows) do
        local data = skills and skills[craft]; local role = F:Role(id, craft)
        local text = data and string.format("rank %d | passives %d | tier %d",data.rank,data.passivePoints,data.tier) or "Missing/stale skills"
        if data and data.rarity then text = text .. " | quality " .. data.rarity end
        local count = recipes and recipes.complete and string.format(" | recipes %d ready / %d known",recipes.ready[craft] or 0,recipes.known[craft] or 0) or ""
        row.label:SetText(F.names[craft] .. ": " .. text .. count .. "\n" ..
            (role.crafter and "Crafter " or "") .. (role.researcher and "Researcher " or "") .. (role.learner and "Learner " or "") .. "Priority " .. (role.priority or 100))
    end
end

function U:RoleMenu(button, craft)
    ClearMenu()
    local id = self.character
    local function Save(key, value)
        local profile = R.data.profiles[id] or {}; R.data.profiles[id] = profile
        profile.crafts = profile.crafts or {}
        local role = {}; for k,v in pairs(F:Role(id,craft)) do role[k]=v end
        role[key] = value; profile.crafts[craft] = role; ClearMenu(); self:Update()
    end
    local current = F:Role(id, craft)
    for _, key in ipairs({"crafter","researcher","learner"}) do
        local name = key
        AddMenuItem(name .. ": " .. (current[name] and "ON" or "off"), function() Save(name,not current[name]) end)
    end
    for _, priority in ipairs({1,2,3,5,10,20,50,100}) do
        local value = priority; AddMenuItem("Priority " .. value, function() Save("priority",value) end)
    end
    AddMenuItem("Use general profile defaults",function()
        local profile=R.data.profiles[id]; if profile and profile.crafts then profile.crafts[craft]=nil end
        ClearMenu(); self:Update()
    end)
    ShowMenu(button)
end

function U:Edit(rule)
    if R.pending or (GridBagsGold and GridBagsGold.pending) then P:Message("Wait for the transfer to settle before editing."); return end
    GridBags:ReleaseSearchFocus(); P:Close(); self:Close()
    self.editing = { id=rule and rule.id, source=rule and rule.source or self.character or R.character,
        dest=rule and rule.dest or R.BANK, craft=rule and rule.craft or 5, scope=rule and rule.scope or "all",
        mode=rule and rule.mode or "ask", enabled=not rule or rule.enabled ~= false,
        sourceUnassigned=rule and rule.sourceUnassigned == true or false }
    P.editingSession = true
    P.confirmWindow:SetHidden(true)
    if GridBagsGoldUI and GridBagsGoldUI.window then GridBagsGoldUI:Update() end
    self.quantity:SetText(tostring(rule and rule.maxPerStack or 200))
    self.units:SetText(rule and rule.unitsLeft ~= nil and tostring(rule.unitsLeft) or "")
    self.moves:SetText(rule and rule.movesLeft ~= nil and tostring(rule.movesLeft) or "")
    self.message:SetText("Specific items > known recipes > usable > storage. Equal scopes follow planner order. Unknown evidence holds stock. Named deliveries stay pinned after creation.")
    self:UpdateEditor(); self.editor:SetHidden(false)
end

function U:UpdateEditor()
    local s = self.editing; if not s then return end
    self.source:SetText("From: " .. R:Name(s.source)); self.dest:SetText("To: " .. R:Name(s.dest))
    self.craft:SetText(F.names[s.craft]); self.scope:SetText(SCOPES[s.scope])
    self.mode:SetText("Approval: " .. s.mode); self.enabled:SetText(s.enabled and "Rule enabled" or "Rule paused")
    self.dynamic:SetText(s.dest == "@best-crafter" and "Dynamic lead: ON" or "Use best profession crafter")
    self.dynamic:SetEnabled(s.craft >= 1 and s.craft <= 7)
    self.sourceFilter:SetEnabled(s.craft < 8)
    self.sourceFilter:SetText(s.sourceUnassigned and "Only source's non-crafter professions: ON" or "Source professions: include all")
end

function U:Save()
    local s = self.editing; if not s then return end
    local spec = { material=true,craft=s.craft,scope=s.scope,source=s.source,dest=s.dest,mode=s.mode,enabled=s.enabled,
        link="@materials:"..s.craft..":"..s.scope, name=F.names[s.craft] .. " / " .. SCOPES[s.scope] ..
            (s.sourceUnassigned and " / source non-crafter" or ""),maxStack=1,sourceUnassigned=s.sourceUnassigned,
        qty=tonumber(self.quantity:GetText()),units=self.units:GetText()~="" and self.units:GetText() or nil,
        moves=self.moves:GetText()~="" and self.moves:GetText() or nil }
    local rule, err
    if s.id then rule,err=R:UpdateRule(s.id,spec) else rule,err=R:AddRule(spec); if rule then rule.enabled=s.enabled end end
    if not rule then self.message:SetText(err); return end
    self:Close(); P:Show(); P:Message("Saved: "..rule.name..". Preview in Log > Preview; rule changes are recorded under Backups / import > Rule change history.")
end

function U:Initialize()
    local Frame,Label,Button,Edit = P.MakeFrame,P.MakeLabel,P.MakeButton,P.MakeEdit
    self.window=Frame("GridBagsCraftingOverview",960,740)
    Label(self.window,"CRAFTING OVERVIEW / PROFESSION ROLES",20,12,820,"ZoFontWinH2")
    Button(self.window,"Close",850,12,90,function()self:Close()end)
    self.characterButton=Button(self.window,"Character",20,55,510,function(c)
        P:Characters(c,function(id)self.character=id;self:Update()end,false)
    end)
    Button(self.window,"Refresh current character",550,55,270,function()
        F.recipeCache=nil; F.skillFrame=nil; GridBagsSnapshots:Capture(); self:Update()
    end)
    self.status=Label(self.window,"",20,96,920)
    self.rows={}
    for craft=1,7 do
        local index=craft; local y=148+(craft-1)*63
        self.rows[craft]={label=Label(self.window,"",20,y,755),button=Button(self.window,"Roles...",795,y,140,function(c)self:RoleMenu(c,index)end)}
    end
    Button(self.window,"New material rule",20,600,250,function()self:Edit()end)
    Button(self.window,"Routing planner",290,600,200,function()self:Close();P:Show()end)
    Button(self.window,"Clear gatherer's materials...",510,600,425,function()
        self:Edit()
        if not self.editing then return end
        self.editing.craft=0;self.editing.scope="all";self.editing.dest=R.BANK;self.editing.sourceUnassigned=true
        self.message:SetText("Choose the farming character as From. Its non-crafter professions are determined by your profession roles, not low skill rank. Bank deposits free space now; another character collects deliveries on its own bank visit.")
        self:UpdateEditor()
    end)
    Button(self.window,"Gather ingredients...",20,640,920,function()GridBagsRecipeGatherUI:Show()end)
    Label(self.window,"Roles inherit general profiles until customized. Lower priority numbers win rank/passive ties. Ready recipes meet skill requirements; ingredient stock is not required.",20,680,920)

    self.editor=Frame("GridBagsMaterialRule",800,620)
    Label(self.editor,"PROFESSION MATERIAL RULE",20,12,620,"ZoFontWinH2")
    Button(self.editor,"Close",690,12,90,function()self:Close()end)
    self.source=Button(self.editor,"",20,65,750,function(c)P:Characters(c,function(id)self.editing.source=id;self:UpdateEditor()end,true,true)end)
    self.dest=Button(self.editor,"",20,108,750,function(c)P:Characters(c,function(id)self.editing.dest=id;self:UpdateEditor()end,true)end)
    self.dynamic=Button(self.editor,"",20,151,750,function()self.editing.dest="@best-crafter";self:UpdateEditor()end)
    self.craft=Button(self.editor,"",20,200,300,function(c)
        ClearMenu();for index=0,9 do local id=index;AddMenuItem(F.names[id],function()
            ClearMenu();self.editing.craft=id
            if id==0 then self.editing.scope="all";if self.editing.dest=="@best-crafter"then self.editing.dest=R.BANK end end
            if id>=8 then self.editing.scope="all";self.editing.sourceUnassigned=false;if self.editing.dest=="@best-crafter"then self.editing.dest=R.BANK end end
            self:UpdateEditor()
        end)end;ShowMenu(c)
    end)
    self.scope=Button(self.editor,"",340,200,430,function(c)
        ClearMenu();for _,key in ipairs(self.editing.craft>=8 and {"all"}or {"all","usable","known"})do local scope=key;AddMenuItem(SCOPES[scope],function()ClearMenu();self.editing.scope=scope;self:UpdateEditor()end)end;ShowMenu(c)
    end)
    self.mode=Button(self.editor,"",20,250,360,function(c)
        ClearMenu();for _,key in ipairs({"ask","limited","standing"})do local mode=key;AddMenuItem(mode,function()ClearMenu();self.editing.mode=mode;self:UpdateEditor()end)end;ShowMenu(c)
    end)
    self.enabled=Button(self.editor,"",400,250,370,function()self.editing.enabled=not self.editing.enabled;self:UpdateEditor()end)
    self.quantity=Edit(self.editor,"Max units / stack",20,305,200)
    self.units=Edit(self.editor,"Allowance units",410,305,"")
    self.moves=Edit(self.editor,"Allowance moves",410,350,"")
    self.sourceFilter=Button(self.editor,"",20,350,370,function()
        self.editing.sourceUnassigned=not self.editing.sourceUnassigned;self:UpdateEditor()
    end)
    Label(self.editor,"Ask: confirm each batch. Limited: use an allowance, then ask. Standing: repeat until paused/revoked. Blank allowance = unlimited; limited needs at least one counter.",20,400,750)
    self.message=Label(self.editor,"",20,465,750)
    self.message:SetDimensions(750,90)
    Button(self.editor,"Save material rule",20,565,320,function()self:Save()end)
    Button(self.editor,"Cancel",480,565,290,function()self:Close()end)
    GridBagsHelp:Bind(self.source,"Choose a character, account bank, or Any source. Any evaluates the logged-in character and unreserved bank stock; it leaves the destination's own backpack alone. Offline characters export only when they visit the bank.")
    GridBagsHelp:Bind(self.dest,"Choose bank storage or a named recipient. Character deliveries use reserved bank stock and wait for that recipient to visit the bank.")
    GridBagsHelp:Bind(self.scope,"All related and Usable match only this profession's own material types. Known requires a learned, skill-qualified recipe and can include cross-profession ingredients; those deliveries always need explicit approval, even under a Standing rule. This is not an active crafting shopping list.")
    GridBagsHelp:Bind(self.dynamic,"Resolve the lead for each new batch using earned profession rank, then passive investment, then configured priority. Missing/stale candidates or exact ties hold selection. Existing deliveries never retarget.")
    GridBagsHelp:Bind(self.mode,GridBagsHelp.text.Approval)
    GridBagsHelp:Bind(self.sourceFilter,"When enabled, keep materials for professions where the concrete source character has an assigned Crafter role. Low skill alone does not mean non-crafter. Style and trait materials use separate categories.")
    GridBagsHelp:Bind(self.enabled,"Enable or pause future execution under this rule. Pausing does not reverse deposits or remove reserved deliveries.")
end
