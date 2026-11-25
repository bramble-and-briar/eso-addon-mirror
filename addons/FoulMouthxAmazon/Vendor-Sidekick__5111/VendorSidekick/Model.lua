VendorSidekick={name="VendorSidekick",version="0.1.2-beta",views={}}
local V=VendorSidekick
local M={};V.Model=M
V.kinds={vendor="Vendor sale",fence="Fence sale",launder="Laundering",buyback="Buyback"}
function M.Clean(text)
 text=text or ""
 if text:find("|H",1,true) and GetItemLinkName then text=GetItemLinkName(text)end
 return zo_strformat("<<1>>",text):gsub("|c%x%x%x%x%x%x",""):gsub("|r","")
end
function M.Init(db)
 db.history=db.history or {};db.characters=db.characters or {};db.keep=db.keep or {};db.nextId=db.nextId or 0
 db.settings=db.settings or {autoSell=true,receipts=true,protectPurple=false}
 if db.settings.autoSell==nil then db.settings.autoSell=true end
 if db.settings.receipts==nil then db.settings.receipts=true end
 return db
end
function M.Add(kind,item,quantity,gold,session,automatic)
 assert(V.kinds[kind],"Invalid transaction kind")
 assert(gold==nil or (type(gold)=="number" and gold>=0),"Invalid receipt amount")
 V.db.nextId=V.db.nextId+1
 local row={id=V.db.nextId,kind=kind,name=M.Clean(item and item.name or "Item details unavailable"),link=item and item.link or "",itemId=item and item.itemId or nil,
  quantity=quantity,gold=gold,time=GetTimeStamp(),clock=GetTimeString(),character=V.characterId,characterName=V.characterName,vendor=session and session.vendor or "Unknown vendor",visit=session and session.id or nil,automatic=automatic==true}
 table.insert(V.db.history,1,row);while #V.db.history>5000 do table.remove(V.db.history)end
 V.ScheduleRender();return row
end
function M.Totals(rows)
 local t={vendor=0,fence=0,launder=0,buyback=0,unknown=0,transactions=0,items=0}
 for _,r in ipairs(rows)do
  t.transactions=t.transactions+1;t.items=t.items+(r.quantity or 0)
  if r.gold~=nil then t[r.kind]=t[r.kind]+r.gold else t.unknown=t.unknown+1 end
 end
 t.net=t.vendor+t.fence-t.launder-t.buyback;return t
end
function M.Filter(kind,character,period,search)
 local out={};local now=GetTimeStamp();local today=GetDateStringFromTimestamp(now);search=(search or ""):lower()
 for _,r in ipairs(V.db.history)do
  local dateOK=period~="Today" or GetDateStringFromTimestamp(r.time)==today
  if period=="7 days" then dateOK=r.time>=now-7*86400 end
  if (not kind or kind=="all" or r.kind==kind) and (not character or character=="all" or r.character==character) and dateOK and (search=="" or (r.name.." "..r.vendor):lower():find(search,1,true))then out[#out+1]=r end
 end;return out
end
function M.Gold(value)return value==nil and "unconfirmed" or tostring(value).."g"end
function M.QueueReceipt(items)
 local rows,byKey={},{};local summary={quantity=0,total=0,lines=0,excluded=0}
 for _,item in ipairs(items)do
  local price=item.price or 0
  local key=(item.link or item.name).."\031"..tostring(price).."\031"..(item.exclusion or "")
  local row=byKey[key]
  if not row then
   row={itemId=item.itemId,name=item.name,link=item.link,quantity=0,price=price,total=0,exclusion=item.exclusion}
   byKey[key]=row;rows[#rows+1]=row
   if not row.exclusion then summary.lines=summary.lines+1 end
  end
  row.quantity=row.quantity+item.quantity;row.total=row.quantity*price
  if not item.exclusion then summary.quantity=summary.quantity+item.quantity;summary.total=summary.total+item.quantity*price
  else summary.excluded=summary.excluded+item.quantity end
 end
 table.sort(rows,function(a,b)
  if (a.exclusion~=nil)~=(b.exclusion~=nil)then return a.exclusion==nil end
  if a.name:lower()~=b.name:lower()then return a.name:lower()<b.name:lower()end
  if a.price~=b.price then return a.price<b.price end
  return (a.exclusion or "")<(b.exclusion or "")
 end)
 return rows,summary
end
function M.Export(rows)
 local out={"Date\tTime\tCharacter\tActivity\tItem\tQuantity\tGold\tVendor\tSource"};local bytes=#out[1]
 local function clean(text)return tostring(text or ""):gsub("[\r\n\t]"," ")end
 for _,r in ipairs(rows)do
  local text=table.concat({clean(GetDateStringFromTimestamp(r.time)),clean(r.clock),clean(r.characterName),V.kinds[r.kind],clean(r.name),tostring(r.quantity or "?"),r.gold==nil and "UNCONFIRMED" or tostring(r.gold),clean(r.vendor),r.automatic and "Vendor Sidekick auto" or "Manual / other addon"},"\t")
  if bytes+#text+1>115000 then out[#out+1]="EXPORT TRUNCATED: narrow your filters to copy the remaining records.";break end
  out[#out+1]=text;bytes=bytes+#text+1
 end
 return table.concat(out,"\n")
end
V.help=[[VENDOR SIDEKICK
Type /vendor or /vsidekick. Extended Journal opens when installed; /vendor window opens the standalone view.

AUTO-SELL ORDINARY JUNK
Mark unwanted items as Junk in ESO. At an ordinary merchant, the addon waits briefly, then runs the whole eligible batch automatically in that one visit. Marking another item as junk while that merchant stays open also queues it. Automation is ON initially because you requested it; change it in Settings or use /vendor off. Sell all ready junk (or /vendor sell) starts a one-off batch or restarts a paused batch without reopening dialogue. It also works when ongoing auto-sale is OFF, and does not change that preference. Pause visit stops the batch. Never run two automatic junk sellers together.

STOLEN GOODS ARE MANUAL ONLY
This addon NEVER automatically sells stolen items and NEVER calls the laundering function. Fences are tracking only. Sell and launder through ESO's normal controls; the ledger records successful transactions. Laundering is an expense. Locked items, stolen items, zero-value items and your keep list are excluded from automatic sales. Purple/gold protection is optional and OFF initially. The keep list matches the base item ID, so it protects other copies of the same item too.

LEDGER
NPC sale and buyback totals come from ESO receipts. Laundering needs a successful result and the specific laundering-money event; if its cost cannot be confirmed, it is shown as unconfirmed and excluded from gold totals. No estimated cost is silently substituted. Some bulk/manual transactions may have an item name but no unambiguous item link. Names and gold still come from the receipt. Unknown item details are labelled.

NET VENDOR FLOW
Vendor sales + fence sales - buybacks - confirmed laundering costs. This is NOT total profit: purchases, repairs, bounties, guild sales, trading, mail, looted gold and crafting costs are excluded. Buying an item back is an expense, not another sale. Historical transactions before installation cannot be recovered.

FILTERS / EXPORT
Filter by activity, character, Today/7 days/All retained, or item/vendor name. Export copies those same filtered records into a selectable text field. Click, Ctrl+A, Ctrl+C. No data is uploaded or automatically posted. Up to 5,000 recent transactions are retained per account and server. Old records drop off, so totals reflect retained history. Other characters appear after you log into them with the addon enabled.

JUNK QUEUE
Preview your junk and excluded items. Keep/Allow changes only this addon's auto-sale rules; it does not lock the item or block you/another addon from selling it manually. Use ESO's item lock for stronger protection. Values here are previews; the ledger uses actual sale receipts.

TESTING
First mark one cheap ordinary item as junk and open a merchant. Confirm its receipt in Ledger. Try one manual sale, one buyback, one fence sale and one laundering transaction. Keep other automatic sellers disabled while testing. If a sale is rejected or times out, the queue pauses rather than repeatedly retrying.

This is an English-interface PC/Mac beta. Native receipt tracking, hook ordering and rendering need in-game validation. Saved data is local. Fixed journal layout has no appearance, color, opacity or sizing controls. Optional libraries must be installed separately.

AI DISCLOSURE
Developed with ChatGPT-assisted code generation. Maintained by FoulMouthxAmazon. ESO assets belong to their owners; this independent addon is not affiliated with ZeniMax Online Studios or Bethesda.]]
