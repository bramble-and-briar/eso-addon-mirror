-- ItemHound 0.8.0. Backpack, bank, Craft Bag and housing storage test; no external libraries.
local NAME = "ItemHound"
local db, character, scanning
local generation = 0
local bankOpen = false
local bankToken = 0
local bankDirty
local ScanBank
local bankTarget, bankBags
local craftToken = 0
local craftDirty
local ScanCraft
local ScanVault, ScanHouse, ShowWindow
local vaultToken, houseToken = 0, 0
local vaultDirty, houseDirty
local currentHouse
local notice = "Ready"
local function Say(message) notice = message end
local function Clean(name) return zo_strformat("<<1>>", name) end
local function ReadSlot(slot, bag)
    bag = bag or BAG_BACKPACK
    local link = GetItemLink(bag, slot)
    if not link or link == "" then return nil end
    local count = GetSlotStackSize(bag, slot)
    if not count or count <= 0 then return nil end
    -- Preserve full item identity in this prototype (different gear/potions stay distinct).
    return {link = link, name = Clean(GetItemLinkName(link)), count = count}
end
local function CurrencyDefinitions()
    return {{id=CURT_MONEY,name="Gold"},{id=CURT_ALLIANCE_POINTS,name="Alliance Points"},{id=CURT_TELVAR_STONES,name="Tel Var"},{id=CURT_WRIT_VOUCHERS,name="Writ Vouchers"}}
end
local function StoreCurrency(currency,location,amount)
    if not character then return end
    local record={amount=amount,updatedAt=GetTimeStamp()}
    if location==CURRENCY_LOCATION_CHARACTER then
        character.wallet=character.wallet or {};character.wallet[currency]=record
    elseif location==CURRENCY_LOCATION_BANK or location==CURRENCY_LOCATION_ACCOUNT then
        db.wallet.shared[currency]=db.wallet.shared[currency] or {};db.wallet.shared[currency][location]=record
    end
end
local function ScanWallet()
    if not character then return end
    for _,currency in ipairs(CurrencyDefinitions()) do
        local location=GetCurrencyPlayerStoredLocation(currency.id)
        StoreCurrency(currency.id,location,GetCurrencyAmount(currency.id,location))
        if location~=CURRENCY_LOCATION_BANK and CanCurrencyBeStoredInLocation(currency.id,CURRENCY_LOCATION_BANK) then
            StoreCurrency(currency.id,CURRENCY_LOCATION_BANK,GetCurrencyAmount(currency.id,CURRENCY_LOCATION_BANK))
        end
    end
end
local function CurrencyChanged(_,currency,location,amount)
    for _,c in ipairs(CurrencyDefinitions())do if c.id==currency then StoreCurrency(currency,location,amount);return end end
end
local function ScanWorn()
    if not character then return end
    local c=character.worn or {id="worn:"..character.id,slots={}}
    c.name=character.name .. " (equipped)"
    local slots={}
    for slot=0,GetBagSize(BAG_WORN)-1 do slots[slot]=ReadSlot(slot,BAG_WORN)end
    c.slots=slots;c.scannedAt=GetTimeStamp();c.updatedAt=c.scannedAt;character.worn=c
end
local function FormatAmount(n)return ZO_CommaDelimitNumber(n or 0)end
local function WalletResults(query)
    query=string.lower(query or ""):match("^%s*(.-)%s*$")
    local rows,panels={},{}
    local scanned,known=0,0
    for _,c in pairs(db.characters)do known=known+1;if c.wallet then scanned=scanned+1 end end
    for _,currency in ipairs(CurrencyDefinitions())do
        local locations,total={},0
        for _,c in pairs(db.characters)do
            local record=c.wallet and c.wallet[currency.id]
            if record then locations[#locations+1]={name=c.name,amount=record.amount,updatedAt=record.updatedAt};total=total+record.amount end
        end
        for location,record in pairs(db.wallet.shared[currency.id]or{})do
            locations[#locations+1]={name=location==CURRENCY_LOCATION_BANK and "Bank" or "Account (shared)",amount=record.amount,updatedAt=record.updatedAt}
            total=total+record.amount
        end
        table.sort(locations,function(a,b)if a.amount==b.amount then return a.name<b.name end;return a.amount>b.amount end)
        local currencyMatches=string.find(string.lower(currency.name),query,1,true) or (currency.id==CURT_ALLIANCE_POINTS and query=="ap")
        local panel={title=currency.name .. " | Total " .. FormatAmount(total),locations={}}
        panels[currency.id]=panel
        if query=="" or currencyMatches then
            rows[#rows+1]={title=currency.name .. " | Total " .. FormatAmount(total),detail="Recorded character balances + shared balances counted once."}
        end
        for _,loc in ipairs(locations)do
            if loc.amount>0 and (query=="" or currencyMatches or string.find(string.lower(loc.name),query,1,true)) then panel.locations[#panel.locations+1]=loc end
            if query=="" or currencyMatches or string.find(string.lower(loc.name),query,1,true)then
                rows[#rows+1]={title=currency.name .. " | " .. loc.name .. ": " .. FormatAmount(loc.amount),detail="Updated " .. math.floor(math.max(0,GetTimeStamp()-(loc.updatedAt or 0))/60) .. " min ago"}
            end
        end
    end
    for _,c in pairs(db.characters)do
        if not c.wallet and(query=="" or string.find(string.lower(c.name),query,1,true))then rows[#rows+1]={title=c.name .. " | Wallet not scanned",detail="Log into this character once with 0.8.0 installed."}end
    end
    return rows,"Wallet: " .. scanned .. "/" .. known .. " recorded characters scanned. Filter by currency or character.\nLast-known balances; visit every toon once. Largest holders first; zero balances hidden.",panels
end

local function Counts(slots)
    local used, quantity = 0, 0
    for _, item in pairs(slots) do used = used + 1; quantity = quantity + item.count end
    return used, quantity
end
local function Scan()
    if not character then Say("Not ready yet."); return end
    generation = generation + 1
    local token = generation
    local slots, dirty = {}, {}
    local nextSlot, size = 0, GetBagSize(BAG_BACKPACK)
    scanning = dirty
    local function Step()
        if token ~= generation then return end
        local stop = math.min(nextSlot + 20, size)
        for slot = nextSlot, stop - 1 do slots[slot] = ReadSlot(slot) end
        nextSlot = stop
        if nextSlot < size then zo_callLater(Step, 20); return end
        -- Replay changes received while the chunked snapshot was being built.
        for slot in pairs(dirty) do slots[slot] = ReadSlot(slot) end
        character.slots = slots
        character.scannedAt = GetTimeStamp()
        character.updatedAt = character.scannedAt
        scanning = nil
        local used, quantity = Counts(slots)
        Say("0.8.0 scanned " .. character.name .. ": " .. used .. " backpack slots, " .. quantity .. " items. Type /ih find sandcastle")
    end
    Step()
end
local function Changed(_, bag, slot)
    if bag==BAG_WORN and character then
        if not character.worn then ScanWorn() else
            character.worn.slots[slot]=ReadSlot(slot,BAG_WORN);character.worn.updatedAt=GetTimeStamp()
        end
        return
    end
    if BAG_FURNITURE_VAULT and bag == BAG_FURNITURE_VAULT then
        if vaultDirty then vaultDirty[slot] = true
        elseif db.vault.scannedAt then db.vault.slots[slot] = ReadSlot(slot, bag); db.vault.updatedAt = GetTimeStamp() end
        return
    end
    if bag == BAG_VIRTUAL then
        if craftDirty then craftDirty[slot] = true
        elseif db.craft.scannedAt then
            db.craft.slots[slot] = ReadSlot(slot, bag)
            db.craft.updatedAt = GetTimeStamp()
        end
        return
    end
    if bankOpen and bankBags and (bag == bankBags[1] or bag == bankBags[2]) then
        if bankDirty then bankDirty[bag .. ":" .. slot] = {bag, slot}
        elseif bankTarget.scannedAt then
            bankTarget.slots[bag .. ":" .. slot] = ReadSlot(slot, bag)
            bankTarget.updatedAt = GetTimeStamp()
        end
        return
    end
    if bag ~= BAG_BACKPACK or not character then return end
    if scanning then scanning[slot] = true; return end
    if not character.scannedAt then return end
    character.slots[slot] = ReadSlot(slot)
    character.updatedAt = GetTimeStamp()
end
local function CloseBank()
    bankOpen = false
    bankToken = bankToken + 1
    bankDirty = nil
    bankTarget, bankBags = nil, nil
end
ScanBank = function()
    if not bankOpen then Say("Open your personal bank or a storage chest/coffer first."); return end
    bankToken = bankToken + 1
    local token = bankToken
    local slots, dirty = {}, {}
    bankDirty = dirty
    local bags, target = bankBags, bankTarget
    local index, nextSlot = 1, 0
    local function Step()
        if not bankOpen or token ~= bankToken then return end
        local bag = bags[index]
        local size = GetBagSize(bag)
        local stop = math.min(nextSlot + 20, size)
        for slot = nextSlot, stop - 1 do slots[bag .. ":" .. slot] = ReadSlot(slot, bag) end
        nextSlot = stop
        if nextSlot >= size then index = index + 1; nextSlot = 0 end
        if index <= #bags then zo_callLater(Step, 20); return end
        for key, pos in pairs(dirty) do slots[key] = ReadSlot(pos[2], pos[1]) end
        target.slots = slots
        target.scannedAt = GetTimeStamp()
        target.updatedAt = target.scannedAt
        bankDirty = nil
        local used, quantity = Counts(slots)
        Say(target.name .. " scanned: " .. used .. " occupied slots, " .. quantity .. " items.")
    end
    Step()
end
local function StorageName(c)
    local name = GetCollectibleNickname(c.collectibleId)
    if not name or name == "" then name = GetCollectibleName(c.collectibleId) end
    c.name = Clean(name or ("Storage " .. c.collectibleId))
end
local function OpenBank()
    CloseBank()
    local bag = GetBankingBag()
    if bag == BAG_BANK then
        bankTarget, bankBags = db.bank, {BAG_BANK}
        if BAG_SUBSCRIBER_BANK then bankBags[2] = BAG_SUBSCRIBER_BANK end
    elseif BAG_FURNITURE_VAULT and bag == BAG_FURNITURE_VAULT then ScanVault(); return
    elseif IsHouseBankBag(bag) then
        local getCollectible = GetCollectibleForBag or GetCollectibleForHouseBankBag
        local collectibleId = getCollectible(bag)
        if not collectibleId or collectibleId == 0 then Say("Cannot identify this storage container."); return end
        local key = tostring(collectibleId)
        local c = db.storage[key]
        if not c then
            c = {id = "storage:" .. key, collectibleId = collectibleId, slots = {}}
            db.storage[key] = c
        end
        StorageName(c)
        bankTarget, bankBags = c, {bag}
    else return end
    bankOpen = true
    ScanBank()
end
ScanCraft = function()
    craftToken = craftToken + 1
    local token = craftToken
    local slots, dirty = {}, {}
    craftDirty = dirty
    local cursor = nil
    local function Step()
        if token ~= craftToken then return end
        for i = 1, 20 do
            cursor = GetNextVirtualBagSlotId(cursor)
            if cursor == nil then
                for slot in pairs(dirty) do slots[slot] = ReadSlot(slot, BAG_VIRTUAL) end
                db.craft.slots = slots
                db.craft.scannedAt = GetTimeStamp()
                db.craft.updatedAt = db.craft.scannedAt
                craftDirty = nil
                local used, quantity = Counts(slots)
                Say("Craft Bag scanned: " .. used .. " material stacks, " .. quantity .. " items.")
                return
            end
            slots[cursor] = ReadSlot(cursor, BAG_VIRTUAL)
        end
        zo_callLater(Step, 20)
    end
    Step()
end
local function Sources()
    local sources = {db.bank, db.craft, db.vault}
    for _, c in pairs(db.characters) do sources[#sources + 1] = c;if c.worn then sources[#sources+1]=c.worn end end
    local nameCounts = {}
    for _, c in pairs(db.storage) do StorageName(c); nameCounts[c.name] = (nameCounts[c.name] or 0) + 1 end
    for _, c in pairs(db.storage) do
        c.displayName = c.name .. (nameCounts[c.name] > 1 and (" [" .. GetCollectibleName(c.collectibleId) .. "]") or "")
        sources[#sources + 1] = c
    end
    for _, c in pairs(db.houses) do sources[#sources + 1] = c end
    return sources
end
local function Results(query)
    query = string.lower(query or ""):match("^%s*(.-)%s*$")
    local rows = {}
    if query == "" then
        for _, c in ipairs(Sources()) do
            local used, quantity = Counts(c.slots or {})
            rows[#rows + 1] = {title = c.displayName or c.name, detail = c.scannedAt and (used .. " slots / " .. quantity .. " items | cached " .. math.floor(math.max(0, GetTimeStamp() - (c.updatedAt or c.scannedAt)) / 60) .. " min ago") or "Not scanned yet"}
        end
        table.sort(rows, function(a,b) return a.title < b.title end)
        return rows, "Scan dashboard: visit characters and houses; open each storage container.\n" .. notice
    end
    local matches = {}
    for _, c in ipairs(Sources()) do
        for _, item in pairs(c.slots or {}) do
            if string.find(string.lower(item.name), query, 1, true) then
                local m = matches[item.link]
                if not m then m = {name=item.name, total=0, locations={}}; matches[item.link]=m end
                m.total=m.total+item.count
                local loc=m.locations[c.id]
                if not loc then loc={name=c.displayName or c.name,count=0,updated=c.updatedAt};m.locations[c.id]=loc end
                loc.count=loc.count+item.count
            end
        end
    end
    local sorted = {}
    for link, m in pairs(matches) do m.link=link;sorted[#sorted+1]=m end
    table.sort(sorted,function(a,b) if a.name==b.name then return a.link<b.link end;return a.name<b.name end)
    local locationCount=0
    for _,m in ipairs(sorted)do
        local locations={}
        for _,loc in pairs(m.locations)do locations[#locations+1]=loc end
        table.sort(locations,function(a,b)return a.name<b.name end)
        locationCount=locationCount+#locations
        local icon,quality,metadata
        if string.find(m.link,"|H",1,true) and not string.find(m.link,"collectible:",1,true) then
            icon=GetItemLinkIcon(m.link)
            quality=GetItemLinkDisplayQuality(m.link)
            local kind=GetItemLinkItemType(m.link)
            if kind==ITEMTYPE_ARMOR or kind==ITEMTYPE_WEAPON then
                local trait=GetItemLinkTraitInfo(m.link)
                local _,enchant=GetItemLinkEnchantInfo(m.link)
                metadata=GetString("SI_ITEMDISPLAYQUALITY",quality)
                if trait and trait~=ITEM_TRAIT_TYPE_NONE then metadata=metadata .. " / " .. GetString("SI_ITEMTRAITTYPE",trait) end
                if enchant and enchant~="" then metadata=metadata .. " / " .. Clean(enchant) end
            end
        end
        for first=1,#locations,2 do
            local lines={}
            for j=first,math.min(first+1,#locations)do
                local loc=locations[j]
                lines[#lines+1]=loc.name .. " x" .. FormatAmount(loc.count) .. "  |  " .. math.floor(math.max(0,GetTimeStamp()-(loc.updated or 0))/60) .. " min ago"
            end
            rows[#rows+1]={title=m.name .. (first==1 and ("  |  Total " .. FormatAmount(m.total)) or "  (locations continued)"),
                detail=table.concat(lines,"\n"),meta=metadata or "",icon=icon,quality=quality}
        end
    end
    return rows,#sorted .. " item variants / " .. locationCount .. " locations | Last-known contents, including equipped gear."

end
ScanVault = function()
    if not BAG_FURNITURE_VAULT or not GetNextFurnitureVaultSlotId then Say("Furnishing Vault API unavailable."); return end
    if GetFurnitureVaultCollectibleId and not IsCollectibleUnlocked(GetFurnitureVaultCollectibleId()) then Say("Furnishing Vault not unlocked."); return end
    vaultToken=vaultToken+1
    local token=vaultToken
    local slots,dirty={},{}
    vaultDirty=dirty
    local cursor
    local function Step()
        if token~=vaultToken then return end
        for i=1,20 do
            cursor=GetNextFurnitureVaultSlotId(cursor)
            if cursor==nil then
                for slot in pairs(dirty) do slots[slot]=ReadSlot(slot,BAG_FURNITURE_VAULT) end
                db.vault.slots=slots;db.vault.scannedAt=GetTimeStamp();db.vault.updatedAt=db.vault.scannedAt;vaultDirty=nil
                Say("Furnishing Vault scanned.");return
            end
            slots[cursor]=ReadSlot(cursor,BAG_FURNITURE_VAULT)
        end
        zo_callLater(Step,20)
    end
    Step()
end
local function ReadFurniture(id)
    local itemLink,collectibleLink=GetPlacedFurnitureLink(id)
    local link=(itemLink and itemLink~="") and itemLink or collectibleLink
    if not link or link=="" then return nil end
    local name=GetPlacedHousingFurnitureInfo(id)
    if not name or name=="" then return nil end
    return {link=link,name=Clean(name),count=1}
end
local function FurnitureKey(id) return zo_getSafeId64Key(id) end
ScanHouse = function()
    local houseId=GetCurrentZoneHouseId()
    if houseId==0 or not IsOwnerOfCurrentHouse() then currentHouse=nil;return end
    local key=tostring(houseId)
    local c=db.houses[key]
    if not c then c={id="house:" .. key,slots={}};db.houses[key]=c end
    local collectibleId=GetCollectibleIdForHouse(houseId)
    local nickname=GetCollectibleNickname(collectibleId)
    c.name="House: " .. Clean(nickname~="" and nickname or GetCollectibleName(collectibleId)) .. " (placed)"
    currentHouse=c
    houseToken=houseToken+1
    local token=houseToken
    local slots,dirty={},{}
    houseDirty=dirty
    local cursor
    local function Step()
        if token~=houseToken or GetCurrentZoneHouseId()~=houseId or not IsOwnerOfCurrentHouse() then return end
        for i=1,20 do
            cursor=GetNextPlacedHousingFurnitureId(cursor)
            if cursor==nil then
                for k,id in pairs(dirty) do slots[k]=ReadFurniture(id) end
                c.slots=slots;c.scannedAt=GetTimeStamp();c.updatedAt=c.scannedAt;houseDirty=nil
                Say(c.name .. " scanned.");return
            end
            slots[FurnitureKey(cursor)]=ReadFurniture(cursor)
        end
        zo_callLater(Step,20)
    end
    Step()
end
local function FurnitureChanged(_,id)
    if not currentHouse or not IsOwnerOfCurrentHouse() then return end
    local key=FurnitureKey(id)
    if houseDirty then houseDirty[key]=id
    elseif currentHouse.scannedAt then currentHouse.slots[key]=ReadFurniture(id);currentHouse.updatedAt=GetTimeStamp() end
end
local ui
local function CreateWindow()
    if ui then return end
    local wm=WINDOW_MANAGER
    local window=wm:CreateTopLevelWindow("ItemHoundWindow")
    window:SetDimensions(1120,820)
    local screenWidth,screenHeight=GuiRoot:GetDimensions()
    window:SetScale(math.min(1,screenWidth/1180,screenHeight/900))
    window:SetAnchor(CENTER,GuiRoot,CENTER,0,0);window:SetHidden(true)
    window:SetMouseEnabled(true)
    local background=wm:CreateControl(nil,window,CT_BACKDROP)
    background:SetAnchorFill();background:SetCenterColor(0.012,0.012,0.018,1);background:SetEdgeColor(0.38,0.07,0.065,1)
    local function Label(y,height,font)
        local c=wm:CreateControl(nil,window,CT_LABEL)
        c:SetAnchor(TOPLEFT,window,TOPLEFT,35,y);c:SetDimensions(1050,height);c:SetFont(font);return c
    end
    local heading=Label(20,45,"ZoFontGamepad34");heading:SetText("ItemHound");heading:SetColor(0.88,0.88,0.9,1)
    local editBackground=wm:CreateControl(nil,window,CT_BACKDROP)
    editBackground:SetAnchor(TOPLEFT,window,TOPLEFT,35,80);editBackground:SetDimensions(1050,48)
    editBackground:SetCenterColor(0.055,0.055,0.065,1);editBackground:SetEdgeColor(0.22,0.22,0.25,1)
    local template=IsInGamepadPreferredMode() and "ZO_DefaultEditForBackdrop_Gamepad" or "ZO_DefaultEditForBackdrop"
    local edit=wm:CreateControlFromVirtual("ItemHoundSearch",editBackground,template)
    edit:ClearAnchors()
    edit:SetAnchor(TOPLEFT,editBackground,TOPLEFT,12,5);edit:SetDimensions(1025,38);edit:SetMaxInputChars(100)
    local summary=Label(142,55,"ZoFontGamepad22")
    local controls={}
    for i=1,4 do
        local y=205+(i-1)*120
        local card=wm:CreateControl(nil,window,CT_BACKDROP)
        card:SetAnchor(TOPLEFT,window,TOPLEFT,25,y-4);card:SetDimensions(1070,114)
        card:SetCenterColor(0.033,0.033,0.042,1);card:SetEdgeColor(0.07,0.07,0.085,1)
        local icon=wm:CreateControl(nil,window,CT_TEXTURE)
        icon:SetAnchor(TOPLEFT,window,TOPLEFT,38,y+6);icon:SetDimensions(36,36)
        local title=Label(y,32,"ZoFontGamepad27");title:ClearAnchors();title:SetAnchor(TOPLEFT,window,TOPLEFT,85,y);title:SetDimensions(1000,32)
        local meta=Label(y+31,25,"ZoFontGamepad22");meta:SetColor(0.58,0.58,0.63,1)
        local detail=Label(y+57,54,"ZoFontGamepad22");detail:SetColor(0.78,0.78,0.81,1)
        controls[i]={title=title,detail=detail,meta=meta,icon=icon,card=card}
    end
    local walletControls={}
    local order={CURT_MONEY,CURT_TELVAR_STONES,CURT_ALLIANCE_POINTS,CURT_WRIT_VOUCHERS}
    for i,currency in ipairs(order) do
        local x=25+((i-1)%2)*545
        local y=201+math.floor((i-1)/2)*245
        local card=wm:CreateControl(nil,window,CT_BACKDROP)
        card:SetAnchor(TOPLEFT,window,TOPLEFT,x,y);card:SetDimensions(525,235)
        card:SetCenterColor(0.033,0.033,0.042,1);card:SetEdgeColor(0.16,0.06,0.065,1)
        local title=wm:CreateControl(nil,card,CT_LABEL)
        title:SetAnchor(TOPLEFT,card,TOPLEFT,12,7);title:SetDimensions(501,30);title:SetFont("ZoFontGamepad25");title:SetColor(0.85,0.3,0.28,1)
        local lines={}
        for j=1,24 do
            local label=wm:CreateControl(nil,card,CT_LABEL)
            label:SetFont("ZoFontGamepad18");label:SetMaxLineCount(1);label:SetColor(0.78,0.78,0.81,1)
            lines[j]=label
        end
        walletControls[i]={card=card,title=title,lines=lines,currency=currency}
    end
    local footer=Label(701,32,"ZoFontGamepad22");footer:SetColor(0.6,0.6,0.65,1)
    local credit=Label(750,32,"ZoFontGamepad22");credit:SetText("by @TheGreyWolf98");credit:SetColor(0.57,0.24,0.23,1)
    ui={tab="items",window=window,edit=edit,summary=summary,controls=controls,footer=footer,page=1,rows={},epoch=0}
    local function Render()
        local wallet=ui.tab=="wallet"
        if ui.pageButtons then for _,button in ipairs(ui.pageButtons)do button:SetHidden(wallet)end end
        local pages=wallet and 1 or math.max(1,math.ceil(#ui.rows/4))
        if ui.tabButtons then ui.tabButtons.items:SetText(ui.tab=="items" and "[Items]" or "Items");ui.tabButtons.wallet:SetText(ui.tab=="wallet" and "[Wallet]" or "Wallet");ui.tabButtons.items:SetNormalFontColor(ui.tab=="items" and 0.85 or 0.55,ui.tab=="items" and 0.3 or 0.55,ui.tab=="items" and 0.28 or 0.58,1);ui.tabButtons.wallet:SetNormalFontColor(ui.tab=="wallet" and 0.85 or 0.55,ui.tab=="wallet" and 0.3 or 0.55,ui.tab=="wallet" and 0.28 or 0.58,1) end
        ui.page=math.max(1,math.min(ui.page,pages))
        for i,c in ipairs(controls) do
            local r=not wallet and ui.rows[(ui.page-1)*4+i]
            c.title:SetText(r and r.title or (not wallet and i==1 and #ui.rows==0 and "No matches in scanned locations." or ""))
            c.detail:SetText(r and r.detail or "")
            c.meta:SetText(r and r.meta or "")
            c.icon:SetHidden(not (r and r.icon and r.icon~=""))
            if r and r.icon then c.icon:SetTexture(r.icon)end
            c.title:SetColor(0.88,0.88,0.9,1)
            if r and r.quality then c.title:SetColor(GetItemQualityColor(r.quality):UnpackRGBA())end
            c.card:SetHidden(wallet or (not r and not(i==1 and #ui.rows==0)))
        end
        for _,c in ipairs(walletControls) do
            c.card:SetHidden(not wallet)
            local panel=ui.panels and ui.panels[c.currency]
            c.title:SetText(wallet and panel and panel.title or "")
            local locations=panel and panel.locations or {}
            local count=#locations
            local perColumn=math.max(1,math.ceil(count/2))
            local spacing=math.min(22,190/perColumn)
            for j,label in ipairs(c.lines) do
                local loc=wallet and locations[j]
                label:ClearAnchors()
                label:SetAnchor(TOPLEFT,c.card,TOPLEFT,12+math.floor((j-1)/perColumn)*253,42+((j-1)%perColumn)*spacing)
                label:SetDimensions(247,22)
                label:SetText(loc and (loc.name .. ": " .. FormatAmount(loc.amount)) or (wallet and j==1 and count==0 and "No matching balances." or ""))
            end
        end
        footer:SetText(wallet and "LB/RB: Items / Wallet    |    Search: currency or character    |    Shared balances counted once" or "Page " .. ui.page .. " / " .. pages .. "    |    LB/RB: Items / Wallet    |    Empty item search: scan dashboard")
    end
    ui.render=Render
    ui.refresh=function()
        if ui.tab=="wallet" then ui.rows,ui.description,ui.panels=WalletResults(edit:GetText()) else ui.rows,ui.description=Results(edit:GetText()) end
        summary:SetText(ui.description);Render()
    end
    ui.setTab=function(tab)
        ui.tab=tab;ui.page=1;edit:SetText("");ui.refresh()
    end
    local tabButtons={}
    local function TabButton(name,x,tab)
        local button=wm:CreateControl(nil,window,CT_BUTTON)
        button:SetAnchor(TOPLEFT,window,TOPLEFT,x,24);button:SetDimensions(130,38);button:SetFont("ZoFontGamepad22")
        button:SetText(name);button:SetMouseEnabled(true);button:SetHandler("OnClicked",function()ui.setTab(tab)end)
        tabButtons[tab]=button
    end
    TabButton("Items",370,"items");TabButton("Wallet",505,"wallet")
    ui.tabButtons=tabButtons
    local keys={alignment=KEYBIND_STRIP_ALIGN_CENTER,
        {name="Search",keybind="UI_SHORTCUT_SECONDARY",callback=function() edit:TakeFocus() end},
        {name="Refresh",keybind="UI_SHORTCUT_TERTIARY",callback=function() ui.refresh() end},
        {name="Previous",keybind="UI_SHORTCUT_LEFT_TRIGGER",callback=function() ui.page=ui.page-1;Render() end},
        {name="Next",keybind="UI_SHORTCUT_RIGHT_TRIGGER",callback=function() ui.page=ui.page+1;Render() end},
        {name="Close",keybind="UI_SHORTCUT_NEGATIVE",callback=function() SCENE_MANAGER:Hide("itemhound") end},
        {name="Items",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function()ui.setTab("items")end},
        {name="Wallet",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=function()ui.setTab("wallet")end},
    }
    local scene=ZO_Scene:New("itemhound",SCENE_MANAGER)
    scene:AddFragment(ZO_FadeSceneFragment:New(window))
    scene:AddFragmentGroup(IsInGamepadPreferredMode() and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    scene:RegisterCallback("StateChange",function(_,state)
        if state==SCENE_SHOWN then KEYBIND_STRIP:AddKeybindButtonGroup(keys)
        elseif state==SCENE_HIDING then edit:LoseFocus();KEYBIND_STRIP:RemoveKeybindButtonGroup(keys) end
    end)
    edit:SetHandler("OnTextChanged",function()
        ui.epoch=ui.epoch+1;local epoch=ui.epoch
        zo_callLater(function() if epoch==ui.epoch then ui.page=1;ui.refresh() end end,200)
    end)
    edit:SetHandler("OnEnter",function() edit:LoseFocus();ui.refresh() end)
    -- Mouse controls also make the prototype usable in keyboard mode.
    ui.pageButtons={}
    for i,entry in ipairs({{"Previous",function()ui.page=ui.page-1;Render()end},{"Next",function()ui.page=ui.page+1;Render()end},{"Close",function()SCENE_MANAGER:Hide("itemhound")end}}) do
        local button=wm:CreateControl(nil,window,CT_BUTTON)
        button:SetAnchor(TOPLEFT,window,TOPLEFT,690+(i-1)*125,22);button:SetDimensions(120,38)
        if i<3 then ui.pageButtons[#ui.pageButtons+1]=button end
        button:SetFont("ZoFontGamepad22");button:SetText(entry[1]);button:SetMouseEnabled(true);button:SetHandler("OnClicked",entry[2])
    end
end
ShowWindow=function(query,tab)
    CreateWindow();ui.tab=tab or "items";ui.page=1;ui.edit:SetText(query or "");ui.refresh();SCENE_MANAGER:Show("itemhound")
end

local function Command(text)
    if not db then Say("Not ready yet."); return end
    text = text:match("^%s*(.-)%s*$")
    local cmd, rest = text:match("^(%S+)%s*(.*)$")
    cmd = string.lower(cmd or "")
    if cmd == "bank" then ScanBank()
    elseif cmd == "craft" then ScanCraft()
    elseif cmd == "vault" then ScanVault()
    elseif cmd == "house" then ScanHouse()
    elseif cmd == "scan" then Scan(); ScanWorn(); ScanWallet(); ScanCraft(); ScanVault(); ScanHouse()
    elseif cmd == "wallet" then ScanWallet();ShowWindow(rest,"wallet")
    elseif cmd == "status" then ShowWindow("")
    elseif cmd == "find" then ShowWindow(rest)
    else ShowWindow(text) end
end
local function Activated()
    local id = tostring(GetCurrentCharacterId())
    character = db.characters[id]
    if not character then character = {id = id, slots = {}}; db.characters[id] = character end
    character.name = Clean(GetUnitName("player"))
    Scan()
    ScanWorn()
    ScanWallet()
    ScanCraft()
    ScanVault()
    local token=houseToken
    zo_callLater(function() if token==houseToken and character then ScanHouse() end end,250)
end
local function Deactivated()
    CloseBank()
    vaultToken=vaultToken+1;vaultDirty=nil
    houseToken=houseToken+1;houseDirty=nil;currentHouse=nil
    if SCENE_MANAGER:IsShowing("itemhound") then SCENE_MANAGER:Hide("itemhound") end
    craftToken = craftToken + 1
    craftDirty = nil
    generation = generation + 1
    scanning = nil
    character = nil
end
local function Loaded(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    db = ZO_SavedVars:NewAccountWide("ItemHoundSavedVariables", 1, GetWorldName(), {characters = {}})
    db.bank = db.bank or {slots = {}}
    db.bank.id = "shared:bank"
    db.bank.name = "Bank"
    db.craft = db.craft or {slots = {}}
    db.craft.id, db.craft.name = "shared:craft", "Craft Bag"
    db.storage = db.storage or {}
    db.vault=db.vault or {id="shared:vault",name="Furnishing Vault",slots={}}
    db.houses=db.houses or {}
    db.wallet=db.wallet or {shared={}}
    SLASH_COMMANDS["/ih"] = Command
    SLASH_COMMANDS["/itemhound"] = Command
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CURRENCY_UPDATE, CurrencyChanged)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_HOUSING_FURNITURE_PLACED, FurnitureChanged)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_HOUSING_FURNITURE_REMOVED, FurnitureChanged)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_OPEN_BANK, OpenBank)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CLOSE_BANK, CloseBank)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, Activated)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, Deactivated)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, Changed)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_INVENTORY_FULL_UPDATE, function(_, bag)
        if bag==BAG_WORN and character then ScanWorn()
        elseif bag == BAG_BACKPACK and character then Scan()
        elseif BAG_FURNITURE_VAULT and bag == BAG_FURNITURE_VAULT then ScanVault()
        elseif bag == BAG_VIRTUAL then ScanCraft()
        elseif bankOpen and bankBags and (bag == bankBags[1] or bag == bankBags[2]) then ScanBank() end
    end)
end
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Loaded)
