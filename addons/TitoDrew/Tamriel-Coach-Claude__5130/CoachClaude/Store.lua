-- Coach Claude: store actions (v1.7).
-- When you open a guild store, approved buy tasks for that guild are searched and bought,
-- but only inside your rules (Settings). Anything outside them becomes a decision row:
-- left-click buys, right-click skips. Dry run (on by default) logs what it would buy and spends nothing.
-- Only the store you are standing at is searched, and only after you open it.

local CC = CoachClaude
local S = {}
CC.Store = S

S.DEFAULTS = { tol = 5, cap = 20000, keep = 0, close = 10, avgStop = true, onOpen = true, autoBuy = true, confirmEach = false, dry = true, others = true }
S.STEPS = {
  tol  = { 0, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000 },
  cap  = { 0, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000 },
  keep = { 0, 1000, 5000, 10000, 20000, 50000, 100000, 200000 },
  close = { 0, 5, 10, 15, 20, 25, 50 },
}
local TIMEOUT_MS = 12000
local ASK_TIMEOUT_MS = 120000   -- time you have to answer ESO's confirm box when "confirm each automatic buy" is on
local COL = { ok = "66CC66", dry = "9FC5E8", bad = "E06666", warn = "E8C15A", good = "7FD3A0", note = "A0A0A0", head = "5AC8FA" }

local function col(h, s) return "|c" .. h .. tostring(s) .. "|r" end
local function norm(s) return (tostring(s or ""):lower():gsub("[^%w]", "")) end
local function g(n) return ZO_CommaDelimitNumber(math.floor((n or 0) + 0.5)) .. "g" end
local function rules() return CC.sv.rules end
local function plan() return CoachClaude_Tasks and CoachClaude_Tasks.generated or "" end

S.run = { lines = {}, decisions = {}, spent = 0, dryBought = {} }

---------------------------------------------------------------------------
-- tasks
---------------------------------------------------------------------------
-- a task the store can act on: a buy with an item, quantity, target unit price, in a group naming a guild
function S.Actionable(t, grp)
  return t.kind == "buy" and t.item and t.qty and t.price and grp and grp.guild and true or false
end

local function bought(t)
  local n = 0
  for _, b in ipairs(CC.sv.buys) do
    if b.id == t.id and not b.dry and b.plan == plan() then n = n + b.qty end
  end
  return n
end

function S.Remaining(t)
  return math.max(0, t.qty - bought(t) - (S.run.dryBought[t.id] or 0))
end

local function approvedTasks(guildNorm)
  local here, other = {}, {}
  for _, grp in ipairs(CC.groups()) do
    for _, t in ipairs(grp.tasks or {}) do
      if S.Actionable(t, grp) and CC.stateOfTask(t) == "approved" and S.Remaining(t) > 0 then
        if norm(grp.guild) == guildNorm then here[#here + 1] = t
        else other[#other + 1] = { t = t, other = true, guild = grp.guild } end
      end
    end
  end
  return here, other
end

function S.ApprovedHere()
  if not (CC.atStore and S.run.guildNorm) then return 0 end
  local here = approvedTasks(S.run.guildNorm)
  return #here
end

---------------------------------------------------------------------------
-- log lines shown in the STORE block
---------------------------------------------------------------------------
local function line(text, tip)
  local l = S.run.lines
  l[#l + 1] = { text = text, tip = tip }
  while #l > 12 do table.remove(l, 1) end
  CC.Refresh()
end

-- decisions offered and what you did with them, for your coach
local function note(o, action)
  local log = CC.sv.decisions
  log[#log + 1] = { id = o.t.id, item = o.t.item, kind = o.kind, total = o.total, units = o.units,
                    action = action, dry = rules().dry or nil, guild = S.run.guild, plan = plan(), t = GetTimeStamp() }
  while #log > 300 do table.remove(log, 1) end
end
S.Note = note

local function record(t, r, how)
  local dry = rules().dry
  local e = { id = t.id, item = t.item, qty = r.stack, total = r.price, unit = r.price / r.stack,
              guild = S.run.guild, seller = r.seller, how = how, dry = dry or nil, plan = plan(), t = GetTimeStamp() }
  local buys = CC.sv.buys
  buys[#buys + 1] = e
  while #buys > 300 do table.remove(buys, 1) end
  S.run.spent = S.run.spent + r.price
  if dry then S.run.dryBought[t.id] = (S.run.dryBought[t.id] or 0) + r.stack end
  -- decisions for a task that is now covered are no longer needed
  if S.Remaining(t) == 0 then
    for k = #S.run.decisions, 1, -1 do if S.run.decisions[k].t == t then table.remove(S.run.decisions, k) end end
  end
  local verb = dry and col(COL.dry, "DRY RUN - would buy ") or col(COL.ok, "Bought ")
  line(verb .. t.item .. " x" .. r.stack .. " @ " .. g(r.price / r.stack) .. " = " .. g(r.price) ..
       col(COL.note, "  (" .. how .. ", visit total " .. g(S.run.spent) .. ")"))
  if not dry and S.Remaining(t) == 0 then CC.SetTaskState(t, "done", t.qty) end
end

---------------------------------------------------------------------------
-- money rules
---------------------------------------------------------------------------
function S.Affordable(total)
  local R = rules()
  local wallet = GetCurrentMoney() - (R.dry and S.run.spent or 0)
  if total > wallet then return false, "not enough gold (" .. g(wallet) .. " on you)" end
  if R.keep > 0 and wallet - total < R.keep then
    return false, "would leave " .. g(wallet - total) .. ", your keep-at-least is " .. g(R.keep)
  end
  if R.cap > 0 and S.run.spent + total > R.cap then
    return false, "visit cap: " .. g(S.run.spent) .. " spent + " .. g(total) .. " > " .. g(R.cap)
  end
  return true
end

-- per-item ceiling: target + tolerance, never above the sale average when that rule is on
function S.Ceiling(t)
  local R = rules()
  local c, why = t.price + R.tol, "target " .. g(t.price) .. " + " .. g(R.tol) .. " tolerance"
  if R.avgStop and t.avg and t.avg < c then c, why = t.avg, "sale average " .. g(t.avg) .. " (never-above-average rule)" end
  return c, why
end

---------------------------------------------------------------------------
-- evaluation: one auto buy, or decision options with the math
---------------------------------------------------------------------------
local function sortUnit(a, b) return a.unit < b.unit end

function S.Evaluate(t, rows, other)
  local need = S.Remaining(t)
  local ceil, ceilWhy = S.Ceiling(t)
  local planned = need * t.price
  local exact, bigger, smaller = {}, {}, {}
  for _, r in ipairs(rows) do
    if r.stack == need then exact[#exact + 1] = r
    elseif r.stack > need then bigger[#bigger + 1] = r
    else smaller[#smaller + 1] = r end
  end
  table.sort(exact, sortUnit); table.sort(bigger, sortUnit); table.sort(smaller, sortUnit)
  local out = { options = {} }
  local function opt(kind, hue, rs, text, tip, complete)
    local total, units = 0, 0
    for _, r in ipairs(rs) do total, units = total + r.price, units + r.stack end
    out.options[#out.options + 1] = { kind = kind, hue = hue, rows = rs, total = total, units = units, t = t,
      text = (other and "Also here - " or "") .. text, tip = tip .. (complete and "\nAccepting this completes the task." or ""), complete = complete }
  end
  local base = "Plan: " .. need .. " @ " .. g(t.price) .. " = " .. g(planned) .. ".  Ceiling " .. g(ceil) .. " per item (" .. ceilWhy .. ")."

  local best = exact[1]
  if best and best.unit <= ceil then
    local ok, why = S.Affordable(best.price)
    if ok and not other and rules().autoBuy then
      out.auto = best
      -- tell the player when a bigger stack is cheaper per item (buying it is extra stock, never automatic)
      local cheap
      for _, r in ipairs(bigger) do if r.unit < best.unit and r.unit <= ceil then cheap = r; break end end
      if cheap then
        opt("cheaper", COL.warn, { cheap }, "Cheaper per item in a bigger stack: " .. t.item .. " x" .. cheap.stack .. " @ " .. g(cheap.unit) ..
            " = " .. g(cheap.price) .. "  (+" .. g(cheap.price - best.price) .. " total)",
            base .. "\nBought the exact " .. need .. " @ " .. g(best.unit) .. ". This stack is " .. g(best.unit - cheap.unit) ..
            " less per item, but " .. g(cheap.price - best.price) .. " more in total. Click only if you want the extra stock.")
      end
      return out
    end
    if ok and not other then
      opt("exact", COL.good, { best }, "Ready: " .. t.item .. " x" .. need .. " @ " .. g(best.unit) .. " = " .. g(best.price),
          base .. "\nInside all your rules. Automatic buying is off in Settings, so it waits for your click.", true)
    elseif other then
      opt("exact", COL.good, { best }, t.item .. " x" .. need .. " @ " .. g(best.unit) .. " = " .. g(best.price) ..
          (ok and "" or ("  - " .. why)), base .. "\nPlanned for " .. (t._guild or "another guild") .. "; found here inside your price rule.", true)
    else
      opt("gold", COL.bad, { best }, "Rejected by gold rule: " .. t.item .. " x" .. need .. " = " .. g(best.price) .. "  - " .. why,
          base .. "\nPrice is inside your rule, but the gold rule stopped it. Click to buy anyway.")
    end
    return out
  end

  -- close match: a stack near the quantity you need, inside the price rule; accepting it completes the task
  local R = rules()
  local close
  if R.close > 0 then
    local slack = math.max(1, math.floor(need * R.close / 100))
    for _, r in ipairs(rows) do
      local diff = math.abs(r.stack - need)
      if diff > 0 and diff <= slack and r.unit <= ceil then
        if not close or diff < math.abs(close.stack - need) or (diff == math.abs(close.stack - need) and r.unit < close.unit) then close = r end
      end
    end
    if close then
      local d = close.stack - need
      local ok, why = S.Affordable(close.price)
      opt("close", (close.unit <= t.price) and COL.good or COL.warn, { close },
          "Close match: " .. t.item .. " x" .. close.stack .. " (need " .. need .. ", " .. (d > 0 and "+" or "") .. d .. ") @ " .. g(close.unit) ..
          " = " .. g(close.price) .. (ok and "" or ("  - " .. why)),
          base .. "\nWithin " .. R.close .. "% of your quantity and inside your price rule (" .. g(close.price - planned) .. " vs plan).", true)
    end
  end

  -- skip when the close match already offers the same kind of stack (same size, same or better price)
  local sameAsClose = close and bigger[1] and bigger[1].stack == close.stack and bigger[1].unit >= close.unit
  if bigger[1] and bigger[1].unit <= ceil and not sameAsClose then
    local r = bigger[1]
    local extra = r.stack - need
    local worth = t.avg and (extra * t.avg) or nil
    local hue = (r.unit <= t.price) and COL.good or COL.warn
    local ok, why = S.Affordable(r.price)
    opt("bigger", hue, { r }, (r.unit <= t.price and "Good deal, more stock: " or "Within rules, more than needed: ") ..
        t.item .. " x" .. r.stack .. " @ " .. g(r.unit) .. " = " .. g(r.price) .. (ok and "" or ("  - " .. why)),
        base .. "\n" .. r.stack .. " in one stack: " .. g(r.price) .. ", which is " .. g(r.price - planned) .. " more than planned." ..
        "\nYou'd get " .. extra .. " extra" .. (worth and (", worth about " .. g(worth) .. " at the sale average") or "") .. "." ..
        "\nPer item " .. g(r.unit) .. " vs target " .. g(t.price) .. " (" .. (r.unit <= t.price and "under" or "over") .. " by " .. g(math.abs(r.unit - t.price)) .. ").", true)
  end

  local fill, units = {}, 0
  for _, r in ipairs(smaller) do
    if r.unit <= ceil and units + r.stack <= need then fill[#fill + 1] = r; units = units + r.stack end
  end
  if #fill == 1 and fill[1] == close then fill = {} end   -- same stack already offered as a close match
  if #fill > 0 then
    local total = 0
    for _, r in ipairs(fill) do total = total + r.price end
    local ok, why = S.Affordable(total)
    opt("fill", COL.warn, fill, (#fill > 1 and ("Fill from " .. #fill .. " stacks: ") or "Partial: ") .. t.item .. " " .. units .. " of " .. need ..
        " = " .. g(total) .. (units < need and ("  (" .. (need - units) .. " still to find)") or "") .. (ok and "" or ("  - " .. why)),
        base .. "\nAverage " .. g(total / units) .. " per item, all inside your ceiling.")
  end

  -- nothing usable inside the rule: show the cheapest listing (exact size first) so you can decide
  local over = best
  if not over and #out.options == 0 then
    local all = {}
    for _, r in ipairs(rows) do all[#all + 1] = r end
    table.sort(all, sortUnit)
    over = all[1]
  end
  if over and not other then
    local ok, why = S.Affordable(over.price)
    opt("over", COL.bad, { over }, "Over your price rule: " .. t.item .. " x" .. over.stack .. " @ " .. g(over.unit) .. " = " .. g(over.price) ..
        (over.stack == need and ("  (+" .. g(over.price - planned) .. ")") or ("  (you need " .. need .. ")")) .. (ok and "" or ("  - " .. why)),
        base .. "\n" .. g(over.unit - ceil) .. " per item over your ceiling. Click to buy anyway.")
  end
  if #out.options == 0 then
    out.none = (#rows == 0) and ("Not listed here: " .. t.item) or ("Nothing usable here for " .. t.item .. " (" .. #rows .. " listings, none fit)")
  end
  return out
end

---------------------------------------------------------------------------
-- talking to the store (search, buy), one request at a time
---------------------------------------------------------------------------
local token = 0
local function await(kind, cb, ms)
  token = token + 1
  local my = token
  S.awaiting, S.cb = kind, cb
  zo_callLater(function()
    if S.awaiting and token == my then
      local f = S.cb; S.awaiting, S.cb = nil, nil
      if f then f(nil, "no response from the store") end
    end
  end, ms or TIMEOUT_MS)
end

local function readResults()
  local me = norm(GetDisplayName())
  local num = GetTradingHouseSearchResultsInfo() or 0
  local rows = {}
  for i = 1, num do
    local _, name, _, stack, seller, _, price, currency, uid = GetTradingHouseSearchResultItemInfo(i)
    if currency == CURT_MONEY and stack and stack > 0 and price and price > 0 and norm(seller) ~= me then
      rows[#rows + 1] = { name = zo_strformat("<<1>>", name), stack = stack, price = price, unit = price / stack,
                          uid = uid, seller = seller, link = GetTradingHouseSearchResultItemLink(i, LINK_STYLE_DEFAULT) }
    end
  end
  return rows
end

local function execSearch(hashes, cb)
  if not CC.atStore then return cb(nil, "store closed") end
  local cd = GetTradingHouseCooldownRemaining() or 0
  if cd > 0 or S.awaiting then
    return zo_callLater(function() execSearch(hashes, cb) end, math.max(cd, 300) + 150)
  end
  ClearAllTradingHouseSearchTerms()
  SetTradingHouseFilter(TRADING_HOUSE_FILTER_TYPE_NAME_HASH, unpack(hashes))
  await(TRADING_HOUSE_RESULT_SEARCH_PENDING, function(ok, err)
    if not ok then return cb(nil, err) end
    cb(readResults())
  end)
  ExecuteTradingHouseSearch(0, TRADING_HOUSE_SORT_SALE_PRICE_PER_UNIT, true, false)
end

-- search one task's item; rows are only the exact item (by item id when the task has a link)
function S.SearchItem(t, cb)
  local name = ((t.match or t.item):gsub("%s*%b()", ""))
  local text = ZO_TradingHouseNameSearchFeature_Shared and ZO_TradingHouseNameSearchFeature_Shared.MakeExactSearchText(name) or name
  local id = MatchTradingHouseItemNames(text)
  if not id then return cb(nil, "name search unavailable") end
  S.matchId, S.matchCb = id, function(num)
    if num == 0 then return cb({}) end
    local hashes = {}
    local max = GetMaxTradingHouseFilterExactTerms(TRADING_HOUSE_FILTER_TYPE_NAME_HASH)
    for i = 1, math.min(num, max) do
      local _, h = GetMatchTradingHouseItemNamesResult(id, i)
      hashes[#hashes + 1] = h
    end
    execSearch(hashes, function(rows, err)
      if not rows then return cb(nil, err) end
      local want, wantId = norm(name), t.link and GetItemLinkItemId(t.link)
      local keep = {}
      for _, r in ipairs(rows) do
        local same
        if wantId and wantId > 0 then same = GetItemLinkItemId(r.link) == wantId else same = norm(r.name) == want end
        if same then keep[#keep + 1] = r end
      end
      -- what the store had, for your coach (live prices beat a day-old price table)
      local seen = { item = name, guild = S.run.guild, t = GetTimeStamp(), rows = {} }
      for k = 1, math.min(#keep, 40) do seen.rows[k] = { s = keep[k].stack, p = keep[k].price } end
      CC.sv.seen[norm(name) .. "@" .. norm(S.run.guild)] = seen
      cb(keep)
    end)
  end
end

-- ESO's keyboard store screen opens its own "confirm purchase" box whenever a purchase is set up.
-- While Coach is buying (inside rules you set, or a row you clicked) that box is skipped;
-- your own manual purchases still get it.
local function hooks()
  if S.hooked or not ZO_PreHook then return end
  if TRADING_HOUSE then
    -- skip the box while Coach confirms the purchase itself
    ZO_PreHook(TRADING_HOUSE, "ConfirmPendingPurchase", function() return S.buying == "quiet" end)
  end
  -- you pressed Cancel on the box Coach asked you to confirm
  ZO_PreHook("ClearPendingItemPurchase", function()
    if S.buying == "ask" and S.awaiting == TRADING_HOUSE_RESULT_PURCHASE_PENDING then
      local f = S.cb; S.awaiting, S.cb, S.buying = nil, nil, false
      if f then zo_callLater(function() f(nil, "you cancelled") end, 0) end
    end
  end)
  S.hooked = true
end

-- ask = true: show ESO's confirm box and buy only if you press Accept
local function buyRow(r, cb, ask)
  if rules().dry then return cb(true) end
  if not CC.atStore then return cb(false, "store closed") end
  if S.awaiting then return zo_callLater(function() buyRow(r, cb, ask) end, 300) end
  hooks()
  if ask and IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
    return cb(false, "confirm-each needs keyboard mode")
  end
  S.buying = ask and "ask" or "quiet"
  await(TRADING_HOUSE_RESULT_PURCHASE_PENDING, function(ok, err) S.buying = false; cb(ok, err) end, ask and ASK_TIMEOUT_MS or nil)
  SetPendingItemPurchaseByItemUniqueId(r.uid, r.price)
  if ask then return end   -- ESO's box is open; your Accept confirms it
  ConfirmPendingItemPurchase()
  -- fallback if the box still opened (another addon replacing the store screen, for example)
  if ZO_Dialogs_IsShowing and ZO_Dialogs_IsShowing("CONFIRM_TRADING_HOUSE_PURCHASE") then
    ZO_Dialogs_ReleaseDialog("CONFIRM_TRADING_HOUSE_PURCHASE")
  end
end

-- buy rows one by one; stop at the first failure
local function buyRows(t, rows, how, done, ask)
  local i = 0
  local function step()
    i = i + 1
    local r = rows[i]
    if not r then return done(true) end
    buyRow(r, function(ok, err)
      if ok then record(t, r, how); step()
      else
        if err == "you cancelled" then line(col(COL.note, "Not bought (you pressed Cancel): ") .. t.item .. " x" .. r.stack)
        else line(col(COL.bad, "Purchase failed: ") .. t.item .. " x" .. r.stack .. col(COL.note, "  (" .. tostring(err or "sold or changed") .. ")")) end
        done(false)
      end
    end, ask)
  end
  step()
end

---------------------------------------------------------------------------
-- the visit: queue approved tasks, auto-buy inside rules, collect decisions
---------------------------------------------------------------------------
function S.Begin()
  local ok, _, name = pcall(GetCurrentTradingHouseGuildDetails)
  name = ok and name or nil
  local gn = norm(name)
  if S.run.guildNorm ~= gn then
    S.run = { guild = name, guildNorm = gn, lines = {}, decisions = {}, spent = 0, dryBought = {}, started = false }
  end
  CC.Refresh()
  if rules().onOpen and S.ApprovedHere() > 0 then S.Run() end
end

function S.Run()
  local run = S.run
  if run.busy or not CC.atStore or not run.guildNorm then return end
  local here, other = approvedTasks(run.guildNorm)
  local queue = {}
  for _, t in ipairs(here) do queue[#queue + 1] = { t = t } end
  if rules().others then for _, o in ipairs(other) do queue[#queue + 1] = o end end
  if #queue == 0 then line(col(COL.note, "No approved buys left to check here.")); return end
  run.busy, run.started, run.decisions = true, true, {}
  line(col(COL.head, (rules().dry and "Dry run: " or "Checking ") .. #here .. " approved here" ..
       (#queue > #here and (" + " .. (#queue - #here) .. " from other guilds") or "") .. "..."))
  local i = 0
  local function nextItem()
    i = i + 1
    local q = queue[i]
    if not q or not CC.atStore then
      run.busy = false
      line(col(COL.head, "Done.") .. col(COL.note, "  Spent this visit: " .. g(run.spent) .. (rules().dry and " (dry run, nothing bought)" or "")))
      return
    end
    local t = q.t
    t._guild = q.guild
    S.SearchItem(t, function(rows, err)
      if not rows then line(col(COL.bad, "Search failed: ") .. t.item .. col(COL.note, "  (" .. tostring(err) .. ")")); return nextItem() end
      local ev = S.Evaluate(t, rows, q.other)
      if ev.auto then
        buyRows(t, { ev.auto }, rules().confirmEach and "auto, you confirmed" or "auto, inside rules", function()
          for _, o in ipairs(ev.options) do run.decisions[#run.decisions + 1] = o; note(o, "offered") end
          CC.Refresh()
          nextItem()
        end, rules().confirmEach)
        return
      end
      if ev.none then
        if not q.other then line(col(COL.note, ev.none)) end
      else
        for _, o in ipairs(ev.options) do run.decisions[#run.decisions + 1] = o; note(o, "offered") end
        CC.Refresh()
      end
      nextItem()
    end)
  end
  nextItem()
end

-- a decision clicked: re-search (the page may have changed), then buy the same listings if still there at the same price
function S.Take(o)
  local run = S.run
  if run.busy then return line(col(COL.note, "Busy - try again in a moment.")) end
  local t = o.t
  for k, d in ipairs(run.decisions) do if d == o then table.remove(run.decisions, k); break end end
  note(o, "accepted")
  run.busy = true
  line(col(COL.note, "Checking " .. t.item .. " again..."))
  S.SearchItem(t, function(rows, err)
    if not rows then run.busy = false; return line(col(COL.bad, "Search failed: ") .. tostring(err)) end
    local live = {}
    for _, r in ipairs(rows) do live[Id64ToString(r.uid)] = r end
    local pick = {}
    for _, r in ipairs(o.rows) do
      local now = live[Id64ToString(r.uid)]
      if now and now.price == r.price then pick[#pick + 1] = now end
    end
    if #pick == 0 then run.busy = false; return line(col(COL.warn, "Gone or repriced: ") .. t.item .. col(COL.note, "  - nothing bought")) end
    local total = 0
    for _, r in ipairs(pick) do total = total + r.price end
    if total > GetCurrentMoney() - (rules().dry and run.spent or 0) then run.busy = false; return line(col(COL.bad, "Not enough gold for ") .. t.item) end
    buyRows(t, pick, "your choice: " .. o.kind, function(ok)
      run.busy = false
      if ok and o.complete then
        if rules().dry then
          run.dryBought[t.id] = t.qty   -- the dry run treats the task as covered for this visit
          line(col(COL.dry, "DRY RUN - would mark complete: ") .. t.item)
        else
          CC.SetTaskState(t, "done", t.qty)
          line(col(COL.ok, "Complete: ") .. t.item)
        end
        for k = #run.decisions, 1, -1 do if run.decisions[k].t == t then table.remove(run.decisions, k) end end
      end
      CC.Refresh()
    end)
  end)
end

function S.Skip(o)
  for k, d in ipairs(S.run.decisions) do if d == o then table.remove(S.run.decisions, k); break end end
  note(o, "skipped")
  line(col(COL.note, "Skipped: " .. o.t.item .. " (" .. o.kind .. ")"))
end

---------------------------------------------------------------------------
-- lines for the main window (STORE block at the top while a store is open)
---------------------------------------------------------------------------
function S.Lines()
  if not CC.atStore then return {} end
  local run, R, out = S.run, rules(), {}
  local hereN = S.ApprovedHere()
  if hereN == 0 and #run.lines == 0 and #run.decisions == 0 then return out end
  out[#out + 1] = { kind = "store", text = col(COL.head, "STORE  " .. (run.guild or "?")) ..
    (R.dry and col(COL.dry, "   DRY RUN - nothing is bought") or "") ..
    col(COL.note, "   visit spend " .. g(run.spent) .. (R.cap > 0 and (" / cap " .. g(R.cap)) or "")),
    tip = "Approved buys for this guild run inside your rules (Settings). Decisions: left-click buy, right-click skip." }
  if not run.busy and hereN > 0 then
    out[#out + 1] = { kind = "storeRun", text = col(COL.good, "  > " .. hereN .. " approved here - click to check" .. (run.started and " again" or "")) }
  end
  for _, l in ipairs(run.lines) do out[#out + 1] = { kind = "where", text = "    " .. l.text, tip = l.tip } end
  for _, o in ipairs(run.decisions) do
    out[#out + 1] = { kind = "decision", opt = o, text = col(o.hue, "  [?] " .. o.text), tip = o.tip .. "\n\nLeft-click: buy.  Right-click: skip." }
  end
  return out
end

---------------------------------------------------------------------------
-- settings rows
---------------------------------------------------------------------------
local SETTINGS = {
  { key = "dry", label = "Dry run (log only, never buy)", tip = "On: approved buys and decisions are logged as 'would buy'. Nothing is spent." },
  { key = "onOpen", label = "Check approved items when I open the store", tip = "Off: nothing is searched until you click the 'click to check' row." },
  { key = "autoBuy", label = "Buy exact matches automatically", tip = "Off: even a perfect match waits as a green 'Ready' row for your click." },
  { key = "confirmEach", label = "Ask me to confirm each automatic buy", tip = "On: ESO's own confirm box opens for every automatic buy. Nothing is bought until you press Accept (keyboard mode)." },
  { key = "tol", label = "Price tolerance per item", step = true, tip = "Buy automatically up to target + this, per item." },
  { key = "close", label = "Close-match stack size (+/- %, 0 = off)", step = true, pct = true, tip = "A stack this close to your quantity, at your price, shows as a decision. Accepting it completes the task." },
  { key = "avgStop", label = "Never pay above the sale average", tip = "Uses the sale average in the plan. Caps the tolerance." },
  { key = "cap", label = "Gold cap per store visit (0 = off)", step = true, tip = "Automatic buys stop at this total. Dry-run amounts count too." },
  { key = "keep", label = "Always keep at least (0 = off)", step = true, tip = "Never let an automatic buy take your gold below this." },
  { key = "others", label = "Also check items planned for other guilds", tip = "Found here inside your rules: shown as a decision, never bought automatically." },
}

function S.SettingLines()
  local R, out = rules(), {}
  out[#out + 1] = { kind = "section", key = "settings", text = col("F0E6D2", "SETTINGS") .. col(COL.note, "   left-click: change / up    right-click: down") }
  for _, s in ipairs(SETTINGS) do
    local v = R[s.key]
    local shown
    if s.pct then shown = (v == 0) and "off" or (v .. "%")
    elseif s.step then shown = (v == 0 and s.key ~= "tol") and "off" or g(v)
    else shown = v and "ON" or "off" end
    out[#out + 1] = { kind = "setting", key = s.key, tip = s.tip,
      text = "  " .. s.label .. ":  " .. col((v and v ~= 0) and COL.good or COL.note, shown) }
  end
  out[#out + 1] = { kind = "where", text = col(COL.note, "  Rules apply to approved buys only. Every action is logged for your coach.") }
  return out
end

function S.ChangeSetting(key, down)
  local R = rules()
  local steps = S.STEPS[key]
  if steps then
    local idx = 1
    for i, v in ipairs(steps) do if v <= R[key] then idx = i end end
    idx = zo_clamp(idx + (down and -1 or 1), 1, #steps)
    R[key] = steps[idx]
  else
    R[key] = not R[key]
  end
  PlaySound(SOUNDS.DEFAULT_CLICK)
  CC.Refresh()
end

---------------------------------------------------------------------------
-- init
---------------------------------------------------------------------------
function S.Init()
  CC.sv.rules = CC.sv.rules or {}
  for k, v in pairs(S.DEFAULTS) do if CC.sv.rules[k] == nil then CC.sv.rules[k] = v end end
  CC.sv.buys = CC.sv.buys or {}
  CC.sv.seen = CC.sv.seen or {}
  CC.sv.decisions = CC.sv.decisions or {}
  local EM, ns = EVENT_MANAGER, CC.name .. "Store"
  EM:RegisterForEvent(ns, EVENT_OPEN_TRADING_HOUSE, function() zo_callLater(S.Begin, 900) end)
  EM:RegisterForEvent(ns, EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED, function() if CC.atStore then zo_callLater(S.Begin, 300) end end)
  EM:RegisterForEvent(ns, EVENT_CLOSE_TRADING_HOUSE, function()
    S.awaiting, S.cb, S.matchId, S.matchCb, S.buying = nil, nil, nil, nil, false
    S.run.busy = false
    S.run.guildNorm = nil
  end)
  EM:RegisterForEvent(ns, EVENT_MATCH_TRADING_HOUSE_ITEM_NAMES_COMPLETE, function(_, id, num)
    if id == S.matchId and S.matchCb then
      local f = S.matchCb; S.matchId, S.matchCb = nil, nil
      f(num or 0)
    end
  end)
  EM:RegisterForEvent(ns, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, responseType, result)
    if S.awaiting and responseType == S.awaiting then
      local f = S.cb; S.awaiting, S.cb = nil, nil
      if f then
        if result == TRADING_HOUSE_RESULT_SUCCESS then f(true) else f(nil, "store said no (code " .. tostring(result) .. ")") end
      end
    end
  end)
end
