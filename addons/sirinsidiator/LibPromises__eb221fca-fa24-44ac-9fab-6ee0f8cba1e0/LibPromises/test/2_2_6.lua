-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth then return end

Taneth("LibPromises", function()
    local testFulfilled = LibPromiseTest.testFulfilled
    local testRejected = LibPromiseTest.testRejected

    local dummy = { dummy = "dummy" }          -- we fulfill or reject with this when we don't intend to test against it
    local other = { other = "other" }          -- a value we don't want to be strict equal to
    local sentinel = { sentinel = "sentinel" } -- a sentinel fulfillment value to test for with strict equality
    local sentinel2 = { sentinel2 = "sentinel2" }
    local sentinel3 = { sentinel3 = "sentinel3" }

    local function callbackAggregator(times, ultimateCallback)
        local soFar = 0
        return function()
            soFar = soFar + 1
            if soFar == times then
                ultimateCallback()
            end
        end
    end

    describe("2.2.6: `then` may be called multiple times on the same promise.", function()
        describe(
            "2.2.6.1: If/when `promise` is fulfilled, all respective `onFulfilled` callbacks must execute in the order of their originating calls to `then`.",
            function()
                describe("multiple boring fulfillment handlers", function()
                    testFulfilled(sentinel, function(promise, done)
                        local handler1 = stub().returns(other)
                        local handler2 = stub().returns(other)
                        local handler3 = stub().returns(other)

                        local spy = spy.new(function() end)
                        promise:Then(handler1, spy)
                        promise:Then(handler2, spy)
                        promise:Then(handler3, spy)

                        promise:Then(function(value)
                            assert.equals(value, sentinel)

                            assert.stub(handler1).called_with(sentinel)
                            assert.stub(handler2).called_with(sentinel)
                            assert.stub(handler3).called_with(sentinel)
                            assert.spy(spy).called_at_most(0)

                            done()
                        end)
                    end)
                end)

                describe("multiple fulfillment handlers, one of which throws", function()
                    testFulfilled(sentinel, function(promise, done)
                        local handler1 = stub().returns(other)
                        local handler2 = stub().invokes(function() error(other) end)
                        local handler3 = stub().returns(other)

                        local spy = spy.new(function() end)
                        promise:Then(handler1, spy)
                        promise:Then(handler2, spy)
                        promise:Then(handler3, spy)

                        promise:Then(function(value)
                            assert.equals(value, sentinel)

                            assert.stub(handler1).called_with(sentinel)
                            assert.stub(handler2).called_with(sentinel)
                            assert.stub(handler3).called_with(sentinel)
                            assert.spy(spy).called_at_most(0)

                            done()
                        end)
                    end)
                end)

                describe("results in multiple branching chains with their own fulfillment values", function()
                    testFulfilled(dummy, function(promise, done)
                        local semiDone = callbackAggregator(3, done)

                        promise:Then(function()
                            return sentinel
                        end):Then(function(value)
                            assert.equals(value, sentinel)
                            semiDone()
                        end)

                        promise:Then(function()
                            error(sentinel2)
                        end):Then(nil, function(reason)
                            assert.equals(reason, sentinel2)
                            semiDone()
                        end)

                        promise:Then(function()
                            return sentinel3
                        end):Then(function(value)
                            assert.equals(value, sentinel3)
                            semiDone()
                        end)
                    end)
                end)

                describe("`onFulfilled` handlers are called in the original order", function()
                    testFulfilled(dummy, function(promise, done)
                        local order = {}
                        local handler1 = spy.new(function() order[#order + 1] = 1 end)
                        local handler2 = spy.new(function() order[#order + 1] = 2 end)
                        local handler3 = spy.new(function() order[#order + 1] = 3 end)

                        promise:Then(handler1)
                        promise:Then(handler2)
                        promise:Then(handler3)

                        promise:Then(function()
                            assert.same(order, { 1, 2, 3 })
                            done()
                        end)
                    end)

                    describe("even when one handler is added inside another handler", function()
                        testFulfilled(dummy, function(promise, done)
                            local order = {}
                            local handler1 = spy.new(function() order[#order + 1] = 1 end)
                            local handler2 = spy.new(function() order[#order + 1] = 2 end)
                            local handler3 = spy.new(function() order[#order + 1] = 3 end)

                            promise:Then(function()
                                handler1()
                                promise:Then(handler3)
                            end)
                            promise:Then(handler2)

                            promise:Then(function()
                                -- Give implementations a bit of extra time to flush their internal queue, if necessary.
                                zo_callLater(function()
                                    assert.same(order, { 1, 2, 3 })
                                    done()
                                end, 50)
                            end)
                        end)
                    end)
                end)
            end)

        describe(
            "2.2.6.2: If/when `promise` is rejected, all respective `onRejected` callbacks must execute in the order of their originating calls to `then`.",
            function()
                describe("multiple boring rejection handlers", function()
                    testRejected(sentinel, function(promise, done)
                        local handler1 = stub().returns(other)
                        local handler2 = stub().returns(other)
                        local handler3 = stub().returns(other)

                        local spy = spy.new(function() end)
                        promise:Then(spy, handler1)
                        promise:Then(spy, handler2)
                        promise:Then(spy, handler3)

                        promise:Then(nil, function(reason)
                            assert.equals(reason, sentinel)

                            assert.stub(handler1).called_with(sentinel)
                            assert.stub(handler2).called_with(sentinel)
                            assert.stub(handler3).called_with(sentinel)
                            assert.spy(spy).called_at_most(0)

                            done()
                        end)
                    end)
                end)

                describe("multiple rejection handlers, one of which throws", function()
                    testRejected(sentinel, function(promise, done)
                        local handler1 = stub().returns(other)
                        local handler2 = stub().invokes(function() error(other) end)
                        local handler3 = stub().returns(other)

                        local spy = spy.new(function() end)
                        promise:Then(spy, handler1)
                        promise:Then(spy, handler2)
                        promise:Then(spy, handler3)

                        promise:Then(nil, function(reason)
                            assert.equals(reason, sentinel)

                            assert.stub(handler1).called_with(sentinel)
                            assert.stub(handler2).called_with(sentinel)
                            assert.stub(handler3).called_with(sentinel)
                            assert.spy(spy).called_at_most(0)

                            done()
                        end)
                    end)
                end)

                describe("results in multiple branching chains with their own fulfillment values", function()
                    testRejected(sentinel, function(promise, done)
                        local semiDone = callbackAggregator(3, done)

                        promise:Then(nil, function()
                            return sentinel
                        end):Then(function(value)
                            assert.equals(value, sentinel)
                            semiDone()
                        end)

                        promise:Then(nil, function()
                            error(sentinel2)
                        end):Then(nil, function(reason)
                            assert.equals(reason, sentinel2)
                            semiDone()
                        end)

                        promise:Then(nil, function()
                            return sentinel3
                        end):Then(function(value)
                            assert.equals(value, sentinel3)
                            semiDone()
                        end)
                    end)
                end)

                describe("`onRejected` handlers are called in the original order", function()
                    testRejected(dummy, function(promise, done)
                        local order = {}
                        local handler1 = spy.new(function() order[#order + 1] = 1 end)
                        local handler2 = spy.new(function() order[#order + 1] = 2 end)
                        local handler3 = spy.new(function() order[#order + 1] = 3 end)

                        promise:Then(nil, handler1)
                        promise:Then(nil, handler2)
                        promise:Then(nil, handler3)

                        promise:Then(nil, function()
                            assert.same(order, { 1, 2, 3 })
                            done()
                        end)
                    end)

                    describe("even when one handler is added inside another handler", function()
                        testRejected(dummy, function(promise, done)
                            local order = {}
                            local handler1 = spy.new(function() order[#order + 1] = 1 end)
                            local handler2 = spy.new(function() order[#order + 1] = 2 end)
                            local handler3 = spy.new(function() order[#order + 1] = 3 end)

                            promise:Then(nil, function()
                                handler1()
                                promise:Then(nil, handler3)
                            end)
                            promise:Then(nil, handler2)

                            promise:Then(nil, function()
                                -- Give implementations a bit of extra time to flush their internal queue, if necessary.
                                zo_callLater(function()
                                    assert.same(order, { 1, 2, 3 })
                                    done()
                                end, 50)
                            end)
                        end)
                    end)
                end)
            end)
    end)
end)
