-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

local LIB_IDENTIFIER = "LibPromises"

assert(not _G[LIB_IDENTIFIER], LIB_IDENTIFIER .. " is already loaded")

local lib = {
    SetUnhandledRejectionHandler = function(self, handler)
        self.unhandledRejectionHandler = handler
    end
}

if LibDebugLogger then
    local logger = LibDebugLogger(LIB_IDENTIFIER)
    lib.logger = logger
    lib:SetUnhandledRejectionHandler(function(promise)
        logger:Warn("Unhandled promise rejection:", promise.value)
    end)
end

_G[LIB_IDENTIFIER] = lib

local STATE_PENDING = 1
local STATE_FULFILLED = 2
local STATE_REJECTED = 3
local STATE_STRING = {
    [STATE_PENDING] = "STATE_PENDING",
    [STATE_FULFILLED] = "STATE_FULFILLED",
    [STATE_REJECTED] = "STATE_REJECTED",
}

local Promise = ZO_Object:Subclass()

local function IsPromise(obj)
    return getmetatable(obj) == Promise
end

local function IsCallable(func)
    return type(func) == "function" or type(rawget(getmetatable(func) or {}, "__call")) == "function"
end

local function GetThenFunctionIfIsThenable(table)
    if type(table) ~= "table" then return end
    local thenFunction = table.Then
    if thenFunction and IsCallable(thenFunction) then
        return thenFunction
    end
end

local Resolve

local function ResolveThenable(promise, x, thenFunction)
    local wasCalled = false
    local success, e = pcall(function()
        return thenFunction(x, function(y)
            if not wasCalled then
                wasCalled = true
                Resolve(promise, y)
            end
        end, function(r)
            if not wasCalled then
                wasCalled = true
                promise:Reject(r)
            end
        end)
    end)
    if not success and not wasCalled then
        promise:Reject(e)
        return
    end
end

function Resolve(promise, x)
    if promise == x then
        promise:Reject("TypeError: Tried to pass promise to itself")
        return
    end
    if IsPromise(x) then
        x:Then(function(value)
            Resolve(promise, value)
        end, function(reason)
            promise:Reject(reason)
        end)
    elseif IsCallable(x) then
        ResolveThenable(promise, { Then = x }, x)
    elseif type(x) == "table" then
        local success, thenFunction = pcall(GetThenFunctionIfIsThenable, x)
        if not success then
            promise:Reject(thenFunction)
        elseif thenFunction then
            ResolveThenable(promise, x, thenFunction)
        else
            promise:Resolve(x)
        end
    else
        promise:Resolve(x)
    end
end

local functionsCache = { {}, {} }
local targetIndex = 1
local drainScheduled = false

local function ScheduleDrain()
    if drainScheduled then return end
    drainScheduled = true
    zo_callLater(function()
        local functions = functionsCache[targetIndex]
        targetIndex = targetIndex % #functionsCache + 1
        drainScheduled = false
        ZO_ClearTable(functionsCache[targetIndex])
        for i = 1, #functions do
            functions[i]()
        end
        ZO_ClearTable(functions)
    end, 0)
end

local function ExecuteAllLater(functions, value)
    if #functions == 0 then return end
    local target = functionsCache[targetIndex]
    for i = 1, #functions do
        local func = functions[i]
        target[#target + 1] = function() func(value) end
    end
    ScheduleDrain()
end

local function ClearAll(functions)
    for i = 1, #functions do
        functions[i] = nil
    end
end

local function SanitizeError(err)
    if type(err) == "string" then
        -- Lua5.1 error() converts numeric arguments to string, and the game prefixes the
        -- message with the location and appends a stack traceback
        local traceback = err:find("stack traceback", 1, true)
        if traceback then err = err:sub(1, traceback - 1) end
        local message = err:match("^.-:%d+: (.*)$") or err
        message = message:gsub("%s+$", "")
        local number = tonumber(message)
        if number then return number end
        return message
    end
    return err
end

local function GetNumArgsAndArgs(...)
    return select("#", ...), ...
end

local function WrapCall(callback, promise, nextPromise)
    return function()
        local count, x -- we need to distinguish between nil and no return value
        local success, e = pcall(function()
            count, x = GetNumArgsAndArgs(callback(promise.value))
        end)
        if not success then
            nextPromise:Reject(SanitizeError(e))
        elseif count > 0 then
            Resolve(nextPromise, x)
        end
    end
end

local function DoReportUnhandledRejectionIfNeeded(self)
    self.unhandledRejectionHandler = nil
    if lib.unhandledRejectionHandler and #self.rejected == 0 then
        lib.unhandledRejectionHandler(self)
    end
end

local function RequestReportUnhandledRejectionIfNeeded(self)
    if lib.unhandledRejectionHandler then
        self.unhandledRejectionHandler = zo_callLater(function()
            DoReportUnhandledRejectionIfNeeded(self)
        end, 0)
    end
end

local function ClearReportUnhandledRejectionIfNeeded(self)
    if self.unhandledRejectionHandler and #self.rejected > 0 then
        zo_removeCallLater(self.unhandledRejectionHandler)
        self.unhandledRejectionHandler = nil
    end
end

local function FlushAllCallbacks(self)
    if self.state == STATE_FULFILLED then
        ExecuteAllLater(self.fulfilled, self.value)
    elseif self.state == STATE_REJECTED then
        ClearReportUnhandledRejectionIfNeeded(self)
        ExecuteAllLater(self.rejected, self.value)
    end

    if self.state ~= STATE_PENDING then
        ClearAll(self.fulfilled)
        ClearAll(self.rejected)
    end
end

local next = 1
function Promise:New()
    local obj = ZO_Object.New(self)
    obj.name = string.format("Promise%d", next)
    next = next + 1
    obj.state = STATE_PENDING
    obj.fulfilled = {}
    obj.rejected = {}
    return obj
end

function Promise:Then(OnFulfilled, OnRejected)
    local nextPromise = Promise:New()

    if IsCallable(OnFulfilled) then
        self.fulfilled[#self.fulfilled + 1] = WrapCall(OnFulfilled, self, nextPromise)
    else
        self.fulfilled[#self.fulfilled + 1] = function(value) nextPromise:Resolve(value) end
    end

    if IsCallable(OnRejected) then
        self.rejected[#self.rejected + 1] = WrapCall(OnRejected, self, nextPromise)
    else
        self.rejected[#self.rejected + 1] = function(value) nextPromise:Reject(value) end
    end

    if self.state ~= STATE_PENDING then
        FlushAllCallbacks(self)
    end

    return nextPromise
end

function Promise:Resolve(value)
    if self.state == STATE_PENDING then
        self.value = value
        self.state = STATE_FULFILLED
        FlushAllCallbacks(self)
    end
end

function Promise:Reject(reason)
    if self.state == STATE_PENDING then
        self.value = reason
        self.state = STATE_REJECTED
        RequestReportUnhandledRejectionIfNeeded(self)
        FlushAllCallbacks(self)
    end
end

function Promise:ToString(name)
    name = name or self.name or "Promise"
    local stateString = STATE_STRING[self.state]
    local numFulfilled = #self.fulfilled
    local numRejected = #self.rejected
    return string.format("%s(%s, #f: %d, #r: %d)", name, stateString, numFulfilled, numRejected)
end

function lib:New()
    return Promise:New()
end
