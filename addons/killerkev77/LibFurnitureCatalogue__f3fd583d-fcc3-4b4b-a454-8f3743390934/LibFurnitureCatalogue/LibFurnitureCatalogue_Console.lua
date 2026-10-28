-- LibFurnitureCatalogue - console loader
-- Added by the console build script (Build-LFC-Console.ps1), not part of the upstream library.
--
-- Console limits add-ons to 1000 ms of CPU per frame. Upstream builds its whole
-- database in one go, which runs past that limit on console:
--   "cpu time budget of 1000 ms for addons reached this frame"
-- This file spreads the same work over many frames without changing what is built:
--   1. data\GeneratedDatabase.lua is repacked into small blocks
--      (LFCConsoleDatabaseChunks); they are copied into LFCGeneratedDatabase
--      a few blocks per frame.
--   2. Build.lua already runs its build steps through an async task when LibAsync
--      is present (Call / Then / OnError). This file provides a task with that
--      same shape which runs each step in a coroutine and pauses between frames.
--   3. While a step runs, Build.Upsert pauses after every few entries, so the
--      big item loop is split across frames as well.

local LFC = LibFurnitureCatalogue
local internal = LFC and LFC.Internal
local lifecycle = internal and internal.Lifecycle
local build = internal and internal.Build
if not (lifecycle and build and build.Upsert and LFCGeneratedDatabase) then
  return
end

local NAME = "LibFurnitureCatalogue_Console"
local UPSERTS_PER_FRAME = 100 -- database rows written per frame while building
local CHUNKS_PER_FRAME = 2 -- data blocks unpacked per frame while loading
local SLICE_MS = 25 -- also pause once a slice has run this long

local chunks = LFCConsoleDatabaseChunks or {}
local data = LFCGeneratedDatabase
local nextChunk = 1

local now = GetGameTimeMilliseconds
local current -- the coroutine this file is running, if any
local sliceStart, opCount = 0, 0

local function shouldPause()
  opCount = opCount + 1
  return opCount >= UPSERTS_PER_FRAME or (now() - sliceStart) >= SLICE_MS
end

-- Pause inside a build step once this frame's share is used up
local originalUpsert = build.Upsert
local function passThrough(...)
  if current and coroutine.running() == current and shouldPause() then
    coroutine.yield()
  end
  return ...
end
build.Upsert = function(...)
  return passThrough(originalUpsert(...))
end

-- Async task with the shape Build.lua expects from LibAsync
local queue = {}
local onError
local chain = {}
function chain:Then(fn)
  queue[#queue + 1] = fn
  return chain
end
function chain:OnError(fn)
  onError = fn
  return chain
end

local updating = false
local onUpdate

local function startUpdates()
  if not updating then
    updating = true
    EVENT_MANAGER:RegisterForUpdate(NAME, 0, onUpdate)
  end
end

local function stopUpdates()
  if updating then
    updating = false
    EVENT_MANAGER:UnregisterForUpdate(NAME)
  end
end

local task = {}
function task:Call(fn)
  queue = { fn }
  onError = nil
  current = nil
  startUpdates() -- first step starts next frame, after Build.lua has queued the rest
  return chain
end

local function loadChunks()
  local loaded = 0
  while loaded < CHUNKS_PER_FRAME and chunks[nextChunk] do
    local chunk = chunks[nextChunk]
    local section = data[chunk[1]]
    for key, value in pairs(chunk[2]()) do
      section[key] = value
    end
    chunks[nextChunk] = nil
    nextChunk = nextChunk + 1
    loaded = loaded + 1
  end
  return chunks[nextChunk] == nil
end

onUpdate = function()
  -- 1. finish unpacking the data before any build step runs
  if not loadChunks() then
    return
  end

  -- 2. run queued build steps, one slice per frame
  if not current then
    local fn = table.remove(queue, 1)
    if not fn then
      stopUpdates()
      return
    end
    current = coroutine.create(fn)
  end

  sliceStart, opCount = now(), 0
  local ok, err = coroutine.resume(current)
  if not ok then
    current, queue = nil, {}
    stopUpdates()
    if onError then
      onError({ Error = err })
    else
      error(err, 0)
    end
    return
  end
  if coroutine.status(current) == "dead" then
    current = nil
  end
end

lifecycle.task = task
startUpdates() -- begin unpacking the data straight away