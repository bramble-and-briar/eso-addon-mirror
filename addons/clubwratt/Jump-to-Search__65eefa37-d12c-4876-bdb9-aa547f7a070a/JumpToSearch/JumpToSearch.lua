-- JumpToSearch.lua: Root namespace
JumpToSearch = {
    name = "JumpToSearch",
    displayName = "Jump to Search",
    version = "0.2.1",
    savedVarsName = "JumpToSearchSavedVars",
    savedVarsVersion = 1,
    actionLayerName = "JumpToSearchLayer",
    ---@type JumpToSearchState
    state = nil,
}

-- The keybindings UI looks this up by action name when EVENT_KEYBINDINGS_LOADED
-- fires (after addons load), so define it at file scope.
ZO_CreateStringId("SI_BINDING_NAME_JUMP_TO_SEARCH_FOCUS", "Jump to Search")
