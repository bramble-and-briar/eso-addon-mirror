-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth then return end

Taneth("LibPromises", function()
    local rejected = LibPromiseTest.rejected
    local resolved = LibPromiseTest.resolved
    local dummy = { dummy = "dummy" } -- we fulfill or reject with this when we don't intend to test against it

    describe("2.2.1: Both `onFulfilled` and `onRejected` are optional arguments.", function()
        describe("2.2.1.1: If `onFulfilled` is not a function, it must be ignored.", function()
            describe("applied to a directly-rejected promise", function()
                local function testNonFunction(nonFunction, stringRepresentation)
                    it.async("`onFulfilled` is " .. stringRepresentation, function(done)
                        rejected(dummy):Then(nonFunction, function()
                            done()
                        end)
                    end)
                end

                testNonFunction(nil, "`nil`")
                testNonFunction(false, "`false`")
                testNonFunction(5, "`5`")
                testNonFunction({}, "a table")
            end)

            describe("applied to a promise rejected and then chained off of", function()
                local function testNonFunction(nonFunction, stringRepresentation)
                    it.async("`onFulfilled` is " .. stringRepresentation, function(done)
                        rejected(dummy):Then(function() end):Then(nonFunction, function()
                            done()
                        end)
                    end)
                end

                testNonFunction(nil, "`nil`")
                testNonFunction(false, "`false`")
                testNonFunction(5, "`5`")
                testNonFunction({}, "a table")
            end)
        end)

        describe("2.2.1.2: If `onRejected` is not a function, it must be ignored.", function()
            describe("applied to a directly-fulfilled promise", function()
                local function testNonFunction(nonFunction, stringRepresentation)
                    it.async("`onRejected` is " .. stringRepresentation, function(done)
                        resolved(dummy):Then(function()
                            done()
                        end, nonFunction)
                    end)
                end

                testNonFunction(nil, "`nil`")
                testNonFunction(false, "`false`")
                testNonFunction(5, "`5`")
                testNonFunction({}, "an object")
            end)

            describe("applied to a promise fulfilled and then chained off of", function()
                local function testNonFunction(nonFunction, stringRepresentation)
                    it.async("`onRejected` is " .. stringRepresentation, function(done)
                        resolved(dummy):Then(nil, function() end):Then(function()
                            done()
                        end, nonFunction)
                    end)
                end

                testNonFunction(nil, "`nil`")
                testNonFunction(false, "`false`")
                testNonFunction(5, "`5`")
                testNonFunction({}, "an object")
            end)
        end)
    end)
end)
