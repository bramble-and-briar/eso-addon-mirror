-- mem_begin.lua: loaded first, so /qrspike mem can estimate this add-on's own load footprint.
-- collectgarbage("count") returns Lua memory in KB (ZOS's own ZO_StartMemProfile uses it).
-- These are load-time snapshots without a forced GC, so they include some garbage.

CompanionExport_MemMarks = { begin = collectgarbage("count") }
