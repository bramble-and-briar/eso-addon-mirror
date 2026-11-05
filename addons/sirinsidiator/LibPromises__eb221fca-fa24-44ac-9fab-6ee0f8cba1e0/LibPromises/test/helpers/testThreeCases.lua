-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth then return end
local deferred = LibPromiseTest.deferred
local resolved = LibPromiseTest.resolved
local rejected = LibPromiseTest.rejected

local function testFulfilled(value, test)
    setfenv(1, getfenv(2))
    apply_test_env(test)

    it.async("already-fulfilled", function(done)
        test(resolved(value), done)
    end)

    it.async("immediately-fulfilled", function(done)
        local d = deferred()
        test(d.promise, done)
        d.resolve(value)
    end)

    it.async("eventually-fulfilled", function(done)
        local d = deferred()
        test(d.promise, done)
        zo_callLater(function()
            d.resolve(value)
        end, 50)
    end)
end
LibPromiseTest.testFulfilled = testFulfilled

local function testRejected(reason, test)
    setfenv(1, getfenv(2))
    apply_test_env(test)

    it.async("already-rejected", function(done)
        test(rejected(reason), done)
    end)

    it.async("immediately-rejected", function(done)
        local d = deferred()
        test(d.promise, done)
        d.reject(reason)
    end)

    it.async("eventually-rejected", function(done)
        local d = deferred()
        test(d.promise, done)
        zo_callLater(function ()
            d.reject(reason)
        end, 50)
    end)
end
LibPromiseTest.testRejected = testRejected