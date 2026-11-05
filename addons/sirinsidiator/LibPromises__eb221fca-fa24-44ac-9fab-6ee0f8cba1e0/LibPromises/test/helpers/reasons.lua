-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth then return end
local resolved = LibPromiseTest.resolved
local rejected = LibPromiseTest.rejected

-- This module exports some valid rejection reason factories, keyed by human-readable versions of their names.

local dummy = { dummy = "dummy" }

local exports = {}

exports["`nil`"] = function()
    return nil
end

exports["`false`"] = function()
    return false
end

exports["`0`"] = function()
    return 0
end

exports["a table"] = function()
    return {}
end

exports["an always-pending thenable"] = function()
    return { Then = function() end }
end

exports["a fulfilled promise"] = function()
    return resolved(dummy)
end

exports["a rejected promise"] = function()
    local promise = rejected(dummy)
    promise:Then(nil, function() end)
    return promise
end

LibPromiseTest.reasons = exports
