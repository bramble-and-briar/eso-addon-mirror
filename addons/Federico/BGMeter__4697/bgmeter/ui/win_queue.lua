BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local U = BGMeter.UI._win
local set_text = U.set_text

local K = BGMeter.Constants
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Sound = BGMeter.Sound

local Q = {}

local TICKER = "BGMeterQueueTick"

local q = nil
local host = nil

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

local function safe_m(obj, method, ...)
    if not obj or type(obj[method]) ~= "function" then return nil end
    local ok, a = pcall(obj[method], obj, ...)
    if not ok then return nil end
    return a
end

local function clean(s)
    if not s or s == "" then return nil end
    return (tostring(s):gsub("%^.*$", ""))
end

local function push_set(id, name)
    local A = BGMeter.zenimax.api
    if not id then return end
    name = clean(name) or clean(safe(A.lfg_set_info, id)) or ("Set " .. id)
    q.sets[#q.sets + 1] = { id = id, name = name }
end

local function collect_from_manager(types)
    local mgr = ZO_ACTIVITY_FINDER_ROOT_MANAGER
    if not mgr or type(mgr.GetLocationsData) ~= "function" then return false end
    for _, act in ipairs(types) do
        local ok, locations = pcall(mgr.GetLocationsData, mgr, act)
        if ok and type(locations) == "table" and #locations > 0 then
            for _, loc in ipairs(locations) do
                if safe_m(loc, "IsSetEntryType")
                    and not safe_m(loc, "IsLocked")
                    and not safe_m(loc, "IsDisabled") then
                    push_set(safe_m(loc, "GetId"), safe_m(loc, "GetRawName"))
                end
            end
            if #q.sets > 0 then
                q.act = act
                BGMeter.Log.debug("queue sets via manager: %d playable of %d (activity %s)",
                    #q.sets, #locations, tostring(act))
                return true
            end
        end
    end
    return false
end

function Q.populate()
    if not q then return end
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    q.sets = {}
    q.act = nil
    local types = { C.LFG_ACTIVITY_BG_CHAMPION, C.LFG_ACTIVITY_BG_NON_CHAMPION, C.LFG_ACTIVITY_BG_LOW_LEVEL }
    if not collect_from_manager(types) then
        for _, act in ipairs(types) do
            local n = safe(A.lfg_num_sets, act) or 0
            BGMeter.Log.debug("queue sets: activity=%s count=%s", tostring(act), tostring(n))
            if n > 0 then
                q.act = act
                for i = 1, n do
                    local id = safe(A.lfg_set_id, act, i)
                    if id and not safe(A.lfg_set_disabled, id) then
                        push_set(id, nil)
                    end
                end
                BGMeter.Log.debug("queue sets: %d enabled of %d", #q.sets, n)
                break
            end
        end
    end
    if not q.sets[q.sel] then q.sel = 1 end
    if q.combo and q.combo.ClearItems then
        q.combo:ClearItems()
        for i, s in ipairs(q.sets) do
            q.combo:AddItem(q.combo:CreateItemEntry(s.name, function() q.sel = i end))
        end
        if q.sets[q.sel] and q.combo.SetSelectedItemText then
            q.combo:SetSelectedItemText(q.sets[q.sel].name)
        end
    end
end

local bg_types
local function is_bg_activity(activityId)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    if not bg_types then
        bg_types = {}
        for _, t in ipairs({ C.LFG_ACTIVITY_BG_CHAMPION, C.LFG_ACTIVITY_BG_NON_CHAMPION, C.LFG_ACTIVITY_BG_LOW_LEVEL }) do
            if t ~= nil then bg_types[t] = true end
        end
    end
    if not activityId or activityId <= 0 then return false end
    return bg_types[safe(A.lfg_activity_type, activityId)] == true
end

local function bg_searching()
    local A = BGMeter.zenimax.api
    if not safe(A.lfg_searching) then return false end
    local n = safe(A.lfg_num_requests)
    if not n or type(A.lfg_request_ids) ~= "function" then return true end
    for i = 1, n do
        local ok, aid, sid = pcall(A.lfg_request_ids, i)
        if ok then
            if sid and sid ~= 0 and (safe(A.lfg_set_activity_count, sid) or 0) > 0 then
                aid = safe(A.lfg_set_activity_id, sid, 1)
            end
            if is_bg_activity(aid) then return true end
        end
    end
    return false
end

local function in_lfg_dungeon()
    local A = BGMeter.zenimax.api
    local curId = safe(A.lfg_current_activity) or 0
    return curId > 0 and not is_bg_activity(curId)
end

local function ticker_sync(searching)
    local E = BGMeter.zenimax.events
    local want = searching and q ~= nil and host.visible()
    if want and not q.ticking then
        E.register_update(TICKER, 1000, function() Q.update() end)
        q.ticking = true
    elseif not want and q.ticking then
        E.unregister_update(TICKER)
        q.ticking = false
    end
end

function Q.stop_ticker() ticker_sync(false) end

function Q.layout(statusW)
    if not q then return end
    q.statusW = statusW
    q.status:SetWidth(statusW)
end

function Q.update()
    if not q then return end
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local anySearch = safe(A.lfg_searching) and true or false
    local searching = anySearch and bg_searching()
    local capturing = BGMeter.Capture and BGMeter.Capture.is_active and BGMeter.Capture.is_active() or false
    local inDungeon = in_lfg_dungeon()
    if host.on_update then host.on_update() end
    local compact = (q.statusW or 200) < 110
    if q.btn.SetEnabled then
        q.btn:SetEnabled(searching or not (capturing or anySearch or inDungeon))
    end
    if capturing and not searching then
        q.btn:SetText("Queue")
        set_text(q.status, compact and "" or "in a battleground")
        S.color(q.status, K.COLOR.text_dim)
    elseif anySearch and not searching then
        q.btn:SetText("Queue")
        set_text(q.status, compact and "" or "in another queue")
        S.color(q.status, K.COLOR.text_dim)
    elseif inDungeon and not searching then
        q.btn:SetText("Queue")
        set_text(q.status, compact and "" or "in a dungeon")
        S.color(q.status, K.COLOR.text_dim)
    elseif searching then
        q.btn:SetText("Cancel")
        local startMs, etaMs = safe(A.lfg_times)
        local now = safe(A.now_ms) or 0
        local txt = compact and "..." or "in queue"
        if startMs and startMs > 0 and now > startMs then
            if compact then
                txt = F.duration(now - startMs)
            else
                txt = "in queue  " .. F.duration(now - startMs)
                if etaMs and etaMs > startMs then
                    txt = txt .. "  ·  eta ~" .. F.duration(etaMs - startMs)
                end
            end
        end
        set_text(q.status, txt)
        S.color(q.status, K.COLOR.gold)
    else
        q.btn:SetText("Queue")
        local cd = C.LFG_COOLDOWN_BATTLEGROUND_DESERTED_QUEUE
            and safe(A.lfg_cooldown, C.LFG_COOLDOWN_BATTLEGROUND_DESERTED_QUEUE) or 0
        if cd and cd > 0 then
            set_text(q.status, (compact and "" or "deserter  ") .. F.duration(cd * 1000))
            S.color(q.status, K.COLOR.accent)
        else
            set_text(q.status, "")
        end
    end
    ticker_sync(searching or capturing)
end

function Q.click()
    if not q then return end
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    if safe(A.lfg_searching) then
        if bg_searching() then
            safe(A.lfg_cancel)
            Sound.play("nav")
            BGMeter.Log.debug("battleground queue cancelled")
            Q.update()
        end
        return
    end
    if (BGMeter.Capture and BGMeter.Capture.is_active()) or in_lfg_dungeon() then
        return
    end
    local flash
    local s = q.sets and q.sets[q.sel]
    if not s then
        flash = "no queue entries available"
    else
        safe(A.lfg_clear_search)
        safe(A.lfg_add_set, s.id)
        local res = safe(A.lfg_start)
        Sound.play("nav")
        if C.ACTIVITY_QUEUE_RESULT_SUCCESS and res and res ~= C.ACTIVITY_QUEUE_RESULT_SUCCESS then
            flash = "queue rejected (" .. tostring(res) .. ")"
        else
            BGMeter.Log.debug("queued: %s", s.name)
        end
    end
    Q.update()
    if flash then
        set_text(q.status, flash)
        S.color(q.status, K.COLOR.accent)
    end
end

function Q.build(pw, opts)
    host = { win = pw, visible = opts.visible, on_update = opts.on_update }
    local qc = BGMeter.zenimax.ui.create_from_virtual(nil, pw, "ZO_ComboBox")
    qc:SetDimensions(168, 30)
    qc:SetAnchor(BOTTOMLEFT, pw, BOTTOMLEFT, opts.x, opts.y)
    q = { combo_c = qc, sel = 1 }
    local bgc = qc.GetNamedChild and qc:GetNamedChild("BG")
    if bgc and bgc.SetEdgeTexture then
        bgc:SetEdgeTexture(P.FRAME_THIN_EDGE, 128, 16, P.FRAME_THIN_SIZE)
        bgc:SetCenterColor(P.BUTTON_FACE[1], P.BUTTON_FACE[2], P.BUTTON_FACE[3], 1)
    end
    if q.combo then
        local g = K.COLOR.gold
        if q.combo.SetFont then q.combo:SetFont("ZoFontGameBold") end
        if q.combo.SetSelectedColor then q.combo:SetSelectedColor(g[1], g[2], g[3], 1) end
        if q.combo.SetHighlightedColor then q.combo:SetHighlightedColor(1, 0.94, 0.66, 1) end
    end
    if type(ZO_ComboBox_ObjectFromContainer) == "function" then
        local ok, obj = pcall(ZO_ComboBox_ObjectFromContainer, qc)
        if ok then q.combo = obj end
    end
    if q.combo and q.combo.SetSortsItems then
        q.combo:SetSortsItems(false)
    end

    q.btn = P.gold_button(pw, "Queue")
    q.btn:SetDimensions(92, 28)
    q.btn:SetAnchor(LEFT, qc, RIGHT, 4, 0)
    q.btn:SetHandler("OnClicked", function() Q.click() end)

    q.status = P.label(pw, S.FONT.small, K.COLOR.text_dim)
    q.status:SetAnchor(LEFT, q.btn, RIGHT, 8, 0)
    q.status:SetHeight(28)
    q.statusW = 90
    U.clamp_line(q.status)
    return q
end

function Q.controls() return q end

BGMeter.UI.queue = Q
