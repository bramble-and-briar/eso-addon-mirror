
Verdant = Verdant or {}
local Verdant = Verdant
Verdant.lib = Verdant.lib or {}
Verdant.lib.mem = Verdant.lib.mem or {}

local RingBuffer = {}
RingBuffer.__index = RingBuffer
Verdant.lib.mem.RingBuffer = RingBuffer

Verdant.Buffer = RingBuffer

function RingBuffer.new(window_ms, capacity, on_evict)
  local self = setmetatable({}, RingBuffer)
  self.window_ms = window_ms or 5000
  self.capacity  = capacity or 1024
  self.on_evict  = on_evict
  self.entries   = {}
  self.head      = 1
  self.tail      = 0
  return self
end

function RingBuffer:push(entry)
  self.tail = self.tail + 1
  self.entries[self.tail] = entry
  if (self.tail - self.head + 1) > self.capacity then
    local evicted = self.entries[self.head]
    self.entries[self.head] = nil
    self.head = self.head + 1
    if self.on_evict and evicted then self.on_evict(evicted) end
  end
end

function RingBuffer:trim(now_ms)
  local cutoff = now_ms - self.window_ms
  local entries = self.entries
  while self.head <= self.tail and (entries[self.head].t or 0) <= cutoff do
    local evicted = entries[self.head]
    entries[self.head] = nil
    self.head = self.head + 1
    if self.on_evict and evicted then self.on_evict(evicted) end
  end
end

function RingBuffer:sum(now_ms, field, predicate)
  self:trim(now_ms)
  local s = 0
  for i = self.head, self.tail do
    local e = self.entries[i]
    if not predicate or predicate(e) then
      s = s + (e[field] or 0)
    end
  end
  return s
end

function RingBuffer:count(now_ms, predicate)
  self:trim(now_ms)
  local n = 0
  for i = self.head, self.tail do
    if not predicate or predicate(self.entries[i]) then
      n = n + 1
    end
  end
  return n
end

function RingBuffer:size()
  return self.tail - self.head + 1
end

function RingBuffer:reset()
  if self.on_evict then
    for i = self.head, self.tail do
      local e = self.entries[i]
      if e then self.on_evict(e) end
    end
  end
  self.entries = {}
  self.head = 1
  self.tail = 0
end
