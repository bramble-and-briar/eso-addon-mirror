-- frame.lua: splits a section payload into QR frame strings.
--
-- Frame wire format (every character is in the QR alphanumeric charset):
--   E2:<session 4ch>:<section 1ch>:<n>/<N>:<fletcher16 4 hex>:<base45 chunk>
-- The whole payload is Base45-encoded first, then cut into chunks of at most maxBodyChars.
-- The decoder reassembles chunks 1..N in order and Base45-decodes the result, so chunk
-- boundaries can fall anywhere. The checksum covers the chunk's characters only.
-- QR has its own error correction. This checksum catches mix-ups during reassembly.

CompanionExport = CompanionExport or {}

local Frame = {}
CompanionExport.Frame = Frame

Frame.VERSION_TAG = "E2"
Frame.DEFAULT_MAX_BODY_CHARS = 450

local SESSION_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

--- Fletcher-16 over the bytes of a string (addition/modulo only, no bit operations).
function Frame.fletcher16(s)
    local sum1, sum2 = 0, 0
    for i = 1, #s do
        sum1 = (sum1 + string.byte(s, i)) % 255
        sum2 = (sum2 + sum1) % 255
    end
    return sum2 * 256 + sum1
end

--- A random 4-character session id. `rand(n)` must return an integer in 1..n;
--- it defaults to math.random (injectable for tests).
function Frame.newSession(rand)
    rand = rand or math.random
    local out = {}
    for i = 1, 4 do
        local k = rand(36)
        out[i] = string.sub(SESSION_ALPHABET, k, k)
    end
    return table.concat(out)
end

--- Build the frame strings for one section.
--- session: 4 chars from [0-9A-Z]; section: 1 char from [A-Z]; bytes: array of 0..255.
function Frame.build(session, section, bytes, maxBodyChars)
    assert(#session == 4 and string.find(session, "^[0-9A-Z]+$"), "frame: bad session id")
    assert(#section == 1 and string.find(section, "^[A-Z]$"), "frame: bad section code")
    maxBodyChars = maxBodyChars or Frame.DEFAULT_MAX_BODY_CHARS
    assert(maxBodyChars >= 1, "frame: maxBodyChars must be >= 1")

    local body = CompanionExport.Base45.encode(bytes)
    local total = math.max(1, math.ceil(#body / maxBodyChars))
    local frames = {}
    for n = 1, total do
        local chunk = string.sub(body, (n - 1) * maxBodyChars + 1, n * maxBodyChars)
        frames[n] = string.format("%s:%s:%s:%d/%d:%04X:%s",
            Frame.VERSION_TAG, session, section, n, total, Frame.fletcher16(chunk), chunk)
    end
    return frames, #body
end
