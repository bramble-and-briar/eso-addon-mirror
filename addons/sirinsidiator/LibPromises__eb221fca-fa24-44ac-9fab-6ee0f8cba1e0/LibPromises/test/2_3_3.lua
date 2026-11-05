-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth then return end

Taneth("LibPromises", function()
    local deferred = LibPromiseTest.deferred
    local resolved = LibPromiseTest.resolved
    local rejected = LibPromiseTest.rejected

    local thenables = LibPromiseTest.thenables
    local reasons = LibPromiseTest.reasons

    local dummy = { dummy = "dummy" }          -- we fulfill or reject with this when we don't intend to test against it
    local sentinel = { sentinel = "sentinel" } -- a sentinel fulfillment value to test for with strict equality
    local other = { other = "other" }          -- a value we don't want to be strict equal to
    local sentinelArray = { sentinel }         -- a sentinel fulfillment value to test when we need an array

    local function testPromiseResolution(xFactory, test)
        apply_test_env(test)

        it.async("via return from a fulfilled promise", function(done)
            local promise = resolved(dummy):Then(function()
                return xFactory()
            end)

            test(promise, done)
        end)

        it.async("via return from a rejected promise", function(done)
            local promise = rejected(dummy):Then(nil, function()
                return xFactory()
            end)

            test(promise, done)
        end)
    end

    local function testCallingResolvePromise(yFactory, stringRepresentation, test)
        describe("`y` is " .. stringRepresentation, function()
            describe("`then` calls `resolvePromise` synchronously", function()
                local function xFactory()
                    return {
                        Then = function(self, resolvePromise)
                            resolvePromise(yFactory())
                        end
                    }
                end

                testPromiseResolution(xFactory, test)
            end)

            describe("`then` calls `resolvePromise` asynchronously", function()
                local function xFactory()
                    return {
                        Then = function(self, resolvePromise)
                            zo_callLater(function()
                                resolvePromise(yFactory())
                            end, 0)
                        end
                    }
                end

                testPromiseResolution(xFactory, test)
            end)
        end)
    end

    local function testCallingRejectPromise(r, stringRepresentation, test)
        describe("`r` is " .. stringRepresentation, function()
            describe("`then` calls `rejectPromise` synchronously", function()
                local function xFactory()
                    return {
                        Then = function(self, resolvePromise, rejectPromise)
                            rejectPromise(r)
                        end
                    }
                end

                testPromiseResolution(xFactory, test)
            end)

            describe("`then` calls `rejectPromise` asynchronously", function()
                local function xFactory()
                    return {
                        Then = function(self, resolvePromise, rejectPromise)
                            zo_callLater(function()
                                rejectPromise(r)
                            end, 0)
                        end
                    }
                end

                testPromiseResolution(xFactory, test)
            end)
        end)
    end

    local function testCallingResolvePromiseFulfillsWith(yFactory, stringRepresentation, fulfillmentValue)
        testCallingResolvePromise(yFactory, stringRepresentation, function(promise, done)
            promise:Then(function(value)
                assert.equals(value, fulfillmentValue)
                done()
            end)
        end)
    end

    local function testCallingResolvePromiseRejectsWith(yFactory, stringRepresentation, rejectionReason)
        testCallingResolvePromise(yFactory, stringRepresentation, function(promise, done)
            promise:Then(nil, function(reason)
                assert.equals(reason, rejectionReason)
                done()
            end)
        end)
    end

    local function testCallingRejectPromiseRejectsWith(reason, stringRepresentation)
        testCallingRejectPromise(reason, stringRepresentation, function(promise, done)
            promise:Then(nil, function(rejectionReason)
                assert.equals(rejectionReason, reason)
                done()
            end)
        end)
    end

    describe("2.3.3: Otherwise, if `x` is an object or function,", function()
        describe("2.3.3.1: Let `then` be `x.then`", function()
            describe("`x` is a table with metatable __index for Then", function()
                local numberOfTimesThenWasRetrieved = nil

                before_each(function()
                    numberOfTimesThenWasRetrieved = 0
                end)

                local function xFactory()
                    return setmetatable({}, {
                        __index = function(key)
                            numberOfTimesThenWasRetrieved = numberOfTimesThenWasRetrieved + 1
                            return function(self, onFulfilled)
                                onFulfilled()
                            end
                        end
                    })
                end

                testPromiseResolution(xFactory, function(promise, done)
                    promise:Then(function()
                        assert.equals(numberOfTimesThenWasRetrieved, 1)
                        done()
                    end)
                end)
            end)

            describe("`x` is a plain table with Then", function()
                local numberOfTimesThenWasRetrieved = nil

                before_each(function()
                    numberOfTimesThenWasRetrieved = 0
                end)

                local function xFactory()
                    return setmetatable({
                        Then = function(self, onFulfilled)
                            onFulfilled()
                        end
                    }, {
                        __index = function(t, i)
                            numberOfTimesThenWasRetrieved = numberOfTimesThenWasRetrieved + 1
                            return rawget(t, i)
                        end
                    })
                end

                testPromiseResolution(xFactory, function(promise, done)
                    promise:Then(function()
                        assert.equals(numberOfTimesThenWasRetrieved, 0)
                        done()
                    end)
                end)
            end)
        end)

        describe(
            "2.3.3.2: If retrieving the property `x.then` results in a thrown exception `e`, reject `promise` with `e` as the reason.",
            function()
                local function testRejectionViaThrowingGetter(e, stringRepresentation)
                    local function xFactory()
                        return setmetatable({}, {
                            __index = function()
                                error(e)
                            end
                        })
                    end

                    describe("`e` is " .. stringRepresentation, function()
                        testPromiseResolution(xFactory, function(promise, done)
                            promise:Then(nil, function(reason)
                                assert.equals(reason, e)
                                done()
                            end)
                        end)
                    end)
                end

                for stringRepresentation, func in pairs(reasons) do
                    testRejectionViaThrowingGetter(func, stringRepresentation)
                end
            end)

        describe(
            "2.3.3.3: If `then` is a function, call it with `x` as `this`, first argument `resolvePromise`, and second argument `rejectPromise`",
            function()
                describe("Calls with `x` as `this` and two function arguments", function()
                    local function xFactory()
                        local x
                        x = {
                            Then = function(self, onFulfilled, onRejected)
                                assert.equals(self, x)
                                assert.equals(type(onFulfilled), "function")
                                assert.equals(type(onRejected), "function")
                                onFulfilled()
                            end
                        }
                        return x
                    end
                    apply_test_env(xFactory)

                    testPromiseResolution(xFactory, function(promise, done)
                        promise:Then(function()
                            done()
                        end)
                    end)
                end)

                describe("Uses the original value of `then`", function()
                    local numberOfTimesThenWasRetrieved = nil

                    before_each(function()
                        numberOfTimesThenWasRetrieved = 0
                    end)

                    local function xFactory()
                        return setmetatable({}, {
                            __index = function()
                                if numberOfTimesThenWasRetrieved == 0 then
                                    return function(self, onFulfilled)
                                        onFulfilled()
                                    end
                                end
                                return nil
                            end
                        })
                    end

                    testPromiseResolution(xFactory, function(promise, done)
                        promise:Then(function()
                            done()
                        end)
                    end)
                end)

                describe("2.3.3.3.1: If/when `resolvePromise` is called with value `y`, run `[[Resolve]](promise, y)`",
                    function()
                        describe("`y` is not a thenable", function()
                            testCallingResolvePromiseFulfillsWith(function() return nil end, "`nil`", nil)
                            testCallingResolvePromiseFulfillsWith(function() return false end, "`false`", false)
                            testCallingResolvePromiseFulfillsWith(function() return 5 end, "`5`", 5)
                            testCallingResolvePromiseFulfillsWith(function() return sentinel end, "an object", sentinel)
                            testCallingResolvePromiseFulfillsWith(function() return sentinelArray end, "an array",
                                sentinelArray)
                        end)

                        describe("`y` is a thenable", function()
                            for stringRepresentation, func in pairs(thenables.fulfilled) do
                                local function yFactory()
                                    return func(sentinel)
                                end

                                testCallingResolvePromiseFulfillsWith(yFactory, stringRepresentation, sentinel)
                            end

                            for stringRepresentation, func in pairs(thenables.rejected) do
                                local function yFactory()
                                    return func(sentinel)
                                end

                                testCallingResolvePromiseRejectsWith(yFactory, stringRepresentation, sentinel)
                            end
                        end)

                        describe("`y` is a thenable for a thenable", function()
                            for outerStringRepresentation, outerThenableFactory in pairs(thenables.fulfilled) do
                                for innerStringRepresentation, innerThenableFactory in pairs(thenables.fulfilled) do
                                    local stringRepresentation = outerStringRepresentation ..
                                        " for " .. innerStringRepresentation

                                    local function yFactory()
                                        return outerThenableFactory(innerThenableFactory(sentinel))
                                    end

                                    testCallingResolvePromiseFulfillsWith(yFactory, stringRepresentation, sentinel)
                                end

                                for innerStringRepresentation, innerThenableFactory in pairs(thenables.rejected) do
                                    local stringRepresentation = outerStringRepresentation ..
                                        " for " .. innerStringRepresentation

                                    local function yFactory()
                                        return outerThenableFactory(innerThenableFactory(sentinel))
                                    end

                                    testCallingResolvePromiseRejectsWith(yFactory, stringRepresentation, sentinel)
                                end
                            end
                        end)
                    end)

                describe("2.3.3.3.2: If/when `rejectPromise` is called with reason `r`, reject `promise` with `r`",
                    function()
                        for stringRepresentation, func in pairs(reasons) do
                            testCallingRejectPromiseRejectsWith(func(), stringRepresentation)
                        end
                    end)

                describe(
                    "2.3.3.3.3: If both `resolvePromise` and `rejectPromise` are called, or multiple calls to the same argument are made, the first call takes precedence, and any further calls are ignored.",
                    function()
                        describe("calling `resolvePromise` then `rejectPromise`, both synchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise, rejectPromise)
                                        resolvePromise(sentinel)
                                        rejectPromise(other)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(function(value)
                                    assert.equals(value, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("calling `resolvePromise` synchronously then `rejectPromise` asynchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise, rejectPromise)
                                        resolvePromise(sentinel)

                                        zo_callLater(function()
                                            rejectPromise(other)
                                        end, 0)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(function(value)
                                    assert.equals(value, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("calling `resolvePromise` then `rejectPromise`, both asynchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise, rejectPromise)
                                        zo_callLater(function()
                                            resolvePromise(sentinel)
                                            zo_callLater(function()
                                                rejectPromise(other)
                                            end, 0)
                                        end, 0)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(function(value)
                                    assert.equals(value, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe(
                            "calling `resolvePromise` with an asynchronously-fulfilled promise, then calling `rejectPromise`, both synchronously",
                            function()
                                local function xFactory()
                                    local d = deferred()
                                    zo_callLater(function()
                                        d.resolve(sentinel)
                                    end, 50)

                                    return {
                                        Then = function(self, resolvePromise, rejectPromise)
                                            resolvePromise(d.promise)
                                            rejectPromise(other)
                                        end
                                    }
                                end

                                testPromiseResolution(xFactory, function(promise, done)
                                    promise:Then(function(value)
                                        assert.equals(value, sentinel)
                                        done()
                                    end)
                                end)
                            end)

                        describe(
                            "calling `resolvePromise` with an asynchronously-rejected promise, then calling `rejectPromise`, both synchronously",
                            function()
                                local function xFactory()
                                    local d = deferred()
                                    zo_callLater(function()
                                        d.reject(sentinel)
                                    end, 50)

                                    return {
                                        Then = function(self, resolvePromise, rejectPromise)
                                            resolvePromise(d.promise)
                                            rejectPromise(other)
                                        end
                                    }
                                end

                                testPromiseResolution(xFactory, function(promise, done)
                                    promise:Then(nil, function(reason)
                                        assert.equals(reason, sentinel)
                                        done()
                                    end)
                                end)
                            end)

                        describe("calling `rejectPromise` then `resolvePromise`, both synchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise, rejectPromise)
                                        rejectPromise(sentinel)
                                        resolvePromise(other)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(nil, function(reason)
                                    assert.equals(reason, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("calling `rejectPromise` synchronously then `resolvePromise` asynchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise, rejectPromise)
                                        rejectPromise(sentinel)

                                        zo_callLater(function()
                                            resolvePromise(other)
                                        end, 0)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(nil, function(reason)
                                    assert.equals(reason, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("calling `rejectPromise` then `resolvePromise`, both asynchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise, rejectPromise)
                                        zo_callLater(function()
                                            rejectPromise(sentinel)
                                            zo_callLater(function()
                                                resolvePromise(other)
                                            end, 0)
                                        end, 0)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(nil, function(reason)
                                    assert.equals(reason, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("calling `resolvePromise` twice synchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise)
                                        resolvePromise(sentinel)
                                        resolvePromise(other)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(function(value)
                                    assert.equals(value, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("calling `resolvePromise` twice, first synchronously then asynchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise)
                                        resolvePromise(sentinel)

                                        zo_callLater(function()
                                            resolvePromise(other)
                                        end, 0)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(function(value)
                                    assert.equals(value, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("calling `resolvePromise` twice, both times asynchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise)
                                        zo_callLater(function()
                                            resolvePromise(sentinel)
                                            zo_callLater(function()
                                                resolvePromise(other)
                                            end, 0)
                                        end, 0)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(function(value)
                                    assert.equals(value, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe(
                            "calling `resolvePromise` with an asynchronously-fulfilled promise, then calling it again, both times synchronously",
                            function()
                                local function xFactory()
                                    local d = deferred()
                                    zo_callLater(function()
                                        d.resolve(sentinel)
                                    end, 50)

                                    return {
                                        Then = function(self, resolvePromise)
                                            resolvePromise(d.promise)
                                            resolvePromise(other)
                                        end
                                    }
                                end

                                testPromiseResolution(xFactory, function(promise, done)
                                    promise:Then(function(value)
                                        assert.equals(value, sentinel)
                                        done()
                                    end)
                                end)
                            end)

                        describe(
                            "calling `resolvePromise` with an asynchronously-rejected promise, then calling it again, both times synchronously",
                            function()
                                local function xFactory()
                                    local d = deferred()
                                    zo_callLater(function()
                                        d.reject(sentinel)
                                    end, 50)

                                    return {
                                        Then = function(self, resolvePromise)
                                            resolvePromise(d.promise)
                                            resolvePromise(other)
                                        end
                                    }
                                end

                                testPromiseResolution(xFactory, function(promise, done)
                                    promise:Then(nil, function(reason)
                                        assert.equals(reason, sentinel)
                                        done()
                                    end)
                                end)
                            end)

                        describe("calling `rejectPromise` twice synchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise, rejectPromise)
                                        rejectPromise(sentinel)
                                        rejectPromise(other)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(nil, function(reason)
                                    assert.equals(reason, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("calling `rejectPromise` twice, first synchronously then asynchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise, rejectPromise)
                                        rejectPromise(sentinel)

                                        zo_callLater(function()
                                            rejectPromise(other)
                                        end, 0)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(nil, function(reason)
                                    assert.equals(reason, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("calling `rejectPromise` twice, both times asynchronously", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise, rejectPromise)
                                        zo_callLater(function()
                                            rejectPromise(sentinel)
                                            zo_callLater(function()
                                                rejectPromise(other)
                                            end, 0)
                                        end, 0)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(nil, function(reason)
                                    assert.equals(reason, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("saving and abusing `resolvePromise` and `rejectPromise`", function()
                            local savedResolvePromise, savedRejectPromise

                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise, rejectPromise)
                                        savedResolvePromise = resolvePromise
                                        savedRejectPromise = rejectPromise
                                    end
                                }
                            end

                            before_each(function()
                                savedResolvePromise = nil
                                savedRejectPromise = nil
                            end)

                            testPromiseResolution(xFactory, function(promise, done)
                                local timesFulfilled = 0
                                local timesRejected = 0

                                promise:Then(
                                    function()
                                        timesFulfilled = timesFulfilled + 1
                                    end,
                                    function()
                                        timesRejected = timesRejected + 1
                                    end
                                )

                                if savedResolvePromise and savedRejectPromise then
                                    savedResolvePromise(dummy)
                                    savedResolvePromise(dummy)
                                    savedRejectPromise(dummy)
                                    savedRejectPromise(dummy)
                                end

                                zo_callLater(function()
                                    savedResolvePromise(dummy)
                                    savedResolvePromise(dummy)
                                    savedRejectPromise(dummy)
                                    savedRejectPromise(dummy)
                                end, 50)

                                zo_callLater(function()
                                    assert.equals(timesFulfilled, 1)
                                    assert.equals(timesRejected, 0)
                                    done()
                                end, 100)
                            end)
                        end)
                    end)

                describe("2.3.3.3.4: If calling `then` throws an exception `e`,", function()
                    describe("2.3.3.3.4.1: If `resolvePromise` or `rejectPromise` have been called, ignore it.",
                        function()
                            describe("`resolvePromise` was called with a non-thenable", function()
                                local function xFactory()
                                    return {
                                        Then = function(self, resolvePromise)
                                            resolvePromise(sentinel)
                                            error(other)
                                        end
                                    }
                                end

                                testPromiseResolution(xFactory, function(promise, done)
                                    promise:Then(function(value)
                                        assert.equals(value, sentinel)
                                        done()
                                    end)
                                end)
                            end)

                            describe("`resolvePromise` was called with an asynchronously-fulfilled promise", function()
                                local function xFactory()
                                    local d = deferred()
                                    zo_callLater(function()
                                        d.resolve(sentinel)
                                    end, 50)

                                    return {
                                        Then = function(self, resolvePromise)
                                            resolvePromise(d.promise)
                                            error(other)
                                        end
                                    }
                                end

                                testPromiseResolution(xFactory, function(promise, done)
                                    promise:Then(function(value)
                                        assert.equals(value, sentinel)
                                        done()
                                    end)
                                end)
                            end)

                            describe("`resolvePromise` was called with an asynchronously-rejected promise", function()
                                local function xFactory()
                                    local d = deferred()
                                    zo_callLater(function()
                                        d.reject(sentinel)
                                    end, 50)

                                    return {
                                        Then = function(self, resolvePromise)
                                            resolvePromise(d.promise)
                                            error(other)
                                        end
                                    }
                                end

                                testPromiseResolution(xFactory, function(promise, done)
                                    promise:Then(nil, function(reason)
                                        assert.equals(reason, sentinel)
                                        done()
                                    end)
                                end)
                            end)

                            describe("`rejectPromise` was called", function()
                                local function xFactory()
                                    return {
                                        Then = function(self, resolvePromise, rejectPromise)
                                            rejectPromise(sentinel)
                                            error(other)
                                        end
                                    }
                                end

                                testPromiseResolution(xFactory, function(promise, done)
                                    promise:Then(nil, function(reason)
                                        assert.equals(reason, sentinel)
                                        done()
                                    end)
                                end)
                            end)

                            describe("`resolvePromise` then `rejectPromise` were called", function()
                                local function xFactory()
                                    return {
                                        Then = function(self, resolvePromise, rejectPromise)
                                            resolvePromise(sentinel)
                                            rejectPromise(other)
                                            error(other)
                                        end
                                    }
                                end

                                testPromiseResolution(xFactory, function(promise, done)
                                    promise:Then(function(value)
                                        assert.equals(value, sentinel)
                                        done()
                                    end)
                                end)
                            end)

                            describe("`rejectPromise` then `resolvePromise` were called", function()
                                local function xFactory()
                                    return {
                                        Then = function(self, resolvePromise, rejectPromise)
                                            rejectPromise(sentinel)
                                            resolvePromise(other)
                                            error(other)
                                        end
                                    }
                                end

                                testPromiseResolution(xFactory, function(promise, done)
                                    promise:Then(nil, function(reason)
                                        assert.equals(reason, sentinel)
                                        done()
                                    end)
                                end)
                            end)
                        end)

                    describe("2.3.3.3.4.2: Otherwise, reject `promise` with `e` as the reason.", function()
                        describe("straightforward case", function()
                            local function xFactory()
                                return {
                                    Then = function()
                                        error(sentinel)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(nil, function(reason)
                                    assert.equals(reason, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("`resolvePromise` is called asynchronously before the `throw`", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise)
                                        zo_callLater(function()
                                            resolvePromise(other)
                                        end, 0)
                                        error(sentinel)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(nil, function(reason)
                                    assert.equals(reason, sentinel)
                                    done()
                                end)
                            end)
                        end)

                        describe("`rejectPromise` is called asynchronously before the `throw`", function()
                            local function xFactory()
                                return {
                                    Then = function(self, resolvePromise, rejectPromise)
                                        zo_callLater(function()
                                            rejectPromise(other)
                                        end, 0)
                                        error(sentinel)
                                    end
                                }
                            end

                            testPromiseResolution(xFactory, function(promise, done)
                                promise:Then(nil, function(reason)
                                    assert.equals(reason, sentinel)
                                    done()
                                end)
                            end)
                        end)
                    end)
                end)
            end)

        describe("2.3.3.4: If `then` is not a function, fulfill promise with `x`", function()
            local function testFulfillViaNonFunction(Then, stringRepresentation)
                local x = nil

                before_each(function()
                    x = { Then = Then }
                end)

                local function xFactory()
                    return x
                end

                describe("`then` is " .. stringRepresentation, function()
                    testPromiseResolution(xFactory, function(promise, done)
                        promise:Then(function(value)
                            assert.equals(value, x)
                            done()
                        end)
                    end)
                end)
            end

            testFulfillViaNonFunction(5, "`5`")
            testFulfillViaNonFunction({}, "a table")
            testFulfillViaNonFunction({ function() end }, "an array containing a function")
        end)
    end)
end)
