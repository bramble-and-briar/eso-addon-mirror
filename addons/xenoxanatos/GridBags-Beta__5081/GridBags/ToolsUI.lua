GridBagsToolsUI = {}
local U = GridBagsToolsUI
local A,T,C = GridBagsActivity,GridBagsTransferTools,GridBagsConfig
local UI = GridBagsRoutingUI

function U:Name(id)
    return id and GridBagsRouting:Name(id) or "—"
end

function U:Close()
    if self.window then self.window:SetHidden(true);self.textWindow:SetHidden(true);self.edit:LoseFocus()end
end

function U:Text(title,value,mode)
    self.textMode=mode or "output"
    self.textTitle:SetText(title)
    self.edit:SetText(value or "");self.edit:LoseFocus()
    self.window:SetHidden(true);self.textWindow:SetHidden(false)
    local importing=self.textMode=="import"
    self.validateButton:SetHidden(not importing);self.mapButton:SetHidden(not importing);self.applyButton:SetHidden(not importing)
    self.textStatus:SetText(importing and "Paste a GB1 configuration, then Preview import. No code is executed. Names and rule item links are part of configuration exports." or
        "Use Select all, then Ctrl+C to copy. Reports omit private inventory and character details; private activity/configuration views contain their displayed data.")
end

function U:ImportPreview(resetMapping)
    local payload,err=C:Decode(self.edit:GetText())
    if not payload then self.textStatus:SetText(err);self.importPayload=nil;self.prepared=nil;return end
    self.importPayload=payload;self.importText=self.edit:GetText()
    if resetMapping or not self.mappings then self.mappings=C:Mappings(payload)end
    self:CheckMappings()
end

function U:CheckMappings()
    if not self.importPayload then return end
    local chars=self.importPayload.characters
    if type(chars)~="table"then self.textStatus:SetText("Invalid character section");self.prepared=nil;return end
    local keys={};for id,name in pairs(chars)do
        if type(id)~="string"or type(name)~="string"or #id>100 or #name>200 then self.textStatus:SetText("Invalid character definition");self.prepared=nil;return end
        keys[#keys+1]=id
    end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    self.nextCharacter=nil
    for _,id in ipairs(keys)do if not self.mappings[id]then self.nextCharacter=id;break end end
    self.mapButton:SetEnabled(self.nextCharacter~=nil)
    if self.nextCharacter then
        self.prepared=nil
        self.textStatus:SetText("Map or skip: "..tostring(chars[self.nextCharacter])..". Skipping removes rules that reference this character from the import preview.")
        return
    end
    local prepared,err=C:Prepare(self.importPayload,self.mappings)
    self.prepared=prepared
    self.textStatus:SetText(prepared and string.format("Ready: %d repeat rules; %d skipped. Replaces repeat rules. Imported rules and all gold profiles start disabled/Ask. Existing deposits stay; protections never weaken. Global pause is enabled. A recovery backup is made first.",#prepared.rules,prepared.skipped)or err)
end

function U:MapNext(button)
    local source=self.nextCharacter;if not source then return end
    ClearMenu()
    local entries,seen={},{}
    for id in pairs(GridBagsSnapshots.records)do entries[#entries+1]=id;seen[id]=true end
    if not seen[GridBagsRouting.character]then entries[#entries+1]=GridBagsRouting.character end
    table.sort(entries,function(a,b)return self:Name(a)<self:Name(b)end)
    for _,id in ipairs(entries)do
        local target=id
        AddMenuItem("Map to "..self:Name(target),function()
            if not self.importPayload or not self.mappings then ClearMenu();self.textStatus:SetText("Preview the import again after editing its text.");return end
            self.mappings[source]=target;ClearMenu();self:CheckMappings()
        end)
    end
    AddMenuItem("Skip this character and its referenced rules",function()
        if not self.importPayload or not self.mappings then ClearMenu();self.textStatus:SetText("Preview the import again after editing its text.");return end
        self.mappings[source]="@skip";ClearMenu();self:CheckMappings()
    end)
    ShowMenu(button)
end

function U:ConfigMenu(button)
    ClearMenu()
    AddMenuItem("Rule change history (saves / edits / deletions)",function()ClearMenu();self:Text("PRIVATE RULE CHANGE HISTORY",GridBagsRouting:RuleHistory())end)
    AddMenuItem("Create local configuration backup",function()
        T:Backup();ClearMenu();self.summary:SetText("Configuration backed up locally. The latest five are retained.")
    end)
    AddMenuItem("Export configuration for backup/sharing",function()
        local text,err=C:Encode(T:CaptureConfig());ClearMenu()
        if text then self:Text("CONFIGURATION EXPORT — includes names and rule item links",text)else self.summary:SetText(err)end
    end)
    AddMenuItem("Import configuration...",function()
        ClearMenu();self.importPayload=nil;self.mappings=nil;self:Text("IMPORT / RESTORE CONFIGURATION","","import")
    end)
    for index=#A.data.backups,1,-1 do
        local backup=A.data.backups[index]
        AddMenuItem("Restore backup "..(#A.data.backups-index+1).." — "..GetDateStringFromTimestamp(backup.at).." "..backup.label,function()
            ClearMenu();local text,err=C:Encode(backup.config)
            if not text then self.summary:SetText(err);return end
            self.mappings=nil;self:Text("RESTORE CONFIGURATION — paused preview",text,"import");self:ImportPreview(true)
        end)
    end
    ShowMenu(button)
end

function U:Update()
    if not self.window or not A.data then return end
    self.pauseButton:SetText(A:IsPaused()and"Resume transfers"or"Pause transfers")
    local entries={}
    if self.mode=="preview"then
        for _,row in ipairs(self.previewResult and self.previewResult.rows or {})do entries[#entries+1]=row end
    else
        for index=#A.data.history,1,-1 do
            local entry=A.data.history[index]
            if not self.filter or entry.outcome==self.filter then entries[#entries+1]=entry end
        end
    end
    self.page=math.max(0,math.min(self.page or 0,math.max(0,math.ceil(#entries/6)-1)))
    for i,row in ipairs(self.rows)do
        local entry=entries[self.page*6+i]
        row.button:SetHidden(not entry);row.label:SetHidden(not entry)
        if entry then
            local label=self.mode=="preview"and entry.state or entry.outcome
            row.button:SetText(label or "details")
            local subject=entry.kind=="gold"and"Gold"or(entry.item or entry.kind or"Planned move")
            local quantity=entry.quantity and(" x"..entry.quantity)or""
            local route=entry.source and(" | "..self:Name(entry.source).." > "..self:Name(entry.destination))or""
            row.label:SetText((entry.clock and("["..entry.clock.."] ")or"")..subject..quantity..route.."\n"..tostring(entry.reason).." ["..tostring(entry.code or "").."]")
            row.button:SetHandler("OnClicked",function()
                local lines={subject..quantity, "State: "..tostring(label), "Reason: "..tostring(entry.reason),"Code: "..tostring(entry.code),
                    "Source: "..self:Name(entry.source),"Destination: "..self:Name(entry.destination)}
                if entry.at then lines[#lines+1]="Recorded: "..GetDateStringFromTimestamp(entry.at).." "..tostring(entry.clock or "").." (timestamp "..entry.at..")" end
                if entry.observedAt then lines[#lines+1]="Planning observation age at event: "..math.max(0,math.floor(((entry.at or GetTimeStamp())-entry.observedAt)/60)).." min" end
                if entry.approval then lines[#lines+1]="Approval: "..entry.approval end
                for _,part in ipairs(entry.allocations or {})do lines[#lines+1]="Allocation: "..part.quantity.." for "..self:Name(part.destination)..(part.observedAt and("; observation age "..math.max(0,math.floor(((entry.at or GetTimeStamp())-part.observedAt)/60)).." min")or"")end
                local labels={requestedSourceCount="Source count before request",requestedDestinationCount="Destination count before request",
                    observedSourceCount="Source count last observed",observedDestinationCount="Destination count last observed",
                    beforeChar="Carried gold before",afterChar="Carried gold last observed",beforeBank="Bank gold before",afterBank="Bank gold last observed"}
                for _,key in ipairs({"requestedSourceCount","requestedDestinationCount","observedSourceCount","observedDestinationCount","beforeChar","afterChar","beforeBank","afterBank"})do
                    if entry[key]~=nil then lines[#lines+1]=labels[key]..": "..entry[key]end
                end
                self:Text("PRIVATE ACTIVITY / PREVIEW DETAILS",table.concat(lines,"\n"))
            end)
        end
    end
    local note=self.mode=="preview"and(self.previewResult and self.previewResult.note or"Preview unavailable")or"Private history: requested, verified, skipped, waiting and uncertain outcomes."
    self.summary:SetText((A:IsPaused()and"PAUSED | "or"")..#entries.." entries | page "..(self.page+1).."\n"..note)
    self.filterButton:SetText(self.mode=="preview"and"Refresh read-only preview"or("Filter: "..(self.filter or"all")))
end

function U:Show(mode)
    if GridBagsRecipeGatherUI then GridBagsRecipeGatherUI:Close()end
    if GridBagsProtectionUI then GridBagsProtectionUI:Close() end
    if GridBagsDeliveryUI then GridBagsDeliveryUI:Close() end
    GridBagsCraftingUI:Close()
    GridBags:ReleaseSearchFocus();GridBagsRoutingUI:Close();GridBagsGoldUI:Close()
    self.mode=mode or"history";self.page=0
    if self.mode=="preview"then
        local result,err=T:Preview();self.previewResult=result
        if not result then self.previewResult={rows={},note=err}end
    end
    self.textWindow:SetHidden(true);self.edit:LoseFocus();self.window:SetHidden(false);self:Update()
    if mode=="report"then self:Text("TROUBLESHOOTING REPORT — private details omitted",T:Report())end
end

function U:Initialize(owner)
    self.window=UI.MakeFrame("GridBagsTransferTools",860,720)
    UI.MakeLabel(self.window,"TRANSFER LOG AND TOOLS",20,12,670,"ZoFontWinH2")
    UI.MakeButton(self.window,"Close",740,12,100,function()self:Close()end)
    self.pauseButton=UI.MakeButton(self.window,"Pause transfers",20,55,170,function()A:SetPaused(not A:IsPaused())end)
    UI.MakeButton(self.window,"History",200,55,110,function()self.mode="history";self.page=0;self:Update()end)
    UI.MakeButton(self.window,"Preview",320,55,110,function()self:Show("preview")end)
    UI.MakeButton(self.window,"Report",440,55,110,function()self:Text("TROUBLESHOOTING REPORT — private details omitted",T:Report())end)
    self.configButton=UI.MakeButton(self.window,"Backups / import",560,55,270,function(c)self:ConfigMenu(c)end)
    self.filterButton=UI.MakeButton(self.window,"Filter",20,105,245,function(c)
        if self.mode=="preview"then self:Show("preview");return end
        ClearMenu()
        for _,name in ipairs({"all","success","skipped","waiting","review","requested","failed","control"})do
            local value=name;AddMenuItem(value,function()self.filter=value~="all"and value or nil;self.page=0;ClearMenu();self:Update()end)
        end
        ShowMenu(c)
    end)
    self.summary=UI.MakeLabel(self.window,"",280,100,550,"ZoFontGameSmall");self.summary:SetDimensions(550,48)
    self.rows={}
    for i=1,6 do
        local y=155+(i-1)*73
        self.rows[i]={button=UI.MakeButton(self.window,"Details",20,y,140,function()end),label=UI.MakeLabel(self.window,"",175,y,655,"ZoFontGameSmall")}
        self.rows[i].label:SetDimensions(655,66)
        self.rows[i].label:SetMaxLineCount(3);self.rows[i].label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    UI.MakeButton(self.window,"Previous",20,620,120,function()self.page=math.max(0,(self.page or 0)-1);self:Update()end)
    UI.MakeButton(self.window,"Next",150,620,120,function()self.page=(self.page or 0)+1;self:Update()end)
    UI.MakeButton(self.window,"Deliveries",300,620,245,function()GridBagsDeliveryUI:Show()end)
    UI.MakeButton(self.window,"Protected items",560,620,270,function()GridBagsProtectionUI:Show()end)
    UI.MakeLabel(self.window,"Preview never moves items or consumes approval. Imports start paused and retain existing deposited deliveries. Normal ESO SavedVariables persistence applies.",20,665,800,"ZoFontGameSmall")
    self.textWindow=UI.MakeFrame("GridBagsToolsText",860,720)
    self.textTitle=UI.MakeLabel(self.textWindow,"",20,12,700,"ZoFontWinH3")
    UI.MakeButton(self.textWindow,"Back",740,12,100,function()self.edit:LoseFocus();self.textWindow:SetHidden(true);self.window:SetHidden(false);self:Update()end)
    local bg=WINDOW_MANAGER:CreateControl(nil,self.textWindow,CT_BACKDROP)
    bg:SetAnchor(TOPLEFT,self.textWindow,TOPLEFT,20,65);bg:SetDimensions(820,440)
    bg:SetCenterColor(0.10,0.11,0.13,1);bg:SetEdgeColor(0.4,0.4,0.4,1);bg:SetEdgeTexture("",1,1,1,0)
    self.edit=WINDOW_MANAGER:CreateControlFromVirtual("GridBagsToolsTextEdit",bg,"ZO_DefaultEditForBackdrop")
    self.edit:SetAnchor(TOPLEFT,bg,TOPLEFT,8,6);self.edit:SetAnchor(BOTTOMRIGHT,bg,BOTTOMRIGHT,-8,-6)
    self.edit:SetFont("ZoFontGameSmall");self.edit:SetMultiLine(true);self.edit:SetMaxInputChars(200000)
    self.edit:SetMouseEnabled(true);self.edit:SetEditEnabled(true);self.edit:LoseFocus()
    self.edit:SetHandler("OnEscape",function(c)c:LoseFocus()end)
    self.edit:SetHandler("OnTextChanged",function()if self.textMode=="import"then self.importPayload=nil;self.prepared=nil;self.mappings=nil end end)
    UI.MakeButton(self.textWindow,"Select all",20,525,130,function()self.edit:TakeFocus();self.edit:SelectAll()end)
    self.validateButton=UI.MakeButton(self.textWindow,"Preview import",165,525,190,function()self:ImportPreview(true)end)
    self.mapButton=UI.MakeButton(self.textWindow,"Map next character",370,525,225,function(c)self:MapNext(c)end)
    self.applyButton=UI.MakeButton(self.textWindow,"Apply paused configuration",20,575,330,function()
        if not self.prepared or not self.importPayload or self.edit:GetText()~=self.importText then self.textStatus:SetText("Preview the unchanged import and complete character mappings first.");return end
        local result,err=C:Apply(self.importPayload,self.mappings)
        self.textStatus:SetText(result and("Imported "..#result.rules.." rules, disabled/Ask. Transfers remain paused until you review and resume.")or err)
        if result then self.prepared=nil end
    end)
    self.textStatus=UI.MakeLabel(self.textWindow,"",20,625,810,"ZoFontGameSmall");self.textStatus:SetDimensions(810,80)
end
