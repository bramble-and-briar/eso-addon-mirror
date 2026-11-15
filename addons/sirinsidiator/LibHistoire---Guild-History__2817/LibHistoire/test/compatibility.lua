-- SPDX-FileCopyrightText: 2026 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth then return end
local internal = LibHistoire.internal

Taneth("LibHistoire", function()
    describe("legacy event id conversion", function()
        describe("ConvertEventIdToLegacyId64", function()
            it("encodes a 9 digit eventId with a 3 prefix", function()
                local id64 = internal.ConvertEventIdToLegacyId64(123456789)
                assert.equals("3123456789", Id64ToString(id64))
            end)

            it("pads short eventIds with zeros", function()
                local id64 = internal.ConvertEventIdToLegacyId64(1)
                assert.equals("3000000001", Id64ToString(id64))
            end)

            it("encodes the largest 9 digit eventId", function()
                local id64 = internal.ConvertEventIdToLegacyId64(999999999)
                assert.equals("3999999999", Id64ToString(id64))
            end)
        end)

        describe("ConvertLegacyId64ToEventId", function()
            it("decodes a legacy id64 back to the original eventId", function()
                local id64 = StringToId64("3123456789")
                assert.equals(123456789, internal.ConvertLegacyId64ToEventId(id64))
            end)

            it("decodes zero to zero", function()
                assert.equals(0, internal.ConvertLegacyId64ToEventId(StringToId64("0")))
            end)

            it("decodes the smallest legacy id", function()
                local id64 = StringToId64("3000000001")
                assert.equals(1, internal.ConvertLegacyId64ToEventId(id64))
            end)

            it("decodes the largest legacy id", function()
                local id64 = StringToId64("3999999999")
                assert.equals(999999999, internal.ConvertLegacyId64ToEventId(id64))
            end)

            it("rejects a 10 digit id without 3 prefix", function()
                local id64 = StringToId64("1234567890")
                assert.is_nil(internal.ConvertLegacyId64ToEventId(id64))
            end)

            it("rejects a 9 digit id", function()
                local id64 = StringToId64("123456789")
                assert.is_nil(internal.ConvertLegacyId64ToEventId(id64))
            end)
        end)

        describe("round trip", function()
            local eventIds = { 1, 42, 123456789, 999999999 }
            for i = 1, #eventIds do
                local eventId = eventIds[i]
                it("preserves eventId " .. eventId, function()
                    local id64 = internal.ConvertEventIdToLegacyId64(eventId)
                    assert.equals(eventId, internal.ConvertLegacyId64ToEventId(id64))
                end)
            end
        end)

        -- target behavior for the offset based scheme: legacyId = eventId + 3e9
        describe("10 digit eventIds", function()
            describe("ConvertEventIdToLegacyId64", function()
                it("encodes the smallest 10 digit eventId with a 4 prefix", function()
                    local id64 = internal.ConvertEventIdToLegacyId64(1000000000)
                    assert.equals("4000000000", Id64ToString(id64))
                end)

                it("encodes a 10 digit eventId by replacing the leading 1 with a 4", function()
                    local id64 = internal.ConvertEventIdToLegacyId64(1234567890)
                    assert.equals("4234567890", Id64ToString(id64))
                end)

                it("encodes the largest 10 digit eventId starting with 1", function()
                    local id64 = internal.ConvertEventIdToLegacyId64(1999999999)
                    assert.equals("4999999999", Id64ToString(id64))
                end)

                it("encodes a 10 digit eventId starting with 2 with a 5 prefix", function()
                    local id64 = internal.ConvertEventIdToLegacyId64(2000000000)
                    assert.equals("5000000000", Id64ToString(id64))
                end)

                it("encodes the largest supported eventId", function()
                    local id64 = internal.ConvertEventIdToLegacyId64(6999999999)
                    assert.equals("9999999999", Id64ToString(id64))
                end)

                it("fails on an eventId that would exceed 10 digits", function()
                    assert.has_error("eventId is too large to convert", function()
                        internal.ConvertEventIdToLegacyId64(7000000000)
                    end)
                end)
            end)

            describe("ConvertLegacyId64ToEventId", function()
                it("decodes a 4 prefix id", function()
                    local id64 = StringToId64("4000000000")
                    assert.equals(1000000000, internal.ConvertLegacyId64ToEventId(id64))
                end)

                it("decodes a 4 prefix id with payload", function()
                    local id64 = StringToId64("4234567890")
                    assert.equals(1234567890, internal.ConvertLegacyId64ToEventId(id64))
                end)

                it("decodes the largest legacy id", function()
                    local id64 = StringToId64("9999999999")
                    assert.equals(6999999999, internal.ConvertLegacyId64ToEventId(id64))
                end)

                it("rejects a 10 digit id below the legacy range", function()
                    local id64 = StringToId64("2000000000")
                    assert.is_nil(internal.ConvertLegacyId64ToEventId(id64))
                end)
            end)

            describe("round trip", function()
                local eventIds = { 1000000000, 1234567890, 1999999999, 2000000000, 6999999999 }
                for i = 1, #eventIds do
                    local eventId = eventIds[i]
                    it("preserves eventId " .. eventId, function()
                        local id64 = internal.ConvertEventIdToLegacyId64(eventId)
                        assert.equals(eventId, internal.ConvertLegacyId64ToEventId(id64))
                    end)
                end
            end)

            describe("ordering", function()
                it("keeps 10 digit ids above 9 digit ids", function()
                    local small = internal.ConvertEventIdToLegacyId64(999999999)
                    local large = internal.ConvertEventIdToLegacyId64(1000000000)
                    assert.equals(-1, CompareId64s(small, large))
                end)

                it("preserves order between 10 digit ids", function()
                    local a = internal.ConvertEventIdToLegacyId64(1234567890)
                    local b = internal.ConvertEventIdToLegacyId64(1234567891)
                    assert.equals(-1, CompareId64s(a, b))
                end)
            end)
        end)
    end)
end)
