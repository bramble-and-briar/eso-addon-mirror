-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth then return end

Taneth("LibPromises", function()
    local testFulfilled = LibPromiseTest.testFulfilled
    local testRejected = LibPromiseTest.testRejected

    local dummy = { dummy = "dummy" } -- we fulfill or reject with this when we don't intend to test against it

    describe("2.3.4: If `x` is not an object or function, fulfill `promise` with `x`", function()
        local function testValue(expectedValue, stringRepresentation, beforeEachHook, afterEachHook)
            describe("The value is " .. stringRepresentation, function()
                if type(beforeEachHook) == "function" then
                    before_each(beforeEachHook)
                end
                if type(afterEachHook) == "function" then
                    after_each(afterEachHook)
                end

                testFulfilled(dummy, function(promise1, done)
                    local promise2 = promise1:Then(function()
                        return expectedValue
                    end)

                    promise2:Then(function(actualValue)
                        assert.equals(actualValue, expectedValue)
                        done()
                    end)
                end)
                testRejected(dummy, function(promise1, done)
                    local promise2 = promise1:Then(nil, function()
                        return expectedValue
                    end)

                    promise2:Then(function(actualValue)
                        assert.equals(actualValue, expectedValue)
                        done()
                    end)
                end)
            end)
        end

        testValue(nil, "`nil`")
        testValue(false, "`false`")
        testValue(true, "`true`")
        testValue(0, "`0`")
        testValue("test", "'test'")
    end)
end)
