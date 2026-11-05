-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth then return end

Taneth("LibPromises", function()
    local deferred = LibPromiseTest.deferred
    local resolved = LibPromiseTest.resolved
    local rejected = LibPromiseTest.rejected

    local dummy = { dummy = "dummy" }      -- we fulfill or reject with this when we don't intend to test against it
    local sentinel = { sentinel = "sentinel" } -- a sentinel fulfillment value to test for with strict equality

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

    describe("2.3.2: If `x` is a promise, adopt its state", function()
        describe("2.3.2.1: If `x` is pending, `promise` must remain pending until `x` is fulfilled or rejected.",
            function()
                local function xFactory()
                    return deferred().promise
                end

                testPromiseResolution(xFactory, function(promise, done)
                    local wasFulfilled = false
                    local wasRejected = false

                    promise:Then(
                        function()
                            wasFulfilled = true
                        end,
                        function()
                            wasRejected = true
                        end
                    )

                    zo_callLater(function()
                        assert.equals(wasFulfilled, false)
                        assert.equals(wasRejected, false)
                        done()
                    end, 100)
                end)
            end)

        describe("2.3.2.2: If/when `x` is fulfilled, fulfill `promise` with the same value.", function()
            describe("`x` is already-fulfilled", function()
                local function xFactory()
                    return resolved(sentinel)
                end

                testPromiseResolution(xFactory, function(promise, done)
                    promise:Then(function(value)
                        assert.equals(value, sentinel)
                        done()
                    end)
                end)
            end)

            describe("`x` is eventually-fulfilled", function()
                local d = nil

                local function xFactory()
                    d = deferred()
                    zo_callLater(function()
                        d.resolve(sentinel)
                    end, 50)
                    return d.promise
                end

                testPromiseResolution(xFactory, function(promise, done)
                    promise:Then(function(value)
                        assert.equals(value, sentinel)
                        done()
                    end)
                end)
            end)
        end)

        describe("2.3.2.3: If/when `x` is rejected, reject `promise` with the same reason.", function()
            describe("`x` is already-rejected", function()
                local function xFactory()
                    return rejected(sentinel)
                end

                testPromiseResolution(xFactory, function(promise, done)
                    promise:Then(nil, function(reason)
                        assert.equals(reason, sentinel)
                        done()
                    end)
                end)
            end)

            describe("`x` is eventually-rejected", function()
                local d = nil

                local function xFactory()
                    d = deferred()
                    zo_callLater(function()
                        d.reject(sentinel)
                    end, 50)
                    return d.promise
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
