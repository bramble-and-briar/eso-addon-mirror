
BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.Plot = BGMeter.Plot or {}

local Pool = {}
Pool.__index = Pool

local registry = {}

function Pool.new(factory_fn, reset_fn, label)
    local self = setmetatable({}, Pool)
    self.label = label or ("pool" .. tostring(#registry + 1))
    self.created = 0
    self.zo = BGMeter.zenimax.ui.new_pool(function(p)
        self.created = self.created + 1
        return factory_fn(p)
    end, reset_fn)
    registry[#registry + 1] = self
    return self
end

function Pool:acquire()
    local obj, key = self.zo:AcquireObject()
    return obj, key
end

function Pool:release_all()
    self.zo:ReleaseAllObjects()
end

function Pool:release(key)
    self.zo:ReleaseObject(key)
end

function Pool:active_count()
    return self.zo:GetActiveObjectCount()
end

function Pool:total()
    return self.created
end

function Pool:reserve(total)
    local keys, made = {}, 0
    while self.created < total do
        local before = self.created
        local _, key = self.zo:AcquireObject()
        keys[#keys + 1] = key
        if self.created > before then made = made + 1 end
    end
    for i = 1, #keys do self.zo:ReleaseObject(keys[i]) end
    return made
end

function Pool.all()
    return registry
end

BGMeter.Plot.pool = Pool
